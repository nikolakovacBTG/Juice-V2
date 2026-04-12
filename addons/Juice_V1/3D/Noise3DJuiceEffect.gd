## Continuous noise-based transform animation for Node3D nodes.
# ============================================================================
# WHAT: Drives position, rotation, or scale of a Node3D with procedural noise.
#       Uses FastNoiseLite for configurable noise patterns with fractal and
#       domain warp options. Progress envelope controls intensity.
# WHY: Unified noise component — one effect handles all transform targets
#      with conditional inspector properties.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Handle Control or Node2D targets — use NoiseControl/Noise2DJuiceEffect.
# DOES NOT: Handle arbitrary property noise — use NoisePropertyJuiceEffect.
# ============================================================================
#
# WRITE PATTERN: Delta-first. Computes noise offset and stores in
#   _pos_delta / _rot_delta / _scale_delta. Domain node writes once per frame.
#
# PIVOT: Node3D has no native pivot. AUTO_CENTER/INHERIT use node origin.
#   CUSTOM uses position compensation to simulate pivot.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name Noise3DJuiceEffect
extends Juice3DTransformEffect


# =============================================================================
# ENUMS
# =============================================================================

enum TransformTarget {
	POSITION,  ## Displace Node3D.position (XYZ)
	ROTATION,  ## Rotate Node3D.rotation (XYZ Euler degrees)
	SCALE      ## Scale Node3D.scale (XYZ)
}

enum NoiseDirection {
	BOTH,
	POSITIVE_ONLY,
	NEGATIVE_ONLY
}

enum PivotMode {
	AUTO_CENTER,  ## Rotate/scale around node origin (typical for centered meshes)
	INHERIT,      ## Same as AUTO_CENTER for 3D
	CUSTOM        ## Use custom_pivot_offset
}


# =============================================================================
# CONFIGURATION
# =============================================================================

var transform_target: int = TransformTarget.POSITION:
	set(value):
		transform_target = value
		notify_property_list_changed()

var position_amplitude: Vector3 = Vector3(0.5, 0.5, 0.5)
var position_unit: int = PositionIn3D.WORLD_UNITS:
	set(value):
		position_unit = value
		notify_property_list_changed()
var rotation_amplitude: Vector3 = Vector3(0.0, 5.0, 0.0)
var scale_amplitude: Vector3 = Vector3(0.1, 0.1, 0.1)
var noise_speed: float = 1.0
var noise_direction: int = NoiseDirection.BOTH
var scale_uniform: bool = true:
	set(value):
		scale_uniform = value
		notify_property_list_changed()
var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()
var custom_pivot_offset: Vector3 = Vector3.ZERO

var noise_type: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
var noise_frequency: float = 1.0
var noise_seed: int = 0
var fractal_type: int = FastNoiseLite.FRACTAL_NONE:
	set(value):
		fractal_type = value
		notify_property_list_changed()
var fractal_octaves: int = 1
var lacunarity: float = 2.0
var fractal_gain: float = 0.5
var domain_warp_enabled: bool = false:
	set(value):
		domain_warp_enabled = value
		notify_property_list_changed()
var domain_warp_amplitude: float = 30.0
var domain_warp_frequency: float = 0.5

