## Binds one property slot to a specific named property on a target node.
##
## Add one PropertyTarget per property you want to animate.
## Multiple PropertyTargets on one effect animate multiple properties simultaneously.

# ============================================================================
# WHAT: Per-property slot resource. Pairs a node path + property path with the
#       Ledger registration call and base-value capture needed before any deltas land.
# WHY:  Each animated property needs an independent base-value snapshot so the
#       Ledger can stack concurrent effect deltas correctly. Centralising this
#       contract here prevents every concrete effect from re-implementing it.
#       node_path allows targeting a sibling or child instead of the juiced node.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Know how to compute from/to values or interpolation math — that is
#            the responsibility of concrete sub-resources (InterpolatePropertyTarget).
#            Does not hold animation state — stateless resource except for _resolved_node
#            and _base_value which are runtime-only caches.
# ============================================================================

@tool
class_name PropertyTarget
extends Resource


# =============================================================================
# ENUMS — shared by all PropertyTarget subclasses
# =============================================================================

## Reference source for From/To or State A/B values.
enum ReferenceSource {
	CUSTOM      = 0, ## Explicit user-supplied value in the inspector.
	SELF        = 1, ## This node's own captured snapshot (see CaptureAt).
	TARGET_NODE = 2, ## Another node's live value via NodePath.
}

## When to capture the Self snapshot (only applies when ReferenceSource == SELF).
enum CaptureAt {
	TRIGGER   = 0, ## At animation start (default).
	READY     = 1, ## At scene load (_ready).
	IN_EDITOR = 2, ## Baked WYSIWYG value stored in the scene file.
}


# =============================================================================
# CONFIGURATION
# =============================================================================

## Optional path to the node whose property to animate.
## Leave empty to target the node that owns the JuiceBase component.
var node_path: NodePath = NodePath():
	set(value):
		node_path = value
		notify_property_list_changed()

## The property path to animate (e.g. [code]"modulate"[/code],
## [code]"custom_minimum_size"[/code], [code]"visible"[/code]).
## Supports indexed syntax: [code]"modulate:a"[/code],
## [code]"material:shader_parameter/my_param"[/code].
var property_path: String = "":
	set(value):
		property_path = value
		resource_name = value if not value.is_empty() else ""
		_detect_type()
		notify_property_list_changed()

## Subclasses (NoisePropertyTarget, ShakePropertyTarget, InterpolatePropertyTarget)
## set this to true in _init() to take full ownership of the inspector layout,
## emitting node_path / property_path / _type_display themselves so they can
## place their own amplitude/strength fields after the path block.
var _subclass_owns_target_layout: bool = false

