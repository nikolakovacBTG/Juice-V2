## LooperJuiceComp.gd
## ============================================================================
## WHAT: Repeats a juice component or chain multiple times with optional delay.
## WHY: Enables repeated effects without duplicating nodes. Useful for bounces,
##      pulses, attention-grabbing loops, or any repeating juice pattern.
##      Distinct from JuiceCompBase's built-in loop_count because it provides
##      EXTERNAL loop control — can loop any comp (including chained comps)
##      and then continue to the next component in ITS OWN chain.
## SYSTEM: Juicing System (addons/juice/Events and Time/)
## DOES NOT: Create any visual effect. This is a control/flow component only.
## ============================================================================
##
## LIFECYCLE:
##   Follows the Sequencer pattern — overrides animate_in()/animate_out()/stop()
##   and bypasses the base class animation loop entirely. Triggers the target
##   comp for each iteration, awaits its completed signal, optionally waits for
##   delay_between, then repeats. The _generation counter aborts stale coroutines.
##
## USAGE:
## - Add as child with a juice component to loop as its child
## - OR set loop_target to point to another component
## - Configure repeat_count (-1 for infinite)
## - Optionally set delay_between iterations
##
## EXAMPLES:
## - Bounce 3 times: LooperJuice(repeat=3) → ScaleJuice(one_shot)
## - Pulse infinitely: LooperJuice(repeat=-1, delay=1.0) → FadeJuice(bidirectional)
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBaseEvents.svg") 
class_name LooperJuiceComp
extends JuiceCompBase

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Effect")

## Component to loop. If empty, uses first JuiceCompBase child.
@export_node_path("Node") var loop_target: NodePath

## Number of times to repeat. -1 = infinite loop.
@export var repeat_count: int = 3

## Delay in seconds between each iteration.
@export var delay_between: float = 0.0

## If true, use real time for delay_between (ignores Engine.time_scale).
@export var use_realtime: bool = false

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _target_component: JuiceCompBase = null
var _current_iteration: int = 0

## Coroutine generation counter — incremented on stop() and new triggers.
## Used to abort stale coroutines between iterations.
var _generation: int = 0

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()
	_resolve_target()


func _resolve_target() -> void:
	if not loop_target.is_empty():
		var target := get_node_or_null(loop_target)
		if target is JuiceCompBase:
			_target_component = target
	else:
		# Find first JuiceCompBase child (type-safe discovery)
		for child in get_children():
			if child is JuiceCompBase:
				_target_component = child
				break


# =============================================================================
# PUBLIC API — Sequencer pattern: bypass base class animation loop
# =============================================================================

## Start looping. Overrides base class to bypass the animation loop.
func animate_in() -> void:
	_do_animate(false)


## Also works on animate_out — loops animate_out on the target.
func animate_out(_is_one_shot: bool = false) -> void:
	_do_animate(true)


func _do_animate(is_reverse: bool) -> void:
	# Handle retrigger if already playing
	if _is_playing:
		match retrigger_policy:
			RetriggerPolicy.IGNORE:
				return
			RetriggerPolicy.QUEUE_ONE:
				_queued_trigger = {"is_reverse": is_reverse}
				return
			RetriggerPolicy.RESTART:
				stop()
	
	_generation += 1
	var my_gen := _generation
	
	# Respect start_delay from base class
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
		if _generation != my_gen:
			return
	
	# Resolve target if not cached
	if _target_component == null:
		_resolve_target()
	
	if _target_component == null:
		push_warning("[%s] No target component to loop" % name)
		return
	
	_is_playing = true
	_current_iteration = 0
	started.emit()
	
	# Main loop
	while true:
		# Check finite loop limit
		if repeat_count >= 0 and _current_iteration >= repeat_count:
			break
		
		# Check target validity
		if not is_instance_valid(_target_component):
			push_warning("[%s] Target component destroyed during loop" % name)
			break
		
		_current_iteration += 1
		
		if debug_enabled:
			var count_str := str(repeat_count) if repeat_count >= 0 else "∞"
			print("[%s] Loop iteration %d/%s" % [name, _current_iteration, count_str])
		
		# Trigger target and wait for it to complete
		if is_reverse:
			_target_component.animate_out()
		else:
			_target_component.animate_in()
		
		# Wait for target to finish — but only if it actually started.
		# Guards against stall when target fails (e.g. no _target_node in editor).
		if _target_component.is_playing():
			await _target_component.completed
			if _generation != my_gen:
				return  # Aborted by stop() or retrigger
		elif debug_enabled:
			push_warning("[%s] Loop target '%s' did not start — skipping await" % [name, _target_component.name])
		
		# Delay between iterations (skip after last iteration)
		var has_more := repeat_count < 0 or _current_iteration < repeat_count
		if delay_between > 0.0 and has_more:
			await get_tree().create_timer(delay_between, use_realtime).timeout
			if _generation != my_gen:
				return
	
	# All iterations complete
	_is_playing = false
	
	if debug_enabled:
		print("[%s] Loop complete after %d iterations" % [name, _current_iteration])
	
	completed.emit()
	_trigger_next_component()
	
	# Process queued trigger
	if not _queued_trigger.is_empty():
		var queued := _queued_trigger
		_queued_trigger = {}
		_handle_trigger(queued)


## Stop immediately. Stops target and aborts pending coroutine.
func stop() -> void:
	_generation += 1
	_is_playing = false
	if is_instance_valid(_target_component):
		if _target_component.is_playing():
			_target_component.stop()


## No visual effect — control flow component.
func _apply_effect(_progress: float) -> void:
	pass

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	
	var has_target := false
	
	if not loop_target.is_empty():
		var target := get_node_or_null(loop_target)
		if target == null:
			warnings.append("loop_target points to invalid node")
		elif not target is JuiceCompBase:
			warnings.append("loop_target must be a JuiceCompBase")
		else:
			has_target = true
	else:
		# Check for child JuiceCompBase
		for child in get_children():
			if child is JuiceCompBase:
				has_target = true
				break
	
	if not has_target:
		warnings.append("No JuiceCompBase target to loop. Add a child or set loop_target.")
	
	if repeat_count == 0:
		warnings.append("repeat_count is 0. Loop will never execute.")
	
	return warnings
