## Control-domain wrapper for [ProgressPropertyJuiceEffectBase].
## Drives arbitrary named Control properties from their base toward a target
## value, tracking the Juice progress envelope (0 = base, 1 = target).

# ============================================================================
# WHAT: Control-domain leaf for the ProgressProperty effect family.
# WHY:  Registers the effect under JuiceControlRecipe._CONCRETE_EFFECTS so the
#       inspector dropdown shows it only for Control-domain Juice nodes.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Add any behaviour beyond ProgressPropertyJuiceEffectBase.
# ============================================================================

@tool
class_name ProgressPropertyControlJuiceEffect
extends ProgressPropertyJuiceEffectBase


func _get_domain_tag() -> String:
	return "Control"
