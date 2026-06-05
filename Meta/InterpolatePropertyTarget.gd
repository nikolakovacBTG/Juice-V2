## Defines From/To values and reference mode for a single interpolated property.
##
## Add one [InterpolatePropertyTarget] per property to animate.
## Supports Custom (typed fields), Self (capture at Trigger/Ready/In Editor),
## and Target Node (live read from another node) for both From and To values.

# ============================================================================
# WHAT: From/To target declaration for PropertyInterpolateJuiceEffectBase.
# WHY:  Each animated property needs independently-typed From and To values
#       (float, Vector2, Color, bool, …) plus a per-direction capture-mode
#       decision. Separating this into a sub-resource lets designers configure
#       N targets per effect without code duplication.
#       The inspector layout is conditional: only the backing var matching
#       _detected_type is visible, keeping the inspector clean regardless of
#       how many types are stored.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Perform interpolation math — that is PropertyInterpolateJuiceEffectBase.
#           Does not write to nodes — the base class routes through JuiceLedger.
#           Does not provide a Capture button in the inspector — that is the
#           PropertyPickerPlugin (EditorInspectorPlugin) on Phase 6.6.
# ============================================================================

@tool
class_name InterpolatePropertyTarget
extends PropertyTarget

# =============================================================================
# CONFIGURATION  (managed via _get_property_list so ordering is controlled)
# =============================================================================

# --- From reference model ---
## How to determine the From value: Custom (typed field), Self (capture from node), or Target Node (live read).
var from_reference: int = ReferenceSource.CUSTOM:
	set(value):
		from_reference = value
		notify_property_list_changed()

## When Self reference is used: capture at Trigger (each animation start), Ready (once at _ready), or In Editor (snapshot).
var from_capture_at: int = CaptureAt.TRIGGER:
	set(value):
		from_capture_at = value
		if value != CaptureAt.IN_EDITOR:
			_from_editor_cached = null
		notify_property_list_changed()

## Path to the node whose property value is read live as the From value (Target Node mode).
var from_target_node: NodePath = NodePath()

# --- To reference model ---
## How to determine the To value: Custom (typed field), Self (capture from node), or Target Node (live read).
var to_reference: int = ReferenceSource.CUSTOM:
	set(value):
		to_reference = value
		notify_property_list_changed()

## When Self reference is used: capture at Trigger (each animation start), Ready (once at _ready), or In Editor (snapshot).
var to_capture_at: int = CaptureAt.TRIGGER:
	set(value):
		to_capture_at = value
		if value != CaptureAt.IN_EDITOR:
			_to_editor_cached = null
		notify_property_list_changed()

## Path to the node whose property value is read live as the To value (Target Node mode).
var to_target_node: NodePath = NodePath()

## Progress threshold at which discrete types (bool, String, etc.) flip from From to To value.
# Flip threshold for discrete types (bool, String, NodePath, etc.).
# Progress must cross this value before the property switches from FROM to TO.
var flip_threshold: float = 0.5

# =============================================================================
# INTERNAL STATE
# =============================================================================

# --- Custom FROM backing vars (one per supported GDScript type) ---
# Only the var matching _detected_type is visible in the inspector.
var from_bool: bool           = false
var from_int: int             = 0
var from_float: float         = 0.0
var from_vec2: Vector2        = Vector2.ZERO
var from_vec2i: Vector2i      = Vector2i.ZERO
var from_rect2: Rect2         = Rect2()
var from_rect2i: Rect2i       = Rect2i()
var from_vec3: Vector3        = Vector3.ZERO
var from_vec3i: Vector3i      = Vector3i()
var from_vec4: Vector4        = Vector4()
var from_vec4i: Vector4i      = Vector4i()
var from_quat: Quaternion     = Quaternion.IDENTITY
var from_aabb: AABB           = AABB()
var from_plane: Plane         = Plane()
var from_basis: Basis         = Basis.IDENTITY
var from_projection: Projection = Projection.IDENTITY
var from_color: Color         = Color.BLACK
var from_string: String       = ""
var from_stringname: StringName = &""
var from_nodepath: NodePath   = NodePath()
var from_object: Resource     = null

