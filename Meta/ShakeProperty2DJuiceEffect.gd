## 2D-domain leaf for [ShakePropertyJuiceEffectBase].
## Shake-drives arbitrary Node2D properties with sine+random oscillation.

# ============================================================================
# WHAT: 2D-domain wrapper for ShakePropertyJuiceEffectBase.
# WHY:  Registers this effect under Juice2DRecipe._CONCRETE_EFFECTS so
#       the inspector dropdown shows it only on Juice2D nodes.
#       All behavior is inherited from ShakePropertyJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Add any behavior beyond ShakePropertyJuiceEffectBase.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBase2D.svg")
class_name ShakeProperty2DJuiceEffect
extends ShakePropertyJuiceEffectBase


func _get_domain_tag() -> String:
	return "2D"
