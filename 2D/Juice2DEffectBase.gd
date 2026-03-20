## Juice2DEffectBase.gd
## ============================================================================
## WHAT: Base class for all 2D-domain juice effects.
## WHY: Enables type-safe domain filtering — Juice2DRecipe uses
##      Array[Juice2DEffectBase] so only 2D effects appear in the
##      inspector dropdown. Prevents slotting Control/3D effects into 2D nodes.
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Implement any effect behavior — concrete subclasses do that.
## ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase2D.svg")
class_name Juice2DEffectBase
extends JuiceEffectBase
