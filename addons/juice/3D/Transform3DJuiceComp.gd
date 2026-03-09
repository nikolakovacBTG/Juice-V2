# Transform3DJuiceComp.gd
# ============================================================================
# WHAT: Consolidated deterministic transform effect for Node3D nodes. Combines
#       position, rotation, and scale animation into a single component with a
#       TransformTarget selector. Uses _get_property_list() to conditionally
#       show only relevant exports in the inspector.
# WHY: Replaces 3 separate scripts (Position3DJuiceComp, Rotation3DJuiceComp,
#      Scale3DJuiceComp) with one unified component, reducing file count and
#      ensuring consistent behavior across transform types.
#
# WRITE PATTERN: Delta-first. Each frame writes only the CHANGE in this comp's
#   contribution: node.property += (desired - _my_contribution). This enables
#   stacking with other effects and preserves external changes to the node.
# SYSTEM: Juicing System (addons/juice/) - 3D Domain
# DOES NOT: Handle Control or Node2D targets (use TransformControl/Transform2D).
# DOES NOT: Handle procedural effects like shake or noise (use Shake/Noise comps).
# DOES NOT: Handle arbitrary property animation (use PropertyShake/PropertyNoise).
# ============================================================================
#
# TRANSFORM TARGETS:
# - POSITION: Animates Node3D.position with Vector3 offset + OffsetUnit3D system.
#   Supports WORLD_UNITS, FRACTION_OWN, FRACTION_PARENT units. Uses size
#   inference (MeshInstance3D AABB, CollisionShape3D, recursive child bounds).
# - ROTATION: Animates Node3D rotation via From/To model (degrees/radians).
#   Uses Quaternion slerp for smooth interpolation. Supports pivot_offset for
#   rotation around arbitrary points (door hinges, lever bases, chest lids).
#   Pivot is Transform3D-based: fixed_pivot = base_origin + base_basis * pivot,
#   new_origin = fixed_pivot - new_basis * pivot.
# - SCALE: Animates Node3D.scale with Vector3 offset + pivot mode.
#   Pivot compensation via: pos += pivot * (ONE - scale_ratio).
#
# PIVOT (ROTATION):
# Uses a Vector3 pivot_offset from node origin (local space). The pivot point
# is pre-computed in parent space at animation start and stays fixed.
#
# PIVOT (SCALE):
# - AUTO_CENTER: Infers center from MeshInstance3D AABB / CollisionShape3D.
# - INHERIT: Scales from node origin (no compensation).
# - CUSTOM: Scales from custom_pivot (local-space world units).
#
# FROM/TO MODEL (Position, Rotation, Scale):
# All transform types use a unified "From [source] To [destination]" model.
# Sources can be CUSTOM (explicit value), SELF (snapshot), or TARGET_NODE (live).
# Rotation uses quaternion slerp for correct interpolation (no gimbal lock).
#
# CONDITIONAL EXPORTS:
# Changing transform_target triggers notify_property_list_changed() which
# shows/hides the relevant parameters via _get_property_list().
# ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBase3D.svg")
class_name Transform3DJuiceComp
extends JuiceCompBase

# =============================================================================
# TRANSFORM TARGET SELECTION
# =============================================================================

## Which transform property to animate
enum TransformTarget {
	POSITION,  ## Animate Node3D.position with offset + unit
	ROTATION,  ## Animate Node3D rotation (3-axis, Quaternion slerp)
	SCALE      ## Animate Node3D.scale with offset
}

@export var transform_target: TransformTarget = TransformTarget.POSITION:
	set(value):
		transform_target = value
		notify_property_list_changed()

# =============================================================================
# ENUMS
# =============================================================================

## How to interpret position offset values (3D-specific, no viewport fraction)
enum OffsetUnit3D {
	WORLD_UNITS,    ## Raw world units
	FRACTION_OWN,   ## Fraction of target's own AABB size
	FRACTION_PARENT ## Fraction of parent's AABB size
}

## Determines how the pivot point is calculated for scaling
enum PivotMode {
	AUTO_CENTER,  ## Infer center from AABB and compensate position
	INHERIT,      ## Scale from node origin (no compensation)
	CUSTOM        ## Scale from custom_pivot (local-space world units)
}

## Reference type for From/To axes (shared by Position, Rotation, and Scale)
enum TransformReference {
	CUSTOM,       ## Explicit value supplied by the user
	SELF,         ## This object's current value (captured at capture_at moment)
	TARGET_NODE   ## Another object's value (tracked live every frame)
}

## How to interpret custom position values (3D — no viewport fraction)
enum PositionIn3D {
	WORLD_UNITS,      ## Position in world units
	FRACTION_OWN,     ## Position in fraction of object's own AABB
	FRACTION_PARENT   ## Position in fraction of parent's AABB
}

## When to capture Self's transform value
enum CaptureAt {
	TRIGGER,  ## Capture when animation starts (default)
	READY     ## Capture when scene loads / _ready()
}

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — they are shown/hidden via _get_property_list()
# =============================================================================

