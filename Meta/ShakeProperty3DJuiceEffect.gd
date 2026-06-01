## 3D-domain leaf for [ShakePropertyJuiceEffectBase].
## Shake-drives arbitrary Node3D properties with sine+random oscillation.

# ============================================================================
# WHAT: 3D-domain wrapper for ShakePropertyJuiceEffectBase.
# WHY:  Registers this effect under Juice3DRecipe._CONCRETE_EFFECTS so
#       the inspector dropdown shows it only on Juice3D nodes.
#       All behavior is inherited from ShakePropertyJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Add any behavior beyond ShakePropertyJuiceEffectBase.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBase3D.svg")
class_name ShakeProperty3DJuiceEffect
extends ShakePropertyJuiceEffectBase


func _get_domain_tag() -> String:
	return "3D"
