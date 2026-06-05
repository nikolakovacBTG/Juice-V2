## Per-property configuration slot for [PropertyNoiseJuiceEffectBase].
##
## Extends [PropertyTarget] with a type-matched amplitude field.
## Add one [NoisePropertyTarget] per property to noise-animate.

# =============================================================================
# WHAT: One noise target slot — property path + type-matched amplitude.
#       Extends PropertyTarget for property-path declaration and base-value
#       capture. Inspector layout is conditional: only the amplitude field
#       matching _detected_type is visible, keeping the inspector clean.
# WHY:  Per-property amplitude is necessary because different animated
#       properties require different magnitudes (e.g. pixels vs. degrees).
#       Storing amplitude here, not on the effect, allows each target in the
#       array to noise-animate with an independent magnitude.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Compute noise values — that is PropertyNoiseJuiceEffectBase's job.
# =============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseProperty.svg")
class_name NoisePropertyTarget
extends PropertyTarget


# =============================================================================
# CONFIGURATION  (managed via _get_property_list — ordering is explicit)
# =============================================================================

## Amplitude for float and int properties (e.g. rotation, alpha).
var amplitude_float: float = 5.0

## Amplitude per axis for Vector2 / Vector2i properties (e.g. position).
var amplitude_vec2: Vector2 = Vector2(5.0, 5.0)

## Amplitude per axis for Vector3 / Vector3i properties (e.g. 3D position).
var amplitude_vec3: Vector3 = Vector3(5.0, 5.0, 5.0)

## Amplitude (uniform RGBA) for Color properties. Keep small (0–1) to avoid saturation.
var amplitude_color: float = 0.1

## Amplitude per component for Vector4 / Vector4i properties.
var amplitude_vec4: Vector4 = Vector4(5.0, 5.0, 5.0, 5.0)

## Amplitude as euler angles (degrees per axis) for Quaternion properties.
## Stored as Vector3 — a raw quaternion offset has no intuitive designer meaning;
## euler axes give direct per-axis rotation noise control. Converted at apply time.
var amplitude_quat: Vector3 = Vector3(5.0, 5.0, 5.0)

## Amplitude per component for Rect2 / Rect2i properties.
## Maps to (position.x, position.y, size.x, size.y).
var amplitude_rect2: Rect2 = Rect2(5.0, 5.0, 5.0, 5.0)

## Amplitude per component group for AABB properties.
## AABB(origin_amplitude, size_amplitude) — applied independently to origin and size.
var amplitude_aabb: AABB = AABB(Vector3(5.0, 5.0, 5.0), Vector3(5.0, 5.0, 5.0))

## Threshold for bool properties. Property is written as (noise_val > flip_threshold)
## each frame — it toggles on every crossing. Range matches FastNoiseLite [-1, 1].
## Default 0.0 = midpoint, giving roughly 50/50 on/off distribution over the noise range.
var flip_threshold: float = 0.0

# --- Reference model for discrete types (State A / State B) ---
## How to determine State A: Custom (typed field), Self (capture from node), or Target Node (live read).
var a_reference: int = ReferenceSource.CUSTOM:
	set(value):
		a_reference = value
		notify_property_list_changed()

## When Self reference is used for State A: capture at Trigger, Ready, or In Editor.
var a_capture_at: int = CaptureAt.TRIGGER:
	set(value):
		a_capture_at = value
		if value != CaptureAt.IN_EDITOR:
			_editor_cache_a = null
		notify_property_list_changed()

## Path to the node whose property value is read live as State A (Target Node mode).
var a_target_node: NodePath = NodePath()

## How to determine State B: Custom (typed field), Self (capture from node), or Target Node (live read).
var b_reference: int = ReferenceSource.CUSTOM:
	set(value):
		b_reference = value
		notify_property_list_changed()

## When Self reference is used for State B: capture at Trigger, Ready, or In Editor.
var b_capture_at: int = CaptureAt.TRIGGER:
	set(value):
		b_capture_at = value
		if value != CaptureAt.IN_EDITOR:
			_editor_cache_b = null
		notify_property_list_changed()

## Path to the node whose property value is read live as State B (Target Node mode).
var b_target_node: NodePath = NodePath()

# --- Discrete typed backing vars (State A / State B) ---
var value_a_bool: bool           = false
var value_a_string: String       = ""
var value_a_stringname: StringName = &""
var value_a_nodepath: NodePath   = NodePath()
var value_a_object: Resource     = null
var value_a_plane: Plane         = Plane()
var value_a_basis: Basis         = Basis.IDENTITY
var value_a_projection: Projection = Projection.IDENTITY

