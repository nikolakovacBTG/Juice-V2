## 2D-domain wrapper for TimeJuiceEffectBase.
##
## Registers the effect in Juice2DRecipe._CONCRETE_EFFECTS so it
## appears in the inspector dropdown on Juice2D nodes.

# ============================================================================
# WHAT: 2D-domain wrapper for TimeJuiceEffectBase.
# WHY:  Registers the effect in Juice2DRecipe._CONCRETE_EFFECTS so it
#       appears in the inspector dropdown on Juice2D nodes.
#       All behavior is inherited from TimeJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V2/Meta/)
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceUtilityTimeCoord.svg")
class_name Time2DJuiceEffect
extends TimeJuiceEffectBase
