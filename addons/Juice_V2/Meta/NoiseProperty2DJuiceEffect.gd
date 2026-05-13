## 2D-domain leaf for [NoisePropertyJuiceEffectBase].
## Noise-drives arbitrary Node2D properties with FastNoiseLite oscillation.

# ============================================================================
# WHAT: 2D-domain wrapper for NoisePropertyJuiceEffectBase.
# WHY:  Registers this effect under Juice2DRecipe._CONCRETE_EFFECTS so
#       the inspector dropdown shows it only on Juice2D nodes.
#       All behavior is inherited from NoisePropertyJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Add any behavior beyond NoisePropertyJuiceEffectBase.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBase2D.svg")
class_name NoiseProperty2DJuiceEffect
extends NoisePropertyJuiceEffectBase


func _get_domain_tag() -> String:
	return "2D"
