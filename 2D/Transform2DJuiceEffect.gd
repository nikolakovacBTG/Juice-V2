## Transform2DJuiceEffect.gd
## ============================================================================
## WHAT: Animate position, rotation, or scale of a Node2D with tween-based easing.
## WHY: Replaces 3 separate scripts with one unified component. Select a
##      transform_target (Position, Rotation, or Scale) and configure a From/To
##      animation using CUSTOM values, SELF snapshots, or live TARGET_NODE refs.
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Handle Control or Node3D targets — use TransformControl/3DJuiceEffect.
## DOES NOT: Handle procedural effects like shake or noise — use Shake/Noise effects.
## ============================================================================
##
## WRITE PATTERN: Delta-first. Each frame writes only the CHANGE in this effect's
##   contribution: node.property += (desired - _my_contribution). This enables
##   stacking with other effects and preserves external changes to the node.
##
## FROM/TO MODEL:
## All transform types use a "From [source] To [destination]" model.
## Sources can be CUSTOM (explicit value), SELF (snapshot), or TARGET_NODE (live).
##
## PIVOT (ROTATION and SCALE):
## Node2D lacks native pivot_offset, so pivot is achieved by position compensation:
##   Rotation: fixed_pivot = base_pos + pivot.rotated(base_rot),
##             new_pos = fixed_pivot - pivot.rotated(new_rot)
##   Scale:    pos += pivot * (ONE - scale_ratio)
## AUTO_CENTER infers visual center from Sprite2D/CollisionShape2D/Polygon2D etc.
##
## CONDITIONAL EXPORTS:
## Uses _get_property_list() to conditionally show/hide parameters based on
## transform_target and from/to reference selections.
## ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase2D.svg")
class_name Transform2DJuiceEffect
extends Juice2DEffectBase


# =============================================================================
# ENUMS
# =============================================================================

## Which transform property to animate
enum TransformTarget {
	POSITION,  ## Animate Node2D.position with offset + unit
	ROTATION,  ## Animate Node2D.rotation (single-axis Z, degrees)
	SCALE      ## Animate Node2D.scale with offset
}

## Determines how the pivot point is calculated
enum PivotMode {
	AUTO_CENTER,  ## Infer visual center and compensate position (most common)
	INHERIT,      ## Rotate/scale from node origin (no compensation)
	CUSTOM        ## Rotate/scale from custom_pivot (local-space pixels)
}

## Reference type for From/To axes (shared by Position, Rotation, and Scale)
enum TransformReference {
	CUSTOM,       ## Explicit value supplied by the user
	SELF,         ## This object's current value (captured at capture_at moment)
	TARGET_NODE   ## Another object's value (tracked live every frame)
}

## How to interpret custom position values (2D)
enum PositionIn {
	PIXELS,           ## Position in absolute pixels
	FRACTION_OWN,     ## Position in fraction of object's own size
	FRACTION_PARENT,  ## Position in fraction of parent's size
	FRACTION_VIEWPORT ## Position in fraction of viewport size
}

## When to capture Self's transform value
enum CaptureAt {
	TRIGGER,    ## Capture when animation starts (default)
	READY,      ## Capture when scene loads / _ready()
	IN_EDITOR   ## WYSIWYG — bake editor-time value into the scene file
}


# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Effect")

@export var transform_target: TransformTarget = TransformTarget.POSITION:
	set(value):
		transform_target = value
		notify_property_list_changed()


# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — they are shown/hidden via _get_property_list()
# =============================================================================

# --- POSITION (From/To model) ---
var from_position: Vector2 = Vector2.ZERO
var from_position_in: int = PositionIn.FRACTION_OWN
var to_position: Vector2 = Vector2.ZERO
var to_position_in: int = PositionIn.FRACTION_OWN

# --- ROTATION (From/To model) ---
var from_rotation_degrees: float = 0.0
var to_rotation_degrees: float = 15.0

# --- SHARED FROM/TO (used by all transform types) ---
var from_reference: int = TransformReference.SELF:
	set(value):
		from_reference = value
		notify_property_list_changed()
var to_reference: int = TransformReference.CUSTOM:
	set(value):
		to_reference = value
		notify_property_list_changed()
