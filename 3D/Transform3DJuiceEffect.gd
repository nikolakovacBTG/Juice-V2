## Transform3DJuiceEffect.gd
## ============================================================================
## WHAT: Animate position, rotation, or scale of a Node3D with tween-based easing.
## WHY: Replaces 3 separate scripts with one unified component. Select a
##      transform_target (Position, Rotation, or Scale) and configure a From/To
##      animation using CUSTOM values, SELF snapshots, or live TARGET_NODE refs.
##      Rotation uses quaternion slerp for smooth interpolation (no gimbal lock).
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Handle Control or Node2D targets — use TransformControl/2DJuiceEffect.
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
## Rotation uses quaternion slerp for correct interpolation.
##
## PIVOT:
## - ROTATION: Uses rotation_pivot_offset (Vector3) from node origin. The pivot
##   point is fixed in parent space at animation start. Useful for doors, levers, lids.
## - SCALE: Uses scale_pivot_mode (AUTO_CENTER/INHERIT/CUSTOM) with position
##   compensation: pos += pivot * (ONE - scale_ratio).
##
## CONDITIONAL EXPORTS:
## Uses _get_property_list() to conditionally show/hide parameters based on
## transform_target and from/to reference selections.
## ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name Transform3DJuiceEffect
extends Juice3DEffectBase


# =============================================================================
# ENUMS
# =============================================================================

## Which transform property to animate
enum TransformTarget {
	POSITION,  ## Animate Node3D.position with offset + unit
	ROTATION,  ## Animate Node3D rotation (3-axis, Quaternion slerp)
	SCALE      ## Animate Node3D.scale with offset
}

## Determines how the pivot point is calculated for scaling
enum PivotMode {
	AUTO_CENTER,  ## Infer center from AABB and compensate position
	INHERIT,      ## Scale from node origin (no compensation)
	CUSTOM        ## Scale from custom_pivot (local-space world units)
}

## Reference type for From/To axes (shared by Position, Rotation, and Scale)
enum TransformReference {
	CUSTOM,       ## Explicit value supplied by the user
	SELF,         ## This object's current value (captured at capture_at moment)
	TARGET_NODE   ## Another object's value (tracked live every frame)
}

