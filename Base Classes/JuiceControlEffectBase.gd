## JuiceControlEffectBase.gd
## ============================================================================
## WHAT: Base class for all Control-domain juice effects.
## WHY: Enables type-safe domain filtering — JuiceControlRecipe uses
##      Array[JuiceControlEffectBase] so only Control effects appear in the
##      inspector dropdown. Prevents slotting 2D/3D effects into Control nodes.
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Implement any effect behavior — concrete subclasses do that.
## ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name JuiceControlEffectBase
extends JuiceEffectBase

# =============================================================================
# DELTA CONTRIBUTION STORAGE
# =============================================================================
# Effects compute deltas (offsets from natural state) and store them here.
# The domain node (JuiceControl) reads these after tick and writes ONCE.
# Effects NEVER write to the target directly.

## Which channels this effect contributes to. Set by concrete effects in _init().
var _contributes_position: bool = false
var _contributes_rotation: bool = false
var _contributes_scale: bool = false

## Current delta values. Updated by _apply_effect() each tick.
## Position: offset from natural position (Vector2)
## Rotation: offset from natural rotation (float, radians)
## Scale: offset from natural scale (Vector2) — additive, not multiplicative
var _pos_delta: Vector2 = Vector2.ZERO
var _rot_delta: float = 0.0
var _scale_delta: Vector2 = Vector2.ZERO


## Reset all deltas to zero. Called by domain node when effect stops.
func _clear_deltas() -> void:
	_pos_delta = Vector2.ZERO
	_rot_delta = 0.0
	_scale_delta = Vector2.ZERO
