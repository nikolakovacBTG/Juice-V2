## Physics-based spring animation for Node3D nodes.
# ============================================================================
# WHAT: Drives position, rotation, or scale of a Node3D with spring physics.
#       Uses stiffness/damping/mass simulation, NOT easing curves.
# WHY: Unified spring component — one effect handles all transform targets.
# SYSTEM: Juicing System (addons/Juice_V1/)
# DOES NOT: Handle Control or Node2D targets — use SpringControl/Spring2DJuiceEffect.
# ============================================================================
#
# WRITE PATTERN: Delta-first. Spring simulation runs internally, delta =
#   current_spring_value - base_value stored in _pos_delta / _rot_delta /
#   _scale_delta. Domain node writes once per frame.
#
# PIVOT: Node3D has no native pivot. Rotation uses rotation_pivot_offset.
#   Scale uses PivotMode enum with position compensation.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name Spring3DJuiceEffect
extends Juice3DTransformEffect


# =============================================================================
# ENUMS
# =============================================================================

enum TransformTarget {
	POSITION,
	ROTATION,
	SCALE
}

enum PivotMode {
	AUTO_CENTER,
	INHERIT,
	CUSTOM
}


# =============================================================================
# CONFIGURATION
# =============================================================================

var transform_target: int = TransformTarget.POSITION:
	set(value):
		transform_target = value
		notify_property_list_changed()

var stiffness: float = 300.0
var damping: float = 10.0
var mass: float = 1.0

var velocity_threshold: float = 0.5
var value_threshold: float = 0.1
var trigger_cooldown: float = 0.0

var position_offset: Vector3 = Vector3(0, 0.5, 0)
var rotation_offset: Vector3 = Vector3(0, 15, 0)
var rotation_pivot_offset: Vector3 = Vector3.ZERO

var scale_offset: Vector3 = Vector3(0.2, 0.2, 0.2)
var scale_pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		scale_pivot_mode = value
		notify_property_list_changed()
var scale_custom_pivot: Vector3 = Vector3.ZERO

