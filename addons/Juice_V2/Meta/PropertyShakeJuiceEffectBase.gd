## Drives arbitrary node properties with a sine-blend shake oscillation.
##
## Shared settings (frequency, randomness) apply across ALL property targets.
## Each target carries its own amplitude via [ShakePropertyTarget].
## The animate-in / animate-out progress envelope from [JuiceEffectBase] scales
## intensity so shake fades in and out smoothly.

# =============================================================================
# WHAT: Sine+random shake for arbitrary named properties via the Juice Ledger.
#       Uses sin(time * frequency * TAU + seed + offset) blended with per-frame
#       randomness. Progress envelope scales intensity each frame.
# WHY:  Provides domain-agnostic oscillating shake for the Property family.
#       Targets any numeric property on any node — not limited to position,
#       rotation, or scale. Routes through JuiceLedger so stacking with other
#       Property effects is automatic and conflict-free.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Write to nodes directly — PropertyJuiceEffectBase._apply_effect()
#           routes all writes via JuiceLedger.
#           Does not support discrete property types (bool, String, etc.) —
#           shake displacement is continuous and only meaningful for numeric types.
# NOTE: The oscillation core (sine-blend + seed) mirrors ShakeControlJuiceEffect.
#       GDScript has no mixins, so it is intentionally duplicated and kept in sync
#       manually. Any shake-algorithm change must be applied in both places.
# =============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseProperty.svg")
class_name PropertyShakeJuiceEffectBase
extends PropertyJuiceEffectBase


# =============================================================================
# LIFECYCLE
# =============================================================================

func _init() -> void:
	# This class owns its own _get_property_list() which emits property_targets.
	# Setting this flag prevents PropertyJuiceEffectBase from emitting a second
	# property_targets entry, which would create duplicate rows in the inspector.
	_subclass_owns_prop_layout = true


# =============================================================================
# CONFIGURATION — Shake settings (shared across all property targets)
# =============================================================================

## How many oscillation cycles per second. Higher values produce faster shaking.
var shake_frequency: float = 20.0

