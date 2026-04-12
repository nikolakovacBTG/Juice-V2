## Base class for all 3D-domain juice effects.

# ============================================================================
# WHAT: Base class for all 3D-domain juice effects.
# WHY: Enables type-safe domain filtering — Juice3DRecipe uses
#      Array[Juice3DEffectBase] so only 3D effects appear in the
#      inspector dropdown. Prevents slotting Control/2D effects into 3D nodes.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Implement any effect behavior — concrete subclasses do that.
# DOES NOT: Hold transform delta storage — see Juice3DTransformEffect.
# ============================================================================
#
# HIERARCHY:
# JuiceEffectBase (timing, easing, animation state)
#   └─ Juice3DEffectBase (domain filter — this class)
#        ├─ Juice3DTransformEffect (pos/rot/scale deltas)
#        │    └─ Transform3DJuiceEffect, Noise3DJuiceEffect, etc.
#        └─ Non-transform effects extend this directly
#             └─ Appearance3DJuiceEffect, Progress3DJuiceEffect, etc.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name Juice3DEffectBase
extends JuiceEffectBase
