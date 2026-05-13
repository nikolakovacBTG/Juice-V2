## 2D-domain wrapper for [InterpolatePropertyJuiceEffectBase].
## Interpolates arbitrary named Node2D properties from a FROM to a TO value.

# ============================================================================
# WHAT: 2D-domain leaf for the Interpolate property effect family.
# WHY:  Registers the effect under Juice2DRecipe._CONCRETE_EFFECTS so the
#       inspector dropdown shows it only for 2D-domain Juice nodes.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Add any behavior beyond InterpolatePropertyJuiceEffectBase.
# ============================================================================

@tool
class_name InterpolateProperty2DJuiceEffect
extends InterpolatePropertyJuiceEffectBase


func _get_domain_tag() -> String:
	return "2D"
