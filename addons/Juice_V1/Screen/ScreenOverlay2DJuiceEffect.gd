## Full-screen color or texture overlay effect for [Juice2D] node recipes.
##
## All behavior is provided by [ScreenOverlayJuiceEffectBase].
## This class exists solely to appear in the [Juice2DRecipe] inspector dropdown.

# ============================================================================
# WHAT: Full-screen color or texture overlay effect, scoped to the 2D domain.
# WHY: Juice recipes are domain-typed. This thin subclass registers the effect
#      in Juice2DRecipe._CONCRETE_EFFECTS so it appears in the inspector dropdown
#      on Juice2D nodes. All logic lives in ScreenOverlayJuiceEffectBase.
# SYSTEM: Juicing System (addons/Juice_V1/)
# DOES NOT: Implement any behavior — see ScreenOverlayJuiceEffectBase.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase2D.svg")
class_name ScreenOverlay2DJuiceEffect
extends ScreenOverlayJuiceEffectBase
