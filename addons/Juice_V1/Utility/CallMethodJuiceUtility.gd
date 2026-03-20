## CallMethodJuiceUtility.gd
## ============================================================================
## WHAT: Calls any method on any node when triggered, enabling designer-driven
##       function calls without writing custom scripts.
## WHY: Allows wiring "when juice triggers → call method X" in inspector.
##      Useful for playing sounds, spawning effects, or any simple action.
## SYSTEM: Juicing System (addons/juice/Events and Time/)
## DOES NOT: Create any visual effect. This is a control/flow component only.
##           Does NOT handle return values from called methods.
## ============================================================================
##
## LIFECYCLE:
##   Follows the Sequencer pattern — overrides animate_in()/animate_out()/stop()
##   and bypasses the base class animation loop entirely. The base class is only
##   used for trigger infrastructure (auto-connect, signal wiring) and chaining.
##
## USAGE:
## - Add as child of any node or in a juice chain
## - Set target_node_path to the node containing the method
## - Set method_name to the method to call
## - Optionally add arguments to pass
##
## EXAMPLES:
## - Call AudioManager.play_sound("click") on button press
## - Call enemy.take_damage(10) when attack animation completes
## - Call particle_system.emit() when effect triggers
## ============================================================================

@tool
@icon("res://addons/Juice_V1/Icons/JuiceUtilityMethods.svg")
class_name CallMethodJuiceUtility
extends JuiceCompBase

# =============================================================================
# ENUMS
# =============================================================================

## When to call the method relative to component lifecycle.
## For an instant comp, ON_START fires first, then ON_COMPLETE fires
## immediately after (same call stack). The distinction is for readability:
## ON_START = "fire when triggered", ON_COMPLETE = "fire just before chaining".
enum CallTiming {
	ON_START,    ## Call when animate_in() begins
	ON_COMPLETE, ## Call just before completion and chaining
	ON_BOTH      ## Call on both start and complete
}

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Method Call")

## Path to the node containing the method to call.
## Leave empty to call on parent node.
@export_node_path("Node") var target_node_path: NodePath

## Name of the method to call on the target node.
@export var method_name: String = ""

## Arguments to pass to the method.
## Each array element is one argument.
@export var arguments: Array = []

## When to call the method
@export var call_on: CallTiming = CallTiming.ON_START

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _method_target: Node = null

## Coroutine generation counter — incremented on stop() and new triggers.
## Used to abort stale coroutines after start_delay awaits.
var _generation: int = 0

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()
	_resolve_target()


func _resolve_target() -> void:
	if target_node_path.is_empty():
		_method_target = get_parent()
	else:
		_method_target = get_node_or_null(target_node_path)


# =============================================================================
# PUBLIC API — Sequencer pattern: bypass base class animation loop
# =============================================================================

## Trigger the method call. Overrides base class to bypass the animation loop.
## The base class trigger infrastructure (auto-connect, _handle_trigger) calls
## this method, so all trigger wiring works unchanged.
func animate_in() -> void:
	_do_animate()


## Also trigger on animate_out — control flow comps fire regardless of direction.
func animate_out(_is_one_shot: bool = false) -> void:
	_do_animate()


func _do_animate() -> void:
	# Retrigger is already handled by _handle_trigger() in the base class
	# before it calls animate_in()/animate_out(). For synchronous comps
	# (no await), _is_playing is false by the time we return, so retrigger
	# never applies. But we guard start_delay with _generation just in case.
	
	_generation += 1
	var my_gen := _generation
	
	# Respect start_delay from base class
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
		if _generation != my_gen:
			return  # Aborted by stop() or retrigger during delay
	
	_is_playing = true
	started.emit()
	
	# Fire method on start
	if call_on == CallTiming.ON_START or call_on == CallTiming.ON_BOTH:
		_call_method()
	
	# Fire method on complete (same call stack for instant comp)
	if call_on == CallTiming.ON_COMPLETE or call_on == CallTiming.ON_BOTH:
		_call_method()
	
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

func _call_method() -> void:
	if not is_instance_valid(_method_target):
		_resolve_target()
		if not is_instance_valid(_method_target):
			push_warning("[%s] Cannot call method - no valid target node" % name)
			return
	
	if method_name.is_empty():
		push_warning("[%s] Cannot call method - method_name is empty" % name)
		return
	
	if not _method_target.has_method(method_name):
		push_warning("[%s] Target '%s' doesn't have method '%s'" % [name, _method_target.name, method_name])
		return
	
	# Call the method with arguments
	if arguments.is_empty():
		_method_target.call(method_name)
	else:
		_method_target.callv(method_name, arguments)
	
	if debug_enabled:
		var args_str := str(arguments) if not arguments.is_empty() else "()"
		print("[%s] Called %s.%s%s" % [name, _method_target.name, method_name, args_str])

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	
	if method_name.is_empty():
		warnings.append("method_name is empty. No method will be called.")
	
	# Try to validate target and method at edit time
	var target: Node = null
	if target_node_path.is_empty():
		target = get_parent()
	else:
		target = get_node_or_null(target_node_path)
	
	if target != null and not method_name.is_empty():
		if not target.has_method(method_name):
			warnings.append("Target node '%s' doesn't have method '%s'" % [target.name, method_name])
	
	return warnings