# --- POSITION (From/To model) ---
## Custom From position value (shown when from_reference == CUSTOM)
var from_position: Vector3 = Vector3.ZERO
## How to interpret From position values
var from_position_in: int = PositionIn3D.WORLD_UNITS
## Custom To position value (shown when to_reference == CUSTOM)
var to_position: Vector3 = Vector3.ZERO
## How to interpret To position values
var to_position_in: int = PositionIn3D.WORLD_UNITS

# --- ROTATION (From/To model) ---
## Custom From rotation offset (shown when from_reference == CUSTOM)
var from_rotation: Vector3 = Vector3.ZERO
## Custom To rotation offset (shown when to_reference == CUSTOM)
var to_rotation: Vector3 = Vector3(0, 90, 0)
## Unit for rotation values (degrees is more intuitive for most users)
var rotation_unit: int = RotationUnit.DEGREES
## Pivot point offset from node origin (local space).
## Rotation appears to happen around this point.
## Useful for doors (hinge), levers (base), lids (back edge).
var rotation_pivot_offset: Vector3 = Vector3.ZERO

# --- SHARED FROM/TO (used by all transform types) ---
## Reference type for the From endpoint (CUSTOM, SELF, or TARGET_NODE)
var from_reference: int = TransformReference.CUSTOM:
	set(value):
		from_reference = value
		notify_property_list_changed()
## Reference type for the To endpoint (CUSTOM, SELF, or TARGET_NODE)
var to_reference: int = TransformReference.SELF:
	set(value):
		to_reference = value
		notify_property_list_changed()
## Target node for From reference (shown when from_reference == TARGET_NODE)
var from_target_node: NodePath
## Target node for To reference (shown when to_reference == TARGET_NODE)
var to_target_node: NodePath
## When to capture Self's transform value (shown when reference == SELF)
var capture_at: int = CaptureAt.TRIGGER

# --- SCALE (From/To model) ---
## Custom From scale value (shown when from_reference == CUSTOM)
var from_scale: Vector3 = Vector3.ZERO
## Custom To scale value (shown when to_reference == CUSTOM)
var to_scale: Vector3 = Vector3.ONE
## Pivot mode for scaling
var scale_pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		scale_pivot_mode = value
		notify_property_list_changed()
## Custom pivot in local-space coordinates (world units)
var scale_custom_pivot: Vector3 = Vector3.ZERO

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _base_position: Vector3 = Vector3.ZERO
var _base_transform: Transform3D = Transform3D.IDENTITY
var _base_euler: Vector3 = Vector3.ZERO
var _base_quat: Quaternion = Quaternion.IDENTITY
var _base_scale: Vector3 = Vector3.ONE

## Whether base has been captured
var _has_base: bool = false

## Fixed pivot position in parent space (for rotation, computed once at start)
var _fixed_pivot_parent: Vector3 = Vector3.ZERO

## Resolved pivot point for scale (local space)
var _scale_pivot_point: Vector3 = Vector3.ZERO
var _scale_pivot_resolved: bool = false

## Delta-first contribution tracking.
## Each tracks what THIS comp has contributed to the node's property.
## On each frame: delta = desired - contribution; node.prop += delta.
## On cleanup: node.prop -= contribution.
var _my_position_contribution: Vector3 = Vector3.ZERO
var _my_rotation_contribution: Vector3 = Vector3.ZERO
var _my_scale_contribution: Vector3 = Vector3.ZERO

## Tracks last logged progress decile to throttle per-frame debug output.
## Logs at ~10% intervals instead of every frame to avoid flooding the buffer.
var _debug_last_logged_decile: int = -1

## Resolved references for From/To target nodes (cached at animation start)
## Shared by Position, Rotation, and Scale From/To models
var _from_ref: Node3D = null
var _to_ref: Node3D = null
## Self position snapshot — captured once at the moment chosen by capture_at
var _self_position_snapshot: Vector3 = Vector3.ZERO
var _has_self_position_snapshot: bool = false
## Self rotation snapshot — captured once at the moment chosen by capture_at (euler radians)
var _self_rotation_snapshot: Vector3 = Vector3.ZERO
var _has_self_rotation_snapshot: bool = false
## Self scale snapshot — captured once at the moment chosen by capture_at
var _self_scale_snapshot: Vector3 = Vector3.ONE
var _has_self_scale_snapshot: bool = false


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	match transform_target:
		TransformTarget.POSITION:
			props.append_array(_get_position_from_to_properties())

		TransformTarget.ROTATION:
			props.append_array(_get_rotation_from_to_properties())

		TransformTarget.SCALE:
			props.append_array(_get_scale_from_to_properties())
			props.append_array(_get_scale_pivot_properties())

	return props


