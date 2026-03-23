## Physics-based spring animation for Node2D nodes.
# ============================================================================
# WHAT: Drives position, rotation, or scale of a Node2D with spring physics.
#       Uses stiffness/damping/mass simulation, NOT easing curves.
# WHY: Unified spring component — one effect handles all transform targets.
# SYSTEM: Juicing System (addons/Juice_V1/)
# DOES NOT: Handle Control or Node3D targets — use SpringControl/Spring3DJuiceEffect.
# ============================================================================
#
# WRITE PATTERN: Delta-first. Spring simulation runs internally, delta =
#   current_spring_value - base_value stored in _pos_delta / _rot_delta /
#   _scale_delta. Domain node writes once per frame.
#
# PIVOT: Node2D has no native pivot. Position compensation simulates
#   rotation/scale around the pivot point — stored in _pos_delta.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase2D.svg")
class_name Spring2DJuiceEffect
extends Juice2DTransformEffect


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

var position_offset: Vector2 = Vector2(0, -20)
var rotation_offset_degrees: float = 15.0
var scale_offset: Vector2 = Vector2(0.2, 0.2)

var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()
var custom_pivot: Vector2 = Vector2.ZERO

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
		props.append({"name": "position_offset", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT})
	elif is_rot:
		props.append({"name": "rotation_offset_degrees", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT})
	elif is_scale:
		props.append({"name": "scale_offset", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT})

	if not is_pos:
		props.append({"name": "pivot_mode", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Auto Center,Inherit,Custom",
			"usage": PROPERTY_USAGE_DEFAULT})
		if pivot_mode == PivotMode.CUSTOM:
			props.append({"name": "custom_pivot", "type": TYPE_VECTOR2,
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
		&"rotation_offset_degrees": rotation_offset_degrees = value; return true
		&"scale_offset": scale_offset = value; return true
		&"pivot_mode": pivot_mode = value; return true
		&"custom_pivot": custom_pivot = value; return true
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
		&"rotation_offset_degrees": return rotation_offset_degrees
		&"scale_offset": return scale_offset
		&"pivot_mode": return pivot_mode
		&"custom_pivot": return custom_pivot
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _tick_delta: float = 0.0
var _last_trigger_time: float = -INF
var _pivot_offset: Vector2 = Vector2.ZERO
var _base_scale: Vector2 = Vector2.ONE

# Spring simulation state (deltas from base)
var _current_value: Variant = null
var _spring_target_value: Variant = null
var _velocity: Variant = null


# =============================================================================
# TICK OVERRIDE
# =============================================================================

func tick(delta: float, target: Node) -> TickResult:
	_tick_delta = delta
	var result := super.tick(delta, target)
	if _in_hold_at_peak and _is_playing:
		_spring_step(_tick_delta)
		_compute_deltas_from_spring()
	return result


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

func _on_animate_start(target: Node) -> void:
	if trigger_cooldown > 0.0:
		var current_time := Time.get_ticks_msec() / 1000.0
		if current_time - _last_trigger_time < trigger_cooldown:
			return
		_last_trigger_time = current_time

	_contributes_position = (transform_target == TransformTarget.POSITION)
	_contributes_rotation = (transform_target == TransformTarget.ROTATION)
	_contributes_scale = (transform_target == TransformTarget.SCALE)

	# Capture base scale for pivot compensation
	var n2d := target as Node2D
	if n2d != null:
		_base_scale = n2d.scale

	if transform_target != TransformTarget.POSITION:
		_compute_pivot_offset(target)
		_contributes_position = (_contributes_position or _pivot_offset != Vector2.ZERO)

	_initialize_spring_state()

	if debug_enabled:
		print("[Spring2D] Start: %s, stiffness=%.0f, damping=%.0f" % [
			TransformTarget.keys()[transform_target], stiffness, damping])


func _apply_effect(progress: float, _target: Node) -> void:
	_spring_step(_tick_delta)
	_compute_deltas_from_spring()

	if _is_spring_settled():
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
			_current_value = Vector2.ZERO
			_spring_target_value = position_offset
			_velocity = Vector2.ZERO
		TransformTarget.ROTATION:
			_current_value = 0.0
			_spring_target_value = deg_to_rad(rotation_offset_degrees)
			_velocity = 0.0
		TransformTarget.SCALE:
			_current_value = Vector2.ZERO
			_spring_target_value = scale_offset
			_velocity = Vector2.ZERO


func _spring_step(delta: float) -> void:
	if delta <= 0.0:
		return
	match transform_target:
		TransformTarget.POSITION, TransformTarget.SCALE:
			_spring_step_vector2(delta)
		TransformTarget.ROTATION:
			_spring_step_float(delta)


func _spring_step_float(delta: float) -> void:
	var current := _current_value as float
	var target := _spring_target_value as float
	var vel := _velocity as float
	var displacement := target - current
	var acceleration := (displacement * stiffness - vel * damping) / mass
	vel += acceleration * delta
	current += vel * delta
	_velocity = vel
	_current_value = current


func _spring_step_vector2(delta: float) -> void:
	var current := _current_value as Vector2
	var target := _spring_target_value as Vector2
	var vel := _velocity as Vector2
	var displacement := target - current
	var acceleration := (displacement * stiffness - vel * damping) / mass
	vel += acceleration * delta
	current += vel * delta
	_velocity = vel
	_current_value = current


func _is_spring_settled() -> bool:
	match transform_target:
		TransformTarget.POSITION, TransformTarget.SCALE:
			var vel := _velocity as Vector2
			var current := _current_value as Vector2
			var target := _spring_target_value as Vector2
			return vel.length() < velocity_threshold and current.distance_to(target) < value_threshold
		TransformTarget.ROTATION:
			var vel := _velocity as float
			var current := _current_value as float
			var target := _spring_target_value as float
			return absf(vel) < velocity_threshold and absf(current - target) < value_threshold
	return false


func _compute_deltas_from_spring() -> void:
	match transform_target:
		TransformTarget.POSITION:
			_pos_delta = _current_value as Vector2
		TransformTarget.ROTATION:
			var rot_delta_val := _current_value as float
			_rot_delta = rot_delta_val
			# Position compensation for pivot
			if _pivot_offset != Vector2.ZERO:
				_pos_delta = _pivot_offset - _pivot_offset.rotated(rot_delta_val)
		TransformTarget.SCALE:
			var scale_delta_val := _current_value as Vector2
			_scale_delta = scale_delta_val
			# Position compensation for pivot
			if _pivot_offset != Vector2.ZERO:
				var new_scale := _base_scale + scale_delta_val
				var scale_ratio := new_scale / _base_scale
				_pos_delta = _pivot_offset - _pivot_offset * scale_ratio


# =============================================================================
# PIVOT HELPERS
# =============================================================================

func _compute_pivot_offset(target: Node) -> void:
	match pivot_mode:
		PivotMode.INHERIT:
			_pivot_offset = Vector2.ZERO
		PivotMode.CUSTOM:
			_pivot_offset = custom_pivot
		PivotMode.AUTO_CENTER:
			_pivot_offset = _estimate_visual_center(target)


func _estimate_visual_center(target: Node) -> Vector2:
	if not is_instance_valid(target):
		return Vector2.ZERO
	for child in target.get_children():
		if child is Sprite2D and (child as Sprite2D).texture != null:
			var spr := child as Sprite2D
			if spr.centered:
				return spr.position
			else:
				return spr.position + spr.texture.get_size() / 2.0
	return Vector2.ZERO
