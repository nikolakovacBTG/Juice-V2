## Lightweight relay that listens for local signals and re-emits them on a global signal bus.
##
## Bridges the gap between local triggers and remote juice components that listen on a signal bus. Essential for signal relay patterns where juice comps live in different scenes than triggers.

# ============================================================================
# WHAT: Lightweight relay that listens for a signal on a local node and
#       re-emits a named signal on a global signal bus autoload.
# WHY: Bridges the gap between local triggers (clicks, collisions) and
#      remote juice components that listen on a signal bus. Essential for the
#      signal relay pattern where juice comps live on a persistent camera
#      rig or screen receiver in a different scene than the trigger.
# SYSTEM: Juicing System (addons/Juice_V1/) - Utility
# DOES NOT: Produce any visual effect. This is a pure signal-routing node.
##
## USAGE:
## 1. Add as child of a node that emits a signal (Clickable3DComp, Button, etc.)
## 2. Set listen_signal to the local signal name (e.g., "left_clicked", "pressed")
## 3. Set emit_signal_name to the signal bus signal (e.g., "camera_shake_test_requested")
## 4. The remote juice comp uses manual_trigger_signal + trigger_source_path
##    pointed at your signal bus autoload to receive the relayed signal.
## ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceUtilitySignals.svg")
class_name SignalRelayJuiceUtility
extends Node


# =============================================================================
# CONFIGURATION
# =============================================================================

## Signal name to listen for on the source node.
## Common values: "left_clicked", "right_clicked", "pressed", "body_entered"
@export var listen_signal: String = "left_clicked"

## Path to the node that emits listen_signal.
## Leave empty to use parent node.
@export_node_path("Node") var listen_source_path: NodePath

## Signal name to emit on the signal bus when the listen signal fires.
## Must match a signal declared on the target signal bus autoload.
@export var emit_signal_name: String = ""

## Path to the signal bus node that receives emitted signals.
## Autoloads in Godot are children of /root/, so an autoload named
## "SignalBus" is reached at "/root/SignalBus". Change this if your
## project uses a different autoload name (e.g., "/root/EventBus").
@export_node_path("Node") var signal_bus_path: NodePath = "/root/SignalBus"

@export_group("Debug")
@export var debug_enabled: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	var source: Node
	if listen_source_path.is_empty():
		source = get_parent()
	else:
		source = get_node_or_null(listen_source_path)

	if source == null:
		push_warning("[%s] SignalRelay: source node not found (path: %s)" % [
			name, listen_source_path])
		return

	if not source.has_signal(listen_signal):
		push_warning("[%s] SignalRelay: signal '%s' not found on '%s'" % [
			name, listen_signal, source.name])
		return

	if emit_signal_name.is_empty():
		push_warning("[%s] SignalRelay: emit_signal_name is empty" % name)
		return

	var bus := _get_signal_bus()
	if bus == null:
		push_warning("[%s] SignalRelay: signal bus not found at '%s'" % [
			name, signal_bus_path])
		return

	if not bus.has_signal(emit_signal_name):
		push_warning("[%s] SignalRelay: signal bus at '%s' has no signal '%s'" % [
			name, signal_bus_path, emit_signal_name])
		return

	source.connect(listen_signal, _on_source_triggered)

	if debug_enabled:
		print("[%s] SignalRelay: '%s' on '%s' → '%s'.'%s'" % [
			name, listen_signal, source.name, signal_bus_path, emit_signal_name])


func _on_source_triggered(_interactor: Variant = null) -> void:
	var bus := _get_signal_bus()
	if bus:
		bus.emit_signal(emit_signal_name)
		if debug_enabled:
			print("[%s] SignalRelay: emitted '%s' on '%s'" % [
				name, emit_signal_name, signal_bus_path])


func _get_signal_bus() -> Node:
	return get_node_or_null(signal_bus_path)