## Position From/To inspector properties (new model)
func _get_position_from_to_properties() -> Array[Dictionary]:
	var pos_props: Array[Dictionary] = []

	# --- From group ---
	pos_props.append({"name": "From", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	pos_props.append({
		"name": "from_reference",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node",
	})

	if from_reference == TransformReference.CUSTOM:
		pos_props.append({
			"name": "from_position_in",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "World Units,Fraction Own,Fraction Parent",
		})
		pos_props.append({
			"name": "from_position",
			"type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif from_reference == TransformReference.SELF:
		pos_props.append({
			"name": "capture_at",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready",
		})
	elif from_reference == TransformReference.TARGET_NODE:
		pos_props.append({
			"name": "from_target_node",
			"type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node3D",
		})

	# --- To group ---
	pos_props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	pos_props.append({
		"name": "to_reference",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node",
	})

	if to_reference == TransformReference.CUSTOM:
		pos_props.append({
			"name": "to_position_in",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "World Units,Fraction Own,Fraction Parent",
		})
		pos_props.append({
			"name": "to_position",
			"type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif to_reference == TransformReference.SELF:
		pos_props.append({
			"name": "capture_at",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready",
		})
	elif to_reference == TransformReference.TARGET_NODE:
		pos_props.append({
			"name": "to_target_node",
			"type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node3D",
		})

	return pos_props


## Rotation From/To inspector properties (new model)
func _get_rotation_from_to_properties() -> Array[Dictionary]:
	var rot_props: Array[Dictionary] = []

	# --- From group ---
	rot_props.append({"name": "From", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	rot_props.append({
		"name": "from_reference",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node",
	})

	if from_reference == TransformReference.CUSTOM:
		rot_props.append({
			"name": "from_rotation",
			"type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		rot_props.append({
			"name": "rotation_unit",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Degrees,Radians",
		})
	elif from_reference == TransformReference.SELF:
		rot_props.append({
			"name": "capture_at",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready",
		})
	elif from_reference == TransformReference.TARGET_NODE:
		rot_props.append({
			"name": "from_target_node",
			"type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node3D",
		})

	# --- To group ---
	rot_props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	rot_props.append({
		"name": "to_reference",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node",
	})

	if to_reference == TransformReference.CUSTOM:
		rot_props.append({
			"name": "to_rotation",
			"type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		# Only show rotation_unit once (shared between From/To custom)
		if from_reference != TransformReference.CUSTOM:
			rot_props.append({
				"name": "rotation_unit",
				"type": TYPE_INT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Degrees,Radians",
			})
	elif to_reference == TransformReference.SELF:
		rot_props.append({
			"name": "capture_at",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready",
		})
	elif to_reference == TransformReference.TARGET_NODE:
		rot_props.append({
			"name": "to_target_node",
			"type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node3D",
		})

	# Rotation pivot (always shown for rotation)
	rot_props.append({"name": "Pivot", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	rot_props.append({
		"name": "rotation_pivot_offset",
		"type": TYPE_VECTOR3,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_NONE,
	})

	return rot_props


## Scale From/To inspector properties (new model)
func _get_scale_from_to_properties() -> Array[Dictionary]:
	var scale_props: Array[Dictionary] = []

	# --- From group ---
	scale_props.append({"name": "From", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	scale_props.append({
		"name": "from_reference",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node",
	})

	if from_reference == TransformReference.CUSTOM:
		scale_props.append({
			"name": "from_scale",
			"type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif from_reference == TransformReference.SELF:
		scale_props.append({
			"name": "capture_at",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready",
		})
	elif from_reference == TransformReference.TARGET_NODE:
		scale_props.append({
			"name": "from_target_node",
			"type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node3D",
		})

	# --- To group ---
	scale_props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	scale_props.append({
		"name": "to_reference",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node",
	})

	if to_reference == TransformReference.CUSTOM:
		scale_props.append({
			"name": "to_scale",
			"type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif to_reference == TransformReference.SELF:
		scale_props.append({
			"name": "capture_at",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready",
		})
	elif to_reference == TransformReference.TARGET_NODE:
		scale_props.append({
			"name": "to_target_node",
			"type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node3D",
		})

	return scale_props


## Scale pivot properties (extracted for clarity)
func _get_scale_pivot_properties() -> Array[Dictionary]:
	var pivot_props: Array[Dictionary] = [{
		"name": "scale_pivot_mode",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Auto Center,Inherit,Custom",
	}]
	# Only show scale_custom_pivot input when scale_pivot_mode is CUSTOM
	if scale_pivot_mode == PivotMode.CUSTOM:
		pivot_props.append({
			"name": "scale_custom_pivot",
			"type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE,
		})
	return pivot_props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		# Position (From/To model)
		&"from_position": from_position = value; return true
		&"from_position_in": from_position_in = value; return true
		&"to_position": to_position = value; return true
		&"to_position_in": to_position_in = value; return true
		# Rotation (From/To model)
		&"from_rotation": from_rotation = value; return true
		&"to_rotation": to_rotation = value; return true
		&"rotation_unit": rotation_unit = value; return true
		&"rotation_pivot_offset": rotation_pivot_offset = value; return true
		# Shared From/To
		&"from_reference": from_reference = value; return true
		&"to_reference": to_reference = value; return true
		&"from_target_node": from_target_node = value; return true
		&"to_target_node": to_target_node = value; return true
		&"capture_at": capture_at = value; return true
		# Scale (From/To model)
		&"from_scale": from_scale = value; return true
		&"to_scale": to_scale = value; return true
		# Scale pivot
		&"scale_pivot_mode": scale_pivot_mode = value; return true
		&"scale_custom_pivot": scale_custom_pivot = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		# Position (From/To model)
		&"from_position": return from_position
		&"from_position_in": return from_position_in
		&"to_position": return to_position
		&"to_position_in": return to_position_in
		# Rotation (From/To model)
		&"from_rotation": return from_rotation
		&"to_rotation": return to_rotation
		&"rotation_unit": return rotation_unit
		&"rotation_pivot_offset": return rotation_pivot_offset
		# Shared From/To
		&"from_reference": return from_reference
		&"to_reference": return to_reference
		&"from_target_node": return from_target_node
		&"to_target_node": return to_target_node
		&"capture_at": return capture_at
		# Scale (From/To model)
		&"from_scale": return from_scale
		&"to_scale": return to_scale
		# Scale pivot
		&"scale_pivot_mode": return scale_pivot_mode
		&"scale_custom_pivot": return scale_custom_pivot
	return null


# =============================================================================
# LIFECYCLE OVERRIDES
# =============================================================================

func _ready() -> void:
	super._ready()
	# All transform types now use From/To model — capture base early
	call_deferred("_capture_base")
	# If Self reference uses CaptureAt.READY, snapshot now (only if SELF is actually used)
	var uses_self := (from_reference == TransformReference.SELF or to_reference == TransformReference.SELF)
	if uses_self and capture_at == CaptureAt.READY:
		match transform_target:
			TransformTarget.POSITION:
				call_deferred("_capture_self_position_snapshot")
			TransformTarget.ROTATION:
				call_deferred("_capture_self_rotation_snapshot")
			TransformTarget.SCALE:
				call_deferred("_capture_self_scale_snapshot")


func _invalidate_base_cache() -> void:
	_has_base = false
	_scale_pivot_resolved = false
	_from_ref = null
	_to_ref = null
	_has_self_position_snapshot = false
	_has_self_rotation_snapshot = false
	_has_self_scale_snapshot = false
	_my_position_contribution = Vector3.ZERO
	_my_rotation_contribution = Vector3.ZERO
	_my_scale_contribution = Vector3.ZERO


func _get_interrupt_identity() -> Variant:
	return [get_script(), transform_target]


func _exit_tree() -> void:
	# Clean up our delta contribution if freed mid-animation
	if not is_instance_valid(_target_node) or not (_target_node is Node3D):
		return
	var n3d := _target_node as Node3D
	match transform_target:
		TransformTarget.POSITION:
			n3d.position -= _my_position_contribution
		TransformTarget.ROTATION:
			n3d.rotation -= _my_rotation_contribution
			if rotation_pivot_offset != Vector3.ZERO:
				n3d.position -= _my_position_contribution
		TransformTarget.SCALE:
			n3d.scale -= _my_scale_contribution
			if _scale_pivot_point != Vector3.ZERO:
				n3d.position -= _my_position_contribution
	_my_position_contribution = Vector3.ZERO
	_my_rotation_contribution = Vector3.ZERO
	_my_scale_contribution = Vector3.ZERO


func _on_animate_start() -> void:
	if not _has_base:
		_capture_base()

	# All transform types now use From/To model
	_resolve_from_to_refs()
	# Capture Self snapshot at trigger time (only if SELF is actually used)
	var uses_self := (from_reference == TransformReference.SELF or to_reference == TransformReference.SELF)
	if uses_self and capture_at == CaptureAt.TRIGGER:
		match transform_target:
			TransformTarget.POSITION:
				_capture_self_position_snapshot()
			TransformTarget.ROTATION:
				_capture_self_rotation_snapshot()
			TransformTarget.SCALE:
				_capture_self_scale_snapshot()

	# Resolve scale pivot if needed
	if transform_target == TransformTarget.SCALE and not _scale_pivot_resolved:
		_resolve_scale_pivot()
		_scale_pivot_resolved = true

	# Reset throttle tracker so each phase logs from the start
	_debug_last_logged_decile = -1

	if debug_enabled:
		var target_name: String = TransformTarget.keys()[transform_target]
		print("[%s] Transform start (3D, %s)" % [name, target_name])


func _apply_effect(progress: float) -> void:
	if not is_instance_valid(_target_node) or not (_target_node is Node3D):
		return

	var n3d := _target_node as Node3D

	match transform_target:
		TransformTarget.POSITION:
			_apply_position_effect(progress, n3d)
		TransformTarget.ROTATION:
			_apply_rotation_effect(progress, n3d)
		TransformTarget.SCALE:
			_apply_scale_effect(progress, n3d)


# =============================================================================
# POSITION EFFECT
# =============================================================================

## Apply position using From/To lerp model.
## Both From and To are resolved to world units, then interpolated.
func _apply_position_effect(progress: float, n3d: Node3D) -> void:
	var from_value := _resolve_from_position(n3d)
	var to_value := _resolve_to_position(n3d)
	var desired_absolute := from_value.lerp(to_value, progress)

	# Convert absolute position to delta from base (for delta-first write pattern)
	var desired_offset := desired_absolute - _base_position
	var delta := desired_offset - _my_position_contribution
	n3d.position += delta
	_my_position_contribution = desired_offset


## Resolve the From position to an absolute Vector3 in local space
func _resolve_from_position(animated: Node3D) -> Vector3:
	match from_reference:
		TransformReference.CUSTOM:
			return _base_position + _convert_to_world_units(from_position, from_position_in)
		TransformReference.SELF:
			return _self_position_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_position(_from_ref, animated)
			return _base_position
	return _base_position


## Resolve the To position to an absolute Vector3 in local space
func _resolve_to_position(animated: Node3D) -> Vector3:
	match to_reference:
		TransformReference.CUSTOM:
			return _base_position + _convert_to_world_units(to_position, to_position_in)
		TransformReference.SELF:
			return _self_position_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_position(_to_ref, animated)
			return _base_position
	return _base_position


## Convert a position value from its PositionIn3D unit to world units (offset)
func _convert_to_world_units(pos: Vector3, position_in: int) -> Vector3:
	match position_in:
		PositionIn3D.WORLD_UNITS:
			return pos
		PositionIn3D.FRACTION_OWN:
			var size := _infer_node3d_size(_target_node as Node3D)
			return Vector3(pos.x * size.x, pos.y * size.y, pos.z * size.z)
		PositionIn3D.FRACTION_PARENT:
			var size := _infer_parent_size()
			return Vector3(pos.x * size.x, pos.y * size.y, pos.z * size.z)
	return pos


## Convert a reference node's global position to the animated node's parent-local position
func _get_ref_local_position(ref: Node3D, animated: Node3D) -> Vector3:
	var parent := animated.get_parent()
	if parent is Node3D:
		return (parent as Node3D).global_transform.affine_inverse() * ref.global_position
	return ref.global_position


# =============================================================================
# ROTATION EFFECT (From/To with Quaternion slerp + pivot)
# =============================================================================

## Apply rotation using From/To model with Quaternion slerp.
## Supports pivot_offset for rotating around arbitrary points (e.g., door hinges).
## The pivot point is fixed in parent space at animation start.
func _apply_rotation_effect(progress: float, n3d: Node3D) -> void:
	var from_quat := _resolve_from_rotation_quat(n3d)
	var to_quat := _resolve_to_rotation_quat(n3d)
	var current_quat := from_quat.slerp(to_quat, progress)

	# Convert back to euler for delta-first application
	var desired_euler := Basis(current_quat).get_euler()
	var desired_offset := desired_euler - _base_euler
	var rot_delta := desired_offset - _my_rotation_contribution

	# Pivot compensation
	if rotation_pivot_offset != Vector3.ZERO:
		var new_basis := Basis(current_quat)
		var desired_pos := _fixed_pivot_parent - new_basis * rotation_pivot_offset
		var desired_pos_offset := desired_pos - _base_position
		var pos_delta := desired_pos_offset - _my_position_contribution
		n3d.position += pos_delta
		_my_position_contribution = desired_pos_offset

	# Apply rotation as euler delta (composable with other effects)
	n3d.rotation += rot_delta
	_my_rotation_contribution = desired_offset


## Resolve the From rotation to an absolute Quaternion in local space
func _resolve_from_rotation_quat(animated: Node3D) -> Quaternion:
	match from_reference:
		TransformReference.CUSTOM:
			var offset_rad := _rotation_to_radians(from_rotation)
			return _base_quat * Quaternion.from_euler(offset_rad)
		TransformReference.SELF:
			return Quaternion.from_euler(_self_rotation_snapshot)
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_rotation_quat(_from_ref, animated)
			return _base_quat
	return _base_quat


## Resolve the To rotation to an absolute Quaternion in local space
func _resolve_to_rotation_quat(animated: Node3D) -> Quaternion:
	match to_reference:
		TransformReference.CUSTOM:
			var offset_rad := _rotation_to_radians(to_rotation)
			return _base_quat * Quaternion.from_euler(offset_rad)
		TransformReference.SELF:
			return Quaternion.from_euler(_self_rotation_snapshot)
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_rotation_quat(_to_ref, animated)
			return _base_quat
	return _base_quat


## Convert a rotation Vector3 from configured rotation_unit to radians
func _rotation_to_radians(rot: Vector3) -> Vector3:
	if rotation_unit == RotationUnit.DEGREES:
		return Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))
	return rot


## Convert a reference node's global rotation to the animated node's parent-local Quaternion
func _get_ref_local_rotation_quat(ref: Node3D, animated: Node3D) -> Quaternion:
	var ref_global_basis := ref.global_transform.basis.orthonormalized()
	var parent_basis := Basis.IDENTITY
	if animated.get_parent() is Node3D:
		parent_basis = (animated.get_parent() as Node3D).global_transform.basis.orthonormalized()
	var local_basis := parent_basis.inverse() * ref_global_basis
	return Quaternion(local_basis)


# =============================================================================
# SCALE EFFECT (with pivot compensation)
# =============================================================================

## Apply scale using From/To lerp model with pivot compensation.
## Node3D has no native pivot property, so we adjust position:
##   pos += pivot * (ONE - scale_ratio)
func _apply_scale_effect(progress: float, n3d: Node3D) -> void:
	# Resolve absolute From and To values, then lerp between them
	var from_value := _resolve_from_scale(n3d)
	var to_value := _resolve_to_scale(n3d)
	var desired_absolute := from_value.lerp(to_value, progress)

	# Convert absolute scale to delta from base (for delta-first write pattern)
	var desired_offset := desired_absolute - _base_scale
	var scale_delta := desired_offset - _my_scale_contribution

	# Pivot compensation: adjust position so the pivot point stays stationary
	if _scale_pivot_point != Vector3.ZERO:
		var scale_ratio := desired_absolute / _base_scale
		var desired_pos_offset := _scale_pivot_point * (Vector3.ONE - scale_ratio)
		var pos_delta := desired_pos_offset - _my_position_contribution
		n3d.position += pos_delta
		_my_position_contribution = desired_pos_offset

	n3d.scale += scale_delta
	_my_scale_contribution = desired_offset

	# Throttle to ~10% progress milestones to avoid flooding debug buffer
	var scale_decile := int(progress * 10)
	if debug_enabled and scale_decile != _debug_last_logged_decile:
		_debug_last_logged_decile = scale_decile
		print("[%s] _apply_effect: progress=%.2f, scale=%s" % [name, progress, n3d.scale])


## Resolve the From scale value to an absolute Vector3 based on from_reference
func _resolve_from_scale(n3d: Node3D) -> Vector3:
	match from_reference:
		TransformReference.CUSTOM:
			return from_scale
		TransformReference.SELF:
			return _self_scale_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_scale(_from_ref, n3d)
			return _base_scale
	return _base_scale


## Resolve the To scale value to an absolute Vector3 based on to_reference
func _resolve_to_scale(n3d: Node3D) -> Vector3:
	match to_reference:
		TransformReference.CUSTOM:
			return to_scale
		TransformReference.SELF:
			return _self_scale_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_scale(_to_ref, n3d)
			return _base_scale
	return _base_scale


## Convert a reference node's global scale to the animated node's parent-local scale
func _get_ref_local_scale(ref: Node3D, animated: Node3D) -> Vector3:
	var ref_global_scale := ref.global_transform.basis.get_scale()
	var parent_scale := Vector3.ONE
	var parent := animated.get_parent()
	if parent is Node3D:
		parent_scale = (parent as Node3D).global_transform.basis.get_scale()
	return ref_global_scale / parent_scale


# =============================================================================
# FROM/TO REFERENCE RESOLUTION (shared by Position, Rotation, and Scale)
# =============================================================================

## Resolve from_target_node and to_target_node NodePaths to cached references.
## Called once per animation start for all From/To models.
func _resolve_from_to_refs() -> void:
	_from_ref = null
	_to_ref = null
	if from_reference == TransformReference.TARGET_NODE:
		_from_ref = _resolve_node_path_to_node3d(from_target_node, "from_target_node")
	if to_reference == TransformReference.TARGET_NODE:
		_to_ref = _resolve_node_path_to_node3d(to_target_node, "to_target_node")


## Capture Self's current rotation as a stable snapshot for use during animation.
## Called at the moment chosen by capture_at (READY or TRIGGER). Stores euler radians.
func _capture_self_rotation_snapshot() -> void:
	if _has_self_rotation_snapshot:
		return
	if _target_node is Node3D:
		_self_rotation_snapshot = (_target_node as Node3D).rotation
	else:
		_self_rotation_snapshot = Vector3.ZERO
	_has_self_rotation_snapshot = true
	if debug_enabled:
		print("[%s] Captured self rotation snapshot: %s" % [name, _self_rotation_snapshot])


## Capture Self's current position as a stable snapshot for use during animation.
## Called at the moment chosen by capture_at (READY or TRIGGER).
func _capture_self_position_snapshot() -> void:
	if _has_self_position_snapshot:
		return
	if _target_node is Node3D:
		_self_position_snapshot = (_target_node as Node3D).position
	else:
		_self_position_snapshot = Vector3.ZERO
	_has_self_position_snapshot = true
	if debug_enabled:
		print("[%s] Captured self position snapshot: %s" % [name, _self_position_snapshot])


## Capture Self's current scale as a stable snapshot for use during animation.
## Called at the moment chosen by capture_at (READY or TRIGGER).
func _capture_self_scale_snapshot() -> void:
	if _has_self_scale_snapshot:
		return
	if _target_node is Node3D:
		_self_scale_snapshot = (_target_node as Node3D).scale
	else:
		_self_scale_snapshot = Vector3.ONE
	_has_self_scale_snapshot = true
	if debug_enabled:
		print("[%s] Captured self scale snapshot: %s" % [name, _self_scale_snapshot])


## Helper: resolve a NodePath to a Node3D, with debug warnings on failure.
## Returns null if the path is empty, unresolvable, or not a Node3D.
func _resolve_node_path_to_node3d(path: NodePath, path_name: String) -> Node3D:
	if path.is_empty():
		return null
	var resolved := get_node_or_null(path)
	if resolved == null:
		if debug_enabled:
			push_warning("[%s] %s path '%s' could not be resolved" % [name, path_name, path])
		return null
	if not (resolved is Node3D):
		if debug_enabled:
			push_warning("[%s] %s '%s' is not a Node3D (is %s)" % [name, path_name, resolved.name, resolved.get_class()])
		return null
	if debug_enabled:
		print("[%s] Resolved %s: '%s'" % [name, path_name, resolved.name])
	return resolved as Node3D


# =============================================================================
# BASE CAPTURE
# =============================================================================

func _capture_base() -> void:
	if _has_base:
		return

	if not (_target_node is Node3D):
		if debug_enabled and _target_node != null:
			push_warning("[%s] Target '%s' is not Node3D" % [name, _target_node.name])
		_base_transform = Transform3D.IDENTITY
		_has_base = true
		return

	var n3d := _target_node as Node3D
	_base_position = n3d.position
	_base_transform = n3d.transform
	var ortho_basis := _base_transform.basis.orthonormalized()
	_base_euler = ortho_basis.get_euler()
	_base_quat = Quaternion(ortho_basis)
	_base_scale = n3d.scale

	# Pre-compute the fixed pivot position in parent space for rotation.
	# This is where the pivot point is at animation start — it stays fixed.
	_fixed_pivot_parent = _base_transform.origin + _base_transform.basis * rotation_pivot_offset

	_has_base = true

	if debug_enabled:
		print("[%s] Captured base: pos=%s, scale=%s" % [name, _base_position, _base_scale])


# =============================================================================
# SCALE PIVOT RESOLUTION
# =============================================================================

## Resolve the pivot point for scale based on scale_pivot_mode
func _resolve_scale_pivot() -> void:
	match scale_pivot_mode:
		PivotMode.AUTO_CENTER:
			# Compute the visual center of the target in local space.
			# Node3D content (MeshInstance3D, shapes, etc.) is typically centered at origin,
			# so the center is often (0,0,0) — meaning no position compensation.
			if _target_node is Node3D:
				var n3d := _target_node as Node3D
				var bounds := _infer_node3d_local_bounds(n3d)
				if bounds.size == Vector3.ZERO:
					bounds = _infer_node3d_bounds_recursive(n3d)
				if bounds.size != Vector3.ZERO:
					_scale_pivot_point = bounds.get_center()
				else:
					_scale_pivot_point = Vector3.ZERO
				if debug_enabled:
					print("[%s] Auto-center scale pivot: bounds=%s, center=%s" % [name, bounds, _scale_pivot_point])
			else:
				_scale_pivot_point = Vector3.ZERO
		PivotMode.INHERIT:
			_scale_pivot_point = Vector3.ZERO
		PivotMode.CUSTOM:
			_scale_pivot_point = scale_custom_pivot


# =============================================================================
# SIZE INFERENCE (shared between position offset units and scale pivot)
# =============================================================================

func _infer_parent_size() -> Vector3:
	if _target_node == null:
		return Vector3.ZERO
	var parent := _target_node.get_parent()
	if parent is Node3D:
		return _infer_node3d_size(parent as Node3D)
	return Vector3.ZERO


func _infer_node3d_size(node: Node3D) -> Vector3:
	if node == null:
		return Vector3.ZERO

	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var aabb := mi.mesh.get_aabb()
			var sc := mi.global_transform.basis.get_scale()
			return Vector3(absf(sc.x) * aabb.size.x, absf(sc.y) * aabb.size.y, absf(sc.z) * aabb.size.z)

	if node is CollisionShape3D:
		var col := node as CollisionShape3D
		if col.shape != null:
			var shape := col.shape
			if shape is BoxShape3D:
				return (shape as BoxShape3D).size
			if shape is SphereShape3D:
				var r := (shape as SphereShape3D).radius
				return Vector3(r * 2.0, r * 2.0, r * 2.0)
			if shape is CapsuleShape3D:
				var cap := shape as CapsuleShape3D
				return Vector3(cap.radius * 2.0, cap.height + cap.radius * 2.0, cap.radius * 2.0)

	if node.has_method("get_aabb"):
		var aabb_var: Variant = node.call("get_aabb")
		if aabb_var is AABB:
			var aabb := aabb_var as AABB
			var sc := node.global_transform.basis.get_scale()
			return Vector3(absf(sc.x) * aabb.size.x, absf(sc.y) * aabb.size.y, absf(sc.z) * aabb.size.z)

	# Container fallback: bounding box from children
	var bounds := _infer_node3d_bounds_recursive(node)
	if bounds.size != Vector3.ZERO:
		return bounds.size

	if debug_enabled:
		push_warning("[%s] Cannot infer Node3D size on '%s' (%s)" % [name, node.name, node.get_class()])
	return Vector3.ZERO


func _infer_node3d_bounds_recursive(root: Node3D) -> AABB:
	var has_any: bool = false
	var combined := AABB(Vector3.ZERO, Vector3.ZERO)

	for child in root.get_children():
		if not (child is Node3D):
			continue
		var child_n3d := child as Node3D
		var child_local := _infer_node3d_local_bounds(child_n3d)
		if child_local.size != Vector3.ZERO:
			child_local.position += child_n3d.position
			if not has_any:
				has_any = true
				combined = child_local
			else:
				combined = combined.merge(child_local)

		var grandchild_bounds := _infer_node3d_bounds_recursive(child_n3d)
		if grandchild_bounds.size != Vector3.ZERO:
			grandchild_bounds.position += child_n3d.position
			if not has_any:
				has_any = true
				combined = grandchild_bounds
			else:
				combined = combined.merge(grandchild_bounds)

	if not has_any:
		return AABB(Vector3.ZERO, Vector3.ZERO)
	return combined


func _infer_node3d_local_bounds(node: Node3D) -> AABB:
	var size := Vector3.ZERO

	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var aabb := mi.mesh.get_aabb()
			var sc := mi.transform.basis.get_scale()
			size = Vector3(absf(sc.x) * aabb.size.x, absf(sc.y) * aabb.size.y, absf(sc.z) * aabb.size.z)

	elif node is CollisionShape3D:
		var col := node as CollisionShape3D
		if col.shape != null:
			var shape := col.shape
			if shape is BoxShape3D:
				size = (shape as BoxShape3D).size
			elif shape is SphereShape3D:
				var r := (shape as SphereShape3D).radius
				size = Vector3(r * 2.0, r * 2.0, r * 2.0)
			elif shape is CapsuleShape3D:
				var cap := shape as CapsuleShape3D
				size = Vector3(cap.radius * 2.0, cap.height + cap.radius * 2.0, cap.radius * 2.0)

	elif node.has_method("get_aabb"):
		var aabb_var: Variant = node.call("get_aabb")
		if aabb_var is AABB:
			var aabb := aabb_var as AABB
			var sc := node.transform.basis.get_scale()
			size = Vector3(absf(sc.x) * aabb.size.x, absf(sc.y) * aabb.size.y, absf(sc.z) * aabb.size.z)

	if size == Vector3.ZERO:
		return AABB(Vector3.ZERO, Vector3.ZERO)

	# Local bounds centered on the node origin
	return AABB(-size * 0.5, size)


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var target := get_parent()
	if target and not target is Node3D:
		warnings.append("Transform3DJuiceComp requires a Node3D parent. Current parent is: " + target.get_class())
	# From/To: warn if both reference Self (no visible effect)
	if from_reference == TransformReference.SELF and to_reference == TransformReference.SELF:
		warnings.append("Both From and To reference Self \u2014 animation will have no visible effect.")
	return warnings


# =============================================================================
# SEQUENCER RECIPE CONTRACT
# =============================================================================

func _recipe_capture_natural(target: Node) -> Variant:
	if target is Node3D:
		var n3d := target as Node3D
		match transform_target:
			TransformTarget.POSITION:
				return {"position": n3d.position}
			TransformTarget.ROTATION:
				# Rotation needs full transform for Quaternion + pivot
				return {"transform": n3d.transform}
			TransformTarget.SCALE:
				# Scale with pivot needs position too for compensation
				return {"scale": n3d.scale, "position": n3d.position}
	return null


func _recipe_apply_natural(_target: Node, natural: Variant) -> void:
	if not (natural is Dictionary):
		return
	var dict := natural as Dictionary

	match transform_target:
		TransformTarget.POSITION:
			_base_position = dict.get("position", Vector3.ZERO) as Vector3
			# Reset self snapshot so it gets re-captured for this target
			_has_self_position_snapshot = false
		TransformTarget.ROTATION:
			_base_transform = dict.get("transform", Transform3D.IDENTITY) as Transform3D
			_base_position = _base_transform.origin
			# Re-compute fixed pivot
			_fixed_pivot_parent = _base_transform.origin + _base_transform.basis * rotation_pivot_offset
			# Reset self snapshot so it gets re-captured for this target
			_has_self_rotation_snapshot = false
		TransformTarget.SCALE:
			_base_scale = dict.get("scale", Vector3.ONE) as Vector3
			_base_position = dict.get("position", Vector3.ZERO) as Vector3
			# Reset self snapshot so it gets re-captured for this target
			_has_self_scale_snapshot = false

	_has_base = true
	_scale_pivot_resolved = false


func _recipe_restore_natural(target: Node, natural: Variant) -> void:
	if not (natural is Dictionary) or not (target is Node3D):
		return
	var dict := natural as Dictionary
	var n3d := target as Node3D

	match transform_target:
		TransformTarget.POSITION:
			n3d.position = dict.get("position", Vector3.ZERO) as Vector3
		TransformTarget.ROTATION:
			n3d.transform = dict.get("transform", Transform3D.IDENTITY) as Transform3D
		TransformTarget.SCALE:
			n3d.scale = dict.get("scale", Vector3.ONE) as Vector3
			n3d.position = dict.get("position", Vector3.ZERO) as Vector3
