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
# INSPECTOR LAYOUT:
#   ▼ Trigger
#       Trigger Behaviour  — Play In And Out fires on start AND reverse
#       Start Delay        — delays when the signal fires in a sequence
#       Loop Count         — enables rhythmic repeated emission
#       [loop options: ping_pong, loop_delay, loop_phase_offset]
#       Signal Description — human label (no runtime effect)
#       Payload            — arbitrary Variant passed with the signal
#       Emit On            — On Start / On Complete / On Both
#
# CROSSFADE TIME is intentionally hidden — it blends _animation_progress,
# but _apply_effect is a no-op here so crossfade has no observable effect.
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

func _init() -> void:
	_subclass_owns_effect_group = true

## Human-readable label for this signal (documentation / debug only).
## The actual emitted signal is always juice_signal — this name is never used at runtime.
var signal_description: String = "juice_triggered"

## Data passed with the signal. Can be any Variant: String, int, Resource, Dictionary, etc.
## Leave null for a bare notification with no data.
var payload: Variant = null

## When to emit relative to the animation lifecycle.
var emit_on: EmitTiming = EmitTiming.ON_START


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# Single "Trigger" group — meta effects have no visual properties.
	props.append({"name": "Trigger", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})

	# Trigger Behaviour: kept — Play In And Out fires on start AND reverse,
	# which is useful to sync signal emission with in-and-out visual effects.
	props.append({"name": "trigger_behaviour", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Play In And Out,Play In Only,Play Out Only,Toggle,Set From Source",
		"usage": PROPERTY_USAGE_DEFAULT})

	props.append({"name": "start_delay", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,100.0,0.01,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})

	# loop_count != 1 enables rhythmic repeated emission (e.g. periodic events).
	props.append({"name": "loop_count", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT})
	if loop_count != 1:
		props.append({"name": "ping_pong", "type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "loop_delay", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "loop_phase_offset", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
			"usage": PROPERTY_USAGE_DEFAULT})

	# Crossfade Time intentionally omitted — see file header.

	props.append({"name": "signal_description", "type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "payload", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_NIL_IS_VARIANT})
	props.append({"name": "emit_on", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "On Start,On Complete,On Both",
		"usage": PROPERTY_USAGE_DEFAULT})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"signal_description": signal_description = value; return true
		&"payload":            payload            = value; return true
		&"emit_on":            emit_on            = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"signal_description": return signal_description
		&"payload":            return payload
		&"emit_on":            return emit_on
	return null


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
