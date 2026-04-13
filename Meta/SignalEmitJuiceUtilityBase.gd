## Base class for signal emission utilities.
##
## Emits juice_signal(payload) at the configured timing relative to the
## animation lifecycle. Domain-agnostic — no visual output.

# ============================================================================
# WHAT: Emits a custom signal when an animation starts or completes.
# WHY:  Allows designers to wire "when this animation fires → notify system X"
#       purely in the inspector, without writing custom scripts. Replaces V0
#       SignalEmitJuiceUtility (standalone Node) with a chainable Resource that
#       participates in the recipe stack: start_delay, chain_to, loop all work.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# DOES NOT: Produce any visual effect — control/flow only.
# DOES NOT: Block animation completion — fires and immediately completes.
#
# USAGE:
#   - Add to a JuiceBase recipe alongside visual effects
#   - Use start_delay to fire the signal partway through a sequence
#   - Use chain_to to fire a signal when a preceding visual effect completes
#   - Connect juice_signal to game systems in the inspector or via code
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceUtilitySignals.svg")
class_name SignalEmitJuiceUtilityBase
extends JuiceEffectBase


# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when this effect triggers. payload carries the configured data.
## Connect other systems to this signal to react to animation events.
signal juice_signal(payload: Variant)


# =============================================================================
# ENUMS
# =============================================================================

## When to emit the signal relative to the animation lifecycle.
enum EmitTiming {
	ON_START,    ## Emit when animate_in() begins (after start_delay).
	ON_COMPLETE, ## Emit when animation reaches peak (progress=1.0).
	ON_BOTH,     ## Emit on both start and complete.
}


# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Signal Emission")


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	props.append({"name": "Utility", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append_array(_get_effect_base_properties())
	return props


func _init() -> void:
	_subclass_owns_effect_group = true

## Human-readable description of this signal (for documentation/debugging only).
## The actual emitted signal is always juice_signal.
@export var signal_description: String = "juice_triggered"

## Data payload passed with the signal. Can be any Variant: String, int,
## Resource, Dictionary, etc. Leave null for a no-payload signal.
@export var payload: Variant = null

## When to emit relative to the animation.
@export var emit_on: EmitTiming = EmitTiming.ON_START


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

func _on_animate_start(_target: Node) -> void:
	if emit_on == EmitTiming.ON_START or emit_on == EmitTiming.ON_BOTH:
		_emit_juice_signal("ON_START")


func _on_animate_in_complete(_target: Node) -> void:
	if emit_on == EmitTiming.ON_COMPLETE or emit_on == EmitTiming.ON_BOTH:
		_emit_juice_signal("ON_COMPLETE")


func _apply_effect(_progress: float, _target: Node) -> void:
	pass  # No visual output — signal emission happens in lifecycle hooks.


# =============================================================================
# HELPERS
# =============================================================================

func _emit_juice_signal(timing_label: String) -> void:
	juice_signal.emit(payload)
	if debug_enabled:
		print("[SignalEmit] '%s' emitted at %s. Payload: %s" % [
			signal_description, timing_label, payload])
