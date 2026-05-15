## Defines From/To values and capture mode for a single interpolated property.
##
## Add one InterpolatePropertyTarget per property to animate.
## Supports Custom, In-Editor, and On-Trigger capture of the From and To values.

# ============================================================================
# WHAT: From/To target declaration for InterpolatePropertyJuiceEffectBase.
# WHY:  Each animated property needs independently-typed From and To values
#       (float, Vector2, Color, bool, …) plus a capture-mode decision.
#       Separating this into a sub-resource lets designers configure N targets
#       per effect without code duplication.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Perform interpolation math — that is InterpolatePropertyJuiceEffectBase.
#           Does not write to nodes — the base class routes through JuiceLedger.
#           Does not support node_path cross-targeting — always targets the
#           domain node's primary target (Phase 6.2 constraint; extended later).
# ============================================================================

@tool
class_name InterpolatePropertyTarget
extends PropertyTarget

# =============================================================================
# ENUMS
# =============================================================================

enum CaptureMode {
	## Use the manually typed From/To values below.
	CUSTOM    = 0,
	## Capture the property value once in the editor (press the Capture button).
	IN_EDITOR = 1,
	## Capture the property value at the moment the animation is triggered.
	ON_TRIGGER = 2,
}

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("From")

## Where the FROM value comes from: manually typed, captured in editor, or
## captured the moment the animation fires.
@export var capture_from: CaptureMode = CaptureMode.CUSTOM

@export_group("To")

## Where the TO value comes from.
@export var capture_to: CaptureMode = CaptureMode.CUSTOM

@export_group("Discrete")

## Progress threshold at which discrete/flip types (bool, String, NodePath, etc.)
## switch from the FROM value to the TO value. 0.5 = halfway through the animation.
@export_range(0.0, 1.0, 0.01) var flip_threshold: float = 0.5

# =============================================================================
# INTERNAL STATE
# =============================================================================

# _detected_type is inherited from PropertyTarget — do not redeclare here.
# PropertyTarget._detect_type() updates it, and _get_property_list() serialises it.
# Shadowing it in this subclass would cause PropertyTarget._set() and subclass
# code to read/write different slots, breaking type detection permanently.

# --- Custom FROM backing vars (one per supported type) ---
var from_bool: bool        = false
var from_int: int          = 0
var from_float: float      = 0.0
var from_vec2: Vector2     = Vector2.ZERO
var from_vec2i: Vector2i   = Vector2i.ZERO
var from_rect2: Rect2      = Rect2()
var from_rect2i: Rect2i    = Rect2i()
var from_vec3: Vector3     = Vector3.ZERO
var from_vec3i: Vector3i   = Vector3i()
var from_vec4: Vector4     = Vector4()
var from_vec4i: Vector4i   = Vector4i()
var from_quat: Quaternion  = Quaternion.IDENTITY
var from_aabb: AABB        = AABB()
var from_plane: Plane      = Plane()
var from_basis: Basis      = Basis.IDENTITY
var from_projection: Projection = Projection.IDENTITY
var from_color: Color      = Color.BLACK
var from_string: String    = ""
var from_stringname: StringName = &""
var from_nodepath: NodePath = NodePath()
var from_object: Resource  = null

# --- Custom TO backing vars ---
var to_bool: bool          = true
var to_int: int            = 1
var to_float: float        = 1.0
var to_vec2: Vector2       = Vector2.ONE
var to_vec2i: Vector2i     = Vector2i.ONE
var to_rect2: Rect2        = Rect2(0.0, 0.0, 1.0, 1.0)
var to_rect2i: Rect2i      = Rect2i(0, 0, 1, 1)
var to_vec3: Vector3       = Vector3.ONE
var to_vec3i: Vector3i     = Vector3i(1, 1, 1)
var to_vec4: Vector4       = Vector4(1.0, 1.0, 1.0, 1.0)
var to_vec4i: Vector4i     = Vector4i(1, 1, 1, 1)
var to_quat: Quaternion    = Quaternion.IDENTITY
var to_aabb: AABB          = AABB(Vector3.ZERO, Vector3.ONE)
var to_plane: Plane        = Plane(0.0, 1.0, 0.0, 0.0)
var to_basis: Basis        = Basis.IDENTITY
var to_projection: Projection = Projection.IDENTITY
var to_color: Color        = Color.WHITE
var to_string: String      = ""
var to_stringname: StringName = &""
var to_nodepath: NodePath  = NodePath()
var to_object: Resource    = null

# --- Runtime capture (ON_TRIGGER mode) ---
var _runtime_from: Variant = null
var _runtime_to:   Variant = null

# --- Editor capture (IN_EDITOR mode) ---
var _from_editor_cached: Variant = null
var _to_editor_cached:   Variant = null

# =============================================================================
# PUBLIC API
# =============================================================================

## Returns true when the property path has been set.
func is_configured() -> bool:
	return not property_path.is_empty()


## Records the current property value on [param host] as the Ledger base,
## then auto-detects [member _detected_type] from the base value if not yet set.
func capture_base(host: Node) -> void:
	super.capture_base(host)
	if _detected_type == TYPE_NIL and not property_path.is_empty() and host != null:
		var base_val: Variant = JuiceLedger.get_base(host, property_path, null)
		if base_val != null:
			_detected_type = typeof(base_val)


## Captures ON_TRIGGER From/To values from the current property state on [param target].
## Call in [method _on_animate_start] after [method capture_base].
func capture_runtime_values(target: Node) -> void:
	if target == null or property_path.is_empty():
		return
	var current: Variant = target.get_indexed(property_path)
	if capture_from == CaptureMode.ON_TRIGGER:
		_runtime_from = current
	if capture_to == CaptureMode.ON_TRIGGER:
		_runtime_to = current


## Returns the resolved FROM value based on the capture mode.
## Returns [code]null[/code] if not yet captured or not configured.
func get_from() -> Variant:
	match capture_from:
		CaptureMode.IN_EDITOR:  return _from_editor_cached
		CaptureMode.ON_TRIGGER: return _runtime_from
		_:                      return _custom_value(false)


## Returns the resolved TO value based on the capture mode.
## Returns [code]null[/code] if not yet captured or not configured.
func get_to() -> Variant:
	match capture_to:
		CaptureMode.IN_EDITOR:  return _to_editor_cached
		CaptureMode.ON_TRIGGER: return _runtime_to
		_:                      return _custom_value(true)

# =============================================================================
# HELPERS
# =============================================================================

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
