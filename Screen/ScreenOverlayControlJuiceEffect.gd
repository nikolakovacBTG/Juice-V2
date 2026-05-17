## Full-screen color or texture overlay effect for [JuiceControl] node recipes.
##
## All behavior is provided by [ScreenOverlayJuiceEffectBase].
## This class exists solely to appear in the [JuiceControlRecipe] inspector dropdown.

# ============================================================================
# WHAT: Full-screen color or texture overlay effect, scoped to the Control domain.
# WHY: Juice recipes are domain-typed. This thin subclass registers the effect
#      in JuiceControlRecipe._CONCRETE_EFFECTS so it appears in the inspector
#      dropdown on JuiceControl nodes. All logic lives in ScreenOverlayJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Implement any behavior — see ScreenOverlayJuiceEffectBase.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseControl.svg")
class_name ScreenOverlayControlJuiceEffect
extends ScreenOverlayJuiceEffectBase
