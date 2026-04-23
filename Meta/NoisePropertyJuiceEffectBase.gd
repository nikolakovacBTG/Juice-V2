## Drives arbitrary node properties with procedural FastNoiseLite oscillation.
##
## Shared noise settings (speed, type, frequency, seed, fractal, domain warp)
## apply across ALL property targets. Each target has its own amplitude.
## Wraps automatically with the animate-in / animate-out envelope from JuiceEffectBase.

# =============================================================================
# WHAT: Noise-drives a list of arbitrary properties on any nodes.
#       Uses FastNoiseLite with multi-channel sampling (Y offset per axis).
#       Progress envelope (inherited from JuiceEffectBase) scales intensity.
# WHY:  Ports the Property family's noise effect to V1. Domain-agnostic:
#       targets any property on any node — not bound to position/rotation/scale.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# DOES NOT: Use domain delta aggregation — writes via set_indexed() directly.
#            This is the same approved exception as ProgressPropertyJuiceEffectBase.
# DOES NOT: Handle shader parameters via picker (type them as
#            "material:shader_parameter/name" manually — set_indexed() handles it).
# NOTE: The noise algorithm here mirrors Noise2DJuiceEffect / Noise3DJuiceEffect.
#       GDScript has no mixins, so it is intentionally duplicated and documented.
# =============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseProperty.svg")
class_name PropertyNoiseJuiceEffectBase
extends PropertyJuiceEffectBase


# =============================================================================
# ENUMS
# =============================================================================

enum NoiseDirection {
	BOTH,           ## Noise samples both positive and negative values.
	POSITIVE_ONLY,  ## Noise samples are abs() — always positive.
	NEGATIVE_ONLY   ## Noise samples are -abs() — always negative.
}


# =============================================================================
# CONFIGURATION — Noise settings (shared across all property targets)
# =============================================================================

## How fast the noise time cursor advances. Increase for faster oscillation.
var noise_speed: float = 1.0
## Direction bias for noise sampling.
var noise_direction: int = NoiseDirection.BOTH:
	set(value): noise_direction = value; notify_property_list_changed()

## FastNoiseLite noise algorithm.
var noise_type: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
## FastNoiseLite base frequency.
var noise_frequency: float = 1.0
## Seed for the noise generator. 0 = random each play.
var noise_seed: int = 0

## Fractal overlay type.
var fractal_type: int = FastNoiseLite.FRACTAL_NONE:
	set(value): fractal_type = value; notify_property_list_changed()
## Fractal layers (visible when fractal_type != NONE).
var fractal_octaves: int = 1
## Frequency multiplier per fractal layer.
var lacunarity: float = 2.0
## Amplitude multiplier per fractal layer.
var fractal_gain: float = 0.5

## Enable domain warp for extra complexity.
var domain_warp_enabled: bool = false:
	set(value): domain_warp_enabled = value; notify_property_list_changed()
## Domain warp amplitude.
var domain_warp_amplitude: float = 30.0
## Domain warp frequency.
var domain_warp_frequency: float = 0.5

## Clamp raw noise sample below this value.
var clamp_min: float = -1.0
## Clamp raw noise sample above this value.
var clamp_max: float = 1.0


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_target_resource_type() -> String:
	return "NoisePropertyTarget"


