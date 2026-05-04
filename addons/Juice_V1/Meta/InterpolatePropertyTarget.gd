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
## ON_TRIGGER snapshots the live property value the instant animate_in() fires.
## IN_EDITOR uses a value captured via the Capture button at design time.
## CUSTOM shows typed From/To fields below, matched to the detected property type.
var capture_from: int = CaptureMode.ON_TRIGGER:
	set(v): capture_from = v; notify_property_list_changed()

## Editor-time snapshot of the FROM value. Set by pressing Capture From Value.
## Stored as Variant so any property type can be cached without casting.
var _from_editor_cached: Variant = null

## How to determine the TO value. See capture_from for mode descriptions.
var capture_to: int = CaptureMode.CUSTOM:
	set(v): capture_to = v; notify_property_list_changed()

## Editor-time snapshot of the TO value. Set by pressing Capture To Value.
var _to_editor_cached: Variant = null

# --- Threshold (shared by all discrete / threshold-flip types) ---------------
## Progress at which discrete types flip from the FROM value to the TO value.
## At progress >= flip_threshold the TO value is used; below it, FROM is used.
## Applies to: bool, String, StringName, NodePath, Object, Plane, Basis, Projection.
## Range 0.0–1.0. Default 0.5 = halfway through the animation.
var flip_threshold: float = 0.5

# --- Manual FROM values -------------------------------------------------------
# One field per supported Godot type. Only the field matching the auto-detected
# property type is shown in the inspector (Step B wires the conditional display).
# All fields are always serialized so switching the target property never loses
# previously typed values.

## FROM value for bool properties (e.g. visible, disabled).
## Flips to to_bool at flip_threshold progress.
var from_bool: bool = false

## FROM value for int properties. Stored as true int — no float promotion.
## The lerp result is cast back to int on write so Godot's type stays intact.
var from_int: int = 0

## FROM value for float properties (e.g. modulate alpha, shader uniforms).
var from_float: float = 0.0

## FROM value for Vector2 properties (e.g. size, pivot_offset).
var from_vec2: Vector2 = Vector2.ZERO

## FROM value for Vector2i properties.
var from_vec2i: Vector2i = Vector2i.ZERO

## FROM value for Rect2 properties (e.g. region_rect on Sprite2D).
## Position and size are lerped independently.
var from_rect2: Rect2 = Rect2()

## FROM value for Rect2i properties.
var from_rect2i: Rect2i = Rect2i()

## FROM value for Vector3 properties.
var from_vec3: Vector3 = Vector3.ZERO

## FROM value for Vector3i properties.
var from_vec3i: Vector3i = Vector3i()

## FROM value for Vector4 properties (primarily shader vec4 uniforms).
## Four independent float channels with no clamping — unlike Color.
var from_vec4: Vector4 = Vector4()

## FROM value for Vector4i properties.
var from_vec4i: Vector4i = Vector4i()

## FROM value for Plane properties. Switches at flip_threshold (no lerp).
var from_plane: Plane = Plane()

## FROM value for Quaternion properties. Interpolated with slerp() for
## correct smooth rotation without gimbal lock.
var from_quat: Quaternion = Quaternion.IDENTITY

## FROM value for AABB properties (e.g. custom_aabb on GeometryInstance3D).
## Position and size extents are lerped independently.
var from_aabb: AABB = AABB()

## FROM value for Basis properties. Switches at flip_threshold (no lerp).
## Direct Basis lerp is ambiguous — use Quaternion for smooth rotation instead.
var from_basis: Basis = Basis.IDENTITY

## FROM value for Projection (4×4 matrix) properties. Switches at flip_threshold.
var from_projection: Projection = Projection.IDENTITY

## FROM value for Color properties (e.g. shader color uniforms, custom colors).
## Note: modulate and self_modulate are ledger-managed — use Appearance Effect.
var from_color: Color = Color.BLACK

## FROM value for String properties (e.g. text, animation names).
## Switches at flip_threshold (no lerp — strings are discrete values).
var from_string: String = ""

## FROM value for StringName properties.
## Switches at flip_threshold.
var from_stringname: StringName = &""

## FROM value for NodePath properties.
## Switches at flip_threshold — useful to redirect which node is targeted.
var from_nodepath: NodePath = NodePath()

