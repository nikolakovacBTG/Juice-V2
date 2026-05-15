## Drives arbitrary node properties from their natural base toward a configured
## target value, using the Juice animate-in / animate-out progress envelope (0–1).
##
## Add [PropertyTarget] entries to declare which properties to animate.
## Set the [code]to_*[/code] field matching your property type (float, Vector2,
## Vector3, or Color). Progress 0 = natural base; progress 1 = target value.

# =============================================================================
# WHAT: Progress-driven lerp for arbitrary named properties via JuiceLedger.
#       Each frame: desired = lerp(base, to_*, progress). PropertyJuiceEffectBase
#       converts that into the correct Ledger registration (delta or hold).
# WHY:  InterpolateProperty requires per-property FROM/TO resources. ProgressProperty
#       is intentionally simpler: FROM is always the captured base, TO is a single
#       typed value on the effect. This covers the common pattern of animating a
#       property (e.g. shader intensity, progress bar value, alpha) in sync with
#       the Juice tween envelope without needing a specialised target resource.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Support discrete property types (bool, String, etc.) — progress lerp
#           is only meaningful for continuous numeric types.
#           Does not capture FROM values from external nodes — use
#           InterpolatePropertyJuiceEffectBase for that.
#           Does not write to nodes directly — PropertyJuiceEffectBase._apply_effect()
#           routes all writes via JuiceLedger.
# =============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseProperty.svg")
class_name ProgressPropertyJuiceEffectBase
extends PropertyJuiceEffectBase


# =============================================================================
# CONFIGURATION — Target values (set the field matching your property type)
# =============================================================================

## Target value when property type is [float]. Progress 1.0 drives the property here.
var to_float: float = 1.0

## Target value when property type is [Vector2].
var to_vec2: Vector2 = Vector2.ONE

## Target value when property type is [Vector3].
var to_vec3: Vector3 = Vector3.ONE

## Target [Color] value. Progress 1.0 drives the property to this color.
## Uses the Ledger's multiplicative Color path — keep channels non-zero to avoid
## divide-by-zero when computing the factor from a dark base.
var to_color: Color = Color.WHITE


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# --- Progress group: to_* target values ---
	# Renamed from "Effect" to avoid colliding with JuiceEffectBase's own
	# "Effect" timing group (duration_in, start_delay, etc.).
	props.append({"name": "Progress", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "Target Values", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_SUBGROUP, "hint_string": ""})
	props.append({"name": "to_float", "type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "to_vec2", "type": TYPE_VECTOR2,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "to_vec3", "type": TYPE_VECTOR3,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "to_color", "type": TYPE_COLOR,
		"usage": PROPERTY_USAGE_DEFAULT})

	# property_targets is intentionally NOT emitted here.
	# PropertyJuiceEffectBase._get_property_list() already emits it with the
	# correct PROPERTY_HINT_TYPE_STRING hint when _subclass_owns_prop_layout
	# is false (the default). Emitting it here would create a duplicate row.

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"to_float":  to_float = value;  return true
		&"to_vec2":   to_vec2  = value;  return true
		&"to_vec3":   to_vec3  = value;  return true
		&"to_color":  to_color = value;  return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"to_float":  return to_float
		&"to_vec2":   return to_vec2
		&"to_vec3":   return to_vec3
		&"to_color":  return to_color
	return null


# =============================================================================
# LIFECYCLE
# =============================================================================

## Progress-to-value effects must keep ticking during the sustain phase so that
## the property holds at the target value rather than snapping back to base.
func _needs_sustain() -> bool:
	return true


# =============================================================================
# CORE LOGIC
# =============================================================================

## Returns the absolute desired property value at [param progress] by lerping
## from [param base_val] toward the matching [code]to_*[/code] field.
## [PropertyJuiceEffectBase._apply_effect] converts the result into the correct
## Ledger registration (multiplicative factor for Color, additive delta otherwise).
## Unsupported types return [param base_val] unchanged — no-op with zero delta.
func _compute_property_value(progress: float, _prop: String, base_val: Variant, _target: Node) -> Variant:
	match typeof(base_val):
		TYPE_FLOAT:
			return lerpf(base_val as float, to_float, progress)

		TYPE_VECTOR2:
			return (base_val as Vector2).lerp(to_vec2, progress)

		TYPE_VECTOR3:
			return (base_val as Vector3).lerp(to_vec3, progress)

		TYPE_COLOR:
			# Return absolute desired Color. PropertyJuiceEffectBase converts this
			# into a multiplicative factor (desired / base) for the Ledger's Color path.
			return (base_val as Color).lerp(to_color, progress)

	# Type not supported (bool, String, int, etc.) — register a zero delta so
	# the Ledger writes back the unmodified base value.
	return base_val
