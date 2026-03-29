## 2D-domain wrapper for ScreenOverlayJuiceEffectBase.
##
## Registers the effect in Juice2DRecipe._CONCRETE_EFFECTS so it
## appears in the inspector dropdown on Juice2D nodes.

# ============================================================================
# WHAT: 2D-domain wrapper for ScreenOverlayJuiceEffectBase.
# WHY: Registers the effect in Juice2DRecipe._CONCRETE_EFFECTS so it
#      appears in the inspector dropdown on Juice2D nodes.
#      All behavior is inherited from ScreenOverlayJuiceEffectBase.
# SYSTEM: Juicing System (addons/Juice_V1/)
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase2D.svg")
class_name ScreenOverlay2DJuiceEffect
extends ScreenOverlayJuiceEffectBase
