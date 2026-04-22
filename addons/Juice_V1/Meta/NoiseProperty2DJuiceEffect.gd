## 2D-domain wrapper for NoisePropertyJuiceEffectBase.
##
## Registers the effect in Juice2DRecipe._CONCRETE_EFFECTS so it
## appears in the inspector dropdown on Juice2D nodes.

# ============================================================================
# WHAT: 2D-domain wrapper for NoisePropertyJuiceEffectBase.
# WHY:  Registers the effect in Juice2DRecipe._CONCRETE_EFFECTS so it
#       appears in the inspector dropdown on Juice2D nodes.
#       All behavior is inherited from NoisePropertyJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase2D.svg")
class_name NoiseProperty2DJuiceEffect
extends NoisePropertyJuiceEffectBase
