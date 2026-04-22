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

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# Node/property path fields from parent (node_path, property_path, _type_display).
	props.append_array(super._get_property_list())

	# Show only the amplitude field matching the detected type.
	# If TYPE_NIL (unknown), show all so the user can see something.
	var t := _detected_type
	var show_float := (t == TYPE_FLOAT or t == TYPE_NIL)
	var show_vec2 := (t == TYPE_VECTOR2 or t == TYPE_NIL)
	var show_vec3 := (t == TYPE_VECTOR3 or t == TYPE_NIL)
	var show_color := (t == TYPE_COLOR or t == TYPE_NIL)

	if show_float:
		props.append({"name": "amplitude_float", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.001,100.0,0.001,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT})
	if show_vec2:
		props.append({"name": "amplitude_vec2", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT})
	if show_vec3:
		props.append({"name": "amplitude_vec3", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})
	if show_color:
		props.append({"name": "amplitude_color", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.001,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT})

	# Always serialize all amplitude values so switching detected type
	# doesn't lose the previously configured value.
	props.append({"name": "amplitude_float", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_STORAGE})
	props.append({"name": "amplitude_vec2", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_STORAGE})
	props.append({"name": "amplitude_vec3", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_STORAGE})
	props.append({"name": "amplitude_color", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_STORAGE})

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
