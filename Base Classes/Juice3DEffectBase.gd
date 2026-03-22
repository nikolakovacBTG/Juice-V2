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

# =============================================================================
# DELTA CONTRIBUTION STORAGE
# =============================================================================
# Effects compute deltas (offsets from natural state) and store them here.
# The domain node (Juice3D) reads these after tick and writes ONCE.
# Effects NEVER write to the target directly.

## Which channels this effect contributes to. Set by concrete effects in _init().
var _contributes_position: bool = false
var _contributes_rotation: bool = false
var _contributes_scale: bool = false

## Current delta values. Updated by _apply_effect() each tick.
## Position: offset from natural position (Vector3)
## Rotation: offset from natural rotation (Vector3, radians per axis)
## Scale: offset from natural scale (Vector3) — additive, not multiplicative
var _pos_delta: Vector3 = Vector3.ZERO
var _rot_delta: Vector3 = Vector3.ZERO
var _scale_delta: Vector3 = Vector3.ZERO


## Reset all deltas to zero. Called by domain node when effect stops.
func _clear_deltas() -> void:
	_pos_delta = Vector3.ZERO
	_rot_delta = Vector3.ZERO
	_scale_delta = Vector3.ZERO


## Return current deltas as a Dictionary keyed by Godot property names.
## Used by Sequencer contribution-tracking (generic, no hardcoded channels
## in domain nodes). Future effects override this to add their own channels.
func _get_seq_contribution() -> Dictionary:
	var d := {}
	if _contributes_position:
		d["position"] = _pos_delta
	if _contributes_rotation:
		d["rotation"] = _rot_delta
	if _contributes_scale:
		d["scale"] = _scale_delta
	return d
