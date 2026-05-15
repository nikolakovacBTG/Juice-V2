## Drives arbitrary node properties with procedural FastNoiseLite oscillation.
##
## Shared noise settings (speed, type, frequency, seed, fractal, domain warp)
## apply across ALL property targets. Each target carries its own amplitude via
## [NoisePropertyTarget]. The animate-in / animate-out progress envelope from
## [JuiceEffectBase] scales intensity so noise fades in and out smoothly.

# =============================================================================
# WHAT: Noise-drives a list of arbitrary properties on any nodes.
#       Uses FastNoiseLite with multi-channel sampling (Y offset per axis).
#       Progress envelope (from JuiceEffectBase) scales intensity each frame.
# WHY:  Provides domain-agnostic continuous noise perturbation for the Property
#       family. Targets any property on any node — not limited to position,
#       rotation, or scale. Routes through JuiceLedger so stacking with other
#       Property effects is automatic and conflict-free.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Write to nodes directly — PropertyJuiceEffectBase._apply_effect()
#           routes all writes via JuiceLedger.
#           Does not support discrete property types (bool, String, etc.) —
#           noise displacement is continuous and meaningful only for numeric types.
#           Does not handle shader parameters via picker — type
#           "material:shader_parameter/name" manually; set_indexed() handles it.
# NOTE: The noise algorithm here mirrors NoiseControlJuiceEffect /
#       Noise2DJuiceEffect / Noise3DJuiceEffect. GDScript has no mixins, so
#       it is intentionally duplicated and kept in sync manually.
# =============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseProperty.svg")
class_name NoisePropertyJuiceEffectBase
extends PropertyJuiceEffectBase


# =============================================================================
# ENUMS
# =============================================================================

enum NoiseDirection {
	BOTH,           ## Noise samples both positive and negative values.
	POSITIVE_ONLY,  ## Noise samples are abs() — always positive displacement.
	NEGATIVE_ONLY   ## Noise samples are -abs() — always negative displacement.
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
## Number of fractal layers (visible when fractal_type is not None).
var fractal_octaves: int = 1
## Frequency multiplier per fractal layer.
var lacunarity: float = 2.0
## Amplitude multiplier per fractal layer.
var fractal_gain: float = 0.5

## Enable domain warp for added organic complexity.
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
# LIFECYCLE
# =============================================================================

func _init() -> void:
	# This class owns its own _get_property_list() which emits property_targets.
	# Setting this flag prevents PropertyJuiceEffectBase from emitting a second
	# property_targets entry, which would create duplicate rows in the inspector.
	_subclass_owns_prop_layout = true


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================




func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# --- Noise group: all noise-specific settings ---
	# Timing fields (duration_in, start_delay, etc.) are emitted by JuiceEffectBase's
	# _get_property_list() under the "Effect" group. We use "Noise" here to keep
	# the two groups visually distinct without a conflicting duplicate header.
	props.append({"name": "Noise", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "noise_speed", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,100.0,0.01,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "noise_direction", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Both,Positive Only,Negative Only",
		"usage": PROPERTY_USAGE_DEFAULT})

	# --- Noise Pattern subgroup: FastNoiseLite configuration ---
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

	# Fractal settings (hidden when fractal_type is NONE)
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

	# Domain warp settings (hidden unless enabled)
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
	props.append({"name": "clamp_min", "type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "clamp_max", "type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT})

