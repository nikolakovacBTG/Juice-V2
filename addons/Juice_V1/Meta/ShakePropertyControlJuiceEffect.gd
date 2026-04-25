## Control-domain wrapper for [PropertyShakeJuiceEffectBase]. Drives properties with sine-wave + random shake.

# ============================================================================
# WHAT: Control-domain wrapper for ShakePropertyJuiceEffectBase.
# WHY:  Registers the effect in JuiceControlRecipe._CONCRETE_EFFECTS.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name PropertyShakeControlJuiceEffect
extends PropertyShakeJuiceEffectBase
