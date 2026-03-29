## SignalEmitJuiceUtility.gd
## ============================================================================
## WHAT: Emits a custom signal when triggered, allowing game systems to react
##       to juice events without tight coupling.
## WHY: Decouples juice animations from game logic. Designers can wire "when
##       this juice completes → emit signal X" purely in inspector.
## SYSTEM: Juicing System (addons/Juice_V1/Utilities/)
## DOES NOT: Create any visual effect. This is a control/flow utility only.
## ============================================================================
##
## LIFECYCLE:
##   Observes a sibling JuiceBase node (JuiceControl/Juice2D/Juice3D). When that
##   node fires animate_in_started or completed, this utility emits juice_signal.
##
## USAGE:
## - Add as sibling of a JuiceBase node
## - Set observe_juice to point at the JuiceBase node
## - Connect other nodes to this utility's `juice_signal` signal
## - Configure when to emit (on start, on complete, or both)
##
## EXAMPLES:
## - Notify game system when a JuiceControl animation completes
## - Standalone: emit a signal when any juice effect triggers
## ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceUtilitySignals.svg")
class_name SignalEmitJuiceUtility
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Custom signal emitted when this component triggers.
## Connect other systems to this signal to react to juice events.
## The payload parameter is optional data configured in inspector.
signal juice_signal(payload: Variant)

# =============================================================================
# ENUMS
# =============================================================================

## When to emit the signal relative to component lifecycle.
## For an instant comp, ON_START fires first, then ON_COMPLETE fires
## immediately after (same call stack). The distinction is for readability:
## ON_START = "fire when triggered", ON_COMPLETE = "fire just before chaining".
enum EmitTiming {
	ON_START,    ## Emit when animate_in() begins
	ON_COMPLETE, ## Emit just before completion and chaining
	ON_BOTH      ## Emit on both start and complete
}

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Observe")

## JuiceBase node (JuiceControl/Juice2D/Juice3D) whose events trigger this utility.
## Leave empty to auto-detect the first JuiceBase sibling.
@export_node_path("Node") var observe_juice: NodePath

## When to emit the signal relative to the observed node's lifecycle.
@export var emit_on: EmitTiming = EmitTiming.ON_COMPLETE

@export_group("Signal Emission")

## Descriptive name for this signal (for documentation/debugging only).
## The actual signal emitted is always `juice_signal`.
@export var signal_description: String = "juice_triggered"

## Optional payload data to pass with the signal.
## Can be any Variant: String, int, Resource, etc.
@export var payload: Variant = null

@export_group("Timing")

## Optional delay in seconds before the signal fires after the trigger.
@export_range(0.0, 10.0, 0.01, "suffix:s") var start_delay: float = 0.0

@export_group("Debug")

## Enable debug output to console.
@export var debug_enabled: bool = false

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _generation: int = 0


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var juice := _resolve_juice()
	if juice == null:
		push_warning("[%s] No JuiceBase found. Set observe_juice or add a JuiceBase sibling." % name)
		return
	if emit_on in [EmitTiming.ON_START, EmitTiming.ON_BOTH]:
		juice.animate_in_started.connect(_on_trigger)
	if emit_on in [EmitTiming.ON_COMPLETE, EmitTiming.ON_BOTH]:
		juice.completed.connect(_on_trigger)
	if debug_enabled:
		print("[%s] Observing '%s' (timing: %s)" % [name, juice.name, EmitTiming.keys()[emit_on]])


func _resolve_juice() -> JuiceBase:
	if not observe_juice.is_empty():
		return get_node_or_null(observe_juice) as JuiceBase
	# Auto-detect first JuiceBase sibling
	if get_parent():
		for sibling in get_parent().get_children():
			if sibling is JuiceBase and sibling != self:
				return sibling as JuiceBase
	return null


# =============================================================================
# TRIGGER HANDLER
# =============================================================================

func _on_trigger() -> void:
	_generation += 1
	var my_gen := _generation
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
		if _generation != my_gen:
			return
	_emit_juice_signal()

# =============================================================================
# INTERNAL
# =============================================================================

func _emit_juice_signal() -> void:
	juice_signal.emit(payload)
	
	if debug_enabled:
		var timing_str: String = EmitTiming.keys()[emit_on]
		print("[%s] Signal emitted (%s). Payload: %s" % [name, timing_str, payload])
