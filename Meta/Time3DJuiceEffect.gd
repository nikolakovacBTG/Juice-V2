## 3D-domain wrapper for TimeJuiceEffectBase.
##
## Registers the effect in Juice3DRecipe._CONCRETE_EFFECTS so it
## appears in the inspector dropdown on Juice3D nodes.

# ============================================================================
# WHAT: 3D-domain wrapper for TimeJuiceEffectBase.
# WHY:  Registers the effect in Juice3DRecipe._CONCRETE_EFFECTS so it
#       appears in the inspector dropdown on Juice3D nodes.
#       All behavior is inherited from TimeJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V2/Meta/)
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceUtilityTimeCoord.svg")
class_name Time3DJuiceEffect
extends TimeJuiceEffectBase
