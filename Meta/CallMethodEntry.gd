## One method-call entry in a CallMethodJuiceUtilityBase entries array.
##
## Each entry targets its own node, calls its own method with its own arguments,
## and fires at its own timing. Multiple entries = multiple calls from one utility.

# =============================================================================
# WHAT: Sub-resource representing one method call to make.
#       Stores target node path, method name, arguments, and timing.
# WHY:  Enables one CallMethod utility to trigger multiple distinct method calls
#       at different lifecycle points — mirrors the recipe-item paradigm.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# DOES NOT: Execute the call — the parent utility does that in lifecycle hooks.
# =============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceUtilityMethods.svg")
class_name CallMethodEntry
extends Resource


# =============================================================================
# CONFIGURATION
# =============================================================================

## Path to the node containing the method, resolved relative to the host
## JuiceBase node. Leave empty to call on the juiced target node itself.
var target_node_path: NodePath = NodePath()

## Name of the method to call on the target node.
var method_name: String = ""

## Arguments to pass. Each element is one argument (any Variant type).
var arguments: Array = []

## When to call the method relative to the animation lifecycle.
## 0 = On Start, 1 = On Complete, 2 = On Both.
var call_on: int = 0


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
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
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if method_name.is_empty():
		warnings.append("method_name is empty — no method will be called.")
	return warnings
