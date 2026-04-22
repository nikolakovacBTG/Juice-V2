## 3D-domain wrapper for NoisePropertyJuiceEffectBase.
##
## Registers the effect in Juice3DRecipe._CONCRETE_EFFECTS so it
## appears in the inspector dropdown on Juice3D nodes.

# ============================================================================
# WHAT: 3D-domain wrapper for NoisePropertyJuiceEffectBase.
# WHY:  Registers the effect in Juice3DRecipe._CONCRETE_EFFECTS so it
#       appears in the inspector dropdown on Juice3D nodes.
#       All behavior is inherited from NoisePropertyJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name NoiseProperty3DJuiceEffect
extends NoisePropertyJuiceEffectBase
