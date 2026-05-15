## 2D-domain leaf for [PropertyNoiseJuiceEffectBase].
## Noise-drives arbitrary Node2D properties with FastNoiseLite oscillation.

# ============================================================================
# WHAT: 2D-domain wrapper for PropertyNoiseJuiceEffectBase.
# WHY:  Registers this effect under Juice2DRecipe._CONCRETE_EFFECTS so
#       the inspector dropdown shows it only on Juice2D nodes.
#       All behavior is inherited from PropertyNoiseJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Add any behavior beyond PropertyNoiseJuiceEffectBase.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseProperty.svg")
class_name PropertyNoise2DJuiceEffect
extends PropertyNoiseJuiceEffectBase


func _get_domain_tag() -> String:
	return "2D"
