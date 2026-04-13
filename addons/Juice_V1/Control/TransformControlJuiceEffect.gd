## Animate position, rotation, or scale of a [Control] (UI) with tween-based easing and From/To configuration.
##
## Select a transform target (Position, Rotation, or Scale) and configure animations
## using CUSTOM values, SELF snapshots, or live TARGET_NODE references.

# ============================================================================
# WHAT: Animate position, rotation, or scale of a Control with tween-based easing.
# WHY: Replaces 3 separate scripts with one unified component.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Handle Node2D or Node3D targets — use Transform2D/3DJuiceEffect.
# DOES NOT: Handle procedural effects like shake or noise — use Shake/Noise effects.
# WRITE PATTERN: Delta-first. Each frame writes only the CHANGE in this effect's
#   contribution: node.property += (desired - _my_contribution). This enables
#   stacking with other effects and preserves external changes to the node.
#
# FROM/TO MODEL:
# All transform types use a "From [source] To [destination]" model.
# Sources can be CUSTOM (explicit value), SELF (snapshot), or TARGET_NODE (live).
#
# CONDITIONAL EXPORTS:
# Uses _get_property_list() to conditionally show/hide parameters based on
# transform_target and from/to reference selections.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name TransformControlJuiceEffect
extends JuiceControlTransformEffect


# =============================================================================
# ENUMS
# =============================================================================

## Which transform property to animate
enum TransformTarget {
	POSITION,  ## Animate Control.position with offset + unit
	ROTATION,  ## Animate Control.rotation (single-axis Z, degrees)
	SCALE      ## Animate Control.scale with offset
}

## Determines how the pivot point is calculated
enum PivotMode {
	AUTO_CENTER,  ## Automatically center pivot (most common for UI)
	INHERIT,      ## Use the node's existing pivot_offset
	CUSTOM        ## Use custom_pivot values below
}

## Reference type for From/To axes (shared by Position, Rotation, and Scale)
enum TransformReference {
	CUSTOM,       ## Explicit value supplied by the user
	SELF,         ## This object's current value (captured at capture_at moment)
	TARGET_NODE   ## Another object's value (tracked live every frame)
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
var from_position: Vector2 = Vector2.ZERO
var from_position_in: int = PositionIn.OWN_SIZE
var to_position: Vector2 = Vector2.ZERO
var to_position_in: int = PositionIn.OWN_SIZE

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

var from_capture_at: int = CaptureAt.TRIGGER:
	set(value):
		from_capture_at = value
		if value != CaptureAt.IN_EDITOR:
			_from_editor_cached_position = Vector2.ZERO
			_from_editor_cached_rotation = 0.0
			_from_editor_cached_scale = Vector2.ONE
		elif Engine.is_editor_hint():
			_update_editor_cache()
		notify_property_list_changed()

var to_capture_at: int = CaptureAt.TRIGGER:
	set(value):
		to_capture_at = value
		if value != CaptureAt.IN_EDITOR:
			_to_editor_cached_position = Vector2.ZERO
			_to_editor_cached_rotation = 0.0
			_to_editor_cached_scale = Vector2.ONE
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
var custom_pivot: Vector2 = Vector2(0.5, 0.5)

# --- EDITOR CACHE (serialized only when capture_at == IN_EDITOR) ---
var _from_editor_cached_position: Vector2 = Vector2.ZERO
var _from_editor_cached_rotation: float = 0.0
var _from_editor_cached_scale: Vector2 = Vector2.ONE

var _to_editor_cached_position: Vector2 = Vector2.ZERO
var _to_editor_cached_rotation: float = 0.0
var _to_editor_cached_scale: Vector2 = Vector2.ONE


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
			props.append_array(_get_pivot_properties())
		TransformTarget.SCALE:
			props.append_array(_get_scale_from_to_properties())
			props.append_array(_get_pivot_properties())

	# Editor cache — serialized (STORAGE only) when IN_EDITOR is active
	if from_reference == TransformReference.SELF and from_capture_at == CaptureAt.IN_EDITOR:
		props.append({"name": "_from_editor_cached_position", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_STORAGE})
		props.append({"name": "_from_editor_cached_rotation", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_STORAGE})
		props.append({"name": "_from_editor_cached_scale", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_STORAGE})

