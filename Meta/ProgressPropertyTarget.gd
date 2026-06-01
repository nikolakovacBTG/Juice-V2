## Per-property rate configuration for the Progress (rate-accumulator) effect.
##
## Each ProgressPropertyTarget binds one named property on a target node to a
## typed rate (units/second). The effect base reads these rates to advance
## the accumulator each frame.
##
## Continuous types show a single rate field matching _detected_type.
## Discrete types (bool, string, etc.) show an informational note — rate
## accumulation is not meaningful for non-numeric properties.

# =============================================================================
# WHAT: Per-property rate resource for the Progress property effect.
#       Holds typed rate vars for all 11 continuous type groups.
#       Integer variants map to their float-counterpart rate var.
# WHY:  Migrates Progress from a single-path + manual-type-enum model to
#       the standard PropertyTarget array architecture. Each target is fully
#       self-describing — auto-detects its type and shows the correct rate field.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Hold accumulation state (that stays on the effect base).
#           Non-numeric types (bool, string, object, etc.) are filtered from
#           the property picker and show an informational note if assigned manually.
# =============================================================================

@tool
class_name ProgressPropertyTarget
extends PropertyTarget


# =============================================================================
# LIFECYCLE
# =============================================================================

func _init() -> void:
	_subclass_owns_target_layout = true


# =============================================================================
# CONFIGURATION — Rate vars (one per continuous type group)
# =============================================================================

## Accumulation speed in units/second for Float and Int properties.
var float_rate: float = 1.0

## Per-axis accumulation speed in units/second for Vector2 and Vector2i properties.
var vec2_rate: Vector2 = Vector2(1.0, 0.0)

## Per-axis accumulation speed in units/second for Vector3 and Vector3i properties.
var vec3_rate: Vector3 = Vector3(1.0, 0.0, 0.0)

## Per-channel additive rate in units/second for Color properties.
## Values are added to the base color each second. Keep small (0.0–1.0 range).
var color_rate: Color = Color(0.1, 0.0, 0.0, 0.0)

## Per-axis accumulation speed in units/second for Vector4 and Vector4i properties.
var vec4_rate: Vector4 = Vector4(1.0, 0.0, 0.0, 0.0)

## Euler degrees/second for Quaternion properties.
## Internally converted to radians before accumulation.
var quat_rate: Vector3 = Vector3(0.0, 0.0, 0.0)

## Per-component accumulation for Rect2 and Rect2i properties.
## position = offset rate, size = size rate.
var rect2_rate: Rect2 = Rect2(0.0, 0.0, 0.0, 0.0)

## Per-component accumulation for AABB properties.
## position = offset rate, size = size rate.
var aabb_rate: AABB = AABB(Vector3.ZERO, Vector3.ZERO)

## Per-component rate for Plane properties.
## normal = normal direction rate/sec, d = distance rate/sec.
var plane_rate: Plane = Plane(Vector3.ZERO, 0.0)

## Per-row rate for Basis properties (3×3 matrix).
## Each row (x, y, z) is a Vector3 rate/sec.
var basis_rate: Basis = Basis()

## Per-column rate for Projection properties (4×4 matrix).
## Each column is a Vector4 rate/sec.
var projection_rate: Projection = Projection()


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