var value_b_bool: bool           = true
var value_b_string: String       = ""
var value_b_stringname: StringName = &""
var value_b_nodepath: NodePath   = NodePath()
var value_b_object: Resource     = null
var value_b_plane: Plane         = Plane()
var value_b_basis: Basis         = Basis.IDENTITY
var value_b_projection: Projection = Projection.IDENTITY


# =============================================================================
# INTERNAL STATE
# =============================================================================

# _detected_type is inherited from PropertyTarget — do not redeclare here.

# --- Runtime caches ---
var _runtime_a: Variant = null
var _runtime_b: Variant = null
var _ready_a: Variant = null
var _ready_b: Variant = null
var _editor_cache_a: Variant = null
var _editor_cache_b: Variant = null
var _a_target_resolved: Node = null
var _b_target_resolved: Node = null


# =============================================================================
# LIFECYCLE
# =============================================================================

func _init() -> void:
	# Takes ownership of the full inspector layout so PropertyTarget's
	# _get_property_list() returns [] and path fields appear before amplitude.
	_subclass_owns_target_layout = true


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

## Emits Target (path fields) then the amplitude field matching _detected_type.
## All amplitude vars are always serialised (PROPERTY_USAGE_STORAGE) even when
## hidden, preserving values if the designer changes the target property type.
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

	# Map detected type to the active amplitude slot.
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
		TYPE_BOOL:                    active = "bool"

	var is_continuous := active != "" and active != "bool"
	var is_discrete := _detected_type in [TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME,
			TYPE_NODE_PATH, TYPE_OBJECT, TYPE_PLANE, TYPE_BASIS, TYPE_PROJECTION]

	# --- Amplitude block (continuous types only) ---
	if is_continuous:
		props.append({"name": "Amplitude", "type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})

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
	props.append({"name": "amplitude_vec4", "type": TYPE_VECTOR4,
		"usage": PROPERTY_USAGE_DEFAULT if active == "vec4" else PROPERTY_USAGE_STORAGE})
	props.append({"name": "amplitude_quat", "type": TYPE_VECTOR3,
		"usage": PROPERTY_USAGE_DEFAULT if active == "quat" else PROPERTY_USAGE_STORAGE})
	props.append({"name": "amplitude_rect2", "type": TYPE_RECT2,
		"usage": PROPERTY_USAGE_DEFAULT if active == "rect2" else PROPERTY_USAGE_STORAGE})
	props.append({"name": "amplitude_aabb", "type": TYPE_AABB,
		"usage": PROPERTY_USAGE_DEFAULT if active == "aabb" else PROPERTY_USAGE_STORAGE})

	# --- State A / State B (discrete types only) ---
	if is_discrete:
		_emit_state_group(props, false)  # State A
		_emit_state_group(props, true)   # State B

	# --- Flip block (all discrete types) ---
	if is_discrete:
		props.append({"name": "Flip", "type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
		props.append({"name": "flip_threshold", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "-1.0,1.0,0.001",
			"usage": PROPERTY_USAGE_DEFAULT})
	else:
		props.append({"name": "flip_threshold", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_STORAGE})

	# --- Discrete backing vars (always serialised, hidden when not shown above) ---
	_emit_discrete_storage(props, is_discrete)
	# --- Reference model vars (always serialised) ---
	_emit_reference_storage(props, is_discrete)
	# --- Editor cache (always serialised) ---
	props.append({"name": "_editor_cache_a", "type": TYPE_NIL, "usage": PROPERTY_USAGE_STORAGE})
	props.append({"name": "_editor_cache_b", "type": TYPE_NIL, "usage": PROPERTY_USAGE_STORAGE})

	# --- Pick hint (only when path is set but type detection failed) ---
	if _detected_type == TYPE_NIL and not property_path.is_empty():
		props.append({"name": "_amplitude_hint", "type": TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		# --- Amplitude ---
		&"amplitude_float":  amplitude_float = value;  return true
		&"amplitude_vec2":   amplitude_vec2  = value;  return true
		&"amplitude_vec3":   amplitude_vec3  = value;  return true
		&"amplitude_color":  amplitude_color = value;  return true
		&"amplitude_vec4":   amplitude_vec4  = value;  return true
		&"amplitude_quat":   amplitude_quat  = value;  return true
		&"amplitude_rect2":  amplitude_rect2 = value;  return true
		&"amplitude_aabb":   amplitude_aabb  = value;  return true
		&"flip_threshold":   flip_threshold  = value;  return true
		# --- Reference model ---
		&"a_reference":      a_reference = value;      return true
		&"a_capture_at":     a_capture_at = value;     return true
		&"a_target_node":    a_target_node = value;    return true
		&"b_reference":      b_reference = value;      return true
		&"b_capture_at":     b_capture_at = value;     return true
		&"b_target_node":    b_target_node = value;    return true
		# --- Discrete backing vars ---
		&"value_a_bool":       value_a_bool = value;       return true
		&"value_a_string":     value_a_string = value;     return true
		&"value_a_stringname": value_a_stringname = value; return true
		&"value_a_nodepath":   value_a_nodepath = value;   return true
		&"value_a_object":     value_a_object = value;     return true
		&"value_a_plane":      value_a_plane = value;      return true
		&"value_a_basis":      value_a_basis = value;      return true
		&"value_a_projection": value_a_projection = value; return true
		&"value_b_bool":       value_b_bool = value;       return true
		&"value_b_string":     value_b_string = value;     return true
		&"value_b_stringname": value_b_stringname = value; return true
		&"value_b_nodepath":   value_b_nodepath = value;   return true
		&"value_b_object":     value_b_object = value;     return true
		&"value_b_plane":      value_b_plane = value;      return true
		&"value_b_basis":      value_b_basis = value;      return true
		&"value_b_projection": value_b_projection = value; return true
		# --- Editor cache ---
		&"_editor_cache_a":  _editor_cache_a = value;  return true
		&"_editor_cache_b":  _editor_cache_b = value;  return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		# --- Amplitude ---
		&"amplitude_float":  return amplitude_float
		&"amplitude_vec2":   return amplitude_vec2
		&"amplitude_vec3":   return amplitude_vec3
		&"amplitude_color":  return amplitude_color
		&"amplitude_vec4":   return amplitude_vec4
		&"amplitude_quat":   return amplitude_quat
		&"amplitude_rect2":  return amplitude_rect2
		&"amplitude_aabb":   return amplitude_aabb
		&"flip_threshold":   return flip_threshold
		# --- Reference model ---
		&"a_reference":      return a_reference
		&"a_capture_at":     return a_capture_at
		&"a_target_node":    return a_target_node
		&"b_reference":      return b_reference
		&"b_capture_at":     return b_capture_at
		&"b_target_node":    return b_target_node
		# --- Discrete backing vars ---
		&"value_a_bool":       return value_a_bool
		&"value_a_string":     return value_a_string
		&"value_a_stringname": return value_a_stringname
		&"value_a_nodepath":   return value_a_nodepath
		&"value_a_object":     return value_a_object
		&"value_a_plane":      return value_a_plane
		&"value_a_basis":      return value_a_basis
		&"value_a_projection": return value_a_projection
		&"value_b_bool":       return value_b_bool
		&"value_b_string":     return value_b_string
		&"value_b_stringname": return value_b_stringname
		&"value_b_nodepath":   return value_b_nodepath
		&"value_b_object":     return value_b_object
		&"value_b_plane":      return value_b_plane
		&"value_b_basis":      return value_b_basis
		&"value_b_projection": return value_b_projection
		# --- Editor cache ---
		&"_editor_cache_a":  return _editor_cache_a
		&"_editor_cache_b":  return _editor_cache_b
		# --- Display ---
		&"_type_display":
			match _detected_type:
				TYPE_BOOL:        return "Bool (flip)"
				TYPE_STRING:      return "String (flip)"
				TYPE_STRING_NAME: return "StringName (flip)"
				TYPE_NODE_PATH:   return "NodePath (flip)"
				TYPE_OBJECT:      return "Object (flip)"
				TYPE_PLANE:       return "Plane (flip)"
				TYPE_BASIS:       return "Basis (flip)"
				TYPE_PROJECTION:  return "Projection (flip)"
			return null
		&"_amplitude_hint":  return "← Pick a property path first"
	return null


# =============================================================================
# HELPERS
# =============================================================================

# Emits one State A or State B group with reference model conditional sub-fields.
func _emit_state_group(props: Array[Dictionary], is_b: bool) -> void:
	var label := "State B" if is_b else "State A"
	var ref_var := "b_reference" if is_b else "a_reference"
	var cap_var := "a_capture_at" if not is_b else "b_capture_at"
	var node_var := "b_target_node" if is_b else "a_target_node"
	var ref_val: int = b_reference if is_b else a_reference

	props.append({"name": label, "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": ref_var, "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Custom,Self,Target Node",
		"usage": PROPERTY_USAGE_DEFAULT})

	match ref_val:
		ReferenceSource.CUSTOM:
			_emit_discrete_value_field(props, is_b)
		ReferenceSource.SELF:
			props.append({"name": cap_var, "type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM, "hint_string": "Trigger,Ready,In Editor",
				"usage": PROPERTY_USAGE_DEFAULT})
		ReferenceSource.TARGET_NODE:
			props.append({"name": node_var, "type": TYPE_NODE_PATH,
				"usage": PROPERTY_USAGE_DEFAULT})


# Appends the single typed value field for State A or B matching _detected_type.
func _emit_discrete_value_field(props: Array[Dictionary], is_b: bool) -> void:
	var prefix := "value_b_" if is_b else "value_a_"
	match _detected_type:
		TYPE_BOOL:        props.append({"name": prefix + "bool",        "type": TYPE_BOOL,        "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_STRING:      props.append({"name": prefix + "string",      "type": TYPE_STRING,      "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_STRING_NAME: props.append({"name": prefix + "stringname",  "type": TYPE_STRING_NAME, "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_NODE_PATH:   props.append({"name": prefix + "nodepath",    "type": TYPE_NODE_PATH,   "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_OBJECT:      props.append({"name": prefix + "object",      "type": TYPE_OBJECT,      "hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string": "Resource", "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_PLANE:       props.append({"name": prefix + "plane",       "type": TYPE_PLANE,       "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_BASIS:       props.append({"name": prefix + "basis",       "type": TYPE_BASIS,       "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_PROJECTION:  props.append({"name": prefix + "projection",  "type": TYPE_PROJECTION,  "usage": PROPERTY_USAGE_DEFAULT})


# Serialises all discrete backing vars that are NOT currently shown via _emit_discrete_value_field.
func _emit_discrete_storage(props: Array[Dictionary], is_discrete: bool) -> void:
	var all_names := ["value_a_bool", "value_a_string", "value_a_stringname", "value_a_nodepath",
		"value_a_object", "value_a_plane", "value_a_basis", "value_a_projection",
		"value_b_bool", "value_b_string", "value_b_stringname", "value_b_nodepath",
		"value_b_object", "value_b_plane", "value_b_basis", "value_b_projection"]
	# When discrete + CUSTOM, _emit_discrete_value_field already emitted the active pair.
	# All others are storage-only.
	for n in all_names:
		if not _is_var_shown_in_inspector(n, is_discrete):
			props.append({"name": n, "type": _type_for_var(n), "usage": PROPERTY_USAGE_STORAGE})


# Serialises reference model vars that are NOT shown in the State A/B groups.
func _emit_reference_storage(props: Array[Dictionary], is_discrete: bool) -> void:
	var ref_vars := ["a_reference", "a_capture_at", "a_target_node",
		"b_reference", "b_capture_at", "b_target_node"]
	for n in ref_vars:
		if not is_discrete:
			var t := TYPE_INT if "reference" in n or "capture" in n else TYPE_NODE_PATH
			props.append({"name": n, "type": t, "usage": PROPERTY_USAGE_STORAGE})


# Whether a discrete backing var is currently shown via _emit_discrete_value_field.
func _is_var_shown_in_inspector(var_name: String, is_discrete: bool) -> bool:
	if not is_discrete:
		return false
	# Determine which prefix + suffix is the active one
	var is_b := var_name.begins_with("value_b_")
	var ref_val: int = b_reference if is_b else a_reference
	if ref_val != ReferenceSource.CUSTOM:
		return false
	var suffix := var_name.substr(8)  # after "value_a_" or "value_b_"
	match _detected_type:
		TYPE_BOOL:        return suffix == "bool"
		TYPE_STRING:      return suffix == "string"
		TYPE_STRING_NAME: return suffix == "stringname"
		TYPE_NODE_PATH:   return suffix == "nodepath"
		TYPE_OBJECT:      return suffix == "object"
		TYPE_PLANE:       return suffix == "plane"
		TYPE_BASIS:       return suffix == "basis"
		TYPE_PROJECTION:  return suffix == "projection"
	return false


# Returns the Godot TYPE_* constant for a backing var name.
func _type_for_var(var_name: String) -> int:
	var suffix := var_name.rsplit("_", true, 1)[1]
	match suffix:
		"bool":        return TYPE_BOOL
		"string":      return TYPE_STRING
		"stringname":  return TYPE_STRING_NAME
		"nodepath":    return TYPE_NODE_PATH
		"object":      return TYPE_OBJECT
		"plane":       return TYPE_PLANE
		"basis":       return TYPE_BASIS
		"projection":  return TYPE_PROJECTION
	return TYPE_NIL


# Returns the typed CUSTOM value for State A (is_b=false) or State B (is_b=true).
func _custom_value_ab(is_b: bool) -> Variant:
	match _detected_type:
		TYPE_BOOL:        return value_b_bool if is_b else value_a_bool
		TYPE_STRING:      return value_b_string if is_b else value_a_string
		TYPE_STRING_NAME: return value_b_stringname if is_b else value_a_stringname
		TYPE_NODE_PATH:   return value_b_nodepath if is_b else value_a_nodepath
		TYPE_OBJECT:      return value_b_object if is_b else value_a_object
		TYPE_PLANE:       return value_b_plane if is_b else value_a_plane
		TYPE_BASIS:       return value_b_basis if is_b else value_a_basis
		TYPE_PROJECTION:  return value_b_projection if is_b else value_a_projection
	return null


# =============================================================================
# RESOLVE METHODS
# =============================================================================

## Returns the resolved State A value based on the reference mode.
func get_a() -> Variant:
	match a_reference:
		ReferenceSource.SELF:
			match a_capture_at:
				CaptureAt.IN_EDITOR: return _editor_cache_a
				CaptureAt.READY:     return _ready_a
				_:                   return _runtime_a
		ReferenceSource.TARGET_NODE:
			if is_instance_valid(_a_target_resolved) and not property_path.is_empty():
				return _a_target_resolved.get_indexed(property_path)
			return null
		_:
			return _custom_value_ab(false)


## Returns the resolved State B value based on the reference mode.
func get_b() -> Variant:
	match b_reference:
		ReferenceSource.SELF:
			match b_capture_at:
				CaptureAt.IN_EDITOR: return _editor_cache_b
				CaptureAt.READY:     return _ready_b
				_:                   return _runtime_b
		ReferenceSource.TARGET_NODE:
			if is_instance_valid(_b_target_resolved) and not property_path.is_empty():
				return _b_target_resolved.get_indexed(property_path)
			return null
		_:
			return _custom_value_ab(true)


## Resolves TARGET_NODE references and captures base values.
## [param juice_node] is the JuiceBase node — passed through to [method PropertyTarget.capture_base]
## so [member node_path] resolves from the correct anchor.
func capture_base(host: Node, juice_node: Node = null) -> void:
	super.capture_base(host, juice_node)
	# Resolve TARGET_NODE references once so get_a()/get_b() can live-read.
	# Use _juice_node (set by super.capture_base) as the anchor — these NodePaths
	# are configured in the inspector relative to the JuiceBase node.
	var anchor: Node = _juice_node if _juice_node != null else host
	if anchor != null:
		if a_reference == ReferenceSource.TARGET_NODE and a_target_node != NodePath():
			_a_target_resolved = anchor.get_node_or_null(a_target_node)
		if b_reference == ReferenceSource.TARGET_NODE and b_target_node != NodePath():
			_b_target_resolved = anchor.get_node_or_null(b_target_node)


## Captures SELF+TRIGGER State A/B values.
## Uses [member _resolved_node] (set by [method capture_base]) for cross-node
## targeting — falls back to [param target] when node_path is empty.
func capture_runtime_values(target: Node) -> void:
	var source: Node = _resolved_node if is_instance_valid(_resolved_node) else target
	if source == null or property_path.is_empty():
		return
	var current: Variant = source.get_indexed(property_path)
	if a_reference == ReferenceSource.SELF and a_capture_at == CaptureAt.TRIGGER:
		_runtime_a = current
	if b_reference == ReferenceSource.SELF and b_capture_at == CaptureAt.TRIGGER:
		_runtime_b = current


## Captures SELF+READY State A/B values.
## [param juice_node] is the JuiceBase node — used as anchor to resolve
## [member node_path] so cross-node targeting reads from the correct node.
func capture_ready_values(target: Node, juice_node: Node = null) -> void:
	if property_path.is_empty():
		return
	var source: Node
	if node_path == NodePath():
		source = target
	elif juice_node != null:
		source = juice_node.get_node_or_null(node_path)
	else:
		source = target
	if source == null:
		return
	var current: Variant = source.get_indexed(property_path)
	if a_reference == ReferenceSource.SELF and a_capture_at == CaptureAt.READY:
		_ready_a = current
	if b_reference == ReferenceSource.SELF and b_capture_at == CaptureAt.READY:
		_ready_b = current
