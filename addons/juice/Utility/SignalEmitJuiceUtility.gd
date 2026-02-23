## SignalEmitJuiceUtility.gd
## ============================================================================
## WHAT: Emits a custom signal when triggered, allowing game systems to react
##       to juice events without tight coupling.
## WHY: Decouples juice animations from game logic. Designers can wire "when
##       this juice completes → emit signal X" purely in inspector.
## SYSTEM: Juicing System (addons/juice/Events and Time/)
## DOES NOT: Create any visual effect. This is a control/flow component only.
## ============================================================================
##
## LIFECYCLE:
##   Follows the Sequencer pattern — overrides animate_in()/animate_out()/stop()
##   and bypasses the base class animation loop entirely. The base class is only
##   used for trigger infrastructure (auto-connect, signal wiring) and chaining.
##
## USAGE:
## - Add as child of any node or in a juice chain
## - Connect other nodes to this component's `juice_signal` signal
## - Configure when to emit (on start, on complete, or both)
##
## EXAMPLES:
## - Chain: ScaleJuice → SignalEmitJuice → ColorJuice
##   When scale completes, signal fires, then color starts
## - Standalone: Button press → SignalEmitJuice(on_start)
##   Immediately notifies game system that button was pressed
## ============================================================================

@tool
class_name SignalEmitJuiceUtility
extends JuiceCompBase

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

@export_group("Signal Emission")

## Descriptive name for this signal (for documentation/debugging only).
## The actual signal emitted is always `juice_signal`.
@export var signal_description: String = "juice_triggered"

## Optional payload data to pass with the signal.
## Can be any Variant: String, int, Resource, etc.
@export var payload: Variant = null

## When to emit the signal
@export var emit_on: EmitTiming = EmitTiming.ON_START

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Coroutine generation counter — incremented on stop() and new triggers.
## Used to abort stale coroutines after start_delay awaits.
var _generation: int = 0

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()


# =============================================================================
# PUBLIC API — Sequencer pattern: bypass base class animation loop
# =============================================================================

## Trigger signal emission. Overrides base class to bypass the animation loop.
func animate_in() -> void:
	_do_animate()


## Also trigger on animate_out — control flow comps fire regardless of direction.
func animate_out(_is_one_shot: bool = false) -> void:
	_do_animate()


func _do_animate() -> void:
	_generation += 1
	var my_gen := _generation
	
	# Respect start_delay from base class
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
		if _generation != my_gen:
			return
	
	_is_playing = true
	started.emit()
	
	# Fire signal on start
	if emit_on == EmitTiming.ON_START or emit_on == EmitTiming.ON_BOTH:
		_emit_juice_signal()
	
	# Fire signal on complete (same call stack for instant comp)
	if emit_on == EmitTiming.ON_COMPLETE or emit_on == EmitTiming.ON_BOTH:
		_emit_juice_signal()
	
	_is_playing = false
	completed.emit()
	
	if debug_enabled:
		print("[%s] Completed" % name)
	
	_trigger_next_component()
	
	# Process queued trigger if one was stored by _handle_trigger()
	if not _queued_trigger.is_empty():
		var queued := _queued_trigger
		_queued_trigger = {}
		_handle_trigger(queued)


## Stop immediately. Increments generation to abort any pending start_delay.
func stop() -> void:
	_generation += 1
	_is_playing = false


## No visual effect — control flow component.
func _apply_effect(_progress: float) -> void:
	pass

# =============================================================================
# INTERNAL
# =============================================================================

func _emit_juice_signal() -> void:
	juice_signal.emit(payload)
	
	if debug_enabled:
		var timing_str: String = EmitTiming.keys()[emit_on]
		print("[%s] Signal emitted (%s). Payload: %s" % [name, timing_str, payload])