func _init() -> void:
	_subclass_owns_effect_group = true


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	var is_pos := transform_target == TransformTarget.POSITION
	var is_rot := transform_target == TransformTarget.ROTATION
	var is_scale := transform_target == TransformTarget.SCALE

	props.append({"name": "Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "transform_target", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Position,Rotation,Scale",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "stiffness", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "1.0,1000.0,1.0,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "damping", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,50.0,0.1,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "mass", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,10.0,0.1",
		"usage": PROPERTY_USAGE_DEFAULT})

	if is_pos:
		props.append({"name": "position_offset", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})
	elif is_rot:
		props.append({"name": "rotation_offset", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "rotation_pivot_offset", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})
	elif is_scale:
		props.append({"name": "scale_offset", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "scale_pivot_mode", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Auto Center,Inherit,Custom",
			"usage": PROPERTY_USAGE_DEFAULT})
		if scale_pivot_mode == PivotMode.CUSTOM:
			props.append({"name": "scale_custom_pivot", "type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT})

	props.append({"name": "velocity_threshold", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.01,10.0,0.01",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "value_threshold", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.001,5.0,0.001",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "trigger_cooldown", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,5.0,0.01",
		"usage": PROPERTY_USAGE_DEFAULT})

	props.append_array(_get_effect_base_properties())
	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"transform_target": transform_target = value; return true
		&"stiffness": stiffness = value; return true
		&"damping": damping = value; return true
		&"mass": mass = value; return true
		&"velocity_threshold": velocity_threshold = value; return true
		&"value_threshold": value_threshold = value; return true
		&"trigger_cooldown": trigger_cooldown = value; return true
		&"position_offset": position_offset = value; return true
		&"rotation_offset": rotation_offset = value; return true
		&"rotation_pivot_offset": rotation_pivot_offset = value; return true
		&"scale_offset": scale_offset = value; return true
		&"scale_pivot_mode": scale_pivot_mode = value; return true
		&"scale_custom_pivot": scale_custom_pivot = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"transform_target": return transform_target
		&"stiffness": return stiffness
		&"damping": return damping
		&"mass": return mass
		&"velocity_threshold": return velocity_threshold
		&"value_threshold": return value_threshold
		&"trigger_cooldown": return trigger_cooldown
		&"position_offset": return position_offset
		&"rotation_offset": return rotation_offset
		&"rotation_pivot_offset": return rotation_pivot_offset
		&"scale_offset": return scale_offset
		&"scale_pivot_mode": return scale_pivot_mode
		&"scale_custom_pivot": return scale_custom_pivot
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _tick_delta: float = 0.0
var _last_trigger_time: float = -INF
var _scale_pivot_point: Vector3 = Vector3.ZERO
var _base_scale: Vector3 = Vector3.ONE
var _base_basis: Basis = Basis.IDENTITY
var _fixed_pivot_parent: Vector3 = Vector3.ZERO

# Spring simulation state (deltas from base)
var _current_value: Vector3 = Vector3.ZERO
var _spring_target_value: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO


# =============================================================================
# TICK OVERRIDE
# =============================================================================

func tick(delta: float, target: Node) -> TickResult:
	_tick_delta = delta
	var result := super.tick(delta, target)
	if _in_hold_at_peak and _is_playing:
		_spring_step_vector3(_tick_delta)
		_compute_deltas_from_spring()
	return result


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

func _needs_sustain() -> bool:
	return true


func _on_animate_start(target: Node) -> void:
	if trigger_cooldown > 0.0:
		var current_time := Time.get_ticks_msec() / 1000.0
		if current_time - _last_trigger_time < trigger_cooldown:
			return
		_last_trigger_time = current_time

	_contributes_position = (transform_target == TransformTarget.POSITION)
	_contributes_rotation = (transform_target == TransformTarget.ROTATION)
	_contributes_scale = (transform_target == TransformTarget.SCALE)

	var n3d := target as Node3D
	if n3d != null:
		_base_scale = n3d.scale
		_base_basis = n3d.transform.basis
		if transform_target == TransformTarget.ROTATION and rotation_pivot_offset != Vector3.ZERO:
			_fixed_pivot_parent = n3d.position + _base_basis * rotation_pivot_offset
			_contributes_position = true

	if transform_target == TransformTarget.SCALE:
		_resolve_scale_pivot(target)
		if _scale_pivot_point != Vector3.ZERO:
			_contributes_position = true

	_initialize_spring_state()

	if debug_enabled:
		print("[Spring3D] Start: %s, stiffness=%.0f, damping=%.0f" % [
			TransformTarget.keys()[transform_target], stiffness, damping])


func _apply_effect(progress: float, _target: Node) -> void:
	_spring_step_vector3(_tick_delta)
	_compute_deltas_from_spring()

	if _is_settled_vector3():
		_current_value = _spring_target_value
		_compute_deltas_from_spring()


func _on_animate_in_complete(_target: Node) -> void:
	pass


func _on_animate_out_complete(_target: Node) -> void:
	_clear_deltas()


func _restore_to_natural(_target: Node) -> void:
	_clear_deltas()


func _invalidate_base_cache() -> void:
	_clear_deltas()


func _get_interrupt_identity() -> Variant:
	return [get_script(), transform_target]


# =============================================================================
# SPRING SIMULATION
# =============================================================================

func _initialize_spring_state() -> void:
	match transform_target:
		TransformTarget.POSITION:
			_current_value = Vector3.ZERO
			_spring_target_value = position_offset
		TransformTarget.ROTATION:
			_current_value = Vector3.ZERO
			# rotation_offset is in degrees, convert to radians for delta
			_spring_target_value = Vector3(
				deg_to_rad(rotation_offset.x),
				deg_to_rad(rotation_offset.y),
				deg_to_rad(rotation_offset.z))
		TransformTarget.SCALE:
			_current_value = Vector3.ZERO
			_spring_target_value = scale_offset

	_velocity = Vector3.ZERO


func _spring_step_vector3(delta: float) -> void:
	if delta <= 0.0:
		return
	var displacement := _spring_target_value - _current_value
	var acceleration := (displacement * stiffness - _velocity * damping) / mass
	_velocity += acceleration * delta
	_current_value += _velocity * delta


func _is_settled_vector3() -> bool:
	return _velocity.length() < velocity_threshold and _current_value.distance_to(_spring_target_value) < value_threshold


func _compute_deltas_from_spring() -> void:
	match transform_target:
		TransformTarget.POSITION:
			_pos_delta = _current_value
		TransformTarget.ROTATION:
			_rot_delta = _current_value
			# Position compensation for rotation pivot
			if rotation_pivot_offset != Vector3.ZERO:
				var new_basis := Basis.from_euler(_base_basis.get_euler() + _current_value)
				_pos_delta = _fixed_pivot_parent - (new_basis * rotation_pivot_offset)
				# Subtract base position contribution since delta is additive
				# Actually: delta = new_pos - base_pos
				# new_pos = fixed_pivot - new_basis * pivot
				# base_pos = fixed_pivot - base_basis * pivot
				# delta = base_basis * pivot - new_basis * pivot
				_pos_delta = _base_basis * rotation_pivot_offset - new_basis * rotation_pivot_offset
		TransformTarget.SCALE:
			_scale_delta = _current_value
			if _scale_pivot_point != Vector3.ZERO:
				var new_scale := _base_scale + _current_value
				var scale_ratio := new_scale / _base_scale
				_pos_delta = _scale_pivot_point - Vector3(
					_scale_pivot_point.x * scale_ratio.x,
					_scale_pivot_point.y * scale_ratio.y,
					_scale_pivot_point.z * scale_ratio.z)


# =============================================================================
# SCALE PIVOT RESOLUTION
# =============================================================================

func _resolve_scale_pivot(target: Node) -> void:
	match scale_pivot_mode:
		PivotMode.INHERIT:
			_scale_pivot_point = Vector3.ZERO
		PivotMode.CUSTOM:
			_scale_pivot_point = scale_custom_pivot
		PivotMode.AUTO_CENTER:
			_scale_pivot_point = Vector3.ZERO  # No auto-detect without mesh children in headless
