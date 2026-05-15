## Per-property configuration slot for [PropertyNoiseJuiceEffectBase].
##
## Extends [PropertyTarget] with a type-matched amplitude field.
## Add one [NoisePropertyTarget] per property to noise-animate.

# =============================================================================
# WHAT: One noise target slot — property path + amplitude.
#       Extends PropertyTarget, which provides property-path declaration and
#       base-value capture via JuiceLedger.ensure().
# WHY:  Separates per-property amplitude from the shared noise settings
#       (speed, seed, fractal, domain warp) that live on the base effect.
#       Inspector layout is conditional: only the amplitude field matching
#       _detected_type is visible, keeping the inspector uncluttered.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Compute noise values — that is PropertyNoiseJuiceEffectBase's job.
# =============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseProperty.svg")
class_name NoisePropertyTarget
extends PropertyTarget

# =============================================================================
# CONFIGURATION  (managed via _get_property_list so ordering is controlled)
# =============================================================================

# Amplitude for float properties (e.g. rotation, alpha).
var amplitude_float: float = 5.0

# Amplitude per axis for Vector2 properties (e.g. position, scale).
var amplitude_vec2: Vector2 = Vector2(5.0, 5.0)

# Amplitude per axis for Vector3 properties (e.g. position in 3D).
var amplitude_vec3: Vector3 = Vector3(5.0, 5.0, 5.0)

# Amplitude per channel for Color properties.
# Applied additively to RGBA; keep small (0.0–1.0) to avoid saturation.
var amplitude_color: float = 0.1

# =============================================================================
# INTERNAL STATE
# =============================================================================

# _detected_type is inherited from PropertyTarget — do not redeclare here.
# PropertyTarget._detect_type() auto-updates it; shadowing creates a second
# slot that never syncs with the parent's write, breaking type detection.

# =============================================================================
# LIFECYCLE
# =============================================================================

func _init() -> void:
	# Owns the full layout so PropertyTarget._get_property_list() returns []
	# and the path fields appear before the amplitude field in the inspector.
	_subclass_owns_target_layout = true

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

# Emits Target (path fields) then the single amplitude field matching
# _detected_type. Only numeric types support noise displacement.
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

	# --- Amplitude block ---
	# Each amplitude var is emitted exactly once. Usage is DEFAULT (visible)
	# for the type matching _detected_type, STORAGE-only (hidden but serialised)
	# for all other types. This avoids duplicate entries and ensures no value
	# is lost when the designer switches the target property type.
	props.append({"name": "Amplitude", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})

	# Determine which amplitude field is active for this detected type.
	var active: String = ""
	match _detected_type:
		TYPE_FLOAT, TYPE_INT:         active = "float"
		TYPE_VECTOR2, TYPE_VECTOR2I:  active = "vec2"
		TYPE_VECTOR3, TYPE_VECTOR3I:  active = "vec3"
		TYPE_COLOR:                   active = "color"

	props.append({"name": "amplitude_float", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1000.0,0.01,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT if active == "float" else PROPERTY_USAGE_STORAGE})
	props.append({"name": "amplitude_vec2", "type": TYPE_VECTOR2,
		"usage": PROPERTY_USAGE_DEFAULT if active == "vec2" else PROPERTY_USAGE_STORAGE})
	props.append({"name": "amplitude_vec3", "type": TYPE_VECTOR3,
		"usage": PROPERTY_USAGE_DEFAULT if active == "vec3" else PROPERTY_USAGE_STORAGE})
	props.append({"name": "amplitude_color", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.001,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT if active == "color" else PROPERTY_USAGE_STORAGE})

	# Hint row shown when no property has been picked yet.
	if _detected_type == TYPE_NIL:
		props.append({"name": "_amplitude_hint", "type": TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})
	elif active.is_empty():
		# _detected_type is set but not a continuous numeric type.
		props.append({"name": "_amplitude_unsupported", "type": TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"amplitude_float":  amplitude_float = value;  return true
		&"amplitude_vec2":   amplitude_vec2 = value;   return true
		&"amplitude_vec3":   amplitude_vec3 = value;   return true
		&"amplitude_color":  amplitude_color = value;  return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"amplitude_float":          return amplitude_float
		&"amplitude_vec2":           return amplitude_vec2
		&"amplitude_vec3":           return amplitude_vec3
		&"amplitude_color":          return amplitude_color
		&"_amplitude_hint":          return "← Pick a property path first"
		&"_amplitude_unsupported":   return "Type %d not supported for noise (use float / Vector2 / Vector3 / Color)" % _detected_type
	return null
