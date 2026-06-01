## One signal-emission entry in a SignalEmitJuiceUtilityBase entries array.
##
## Each entry fires independently at its own timing with its own payload.
## [member signal_name] is the actual Godot signal identifier registered on the
## host Node and (optionally) on its owner. [member signal_description] is a
## human-readable inspector label only.
## Multiple entries = multiple signals from a single utility in the recipe.

# =============================================================================
# WHAT: Sub-resource representing one signal to emit.
#       Stores signal_name (runtime identifier), description (label),
#       payload (data), and timing.
# WHY:  Enables one SignalEmit utility to fire multiple distinct signals
#       at different lifecycle points — mirrors the recipe-item paradigm.
#       signal_name is the key the host Node exposes via add_user_signal();
#       other nodes connect to it in the Inspector's Connect dialog.
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

## The Godot signal name registered on the host Node at animation start.
## Other nodes connect to this signal via the Inspector's "Connect Signal" dialog.
## Must be a valid GDScript identifier (e.g. "on_hit", "on_landed").
## Leave empty to emit only the Resource-level juice_signal (code-only fallback).
var signal_name: String = ""

## Human-readable label for this signal (debug / inspector display only).
## Does not affect runtime behaviour — used for logging and resource_name.
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
	props.append({"name": "signal_name", "type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT})
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
		&"signal_name":
			signal_name = value
			return true
		&"signal_description":
			signal_description = value
			resource_name = value if not value.is_empty() else ""
			return true
		&"payload":            payload            = value; return true
		&"emit_on":            emit_on            = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"signal_name":        return signal_name
		&"signal_description": return signal_description
		&"payload":            return payload
		&"emit_on":            return emit_on
	return null
