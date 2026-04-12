## Full-screen color or texture overlay effect for [Juice3D] node recipes.
##
## All behavior is provided by [ScreenOverlayJuiceEffectBase].
## This class exists solely to appear in the [Juice3DRecipe] inspector dropdown.

# ============================================================================
# WHAT: Full-screen color or texture overlay effect, scoped to the 3D domain.
# WHY: Juice recipes are domain-typed. This thin subclass registers the effect
#      in Juice3DRecipe._CONCRETE_EFFECTS so it appears in the inspector dropdown
#      on Juice3D nodes. All logic lives in ScreenOverlayJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Implement any behavior — see ScreenOverlayJuiceEffectBase.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name ScreenOverlay3DJuiceEffect
extends ScreenOverlayJuiceEffectBase
