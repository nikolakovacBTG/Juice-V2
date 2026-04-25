## Interpolates arbitrary node properties from a FROM value to a TO value.
##
## Each InterpolatePropertyTarget entry specifies its own node, property,
## capture modes, and from/to values. GDScript lerp() handles float, Vector2,
## Vector3, and Color polymorphically. int is lerped as float then cast.

# =============================================================================
# WHAT: Drives a list of arbitrary properties from configurable From to To
#       values using the JuiceEffectBase animate_in/out envelope for easing.
# WHY:  Provides a domain-agnostic generic From/To interpolation effect for the Property family.
#       Any exported property on any node can be tweened: energy, modulate:a,
#       shader_parameter paths, custom vars — all via set_indexed().
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# DOES NOT: Use domain delta aggregation — writes via set_indexed() directly.
# DOES NOT: Sustain. set_indexed() is a persistent write — last value at
#           progress=1.0 holds without ticking. Animate_out reverses if enabled.
# NOTE: lerp() is polymorphic in GDScript 4 for float/Vector2/Vector3/Color.
#       int is special-cased: lerpf(from, to, t) cast back to int.
# =============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseProperty.svg")
class_name PropertyInterpolateJuiceEffectBase
extends PropertyJuiceEffectBase


# =============================================================================
# CONFIGURATION
# =============================================================================

func _init() -> void:
	_subclass_owns_effect_group = true


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

## Tell the base class which resource type to use for the typed array hint.
# Required to support strongly-typed property inspector rendering for different concrete effects.
func _get_target_resource_type() -> String:
	return "InterpolatePropertyTarget"


# No additional properties beyond the base Effect group + Property Targets.
# Full layout is inherited from PropertyJuiceEffectBase._get_property_list().


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

## Interpolate does not need frame-by-frame sustain — set_indexed() writes
## are persistent. The last write at progress=1.0 holds naturally.
func _needs_sustain() -> bool:
	return false


## Captures dynamic ON_TRIGGER From/To values at the exact moment of playback, ensuring accurate start points when interrupted or chained.
func _on_animate_start(target: Node) -> void:
	# Capture base values (restore target) and resolve nodes.
	super._on_animate_start(target)
	# Capture ON_TRIGGER from/to values from the current property state.
	for entry: InterpolatePropertyTarget in property_targets:
		if entry != null and entry.is_configured():
			entry.capture_runtime_values()


## Iterates over the target entries and performs polymorphic interpolation (lerp), mapping 0-1 progress to property values directly on the engine target.
func _apply_effect(progress: float, _target: Node) -> void:
	for entry: InterpolatePropertyTarget in property_targets:
		if entry == null or not entry.is_configured():
			continue
		if not is_instance_valid(entry._resolved_node):
			continue
		var value: Variant = _compute_lerp(entry, progress)
		if value == null:
			continue
		entry._resolved_node.set_indexed(entry.property_path, value)


# =============================================================================
# LERP CORE
# =============================================================================

# Compute the interpolated value for one entry at the given progress (0–1).
# Returns null for TYPE_NIL (unknown) or mismatched from/to types.
func _compute_lerp(entry: InterpolatePropertyTarget, progress: float) -> Variant:
	var from_val: Variant = entry.get_from()
	var to_val:   Variant = entry.get_to()

	if from_val == null or to_val == null:
		return null

	# TYPE_INT: lerp as float, cast back to int for clean integer properties.
	if entry._detected_type == TYPE_INT:
		return int(lerpf(float(from_val), float(to_val), progress))

	# All other supported types: GDScript lerp() is polymorphic.
	# float, Vector2, Vector3, Color all work natively.
	if entry._detected_type in [TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR]:
		return lerp(from_val, to_val, progress)

	# TYPE_NIL / unsupported — emit on first frame only to avoid spam.
	if progress < 0.02:
		JuiceLogger.warn(self, _get_domain_tag(),
				"property '%s' type unknown — set property_path first" % entry.property_path,
				debug_enabled)
	return null
