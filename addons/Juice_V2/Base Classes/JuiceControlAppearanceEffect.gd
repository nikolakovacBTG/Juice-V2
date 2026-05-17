## Intermediate base for Control-domain effects that produce modulate contributions.
##
## Separates modulate accumulation from domain filtering. Effects that
## animate color/alpha via modulate extend this.

# ============================================================================
# WHAT: Intermediate base for Control-domain effects that produce modulate contributions.
# WHY: Separates modulate accumulation from domain filtering. Effects that
#      animate color/alpha via modulate extend this. Non-modulate effects
#      (Transform, OUTLINE via StyleBox) extend JuiceControlEffectBase directly.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Implement any effect behavior — concrete subclasses do that.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseControl.svg")
class_name JuiceControlAppearanceEffect
extends JuiceControlEffectBase

# =============================================================================
# MODULATE CONTRIBUTION STORAGE
# =============================================================================
# Effects compute a multiplicative color factor and store it here.
# The domain node (JuiceControl) reads these after tick and writes ONCE:
#   target.modulate = natural_modulate * factor_a * factor_b * ...
# Effects NEVER write to target.modulate directly.

## Whether this effect contributes a modulate factor. Set by concrete effects in _init().
var _contributes_modulate: bool = false

## Current multiplicative factor. Updated by _apply_effect() each tick.
## WHITE = identity (no effect). Multiplied into the domain's combined modulate.
var _modulate_factor: Color = Color.WHITE


# Reset modulate factor to identity. Called by domain node when effect stops.
func _clear_modulate() -> void:
	_modulate_factor = Color.WHITE


# Return current modulate contribution as a Dictionary.
# Used by Sequencer contribution-tracking (generic, no hardcoded channels).
func _get_seq_contribution() -> Dictionary:
	var d := {}
	if _contributes_modulate:
		d["modulate"] = _modulate_factor
	return d