## Emits Target (path fields), then the rate field matching _detected_type.
## Discrete types show an informational note. All rate vars are always
## serialised (PROPERTY_USAGE_STORAGE) even when hidden, preserving values
## across type changes.
func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# --- Target block ---
	props.append({"name": "Target", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "node_path", "type": TYPE_NODE_PATH,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "property_path", "type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT})
	if not property_path.is_empty():
		props.append({"name": "_type_display", "type": TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})
	props.append({"name": "_detected_type", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_STORAGE})

	# Map detected type to the active rate slot.
	var active: String = ""
	match _detected_type:
		TYPE_FLOAT, TYPE_INT:         active = "float"
		TYPE_VECTOR2, TYPE_VECTOR2I:  active = "vec2"
		TYPE_VECTOR3, TYPE_VECTOR3I:  active = "vec3"
		TYPE_COLOR:                   active = "color"
		TYPE_VECTOR4, TYPE_VECTOR4I:  active = "vec4"
		TYPE_QUATERNION:              active = "quat"
		TYPE_RECT2, TYPE_RECT2I:      active = "rect2"
		TYPE_AABB:                    active = "aabb"
		TYPE_PLANE:                   active = "plane"
		TYPE_BASIS:                   active = "basis"
		TYPE_PROJECTION:              active = "projection"

	# Non-numeric types that cannot be rate-accumulated.
	var is_non_numeric := _detected_type in [TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME,
			TYPE_NODE_PATH, TYPE_OBJECT]

	# --- Rate block ---
	if active != "":
		props.append({"name": "Rate", "type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})

	props.append({"name": "float_rate", "type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT if active == "float" else PROPERTY_USAGE_STORAGE})
	props.append({"name": "vec2_rate", "type": TYPE_VECTOR2,
		"usage": PROPERTY_USAGE_DEFAULT if active == "vec2" else PROPERTY_USAGE_STORAGE})
	props.append({"name": "vec3_rate", "type": TYPE_VECTOR3,
		"usage": PROPERTY_USAGE_DEFAULT if active == "vec3" else PROPERTY_USAGE_STORAGE})
	props.append({"name": "color_rate", "type": TYPE_COLOR,
		"usage": PROPERTY_USAGE_DEFAULT if active == "color" else PROPERTY_USAGE_STORAGE})
	props.append({"name": "vec4_rate", "type": TYPE_VECTOR4,
		"usage": PROPERTY_USAGE_DEFAULT if active == "vec4" else PROPERTY_USAGE_STORAGE})
	props.append({"name": "quat_rate", "type": TYPE_VECTOR3,
		"usage": PROPERTY_USAGE_DEFAULT if active == "quat" else PROPERTY_USAGE_STORAGE})
	props.append({"name": "rect2_rate", "type": TYPE_RECT2,
		"usage": PROPERTY_USAGE_DEFAULT if active == "rect2" else PROPERTY_USAGE_STORAGE})
	props.append({"name": "aabb_rate", "type": TYPE_AABB,
		"usage": PROPERTY_USAGE_DEFAULT if active == "aabb" else PROPERTY_USAGE_STORAGE})
	props.append({"name": "plane_rate", "type": TYPE_PLANE,
		"usage": PROPERTY_USAGE_DEFAULT if active == "plane" else PROPERTY_USAGE_STORAGE})
	props.append({"name": "basis_rate", "type": TYPE_BASIS,
		"usage": PROPERTY_USAGE_DEFAULT if active == "basis" else PROPERTY_USAGE_STORAGE})
	props.append({"name": "projection_rate", "type": TYPE_PROJECTION,
		"usage": PROPERTY_USAGE_DEFAULT if active == "projection" else PROPERTY_USAGE_STORAGE})

	# --- Discrete info note ---
	if is_non_numeric:
		props.append({"name": "_discrete_note", "type": TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})

	# --- Pick hint (only when path is set but type detection failed) ---
	if _detected_type == TYPE_NIL and not property_path.is_empty():
		props.append({"name": "_rate_hint", "type": TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"node_path":      node_path = value;      return true
		&"property_path":  property_path = value;  return true
		&"_detected_type": _detected_type = value; return true
		&"float_rate":     float_rate = value;     return true
		&"vec2_rate":      vec2_rate = value;      return true
		&"vec3_rate":      vec3_rate = value;      return true
		&"color_rate":     color_rate = value;     return true
		&"vec4_rate":      vec4_rate = value;      return true
		&"quat_rate":      quat_rate = value;      return true
		&"rect2_rate":     rect2_rate = value;     return true
		&"aabb_rate":      aabb_rate = value;      return true
		&"plane_rate":     plane_rate = value;     return true
		&"basis_rate":     basis_rate = value;     return true
		&"projection_rate": projection_rate = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"node_path":      return node_path
		&"property_path":  return property_path
		&"_detected_type": return _detected_type
		&"_type_display":  return _type_name_for(_detected_type)
		&"float_rate":     return float_rate
		&"vec2_rate":      return vec2_rate
		&"vec3_rate":      return vec3_rate
		&"color_rate":     return color_rate
		&"vec4_rate":      return vec4_rate
		&"quat_rate":      return quat_rate
		&"rect2_rate":     return rect2_rate
		&"aabb_rate":      return aabb_rate
		&"plane_rate":     return plane_rate
		&"basis_rate":     return basis_rate
		&"projection_rate": return projection_rate
		&"_discrete_note": return "Rate accumulation is not applicable to this property type."
		&"_rate_hint":     return "← Pick a property path first"
	return null
