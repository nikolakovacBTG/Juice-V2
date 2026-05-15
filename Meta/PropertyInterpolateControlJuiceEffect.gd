## Control-domain wrapper for [PropertyInterpolateJuiceEffectBase].
## Interpolates arbitrary named Control properties from a FROM to a TO value.

# ============================================================================
# WHAT: Control-domain leaf for the Interpolate property effect family.
# WHY:  Registers the effect under JuiceControlRecipe._CONCRETE_EFFECTS so the
#       inspector dropdown shows it only for Control-domain Juice nodes.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Add any behavior beyond PropertyInterpolateJuiceEffectBase.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseProperty.svg")
class_name PropertyInterpolateControlJuiceEffect
extends PropertyInterpolateJuiceEffectBase


func _get_domain_tag() -> String:
	return "Control"