	# --- Property Targets typed array ---
	# PROPERTY_HINT_TYPE_STRING with "TYPE_OBJECT/RESOURCE_TYPE:ClassName" is the
	# correct form for a typed Array[Resource] shown in the inspector.
	props.append({
		"name": "Property Targets", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({
		"name": "property_targets",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%d/%d:%s" % [
			TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "NoisePropertyTarget"],
		"usage": PROPERTY_USAGE_DEFAULT
	})

	return props


## Tells PropertyJuiceEffectBase which resource subclass to use when the
## parent's _get_property_list() is queried (not active here since
## _subclass_owns_prop_layout = true, but kept for API completeness).
func _get_target_resource_type() -> String:
	return "NoisePropertyTarget"


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
	return false


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
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _noise: FastNoiseLite = null
var _noise_time: float = 0.0


# =============================================================================
# LIFECYCLE
# =============================================================================

## Noise is continuous — keep ticking after animate_in peak.
func _needs_sustain() -> bool:
	return true


## Sets up the noise generator and registers property paths in the Ledger.
## Resets noise time only on a fresh start, not on a mid-play re-trigger,
## so a re-triggered animation continues the noise trajectory smoothly.
func _on_animate_start(target: Node) -> void:
	# super registers all property paths in the Ledger so base values are
	# captured before any _compute_property_value() call reads them.
	super._on_animate_start(target)
	# Reset and rebuild on fresh start only. _target_progress is 0.0 when
	# starting from idle; > 0.0 means the effect was re-triggered mid-play.
	if _target_progress <= 0.0 or _noise == null:
		_noise_time = 0.0
		_setup_noise()
	var actual_seed := _noise.seed if _noise != null else -1
	JuiceLogger.log_capture(self, _get_domain_tag(), "noise_config",
			{"seed": actual_seed, "speed": noise_speed,
			"direction": NoiseDirection.keys()[noise_direction],
			"type": noise_type, "frequency": noise_frequency,
			"clamp": "[%.2f, %.2f]" % [clamp_min, clamp_max]},
			debug_enabled)


## Resets noise state and delegates base-value restoration to the Ledger.
func _restore_to_natural(target: Node) -> void:
	JuiceLogger.log_info(self, _get_domain_tag(),
			"restore_to_natural: noise_time=%.3f targets=%d" % [
			_noise_time, property_targets.size()], debug_enabled)
	super._restore_to_natural(target)
	_noise_time = 0.0


# =============================================================================
# PUBLIC API
# =============================================================================

## Advances noise time for this frame, then delegates per-entry Ledger routing
## to [method PropertyJuiceEffectBase._apply_effect].
## Noise time must advance ONCE per frame before any entries are processed —
## advancing per-entry would sample different time positions for the same frame.
func _apply_effect(progress: float, target: Node) -> void:
	_advance_noise_time(_current_delta)
	super._apply_effect(progress, target)


# =============================================================================
# CORE LOGIC
# =============================================================================

# Finds the NoisePropertyTarget entry for [param prop] by iterating property_targets.
# Returns null if no configured entry matches.
func _find_noise_entry(prop: String) -> NoisePropertyTarget:
	for pt in property_targets:
		var entry := pt as NoisePropertyTarget
		if entry != null and entry.property_path == prop:
			return entry
	return null


# Returns the absolute desired value for [param prop] at the given progress.
# Computes base_val + noise_delta so that PropertyJuiceEffectBase._apply_effect()
# can derive the correct Ledger delta (additive for numeric types, factor for Color).
# Returns base_val unchanged when progress is 0 (no displacement) or when no entry
# is found for the given prop, so the Ledger writes a no-op delta.
func _compute_property_value(progress: float, prop: String, base_val: Variant, _target: Node) -> Variant:
	if progress <= 0.0:
		return base_val

	var entry := _find_noise_entry(prop)
	if entry == null:
		return base_val

	var delta: Variant = _compute_noise_delta(entry, progress)
	if delta == null:
		return base_val

	var result: Variant = base_val + delta
	JuiceLogger.log_delta(self, _get_domain_tag(), progress,
			{"noise_time": _noise_time, "prop": prop,
			"delta": delta, "result": result},
			"property", debug_enabled)
	return result


# Compute the noise delta for one entry at the given progress (0–1).
# Returns a Variant typed to match the entry's _detected_type, or null if unsupported.
# The delta is always near zero (amplitude * sample); adding it to base_val
# gives the desired value, which the base class then routes via the Ledger.
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
			# Adding a Color delta to base_val gives the absolute desired Color;
			# PropertyJuiceEffectBase converts to a multiplicative Ledger factor.
			return Color(
				entry.amplitude_color * _sample_noise(0.0),
				entry.amplitude_color * _sample_noise(100.0),
				entry.amplitude_color * _sample_noise(200.0),
				entry.amplitude_color * _sample_noise(300.0)) * progress

	# Unsupported type (e.g. TYPE_NIL, TYPE_BOOL, TYPE_STRING).
	# Noise displacement is only meaningful for continuous numeric types.
	return null


# =============================================================================
# HELPERS
# =============================================================================

# Instantiates and configures the FastNoiseLite resource if missing.
# Always rebuilds from current inspector values — config changes take effect
# on the next animate-in.
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


# Drives the 1D noise sample position forward based on frame delta and noise_speed.
# Only advances while playing (_target_progress > 0.0) — freezes during idle
# so noise restarts cleanly from _noise_time = 0.0 on next animate-in.
func _advance_noise_time(delta: float) -> void:
	if _target_progress > 0.0:
		_noise_time += delta


# Sample a single noise value at the current noise time.
# y_offset separates channels: 0.0 = X/float, 100.0 = Y, 200.0 = Z, 300.0 = W.
# All channels share one FastNoiseLite instance; the offset makes them uncorrelated.
func _sample_noise(y_offset: float) -> float:
	if _noise == null:
		return 0.0
	var t := _noise_time * noise_speed
	var raw := _noise.get_noise_2d(t, y_offset)
	match noise_direction:
		NoiseDirection.POSITIVE_ONLY: raw = absf(raw)
		NoiseDirection.NEGATIVE_ONLY: raw = -absf(raw)
	return clampf(raw, clamp_min, clamp_max)
