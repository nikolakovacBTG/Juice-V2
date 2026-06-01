## Control-domain wrapper for PauseJuiceEffectBase.
##
## Registers the effect in JuiceControlRecipe._CONCRETE_EFFECTS so it
## appears in the inspector dropdown on JuiceControl nodes.

# ============================================================================
# WHAT: Control-domain wrapper for PauseJuiceEffectBase.
# WHY:  Registers the effect in JuiceControlRecipe._CONCRETE_EFFECTS so it
#       appears in the inspector dropdown on JuiceControl nodes.
#       All behavior is inherited from PauseJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V2/Meta/)
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseEvents.svg")
class_name PauseControlJuiceEffect
extends PauseJuiceEffectBase