var from_target_node: NodePath
var to_target_node: NodePath
var capture_at: int = CaptureAt.TRIGGER:
	set(value):
		capture_at = value
		if value != CaptureAt.IN_EDITOR:
			_editor_cached_position = Vector2.ZERO
			_editor_cached_rotation = 0.0
			_editor_cached_scale = Vector2.ONE
		elif Engine.is_editor_hint():
			_update_editor_cache()
		notify_property_list_changed()

# --- SCALE (From/To model) ---
var from_scale: Vector2 = Vector2.ZERO
var to_scale: Vector2 = Vector2.ONE

# --- PIVOT (ROTATION + SCALE) ---
var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()
var custom_pivot: Vector2 = Vector2.ZERO

# --- EDITOR CACHE (serialized only when capture_at == IN_EDITOR) ---
var _editor_cached_position: Vector2 = Vector2.ZERO
var _editor_cached_rotation: float = 0.0
var _editor_cached_scale: Vector2 = Vector2.ONE


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	match transform_target:
		TransformTarget.POSITION:
			props.append_array(_get_position_from_to_properties())
		TransformTarget.ROTATION:
			props.append_array(_get_rotation_from_to_properties())
			props.append_array(_get_pivot_properties())
		TransformTarget.SCALE:
			props.append_array(_get_scale_from_to_properties())
			props.append_array(_get_pivot_properties())

	var uses_self := (from_reference == TransformReference.SELF or to_reference == TransformReference.SELF)
	if uses_self and capture_at == CaptureAt.IN_EDITOR:
		props.append({"name": "_editor_cached_position", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_STORAGE})
		props.append({"name": "_editor_cached_rotation", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_STORAGE})
		props.append({"name": "_editor_cached_scale", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_STORAGE})

	return props


