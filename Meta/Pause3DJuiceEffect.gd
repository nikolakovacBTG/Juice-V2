## 3D-domain wrapper for PauseJuiceEffectBase.
##
## Registers the effect in Juice3DRecipe._CONCRETE_EFFECTS so it
## appears in the inspector dropdown on Juice3D nodes.

# ============================================================================
# WHAT: 3D-domain wrapper for PauseJuiceEffectBase.
# WHY:  Registers the effect in Juice3DRecipe._CONCRETE_EFFECTS so it
#       appears in the inspector dropdown on Juice3D nodes.
#       All behavior is inherited from PauseJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseEvents.svg")
class_name Pause3DJuiceEffect
extends PauseJuiceEffectBase
