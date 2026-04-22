## Per-property config for ShakePropertyJuiceEffectBase.
##
## Extends PropertyTarget with a strength field shown conditionally based on
## the auto-detected property type.

# =============================================================================
# WHAT: One "shake target slot" — node path + property path + strength.
# WHY:  Separates per-property strength from shared shake settings (frequency,
#       randomness) that live on ShakePropertyJuiceEffectBase.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# =============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseProperty.svg")
class_name ShakePropertyTarget
extends PropertyTarget


# =============================================================================
# CONFIGURATION — strength shown per detected type
# =============================================================================

## Shake strength when property is TYPE_FLOAT.
var strength_float: float = 5.0
## Shake strength when property is TYPE_VECTOR2.
var strength_vec2: Vector2 = Vector2(5.0, 5.0)
## Shake strength when property is TYPE_VECTOR3.
var strength_vec3: Vector3 = Vector3(5.0, 5.0, 5.0)
## Shake strength (uniform across channels) when property is TYPE_COLOR.
var strength_color: float = 0.1


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	props.append_array(super._get_property_list())

	var t := _detected_type
	var show_float := (t == TYPE_FLOAT or t == TYPE_NIL)
	var show_vec2 := (t == TYPE_VECTOR2 or t == TYPE_NIL)
	var show_vec3 := (t == TYPE_VECTOR3 or t == TYPE_NIL)
	var show_color := (t == TYPE_COLOR or t == TYPE_NIL)

	if show_float:
		props.append({"name": "strength_float", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.001,100.0,0.001,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT})
	if show_vec2:
		props.append({"name": "strength_vec2", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT})
	if show_vec3:
		props.append({"name": "strength_vec3", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})
	if show_color:
		props.append({"name": "strength_color", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.001,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT})

	# Always serialize all strength values.
	props.append({"name": "strength_float", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_STORAGE})
	props.append({"name": "strength_vec2", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_STORAGE})
	props.append({"name": "strength_vec3", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_STORAGE})
	props.append({"name": "strength_color", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_STORAGE})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"strength_float":  strength_float = value;  return true
		&"strength_vec2":   strength_vec2 = value;   return true
		&"strength_vec3":   strength_vec3 = value;   return true
		&"strength_color":  strength_color = value;  return true
	return super._set(property, value)


func _get(property: StringName) -> Variant:
	match property:
		&"strength_float":  return strength_float
		&"strength_vec2":   return strength_vec2
		&"strength_vec3":   return strength_vec3
		&"strength_color":  return strength_color
	return super._get(property)
