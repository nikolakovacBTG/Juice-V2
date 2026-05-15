## Control-domain leaf for [PropertyNoiseJuiceEffectBase].
## Noise-drives arbitrary Control properties with FastNoiseLite oscillation.

# ============================================================================
# WHAT: Control-domain wrapper for PropertyNoiseJuiceEffectBase.
# WHY:  Registers this effect under JuiceControlRecipe._CONCRETE_EFFECTS so
#       the inspector dropdown shows it only on Control-domain Juice nodes.
#       All behavior is inherited from PropertyNoiseJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Add any behavior beyond PropertyNoiseJuiceEffectBase.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseProperty.svg")
class_name PropertyNoiseControlJuiceEffect
extends PropertyNoiseJuiceEffectBase


func _get_domain_tag() -> String:
	return "Control"
