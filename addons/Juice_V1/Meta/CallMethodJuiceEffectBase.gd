## Base class for method-call effects.
##
## Calls a named method on a target node at the configured timing.
## Domain-agnostic — no visual output.

# ============================================================================
# WHAT: Calls any method on any node when an animation starts or completes.
# WHY:  Allows designers to wire "when this animation fires → call method X"
#       purely in the inspector, without writing custom scripts. Replaces V0
#       CallMethodJuiceUtility (standalone Node) with a chainable Resource that
#       participates in the recipe stack: start_delay, chain_to, loop all work.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# DOES NOT: Produce any visual effect — control/flow only.
# DOES NOT: Handle return values from called methods.
# DOES NOT: Block animation completion — calls and immediately completes.
#
# TARGET RESOLUTION:
#   target_node_path resolves relative to _host_node (the JuiceBase node).
#   Leave empty to call on the juiced target node itself (passed via _apply_effect).
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceUtilityMethods.svg")
class_name CallMethodJuiceEffectBase
extends JuiceEffectBase


# =============================================================================
# ENUMS
# =============================================================================

## When to call the method relative to the animation lifecycle.
enum CallTiming {
	ON_START,    ## Call when animate_in() begins (after start_delay).
	ON_COMPLETE, ## Call when animation reaches peak (progress=1.0).
	ON_BOTH,     ## Call on both start and complete.
}


# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Method Call")

## Path to the node containing the method. Resolved relative to the host
## JuiceBase node. Leave empty to call on the juiced target node itself.
@export_node_path("Node") var target_node_path: NodePath

## Name of the method to call on the target node.
@export var method_name: String = ""

## Arguments to pass. Each element is one argument (any Variant type).
@export var arguments: Array = []

## When to call the method relative to the animation.
@export var call_on: CallTiming = CallTiming.ON_START


# =============================================================================
# INTERNAL STATE
# =============================================================================

## Cached target node reference. Resolved in _on_animate_start.
var _method_target: Node = null


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

func _on_animate_start(target: Node) -> void:
	_resolve_method_target(target)
	if call_on == CallTiming.ON_START or call_on == CallTiming.ON_BOTH:
		_call_method()


func _on_animate_in_complete(_target: Node) -> void:
	if call_on == CallTiming.ON_COMPLETE or call_on == CallTiming.ON_BOTH:
		_call_method()


func _apply_effect(_progress: float, _target: Node) -> void:
	pass  # No visual output — method call happens in lifecycle hooks.


func _restore_to_natural(_target: Node) -> void:
	_method_target = null


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if method_name.is_empty():
		warnings.append("method_name is empty — no method will be called.")
	return warnings


# =============================================================================
# HELPERS
# =============================================================================

func _resolve_method_target(fallback_target: Node) -> void:
	if not target_node_path.is_empty():
		if _host_node != null:
			_method_target = _host_node.get_node_or_null(target_node_path)
		if _method_target == null and debug_enabled:
			push_warning("[CallMethod] target_node_path '%s' not found from host" % target_node_path)
	else:
		_method_target = fallback_target  # Default: the juiced node itself


func _call_method() -> void:
	if not is_instance_valid(_method_target):
		if debug_enabled:
			push_warning("[CallMethod] No valid target node to call '%s'" % method_name)
		return

	if method_name.is_empty():
		if debug_enabled:
			push_warning("[CallMethod] method_name is empty")
		return

	if not _method_target.has_method(method_name):
		push_warning("[CallMethod] '%s' doesn't have method '%s'" % [
			_method_target.name, method_name])
		return

	if arguments.is_empty():
		_method_target.call(method_name)
	else:
		_method_target.callv(method_name, arguments)

	if debug_enabled:
		var args_str := str(arguments) if not arguments.is_empty() else "()"
		print("[CallMethod] Called %s.%s%s" % [_method_target.name, method_name, args_str])
