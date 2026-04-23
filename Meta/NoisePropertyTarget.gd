## Per-property config for NoisePropertyJuiceEffectBase.
##
## Extends PropertyTarget with an amplitude field that is shown conditionally
## based on the auto-detected property type. Each entry in the effect's
## property_targets array is one of these.

# =============================================================================
# WHAT: One "noise target slot" — node path + property path + amplitude.
#       Subclasses PropertyTarget, which provides node/property resolution
#       and base value capture.
# WHY:  Separates per-property amplitude from shared noise settings (speed,
#       frequency, etc.) that live on NoisePropertyJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# =============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseProperty.svg")
class_name NoisePropertyTarget
extends PropertyTarget


# =============================================================================
# CONFIGURATION — amplitude shown per detected type
# =============================================================================

## Amplitude when property is TYPE_FLOAT (e.g., "energy", "modulate:a").
var amplitude_float: float = 5.0
## Amplitude when property is TYPE_VECTOR2 (e.g., "position", "scale").
var amplitude_vec2: Vector2 = Vector2(5.0, 5.0)
## Amplitude when property is TYPE_VECTOR3 (e.g., "rotation", "velocity").
var amplitude_vec3: Vector3 = Vector3(5.0, 5.0, 5.0)
## Amplitude (uniform across channels) when property is TYPE_COLOR.
var amplitude_color: float = 0.1


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _init() -> void:
	# Take full ownership of the property list so we control ordering:
	# node_path + property_path (from parent) appear FIRST, then amplitude.
	# Without this, Godot emits our props before the parent's — wrong order.
	_subclass_owns_target_layout = true


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

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

	# --- Amplitude (shown only when type is known — hidden until Pick is used) ---
	var t := _detected_type
	if t == TYPE_FLOAT:
		props.append({"name": "amplitude_float", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.001,100.0,0.001,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT})
	elif t == TYPE_VECTOR2:
		props.append({"name": "amplitude_vec2", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT})
	elif t == TYPE_VECTOR3:
		props.append({"name": "amplitude_vec3", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})
	elif t == TYPE_COLOR:
		props.append({"name": "amplitude_color", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.001,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT})
	# TYPE_NIL: no amplitude shown — pick a property first.

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"amplitude_float":  amplitude_float = value;  return true
		&"amplitude_vec2":   amplitude_vec2 = value;   return true
		&"amplitude_vec3":   amplitude_vec3 = value;   return true
		&"amplitude_color":  amplitude_color = value;  return true
	return super._set(property, value)


func _get(property: StringName) -> Variant:
	match property:
		&"amplitude_float":  return amplitude_float
		&"amplitude_vec2":   return amplitude_vec2
		&"amplitude_vec3":   return amplitude_vec3
		&"amplitude_color":  return amplitude_color
	return super._get(property)
