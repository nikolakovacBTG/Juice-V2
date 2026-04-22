## Base sub-resource representing one animated property binding in a PropertyEffect.
##
## Stores a node path + property path and caches the auto-detected value type.
## Subclasses (NoisePropertyTarget, ShakePropertyTarget, etc.) add effect-
## specific fields (amplitude, from/to) shown conditionally by detected type.

# =============================================================================
# WHAT: One "target slot" for the PropertyJuiceEffectBase family.
#       Holds which node, which property, and the natural base value captured
#       at animation start. Subclasses extend with per-effect config.
# WHY:  Separates "what to affect" (this resource) from "how to affect it"
#       (the parent effect). Mirrors how recipe items are independent resources.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# DOES NOT: Drive the property itself — the parent effect calls apply().
# DOES NOT: Use the JuiceLedger — arbitrary properties are not registered there.
#            Uses get_indexed() for base capture, same pattern as ProgressProperty.
# DOES NOT: Support runtime NodePath resolution without a host node reference.
# =============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseProperty.svg")
class_name PropertyTarget
extends Resource


# =============================================================================
# CONFIGURATION
# =============================================================================

## Node to animate. Resolved relative to the host JuiceBase node at runtime.
## Leave empty (NodePath()) to target the juiced node itself.
var node_path: NodePath = NodePath():
	set(value):
		node_path = value
		_detect_type()
		notify_property_list_changed()

## Indexed property path on the target node. Supports Godot indexed syntax:
## "energy", "modulate:a", "material:shader_parameter/dissolve".
## Use the [Pick…] button to browse available properties, or type manually.
var property_path: String = "":
	set(value):
		property_path = value
		_detect_type()
		notify_property_list_changed()