	if to_reference == TransformReference.SELF and to_capture_at == CaptureAt.IN_EDITOR:
		props.append({"name": "_to_editor_cached_position", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_STORAGE})
		props.append({"name": "_to_editor_cached_rotation", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_STORAGE})
		props.append({"name": "_to_editor_cached_scale", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_STORAGE})

	return props


func _get_position_from_to_properties() -> Array[Dictionary]:
	var pos_props: Array[Dictionary] = []

	# --- From group ---
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
			"hint_string": "Pixels,Own Size,Parent Size,Viewport Size",
		})
		pos_props.append({
			"name": "from_position", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif from_reference == TransformReference.SELF:
		pos_props.append({
			"name": "from_capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor",
		})
	elif from_reference == TransformReference.TARGET_NODE:
		pos_props.append({
			"name": "from_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Control",
		})

	# --- To group ---
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
			"hint_string": "Pixels,Own Size,Parent Size,Viewport Size",
		})
		pos_props.append({
			"name": "to_position", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif to_reference == TransformReference.SELF:
		pos_props.append({
			"name": "to_capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor",
		})
	elif to_reference == TransformReference.TARGET_NODE:
		pos_props.append({
			"name": "to_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Control",
		})
	return pos_props


func _get_rotation_from_to_properties() -> Array[Dictionary]:
	var rot_props: Array[Dictionary] = []

	# --- From group ---
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
			"name": "from_capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor",
		})
	elif from_reference == TransformReference.TARGET_NODE:
		rot_props.append({
			"name": "from_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Control",
		})

	# --- To group ---
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
			"name": "to_capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor",
		})
	elif to_reference == TransformReference.TARGET_NODE:
		rot_props.append({
			"name": "to_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Control",
		})
	return rot_props


