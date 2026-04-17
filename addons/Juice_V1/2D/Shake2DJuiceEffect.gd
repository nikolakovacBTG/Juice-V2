## Sine+random shake animation for Node2D nodes.
# ============================================================================
# WHAT: Drives position, rotation, or scale of a Node2D with oscillating shake.
#       Uses sin(time * frequency) blended with per-frame randomness.
#       Progress envelope controls intensity (fade-in, sustain, fade-out).
# WHY: Unified shake component — one effect handles all transform targets.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Handle Control or Node3D targets — use ShakeControl/Shake3DJuiceEffect.
# ============================================================================
#
# WRITE PATTERN: Delta-first. Computes shake offset and stores in
#   _pos_delta / _rot_delta / _scale_delta. Domain node writes once per frame.
#
# PIVOT: Node2D has no native pivot. Position compensation simulates
#   rotation/scale around the pivot point — stored in _pos_delta.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase2D.svg")
class_name Shake2DJuiceEffect
extends Juice2DTransformEffect


# =============================================================================
# ENUMS
# =============================================================================

# TransformTarget inherited from Juice2DTransformEffect

# PivotMode inherited from Juice2DTransformEffect


# =============================================================================
# CONFIGURATION
# =============================================================================

# transform_target inherited from Juice2DTransformEffect (default: POSITION)

var shake_frequency: float = 20.0

var position_strength: Vector2 = Vector2(5.0, 5.0)
var position_unit: int = PositionIn.PIXELS:
	set(value):
		position_unit = value
		notify_property_list_changed()
var position_randomness: float = 0.5

var rotation_amplitude: float = 10.0
var rotation_randomize_direction: bool = true

var scale_amplitude: Vector2 = Vector2(0.15, 0.15)
var scale_randomness: float = 0.5
var scale_uniform: bool = true

# pivot_mode inherited from Juice2DTransformEffect (default: AUTO_CENTER)
var custom_pivot: Vector2 = Vector2.ZERO

func _init() -> void:
	_subclass_owns_effect_group = true
	_leaf_owns_layout = true


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

	if is_pos:
		props.append({"name": "position_unit", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Pixels,Own Size,Parent Size,Viewport Size",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "position_strength", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "position_randomness", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
			"usage": PROPERTY_USAGE_DEFAULT})
	elif is_rot:
		props.append({"name": "rotation_amplitude", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "rotation_randomize_direction", "type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT})
	elif is_scale:
		props.append({"name": "scale_amplitude", "type": TYPE_VECTOR2,
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
			props.append({"name": "custom_pivot", "type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT})

	props.append_array(_get_effect_base_properties())
	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"transform_target": transform_target = value; return true
		&"shake_frequency": shake_frequency = value; return true
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
var _direction_multiplier: float = 1.0
var _last_sine_sign: float = 1.0
var _pivot_offset: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
# _has_base inherited from Juice2DTransformEffect



# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

func _needs_sustain() -> bool:
	return true


func _on_animate_start(target: Node) -> void:
	_capture_base(target)

	_contributes_position = (transform_target == TransformTarget.POSITION)
	_contributes_rotation = (transform_target == TransformTarget.ROTATION)
	_contributes_scale = (transform_target == TransformTarget.SCALE)

	_shake_seed = randf() * 1000.0
	_shake_time = 0.0
	_direction_multiplier = 1.0
	_last_sine_sign = 1.0

	if transform_target != TransformTarget.POSITION:
		_compute_pivot_offset(target)
		_contributes_position = (_contributes_position or _pivot_offset != Vector2.ZERO)

	if debug_enabled:
		print("[Shake2D] Start: %s, freq=%.1f Hz" % [
			TransformTarget.keys()[transform_target], shake_frequency])


func _apply_effect(progress: float, target: Node) -> void:
	_shake_time += _current_delta
	var n2d := target as Node2D
	if n2d:
		_compute_shake_deltas(progress, n2d)


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

func _compute_shake_deltas(intensity: float, target: Node2D) -> void:
	if intensity <= 0.0:
		_pos_delta = Vector2.ZERO
		_rot_delta = 0.0
		_scale_delta = Vector2.ZERO
		return

	match transform_target:
		TransformTarget.POSITION:
			var freq := _shake_time * shake_frequency * TAU
			var sx := sin(freq + _shake_seed)
			var sy := sin(freq * 1.3 + _shake_seed + 100.0)
			var rx := randf_range(-1.0, 1.0)
			var ry := randf_range(-1.0, 1.0)
			var raw_offset = Vector2(
				lerpf(sx, rx, position_randomness) * position_strength.x * intensity,
				lerpf(sy, ry, position_randomness) * position_strength.y * intensity)
			_pos_delta = _convert_to_world_pixels(raw_offset, position_unit, target)

		TransformTarget.ROTATION:
			var sine_val := sin(_shake_time * shake_frequency * TAU)
			if rotation_randomize_direction:
				var cs := signf(sine_val)
				if cs != _last_sine_sign and cs != 0.0:
					if randf() > 0.5:
						_direction_multiplier *= -1.0
					_last_sine_sign = cs
			var angle_offset := deg_to_rad(
				sine_val * rotation_amplitude * intensity * _direction_multiplier)
			_rot_delta = angle_offset
			# Position compensation for pivot
			if _pivot_offset != Vector2.ZERO:
				var rotated_pivot := _pivot_offset.rotated(angle_offset)
				_pos_delta = _pivot_offset - rotated_pivot

		TransformTarget.SCALE:
			var freq := _shake_time * shake_frequency * TAU
			var scale_offset: Vector2
			if scale_uniform:
				var sv := sin(freq + _shake_seed)
				var rv := randf_range(-1.0, 1.0)
				var v := lerpf(sv, rv, scale_randomness) * scale_amplitude.x * intensity
				scale_offset = Vector2(v, v)
			else:
				var sx := sin(freq + _shake_seed)
				var sy := sin(freq * 1.3 + _shake_seed + 100.0)
				var rx := randf_range(-1.0, 1.0)
				var ry := randf_range(-1.0, 1.0)
				scale_offset = Vector2(
					lerpf(sx, rx, scale_randomness) * scale_amplitude.x * intensity,
					lerpf(sy, ry, scale_randomness) * scale_amplitude.y * intensity)
			_scale_delta = scale_offset
			if _pivot_offset != Vector2.ZERO:
				var new_scale := _base_scale + scale_offset
				var scale_ratio := new_scale / _base_scale
				_pos_delta = _pivot_offset - _pivot_offset * scale_ratio


# =============================================================================
# PIVOT / BASE HELPERS
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


func _capture_base(target: Node) -> void:
	if _has_base:
		return
	var n2d := target as Node2D
	if n2d == null:
		return
	_base_rotation = n2d.rotation
	_base_scale = n2d.scale
	_has_base = true