## FROM value for Resource/Object properties (e.g. Texture2D, Material, Mesh).
## Switches at flip_threshold — enables texture swap, material swap, mesh swap effects.
var from_object: Resource = null

# --- Manual TO values ---------------------------------------------------------
# Defaults use typical "arrived at" values so a new entry is already non-trivial.

## TO value for bool properties.
var to_bool: bool = true

## TO value for int properties.
var to_int: int = 1

## TO value for float properties.
var to_float: float = 1.0

## TO value for Vector2 properties.
var to_vec2: Vector2 = Vector2.ONE

## TO value for Vector2i properties.
var to_vec2i: Vector2i = Vector2i.ONE

## TO value for Rect2 properties.
var to_rect2: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)

## TO value for Rect2i properties.
var to_rect2i: Rect2i = Rect2i(0, 0, 1, 1)

## TO value for Vector3 properties.
var to_vec3: Vector3 = Vector3.ONE

## TO value for Vector3i properties.
var to_vec3i: Vector3i = Vector3i(1, 1, 1)

## TO value for Vector4 properties.
var to_vec4: Vector4 = Vector4(1.0, 1.0, 1.0, 1.0)

## TO value for Vector4i properties.
var to_vec4i: Vector4i = Vector4i(1, 1, 1, 1)

## TO value for Plane properties. Switches at flip_threshold.
var to_plane: Plane = Plane(0.0, 1.0, 0.0, 0.0)

## TO value for Quaternion properties (the rotation state at progress = 1.0).
var to_quat: Quaternion = Quaternion.IDENTITY

## TO value for AABB properties.
var to_aabb: AABB = AABB(Vector3.ZERO, Vector3.ONE)

## TO value for Basis properties. Switches at flip_threshold.
var to_basis: Basis = Basis.IDENTITY

## TO value for Projection properties. Switches at flip_threshold.
var to_projection: Projection = Projection.IDENTITY

## TO value for Color properties.
var to_color: Color = Color.WHITE

## TO value for String properties. Switches at flip_threshold.
var to_string: String = ""

## TO value for StringName properties. Switches at flip_threshold.
var to_stringname: StringName = &""

## TO value for NodePath properties. Switches at flip_threshold.
var to_nodepath: NodePath = NodePath()

