## Control-domain wrapper for NoisePropertyJuiceEffectBase.
##
## Registers the effect in JuiceControlRecipe._CONCRETE_EFFECTS so it
## appears in the inspector dropdown on JuiceControl nodes.

# ============================================================================
# WHAT: Control-domain wrapper for NoisePropertyJuiceEffectBase.
# WHY:  Registers the effect in JuiceControlRecipe._CONCRETE_EFFECTS so it
#       appears in the inspector dropdown on JuiceControl nodes.
#       All behavior is inherited from NoisePropertyJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name PropertyNoiseControlJuiceEffect
extends PropertyNoiseJuiceEffectBase
