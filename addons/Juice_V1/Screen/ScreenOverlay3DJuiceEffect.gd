## 3D-domain wrapper for ScreenOverlayJuiceEffectBase.
##
## Registers the effect in Juice3DRecipe._CONCRETE_EFFECTS so it
## appears in the inspector dropdown on Juice3D nodes.

# ============================================================================
# WHAT: 3D-domain wrapper for ScreenOverlayJuiceEffectBase.
# WHY: Registers the effect in Juice3DRecipe._CONCRETE_EFFECTS so it
#      appears in the inspector dropdown on Juice3D nodes.
#      All behavior is inherited from ScreenOverlayJuiceEffectBase.
# SYSTEM: Juicing System (addons/Juice_V1/)
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name ScreenOverlay3DJuiceEffect
extends ScreenOverlayJuiceEffectBase