func _get_position_from_to_properties() -> Array[Dictionary]:
	var pos_props: Array[Dictionary] = []

	pos_props.append({"name": "From", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	pos_props.append({
		"name": "from_reference", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node",
	})
	if from_reference == TransformReference.CUSTOM:
		pos_props.append({
			"name": "from_position_in", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Pixels,Fraction Own,Fraction Parent,Fraction Viewport",
		})
		pos_props.append({
			"name": "from_position", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif from_reference == TransformReference.SELF:
		pos_props.append({
			"name": "capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor",
		})
	elif from_reference == TransformReference.TARGET_NODE:
		pos_props.append({
			"name": "from_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D",
		})

	pos_props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	pos_props.append({
		"name": "to_reference", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node",
	})
	if to_reference == TransformReference.CUSTOM:
		pos_props.append({
			"name": "to_position_in", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Pixels,Fraction Own,Fraction Parent,Fraction Viewport",
		})
		pos_props.append({
			"name": "to_position", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif to_reference == TransformReference.SELF:
		pos_props.append({
			"name": "capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor",
		})
	elif to_reference == TransformReference.TARGET_NODE:
		pos_props.append({
			"name": "to_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D",
		})
	return pos_props


func _get_rotation_from_to_properties() -> Array[Dictionary]:
	var rot_props: Array[Dictionary] = []

	rot_props.append({"name": "From", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	rot_props.append({
		"name": "from_reference", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node",
	})
	if from_reference == TransformReference.CUSTOM:
		rot_props.append({
			"name": "from_rotation_degrees", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif from_reference == TransformReference.SELF:
		rot_props.append({
			"name": "capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor",
		})
	elif from_reference == TransformReference.TARGET_NODE:
		rot_props.append({
			"name": "from_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D",
		})

	rot_props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	rot_props.append({
		"name": "to_reference", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node",
	})
	if to_reference == TransformReference.CUSTOM:
		rot_props.append({
			"name": "to_rotation_degrees", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif to_reference == TransformReference.SELF:
		rot_props.append({
			"name": "capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor",
		})
	elif to_reference == TransformReference.TARGET_NODE:
		rot_props.append({
			"name": "to_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D",
		})
	return rot_props


func _get_scale_from_to_properties() -> Array[Dictionary]:
	var scale_props: Array[Dictionary] = []

	scale_props.append({"name": "From", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	scale_props.append({
		"name": "from_reference", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node",
	})
	if from_reference == TransformReference.CUSTOM:
		scale_props.append({
			"name": "from_scale", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif from_reference == TransformReference.SELF:
		scale_props.append({
			"name": "capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor",
		})
	elif from_reference == TransformReference.TARGET_NODE:
		scale_props.append({
			"name": "from_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D",
		})

	scale_props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	scale_props.append({
		"name": "to_reference", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node",
	})
	if to_reference == TransformReference.CUSTOM:
		scale_props.append({
			"name": "to_scale", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif to_reference == TransformReference.SELF:
		scale_props.append({
			"name": "capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor",
		})
	elif to_reference == TransformReference.TARGET_NODE:
		scale_props.append({
			"name": "to_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D",
		})
	return scale_props


func _get_pivot_properties() -> Array[Dictionary]:
	var pivot_props: Array[Dictionary] = [
		{
			"name": "pivot_mode", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Auto Center,Inherit,Custom",
		},
	]
	if pivot_mode == PivotMode.CUSTOM:
		pivot_props.append({
			"name": "custom_pivot", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE,
		})
	return pivot_props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"from_position": from_position = value; return true
		&"from_position_in": from_position_in = value; return true
		&"to_position": to_position = value; return true
		&"to_position_in": to_position_in = value; return true
		&"from_rotation_degrees": from_rotation_degrees = value; return true
		&"to_rotation_degrees": to_rotation_degrees = value; return true
		&"from_reference": from_reference = value; return true
		&"to_reference": to_reference = value; return true
		&"from_target_node": from_target_node = value; return true
		&"to_target_node": to_target_node = value; return true
		&"capture_at": capture_at = value; return true
		&"from_scale": from_scale = value; return true
		&"to_scale": to_scale = value; return true
		&"pivot_mode": pivot_mode = value; return true
		&"custom_pivot": custom_pivot = value; return true
		&"_editor_cached_position": _editor_cached_position = value; return true
		&"_editor_cached_rotation": _editor_cached_rotation = value; return true
		&"_editor_cached_scale": _editor_cached_scale = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"from_position": return from_position
		&"from_position_in": return from_position_in
		&"to_position": return to_position
		&"to_position_in": return to_position_in
		&"from_rotation_degrees": return from_rotation_degrees
		&"to_rotation_degrees": return to_rotation_degrees
		&"from_reference": return from_reference
		&"to_reference": return to_reference
		&"from_target_node": return from_target_node
		&"to_target_node": return to_target_node
		&"capture_at": return capture_at
		&"from_scale": return from_scale
		&"to_scale": return to_scale
		&"pivot_mode": return pivot_mode
		&"custom_pivot": return custom_pivot
		&"_editor_cached_position": return _editor_cached_position
		&"_editor_cached_rotation": return _editor_cached_rotation
		&"_editor_cached_scale": return _editor_cached_scale
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _base_position: Vector2 = Vector2.ZERO
var _base_rotation_radians: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _has_base: bool = false

# Resolved pivot point in target's local space (for rotation/scale)
var _pivot_point: Vector2 = Vector2.ZERO
var _pivot_resolved: bool = false

# Fixed pivot position in parent space (pre-computed at animation start for rotation)
var _fixed_pivot_parent: Vector2 = Vector2.ZERO

# Delta-first contribution tracking
var _my_position_contribution: Vector2 = Vector2.ZERO
var _my_rotation_contribution: float = 0.0
var _my_scale_contribution: Vector2 = Vector2.ZERO

# External-move detection
var _last_written_position: Vector2 = Vector2.INF

# Resolved From/To target node references
var _from_ref: Node2D = null
var _to_ref: Node2D = null

# Self snapshots
var _self_position_snapshot: Vector2 = Vector2.ZERO
var _has_self_position_snapshot: bool = false
var _self_rotation_snapshot: float = 0.0
var _has_self_rotation_snapshot: bool = false
var _self_scale_snapshot: Vector2 = Vector2.ONE
var _has_self_scale_snapshot: bool = false


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

func _on_host_ready(target: Node, host: Node) -> void:
	_host_node = host
	_capture_base(target)

	var uses_self := (from_reference == TransformReference.SELF or to_reference == TransformReference.SELF)
	if not uses_self:
		return
	if capture_at == CaptureAt.IN_EDITOR:
		return
	if capture_at == CaptureAt.READY:
		match transform_target:
			TransformTarget.POSITION:
				_capture_self_position_snapshot(target)
			TransformTarget.ROTATION:
				_capture_self_rotation_snapshot(target)
			TransformTarget.SCALE:
				_capture_self_scale_snapshot(target)


func _on_editor_pre_save(target: Node) -> void:
	_update_editor_cache(target)


func _on_animate_start(target: Node) -> void:
	if not _has_base:
		_capture_base(target)

	_resolve_from_to_refs()

	var uses_self := (from_reference == TransformReference.SELF or to_reference == TransformReference.SELF)
	if uses_self and (capture_at == CaptureAt.TRIGGER or capture_at == CaptureAt.IN_EDITOR):
		match transform_target:
			TransformTarget.POSITION:
				_capture_self_position_snapshot(target)
			TransformTarget.ROTATION:
				_capture_self_rotation_snapshot(target)
			TransformTarget.SCALE:
				_capture_self_scale_snapshot(target)

	# Resolve pivot for rotation/scale targets
	if transform_target != TransformTarget.POSITION and not _pivot_resolved:
		_resolve_pivot(target)
		_pivot_resolved = true

	# Pre-compute fixed pivot in parent space for rotation
	if transform_target == TransformTarget.ROTATION:
		_fixed_pivot_parent = _base_position + _pivot_point.rotated(_base_rotation_radians)

	if debug_enabled:
		print("[Transform2D] Start: %s" % TransformTarget.keys()[transform_target])


func _apply_effect(progress: float, target: Node) -> void:
	var n2d := target as Node2D
	if n2d == null:
		return

	match transform_target:
		TransformTarget.POSITION:
			_apply_position_effect(progress, n2d)
		TransformTarget.ROTATION:
			_apply_rotation_effect(progress, n2d)
		TransformTarget.SCALE:
			_apply_scale_effect(progress, n2d)


func _restore_to_natural(target: Node) -> void:
	var n2d := target as Node2D
	if n2d == null:
		return
	match transform_target:
		TransformTarget.POSITION:
			n2d.position -= _my_position_contribution
			_my_position_contribution = Vector2.ZERO
			_last_written_position = n2d.position
		TransformTarget.ROTATION:
			n2d.rotation -= _my_rotation_contribution
			_my_rotation_contribution = 0.0
			if _pivot_point != Vector2.ZERO:
				n2d.position -= _my_position_contribution
				_my_position_contribution = Vector2.ZERO
				_last_written_position = n2d.position
		TransformTarget.SCALE:
			n2d.scale -= _my_scale_contribution
			_my_scale_contribution = Vector2.ZERO
			if _pivot_point != Vector2.ZERO:
				n2d.position -= _my_position_contribution
				_my_position_contribution = Vector2.ZERO
				_last_written_position = n2d.position


func _temporarily_undo_visual(target: Node) -> void:
	var n2d := target as Node2D
	if n2d == null:
		return
	match transform_target:
		TransformTarget.POSITION:
			n2d.position -= _my_position_contribution
			_last_written_position = n2d.position
		TransformTarget.ROTATION:
			n2d.rotation -= _my_rotation_contribution
			if _pivot_point != Vector2.ZERO:
				n2d.position -= _my_position_contribution
				_last_written_position = n2d.position
		TransformTarget.SCALE:
			n2d.scale -= _my_scale_contribution
			if _pivot_point != Vector2.ZERO:
				n2d.position -= _my_position_contribution
				_last_written_position = n2d.position


func _temporarily_reapply_visual(target: Node) -> void:
	var n2d := target as Node2D
	if n2d == null:
		return
	match transform_target:
		TransformTarget.POSITION:
			n2d.position += _my_position_contribution
			_last_written_position = n2d.position
		TransformTarget.ROTATION:
			n2d.rotation += _my_rotation_contribution
			if _pivot_point != Vector2.ZERO:
				n2d.position += _my_position_contribution
				_last_written_position = n2d.position
		TransformTarget.SCALE:
			n2d.scale += _my_scale_contribution
			if _pivot_point != Vector2.ZERO:
				n2d.position += _my_position_contribution
				_last_written_position = n2d.position


func _invalidate_base_cache() -> void:
	_has_base = false
	_pivot_resolved = false
	_from_ref = null
	_to_ref = null
	_has_self_position_snapshot = false
	_has_self_rotation_snapshot = false
	_has_self_scale_snapshot = false
	_my_position_contribution = Vector2.ZERO
	_my_rotation_contribution = 0.0
	_my_scale_contribution = Vector2.ZERO
	_last_written_position = Vector2.INF


func _get_interrupt_identity() -> Variant:
	return [get_script(), transform_target]


# =============================================================================
# POSITION EFFECT
# =============================================================================

func _apply_position_effect(progress: float, target: Node2D) -> void:
	if _last_written_position != Vector2.INF:
		if not target.position.is_equal_approx(_last_written_position):
			_base_position = target.position
			_my_position_contribution = Vector2.ZERO

	var from_value := _resolve_from_position(target)
	var to_value := _resolve_to_position(target)
	var desired_absolute := from_value.lerp(to_value, progress)

	var desired_offset := desired_absolute - _base_position
	var delta := desired_offset - _my_position_contribution
	target.position += delta
	_my_position_contribution = desired_offset
	_last_written_position = target.position


func _resolve_from_position(animated: Node2D) -> Vector2:
	match from_reference:
		TransformReference.CUSTOM:
			return _base_position + _convert_to_world_pixels(from_position, from_position_in, animated)
		TransformReference.SELF:
			return _self_position_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_position(_from_ref, animated)
			return _base_position
	return _base_position


func _resolve_to_position(animated: Node2D) -> Vector2:
	match to_reference:
		TransformReference.CUSTOM:
			return _base_position + _convert_to_world_pixels(to_position, to_position_in, animated)
		TransformReference.SELF:
			return _self_position_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_position(_to_ref, animated)
			return _base_position
	return _base_position


func _convert_to_world_pixels(position: Vector2, position_in: int, target: Node2D) -> Vector2:
	match position_in:
		PositionIn.PIXELS:
			return position
		PositionIn.FRACTION_OWN:
			var size := _infer_node2d_size(target)
			return Vector2(position.x * size.x, position.y * size.y)
		PositionIn.FRACTION_PARENT:
			var size := _infer_parent_size(target)
			return Vector2(position.x * size.x, position.y * size.y)
		PositionIn.FRACTION_VIEWPORT:
			var size := _get_viewport_size(target)
			return Vector2(position.x * size.x, position.y * size.y)
	return position


func _get_ref_local_position(ref: Node2D, animated: Node2D) -> Vector2:
	var parent := animated.get_parent()
	if parent is Node2D:
		return (parent as Node2D).global_transform.affine_inverse() * ref.global_position
	elif parent is Control:
		return (parent as Control).get_global_transform().affine_inverse() * ref.global_position
	return ref.global_position


# =============================================================================
# ROTATION EFFECT
# =============================================================================

## Apply rotation with pivot compensation. Node2D lacks native pivot_offset:
##   fixed_pivot = base_pos + pivot.rotated(base_rot)
##   new_pos = fixed_pivot - pivot.rotated(new_rot)
func _apply_rotation_effect(progress: float, target: Node2D) -> void:
	var from_rad := _resolve_from_rotation(target)
	var to_rad := _resolve_to_rotation(target)
	var desired_absolute := lerp_angle(from_rad, to_rad, progress)

	var desired_offset := desired_absolute - _base_rotation_radians
	var rot_delta := desired_offset - _my_rotation_contribution
	target.rotation += rot_delta
	_my_rotation_contribution = desired_offset

	# Pivot compensation
	if _pivot_point != Vector2.ZERO:
		var desired_pos := _fixed_pivot_parent - _pivot_point.rotated(desired_absolute)
		var desired_pos_offset := desired_pos - _base_position
		var pos_delta := desired_pos_offset - _my_position_contribution
		target.position += pos_delta
		_my_position_contribution = desired_pos_offset


func _resolve_from_rotation(animated: Node2D) -> float:
	match from_reference:
		TransformReference.CUSTOM:
			return _base_rotation_radians + deg_to_rad(from_rotation_degrees)
		TransformReference.SELF:
			return _self_rotation_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_rotation(_from_ref, animated)
			return _base_rotation_radians
	return _base_rotation_radians


func _resolve_to_rotation(animated: Node2D) -> float:
	match to_reference:
		TransformReference.CUSTOM:
			return _base_rotation_radians + deg_to_rad(to_rotation_degrees)
		TransformReference.SELF:
			return _self_rotation_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_rotation(_to_ref, animated)
			return _base_rotation_radians
	return _base_rotation_radians


func _get_ref_local_rotation(ref: Node2D, animated: Node2D) -> float:
	var parent := animated.get_parent()
	if parent is Node2D:
		return ref.global_rotation - (parent as Node2D).global_rotation
	return ref.global_rotation


# =============================================================================
# SCALE EFFECT
# =============================================================================

## Apply scale with pivot compensation:
##   pos += pivot * (ONE - scale_ratio)
func _apply_scale_effect(progress: float, target: Node2D) -> void:
	var from_value := _resolve_from_scale(target)
	var to_value := _resolve_to_scale(target)
	var desired_absolute := from_value.lerp(to_value, progress)

	var desired_offset := desired_absolute - _base_scale
	var scale_delta := desired_offset - _my_scale_contribution

	# Pivot compensation
	if _pivot_point != Vector2.ZERO:
		var scale_ratio := desired_absolute / _base_scale
		var desired_pos_offset := _pivot_point * (Vector2.ONE - scale_ratio)
		var pos_delta := desired_pos_offset - _my_position_contribution
		target.position += pos_delta
		_my_position_contribution = desired_pos_offset

	target.scale += scale_delta
	_my_scale_contribution = desired_offset


func _resolve_from_scale(animated: Node2D) -> Vector2:
	match from_reference:
		TransformReference.CUSTOM:
			return from_scale
		TransformReference.SELF:
			return _self_scale_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_scale(_from_ref, animated)
			return _base_scale
	return _base_scale


func _resolve_to_scale(animated: Node2D) -> Vector2:
	match to_reference:
		TransformReference.CUSTOM:
			return to_scale
		TransformReference.SELF:
			return _self_scale_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_scale(_to_ref, animated)
			return _base_scale
	return _base_scale


func _get_ref_local_scale(ref: Node2D, animated: Node2D) -> Vector2:
	var ref_global_scale := ref.global_scale
	var parent_scale := Vector2.ONE
	var parent := animated.get_parent()
	if parent is Node2D:
		parent_scale = (parent as Node2D).global_scale
	return ref_global_scale / parent_scale


# =============================================================================
# FROM/TO REFERENCE RESOLUTION
# =============================================================================

func _resolve_from_to_refs() -> void:
	_from_ref = null
	_to_ref = null
	if from_reference == TransformReference.TARGET_NODE:
		_from_ref = _resolve_node_path_to_node2d(from_target_node, "from_target_node")
	if to_reference == TransformReference.TARGET_NODE:
		_to_ref = _resolve_node_path_to_node2d(to_target_node, "to_target_node")


# =============================================================================
# SELF SNAPSHOT CAPTURE
# =============================================================================

func _capture_self_position_snapshot(target: Node) -> void:
	if _has_self_position_snapshot:
		return
	if capture_at == CaptureAt.IN_EDITOR:
		_self_position_snapshot = _editor_cached_position
	else:
		var n2d := target as Node2D
		_self_position_snapshot = n2d.position if n2d else Vector2.ZERO
	_has_self_position_snapshot = true
	if debug_enabled:
		print("[Transform2D] Self position snapshot: %s (mode=%s)" % [
			_self_position_snapshot, CaptureAt.keys()[capture_at]])


func _capture_self_rotation_snapshot(target: Node) -> void:
	if _has_self_rotation_snapshot:
		return
	if capture_at == CaptureAt.IN_EDITOR:
		_self_rotation_snapshot = _editor_cached_rotation
	else:
		var n2d := target as Node2D
		_self_rotation_snapshot = n2d.rotation if n2d else 0.0
	_has_self_rotation_snapshot = true
	if debug_enabled:
		print("[Transform2D] Self rotation snapshot: %s rad (mode=%s)" % [
			_self_rotation_snapshot, CaptureAt.keys()[capture_at]])


func _capture_self_scale_snapshot(target: Node) -> void:
	if _has_self_scale_snapshot:
		return
	if capture_at == CaptureAt.IN_EDITOR:
		_self_scale_snapshot = _editor_cached_scale
	else:
		var n2d := target as Node2D
		_self_scale_snapshot = n2d.scale if n2d else Vector2.ONE
	_has_self_scale_snapshot = true
	if debug_enabled:
		print("[Transform2D] Self scale snapshot: %s (mode=%s)" % [
			_self_scale_snapshot, CaptureAt.keys()[capture_at]])


# =============================================================================
# EDITOR CACHE (IN_EDITOR capture mode)
# =============================================================================

func _update_editor_cache(target: Node = null) -> void:
	if not Engine.is_editor_hint():
		return
	if capture_at != CaptureAt.IN_EDITOR:
		return
	var uses_self := (from_reference == TransformReference.SELF or to_reference == TransformReference.SELF)
	if not uses_self:
		return

	var n2d := target as Node2D
	if n2d == null:
		return

	_editor_cached_position = n2d.position
	_editor_cached_rotation = n2d.rotation
	_editor_cached_scale = n2d.scale

	if debug_enabled:
		print("[Transform2D] Editor cache updated: pos=%s, rot=%.1f°, scale=%s" % [
			_editor_cached_position, rad_to_deg(_editor_cached_rotation), _editor_cached_scale])


# =============================================================================
# BASE CAPTURE
# =============================================================================

func _capture_base(target: Node) -> void:
	if _has_base:
		return
	var n2d := target as Node2D
	if n2d == null:
		_has_base = true
		return
	_base_position = n2d.position
	_base_rotation_radians = n2d.rotation
	_base_scale = n2d.scale
	_has_base = true
	if debug_enabled:
		print("[Transform2D] Base captured: pos=%s, rot=%.1f°, scale=%s" % [
			_base_position, rad_to_deg(_base_rotation_radians), _base_scale])


# =============================================================================
# PIVOT RESOLUTION (ROTATION and SCALE)
# =============================================================================

## Resolve the pivot point based on pivot_mode. Node2D has no native
## pivot_offset, so AUTO_CENTER infers visual bounds from child nodes.
func _resolve_pivot(target: Node) -> void:
	var n2d := target as Node2D
	match pivot_mode:
		PivotMode.AUTO_CENTER:
			if n2d:
				var bounds := _infer_node2d_local_bounds(n2d)
				if bounds.size == Vector2.ZERO:
					bounds = _infer_node2d_bounds_recursive(n2d)
				if bounds.size != Vector2.ZERO:
					_pivot_point = bounds.get_center()
				else:
					_pivot_point = Vector2.ZERO
				if debug_enabled:
					print("[Transform2D] Auto-center pivot: bounds=%s, center=%s" % [bounds, _pivot_point])
			else:
				_pivot_point = Vector2.ZERO
		PivotMode.INHERIT:
			_pivot_point = Vector2.ZERO
		PivotMode.CUSTOM:
			_pivot_point = custom_pivot


# =============================================================================
# SIZE INFERENCE
# =============================================================================

func _infer_parent_size(target: Node) -> Vector2:
	if target == null:
		return Vector2.ZERO
	var parent := target.get_parent()
	if parent is Control:
		return (parent as Control).size
	if parent is Node2D:
		return _infer_node2d_size(parent as Node2D)
	return Vector2.ZERO


func _infer_node2d_size(node: Node2D) -> Vector2:
	if node == null:
		return Vector2.ZERO

	if node is Sprite2D:
		var spr := node as Sprite2D
		var tex := spr.texture
		if tex != null:
			var size := tex.get_size()
			if spr.region_enabled:
				size = spr.region_rect.size
			var sc := spr.scale
			return Vector2(absf(sc.x) * size.x, absf(sc.y) * size.y)

	if node is AnimatedSprite2D:
		var anim := node as AnimatedSprite2D
		if anim.sprite_frames != null:
			var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
			if tex != null:
				var size := tex.get_size()
				var sc := anim.scale
				return Vector2(absf(sc.x) * size.x, absf(sc.y) * size.y)

	if node is CollisionShape2D:
		var col := node as CollisionShape2D
		if col.shape != null:
			var shape := col.shape
			if shape is RectangleShape2D:
				return (shape as RectangleShape2D).size
			if shape is CircleShape2D:
				var r := (shape as CircleShape2D).radius
				return Vector2(r * 2.0, r * 2.0)
			if shape is CapsuleShape2D:
				var cap := shape as CapsuleShape2D
				return Vector2(cap.radius * 2.0, cap.height + cap.radius * 2.0)

	if node is Polygon2D:
		var poly := node as Polygon2D
		if poly.polygon.size() > 0:
			var min_x := poly.polygon[0].x
			var max_x := poly.polygon[0].x
			var min_y := poly.polygon[0].y
			var max_y := poly.polygon[0].y
			for p in poly.polygon:
				min_x = minf(min_x, p.x)
				max_x = maxf(max_x, p.x)
				min_y = minf(min_y, p.y)
				max_y = maxf(max_y, p.y)
			return Vector2(max_x - min_x, max_y - min_y)

	# Container fallback
	var bounds := _infer_node2d_bounds_recursive(node)
	if bounds.size != Vector2.ZERO:
		return bounds.size

	if debug_enabled:
		push_warning("[Transform2D] Cannot infer Node2D size on '%s' (%s)" % [node.name, node.get_class()])
	return Vector2.ZERO


func _infer_node2d_bounds_recursive(root: Node2D) -> Rect2:
	var has_any: bool = false
	var combined := Rect2(Vector2.ZERO, Vector2.ZERO)

	for child in root.get_children():
		if not (child is Node2D):
			continue
		var child_n2d := child as Node2D
		var child_local_bounds := _infer_node2d_local_bounds(child_n2d)
		if child_local_bounds.size != Vector2.ZERO:
			child_local_bounds.position += child_n2d.position
			if not has_any:
				has_any = true
				combined = child_local_bounds
			else:
				combined = combined.merge(child_local_bounds)

		var grandchild_bounds := _infer_node2d_bounds_recursive(child_n2d)
		if grandchild_bounds.size != Vector2.ZERO:
			grandchild_bounds.position += child_n2d.position
			if not has_any:
				has_any = true
				combined = grandchild_bounds
			else:
				combined = combined.merge(grandchild_bounds)

	if not has_any:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return combined


func _infer_node2d_local_bounds(node: Node2D) -> Rect2:
	var size := Vector2.ZERO

	if node is Sprite2D:
		var spr := node as Sprite2D
		var tex := spr.texture
		if tex != null:
			size = tex.get_size()
			if spr.region_enabled:
				size = spr.region_rect.size
			var sc := spr.scale
			size = Vector2(absf(sc.x) * size.x, absf(sc.y) * size.y)

	elif node is AnimatedSprite2D:
		var anim := node as AnimatedSprite2D
		if anim.sprite_frames != null:
			var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
			if tex != null:
				size = tex.get_size()
				var sc := anim.scale
				size = Vector2(absf(sc.x) * size.x, absf(sc.y) * size.y)

	elif node is CollisionShape2D:
		var col := node as CollisionShape2D
		if col.shape != null:
			var shape := col.shape
			if shape is RectangleShape2D:
				size = (shape as RectangleShape2D).size
			elif shape is CircleShape2D:
				var r := (shape as CircleShape2D).radius
				size = Vector2(r * 2.0, r * 2.0)
			elif shape is CapsuleShape2D:
				var cap := shape as CapsuleShape2D
				size = Vector2(cap.radius * 2.0, cap.height + cap.radius * 2.0)

	elif node is Polygon2D:
		var poly := node as Polygon2D
		if poly.polygon.size() > 0:
			var min_x := poly.polygon[0].x
			var max_x := poly.polygon[0].x
			var min_y := poly.polygon[0].y
			var max_y := poly.polygon[0].y
			for p in poly.polygon:
				min_x = minf(min_x, p.x)
				max_x = maxf(max_x, p.x)
				min_y = minf(min_y, p.y)
				max_y = maxf(max_y, p.y)
			size = Vector2(max_x - min_x, max_y - min_y)

	if size == Vector2.ZERO:
		return Rect2(Vector2.ZERO, Vector2.ZERO)

	return Rect2(-size * 0.5, size)


# =============================================================================
# HELPERS
# =============================================================================

func _resolve_node_path_to_node2d(path: NodePath, path_name: String) -> Node2D:
	if path.is_empty():
		return null
	if _host_node == null or not is_instance_valid(_host_node):
		if debug_enabled:
			push_warning("[Transform2D] Cannot resolve %s — no host node" % path_name)
		return null
	var resolved := _host_node.get_node_or_null(path)
	if resolved == null:
		if debug_enabled:
			push_warning("[Transform2D] %s path '%s' could not be resolved" % [path_name, path])
		return null
	if not (resolved is Node2D):
		if debug_enabled:
			push_warning("[Transform2D] %s '%s' is not a Node2D (is %s)" % [path_name, resolved.name, resolved.get_class()])
		return null
	return resolved as Node2D
