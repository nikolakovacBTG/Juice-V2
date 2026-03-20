## ControlJuiceEffectBase.gd
## ============================================================================
## WHAT: Base class for all Control-domain juice effects.
## WHY: Enables type-safe domain filtering — ControlJuiceRecipe uses
##      Array[ControlJuiceEffectBase] so only Control effects appear in the
##      inspector dropdown. Prevents slotting 2D/3D effects into Control nodes.
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Implement any effect behavior — concrete subclasses do that.
## ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name ControlJuiceEffectBase
extends JuiceEffectBase
