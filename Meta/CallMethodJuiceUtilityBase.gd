## Base class for method-call utilities.
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
# INSPECTOR LAYOUT:
#   ▼ Trigger
#       Trigger Behaviour  — Play In And Out fires on start AND reverse
#       Start Delay        — delays when the call fires in a sequence
#       Loop Count         — enables rhythmic repeated calls
#       [loop options: ping_pong, loop_delay, loop_phase_offset]
#       Target Node Path   — relative to the host JuiceBase; empty = juiced target
#       Method Name        — name of the method to call
#       Arguments          — Array of arguments passed to the method
#       Call On            — On Start / On Complete / On Both
#
# CROSSFADE TIME is intentionally hidden — it blends _animation_progress,
# but _apply_effect is a no-op here so crossfade has no observable effect.
#
# TARGET RESOLUTION:
#   target_node_path resolves relative to _host_node (the JuiceBase node).
#   Leave empty to call on the juiced target node itself (passed via _apply_effect).
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceUtilityMethods.svg")
class_name CallMethodJuiceUtilityBase
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

func _init() -> void:
	_subclass_owns_effect_group = true

## Path to the node containing the method, resolved relative to the host
## JuiceBase node. Leave empty to call on the juiced target node itself.
var target_node_path: NodePath

## Name of the method to call on the target node.
var method_name: String = ""

## Arguments to pass. Each element is one argument (any Variant type).
var arguments: Array = []

## When to call the method relative to the animation lifecycle.
var call_on: CallTiming = CallTiming.ON_START


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# Single "Trigger" group — meta effects have no visual properties.
	props.append({"name": "Trigger", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})

	# Trigger Behaviour: kept — Play In And Out fires on start AND reverse,
	# which is useful to sync method calls with in-and-out visual effects.
	props.append({"name": "trigger_behaviour", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Play In And Out,Play In Only,Play Out Only,Toggle,Set From Source",
		"usage": PROPERTY_USAGE_DEFAULT})

	props.append({"name": "start_delay", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,100.0,0.01,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})

	# loop_count != 1 enables rhythmic repeated calls (e.g. periodic events).
	props.append({"name": "loop_count", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT})
	if loop_count != 1:
		props.append({"name": "ping_pong", "type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "loop_delay", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "loop_phase_offset", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
			"usage": PROPERTY_USAGE_DEFAULT})

	# Crossfade Time intentionally omitted — see file header.

	props.append({"name": "target_node_path", "type": TYPE_NODE_PATH,
		"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES, "hint_string": "Node",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "method_name", "type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "arguments", "type": TYPE_ARRAY,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "call_on", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "On Start,On Complete,On Both",
		"usage": PROPERTY_USAGE_DEFAULT})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"target_node_path": target_node_path = value; return true
		&"method_name":      method_name      = value; return true
		&"arguments":        arguments        = value; return true
		&"call_on":          call_on          = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"target_node_path": return target_node_path
		&"method_name":      return method_name
		&"arguments":        return arguments
		&"call_on":          return call_on
	return null


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
