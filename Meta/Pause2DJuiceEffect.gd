## 2D-domain wrapper for PauseJuiceEffectBase.
##
## Registers the effect in Juice2DRecipe._CONCRETE_EFFECTS so it
## appears in the inspector dropdown on Juice2D nodes.

# ============================================================================
# WHAT: 2D-domain wrapper for PauseJuiceEffectBase.
# WHY:  Registers the effect in Juice2DRecipe._CONCRETE_EFFECTS so it
#       appears in the inspector dropdown on Juice2D nodes.
#       All behavior is inherited from PauseJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V2/Meta/)
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseEvents.svg")
class_name Pause2DJuiceEffect
extends PauseJuiceEffectBase
