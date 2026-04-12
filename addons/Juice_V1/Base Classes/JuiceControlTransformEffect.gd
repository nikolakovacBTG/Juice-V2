## Intermediate base for Control-domain effects that produce transform deltas.

# ============================================================================
# WHAT: Intermediate base for Control-domain effects that produce transform deltas.
# WHY: Separates transform delta storage from domain filtering. Effects that
#      manipulate position/rotation/scale extend this. Non-transform effects
#      (Appearance, VFX, etc.) extend JuiceControlEffectBase directly.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Implement any effect behavior — concrete subclasses do that.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name JuiceControlTransformEffect
extends JuiceControlEffectBase

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
