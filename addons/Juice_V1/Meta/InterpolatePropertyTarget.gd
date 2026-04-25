## Per-property config for InterpolatePropertyJuiceEffectBase.
##
## Extends PropertyTarget with From/To values and capture modes.
## CaptureMode controls whether from/to is typed manually, snapshotted
## in the editor, or grabbed at runtime when the trigger fires.

# =============================================================================
# WHAT: One "interpolate target slot" — node+property+from+to+capture modes.
# WHY:  Separates per-property from/to config from shared effect settings.
#       Capture modes give designers full control without writing scripts.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# =============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseProperty.svg")
class_name InterpolatePropertyTarget
extends PropertyTarget


# =============================================================================
# ENUMS
# =============================================================================

enum CaptureMode {
	CUSTOM,     ## Value typed manually in the inspector.
	IN_EDITOR,  ## Snapshot grabbed via Capture button at edit time.
	ON_TRIGGER, ## Captured at runtime when animate_in() starts.
}


# =============================================================================
# CONFIGURATION
# =============================================================================

## How to determine the FROM value.
var capture_from: int = CaptureMode.ON_TRIGGER:
	set(v): capture_from = v; notify_property_list_changed()

# Manual FROM values — one per supported type (only relevant type shown).
var from_int:   int   = 0
var from_float: float = 0.0
var from_vec2:  Vector2 = Vector2.ZERO
var from_vec3:  Vector3 = Vector3.ZERO
var from_color: Color   = Color.BLACK

## Editor-time cached FROM value (set via Capture button).
var _from_editor_cached: Variant = null

## How to determine the TO value.
var capture_to: int = CaptureMode.CUSTOM:
	set(v): capture_to = v; notify_property_list_changed()

# Manual TO values.
var to_int:   int   = 1
var to_float: float = 1.0
var to_vec2:  Vector2 = Vector2.ONE
var to_vec3:  Vector3 = Vector3.ONE
var to_color: Color   = Color.WHITE

