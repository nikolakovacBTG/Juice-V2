## Lightweight relay that listens for local signals and re-emits them on a global signal bus.
##
## Bridges the gap between local triggers (clicks, collisions) and remote juice components
## that listen on a signal bus. Essential for the signal relay pattern where juice comps live
## in a different scene than the trigger.

# ============================================================================
# WHAT: Lightweight relay that listens for a signal on a local node and
#       re-emits a named signal on a global signal bus autoload.
# WHY: Bridges the gap between local triggers and remote juice components.
# SYSTEM: Juice System (addons/Juice_V1/) - Utility
# DOES NOT: Produce any visual effect. This is a pure signal-routing node.
#
# USAGE:
# 1. Add as child of a node that emits a signal (Clickable3DComp, Button, etc.)
# 2. Set listen_signal to the local signal name (e.g., "left_clicked", "pressed")
# 3. Set emit_signal_name to the signal bus signal (e.g., "camera_shake_test_requested")
# 4. The remote juice comp uses manual_trigger_signal + trigger_source_path
#    pointed at your signal bus autoload to receive the relayed signal.
# ============================================================================

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
## Prints detailed state changes and logic paths to the console.
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
		JuiceLogger.warn(self, "SignalRelay",
				"source node not found (path: %s)" % listen_source_path,
				debug_enabled)
		return

	if not source.has_signal(listen_signal):
		JuiceLogger.warn(self, "SignalRelay",
				"signal '%s' not found on '%s'" % [listen_signal, source.name],
				debug_enabled)
		return

	if emit_signal_name.is_empty():
		JuiceLogger.warn(self, "SignalRelay",
				"emit_signal_name is empty", debug_enabled)
		return

	var bus := _get_signal_bus()
	if bus == null:
		JuiceLogger.warn(self, "SignalRelay",
				"signal bus not found at '%s'" % signal_bus_path,
				debug_enabled)
		return

	if not bus.has_signal(emit_signal_name):
		JuiceLogger.warn(self, "SignalRelay",
				"signal bus at '%s' has no signal '%s'" % [
				signal_bus_path, emit_signal_name],
				debug_enabled)
		return

	source.connect(listen_signal, _on_source_triggered)

	JuiceLogger.log_info(self, "SignalRelay",
			"'%s' on '%s' → '%s'.'%s'" % [
			listen_signal, source.name, signal_bus_path, emit_signal_name],
			debug_enabled)


func _on_source_triggered(_interactor: Variant = null) -> void:
	var bus := _get_signal_bus()
	if bus:
		bus.emit_signal(emit_signal_name)
		JuiceLogger.log_info(self, "SignalRelay",
				"emitted '%s' on '%s'" % [emit_signal_name, signal_bus_path],
				debug_enabled)


func _get_signal_bus() -> Node:
	return get_node_or_null(signal_bus_path)
