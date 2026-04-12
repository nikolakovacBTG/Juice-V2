## Calls any method on any node when triggered, enabling designer-driven function calls.
##
## Allows wiring "when juice triggers → call method X" in inspector.
## Useful for playing sounds, spawning effects, or any simple action.

# ============================================================================
# WHAT: Calls any method on any node when triggered, enabling designer-driven
#       function calls without writing custom scripts.
# WHY: Allows wiring "when juice triggers → call method X" in inspector.
# SYSTEM: Juice System (addons/Juice_V1/Utilities/)
# DOES NOT: Create any visual effect. This is a control/flow utility only.
#           Does NOT handle return values from called methods.
#
# LIFECYCLE:
#   Observes a sibling JuiceBase node (JuiceControl/Juice2D/Juice3D). When that
#   node fires animate_in_started or completed, this utility calls the method.
#
# USAGE:
# - Add as sibling of a JuiceBase node
# - Set observe_juice to point at the JuiceBase node
# - Set target_node_path to the node containing the method
# - Set method_name to the method to call
# - Optionally add arguments to pass
#
# EXAMPLES:
# - Call AudioManager.play_sound("click") on button press
# - Call enemy.take_damage(10) when attack animation completes
# - Call particle_system.emit() when effect triggers
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceUtilityMethods.svg")
class_name CallMethodJuiceUtility
extends Node

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

@export_group("Observe")

## JuiceBase node (JuiceControl/Juice2D/Juice3D) whose events trigger this utility.
## Leave empty to auto-detect the first JuiceBase sibling.
@export_node_path("Node") var observe_juice: NodePath

## When to call the method relative to the observed node's lifecycle.
@export var call_on: CallTiming = CallTiming.ON_COMPLETE

@export_group("Method Call")

## Path to the node containing the method to call.
## Leave empty to call on parent node.
@export_node_path("Node") var target_node_path: NodePath

## Name of the method to call on the target node.
@export var method_name: String = ""

## Arguments to pass to the method. Each array element is one argument.
@export var arguments: Array = []

@export_group("Timing")

## Optional delay in seconds before the method call fires after the trigger.
@export_range(0.0, 10.0, 0.01, "suffix:s") var start_delay: float = 0.0

@export_group("Debug")

## Enable debug output to console.
@export var debug_enabled: bool = false

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _method_target: Node = null
var _generation: int = 0


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_resolve_target()
	var juice := _resolve_juice()
	if juice == null:
		push_warning("[%s] No JuiceBase found. Set observe_juice or add a JuiceBase sibling." % name)
		return
	if call_on in [CallTiming.ON_START, CallTiming.ON_BOTH]:
		juice.animate_in_started.connect(_on_trigger)
	if call_on in [CallTiming.ON_COMPLETE, CallTiming.ON_BOTH]:
		juice.completed.connect(_on_trigger)
	if debug_enabled:
		print("[%s] Observing '%s' (timing: %s)" % [name, juice.name, CallTiming.keys()[call_on]])


func _resolve_juice() -> JuiceBase:
	if not observe_juice.is_empty():
		return get_node_or_null(observe_juice) as JuiceBase
	# Auto-detect first JuiceBase sibling
	if get_parent():
		for sibling in get_parent().get_children():
			if sibling is JuiceBase and sibling != self:
				return sibling as JuiceBase
	return null


func _resolve_target() -> void:
	if target_node_path.is_empty():
		_method_target = get_parent()
	else:
		_method_target = get_node_or_null(target_node_path)


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
	_call_method()

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
