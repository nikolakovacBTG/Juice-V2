## 3D-domain leaf for [NoisePropertyJuiceEffectBase].
## Noise-drives arbitrary Node3D properties with FastNoiseLite oscillation.

# ============================================================================
# WHAT: 3D-domain wrapper for NoisePropertyJuiceEffectBase.
# WHY:  Registers this effect under Juice3DRecipe._CONCRETE_EFFECTS so
#       the inspector dropdown shows it only on Juice3D nodes.
#       All behavior is inherited from NoisePropertyJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Add any behavior beyond NoisePropertyJuiceEffectBase.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBase3D.svg")
class_name NoiseProperty3DJuiceEffect
extends NoisePropertyJuiceEffectBase


func _get_domain_tag() -> String:
	return "3D"