# Auto-detected property type. Drives conditional inspector fields in subclasses.
# TYPE_NIL when unknown (no path set, or type could not be resolved at editor time).
var _detected_type: int = TYPE_NIL


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	if _subclass_owns_target_layout:
		# Subclass emits all properties itself, including node_path / property_path.
		return []
	var props: Array[Dictionary] = []
	props.append({"name": "node_path", "type": TYPE_NODE_PATH,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "property_path", "type": TYPE_STRING,
		"hint": PROPERTY_HINT_NONE, "usage": PROPERTY_USAGE_DEFAULT})
	if not property_path.is_empty():
		props.append({"name": "_type_display", "type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})
	props.append({"name": "_detected_type", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_STORAGE})
	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"node_path":      node_path = value;      return true
		&"property_path":  property_path = value;  return true
		&"_detected_type": _detected_type = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"node_path":      return node_path
		&"property_path":  return property_path
		&"_detected_type": return _detected_type
		&"_type_display":  return _type_name_for(_detected_type)
	return null


# =============================================================================
# INTERNAL STATE (runtime only — not serialized)
# =============================================================================

## Resolved target node. Set by capture_base(), used by restore_natural().
var _resolved_node: Node = null
## Natural value of the property before any effect ran.
var _base_value: Variant = null


# =============================================================================
# PUBLIC API
# =============================================================================

## Resolve the target node and register [member property_path] in the Juice Ledger,
## recording its current value as the natural base before any deltas are applied.
## Must be called in [method JuiceEffectBase._on_animate_start] for each entry.
func capture_base(host: Node) -> void:
	_resolved_node = _resolve_node(host)
	if not is_instance_valid(_resolved_node) or property_path.is_empty():
		return
	# Cache locally so restore_natural() works even after ledger teardown.
	_base_value = _resolved_node.get_indexed(property_path)
	# Register path in the Ledger. Domain flush() then writes this property each frame.
	JuiceLedger.ensure(host, [property_path])


## Write the captured natural base value directly back to the node.
## Used for undo-visual (pre-scene-save) and on full stop when the ledger
## is about to be erased. Direct write bypasses the Ledger intentionally:
## at this point the orchestrator is tearing down and will erase the ledger anyway.
func restore_natural() -> void:
	if not is_instance_valid(_resolved_node) or property_path.is_empty():
		return
	if _base_value == null:
		return
	_resolved_node.set_indexed(property_path, _base_value)


## Returns true when the minimum required fields are filled.
func is_configured() -> bool:
	return not property_path.is_empty()


## Returns validation warnings for this entry.
## Used by the parent effect's [method _get_configuration_warnings].
func get_target_warnings() -> Array[String]:
	var warnings: Array[String] = []
	if property_path.is_empty():
		warnings.append("Property path is not set.")
	elif _detected_type == TYPE_NIL:
		warnings.append(
			"Type of '%s' could not be auto-detected. " % property_path
			+ "Amplitude fields will not show. "
			+ "Note: ':x', ':y', ':a' sub-properties are always float.")
	if ":shader_parameter/" in property_path:
		var mat_prop: String = property_path.split(":")[0]
		warnings.append(
			"Shader parameter is on a shared '%s'. " % mat_prop
			+ "Changes affect ALL nodes using this material. "
			+ "Right-click the material → Make Unique for per-instance animation.")
	return warnings


# =============================================================================
# TYPE DETECTION (editor-time only)
# =============================================================================

# Auto-detect property type from the target node's property list.
# Only runs under @tool. Updates _detected_type and triggers inspector refresh
# so subclass amplitude/strength fields appear immediately after a path is picked.
func _detect_type() -> void:
	if not Engine.is_editor_hint():
		return
	if property_path.is_empty():
		_detected_type = TYPE_NIL
		return

	# Split indexed path: "modulate:a" → base="modulate", sub="a"
	var segments := property_path.split(":")
	var base_prop := segments[0]

	var node := _resolve_node_for_editor()
	if node == null:
		return

	var base_type := TYPE_NIL
	for prop: Dictionary in node.get_property_list():
		if prop.get("name", "") == base_prop:
			base_type = prop.get("type", TYPE_NIL)
			break

	if base_type == TYPE_NIL:
		_detected_type = TYPE_NIL
		return

	if segments.size() > 1:
		var sub := segments[1]
		# Shader parameter path: "material:shader_parameter/<name>"
		if sub.begins_with("shader_parameter/"):
			var param_name: String = sub.substr("shader_parameter/".length())
			var material = node.get(base_prop)
			if material is ShaderMaterial and material.shader != null:
				for u: Dictionary in material.shader.get_shader_uniform_list():
					if u.get("name", "") == param_name:
						_detected_type = u.get("type", TYPE_NIL)
						return
			_detected_type = TYPE_NIL
			return
		# Single-component sub: ":a", ":x", ":y", etc. → always float.
		var sub_lower := sub.to_lower()
		if sub_lower in ["x", "y", "z", "w", "r", "g", "b", "a"]:
			_detected_type = TYPE_FLOAT
		else:
			_detected_type = TYPE_NIL
	else:
		_detected_type = base_type

	# Normalise integer types → float equivalents.
	# Effects use float math; set_indexed() casts back to the actual type at write time.
	match _detected_type:
		TYPE_INT:      _detected_type = TYPE_FLOAT
		TYPE_VECTOR2I: _detected_type = TYPE_VECTOR2
		TYPE_VECTOR3I: _detected_type = TYPE_VECTOR3

	notify_property_list_changed()


# =============================================================================
# HELPERS
# =============================================================================

# Resolve the live target node from the host JuiceBase node.
func _resolve_node(host: Node) -> Node:
	if node_path == NodePath():
		return host
	return host.get_node_or_null(node_path)


# Editor-time node resolution.
# JuiceEditorContext is the primary strategy — robust, works even when the
# inspected resource is nested deeply inside a recipe.
func _resolve_node_for_editor() -> Node:
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return null

	# Strategy 1: JuiceEditorContext robust discovery.
	var context_host: Node = JuiceEditorContext.get_host_node(self)
	if context_host != null:
		if node_path == NodePath():
			return context_host
		var resolved := context_host.get_node_or_null(node_path)
		if resolved != null:
			return resolved

	# Strategy 2: Editor selection fallback (less reliable — user may have
	# selected a different node since last click).
	var juice_node: Node = _find_juice_base_from_selection()
	if juice_node != null:
		if node_path == NodePath():
			return juice_node
		var resolved := juice_node.get_node_or_null(node_path)
		if resolved != null:
			return resolved

	# Strategy 3: Absolute NodePath resolved from scene root.
	if node_path != NodePath():
		var resolved := scene_root.get_node_or_null(node_path)
		if resolved != null:
			return resolved

	return scene_root


# Walk the editor selection to find a JuiceBase node.
func _find_juice_base_from_selection() -> Node:
	var selection := EditorInterface.get_selection()
	for selected in selection.get_selected_nodes():
		if selected is JuiceBase:
			return selected
		for child in selected.get_children():
			if child is JuiceBase:
				return child
	return null


# Human-readable type name for the read-only _type_display inspector field.
# Subclasses may override _get() to return a more specific label for TYPE_BOOL
# (e.g. "Bool (flip)" for Noise/Shake vs "Bool (hold)" for Interpolate).
func _type_name_for(t: int) -> String:
	match t:
		TYPE_FLOAT:      return "Float"
		TYPE_INT:        return "Int"
		TYPE_VECTOR2:    return "Vector2"
		TYPE_VECTOR2I:   return "Vector2i"
		TYPE_VECTOR3:    return "Vector3"
		TYPE_VECTOR3I:   return "Vector3i"
		TYPE_VECTOR4:    return "Vector4"
		TYPE_VECTOR4I:   return "Vector4i"
		TYPE_QUATERNION: return "Quaternion"
		TYPE_COLOR:      return "Color"
		TYPE_RECT2:      return "Rect2"
		TYPE_RECT2I:     return "Rect2i"
		TYPE_AABB:       return "AABB"
		TYPE_BOOL:       return "Bool"
		TYPE_STRING:     return "String"
		TYPE_STRING_NAME: return "StringName"
		TYPE_NODE_PATH:  return "NodePath"
		TYPE_OBJECT:     return "Object"
		TYPE_PLANE:      return "Plane"
		TYPE_BASIS:      return "Basis"
		TYPE_PROJECTION: return "Projection"
		_:               return "type %d" % t


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	for w in get_target_warnings():
		out.append(w)
	return out
