## 3D-domain leaf for [PropertyShakeJuiceEffectBase].
## Shake-drives arbitrary Node3D properties with sine+random oscillation.

# ============================================================================
# WHAT: 3D-domain wrapper for PropertyShakeJuiceEffectBase.
# WHY:  Registers this effect under Juice3DRecipe._CONCRETE_EFFECTS so
#       the inspector dropdown shows it only on Juice3D nodes.
#       All behavior is inherited from PropertyShakeJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Add any behavior beyond PropertyShakeJuiceEffectBase.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseProperty.svg")
class_name PropertyShake3DJuiceEffect
extends PropertyShakeJuiceEffectBase


func _get_domain_tag() -> String:
	return "3D"
