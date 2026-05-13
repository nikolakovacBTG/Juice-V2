## Control-domain leaf for [NoisePropertyJuiceEffectBase].
## Noise-drives arbitrary Control properties with FastNoiseLite oscillation.

# ============================================================================
# WHAT: Control-domain wrapper for NoisePropertyJuiceEffectBase.
# WHY:  Registers this effect under JuiceControlRecipe._CONCRETE_EFFECTS so
#       the inspector dropdown shows it only on Control-domain Juice nodes.
#       All behavior is inherited from NoisePropertyJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Add any behavior beyond NoisePropertyJuiceEffectBase.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseControl.svg")
class_name NoisePropertyControlJuiceEffect
extends NoisePropertyJuiceEffectBase


func _get_domain_tag() -> String:
	return "Control"