# Serialized auto-detected type. Not shown in inspector — drives conditional
# display of amplitude/from-to fields in subclasses. TYPE_NIL = unknown.
var _detected_type: int = TYPE_NIL


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	props.append({"name": "node_path", "type": TYPE_NODE_PATH,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "property_path", "type": TYPE_STRING,
		"hint": PROPERTY_HINT_NONE, "usage": PROPERTY_USAGE_DEFAULT})

	# Show detected type as a read-only info row in the inspector.
	# This tells the user what type was resolved without exposing the raw int.
	if not property_path.is_empty():
		props.append({"name": "_type_display", "type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})

	# _detected_type is stored (serialized) but not shown directly.
	props.append({"name": "_detected_type", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_STORAGE})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"node_path":       node_path = value;       return true
		&"property_path":   property_path = value;   return true
		&"_detected_type":  _detected_type = value;  return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"node_path":      return node_path
		&"property_path":  return property_path
		&"_detected_type": return _detected_type
		&"_type_display":
			if _detected_type != TYPE_NIL:
				return "Detected: %s" % type_string(_detected_type)
			return "Detected: unknown (sub-property or shader param — type inferred at runtime)"
	return null


# =============================================================================
# INTERNAL STATE (runtime only — not serialized)
# =============================================================================

## Resolved target node. Set by capture_base(), cleared on stop.
var _resolved_node: Node = null
## Natural value of the property before this effect was applied.
var _base_value: Variant = null


# =============================================================================
# PUBLIC API
# =============================================================================

## Resolve the target node from host and capture its current property value
## as the natural base. Call this in _on_animate_start().
## host: the JuiceBase node (Juice2D, JuiceControl, etc.) running the effect.
func capture_base(host: Node) -> void:
	_resolved_node = _resolve_node(host)
	if not is_instance_valid(_resolved_node) or property_path.is_empty():
		return
	# get_indexed() handles nested paths: "modulate:a", "material:shader_parameter/x".
	# This matches the ProgressPropertyJuiceEffectBase capture pattern exactly.
	_base_value = _resolved_node.get_indexed(property_path)


## Write the captured natural base value back to the property.
## Call this in _restore_to_natural() and _temporarily_undo_visual().
func restore_natural() -> void:
	if not is_instance_valid(_resolved_node) or property_path.is_empty():
		return
	if _base_value == null:
		return
	_resolved_node.set_indexed(property_path, _base_value)


## True if the minimum required fields are filled.
func is_configured() -> bool:
	return not property_path.is_empty()


## Returns validation problems for this entry. Used by parent effect's warnings.
func get_target_warnings() -> Array[String]:
	var warnings: Array[String] = []
	if property_path.is_empty():
		warnings.append("Property path is not set.")
	elif _detected_type == TYPE_NIL:
		warnings.append(
			"Type of '%s' could not be auto-detected. " % property_path
			+ "Amplitude fields will not show correctly. "
			+ "Note: ':x', ':y', ':a' sub-properties are always float.")
	# Warn when targeting a shared shader material so the user knows
	# changes will affect every node using the same resource.
	if ":shader_parameter/" in property_path:
		var mat_prop: String = property_path.split(":")[0]
		warnings.append(
			"Shader parameter is on a shared '%s'. Changes affect ALL nodes " % mat_prop
			+ "using this material. Right-click the material in the Inspector "
			+ "→ Make Unique for per-instance animation.")
	return warnings


# =============================================================================
# TYPE DETECTION (editor-time only)
# =============================================================================

## Auto-detect the property type from the target node's get_property_list().
## Only runs in @tool context. Updates _detected_type and triggers inspector refresh.
func _detect_type() -> void:
	if not Engine.is_editor_hint():
		return
	if property_path.is_empty():
		_detected_type = TYPE_NIL
		return

	# Split indexed path: "modulate:a" → base="modulate", sub="a"
	var segments := property_path.split(":")
	var base_prop := segments[0]

	# Resolve the node from the current edited scene root.
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return
	var node := scene_root.get_node_or_null(node_path)
	if node == null:
		# NodePath not resolved yet. Keep existing _detected_type.
		return

	# Find the base property type in the node's property list.
	var base_type := TYPE_NIL
	for prop: Dictionary in node.get_property_list():
		if prop.get("name", "") == base_prop:
			base_type = prop.get("type", TYPE_NIL)
			break

	if base_type == TYPE_NIL:
		_detected_type = TYPE_NIL
		return

	# Refine for sub-properties and shader parameter paths.
	if segments.size() > 1:
		var sub := segments[1]

		# --- Shader parameter path: "material:shader_parameter/<name>" ---
		# base_prop is "material", "material_override", or "material_overlay".
		# We confirmed via live test that get_indexed chains correctly through
		# these properties into ShaderMaterial.get("shader_parameter/name").
		if sub.begins_with("shader_parameter/"):
			var param_name: String = sub.substr("shader_parameter/".length())
			var material = node.get(base_prop)
			if material is ShaderMaterial and material.shader != null:
				for u: Dictionary in material.shader.get_shader_uniform_list():
					if u.get("name", "") == param_name:
						_detected_type = u.get("type", TYPE_NIL)
						return
			# Shader or param not found yet — keep TYPE_NIL.
			_detected_type = TYPE_NIL
			return

		# --- Single component sub-properties: ":a", ":x", ":y", etc. ---
		# These are always float regardless of the parent vector/color type.
		var sub_lower := sub.to_lower()
		if sub_lower in ["x", "y", "z", "w", "r", "g", "b", "a"]:
			_detected_type = TYPE_FLOAT
		else:
			# Other complex nested path — unknown at editor time.
			_detected_type = TYPE_NIL
	else:
		_detected_type = base_type


# =============================================================================
# HELPERS
# =============================================================================

func _resolve_node(host: Node) -> Node:
	if node_path == NodePath():
		# Empty = target the juiced node itself.
		return host
	return host.get_node_or_null(node_path)


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	for w in get_target_warnings():
		out.append(w)
	return out