## How to interpret custom position values (3D — no viewport fraction)
enum PositionIn3D {
	WORLD_UNITS,      ## Position in world units
	FRACTION_OWN,     ## Position in fraction of object's own AABB
	FRACTION_PARENT   ## Position in fraction of parent's AABB
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

var transform_target: int = TransformTarget.POSITION:
	set(value):
		transform_target = value
		notify_property_list_changed()

func _init() -> void:
	_subclass_owns_effect_group = true


# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — they are shown/hidden via _get_property_list()
# =============================================================================

# --- POSITION (From/To model) ---
var from_position: Vector3 = Vector3.ZERO
var from_position_in: int = PositionIn3D.FRACTION_OWN
var to_position: Vector3 = Vector3.ZERO
var to_position_in: int = PositionIn3D.FRACTION_OWN

# --- ROTATION (From/To model) ---
var from_rotation: Vector3 = Vector3.ZERO
var to_rotation: Vector3 = Vector3(0, 90, 0)
var rotation_unit: int = RotationUnit.DEGREES
var rotation_pivot_offset: Vector3 = Vector3.ZERO

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
			_editor_cached_position = Vector3.ZERO
			_editor_cached_rotation = Vector3.ZERO
			_editor_cached_scale = Vector3.ONE
		elif Engine.is_editor_hint():
			_update_editor_cache()
		notify_property_list_changed()

# --- SCALE (From/To model) ---
var from_scale: Vector3 = Vector3.ZERO
var to_scale: Vector3 = Vector3.ONE

# --- SCALE PIVOT ---
var scale_pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		scale_pivot_mode = value
		notify_property_list_changed()
var scale_custom_pivot: Vector3 = Vector3.ZERO

# --- EDITOR CACHE (serialized only when capture_at == IN_EDITOR) ---
var _editor_cached_position: Vector3 = Vector3.ZERO
var _editor_cached_rotation: Vector3 = Vector3.ZERO
var _editor_cached_scale: Vector3 = Vector3.ONE


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# --- Effect group: subclass selector + base effect properties ---
	props.append({"name": "Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "transform_target", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Position,Rotation,Scale",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append_array(_get_effect_base_properties())

	match transform_target:
		TransformTarget.POSITION:
			props.append_array(_get_position_from_to_properties())
		TransformTarget.ROTATION:
			props.append_array(_get_rotation_from_to_properties())
		TransformTarget.SCALE:
			props.append_array(_get_scale_from_to_properties())
			props.append_array(_get_scale_pivot_properties())

	var uses_self := (from_reference == TransformReference.SELF or to_reference == TransformReference.SELF)
	if uses_self and capture_at == CaptureAt.IN_EDITOR:
		props.append({"name": "_editor_cached_position", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_STORAGE})
		props.append({"name": "_editor_cached_rotation", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_STORAGE})
		props.append({"name": "_editor_cached_scale", "type": TYPE_VECTOR3,
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
			"hint_string": "World Units,Fraction Own,Fraction Parent",
		})
		pos_props.append({
			"name": "from_position", "type": TYPE_VECTOR3,
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
			"hint_string": "Node3D",
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
			"hint_string": "World Units,Fraction Own,Fraction Parent",
		})
		pos_props.append({
			"name": "to_position", "type": TYPE_VECTOR3,
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
			"hint_string": "Node3D",
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
			"name": "from_rotation", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		rot_props.append({
			"name": "rotation_unit", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Degrees,Radians",
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
			"hint_string": "Node3D",
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
			"name": "to_rotation", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		# Only show rotation_unit once (shared between From/To custom)
		if from_reference != TransformReference.CUSTOM:
			rot_props.append({
				"name": "rotation_unit", "type": TYPE_INT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Degrees,Radians",
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
			"hint_string": "Node3D",
		})

	# Rotation pivot (always shown for rotation)
	rot_props.append({"name": "Pivot", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	rot_props.append({
		"name": "rotation_pivot_offset", "type": TYPE_VECTOR3,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_NONE,
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
			"name": "from_scale", "type": TYPE_VECTOR3,
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
			"hint_string": "Node3D",
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
			"name": "to_scale", "type": TYPE_VECTOR3,
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
			"hint_string": "Node3D",
		})
	return scale_props


func _get_scale_pivot_properties() -> Array[Dictionary]:
	var pivot_props: Array[Dictionary] = [{
		"name": "scale_pivot_mode", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Auto Center,Inherit,Custom",
	}]
	if scale_pivot_mode == PivotMode.CUSTOM:
		pivot_props.append({
			"name": "scale_custom_pivot", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE,
		})
	return pivot_props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"transform_target": transform_target = value; return true
		&"from_position": from_position = value; return true
		&"from_position_in": from_position_in = value; return true
		&"to_position": to_position = value; return true
		&"to_position_in": to_position_in = value; return true
		&"from_rotation": from_rotation = value; return true
		&"to_rotation": to_rotation = value; return true
		&"rotation_unit": rotation_unit = value; return true
		&"rotation_pivot_offset": rotation_pivot_offset = value; return true
		&"from_reference": from_reference = value; return true
		&"to_reference": to_reference = value; return true
		&"from_target_node": from_target_node = value; return true
		&"to_target_node": to_target_node = value; return true
		&"capture_at": capture_at = value; return true
		&"from_scale": from_scale = value; return true
		&"to_scale": to_scale = value; return true
		&"scale_pivot_mode": scale_pivot_mode = value; return true
		&"scale_custom_pivot": scale_custom_pivot = value; return true
		&"_editor_cached_position": _editor_cached_position = value; return true
		&"_editor_cached_rotation": _editor_cached_rotation = value; return true
		&"_editor_cached_scale": _editor_cached_scale = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"transform_target": return transform_target
		&"from_position": return from_position
		&"from_position_in": return from_position_in
		&"to_position": return to_position
		&"to_position_in": return to_position_in
		&"from_rotation": return from_rotation
		&"to_rotation": return to_rotation
		&"rotation_unit": return rotation_unit
		&"rotation_pivot_offset": return rotation_pivot_offset
		&"from_reference": return from_reference
		&"to_reference": return to_reference
		&"from_target_node": return from_target_node
		&"to_target_node": return to_target_node
		&"capture_at": return capture_at
		&"from_scale": return from_scale
		&"to_scale": return to_scale
		&"scale_pivot_mode": return scale_pivot_mode
		&"scale_custom_pivot": return scale_custom_pivot
		&"_editor_cached_position": return _editor_cached_position
		&"_editor_cached_rotation": return _editor_cached_rotation
		&"_editor_cached_scale": return _editor_cached_scale
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _base_position: Vector3 = Vector3.ZERO
var _base_transform: Transform3D = Transform3D.IDENTITY
var _base_euler: Vector3 = Vector3.ZERO
var _base_quat: Quaternion = Quaternion.IDENTITY
var _base_scale: Vector3 = Vector3.ONE
var _has_base: bool = false

# Fixed pivot position in parent space (for rotation, computed once at start)
var _fixed_pivot_parent: Vector3 = Vector3.ZERO

# Resolved pivot point for scale (local space)
var _scale_pivot_point: Vector3 = Vector3.ZERO
var _scale_pivot_resolved: bool = false

# Delta-first contribution tracking
var _my_position_contribution: Vector3 = Vector3.ZERO
var _my_rotation_contribution: Vector3 = Vector3.ZERO
var _my_scale_contribution: Vector3 = Vector3.ZERO

# External-move detection
var _last_written_position: Vector3 = Vector3.INF

# Resolved From/To target node references
var _from_ref: Node3D = null
var _to_ref: Node3D = null

# Self snapshots
var _self_position_snapshot: Vector3 = Vector3.ZERO
var _has_self_position_snapshot: bool = false
var _self_rotation_snapshot: Vector3 = Vector3.ZERO
var _has_self_rotation_snapshot: bool = false
var _self_scale_snapshot: Vector3 = Vector3.ONE
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

	# Resolve scale pivot if needed
	if transform_target == TransformTarget.SCALE and not _scale_pivot_resolved:
		_resolve_scale_pivot(target)
		_scale_pivot_resolved = true

	if debug_enabled:
		print("[Transform3D] Start: %s" % TransformTarget.keys()[transform_target])


func _apply_effect(progress: float, target: Node) -> void:
	var n3d := target as Node3D
	if n3d == null:
		return

	match transform_target:
		TransformTarget.POSITION:
			_apply_position_effect(progress, n3d)
		TransformTarget.ROTATION:
			_apply_rotation_effect(progress, n3d)
		TransformTarget.SCALE:
			_apply_scale_effect(progress, n3d)


func _restore_to_natural(target: Node) -> void:
	var n3d := target as Node3D
	if n3d == null:
		return
	match transform_target:
		TransformTarget.POSITION:
			n3d.position -= _my_position_contribution
			_my_position_contribution = Vector3.ZERO
			_last_written_position = n3d.position
		TransformTarget.ROTATION:
			n3d.rotation -= _my_rotation_contribution
			_my_rotation_contribution = Vector3.ZERO
			if rotation_pivot_offset != Vector3.ZERO:
				n3d.position -= _my_position_contribution
				_my_position_contribution = Vector3.ZERO
				_last_written_position = n3d.position
		TransformTarget.SCALE:
			n3d.scale -= _my_scale_contribution
			_my_scale_contribution = Vector3.ZERO
			if _scale_pivot_point != Vector3.ZERO:
				n3d.position -= _my_position_contribution
				_my_position_contribution = Vector3.ZERO
				_last_written_position = n3d.position


func _temporarily_undo_visual(target: Node) -> void:
	var n3d := target as Node3D
	if n3d == null:
		return
	match transform_target:
		TransformTarget.POSITION:
			n3d.position -= _my_position_contribution
			_last_written_position = n3d.position
		TransformTarget.ROTATION:
			n3d.rotation -= _my_rotation_contribution
			if rotation_pivot_offset != Vector3.ZERO:
				n3d.position -= _my_position_contribution
				_last_written_position = n3d.position
		TransformTarget.SCALE:
			n3d.scale -= _my_scale_contribution
			if _scale_pivot_point != Vector3.ZERO:
				n3d.position -= _my_position_contribution
				_last_written_position = n3d.position


func _temporarily_reapply_visual(target: Node) -> void:
	var n3d := target as Node3D
	if n3d == null:
		return
	match transform_target:
		TransformTarget.POSITION:
			n3d.position += _my_position_contribution
			_last_written_position = n3d.position
		TransformTarget.ROTATION:
			n3d.rotation += _my_rotation_contribution
			if rotation_pivot_offset != Vector3.ZERO:
				n3d.position += _my_position_contribution
				_last_written_position = n3d.position
		TransformTarget.SCALE:
			n3d.scale += _my_scale_contribution
			if _scale_pivot_point != Vector3.ZERO:
				n3d.position += _my_position_contribution
				_last_written_position = n3d.position


func _invalidate_base_cache() -> void:
	_has_base = false
	_scale_pivot_resolved = false
	_from_ref = null
	_to_ref = null
	_has_self_position_snapshot = false
	_has_self_rotation_snapshot = false
	_has_self_scale_snapshot = false
	_my_position_contribution = Vector3.ZERO
	_my_rotation_contribution = Vector3.ZERO
	_my_scale_contribution = Vector3.ZERO
	_last_written_position = Vector3.INF


func _get_interrupt_identity() -> Variant:
	return [get_script(), transform_target]


# =============================================================================
# POSITION EFFECT
# =============================================================================

func _apply_position_effect(progress: float, n3d: Node3D) -> void:
	if _last_written_position != Vector3.INF:
		if not n3d.position.is_equal_approx(_last_written_position):
			_base_position = n3d.position
			_my_position_contribution = Vector3.ZERO

	var from_value := _resolve_from_position(n3d)
	var to_value := _resolve_to_position(n3d)
	var desired_absolute := from_value.lerp(to_value, progress)

	var desired_offset := desired_absolute - _base_position
	var delta := desired_offset - _my_position_contribution
	n3d.position += delta
	_my_position_contribution = desired_offset
	_last_written_position = n3d.position


func _resolve_from_position(animated: Node3D) -> Vector3:
	match from_reference:
		TransformReference.CUSTOM:
			return _base_position + _convert_to_world_units(from_position, from_position_in, animated)
		TransformReference.SELF:
			return _self_position_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_position(_from_ref, animated)
			return _base_position
	return _base_position


func _resolve_to_position(animated: Node3D) -> Vector3:
	match to_reference:
		TransformReference.CUSTOM:
			return _base_position + _convert_to_world_units(to_position, to_position_in, animated)
		TransformReference.SELF:
			return _self_position_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_position(_to_ref, animated)
			return _base_position
	return _base_position


func _convert_to_world_units(pos: Vector3, position_in: int, target: Node3D) -> Vector3:
	match position_in:
		PositionIn3D.WORLD_UNITS:
			return pos
		PositionIn3D.FRACTION_OWN:
			var size := _infer_node3d_size(target)
			return Vector3(pos.x * size.x, pos.y * size.y, pos.z * size.z)
		PositionIn3D.FRACTION_PARENT:
			var size := _infer_parent_size(target)
			return Vector3(pos.x * size.x, pos.y * size.y, pos.z * size.z)
	return pos


func _get_ref_local_position(ref: Node3D, animated: Node3D) -> Vector3:
	var parent := animated.get_parent()
	if parent is Node3D:
		return (parent as Node3D).global_transform.affine_inverse() * ref.global_position
	return ref.global_position


# =============================================================================
# ROTATION EFFECT (Quaternion slerp + pivot)
# =============================================================================

## Apply rotation using Quaternion slerp with pivot compensation.
## The pivot point is fixed in parent space at animation start.
func _apply_rotation_effect(progress: float, n3d: Node3D) -> void:
	var from_quat := _resolve_from_rotation_quat(n3d)
	var to_quat := _resolve_to_rotation_quat(n3d)
	var current_quat := from_quat.slerp(to_quat, progress)

	# Convert back to euler for delta-first application
	var desired_euler := Basis(current_quat).get_euler()
	var desired_offset := desired_euler - _base_euler
	var rot_delta := desired_offset - _my_rotation_contribution

	# Pivot compensation
	if rotation_pivot_offset != Vector3.ZERO:
		var new_basis := Basis(current_quat)
		var desired_pos := _fixed_pivot_parent - new_basis * rotation_pivot_offset
		var desired_pos_offset := desired_pos - _base_position
		var pos_delta := desired_pos_offset - _my_position_contribution
		n3d.position += pos_delta
		_my_position_contribution = desired_pos_offset

	n3d.rotation += rot_delta
	_my_rotation_contribution = desired_offset


func _resolve_from_rotation_quat(animated: Node3D) -> Quaternion:
	match from_reference:
		TransformReference.CUSTOM:
			var offset_rad := _rotation_to_radians(from_rotation)
			return _base_quat * Quaternion.from_euler(offset_rad)
		TransformReference.SELF:
			return Quaternion.from_euler(_self_rotation_snapshot)
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_rotation_quat(_from_ref, animated)
			return _base_quat
	return _base_quat


func _resolve_to_rotation_quat(animated: Node3D) -> Quaternion:
	match to_reference:
		TransformReference.CUSTOM:
			var offset_rad := _rotation_to_radians(to_rotation)
			return _base_quat * Quaternion.from_euler(offset_rad)
		TransformReference.SELF:
			return Quaternion.from_euler(_self_rotation_snapshot)
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_rotation_quat(_to_ref, animated)
			return _base_quat
	return _base_quat


func _rotation_to_radians(rot: Vector3) -> Vector3:
	if rotation_unit == RotationUnit.DEGREES:
		return Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))
	return rot


func _get_ref_local_rotation_quat(ref: Node3D, animated: Node3D) -> Quaternion:
	var ref_global_basis := ref.global_transform.basis.orthonormalized()
	var parent_basis := Basis.IDENTITY
	if animated.get_parent() is Node3D:
		parent_basis = (animated.get_parent() as Node3D).global_transform.basis.orthonormalized()
	var local_basis := parent_basis.inverse() * ref_global_basis
	return Quaternion(local_basis)


# =============================================================================
# SCALE EFFECT (with pivot compensation)
# =============================================================================

func _apply_scale_effect(progress: float, n3d: Node3D) -> void:
	var from_value := _resolve_from_scale(n3d)
	var to_value := _resolve_to_scale(n3d)
	var desired_absolute := from_value.lerp(to_value, progress)

	var desired_offset := desired_absolute - _base_scale
	var scale_delta := desired_offset - _my_scale_contribution

	# Pivot compensation
	if _scale_pivot_point != Vector3.ZERO:
		var scale_ratio := desired_absolute / _base_scale
		var desired_pos_offset := _scale_pivot_point * (Vector3.ONE - scale_ratio)
		var pos_delta := desired_pos_offset - _my_position_contribution
		n3d.position += pos_delta
		_my_position_contribution = desired_pos_offset

	n3d.scale += scale_delta
	_my_scale_contribution = desired_offset


func _resolve_from_scale(n3d: Node3D) -> Vector3:
	match from_reference:
		TransformReference.CUSTOM:
			return from_scale
		TransformReference.SELF:
			return _self_scale_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_scale(_from_ref, n3d)
			return _base_scale
	return _base_scale


func _resolve_to_scale(n3d: Node3D) -> Vector3:
	match to_reference:
		TransformReference.CUSTOM:
			return to_scale
		TransformReference.SELF:
			return _self_scale_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_scale(_to_ref, n3d)
			return _base_scale
	return _base_scale


func _get_ref_local_scale(ref: Node3D, animated: Node3D) -> Vector3:
	var ref_global_scale := ref.global_transform.basis.get_scale()
	var parent_scale := Vector3.ONE
	var parent := animated.get_parent()
	if parent is Node3D:
		parent_scale = (parent as Node3D).global_transform.basis.get_scale()
	return ref_global_scale / parent_scale


# =============================================================================
# FROM/TO REFERENCE RESOLUTION
# =============================================================================

func _resolve_from_to_refs() -> void:
	_from_ref = null
	_to_ref = null
	if from_reference == TransformReference.TARGET_NODE:
		_from_ref = _resolve_node_path_to_node3d(from_target_node, "from_target_node")
	if to_reference == TransformReference.TARGET_NODE:
		_to_ref = _resolve_node_path_to_node3d(to_target_node, "to_target_node")


# =============================================================================
# SELF SNAPSHOT CAPTURE
# =============================================================================

func _capture_self_position_snapshot(target: Node) -> void:
	if _has_self_position_snapshot:
		return
	if capture_at == CaptureAt.IN_EDITOR:
		_self_position_snapshot = _editor_cached_position
	else:
		var n3d := target as Node3D
		_self_position_snapshot = n3d.position if n3d else Vector3.ZERO
	_has_self_position_snapshot = true
	if debug_enabled:
		print("[Transform3D] Self position snapshot: %s (mode=%s)" % [
			_self_position_snapshot, CaptureAt.keys()[capture_at]])


func _capture_self_rotation_snapshot(target: Node) -> void:
	if _has_self_rotation_snapshot:
		return
	if capture_at == CaptureAt.IN_EDITOR:
		_self_rotation_snapshot = _editor_cached_rotation
	else:
		var n3d := target as Node3D
		_self_rotation_snapshot = n3d.rotation if n3d else Vector3.ZERO
	_has_self_rotation_snapshot = true
	if debug_enabled:
		print("[Transform3D] Self rotation snapshot: %s (mode=%s)" % [
			_self_rotation_snapshot, CaptureAt.keys()[capture_at]])


func _capture_self_scale_snapshot(target: Node) -> void:
	if _has_self_scale_snapshot:
		return
	if capture_at == CaptureAt.IN_EDITOR:
		_self_scale_snapshot = _editor_cached_scale
	else:
		var n3d := target as Node3D
		_self_scale_snapshot = n3d.scale if n3d else Vector3.ONE
	_has_self_scale_snapshot = true
	if debug_enabled:
		print("[Transform3D] Self scale snapshot: %s (mode=%s)" % [
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

	var n3d := target as Node3D
	if n3d == null:
		return

	_editor_cached_position = n3d.position
	_editor_cached_rotation = n3d.rotation
	_editor_cached_scale = n3d.scale

	if debug_enabled:
		print("[Transform3D] Editor cache updated: pos=%s, rot=%s, scale=%s" % [
			_editor_cached_position, _editor_cached_rotation, _editor_cached_scale])


# =============================================================================
# BASE CAPTURE
# =============================================================================

func _capture_base(target: Node) -> void:
	if _has_base:
		return
	var n3d := target as Node3D
	if n3d == null:
		_base_transform = Transform3D.IDENTITY
		_has_base = true
		return

	_base_position = n3d.position
	_base_transform = n3d.transform
	var ortho_basis := _base_transform.basis.orthonormalized()
	_base_euler = ortho_basis.get_euler()
	_base_quat = Quaternion(ortho_basis)
	_base_scale = n3d.scale

	# Pre-compute the fixed pivot position in parent space for rotation
	_fixed_pivot_parent = _base_transform.origin + _base_transform.basis * rotation_pivot_offset

	_has_base = true

	if debug_enabled:
		print("[Transform3D] Base captured: pos=%s, scale=%s" % [_base_position, _base_scale])


# =============================================================================
# SCALE PIVOT RESOLUTION
# =============================================================================

func _resolve_scale_pivot(target: Node) -> void:
	var n3d := target as Node3D
	match scale_pivot_mode:
		PivotMode.AUTO_CENTER:
			if n3d:
				var bounds := _infer_node3d_local_bounds(n3d)
				if bounds.size == Vector3.ZERO:
					bounds = _infer_node3d_bounds_recursive(n3d)
				if bounds.size != Vector3.ZERO:
					_scale_pivot_point = bounds.get_center()
				else:
					_scale_pivot_point = Vector3.ZERO
				if debug_enabled:
					print("[Transform3D] Auto-center scale pivot: bounds=%s, center=%s" % [bounds, _scale_pivot_point])
			else:
				_scale_pivot_point = Vector3.ZERO
		PivotMode.INHERIT:
			_scale_pivot_point = Vector3.ZERO
		PivotMode.CUSTOM:
			_scale_pivot_point = scale_custom_pivot


# =============================================================================
# SIZE INFERENCE
# =============================================================================

func _infer_parent_size(target: Node) -> Vector3:
	if target == null:
		return Vector3.ZERO
	var parent := target.get_parent()
	if parent is Node3D:
		return _infer_node3d_size(parent as Node3D)
	return Vector3.ZERO


func _infer_node3d_size(node: Node3D) -> Vector3:
	if node == null:
		return Vector3.ZERO

	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var aabb := mi.mesh.get_aabb()
			var sc := mi.global_transform.basis.get_scale()
			return Vector3(absf(sc.x) * aabb.size.x, absf(sc.y) * aabb.size.y, absf(sc.z) * aabb.size.z)

	if node is CollisionShape3D:
		var col := node as CollisionShape3D
		if col.shape != null:
			var shape := col.shape
			if shape is BoxShape3D:
				return (shape as BoxShape3D).size
			if shape is SphereShape3D:
				var r := (shape as SphereShape3D).radius
				return Vector3(r * 2.0, r * 2.0, r * 2.0)
			if shape is CapsuleShape3D:
				var cap := shape as CapsuleShape3D
				return Vector3(cap.radius * 2.0, cap.height + cap.radius * 2.0, cap.radius * 2.0)

	if node.has_method("get_aabb"):
		var aabb_var: Variant = node.call("get_aabb")
		if aabb_var is AABB:
			var aabb := aabb_var as AABB
			var sc := node.global_transform.basis.get_scale()
			return Vector3(absf(sc.x) * aabb.size.x, absf(sc.y) * aabb.size.y, absf(sc.z) * aabb.size.z)

	# Container fallback
	var bounds := _infer_node3d_bounds_recursive(node)
	if bounds.size != Vector3.ZERO:
		return bounds.size

	if debug_enabled:
		push_warning("[Transform3D] Cannot infer Node3D size on '%s' (%s)" % [node.name, node.get_class()])
	return Vector3.ZERO


func _infer_node3d_bounds_recursive(root: Node3D) -> AABB:
	var has_any: bool = false
	var combined := AABB(Vector3.ZERO, Vector3.ZERO)

	for child in root.get_children():
		if not (child is Node3D):
			continue
		var child_n3d := child as Node3D
		var child_local := _infer_node3d_local_bounds(child_n3d)
		if child_local.size != Vector3.ZERO:
			child_local.position += child_n3d.position
			if not has_any:
				has_any = true
				combined = child_local
			else:
				combined = combined.merge(child_local)

		var grandchild_bounds := _infer_node3d_bounds_recursive(child_n3d)
		if grandchild_bounds.size != Vector3.ZERO:
			grandchild_bounds.position += child_n3d.position
			if not has_any:
				has_any = true
				combined = grandchild_bounds
			else:
				combined = combined.merge(grandchild_bounds)

	if not has_any:
		return AABB(Vector3.ZERO, Vector3.ZERO)
	return combined


func _infer_node3d_local_bounds(node: Node3D) -> AABB:
	var size := Vector3.ZERO

	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var aabb := mi.mesh.get_aabb()
			var sc := mi.transform.basis.get_scale()
			size = Vector3(absf(sc.x) * aabb.size.x, absf(sc.y) * aabb.size.y, absf(sc.z) * aabb.size.z)

	elif node is CollisionShape3D:
		var col := node as CollisionShape3D
		if col.shape != null:
			var shape := col.shape
			if shape is BoxShape3D:
				size = (shape as BoxShape3D).size
			elif shape is SphereShape3D:
				var r := (shape as SphereShape3D).radius
				size = Vector3(r * 2.0, r * 2.0, r * 2.0)
			elif shape is CapsuleShape3D:
				var cap := shape as CapsuleShape3D
				size = Vector3(cap.radius * 2.0, cap.height + cap.radius * 2.0, cap.radius * 2.0)

	elif node.has_method("get_aabb"):
		var aabb_var: Variant = node.call("get_aabb")
		if aabb_var is AABB:
			var aabb := aabb_var as AABB
			var sc := node.transform.basis.get_scale()
			size = Vector3(absf(sc.x) * aabb.size.x, absf(sc.y) * aabb.size.y, absf(sc.z) * aabb.size.z)

	if size == Vector3.ZERO:
		return AABB(Vector3.ZERO, Vector3.ZERO)

	return AABB(-size * 0.5, size)


# =============================================================================
# HELPERS
# =============================================================================

func _resolve_node_path_to_node3d(path: NodePath, path_name: String) -> Node3D:
	if path.is_empty():
		return null
	if _host_node == null or not is_instance_valid(_host_node):
		if debug_enabled:
			push_warning("[Transform3D] Cannot resolve %s — no host node" % path_name)
		return null
	var resolved := _host_node.get_node_or_null(path)
	if resolved == null:
		if debug_enabled:
			push_warning("[Transform3D] %s path '%s' could not be resolved" % [path_name, path])
		return null
	if not (resolved is Node3D):
		if debug_enabled:
			push_warning("[Transform3D] %s '%s' is not a Node3D (is %s)" % [path_name, resolved.name, resolved.get_class()])
		return null
	return resolved as Node3D
