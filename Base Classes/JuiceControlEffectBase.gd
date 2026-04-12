## Base class for all Control-domain juice effects.

# ============================================================================
# WHAT: Base class for all Control-domain juice effects.
# WHY: Enables type-safe domain filtering — JuiceControlRecipe uses
#      Array[JuiceControlEffectBase] so only Control effects appear in the
#      inspector dropdown. Prevents slotting 2D/3D effects into Control nodes.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Implement any effect behavior — concrete subclasses do that.
# DOES NOT: Hold transform delta storage — see JuiceControlTransformEffect.
# ============================================================================
#
# HIERARCHY:
# JuiceEffectBase (timing, easing, animation state)
#   └─ JuiceControlEffectBase (domain filter — this class)
#        ├─ JuiceControlTransformEffect (pos/rot/scale deltas)
#        │    └─ TransformControlJuiceEffect, NoiseControlJuiceEffect, etc.
#        └─ Non-transform effects extend this directly
#             └─ AppearanceControlJuiceEffect, ProgressControlJuiceEffect, etc.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name JuiceControlEffectBase
extends JuiceEffectBase
