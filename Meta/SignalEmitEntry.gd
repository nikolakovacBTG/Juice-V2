## One signal-emission entry in a SignalEmitJuiceUtilityBase entries array.
##
## Each entry fires independently at its own timing with its own payload.
## Multiple entries = multiple signals from a single utility in the recipe.

# =============================================================================
# WHAT: Sub-resource representing one signal to emit.
#       Stores description (label), payload (data), and timing.
# WHY:  Enables one SignalEmit utility to fire multiple distinct signals
#       at different lifecycle points — mirrors the recipe-item paradigm.
# SYSTEM: Juice System (addons/Juice_V2/Meta/)
# DOES NOT: Fire the signal — the parent utility does that in lifecycle hooks.
# =============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceUtilitySignals.svg")
class_name SignalEmitEntry
extends Resource


# =============================================================================
# CONFIGURATION
# =============================================================================

## Human-readable label for this signal (debug / inspector only).
## The actual emitted signal is always juice_signal on the parent utility.
var signal_description: String = "juice_triggered"

## Data passed with the signal. Any Variant: String, int, Resource, Dictionary…
## Leave null for a bare notification with no data.
var payload: Variant = null

## When to emit this signal relative to the animation lifecycle.
## 0 = On Start, 1 = On Complete, 2 = On Both.
var emit_on: int = 0


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
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
