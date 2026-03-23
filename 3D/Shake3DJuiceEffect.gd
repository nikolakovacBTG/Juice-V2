## Sine+random shake animation for Node3D nodes.
# ============================================================================
# WHAT: Drives position, rotation, or scale of a Node3D with oscillating shake.
#       Uses sin(time * frequency) blended with per-frame randomness.
#       Progress envelope controls decay (amplitude reduction over duration).
# WHY: Unified shake component — one effect handles all transform targets.
# SYSTEM: Juicing System (addons/Juice_V1/)
# DOES NOT: Handle Control or Node2D targets — use ShakeControl/Shake2DJuiceEffect.
# ============================================================================
#
# WRITE PATTERN: Delta-first. Computes shake offset and stores in
#   _pos_delta / _rot_delta / _scale_delta. Domain node writes once per frame.
#
# PIVOT: Node3D has no native pivot. Position compensation simulates
#   rotation/scale around the pivot point — stored in _pos_delta.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name Shake3DJuiceEffect
extends Juice3DEffectBase


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

var shake_frequency: float = 20.0
var decay: bool = true

var position_strength: Vector3 = Vector3(0.2, 0.2, 0.2)
var position_randomness: float = 0.5

var rotation_amplitude: Vector3 = Vector3(10.0, 10.0, 0.0)
var rotation_randomize_direction: bool = true

var scale_amplitude: Vector3 = Vector3(0.15, 0.15, 0.15)
var scale_randomness: float = 0.5
var scale_uniform: bool = true

