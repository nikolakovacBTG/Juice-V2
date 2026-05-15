## Control-domain leaf for [PropertyShakeJuiceEffectBase].
## Shake-drives arbitrary Control properties with sine+random oscillation.

# ============================================================================
# WHAT: Control-domain wrapper for PropertyShakeJuiceEffectBase.
# WHY:  Registers this effect under JuiceControlRecipe._CONCRETE_EFFECTS so
#       the inspector dropdown shows it only on Control-domain Juice nodes.
#       All behavior is inherited from PropertyShakeJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Add any behavior beyond PropertyShakeJuiceEffectBase.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseProperty.svg")
class_name PropertyShakeControlJuiceEffect
extends PropertyShakeJuiceEffectBase


func _get_domain_tag() -> String:
	return "Control"