## TO value for Resource/Object properties. Switches at flip_threshold.
var to_object: Resource = null



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

	# ---- Serialized storage — all vars, regardless of which type is active. ----
	# Storing every field means switching the target property to a different type
	# never silently discards previously typed From/To values.
	props.append({&"name": "flip_threshold", "type": TYPE_FLOAT,   "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_bool",      "type": TYPE_BOOL,    "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_bool",        "type": TYPE_BOOL,    "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_int",       "type": TYPE_INT,     "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_int",         "type": TYPE_INT,     "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_float",     "type": TYPE_FLOAT,   "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_float",       "type": TYPE_FLOAT,   "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_vec2",      "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_vec2",        "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_vec2i",     "type": TYPE_VECTOR2I,"usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_vec2i",       "type": TYPE_VECTOR2I,"usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_rect2",     "type": TYPE_RECT2,   "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_rect2",       "type": TYPE_RECT2,   "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_rect2i",    "type": TYPE_RECT2I,  "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_rect2i",      "type": TYPE_RECT2I,  "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_vec3",      "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_vec3",        "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_vec3i",     "type": TYPE_VECTOR3I,"usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_vec3i",       "type": TYPE_VECTOR3I,"usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_vec4",      "type": TYPE_VECTOR4, "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_vec4",        "type": TYPE_VECTOR4, "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_vec4i",     "type": TYPE_VECTOR4I,"usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_vec4i",       "type": TYPE_VECTOR4I,"usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_plane",     "type": TYPE_PLANE,   "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_plane",       "type": TYPE_PLANE,   "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_quat",      "type": TYPE_QUATERNION, "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_quat",        "type": TYPE_QUATERNION, "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_aabb",      "type": TYPE_AABB,    "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_aabb",        "type": TYPE_AABB,    "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_basis",     "type": TYPE_BASIS,   "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_basis",       "type": TYPE_BASIS,   "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_projection","type": TYPE_PROJECTION,"usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_projection",  "type": TYPE_PROJECTION,"usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_color",     "type": TYPE_COLOR,   "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_color",       "type": TYPE_COLOR,   "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_string",    "type": TYPE_STRING,  "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_string",      "type": TYPE_STRING,  "usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_stringname","type": TYPE_STRING_NAME,"usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_stringname",  "type": TYPE_STRING_NAME,"usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_nodepath",  "type": TYPE_NODE_PATH,"usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "to_nodepath",    "type": TYPE_NODE_PATH,"usage": PROPERTY_USAGE_STORAGE})
	props.append({&"name": "from_object",    "type": TYPE_OBJECT,  "usage": PROPERTY_USAGE_STORAGE,
		"hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string": "Resource"})
	props.append({&"name": "to_object",      "type": TYPE_OBJECT,  "usage": PROPERTY_USAGE_STORAGE,
		"hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string": "Resource"})
	props.append({&"name": "_from_editor_cached", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_NIL_IS_VARIANT})
	props.append({&"name": "_to_editor_cached",   "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_NIL_IS_VARIANT})

	return props


# Builds the inspector-visible From Value / To Value fields for the given prefix.
# Only the field matching _detected_type is shown — all others are storage-only.
# Discrete types (bool, string, object, etc.) additionally show flip_threshold
# once so the designer can see and adjust the switch point without scrolling.
# Returns [] when _detected_type is TYPE_NIL (no property picked yet).
func _value_props(prefix: String, _label: String) -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	var t := _detected_type

	# Continuous types — lerp/slerp between From and To.
	match t:
		TYPE_INT:
			props.append({&"name": "%s_int" % prefix,  "type": TYPE_INT,
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_FLOAT:
			props.append({&"name": "%s_float" % prefix, "type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_VECTOR2:
			props.append({&"name": "%s_vec2" % prefix,  "type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_VECTOR2I:
			props.append({&"name": "%s_vec2i" % prefix, "type": TYPE_VECTOR2I,
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_RECT2:
			props.append({&"name": "%s_rect2" % prefix, "type": TYPE_RECT2,
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_RECT2I:
			props.append({&"name": "%s_rect2i" % prefix,"type": TYPE_RECT2I,
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_VECTOR3:
			props.append({&"name": "%s_vec3" % prefix,  "type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_VECTOR3I:
			props.append({&"name": "%s_vec3i" % prefix, "type": TYPE_VECTOR3I,
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_VECTOR4:
			props.append({&"name": "%s_vec4" % prefix,  "type": TYPE_VECTOR4,
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_VECTOR4I:
			props.append({&"name": "%s_vec4i" % prefix, "type": TYPE_VECTOR4I,
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_QUATERNION:
			props.append({&"name": "%s_quat" % prefix,  "type": TYPE_QUATERNION,
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_AABB:
			props.append({&"name": "%s_aabb" % prefix,  "type": TYPE_AABB,
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_COLOR:
			props.append({&"name": "%s_color" % prefix, "type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT})

		# Discrete / threshold-flip types — value switches at flip_threshold.
		# flip_threshold is appended after the value field so it sits directly
		# below its From or To entry (shown once per subgroup, not duplicated).
		TYPE_BOOL:
			props.append({&"name": "%s_bool" % prefix, "type": TYPE_BOOL,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({&"name": "flip_threshold", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_STRING:
			props.append({&"name": "%s_string" % prefix, "type": TYPE_STRING,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({&"name": "flip_threshold", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_STRING_NAME:
			props.append({&"name": "%s_stringname" % prefix, "type": TYPE_STRING_NAME,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({&"name": "flip_threshold", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_NODE_PATH:
			props.append({&"name": "%s_nodepath" % prefix, "type": TYPE_NODE_PATH,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({&"name": "flip_threshold", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_OBJECT:
			props.append({&"name": "%s_object" % prefix, "type": TYPE_OBJECT,
				"hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string": "Resource",
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({&"name": "flip_threshold", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_PLANE:
			props.append({&"name": "%s_plane" % prefix, "type": TYPE_PLANE,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({&"name": "flip_threshold", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_BASIS:
			props.append({&"name": "%s_basis" % prefix, "type": TYPE_BASIS,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({&"name": "flip_threshold", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT})
		TYPE_PROJECTION:
			props.append({&"name": "%s_projection" % prefix, "type": TYPE_PROJECTION,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({&"name": "flip_threshold", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT})

		_:
			# TYPE_NIL — no property picked yet. Return empty so no value fields
			# are shown until the user opens the picker and selects a property.
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
