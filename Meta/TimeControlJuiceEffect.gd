## Control-domain wrapper for TimeJuiceEffectBase.
##
## Registers the effect in JuiceControlRecipe._CONCRETE_EFFECTS so it
## appears in the inspector dropdown on JuiceControl nodes.

# ============================================================================
# WHAT: Control-domain wrapper for TimeJuiceEffectBase.
# WHY:  Registers the effect in JuiceControlRecipe._CONCRETE_EFFECTS so it
#       appears in the inspector dropdown on JuiceControl nodes.
#       All behavior is inherited from TimeJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V2/Meta/)
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceUtilityTimeCoord.svg")
class_name TimeControlJuiceEffect
extends TimeJuiceEffectBase