func _init() -> void:
	# Both flags required:
	# _subclass_owns_effect_group  → suppresses JuiceEffectBase's Effect group
	# _subclass_owns_prop_layout   → suppresses PropertyJuiceEffectBase's Effect+PropertyTargets groups
	# Without both, Godot's per-class _get_property_list() chain causes duplicate group headers.
	_subclass_owns_effect_group = true
	_subclass_owns_prop_layout = true


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# Effect group — noise settings + shared effect timing.
	props.append({"name": "Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "noise_speed", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,100.0,0.01,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "noise_direction", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Both,Positive Only,Negative Only",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append_array(_get_effect_base_properties())

	# Noise Pattern subgroup — FastNoiseLite settings.
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

	# Advanced subgroup.
	props.append({"name": "Advanced", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_SUBGROUP, "hint_string": ""})
	props.append({"name": "clamp_min", "type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "clamp_max", "type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT})

	# Property Targets array — typed to NoisePropertyTarget.
	props.append({"name": "Property Targets", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({
		"name": "property_targets",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_ARRAY_TYPE,
		"hint_string": "%d/%d:%s" % [
			TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "NoisePropertyTarget"],
		"usage": PROPERTY_USAGE_DEFAULT
	})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"noise_speed":             noise_speed = value;             return true
		&"noise_direction":         noise_direction = value;         return true
		&"noise_type":              noise_type = value;              return true
		&"noise_frequency":         noise_frequency = value;         return true
		&"noise_seed":              noise_seed = value;              return true
		&"fractal_type":            fractal_type = value;            return true
		&"fractal_octaves":         fractal_octaves = value;         return true
		&"lacunarity":              lacunarity = value;              return true
		&"fractal_gain":            fractal_gain = value;            return true
		&"domain_warp_enabled":     domain_warp_enabled = value;     return true
		&"domain_warp_amplitude":   domain_warp_amplitude = value;   return true
		&"domain_warp_frequency":   domain_warp_frequency = value;   return true
		&"clamp_min":               clamp_min = value;               return true
		&"clamp_max":               clamp_max = value;               return true
	return super._set(property, value)


func _get(property: StringName) -> Variant:
	match property:
		&"noise_speed":             return noise_speed
		&"noise_direction":         return noise_direction
		&"noise_type":              return noise_type
		&"noise_frequency":         return noise_frequency
		&"noise_seed":              return noise_seed
		&"fractal_type":            return fractal_type
		&"fractal_octaves":         return fractal_octaves
		&"lacunarity":              return lacunarity
		&"fractal_gain":            return fractal_gain
		&"domain_warp_enabled":     return domain_warp_enabled
		&"domain_warp_amplitude":   return domain_warp_amplitude
		&"domain_warp_frequency":   return domain_warp_frequency
		&"clamp_min":               return clamp_min
		&"clamp_max":               return clamp_max
	return super._get(property)


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _noise: FastNoiseLite = null
var _noise_time: float = 0.0


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

## Noise is continuous — keep ticking after animate_in peak.
func _needs_sustain() -> bool:
	return true


func _on_animate_start(target: Node) -> void:
	super._on_animate_start(target)
	# Only reset time and rebuild noise on a fresh start.
	# Re-triggering while playing continues the noise trajectory smoothly.
	if _target_progress <= 0.0 or _noise == null:
		_noise_time = 0.0
		_setup_noise()


func _apply_effect(progress: float, _target: Node) -> void:
	# _current_delta is set by JuiceEffectBase.tick() each frame.
	# Same pattern as Noise2DJuiceEffect._advance_noise_time(_current_delta).
	_advance_noise_time(_current_delta)

	for entry: NoisePropertyTarget in property_targets:
		if entry == null or not entry.is_configured():
			continue
		if not is_instance_valid(entry._resolved_node):
			continue
		if entry._base_value == null:
			continue

		var delta: Variant = _compute_noise_delta(entry, progress)
		if delta == null:
			continue

		entry._resolved_node.set_indexed(
			entry.property_path, entry._base_value + delta)


func _restore_to_natural(target: Node) -> void:
	super._restore_to_natural(target)
	_noise_time = 0.0


# =============================================================================
# NOISE CORE
# (Algorithm mirrors Noise2DJuiceEffect — intentional duplication, GDScript
#  has no mixins. Keep in sync with Noise2D/3D if algorithm changes.)
# =============================================================================

func _advance_noise_time(delta: float) -> void:
	# Guard: only advance when actually playing (same guard as Noise2D).
	if _target_progress > 0.0:
		_noise_time += delta


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


## Sample a single noise value at the current time.
## y_offset separates channels: 0.0 = X, 100.0 = Y, 200.0 = Z, 300.0 = W.
func _sample_noise(y_offset: float) -> float:
	if _noise == null:
		return 0.0
	var t := _noise_time * noise_speed
	var raw := _noise.get_noise_2d(t, y_offset)
	match noise_direction:
		NoiseDirection.POSITIVE_ONLY: raw = absf(raw)
		NoiseDirection.NEGATIVE_ONLY: raw = -absf(raw)
	return clampf(raw, clamp_min, clamp_max)


## Compute the noise delta for one entry at the given progress (0–1).
## Returns Variant typed to match the entry's _detected_type, or null if unknown.
func _compute_noise_delta(entry: NoisePropertyTarget, progress: float) -> Variant:
	if progress <= 0.0:
		return null

	match entry._detected_type:
		TYPE_FLOAT:
			return entry.amplitude_float * _sample_noise(0.0) * progress

		TYPE_VECTOR2:
			return Vector2(
				entry.amplitude_vec2.x * _sample_noise(0.0),
				entry.amplitude_vec2.y * _sample_noise(100.0)) * progress

		TYPE_VECTOR3:
			return Vector3(
				entry.amplitude_vec3.x * _sample_noise(0.0),
				entry.amplitude_vec3.y * _sample_noise(100.0),
				entry.amplitude_vec3.z * _sample_noise(200.0)) * progress

		TYPE_COLOR:
			# amplitude_color applies uniformly to all channels.
			return Color(
				entry.amplitude_color * _sample_noise(0.0),
				entry.amplitude_color * _sample_noise(100.0),
				entry.amplitude_color * _sample_noise(200.0),
				entry.amplitude_color * _sample_noise(300.0)) * progress

	# Unknown type (TYPE_NIL) — can't compute delta safely.
	return null
