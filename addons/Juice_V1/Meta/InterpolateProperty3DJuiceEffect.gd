## 3D-domain wrapper for [PropertyInterpolateJuiceEffectBase]. Interpolates arbitrary properties from a FROM to a TO value.

# ============================================================================
# WHAT: 3D-domain wrapper for InterpolatePropertyJuiceEffectBase.
# WHY:  Registers the effect in Juice3DRecipe._CONCRETE_EFFECTS.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name PropertyInterpolate3DJuiceEffect
extends PropertyInterpolateJuiceEffectBase
