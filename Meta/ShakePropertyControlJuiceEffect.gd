## Control-domain leaf for [ShakePropertyJuiceEffectBase].
## Shake-drives arbitrary Control properties with sine+random oscillation.

# ============================================================================
# WHAT: Control-domain wrapper for ShakePropertyJuiceEffectBase.
# WHY:  Registers this effect under JuiceControlRecipe._CONCRETE_EFFECTS so
#       the inspector dropdown shows it only on Control-domain Juice nodes.
#       All behavior is inherited from ShakePropertyJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Add any behavior beyond ShakePropertyJuiceEffectBase.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseControl.svg")
class_name ShakePropertyControlJuiceEffect
extends ShakePropertyJuiceEffectBase


func _get_domain_tag() -> String:
	return "Control"
