## 3D-domain wrapper for [ProgressPropertyJuiceEffectBase].
## Drives arbitrary named Node3D properties from their base toward a target
## value, tracking the Juice progress envelope (0 = base, 1 = target).

# ============================================================================
# WHAT: 3D-domain leaf for the ProgressProperty effect family.
# WHY:  Registers the effect under Juice3DRecipe._CONCRETE_EFFECTS so the
#       inspector dropdown shows it only for 3D-domain Juice nodes.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Add any behaviour beyond ProgressPropertyJuiceEffectBase.
# ============================================================================

@tool
class_name ProgressProperty3DJuiceEffect
extends ProgressPropertyJuiceEffectBase


func _get_domain_tag() -> String:
	return "3D"
