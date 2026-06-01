## 2D-domain leaf for [PropertyShakeJuiceEffectBase].
## Shake-drives arbitrary Node2D properties with sine+random oscillation.

# ============================================================================
# WHAT: 2D-domain wrapper for PropertyShakeJuiceEffectBase.
# WHY:  Registers this effect under Juice2DRecipe._CONCRETE_EFFECTS so
#       the inspector dropdown shows it only on Juice2D nodes.
#       All behavior is inherited from PropertyShakeJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Add any behavior beyond PropertyShakeJuiceEffectBase.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseProperty.svg")
class_name PropertyShake2DJuiceEffect
extends PropertyShakeJuiceEffectBase


func _get_domain_tag() -> String:
	return "2D"