# --- Custom TO backing vars ---
var to_bool: bool             = true
var to_int: int               = 1
var to_float: float           = 1.0
var to_vec2: Vector2          = Vector2.ONE
var to_vec2i: Vector2i        = Vector2i.ONE
var to_rect2: Rect2           = Rect2(0.0, 0.0, 1.0, 1.0)
var to_rect2i: Rect2i         = Rect2i(0, 0, 1, 1)
var to_vec3: Vector3          = Vector3.ONE
var to_vec3i: Vector3i        = Vector3i(1, 1, 1)
var to_vec4: Vector4          = Vector4(1.0, 1.0, 1.0, 1.0)
var to_vec4i: Vector4i        = Vector4i(1, 1, 1, 1)
var to_quat: Quaternion       = Quaternion.IDENTITY
var to_aabb: AABB             = AABB(Vector3.ZERO, Vector3.ONE)
var to_plane: Plane           = Plane(0.0, 1.0, 0.0, 0.0)
var to_basis: Basis           = Basis.IDENTITY
var to_projection: Projection = Projection.IDENTITY
var to_color: Color           = Color.WHITE
var to_string: String         = ""
var to_stringname: StringName = &""
var to_nodepath: NodePath     = NodePath()
var to_object: Resource       = null

# --- Runtime capture (SELF + TRIGGER mode) ---
var _runtime_from: Variant = null
var _runtime_to:   Variant = null

# --- Ready capture (SELF + READY mode) ---
var _ready_from: Variant = null
var _ready_to:   Variant = null

# --- Target Node resolution cache (TARGET_NODE mode) ---
# Resolved once during capture_base() so get_from()/get_to() can read live.
var _from_target_resolved: Node = null
var _to_target_resolved:   Node = null

# --- Editor capture (IN_EDITOR mode) ---
var _from_editor_cached: Variant = null
var _to_editor_cached:   Variant = null

# _detected_type is inherited from PropertyTarget — do not redeclare here.
# PropertyTarget._detect_type() auto-updates it; shadowing creates a second
# slot that never syncs with the parent's write, breaking type detection.

# =============================================================================
# LIFECYCLE
# =============================================================================

func _init() -> void:
	# Tell PropertyTarget._get_property_list() to return [] and let this class
	# own the full layout — so we can interleave Target / From / To / Flip in
	# the intended order instead of getting path fields appended at the bottom.
	_subclass_owns_target_layout = true

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