func _get_scale_from_to_properties() -> Array[Dictionary]:
	var scale_props: Array[Dictionary] = []

	# --- From group ---
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
			"name": "from_capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor",
		})
	elif from_reference == TransformReference.TARGET_NODE:
		scale_props.append({
			"name": "from_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Control",
		})

	# --- To group ---
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
			"name": "to_capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor",
		})
	elif to_reference == TransformReference.TARGET_NODE:
		scale_props.append({
			"name": "to_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Control",
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
		&"transform_target": transform_target = value; return true
		# Position
		&"from_position": from_position = value; return true
		&"from_position_in": from_position_in = value; return true
		&"to_position": to_position = value; return true
		&"to_position_in": to_position_in = value; return true
		# Rotation
		&"from_rotation_degrees": from_rotation_degrees = value; return true
		&"to_rotation_degrees": to_rotation_degrees = value; return true
		# Shared From/To
		&"from_reference": from_reference = value; return true
		&"to_reference": to_reference = value; return true
		&"from_target_node": from_target_node = value; return true
		&"to_target_node": to_target_node = value; return true
		&"from_capture_at": from_capture_at = value; return true
		&"to_capture_at": to_capture_at = value; return true
		# Scale
		&"from_scale": from_scale = value; return true
		&"to_scale": to_scale = value; return true
		# Pivot
		&"pivot_mode": pivot_mode = value; return true
		&"custom_pivot": custom_pivot = value; return true
		# Editor cache (always handle for deserialization even when not in property list)
		&"_from_editor_cached_position": _from_editor_cached_position = value; return true
		&"_from_editor_cached_rotation": _from_editor_cached_rotation = value; return true
		&"_from_editor_cached_scale": _from_editor_cached_scale = value; return true
		&"_to_editor_cached_position": _to_editor_cached_position = value; return true
		&"_to_editor_cached_rotation": _to_editor_cached_rotation = value; return true
		&"_to_editor_cached_scale": _to_editor_cached_scale = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"transform_target": return transform_target
		# Position
		&"from_position": return from_position
		&"from_position_in": return from_position_in
		&"to_position": return to_position
		&"to_position_in": return to_position_in
		# Rotation
		&"from_rotation_degrees": return from_rotation_degrees
		&"to_rotation_degrees": return to_rotation_degrees
		# Shared From/To
		&"from_reference": return from_reference
		&"to_reference": return to_reference
		&"from_target_node": return from_target_node
		&"to_target_node": return to_target_node
		&"from_capture_at": return from_capture_at
		&"to_capture_at": return to_capture_at
		# Scale
		&"from_scale": return from_scale
		&"to_scale": return to_scale
		# Pivot
		&"pivot_mode": return pivot_mode
		&"custom_pivot": return custom_pivot
		# Editor cache
		&"_from_editor_cached_position": return _from_editor_cached_position
		&"_from_editor_cached_rotation": return _from_editor_cached_rotation
		&"_from_editor_cached_scale": return _from_editor_cached_scale
		&"_to_editor_cached_position": return _to_editor_cached_position
		&"_to_editor_cached_rotation": return _to_editor_cached_rotation
		&"_to_editor_cached_scale": return _to_editor_cached_scale
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

# Animation reference base — captured at animation start when target is at natural state.
# Used purely for From/To computation (e.g., CUSTOM: base + offset).
# NOT used for external-move detection or contribution tracking (node handles those).
var _base_position: Vector2 = Vector2.ZERO
var _base_rotation_radians: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _has_base: bool = false
var _pivot_applied: bool = false

# Resolved From/To target node references (cached at animation start)
var _from_ref: Control = null
var _to_ref: Control = null

# Self snapshots — captured once at the moment chosen by capture_at
var _from_self_position_snapshot: Vector2 = Vector2.ZERO
var _has_from_self_position_snapshot: bool = false
var _from_self_rotation_snapshot: float = 0.0
var _has_from_self_rotation_snapshot: bool = false
var _from_self_scale_snapshot: Vector2 = Vector2.ONE
var _has_from_self_scale_snapshot: bool = false

var _to_self_position_snapshot: Vector2 = Vector2.ZERO
var _has_to_self_position_snapshot: bool = false
var _to_self_rotation_snapshot: float = 0.0
var _has_to_self_rotation_snapshot: bool = false
var _to_self_scale_snapshot: Vector2 = Vector2.ONE
var _has_to_self_scale_snapshot: bool = false


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

func _on_host_ready(target: Node, host: Node) -> void:
	_host_node = host
	if debug_enabled:
		var ctrl := target as Control
		print("[FROMTO_DBG] TransformCtrl._on_host_ready: target=%s target.pos=%s from_ref=%s to_ref=%s from_capture_at=%s to_capture_at=%s" % [
			ctrl.name if ctrl else "null",
			ctrl.position if ctrl else "null",
			TransformReference.keys()[from_reference],
			TransformReference.keys()[to_reference],
			CaptureAt.keys()[from_capture_at],
			CaptureAt.keys()[to_capture_at]])
	_capture_base(target)

	var uses_from_self := from_reference == TransformReference.SELF
	var uses_to_self := to_reference == TransformReference.SELF

	# Capture FROM snapshot
	if uses_from_self:
		if from_capture_at == CaptureAt.IN_EDITOR:
			if debug_enabled:
				print("[FROMTO_DBG] TransformCtrl._on_host_ready: IN_EDITOR → using cached from_pos=%s" % [_from_editor_cached_position])
		elif from_capture_at == CaptureAt.READY:
			match transform_target:
				TransformTarget.POSITION:
					_capture_from_self_position_snapshot(target)
				TransformTarget.ROTATION:
					_capture_from_self_rotation_snapshot(target)
				TransformTarget.SCALE:
					_capture_from_self_scale_snapshot(target)

	# Capture TO snapshot
	if uses_to_self:
		if to_capture_at == CaptureAt.IN_EDITOR:
			if debug_enabled:
				print("[FROMTO_DBG] TransformCtrl._on_host_ready: IN_EDITOR → using cached to_pos=%s" % [_to_editor_cached_position])
		elif to_capture_at == CaptureAt.READY:
			match transform_target:
				TransformTarget.POSITION:
					_capture_to_self_position_snapshot(target)
				TransformTarget.ROTATION:
					_capture_to_self_rotation_snapshot(target)
				TransformTarget.SCALE:
					_capture_to_self_scale_snapshot(target)


func _on_editor_pre_save(target: Node) -> void:
	_update_editor_cache(target)


func _on_animate_start(target: Node) -> void:
	var ctrl := target as Control
	if debug_enabled:
		print("[FROMTO_DBG] TransformCtrl._on_animate_start: target.pos=%s _has_base=%s _base_pos=%s" % [
			ctrl.position if ctrl else "null", _has_base, _base_position])
	if not _has_base:
		_capture_base(target)

	# Set contribution flags so the domain node knows which channel to aggregate
	_contributes_position = (transform_target == TransformTarget.POSITION)
	_contributes_rotation = (transform_target == TransformTarget.ROTATION)
	_contributes_scale = (transform_target == TransformTarget.SCALE)

	_resolve_from_to_refs()

	var uses_from_self := from_reference == TransformReference.SELF
	var uses_to_self := to_reference == TransformReference.SELF

	if uses_from_self and (from_capture_at == CaptureAt.TRIGGER or from_capture_at == CaptureAt.IN_EDITOR):
		if debug_enabled:
			print("[FROMTO_DBG] TransformCtrl._on_animate_start: capturing from_self snapshot")
		match transform_target:
			TransformTarget.POSITION:
				_capture_from_self_position_snapshot(target)
			TransformTarget.ROTATION:
				_capture_from_self_rotation_snapshot(target)
			TransformTarget.SCALE:
				_capture_from_self_scale_snapshot(target)

	if uses_to_self and (to_capture_at == CaptureAt.TRIGGER or to_capture_at == CaptureAt.IN_EDITOR):
		if debug_enabled:
			print("[FROMTO_DBG] TransformCtrl._on_animate_start: capturing to_self snapshot")
		match transform_target:
			TransformTarget.POSITION:
				_capture_to_self_position_snapshot(target)
			TransformTarget.ROTATION:
				_capture_to_self_rotation_snapshot(target)
			TransformTarget.SCALE:
				_capture_to_self_scale_snapshot(target)

	# Resolve pivot for rotation/scale targets
	if transform_target != TransformTarget.POSITION and not _pivot_applied:
		_apply_pivot_mode(target)
		_pivot_applied = true

	if debug_enabled:
		print("[FROMTO_DBG] TransformCtrl._on_animate_start DONE")


func _apply_effect(progress: float, target: Node) -> void:
	var ctrl := target as Control
	if ctrl == null:
		return

	match transform_target:
		TransformTarget.POSITION:
			_apply_position_effect(progress, ctrl)
		TransformTarget.ROTATION:
			_apply_rotation_effect(progress, ctrl)
		TransformTarget.SCALE:
			_apply_scale_effect(progress, ctrl)


func _restore_to_natural(_target: Node) -> void:
	# Clear deltas — the domain node will write natural state via _post_tick_write()
	_clear_deltas()


func _invalidate_base_cache() -> void:
	_has_base = false
	_pivot_applied = false
	_from_ref = null
	_to_ref = null
	_has_from_self_position_snapshot = false
	_has_from_self_rotation_snapshot = false
	_has_from_self_scale_snapshot = false
	_has_to_self_position_snapshot = false
	_has_to_self_rotation_snapshot = false
	_has_to_self_scale_snapshot = false
	_clear_deltas()


func _get_interrupt_identity() -> Variant:
	return [get_script(), transform_target]


# =============================================================================
# POSITION EFFECT
# =============================================================================

## Compute position delta using From/To lerp model.
## Both From and To are resolved to pixel positions, then interpolated.
## Stores result in _pos_delta — the domain node writes once per frame.
func _apply_position_effect(progress: float, target: Control) -> void:
	var from_value := _resolve_from_position(target)
	var to_value := _resolve_to_position(target)
	var desired_absolute := from_value.lerp(to_value, progress)

	# Store delta from natural state — node aggregates and writes
	_pos_delta = desired_absolute - _base_position
	if debug_enabled and (progress < 0.01 or progress > 0.99):
		print("[FROMTO_DBG] TransformCtrl._apply_position_effect: p=%.3f from=%s to=%s desired=%s _base=%s => _pos_delta=%s" % [
			progress, from_value, to_value, desired_absolute, _base_position, _pos_delta])


func _resolve_from_position(ctrl: Control) -> Vector2:
	match from_reference:
		TransformReference.CUSTOM:
			return _base_position + _convert_to_pixels(from_position, from_position_in, ctrl)
		TransformReference.SELF:
			return _from_self_position_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_position(_from_ref, ctrl)
			return _base_position
	return _base_position


func _resolve_to_position(ctrl: Control) -> Vector2:
	match to_reference:
		TransformReference.CUSTOM:
			return _base_position + _convert_to_pixels(to_position, to_position_in, ctrl)
		TransformReference.SELF:
			return _to_self_position_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_position(_to_ref, ctrl)
			return _base_position
	return _base_position



func _get_ref_local_position(ref: Control, animated: Control) -> Vector2:
	var parent := animated.get_parent_control()
	if parent:
		return parent.get_global_transform().affine_inverse() * ref.global_position
	return ref.global_position


# =============================================================================
# ROTATION EFFECT
# =============================================================================

## Compute rotation delta using From/To lerp model.
## Control has native pivot_offset, so no position compensation is needed.
## Stores result in _rot_delta — the domain node writes once per frame.
func _apply_rotation_effect(progress: float, target: Control) -> void:
	var from_rad := _resolve_from_rotation(target)
	var to_rad := _resolve_to_rotation(target)
	var desired_absolute := lerp_angle(from_rad, to_rad, progress)

	# Store delta from natural state — node aggregates and writes
	_rot_delta = desired_absolute - _base_rotation_radians


func _resolve_from_rotation(ctrl: Control) -> float:
	match from_reference:
		TransformReference.CUSTOM:
			return _base_rotation_radians + deg_to_rad(from_rotation_degrees)
		TransformReference.SELF:
			return _from_self_rotation_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_rotation(_from_ref, ctrl)
			return _base_rotation_radians
	return _base_rotation_radians


func _resolve_to_rotation(ctrl: Control) -> float:
	match to_reference:
		TransformReference.CUSTOM:
			return _base_rotation_radians + deg_to_rad(to_rotation_degrees)
		TransformReference.SELF:
			return _to_self_rotation_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_rotation(_to_ref, ctrl)
			return _base_rotation_radians
	return _base_rotation_radians


func _get_ref_local_rotation(ref: Control, animated: Control) -> float:
	var ref_rot := ref.get_global_transform().get_rotation()
	var parent := animated.get_parent_control()
	if parent:
		return ref_rot - parent.get_global_transform().get_rotation()
	return ref_rot


# =============================================================================
# SCALE EFFECT
# =============================================================================

## Compute scale delta using From/To lerp model.
## Control has native pivot_offset, so no position compensation is needed.
## Stores result in _scale_delta — the domain node writes once per frame.
func _apply_scale_effect(progress: float, target: Control) -> void:
	var from_value := _resolve_from_scale(target)
	var to_value := _resolve_to_scale(target)
	var desired_absolute := from_value.lerp(to_value, progress)

	# Store delta from natural state — node aggregates and writes
	_scale_delta = desired_absolute - _base_scale


func _resolve_from_scale(ctrl: Control) -> Vector2:
	match from_reference:
		TransformReference.CUSTOM:
			return from_scale
		TransformReference.SELF:
			return _from_self_scale_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_scale(_from_ref, ctrl)
			return _base_scale
	return _base_scale


func _resolve_to_scale(ctrl: Control) -> Vector2:
	match to_reference:
		TransformReference.CUSTOM:
			return to_scale
		TransformReference.SELF:
			return _to_self_scale_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_scale(_to_ref, ctrl)
			return _base_scale
	return _base_scale


func _get_ref_local_scale(ref: Control, animated: Control) -> Vector2:
	var ref_global_scale := ref.get_global_transform().get_scale()
	var parent_scale := Vector2.ONE
	var parent := animated.get_parent_control()
	if parent:
		parent_scale = parent.get_global_transform().get_scale()
	return ref_global_scale / parent_scale


# =============================================================================
# FROM/TO REFERENCE RESOLUTION
# =============================================================================

## Resolve from_target_node and to_target_node NodePaths to cached references.
func _resolve_from_to_refs() -> void:
	_from_ref = null
	_to_ref = null
	if from_reference == TransformReference.TARGET_NODE:
		_from_ref = _resolve_node_path_to_control(from_target_node, "from_target_node")
	if to_reference == TransformReference.TARGET_NODE:
		_to_ref = _resolve_node_path_to_control(to_target_node, "to_target_node")


# =============================================================================
# FROM SELF SNAPSHOT CAPTURE
# =============================================================================

func _capture_from_self_position_snapshot(target: Node) -> void:
	if _has_from_self_position_snapshot:
		if debug_enabled:
			print("[FROMTO_DBG] TransformCtrl._capture_from_self_position: SKIPPED (already has snap=%s)" % [_from_self_position_snapshot])
		return
	if from_capture_at == CaptureAt.IN_EDITOR:
		_from_self_position_snapshot = _from_editor_cached_position
		if debug_enabled:
			print("[FROMTO_DBG] TransformCtrl._capture_from_self_position: IN_EDITOR → cached=%s" % [_from_editor_cached_position])
	else:
		var ctrl := target as Control
		_from_self_position_snapshot = ctrl.position if ctrl else Vector2.ZERO
		if debug_enabled:
			print("[FROMTO_DBG] TransformCtrl._capture_from_self_position: %s → ctrl.pos=%s" % [
				CaptureAt.keys()[from_capture_at], _from_self_position_snapshot])
	_has_from_self_position_snapshot = true


func _capture_from_self_rotation_snapshot(target: Node) -> void:
	if _has_from_self_rotation_snapshot:
		return
	if from_capture_at == CaptureAt.IN_EDITOR:
		_from_self_rotation_snapshot = _from_editor_cached_rotation
	else:
		var ctrl := target as Control
		_from_self_rotation_snapshot = ctrl.rotation if ctrl else 0.0
	_has_from_self_rotation_snapshot = true
	if debug_enabled:
		print("[TransformCtrl] From Self rotation snapshot: %s rad (mode=%s)" % [
			_from_self_rotation_snapshot, CaptureAt.keys()[from_capture_at]])


func _capture_from_self_scale_snapshot(target: Node) -> void:
	if _has_from_self_scale_snapshot:
		return
	if from_capture_at == CaptureAt.IN_EDITOR:
		_from_self_scale_snapshot = _from_editor_cached_scale
	else:
		var ctrl := target as Control
		_from_self_scale_snapshot = ctrl.scale if ctrl else Vector2.ONE
	_has_from_self_scale_snapshot = true
	if debug_enabled:
		print("[TransformCtrl] From Self scale snapshot: %s (mode=%s)" % [
			_from_self_scale_snapshot, CaptureAt.keys()[from_capture_at]])

# =============================================================================
# TO SELF SNAPSHOT CAPTURE
# =============================================================================

func _capture_to_self_position_snapshot(target: Node) -> void:
	if _has_to_self_position_snapshot:
		if debug_enabled:
			print("[FROMTO_DBG] TransformCtrl._capture_to_self_position: SKIPPED (already has snap=%s)" % [_to_self_position_snapshot])
		return
	if to_capture_at == CaptureAt.IN_EDITOR:
		_to_self_position_snapshot = _to_editor_cached_position
		if debug_enabled:
			print("[FROMTO_DBG] TransformCtrl._capture_to_self_position: IN_EDITOR → cached=%s" % [_to_editor_cached_position])
	else:
		var ctrl := target as Control
		_to_self_position_snapshot = ctrl.position if ctrl else Vector2.ZERO
		if debug_enabled:
			print("[FROMTO_DBG] TransformCtrl._capture_to_self_position: %s → ctrl.pos=%s" % [
				CaptureAt.keys()[to_capture_at], _to_self_position_snapshot])
	_has_to_self_position_snapshot = true


func _capture_to_self_rotation_snapshot(target: Node) -> void:
	if _has_to_self_rotation_snapshot:
		return
	if to_capture_at == CaptureAt.IN_EDITOR:
		_to_self_rotation_snapshot = _to_editor_cached_rotation
	else:
		var ctrl := target as Control
		_to_self_rotation_snapshot = ctrl.rotation if ctrl else 0.0
	_has_to_self_rotation_snapshot = true
	if debug_enabled:
		print("[TransformCtrl] To Self rotation snapshot: %s rad (mode=%s)" % [
			_to_self_rotation_snapshot, CaptureAt.keys()[to_capture_at]])


func _capture_to_self_scale_snapshot(target: Node) -> void:
	if _has_to_self_scale_snapshot:
		return
	if to_capture_at == CaptureAt.IN_EDITOR:
		_to_self_scale_snapshot = _to_editor_cached_scale
	else:
		var ctrl := target as Control
		_to_self_scale_snapshot = ctrl.scale if ctrl else Vector2.ONE
	_has_to_self_scale_snapshot = true
	if debug_enabled:
		print("[TransformCtrl] To Self scale snapshot: %s (mode=%s)" % [
			_to_self_scale_snapshot, CaptureAt.keys()[to_capture_at]])


# =============================================================================
# EDITOR CACHE (IN_EDITOR capture mode)
# =============================================================================

## Refresh the editor cache from the target's current transform.
func _update_editor_cache(target: Node = null) -> void:
	if not Engine.is_editor_hint():
		return
	var ctrl := target as Control
	if ctrl == null:
		return

	if from_reference == TransformReference.SELF and from_capture_at == CaptureAt.IN_EDITOR:
		_from_editor_cached_position = ctrl.position
		_from_editor_cached_rotation = ctrl.rotation
		_from_editor_cached_scale = ctrl.scale

	if to_reference == TransformReference.SELF and to_capture_at == CaptureAt.IN_EDITOR:
		_to_editor_cached_position = ctrl.position
		_to_editor_cached_rotation = ctrl.rotation
		_to_editor_cached_scale = ctrl.scale

	if debug_enabled:
		print("[TransformCtrl] Editor cache updated: pos=%s, rot=%.1f°, scale=%s" % [
			ctrl.position, rad_to_deg(ctrl.rotation), ctrl.scale])


# =============================================================================
# BASE CAPTURE
# =============================================================================

func _capture_base(target: Node) -> void:
	if _has_base:
		if debug_enabled:
			print("[FROMTO_DBG] TransformCtrl._capture_base: SKIPPED (already has _base_pos=%s)" % [_base_position])
		return
	var ctrl := target as Control
	if ctrl == null:
		return
	_base_position = ctrl.position
	_base_rotation_radians = ctrl.rotation
	_base_scale = ctrl.scale
	_has_base = true
	if debug_enabled:
		print("[FROMTO_DBG] TransformCtrl._capture_base: pos=%s, rot=%.1f°, scale=%s" % [
			_base_position, rad_to_deg(_base_rotation_radians), _base_scale])


# =============================================================================
# PIVOT HANDLING
# =============================================================================

## Apply pivot mode to the Control node. Called once per animation start
## for ROTATION and SCALE targets.
func _apply_pivot_mode(target: Node) -> void:
	var ctrl := target as Control
	if ctrl == null:
		return
	match pivot_mode:
		PivotMode.AUTO_CENTER:
			ctrl.pivot_offset = ctrl.size / 2.0
		PivotMode.INHERIT:
			return
		PivotMode.CUSTOM:
			ctrl.pivot_offset = Vector2(
				ctrl.size.x * custom_pivot.x,
				ctrl.size.y * custom_pivot.y
			)


# =============================================================================
# HELPERS
# =============================================================================

## Resolve a NodePath to a Control using the host node's scene tree position.
func _resolve_node_path_to_control(path: NodePath, path_name: String) -> Control:
	if path.is_empty():
		return null
	if _host_node == null or not is_instance_valid(_host_node):
		if debug_enabled:
			push_warning("[TransformCtrl] Cannot resolve %s — no host node" % path_name)
		return null
	var resolved := _host_node.get_node_or_null(path)
	if resolved == null:
		if debug_enabled:
			push_warning("[TransformCtrl] %s path '%s' could not be resolved" % [path_name, path])
		return null
	if not (resolved is Control):
		if debug_enabled:
			push_warning("[TransformCtrl] %s '%s' is not a Control (is %s)" % [path_name, resolved.name, resolved.get_class()])
		return null
	return resolved as Control
