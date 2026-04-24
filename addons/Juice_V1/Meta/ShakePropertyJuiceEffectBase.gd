## Drives arbitrary node properties with sine-wave + random shake oscillation.
##
## Shake frequency and randomness blend are shared across ALL property targets.
## Each target has its own strength. Uses the animate-in/out envelope from JuiceEffectBase.

# =============================================================================
# WHAT: Shake-drives a list of arbitrary properties on any nodes.
#       Uses sin(time * frequency) blended with per-frame randomness.
#       A per-entry phase offset makes each property move independently.
#       Progress envelope (inherited from JuiceEffectBase) scales intensity.
# WHY:  Provides a domain-agnostic procedural shake effect for the Property family.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# DOES NOT: Use domain delta aggregation — writes via set_indexed() directly.
# NOTE: Shake algorithm mirrors Shake2DJuiceEffect — intentional duplication
#       since GDScript has no mixins.
# =============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseProperty.svg")
class_name PropertyShakeJuiceEffectBase
extends PropertyJuiceEffectBase


# =============================================================================
# CONFIGURATION — Shake settings (shared across all property targets)
# =============================================================================

## Oscillation cycles per second. Higher = more rapid shaking.
var shake_frequency: float = 20.0
## 0.0 = pure sine wave (smooth). 1.0 = pure random (chaotic). Blend in-between.
var randomness: float = 0.5


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

# Required to support strongly-typed property inspector rendering for different concrete effects.
func _get_target_resource_type() -> String:
	return "ShakePropertyTarget"


func _init() -> void:
	# Both flags required — same rationale as NoisePropertyJuiceEffectBase._init().
	_subclass_owns_effect_group = true
	_subclass_owns_prop_layout = true


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	props.append({"name": "Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "shake_frequency", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,200.0,0.1,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "randomness", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append_array(_get_effect_base_properties())

	props.append({"name": "Property Targets", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({
		"name": "property_targets",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_ARRAY_TYPE,
		"hint_string": "%d/%d:%s" % [
			TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "ShakePropertyTarget"],
		"usage": PROPERTY_USAGE_DEFAULT
	})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"shake_frequency": shake_frequency = value; return true
		&"randomness":      randomness = value;      return true
	return super._set(property, value)


func _get(property: StringName) -> Variant:
	match property:
		&"shake_frequency": return shake_frequency
		&"randomness":      return randomness
	return super._get(property)


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _shake_time: float = 0.0
var _shake_seed: float = 0.0


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

## Shake is a continuous procedural effect that must keep ticking even when progress reaches 1.0 (peak hold).
func _needs_sustain() -> bool:
	return true


## Captures base values and resets the discrete tick timer before the first frame.
func _on_animate_start(target: Node) -> void:
	super._on_animate_start(target)
	# Fresh randomized seed each trigger — each play sounds different.
	_shake_seed = randf() * 1000.0
	_shake_time = 0.0


## Samples random noise discretely based on the frequency timer and writes the resulting delta to the engine property.
func _apply_effect(progress: float, _target: Node) -> void:
	_shake_time += _current_delta  # Same pattern as Shake2DJuiceEffect._apply_effect

	for i: int in property_targets.size():
		var entry: ShakePropertyTarget = property_targets[i]
		if entry == null or not entry.is_configured():
			continue
		if not is_instance_valid(entry._resolved_node):
			continue
		if entry._base_value == null:
			continue

		# Per-entry phase offset ensures different properties oscillate independently.
		var phase_offset := float(i) * 73.6

		var delta: Variant = _compute_shake_delta(entry, progress, phase_offset)
		if delta == null:
			continue

		entry._resolved_node.set_indexed(
			entry.property_path, entry._base_value + delta)


## Undoes the shake delta from the target property to cleanly reset it on stop.
func _restore_to_natural(target: Node) -> void:
	super._restore_to_natural(target)
	_shake_time = 0.0


# =============================================================================
# SHAKE CORE
# (Algorithm mirrors Shake2DJuiceEffect — intentional duplication.
#  Keep in sync with Shake2D/3D if the algorithm changes.)
# =============================================================================

# Compute the shake delta for one entry at the given progress (0–1).
# phase_offset: unique per-entry value so properties shake out of phase.
func _compute_shake_delta(
	entry: ShakePropertyTarget, progress: float, phase_offset: float
) -> Variant:
	if progress <= 0.0:
		return null

	var freq := _shake_time * shake_frequency * TAU

	match entry._detected_type:
		TYPE_FLOAT:
			var sv := sin(freq + _shake_seed + phase_offset)
			var rv := randf_range(-1.0, 1.0)
			return lerpf(sv, rv, randomness) * entry.strength_float * progress

		TYPE_VECTOR2:
			var sx := sin(freq + _shake_seed + phase_offset)
			var sy := sin(freq * 1.3 + _shake_seed + phase_offset + 100.0)
			var rx := randf_range(-1.0, 1.0)
			var ry := randf_range(-1.0, 1.0)
			return Vector2(
				lerpf(sx, rx, randomness) * entry.strength_vec2.x,
				lerpf(sy, ry, randomness) * entry.strength_vec2.y) * progress

		TYPE_VECTOR3:
			var sx := sin(freq + _shake_seed + phase_offset)
			var sy := sin(freq * 1.3 + _shake_seed + phase_offset + 100.0)
			var sz := sin(freq * 1.7 + _shake_seed + phase_offset + 200.0)
			var rx := randf_range(-1.0, 1.0)
			var ry := randf_range(-1.0, 1.0)
			var rz := randf_range(-1.0, 1.0)
			return Vector3(
				lerpf(sx, rx, randomness) * entry.strength_vec3.x,
				lerpf(sy, ry, randomness) * entry.strength_vec3.y,
				lerpf(sz, rz, randomness) * entry.strength_vec3.z) * progress

		TYPE_COLOR:
			var sr := sin(freq + _shake_seed + phase_offset)
			var sg := sin(freq * 1.3 + _shake_seed + phase_offset + 100.0)
			var sb := sin(freq * 1.7 + _shake_seed + phase_offset + 200.0)
			var sa := sin(freq * 2.1 + _shake_seed + phase_offset + 300.0)
			var rr := randf_range(-1.0, 1.0)
			var rg := randf_range(-1.0, 1.0)
			var rb := randf_range(-1.0, 1.0)
			var ra := randf_range(-1.0, 1.0)
			var s := entry.strength_color
			return Color(
				lerpf(sr, rr, randomness) * s,
				lerpf(sg, rg, randomness) * s,
				lerpf(sb, rb, randomness) * s,
				lerpf(sa, ra, randomness) * s) * progress

	return null  # TYPE_NIL — unknown type, can't compute.
