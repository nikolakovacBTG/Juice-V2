## ScreenOverlayControlJuiceEffect.gd
## ============================================================================
## WHAT: Control-domain wrapper for ScreenOverlayJuiceEffectBase.
## WHY: Registers the effect in JuiceControlRecipe._CONCRETE_EFFECTS so it
##      appears in the inspector dropdown on JuiceControl nodes.
##      All behavior is inherited from ScreenOverlayJuiceEffectBase.
## SYSTEM: Juicing System (addons/Juice_V1/)
## ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name ScreenOverlayControlJuiceEffect
extends ScreenOverlayJuiceEffectBase
