## Control-domain wrapper for [PropertyProgressJuiceEffectBase]. Continuously accumulates properties over time.
##
## Registers the effect in JuiceControlRecipe._CONCRETE_EFFECTS so it
## appears in the inspector dropdown on JuiceControl nodes.

# ============================================================================
# WHAT: Control-domain wrapper for ProgressPropertyJuiceEffectBase.
# WHY:  Registers the effect in JuiceControlRecipe._CONCRETE_EFFECTS so it
#       appears in the inspector dropdown on JuiceControl nodes.
#       All behavior is inherited from ProgressPropertyJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name PropertyProgressControlJuiceEffect
extends PropertyProgressJuiceEffectBase
