## Intermediate base for 3D-domain effects that produce appearance contributions.
##
## Separates appearance accumulation from domain filtering. Effects that
## animate albedo/alpha via material slots extend this.

# ============================================================================
# WHAT: Intermediate base for 3D-domain effects that produce appearance contributions.
# WHY: Separates appearance accumulation from domain filtering. Effects that
#      animate albedo/alpha via material slots extend this. Non-appearance effects
#      (Transform) extend Juice3DEffectBase directly.
# SYSTEM: Juicing System (addons/Juice_V1/)
# DOES NOT: Implement any effect behavior — concrete subclasses do that.
# DOES NOT: Manage MeshInstance3D or working materials — that is Juice3D's job.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name Juice3DAppearanceEffect
extends Juice3DEffectBase

# =============================================================================
# APPEARANCE CONTRIBUTION STORAGE
# =============================================================================
# Node3D has no .modulate shortcut — appearance is applied via StandardMaterial3D
# albedo_color on the target's MeshInstance3D.
#
# The domain node (Juice3D) owns one shared working material (duplicated from
# the surface's natural material). After all effects tick, Juice3D accumulates:
#   working_mat.albedo_color = natural_albedo * factor_a * factor_b * ...
#   working_mat.albedo_color.a = natural_alpha * alpha_factor_a * alpha_factor_b * ...
# Effects NEVER write to the working material directly.

## Whether this effect contributes appearance factors. Set by concrete effects in _init().
var _contributes_appearance: bool = false

## Current albedo multiplier (RGB). Updated by _apply_effect() each tick.
## WHITE = identity (no color change).
var _albedo_factor: Color = Color.WHITE

## Current alpha multiplier. 1.0 = no change.
var _alpha_factor: float = 1.0


## Reset appearance factors to identity. Called by domain node when effect stops.
func _clear_appearance() -> void:
	_albedo_factor = Color.WHITE
	_alpha_factor = 1.0


## Return current appearance contribution as a Dictionary.
## Used by Sequencer contribution-tracking (generic, no hardcoded channels).
func _get_seq_contribution() -> Dictionary:
	var d := {}
	if _contributes_appearance:
		d["albedo"] = _albedo_factor
		d["alpha"] = _alpha_factor
	return d