## Editor-time cached TO value (set via Capture button).
var _to_editor_cached: Variant = null


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _init() -> void:
	# Same rationale as NoisePropertyTarget._init():
	# Godot calls child _get_property_list() first, so without this flag
	# From/To fields would appear before node_path/property_path.
	_subclass_owns_target_layout = true

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	# NOTE: do NOT call super._get_property_list() — we own the layout
	# (see _subclass_owns_target_layout set in _init).

	# --- Paths (from PropertyTarget — emitted here because we own the layout) ---
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

	# ---- FROM ----
	props.append({"name": "From", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_SUBGROUP, "hint_string": ""})
	props.append({"name": "capture_from", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Custom,In Editor,On Trigger",
		"usage": PROPERTY_USAGE_DEFAULT})

	if capture_from == CaptureMode.CUSTOM:
		props.append_array(_value_props("from", "From Value"))
	elif capture_from == CaptureMode.IN_EDITOR:
		props.append({"name": "capture_from_now", "type": TYPE_BOOL,
			"hint": PROPERTY_HINT_TOOL_BUTTON,
			"hint_string": "_capture_from_in_editor_now:Capture From Value",
			"usage": PROPERTY_USAGE_EDITOR})
		if _from_editor_cached != null:
			props.append({"name": "_from_editor_cached_display", "type": TYPE_STRING,
				"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})

	# ---- TO ----
	props.append({"name": "To", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_SUBGROUP, "hint_string": ""})
	props.append({"name": "capture_to", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Custom,In Editor,On Trigger",
		"usage": PROPERTY_USAGE_DEFAULT})

	if capture_to == CaptureMode.CUSTOM:
		props.append_array(_value_props("to", "To Value"))
	elif capture_to == CaptureMode.IN_EDITOR:
		props.append({"name": "capture_to_now", "type": TYPE_BOOL,
			"hint": PROPERTY_HINT_TOOL_BUTTON,
			"hint_string": "_capture_to_in_editor_now:Capture To Value",
			"usage": PROPERTY_USAGE_EDITOR})
		if _to_editor_cached != null:
			props.append({"name": "_to_editor_cached_display", "type": TYPE_STRING,
				"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})

	# Serialize everything so type-switches don't lose values.
	props.append({"name": "from_int",   "type": TYPE_INT,     "usage": PROPERTY_USAGE_STORAGE})
	props.append({"name": "from_float", "type": TYPE_FLOAT,   "usage": PROPERTY_USAGE_STORAGE})
	props.append({"name": "from_vec2",  "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_STORAGE})
	props.append({"name": "from_vec3",  "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_STORAGE})
	props.append({"name": "from_color", "type": TYPE_COLOR,   "usage": PROPERTY_USAGE_STORAGE})
	props.append({"name": "to_int",     "type": TYPE_INT,     "usage": PROPERTY_USAGE_STORAGE})
	props.append({"name": "to_float",   "type": TYPE_FLOAT,   "usage": PROPERTY_USAGE_STORAGE})
	props.append({"name": "to_vec2",    "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_STORAGE})
	props.append({"name": "to_vec3",    "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_STORAGE})
	props.append({"name": "to_color",   "type": TYPE_COLOR,   "usage": PROPERTY_USAGE_STORAGE})
	props.append({"name": "_from_editor_cached", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_NIL_IS_VARIANT})
	props.append({"name": "_to_editor_cached",   "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_NIL_IS_VARIANT})

	return props


# Returns inspector value fields for the given prefix ("from"/"to") keyed by detected type.
# Returns [] when TYPE_NIL (no property picked yet) — hides all value fields
# until the user picks a property and the type is auto-detected.
func _value_props(prefix: String, label: String) -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	var t := _detected_type
	match t:
		TYPE_INT:
			props.append({"name": "%s_int" % prefix, "type": TYPE_INT,
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_FLOAT:
			props.append({"name": "%s_float" % prefix, "type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_VECTOR2:
			props.append({"name": "%s_vec2" % prefix, "type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_VECTOR3:
			props.append({"name": "%s_vec3" % prefix, "type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_COLOR:
			props.append({"name": "%s_color" % prefix, "type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT})
		_:  # TYPE_NIL — no property picked yet, hide all value fields.
			pass
	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"capture_from":  capture_from = value;  return true
		&"capture_to":    capture_to = value;    return true
		&"from_int":      from_int = value;      return true
		&"from_float":    from_float = value;    return true
		&"from_vec2":     from_vec2 = value;     return true
		&"from_vec3":     from_vec3 = value;     return true
		&"from_color":    from_color = value;    return true
		&"to_int":        to_int = value;        return true
		&"to_float":      to_float = value;      return true
		&"to_vec2":       to_vec2 = value;       return true
		&"to_vec3":       to_vec3 = value;       return true
		&"to_color":      to_color = value;      return true
		&"_from_editor_cached": _from_editor_cached = value; return true
		&"_to_editor_cached":   _to_editor_cached = value;   return true
		&"capture_from_now":
			if value: _capture_from_in_editor_now()
			return true
		&"capture_to_now":
			if value: _capture_to_in_editor_now()
			return true
	return super._set(property, value)


func _get(property: StringName) -> Variant:
	match property:
		&"capture_from":  return capture_from
		&"capture_to":    return capture_to
		&"from_int":      return from_int
		&"from_float":    return from_float
		&"from_vec2":     return from_vec2
		&"from_vec3":     return from_vec3
		&"from_color":    return from_color
		&"to_int":        return to_int
		&"to_float":      return to_float
		&"to_vec2":       return to_vec2
		&"to_vec3":       return to_vec3
		&"to_color":      return to_color
		&"_from_editor_cached": return _from_editor_cached
		&"_to_editor_cached":   return _to_editor_cached
		&"_from_editor_cached_display":
			return "Captured: %s" % str(_from_editor_cached)
		&"_to_editor_cached_display":
			return "Captured: %s" % str(_to_editor_cached)
	return super._get(property)


# =============================================================================
# INTERNAL STATE (runtime — not serialized)
# =============================================================================

var _runtime_from: Variant = null
var _runtime_to:   Variant = null


# =============================================================================
# PUBLIC API
# =============================================================================

## Returns the resolved FROM value, or null if not ready.
func get_from() -> Variant:
	match capture_from:
		CaptureMode.IN_EDITOR:  return _from_editor_cached
		CaptureMode.ON_TRIGGER: return _runtime_from
		_:  return _custom_value(false)


## Returns the resolved TO value, or null if not ready.
func get_to() -> Variant:
	match capture_to:
		CaptureMode.IN_EDITOR:  return _to_editor_cached
		CaptureMode.ON_TRIGGER: return _runtime_to
		_:  return _custom_value(true)


## Capture ON_TRIGGER values from the current property value.
## Called by InterpolatePropertyJuiceEffectBase._on_animate_start().
func capture_runtime_values() -> void:
	if not is_instance_valid(_resolved_node) or property_path.is_empty():
		return
	var current: Variant = _resolved_node.get_indexed(property_path)
	if capture_from == CaptureMode.ON_TRIGGER:
		_runtime_from = current
	if capture_to == CaptureMode.ON_TRIGGER:
		_runtime_to = current


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func get_target_warnings() -> Array[String]:
	var warnings := super.get_target_warnings()
	if capture_from == CaptureMode.IN_EDITOR and _from_editor_cached == null:
		warnings.append("FROM: In Editor mode but nothing captured yet — press Capture From Value.")
	if capture_to == CaptureMode.IN_EDITOR and _to_editor_cached == null:
		warnings.append("TO: In Editor mode but nothing captured yet — press Capture To Value.")
	if capture_from == CaptureMode.ON_TRIGGER and capture_to == CaptureMode.ON_TRIGGER:
		warnings.append("Both FROM and TO are On Trigger — both will be the same value. No animation will be visible.")
	return warnings


# =============================================================================
# HELPERS
# =============================================================================

func _custom_value(is_to: bool) -> Variant:
	match _detected_type:
		TYPE_INT:     return to_int   if is_to else from_int
		TYPE_FLOAT:   return to_float if is_to else from_float
		TYPE_VECTOR2: return to_vec2  if is_to else from_vec2
		TYPE_VECTOR3: return to_vec3  if is_to else from_vec3
		TYPE_COLOR:   return to_color if is_to else from_color
	return null  # TYPE_NIL — unknown, can't provide a safe default.


func _capture_from_in_editor_now() -> void:
	if not Engine.is_editor_hint():
		return
	var node := _resolve_editor_node()
	if node == null:
		JuiceLogger.warn(self, "PropertyTarget",
				"could not resolve node for FROM capture", true)
		return
	_from_editor_cached = node.get_indexed(property_path)
	notify_property_list_changed()


func _capture_to_in_editor_now() -> void:
	if not Engine.is_editor_hint():
		return
	var node := _resolve_editor_node()
	if node == null:
		JuiceLogger.warn(self, "PropertyTarget",
				"could not resolve node for TO capture", true)
		return
	_to_editor_cached = node.get_indexed(property_path)
	notify_property_list_changed()


# Resolves the target node at editor time for Capture button.
# Uses JuiceEditorContext first (robust), then falls back to selection walking (fragile).
func _resolve_editor_node() -> Node:
	# Robust Context Discovery
	var context_host: Node = JuiceEditorContext.get_host_node(self)
	if context_host != null:
		if node_path == NodePath():
			return context_host
		var resolved := context_host.get_node_or_null(node_path)
		if resolved != null:
			return resolved

	# Fragile Fallbacks (if Context is missing)
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return null
		
	# Try walking selection to find JuiceBase (copied from PropertyPickerPlugin)
	var selection := EditorInterface.get_selection()
	var juice_node: Node = null
	for selected in selection.get_selected_nodes():
		if selected is JuiceBase:
			juice_node = selected
			break
		for child in selected.get_children():
			if child is JuiceBase:
				juice_node = child
				break
		if juice_node != null:
			break
			
	if juice_node != null:
		if node_path == NodePath():
			return juice_node
		var resolved := juice_node.get_node_or_null(node_path)
		if resolved != null:
			return resolved

	if node_path == NodePath():
		return null
	return scene_root.get_node_or_null(node_path)