# Emits the full inspector layout in a controlled order:
#   Target group  →  From group (+ conditional value)  →  To group  →  Flip
# Godot merges this with parent _get_property_list() results automatically.
# Because _subclass_owns_target_layout = true, the parent returns [] and
# THIS method is the sole source of truth for the property layout.
func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# --- Target block (owned here because _subclass_owns_target_layout = true) ---
	props.append({"name": "Target", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "node_path", "type": TYPE_NODE_PATH,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "property_path", "type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT})
	# Type readout — visible only once a property has been picked.
	if not property_path.is_empty():
		props.append({"name": "_type_display", "type": TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})
	# _detected_type is storage-only (never visible but must be serialised).
	props.append({"name": "_detected_type", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_STORAGE})

	# --- From block ---
	props.append({"name": "From", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "from_reference", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Custom,Self,Target Node",
		"usage": PROPERTY_USAGE_DEFAULT})
	if from_reference == ReferenceSource.CUSTOM:
		_emit_value_field(props, false)
	elif from_reference == ReferenceSource.SELF:
		props.append({"name": "from_capture_at", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Trigger,Ready,In Editor",
			"usage": PROPERTY_USAGE_DEFAULT})
		if from_capture_at == CaptureAt.IN_EDITOR:
			props.append({"name": "_from_cached_display", "type": TYPE_STRING,
				"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})
	elif from_reference == ReferenceSource.TARGET_NODE:
		props.append({"name": "from_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT})

	# --- To block ---
	props.append({"name": "To", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "to_reference", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Custom,Self,Target Node",
		"usage": PROPERTY_USAGE_DEFAULT})
	if to_reference == ReferenceSource.CUSTOM:
		_emit_value_field(props, true)
	elif to_reference == ReferenceSource.SELF:
		props.append({"name": "to_capture_at", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Trigger,Ready,In Editor",
			"usage": PROPERTY_USAGE_DEFAULT})
		if to_capture_at == CaptureAt.IN_EDITOR:
			props.append({"name": "_to_cached_display", "type": TYPE_STRING,
				"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})
	elif to_reference == ReferenceSource.TARGET_NODE:
		props.append({"name": "to_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT})

	# --- Editor cache storage (serialized only when SELF + IN_EDITOR) ---
	if from_reference == ReferenceSource.SELF and from_capture_at == CaptureAt.IN_EDITOR:
		props.append({"name": "_from_editor_cached", "type": TYPE_NIL,
			"usage": PROPERTY_USAGE_STORAGE})
	if to_reference == ReferenceSource.SELF and to_capture_at == CaptureAt.IN_EDITOR:
		props.append({"name": "_to_editor_cached", "type": TYPE_NIL,
			"usage": PROPERTY_USAGE_STORAGE})

	# --- Discrete / Flip block ---
	# Only discrete types (bool, string, etc.) use flip_threshold.
	# Continuous types (float, Vector2…) lerp and never need it.
	var is_discrete := _detected_type in [
		TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH,
		TYPE_PLANE, TYPE_BASIS, TYPE_PROJECTION, TYPE_OBJECT,
	]
	if is_discrete and _detected_type != TYPE_NIL:
		props.append({"name": "Flip", "type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
		props.append({"name": "flip_threshold", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
			"usage": PROPERTY_USAGE_DEFAULT})
	else:
		# Still serialise it so saved scenes don't lose a previously set value.
		props.append({"name": "flip_threshold", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_STORAGE})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		# --- Reference model ---
		&"from_reference":       from_reference = value;       return true
		&"from_capture_at":      from_capture_at = value;      return true
		&"from_target_node":     from_target_node = value;     return true
		&"to_reference":         to_reference = value;         return true
		&"to_capture_at":        to_capture_at = value;        return true
		&"to_target_node":       to_target_node = value;       return true
		&"flip_threshold":       flip_threshold = value;       return true
		# --- Migration: old CaptureMode (CUSTOM=0, IN_EDITOR=1, ON_TRIGGER=2) ---
		&"capture_from":
			match value:
				0: from_reference = ReferenceSource.CUSTOM
				1: from_reference = ReferenceSource.SELF; from_capture_at = CaptureAt.IN_EDITOR
				2: from_reference = ReferenceSource.SELF; from_capture_at = CaptureAt.TRIGGER
			return true
		&"capture_to":
			match value:
				0: to_reference = ReferenceSource.CUSTOM
				1: to_reference = ReferenceSource.SELF; to_capture_at = CaptureAt.IN_EDITOR
				2: to_reference = ReferenceSource.SELF; to_capture_at = CaptureAt.TRIGGER
			return true
		# node_path and property_path are handled by PropertyTarget._set()
		# --- FROM backing vars ---
		&"from_bool":             from_bool = value;            return true
		&"from_int":              from_int = value;             return true
		&"from_float":            from_float = value;           return true
		&"from_vec2":             from_vec2 = value;            return true
		&"from_vec2i":            from_vec2i = value;           return true
		&"from_rect2":            from_rect2 = value;           return true
		&"from_rect2i":           from_rect2i = value;          return true
		&"from_vec3":             from_vec3 = value;            return true
		&"from_vec3i":            from_vec3i = value;           return true
		&"from_vec4":             from_vec4 = value;            return true
		&"from_vec4i":            from_vec4i = value;           return true
		&"from_quat":             from_quat = value;            return true
		&"from_aabb":             from_aabb = value;            return true
		&"from_plane":            from_plane = value;           return true
		&"from_basis":            from_basis = value;           return true
		&"from_projection":       from_projection = value;      return true
		&"from_color":            from_color = value;           return true
		&"from_string":           from_string = value;          return true
		&"from_stringname":       from_stringname = value;      return true
		&"from_nodepath":         from_nodepath = value;        return true
		&"from_object":           from_object = value;          return true
		# --- TO backing vars ---
		&"to_bool":               to_bool = value;              return true
		&"to_int":                to_int = value;               return true
		&"to_float":              to_float = value;             return true
		&"to_vec2":               to_vec2 = value;              return true
		&"to_vec2i":              to_vec2i = value;             return true
		&"to_rect2":              to_rect2 = value;             return true
		&"to_rect2i":             to_rect2i = value;            return true
		&"to_vec3":               to_vec3 = value;              return true
		&"to_vec3i":              to_vec3i = value;             return true
		&"to_vec4":               to_vec4 = value;              return true
		&"to_vec4i":              to_vec4i = value;             return true
		&"to_quat":               to_quat = value;              return true
		&"to_aabb":               to_aabb = value;              return true
		&"to_plane":              to_plane = value;             return true
		&"to_basis":              to_basis = value;             return true
		&"to_projection":         to_projection = value;        return true
		&"to_color":              to_color = value;             return true
		&"to_string":             to_string = value;            return true
		&"to_stringname":         to_stringname = value;        return true
		&"to_nodepath":           to_nodepath = value;          return true
		&"to_object":             to_object = value;            return true
		# --- Editor cache ---
		&"_from_editor_cached":   _from_editor_cached = value;  return true
		&"_to_editor_cached":     _to_editor_cached = value;    return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		# --- Reference model ---
		&"from_reference":       return from_reference
		&"from_capture_at":      return from_capture_at
		&"from_target_node":     return from_target_node
		&"to_reference":         return to_reference
		&"to_capture_at":        return to_capture_at
		&"to_target_node":       return to_target_node
		&"flip_threshold":       return flip_threshold
		# FROM backing vars
		&"from_bool":             return from_bool
		&"from_int":              return from_int
		&"from_float":            return from_float
		&"from_vec2":             return from_vec2
		&"from_vec2i":            return from_vec2i
		&"from_rect2":            return from_rect2
		&"from_rect2i":           return from_rect2i
		&"from_vec3":             return from_vec3
		&"from_vec3i":            return from_vec3i
		&"from_vec4":             return from_vec4
		&"from_vec4i":            return from_vec4i
		&"from_quat":             return from_quat
		&"from_aabb":             return from_aabb
		&"from_plane":            return from_plane
		&"from_basis":            return from_basis
		&"from_projection":       return from_projection
		&"from_color":            return from_color
		&"from_string":           return from_string
		&"from_stringname":       return from_stringname
		&"from_nodepath":         return from_nodepath
		&"from_object":           return from_object
		# TO backing vars
		&"to_bool":               return to_bool
		&"to_int":                return to_int
		&"to_float":              return to_float
		&"to_vec2":               return to_vec2
		&"to_vec2i":              return to_vec2i
		&"to_rect2":              return to_rect2
		&"to_rect2i":             return to_rect2i
		&"to_vec3":               return to_vec3
		&"to_vec3i":              return to_vec3i
		&"to_vec4":               return to_vec4
		&"to_vec4i":              return to_vec4i
		&"to_quat":               return to_quat
		&"to_aabb":               return to_aabb
		&"to_plane":              return to_plane
		&"to_basis":              return to_basis
		&"to_projection":         return to_projection
		&"to_color":              return to_color
		&"to_string":             return to_string
		&"to_stringname":         return to_stringname
		&"to_nodepath":           return to_nodepath
		&"to_object":             return to_object
		# Editor cache
		&"_from_editor_cached":   return _from_editor_cached
		&"_to_editor_cached":     return _to_editor_cached
		# Read-only display strings computed on demand.
		&"_from_cached_display":
			return str(_from_editor_cached) if _from_editor_cached != null else "(not captured — use Capture button)"
		&"_to_cached_display":
			return str(_to_editor_cached) if _to_editor_cached != null else "(not captured — use Capture button)"
		&"_from_pick_hint":        return "← Pick a property path first"
		&"_to_pick_hint":          return "← Pick a property path first"
		&"_from_unsupported_hint": return "Type %d not editable via inspector" % _detected_type
		&"_to_unsupported_hint":   return "Type %d not editable via inspector" % _detected_type
	return null

# =============================================================================
# PUBLIC API
# =============================================================================

## Returns true when the property path has been set.
func is_configured() -> bool:
	return not property_path.is_empty()


## Captures base value in the Ledger, then auto-detects [member _detected_type]
## from the registered Ledger base if not yet known.
## [param host] is the juiced node (the node JuiceBase is attached to).
## [param juice_node] is the JuiceBase node — passed through to [method PropertyTarget.capture_base]
## so [member node_path] resolves from the correct anchor.
func capture_base(host: Node, juice_node: Node = null) -> void:
	super.capture_base(host, juice_node)
	if _detected_type == TYPE_NIL and not property_path.is_empty():
		# Auto-detect type from the Ledger base on the resolved node (not host),
		# so cross-node targeting finds the property on the correct node.
		var lookup_node: Node = _resolved_node if is_instance_valid(_resolved_node) else host
		if lookup_node != null:
			var base_val: Variant = JuiceLedger.get_base(lookup_node, property_path, null)
			if base_val != null:
				_detected_type = typeof(base_val)
	# Resolve TARGET_NODE references once so get_from()/get_to() can live-read.
	# Use _juice_node (set by super.capture_base) as the anchor — these NodePaths
	# are configured in the inspector relative to the JuiceBase node.
	var anchor: Node = _juice_node if _juice_node != null else host
	if anchor != null:
		if from_reference == ReferenceSource.TARGET_NODE and from_target_node != NodePath():
			_from_target_resolved = anchor.get_node_or_null(from_target_node)
		if to_reference == ReferenceSource.TARGET_NODE and to_target_node != NodePath():
			_to_target_resolved = anchor.get_node_or_null(to_target_node)


## Captures SELF+TRIGGER From/To values from the current property state on [param target].
## Call in [method _on_animate_start] after [method capture_base].
func capture_runtime_values(target: Node) -> void:
	if target == null or property_path.is_empty():
		return
	var current: Variant = target.get_indexed(property_path)
	if from_reference == ReferenceSource.SELF and from_capture_at == CaptureAt.TRIGGER:
		_runtime_from = current
	if to_reference == ReferenceSource.SELF and to_capture_at == CaptureAt.TRIGGER:
		_runtime_to = current


## Captures SELF+READY From/To values from the current property state on [param target].
## Call once during [code]_ready()[/code] from the owning effect.
func capture_ready_values(target: Node) -> void:
	if target == null or property_path.is_empty():
		return
	var current: Variant = target.get_indexed(property_path)
	if from_reference == ReferenceSource.SELF and from_capture_at == CaptureAt.READY:
		_ready_from = current
	if to_reference == ReferenceSource.SELF and to_capture_at == CaptureAt.READY:
		_ready_to = current


## Returns the resolved FROM value based on the reference mode.
## Returns [code]null[/code] if not yet captured or not configured.
func get_from() -> Variant:
	match from_reference:
		ReferenceSource.SELF:
			match from_capture_at:
				CaptureAt.IN_EDITOR: return _from_editor_cached
				CaptureAt.READY:     return _ready_from
				_:                   return _runtime_from
		ReferenceSource.TARGET_NODE:
			if is_instance_valid(_from_target_resolved) and not property_path.is_empty():
				return _from_target_resolved.get_indexed(property_path)
			return null
		_:
			return _custom_value(false)


## Returns the resolved TO value based on the reference mode.
## Returns [code]null[/code] if not yet captured or not configured.
func get_to() -> Variant:
	match to_reference:
		ReferenceSource.SELF:
			match to_capture_at:
				CaptureAt.IN_EDITOR: return _to_editor_cached
				CaptureAt.READY:     return _ready_to
				_:                   return _runtime_to
		ReferenceSource.TARGET_NODE:
			if is_instance_valid(_to_target_resolved) and not property_path.is_empty():
				return _to_target_resolved.get_indexed(property_path)
			return null
		_:
			return _custom_value(true)

# =============================================================================
# HELPERS
# =============================================================================

# Appends the single inspector field that matches _detected_type to [param props].
# [param is_to] = true → "to_*" prefix, false → "from_*" prefix.
# Called only when capture mode == CUSTOM to keep the inspector uncluttered.
func _emit_value_field(props: Array[Dictionary], is_to: bool) -> void:
	var prefix := "to_" if is_to else "from_"
	match _detected_type:
		TYPE_BOOL:        props.append({"name": prefix + "bool",        "type": TYPE_BOOL,        "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_INT:         props.append({"name": prefix + "int",         "type": TYPE_INT,         "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_FLOAT:       props.append({"name": prefix + "float",       "type": TYPE_FLOAT,       "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_VECTOR2:     props.append({"name": prefix + "vec2",        "type": TYPE_VECTOR2,     "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_VECTOR2I:    props.append({"name": prefix + "vec2i",       "type": TYPE_VECTOR2I,    "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_RECT2:       props.append({"name": prefix + "rect2",       "type": TYPE_RECT2,       "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_RECT2I:      props.append({"name": prefix + "rect2i",      "type": TYPE_RECT2I,      "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_VECTOR3:     props.append({"name": prefix + "vec3",        "type": TYPE_VECTOR3,     "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_VECTOR3I:    props.append({"name": prefix + "vec3i",       "type": TYPE_VECTOR3I,    "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_VECTOR4:     props.append({"name": prefix + "vec4",        "type": TYPE_VECTOR4,     "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_VECTOR4I:    props.append({"name": prefix + "vec4i",       "type": TYPE_VECTOR4I,    "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_QUATERNION:  props.append({"name": prefix + "quat",        "type": TYPE_QUATERNION,  "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_AABB:        props.append({"name": prefix + "aabb",        "type": TYPE_AABB,        "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_PLANE:       props.append({"name": prefix + "plane",       "type": TYPE_PLANE,       "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_BASIS:       props.append({"name": prefix + "basis",       "type": TYPE_BASIS,       "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_PROJECTION:  props.append({"name": prefix + "projection",  "type": TYPE_PROJECTION,  "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_COLOR:       props.append({"name": prefix + "color",       "type": TYPE_COLOR,       "hint": PROPERTY_HINT_COLOR_NO_ALPHA, "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_STRING:      props.append({"name": prefix + "string",      "type": TYPE_STRING,      "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_STRING_NAME: props.append({"name": prefix + "stringname",  "type": TYPE_STRING_NAME, "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_NODE_PATH:   props.append({"name": prefix + "nodepath",    "type": TYPE_NODE_PATH,   "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_OBJECT:      props.append({"name": prefix + "object",      "type": TYPE_OBJECT,      "hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string": "Resource", "usage": PROPERTY_USAGE_DEFAULT})
		TYPE_NIL:
			# No property picked yet — show a hint row.
			var hint_name := "_to_pick_hint" if is_to else "_from_pick_hint"
			props.append({"name": hint_name, "type": TYPE_STRING,
				"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})
		_:
			# Unsupported type — stored but not editable via the inspector.
			var hint_name2 := "_to_unsupported_hint" if is_to else "_from_unsupported_hint"
			props.append({"name": hint_name2, "type": TYPE_STRING,
				"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY})


# Returns the typed CUSTOM value for FROM (is_to=false) or TO (is_to=true).
# Reads the backing var that matches _detected_type.
# Returns null when _detected_type is TYPE_NIL (no property picked yet).
func _custom_value(is_to: bool) -> Variant:
	match _detected_type:
		TYPE_BOOL:        return to_bool        if is_to else from_bool
		TYPE_INT:         return to_int         if is_to else from_int
		TYPE_FLOAT:       return to_float       if is_to else from_float
		TYPE_VECTOR2:     return to_vec2        if is_to else from_vec2
		TYPE_VECTOR2I:    return to_vec2i       if is_to else from_vec2i
		TYPE_RECT2:       return to_rect2       if is_to else from_rect2
		TYPE_RECT2I:      return to_rect2i      if is_to else from_rect2i
		TYPE_VECTOR3:     return to_vec3        if is_to else from_vec3
		TYPE_VECTOR3I:    return to_vec3i       if is_to else from_vec3i
		TYPE_VECTOR4:     return to_vec4        if is_to else from_vec4
		TYPE_VECTOR4I:    return to_vec4i       if is_to else from_vec4i
		TYPE_QUATERNION:  return to_quat        if is_to else from_quat
		TYPE_AABB:        return to_aabb        if is_to else from_aabb
		TYPE_PLANE:       return to_plane       if is_to else from_plane
		TYPE_BASIS:       return to_basis       if is_to else from_basis
		TYPE_PROJECTION:  return to_projection  if is_to else from_projection
		TYPE_COLOR:       return to_color       if is_to else from_color
		TYPE_STRING:      return to_string      if is_to else from_string
		TYPE_STRING_NAME: return to_stringname  if is_to else from_stringname
		TYPE_NODE_PATH:   return to_nodepath    if is_to else from_nodepath
		TYPE_OBJECT:      return to_object      if is_to else from_object
	return null