var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()
var custom_pivot: Vector3 = Vector3.ZERO

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
	props.append({"name": "shake_frequency", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,100.0,0.1,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "decay", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})

	if is_pos:
		props.append({"name": "position_strength", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "position_randomness", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
			"usage": PROPERTY_USAGE_DEFAULT})
	elif is_rot:
		props.append({"name": "rotation_amplitude", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "rotation_randomize_direction", "type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT})
	elif is_scale:
		props.append({"name": "scale_amplitude", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "scale_randomness", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "scale_uniform", "type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT})

	if not is_pos:
		props.append({"name": "pivot_mode", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Auto Center,Inherit,Custom",
			"usage": PROPERTY_USAGE_DEFAULT})
		if pivot_mode == PivotMode.CUSTOM:
			props.append({"name": "custom_pivot", "type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT})

	props.append_array(_get_effect_base_properties())
	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"transform_target": transform_target = value; return true
		&"shake_frequency": shake_frequency = value; return true
		&"decay": decay = value; return true
		&"position_strength": position_strength = value; return true
		&"position_randomness": position_randomness = value; return true
		&"rotation_amplitude": rotation_amplitude = value; return true
		&"rotation_randomize_direction": rotation_randomize_direction = value; return true
		&"scale_amplitude": scale_amplitude = value; return true
		&"scale_randomness": scale_randomness = value; return true
		&"scale_uniform": scale_uniform = value; return true
		&"pivot_mode": pivot_mode = value; return true
		&"custom_pivot": custom_pivot = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"transform_target": return transform_target
		&"shake_frequency": return shake_frequency
		&"decay": return decay
		&"position_strength": return position_strength
		&"position_randomness": return position_randomness
		&"rotation_amplitude": return rotation_amplitude
		&"rotation_randomize_direction": return rotation_randomize_direction
		&"scale_amplitude": return scale_amplitude
		&"scale_randomness": return scale_randomness
		&"scale_uniform": return scale_uniform
		&"pivot_mode": return pivot_mode
		&"custom_pivot": return custom_pivot
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _shake_time: float = 0.0
var _shake_seed: float = 0.0
var _tick_delta: float = 0.0
var _direction_multiplier: Vector3 = Vector3.ONE
var _last_sine_sign: Vector3 = Vector3.ONE
var _pivot_offset: Vector3 = Vector3.ZERO
var _base_rotation: Vector3 = Vector3.ZERO
var _base_scale: Vector3 = Vector3.ONE
var _has_base: bool = false


# =============================================================================
# TICK OVERRIDE
# =============================================================================

func tick(delta: float, target: Node) -> TickResult:
	_tick_delta = delta
	var result := super.tick(delta, target)
	if _in_hold_at_peak and _is_playing:
		_shake_time += delta
		_compute_shake_deltas(1.0 if not decay else 0.0)
	return result


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

func _on_animate_start(target: Node) -> void:
	_capture_base(target)

	_contributes_position = (transform_target == TransformTarget.POSITION)
	_contributes_rotation = (transform_target == TransformTarget.ROTATION)
	_contributes_scale = (transform_target == TransformTarget.SCALE)

	_shake_seed = randf() * 1000.0
	_shake_time = 0.0
	_direction_multiplier = Vector3.ONE
	_last_sine_sign = Vector3.ONE

	if transform_target != TransformTarget.POSITION:
		_compute_pivot_offset()
		_contributes_position = (_contributes_position or _pivot_offset != Vector3.ZERO)

	if debug_enabled:
		print("[Shake3D] Start: %s, freq=%.1f Hz" % [
			TransformTarget.keys()[transform_target], shake_frequency])


func _apply_effect(progress: float, _target: Node) -> void:
	_shake_time += _tick_delta
	var intensity := (1.0 - progress) if decay else 1.0
	_compute_shake_deltas(intensity)


func _on_animate_in_complete(_target: Node) -> void:
	pass


func _on_animate_out_complete(_target: Node) -> void:
	_clear_deltas()
	_has_base = false


func _restore_to_natural(_target: Node) -> void:
	_clear_deltas()


func _invalidate_base_cache() -> void:
	_has_base = false
	_clear_deltas()


func _get_interrupt_identity() -> Variant:
	return [get_script(), transform_target]


# =============================================================================
# SHAKE CORE
# =============================================================================

func _compute_shake_deltas(intensity: float) -> void:
	if intensity <= 0.0:
		_pos_delta = Vector3.ZERO
		_rot_delta = Vector3.ZERO
		_scale_delta = Vector3.ZERO
		return

	match transform_target:
		TransformTarget.POSITION:
			var freq := _shake_time * shake_frequency * TAU
			var sx := sin(freq + _shake_seed)
			var sy := sin(freq * 1.3 + _shake_seed + 100.0)
			var sz := sin(freq * 0.7 + _shake_seed + 200.0)
			var rx := randf_range(-1.0, 1.0)
			var ry := randf_range(-1.0, 1.0)
			var rz := randf_range(-1.0, 1.0)
			_pos_delta = Vector3(
				lerpf(sx, rx, position_randomness) * position_strength.x * intensity,
				lerpf(sy, ry, position_randomness) * position_strength.y * intensity,
				lerpf(sz, rz, position_randomness) * position_strength.z * intensity)

		TransformTarget.ROTATION:
			var freq_base := _shake_time * shake_frequency * TAU
			var sine_x := sin(freq_base)
			var sine_y := sin(freq_base * 1.3 + 100.0)
			var sine_z := sin(freq_base * 0.7 + 200.0)
			if rotation_randomize_direction:
				_update_direction_axis(sine_x, 0)
				_update_direction_axis(sine_y, 1)
				_update_direction_axis(sine_z, 2)
			var amp := rotation_amplitude * intensity
			var rot_offset := Vector3(
				deg_to_rad(sine_x * amp.x * _direction_multiplier.x),
				deg_to_rad(sine_y * amp.y * _direction_multiplier.y),
				deg_to_rad(sine_z * amp.z * _direction_multiplier.z))
			_rot_delta = rot_offset
			if _pivot_offset != Vector3.ZERO:
				var basis_delta := Basis.from_euler(rot_offset)
				_pos_delta = _pivot_offset - basis_delta * _pivot_offset

		TransformTarget.SCALE:
			var freq := _shake_time * shake_frequency * TAU
			var scale_offset: Vector3
			if scale_uniform:
				var sv := sin(freq + _shake_seed)
				var rv := randf_range(-1.0, 1.0)
				var v := lerpf(sv, rv, scale_randomness) * scale_amplitude.x * intensity
				scale_offset = Vector3(v, v, v)
			else:
				var sx := sin(freq + _shake_seed)
				var sy := sin(freq * 1.3 + _shake_seed + 100.0)
				var sz := sin(freq * 0.7 + _shake_seed + 200.0)
				var rx := randf_range(-1.0, 1.0)
				var ry := randf_range(-1.0, 1.0)
				var rz := randf_range(-1.0, 1.0)
				scale_offset = Vector3(
					lerpf(sx, rx, scale_randomness) * scale_amplitude.x * intensity,
					lerpf(sy, ry, scale_randomness) * scale_amplitude.y * intensity,
					lerpf(sz, rz, scale_randomness) * scale_amplitude.z * intensity)
			_scale_delta = scale_offset
			if _pivot_offset != Vector3.ZERO:
				var new_scale := _base_scale + scale_offset
				var scale_ratio := new_scale / _base_scale
				_pos_delta = _pivot_offset - Vector3(
					_pivot_offset.x * scale_ratio.x,
					_pivot_offset.y * scale_ratio.y,
					_pivot_offset.z * scale_ratio.z)


# =============================================================================
# ROTATION DIRECTION HELPER
# =============================================================================

func _update_direction_axis(sine_value: float, axis: int) -> void:
	var current_sign := signf(sine_value)
	var last_sign: float
	match axis:
		0: last_sign = _last_sine_sign.x
		1: last_sign = _last_sine_sign.y
		2: last_sign = _last_sine_sign.z
		_: return
	if current_sign != last_sign and current_sign != 0.0:
		if randf() > 0.5:
			match axis:
				0: _direction_multiplier.x *= -1.0
				1: _direction_multiplier.y *= -1.0
				2: _direction_multiplier.z *= -1.0
		match axis:
			0: _last_sine_sign.x = current_sign
			1: _last_sine_sign.y = current_sign
			2: _last_sine_sign.z = current_sign


# =============================================================================
# PIVOT / BASE HELPERS
# =============================================================================

func _compute_pivot_offset() -> void:
	match pivot_mode:
		PivotMode.AUTO_CENTER:
			_pivot_offset = Vector3.ZERO
		PivotMode.INHERIT:
			_pivot_offset = Vector3.ZERO
		PivotMode.CUSTOM:
			_pivot_offset = custom_pivot


func _capture_base(target: Node) -> void:
	if _has_base:
		return
	var n3d := target as Node3D
	if n3d == null:
		return
	_base_rotation = n3d.rotation
	_base_scale = n3d.scale
	_has_base = true
