## 2D-domain wrapper for [PropertyInterpolateJuiceEffectBase]. Interpolates arbitrary properties from a FROM to a TO value.

# ============================================================================
# WHAT: 2D-domain wrapper for InterpolatePropertyJuiceEffectBase.
# WHY:  Registers the effect in Juice2DRecipe._CONCRETE_EFFECTS.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase2D.svg")
class_name PropertyInterpolate2DJuiceEffect
extends PropertyInterpolateJuiceEffectBase