var position_axis_speed: Vector3 = Vector3(1.0, 1.0, 1.0)
var rotation_axis_speed: Vector3 = Vector3(1.0, 1.0, 1.0)
var scale_axis_speed: Vector3 = Vector3(1.0, 1.0, 1.0)
var clamp_min: float = -1.0
var clamp_max: float = 1.0

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

	if is_pos:
		props.append({"name": "position_amplitude", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "position_unit", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "World Units,Own Size,Parent Size",
			"usage": PROPERTY_USAGE_DEFAULT})
	elif is_rot:
		props.append({"name": "rotation_amplitude", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})
	elif is_scale:
		props.append({"name": "scale_amplitude", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "scale_uniform", "type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT})

	props.append({"name": "noise_speed", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,100.0,0.01,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "noise_direction", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Both,Positive Only,Negative Only",
		"usage": PROPERTY_USAGE_DEFAULT})

	if not is_pos:
		props.append({"name": "pivot_mode", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Auto Center,Inherit,Custom",
			"usage": PROPERTY_USAGE_DEFAULT})
		if pivot_mode == PivotMode.CUSTOM:
			props.append({"name": "custom_pivot_offset", "type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT})

	props.append_array(_get_effect_base_properties())

	# --- Noise Pattern subgroup ---
	props.append({"name": "Noise Pattern", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_SUBGROUP, "hint_string": ""})
	props.append({"name": "noise_type", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Simplex,Simplex Smooth,Cellular,Perlin,Value,Value Cubic",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "noise_frequency", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.001,10.0,0.001,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "noise_seed", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "fractal_type", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "None,FBM,Ridged,Ping Pong",
		"usage": PROPERTY_USAGE_DEFAULT})
	if fractal_type != FastNoiseLite.FRACTAL_NONE:
		props.append({"name": "fractal_octaves", "type": TYPE_INT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "1,6,1",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "lacunarity", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "fractal_gain", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "domain_warp_enabled", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})
	if domain_warp_enabled:
		props.append({"name": "domain_warp_amplitude", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "domain_warp_frequency", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT})

	# --- Advanced subgroup ---
	props.append({"name": "Advanced", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_SUBGROUP, "hint_string": ""})
	if is_pos:
		props.append({"name": "position_axis_speed", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})
	if is_rot:
		props.append({"name": "rotation_axis_speed", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})
	if is_scale and not scale_uniform:
		props.append({"name": "scale_axis_speed", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "clamp_min", "type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "clamp_max", "type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"transform_target": transform_target = value; return true
		&"position_amplitude": position_amplitude = value; return true
		&"rotation_amplitude": rotation_amplitude = value; return true
		&"scale_amplitude": scale_amplitude = value; return true
		&"noise_speed": noise_speed = value; return true
		&"noise_direction": noise_direction = value; return true
		&"scale_uniform": scale_uniform = value; return true
		&"pivot_mode": pivot_mode = value; return true
		&"custom_pivot_offset": custom_pivot_offset = value; return true
		&"noise_type": noise_type = value; return true
		&"noise_frequency": noise_frequency = value; return true
		&"noise_seed": noise_seed = value; return true
		&"fractal_type": fractal_type = value; return true
		&"fractal_octaves": fractal_octaves = value; return true
		&"lacunarity": lacunarity = value; return true
		&"fractal_gain": fractal_gain = value; return true
		&"domain_warp_enabled": domain_warp_enabled = value; return true
		&"domain_warp_amplitude": domain_warp_amplitude = value; return true
		&"domain_warp_frequency": domain_warp_frequency = value; return true
		&"position_axis_speed": position_axis_speed = value; return true
		&"rotation_axis_speed": rotation_axis_speed = value; return true
		&"scale_axis_speed": scale_axis_speed = value; return true
		&"clamp_min": clamp_min = value; return true
		&"clamp_max": clamp_max = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"transform_target": return transform_target
		&"position_amplitude": return position_amplitude
		&"rotation_amplitude": return rotation_amplitude
		&"scale_amplitude": return scale_amplitude
		&"noise_speed": return noise_speed
		&"noise_direction": return noise_direction
		&"scale_uniform": return scale_uniform
		&"pivot_mode": return pivot_mode
		&"custom_pivot_offset": return custom_pivot_offset
		&"noise_type": return noise_type
		&"noise_frequency": return noise_frequency
		&"noise_seed": return noise_seed
		&"fractal_type": return fractal_type
		&"fractal_octaves": return fractal_octaves
		&"lacunarity": return lacunarity
		&"fractal_gain": return fractal_gain
		&"domain_warp_enabled": return domain_warp_enabled
		&"domain_warp_amplitude": return domain_warp_amplitude
		&"domain_warp_frequency": return domain_warp_frequency
		&"position_axis_speed": return position_axis_speed
		&"rotation_axis_speed": return rotation_axis_speed
		&"scale_axis_speed": return scale_axis_speed
		&"clamp_min": return clamp_min
		&"clamp_max": return clamp_max
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _noise: FastNoiseLite
var _noise_time: float = 0.0
var _tick_delta: float = 0.0
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
		_advance_noise_time(delta)
		var n3d := target as Node3D
		if n3d:
			_compute_noise_deltas(1.0, n3d)
	return result


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

func _needs_sustain() -> bool:
	return true


func _on_animate_start(target: Node) -> void:
	_capture_base(target)

	var uses_pivot := (transform_target != TransformTarget.POSITION and _pivot_offset != Vector3.ZERO)
	_contributes_position = (transform_target == TransformTarget.POSITION or uses_pivot)
	_contributes_rotation = (transform_target == TransformTarget.ROTATION)
	_contributes_scale = (transform_target == TransformTarget.SCALE)

	if _target_progress > 0.0:
		_noise_time = 0.0
		_setup_noise()

	if transform_target != TransformTarget.POSITION:
		_compute_pivot_offset()
		_contributes_position = (transform_target == TransformTarget.POSITION or _pivot_offset != Vector3.ZERO)

	if debug_enabled:
		print("[Noise3D] Start: %s, speed=%.2f" % [
			TransformTarget.keys()[transform_target], noise_speed])


func _apply_effect(progress: float, target: Node) -> void:
	_advance_noise_time(_tick_delta)
	var n3d := target as Node3D
	if n3d:
		_compute_noise_deltas(progress, n3d)


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
# NOISE CORE
# =============================================================================

func _advance_noise_time(delta: float) -> void:
	if _target_progress > 0.0:
		_noise_time += delta


func _compute_noise_deltas(intensity: float, target: Node3D) -> void:
	if intensity <= 0.0:
		_pos_delta = Vector3.ZERO
		_rot_delta = Vector3.ZERO
		_scale_delta = Vector3.ZERO
		return

	match transform_target:
		TransformTarget.POSITION:
			var sx := _sample_noise(0.0, position_axis_speed.x)
			var sy := _sample_noise(100.0, position_axis_speed.y)
			var sz := _sample_noise(200.0, position_axis_speed.z)
			var raw_offset = Vector3(
				position_amplitude.x * sx * intensity,
				position_amplitude.y * sy * intensity,
				position_amplitude.z * sz * intensity)
			_pos_delta = _convert_to_world_units(raw_offset, position_unit, target)

		TransformTarget.ROTATION:
			var sx := _sample_noise(0.0, rotation_axis_speed.x)
			var sy := _sample_noise(100.0, rotation_axis_speed.y)
			var sz := _sample_noise(200.0, rotation_axis_speed.z)
			var rot_offset := Vector3(
				deg_to_rad(rotation_amplitude.x * sx * intensity),
				deg_to_rad(rotation_amplitude.y * sy * intensity),
				deg_to_rad(rotation_amplitude.z * sz * intensity))
			_rot_delta = rot_offset
			# Position compensation for custom pivot
			if _pivot_offset != Vector3.ZERO:
				var base_basis := Basis.from_euler(_base_rotation)
				var new_basis := Basis.from_euler(_base_rotation + rot_offset)
				var original_pivot := base_basis * _pivot_offset
				var rotated_pivot := new_basis * _pivot_offset
				_pos_delta = original_pivot - rotated_pivot

		TransformTarget.SCALE:
			var sx: float
			var sy: float
			var sz: float
			if scale_uniform:
				var s := _sample_noise(0.0, 1.0)
				sx = s; sy = s; sz = s
			else:
				sx = _sample_noise(0.0, scale_axis_speed.x)
				sy = _sample_noise(100.0, scale_axis_speed.y)
				sz = _sample_noise(200.0, scale_axis_speed.z)
			var scale_offset := Vector3(
				scale_amplitude.x * sx * intensity,
				scale_amplitude.y * sy * intensity,
				scale_amplitude.z * sz * intensity)
			_scale_delta = scale_offset
			# Position compensation for custom pivot
			if _pivot_offset != Vector3.ZERO:
				var new_scale := _base_scale + scale_offset
				var scale_ratio := new_scale / _base_scale
				var compensated_pivot := Vector3(
					_pivot_offset.x * scale_ratio.x,
					_pivot_offset.y * scale_ratio.y,
					_pivot_offset.z * scale_ratio.z)
				_pos_delta = _pivot_offset - compensated_pivot


# =============================================================================
# PIVOT HELPERS
# =============================================================================

func _compute_pivot_offset() -> void:
	match pivot_mode:
		PivotMode.AUTO_CENTER:
			_pivot_offset = Vector3.ZERO
		PivotMode.INHERIT:
			_pivot_offset = Vector3.ZERO
		PivotMode.CUSTOM:
			_pivot_offset = custom_pivot_offset


func _capture_base(target: Node) -> void:
	if _has_base:
		return
	var n3d := target as Node3D
	if n3d == null:
		return
	_base_rotation = n3d.rotation
	_base_scale = n3d.scale
	_has_base = true


# =============================================================================
# NOISE HELPERS
# =============================================================================

func _setup_noise() -> void:
	if _noise == null:
		_noise = FastNoiseLite.new()
	_noise.noise_type = noise_type
	_noise.frequency = noise_frequency
	_noise.seed = noise_seed if noise_seed != 0 else randi()
	_noise.fractal_type = fractal_type
	_noise.fractal_octaves = fractal_octaves
	_noise.fractal_lacunarity = lacunarity
	_noise.fractal_gain = fractal_gain
	if domain_warp_enabled:
		_noise.domain_warp_enabled = true
		_noise.domain_warp_amplitude = domain_warp_amplitude
		_noise.domain_warp_frequency = domain_warp_frequency
	else:
		_noise.domain_warp_enabled = false


func _sample_noise(y_offset: float, axis_speed: float) -> float:
	var t := _noise_time * noise_speed * axis_speed
	var raw := _noise.get_noise_2d(t, y_offset)
	match noise_direction:
		NoiseDirection.POSITIVE_ONLY:
			raw = absf(raw)
		NoiseDirection.NEGATIVE_ONLY:
			raw = -absf(raw)
	raw = clampf(raw, clamp_min, clamp_max)
	return raw