## Blend ratio between sine wave (0.0) and pure randomness (1.0).
## 0 = smooth, periodic oscillation. 1 = entirely random per-frame jitter.
var randomness: float = 0.5:
	set(value): randomness = clampf(value, 0.0, 1.0)


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# --- Shake group: all shake-specific settings ---
	# Timing fields (duration_in, start_delay, etc.) are emitted by JuiceEffectBase's
	# _get_property_list() under the "Effect" group. We use "Shake" here to keep
	# the two groups visually distinct without a conflicting duplicate header.
	props.append({"name": "Shake", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "shake_frequency", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,100.0,0.1,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "randomness", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
		"usage": PROPERTY_USAGE_DEFAULT})

	# --- Property Targets typed array ---
	# PROPERTY_HINT_TYPE_STRING with "TYPE_OBJECT/RESOURCE_TYPE:ClassName" is the
	# correct form for a typed Array[Resource] shown in the inspector.
	props.append({"name": "Property Targets", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({
		"name": "property_targets",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%d/%d:%s" % [
			TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "ShakePropertyTarget"],
		"usage": PROPERTY_USAGE_DEFAULT
	})

	return props


## Tells PropertyJuiceEffectBase which resource subclass to use when the
## parent's _get_property_list() is queried (not active here since
## _subclass_owns_prop_layout = true, but kept for API completeness).
func _get_target_resource_type() -> String:
	return "ShakePropertyTarget"


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"shake_frequency":  shake_frequency = value;  return true
		&"randomness":       randomness = value;        return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"shake_frequency":  return shake_frequency
		&"randomness":       return randomness
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

# Accumulates elapsed real time while the effect is playing.
# Drives the sine cursor: sin(time * frequency * TAU + seed).
var _shake_time: float = 0.0

# Random per-play offset in the noise field so two simultaneous shakes
# on different nodes don't phase-lock and look identical.
var _shake_seed: float = 0.0


# =============================================================================
# LIFECYCLE
# =============================================================================

## Shake must keep ticking to sustain oscillation at the peak of animate-in.
func _needs_sustain() -> bool:
	return true


## Resets shake state and registers property paths in the Ledger.
## Seed is randomised fresh each play so repeated triggers never pattern-match.
func _on_animate_start(target: Node) -> void:
	# super registers all property paths in the Ledger — must run before any
	# _sample_shake() call reads a base value from the Ledger.
	super._on_animate_start(target)
	# Always reset on a fresh start; preserve time on mid-play re-trigger only if
	# already running (non-zero _shake_time) so continuity is not broken.
	if _shake_time <= 0.0:
		_shake_seed = randf() * 1000.0
	JuiceLogger.log_capture(self, _get_domain_tag(), "shake_config",
			{"seed": _shake_seed, "frequency": shake_frequency,
			"randomness": randomness, "targets": property_targets.size()},
			debug_enabled)


## Resets shake state and delegates base-value restoration to the Ledger.
func _restore_to_natural(target: Node) -> void:
	JuiceLogger.log_info(self, _get_domain_tag(),
			"restore_to_natural: shake_time=%.3f targets=%d" % [
			_shake_time, property_targets.size()], debug_enabled)
	super._restore_to_natural(target)
	_shake_time = 0.0


# =============================================================================
# PUBLIC API
# =============================================================================

## Advances shake time for this frame, then delegates per-entry Ledger routing
## to [method PropertyJuiceEffectBase._apply_effect].
## Time must advance ONCE per frame before any entries are processed —
## advancing per-entry would sample different time positions for the same frame.
func _apply_effect(progress: float, target: Node) -> void:
	_shake_time += _current_delta
	super._apply_effect(progress, target)


# =============================================================================
# CORE LOGIC
# =============================================================================

# Finds the ShakePropertyTarget entry for [param prop] by iterating property_targets.
# Returns null if no configured entry matches the property path.
func _find_shake_entry(prop: String) -> ShakePropertyTarget:
	for pt in property_targets:
		var entry := pt as ShakePropertyTarget
		if entry != null and entry.property_path == prop:
			return entry
	return null


# Returns the absolute desired value for [param prop] at the given progress.
# Computes base_val + shake_delta so PropertyJuiceEffectBase._apply_effect()
# derives the correct Ledger delta (additive for numeric types, factor for Color).
# Returns base_val unchanged when progress is 0 (no displacement) or when no
# entry is found for the given prop — the Ledger then writes a no-op zero delta.
func _compute_property_value(progress: float, prop: String, base_val: Variant, _target: Node) -> Variant:
	if progress <= 0.0:
		return base_val

	var entry := _find_shake_entry(prop)
	if entry == null:
		return base_val

	var delta: Variant = _compute_shake_delta(entry, progress)
	if delta == null:
		return base_val

	var result: Variant = base_val + delta
	JuiceLogger.log_delta(self, _get_domain_tag(), progress,
			{"shake_time": _shake_time, "prop": prop,
			"delta": delta, "result": result},
			"property", debug_enabled)
	return result


# Computes the typed shake delta for one entry at the given progress.
# Multi-axis types use different y_offsets into the sine field so each axis
# oscillates independently — same as NoiseProperty's channel-separation approach.
# Returns null for unsupported types (e.g. TYPE_NIL, TYPE_BOOL).
func _compute_shake_delta(entry: ShakePropertyTarget, progress: float) -> Variant:
	if progress <= 0.0:
		return null

	match entry._detected_type:
		TYPE_FLOAT, TYPE_INT:
			return entry.amplitude_float * _sample_shake(0.0) * progress

		TYPE_VECTOR2:
			return Vector2(
				entry.amplitude_vec2.x * _sample_shake(0.0),
				entry.amplitude_vec2.y * _sample_shake(100.0)) * progress

		TYPE_VECTOR3:
			return Vector3(
				entry.amplitude_vec3.x * _sample_shake(0.0),
				entry.amplitude_vec3.y * _sample_shake(100.0),
				entry.amplitude_vec3.z * _sample_shake(200.0)) * progress

		TYPE_COLOR:
			# amplitude_color applies uniformly to all channels.
			# Adding a Color delta to base_val gives the desired absolute Color;
			# PropertyJuiceEffectBase converts it to a multiplicative Ledger factor.
			return Color(
				entry.amplitude_color * _sample_shake(0.0),
				entry.amplitude_color * _sample_shake(100.0),
				entry.amplitude_color * _sample_shake(200.0),
				entry.amplitude_color * _sample_shake(300.0)) * progress

	# Unsupported type (e.g. TYPE_NIL, TYPE_BOOL, TYPE_STRING).
	# Shake displacement is only meaningful for continuous numeric types.
	return null


# =============================================================================
# HELPERS
# =============================================================================

# Samples one shake value for the current frame at the given axis offset.
# y_offset separates channels so they oscillate independently:
#   0.0 = float / X axis,  100.0 = Y axis,  200.0 = Z axis,  300.0 = Alpha / W.
# Returns a value in approximately [-amplitude, +amplitude] before scaling.
func _sample_shake(y_offset: float) -> float:
	var t := _shake_time * shake_frequency * TAU
	var sine_val := sin(t + _shake_seed + y_offset)
	if randomness > 0.0:
		var rand_val := randf_range(-1.0, 1.0)
		return lerpf(sine_val, rand_val, randomness)
	return sine_val
