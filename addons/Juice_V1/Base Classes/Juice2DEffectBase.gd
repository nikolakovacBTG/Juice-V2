## Base class for all 2D-domain juice effects.

# ============================================================================
# WHAT: Base class for all 2D-domain juice effects.
# WHY: Enables type-safe domain filtering — Juice2DRecipe uses
#      Array[Juice2DEffectBase] so only 2D effects appear in the
#      inspector dropdown. Prevents slotting Control/3D effects into 2D nodes.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Implement any effect behavior — concrete subclasses do that.
# DOES NOT: Hold transform delta storage — see Juice2DTransformEffect.
# ============================================================================
#
# HIERARCHY:
# JuiceEffectBase (timing, easing, animation state)
#   └─ Juice2DEffectBase (domain filter — this class)
#        ├─ Juice2DTransformEffect (pos/rot/scale deltas)
#        │    └─ Transform2DJuiceEffect, Noise2DJuiceEffect, etc.
#        └─ Non-transform effects extend this directly
#             └─ Appearance2DJuiceEffect, Progress2DJuiceEffect, etc.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase2D.svg")
class_name Juice2DEffectBase
extends JuiceEffectBase


func _get_domain_tag() -> String:
	return "2D"
