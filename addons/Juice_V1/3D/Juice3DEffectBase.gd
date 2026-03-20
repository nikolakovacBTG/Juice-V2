## Juice3DEffectBase.gd
## ============================================================================
## WHAT: Base class for all 3D-domain juice effects.
## WHY: Enables type-safe domain filtering — Juice3DRecipe uses
##      Array[Juice3DEffectBase] so only 3D effects appear in the
##      inspector dropdown. Prevents slotting Control/2D effects into 3D nodes.
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Implement any effect behavior — concrete subclasses do that.
## ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name Juice3DEffectBase
extends JuiceEffectBase
