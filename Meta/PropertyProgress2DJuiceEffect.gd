## 2D-domain wrapper for [PropertyProgressJuiceEffectBase].
## Drives arbitrary named Node2D properties from their base toward a target
## value, tracking the Juice progress envelope (0 = base, 1 = target).

# ============================================================================
# WHAT: 2D-domain leaf for the ProgressProperty effect family.
# WHY:  Registers the effect under Juice2DRecipe._CONCRETE_EFFECTS so the
#       inspector dropdown shows it only for 2D-domain Juice nodes.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Add any behaviour beyond PropertyProgressJuiceEffectBase.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseProperty.svg")
class_name PropertyProgress2DJuiceEffect
extends PropertyProgressJuiceEffectBase


func _get_domain_tag() -> String:
	return "2D"
