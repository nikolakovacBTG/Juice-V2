## 3D-domain wrapper for [InterpolatePropertyJuiceEffectBase].
## Interpolates arbitrary named Node3D properties from a FROM to a TO value.

# ============================================================================
# WHAT: 3D-domain leaf for the Interpolate property effect family.
# WHY:  Registers the effect under Juice3DRecipe._CONCRETE_EFFECTS so the
#       inspector dropdown shows it only for 3D-domain Juice nodes.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Add any behavior beyond InterpolatePropertyJuiceEffectBase.
# ============================================================================

@tool
class_name InterpolateProperty3DJuiceEffect
extends InterpolatePropertyJuiceEffectBase


func _get_domain_tag() -> String:
	return "3D"
