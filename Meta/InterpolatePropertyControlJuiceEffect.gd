## Control-domain wrapper for InterpolatePropertyJuiceEffectBase.

# ============================================================================
# WHAT: Control-domain wrapper for InterpolatePropertyJuiceEffectBase.
# WHY:  Registers the effect in JuiceControlRecipe._CONCRETE_EFFECTS.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name InterpolatePropertyControlJuiceEffect
extends InterpolatePropertyJuiceEffectBase
