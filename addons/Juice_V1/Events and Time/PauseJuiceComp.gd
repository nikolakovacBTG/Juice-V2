## PauseJuiceComp.gd
## ============================================================================
## WHAT: Inserts a delay/pause in a juice chain before continuing.
## WHY: Allows timing control in juice sequences without modifying individual
##      component delays. Useful for dramatic pauses, staggered effects.
## SYSTEM: Juicing System (addons/juice/Events and Time/)
## DOES NOT: Create any visual effect. This is a control/flow component only.
## ============================================================================
##
## LIFECYCLE:
##   Follows the Sequencer pattern — overrides animate_in()/animate_out()/stop()
##   and bypasses the base class animation loop entirely. Uses create_timer()
##   for the pause duration, with the process_always parameter controlling
##   whether the timer respects Engine.time_scale.
##
## CHAIN-SCOPED DELAY vs start_delay:
##   PauseJuiceComp only delays when the chain reaches it. If the NEXT comp
##   in the chain is triggered independently (not through the chain), there's
##   no delay. start_delay on a comp fires every time that comp is triggered,
##   regardless of source. This distinction justifies PauseJuiceComp's existence.
##
## USAGE:
## - Add in a juice chain where you need a delay
## - Set pause_duration to desired wait time
## - Optionally use_realtime to ignore time scale
##
## EXAMPLES:
## - Dramatic pause: ScaleJuice → PauseJuice(0.5) → FlashJuice
## - Staggered reveal: FadeIn → PauseJuice(0.2) → SlideIn
## ============================================================================

@tool
@icon("res://addons/Juice_V1/Icons/JuiceBaseEvents.svg")
class_name PauseJuiceComp
extends JuiceCompBase

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Effect")

## Duration of the pause in seconds.
@export var pause_duration: float = 0.5

## If true, use real time (ignores Engine.time_scale).
## Useful for UI pauses during slow-motion effects.
@export var use_realtime: bool = false

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Coroutine generation counter — incremented on stop() and new triggers.
## Used to abort stale coroutines if stop() is called during the pause.
var _generation: int = 0

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()


# =============================================================================
# PUBLIC API — Sequencer pattern: bypass base class animation loop
# =============================================================================

## Start the pause. Overrides base class to bypass the animation loop.
func animate_in() -> void:
	_do_animate()


## Also works on animate_out — pause duration is the same in both directions.
func animate_out(_is_one_shot: bool = false) -> void:
	_do_animate()


func _do_animate() -> void:
	_generation += 1
	var my_gen := _generation
	
	# Respect start_delay from base class (fires before the pause itself)
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
		if _generation != my_gen:
			return
	
	_is_playing = true
	started.emit()
	
	if debug_enabled:
		var realtime_str := " (realtime)" if use_realtime else ""
		print("[%s] Pause started: %.2fs%s" % [name, pause_duration, realtime_str])
	
	# Wait for the pause duration.
	# create_timer second parameter is process_always:
	#   true = runs in real time (ignores Engine.time_scale)
	#   false = respects Engine.time_scale (default Godot behavior)
	if pause_duration > 0.0:
		await get_tree().create_timer(pause_duration, use_realtime).timeout
		if _generation != my_gen:
			return  # Aborted by stop() during pause
	
	_is_playing = false
	
	if debug_enabled:
		print("[%s] Pause complete" % name)
	
	completed.emit()
	_trigger_next_component()
	
	# Process queued trigger if one was stored by _handle_trigger()
	if not _queued_trigger.is_empty():
		var queued := _queued_trigger
		_queued_trigger = {}
		_handle_trigger(queued)


## Stop immediately. Increments generation to abort the pending timer.
func stop() -> void:
	_generation += 1
	_is_playing = false


## No visual effect — control flow component.
func _apply_effect(_progress: float) -> void:
	pass
