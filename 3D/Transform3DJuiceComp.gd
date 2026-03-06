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
# - ROTATION: Animates Node3D rotation with Vector3 offset (degrees/radians).
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
# TRANSFORM TARGET NODE (optional):
# When transform_target_node points to a Node3D node, manual offset fields are
# ignored. Instead, the offset is computed per-frame from the animated node's
# base transform to the target node's current global transform. Supports moving targets.
# For ROTATION in target mode, quaternion slerp is used instead of euler deltas,
# which correctly handles rotations >180° with no gimbal lock.
#
# CONDITIONAL EXPORTS:
# Changing transform_target triggers notify_property_list_changed() which
# shows/hides the relevant parameters via _get_property_list().
# ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBaseControl.svg")
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

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — they are shown/hidden via _get_property_list()
# =============================================================================

# --- POSITION ---
## Offset to apply at progress=1.0
var position_offset: Vector3 = Vector3(0, 1, 0)
## How to interpret the offset values
var position_offset_unit: int = OffsetUnit3D.WORLD_UNITS

# --- ROTATION ---
## How much to rotate when animated in (degrees on each axis)
var rotation_offset: Vector3 = Vector3(0, 90, 0)
## Unit for rotation values (degrees is more intuitive for most users)
var rotation_unit: int = RotationUnit.DEGREES
## Pivot point offset from node origin (local space).
## Rotation appears to happen around this point.
## Useful for doors (hinge), levers (base), lids (back edge).
var rotation_pivot_offset: Vector3 = Vector3.ZERO

# --- TRANSFORM TARGET NODE ---
## Optional: drag a Node3D here to animate TOWARD its transform.
## When set, manual offset fields are ignored — offset is computed per-frame
## from the animated node's base to the target node's current global transform.
## For ROTATION, quaternion slerp replaces euler deltas in target mode.
var transform_target_node: NodePath

# --- SCALE ---
## How much to change scale at progress=1.0 (added to base scale)
var scale_offset: Vector3 = Vector3(0.1, 0.1, 0.1)
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

## Resolved reference to the transform target node (cached at animation start)
var _target_ref: Node3D = null
## Whether to use target node offset instead of manual offset
var _use_target_node: bool = false


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# Transform target node slot — always visible, type-safe to Node3D only
	props.append({
		"name": "transform_target_node",
		"type": TYPE_NODE_PATH,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		"hint_string": "Node3D",
	})

	match transform_target:
		TransformTarget.POSITION:
			props.append({
				"name": "position_offset",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})
			props.append({
				"name": "position_offset_unit",
				"type": TYPE_INT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "World Units,Fraction Own,Fraction Parent",
			})

		TransformTarget.ROTATION:
			props.append({
				"name": "rotation_offset",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})
			props.append({
				"name": "rotation_unit",
				"type": TYPE_INT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Degrees,Radians",
			})
			props.append({
				"name": "rotation_pivot_offset",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})

		TransformTarget.SCALE:
			props.append({
				"name": "scale_offset",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})
			props.append({
				"name": "scale_pivot_mode",
				"type": TYPE_INT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Auto Center,Inherit,Custom",
			})
			# Only show scale_custom_pivot input when scale_pivot_mode is CUSTOM
			if scale_pivot_mode == PivotMode.CUSTOM:
				props.append({
					"name": "scale_custom_pivot",
					"type": TYPE_VECTOR3,
					"usage": PROPERTY_USAGE_DEFAULT,
					"hint": PROPERTY_HINT_NONE,
				})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		# Position
		&"position_offset": position_offset = value; return true
		&"position_offset_unit": position_offset_unit = value; return true
		# Rotation
		&"rotation_offset": rotation_offset = value; return true
		&"rotation_unit": rotation_unit = value; return true
		&"rotation_pivot_offset": rotation_pivot_offset = value; return true
		# Scale
		&"scale_offset": scale_offset = value; return true
		&"scale_pivot_mode": scale_pivot_mode = value; return true
		&"scale_custom_pivot": scale_custom_pivot = value; return true
		# Transform target node
		&"transform_target_node": transform_target_node = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		# Position
		&"position_offset": return position_offset
		&"position_offset_unit": return position_offset_unit
		# Rotation
		&"rotation_offset": return rotation_offset
		&"rotation_unit": return rotation_unit
		&"rotation_pivot_offset": return rotation_pivot_offset
		# Scale
		&"scale_offset": return scale_offset
		&"scale_pivot_mode": return scale_pivot_mode
		&"scale_custom_pivot": return scale_custom_pivot
		# Transform target node
		&"transform_target_node": return transform_target_node
	return null


# =============================================================================
# LIFECYCLE OVERRIDES
# =============================================================================

func _ready() -> void:
	super._ready()
	if transform_target == TransformTarget.SCALE:
		call_deferred("_capture_base")


func _invalidate_base_cache() -> void:
	_has_base = false
	_scale_pivot_resolved = false
	_use_target_node = false
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

	# Resolve transform target node if path is set
	_resolve_transform_target()

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

func _apply_position_effect(progress: float, n3d: Node3D) -> void:
	var actual_offset: Vector3
	if _use_target_node and is_instance_valid(_target_ref):
		actual_offset = _compute_target_position_offset(n3d)
	else:
		actual_offset = _calculate_position_offset()
	var desired := actual_offset * progress
	var delta := desired - _my_position_contribution
	n3d.position += delta
	_my_position_contribution = desired


## Resolve position offset using the configured unit
func _calculate_position_offset() -> Vector3:
	match position_offset_unit:
		OffsetUnit3D.WORLD_UNITS:
			return position_offset
		OffsetUnit3D.FRACTION_OWN:
			var size := _infer_node3d_size(_target_node as Node3D)
			return Vector3(position_offset.x * size.x, position_offset.y * size.y, position_offset.z * size.z)
		OffsetUnit3D.FRACTION_PARENT:
			var size := _infer_parent_size()
			return Vector3(position_offset.x * size.x, position_offset.y * size.y, position_offset.z * size.z)
	return position_offset


# =============================================================================
# ROTATION EFFECT (Quaternion slerp with Transform3D pivot)
# =============================================================================

## Apply rotation using Quaternion math. Supports pivot_offset for rotating
## around arbitrary points (e.g., door hinges). The pivot point is fixed in
## parent space at animation start so it doesn't drift during the animation.
func _apply_rotation_effect(progress: float, n3d: Node3D) -> void:
	# Target node mode: use quaternion slerp (handles >180°, no gimbal lock)
	if _use_target_node and is_instance_valid(_target_ref):
		_apply_rotation_to_target(progress, n3d)
		return

	# Manual offset mode: euler deltas (existing logic)
	var offset_rad := _get_rotation_offset_radians()

	# Desired euler offset at this progress
	var desired_rot := offset_rad * progress
	var rot_delta := desired_rot - _my_rotation_contribution

	if rotation_pivot_offset != Vector3.ZERO:
		# Pivot compensation: position depends on the full rotation.
		# Use quaternion math to compute exact pivot-compensated position,
		# then write position as a delta.
		var rotation_quat := Quaternion.from_euler(desired_rot)
		var base_quat := _base_transform.basis.get_rotation_quaternion()
		var target_quat := base_quat * rotation_quat
		var new_basis := Basis(target_quat)
		var desired_pos := _fixed_pivot_parent - new_basis * rotation_pivot_offset
		var desired_pos_offset := desired_pos - _base_position
		var pos_delta := desired_pos_offset - _my_position_contribution
		n3d.position += pos_delta
		_my_position_contribution = desired_pos_offset

	# Apply rotation as euler delta (composable with other effects)
	n3d.rotation += rot_delta
	_my_rotation_contribution = desired_rot

	# Throttle to ~10% progress milestones to avoid flooding debug buffer
	var decile := int(progress * 10)
	if debug_enabled and decile != _debug_last_logged_decile:
		_debug_last_logged_decile = decile
		print("[%s] _apply_effect: progress=%.2f, rotation=%s" % [
			name, progress, n3d.rotation_degrees])


## Convert configured rotation offset to radians
func _get_rotation_offset_radians() -> Vector3:
	if rotation_unit == RotationUnit.DEGREES:
		return Vector3(
			deg_to_rad(rotation_offset.x),
			deg_to_rad(rotation_offset.y),
			deg_to_rad(rotation_offset.z)
		)
	else:
		return rotation_offset


# =============================================================================
# SCALE EFFECT (with pivot compensation)
# =============================================================================

## Apply scale with pivot compensation. Node3D has no native pivot property,
## so we adjust position: pos += pivot * (ONE - scale_ratio).
func _apply_scale_effect(progress: float, n3d: Node3D) -> void:
	var actual_scale_offset: Vector3
	if _use_target_node and is_instance_valid(_target_ref):
		actual_scale_offset = _compute_target_scale_offset(n3d)
	else:
		actual_scale_offset = scale_offset
	var desired_scale_offset := actual_scale_offset * progress
	var scale_delta := desired_scale_offset - _my_scale_contribution

	# Pivot compensation: adjust position so the pivot point stays stationary
	if _scale_pivot_point != Vector3.ZERO:
		var target_scale := _base_scale + desired_scale_offset
		var scale_ratio := target_scale / _base_scale
		var desired_pos_offset := _scale_pivot_point * (Vector3.ONE - scale_ratio)
		var pos_delta := desired_pos_offset - _my_position_contribution
		n3d.position += pos_delta
		_my_position_contribution = desired_pos_offset

	n3d.scale += scale_delta
	_my_scale_contribution = desired_scale_offset

	# Throttle to ~10% progress milestones to avoid flooding debug buffer
	var scale_decile := int(progress * 10)
	if debug_enabled and scale_decile != _debug_last_logged_decile:
		_debug_last_logged_decile = scale_decile
		print("[%s] _apply_effect: progress=%.2f, scale=%s" % [name, progress, n3d.scale])


# =============================================================================
# TRANSFORM TARGET NODE — RESOLUTION & PER-FRAME OFFSET COMPUTATION
# =============================================================================

## Resolve the transform_target_node NodePath to a cached node reference.
## Called once per animation start. Per-frame validity is checked in _apply_*_effect.
func _resolve_transform_target() -> void:
	_use_target_node = false
	_target_ref = null
	if transform_target_node.is_empty():
		return
	var resolved := get_node_or_null(transform_target_node)
	if resolved == null:
		if debug_enabled:
			push_warning("[%s] transform_target_node path '%s' could not be resolved" % [name, transform_target_node])
		return
	if not (resolved is Node3D):
		if debug_enabled:
			push_warning("[%s] transform_target_node '%s' is not a Node3D (is %s)" % [name, resolved.name, resolved.get_class()])
		return
	if resolved == _target_node:
		if debug_enabled:
			push_warning("[%s] transform_target_node points to self — offset will be zero" % [name])
	_target_ref = resolved as Node3D
	_use_target_node = true
	if debug_enabled:
		print("[%s] Resolved transform target: '%s'" % [name, resolved.name])


## Compute position offset: target's global position converted to animated node's parent space,
## minus the base position. Recomputed every frame to support moving targets.
func _compute_target_position_offset(n3d: Node3D) -> Vector3:
	var parent := n3d.get_parent()
	var target_in_parent: Vector3
	if parent is Node3D:
		target_in_parent = (parent as Node3D).global_transform.affine_inverse() * _target_ref.global_position
	else:
		target_in_parent = _target_ref.global_position
	return target_in_parent - _base_position


## Apply rotation toward target using quaternion slerp. Handles rotations >180°
## correctly with no gimbal lock. Converts result back to euler for the delta-first
## write pattern so it remains composable with other effects.
func _apply_rotation_to_target(progress: float, n3d: Node3D) -> void:
	# Base rotation quaternion (local space, captured at animation start)
	var base_basis := _base_transform.basis.orthonormalized()
	var base_quat := Quaternion(base_basis)

	# Target's rotation converted to animated node's parent (local) space
	var target_global_basis := _target_ref.global_transform.basis.orthonormalized()
	var parent_basis := Basis.IDENTITY
	if n3d.get_parent() is Node3D:
		parent_basis = (n3d.get_parent() as Node3D).global_transform.basis.orthonormalized()
	var target_local_basis := parent_basis.inverse() * target_global_basis
	var target_quat := Quaternion(target_local_basis)

	# Slerp from base to target at current progress
	var current_quat := base_quat.slerp(target_quat, progress)

	# Convert back to euler for delta-first application
	var desired_euler := Basis(current_quat).get_euler()
	var base_euler := base_basis.get_euler()
	var desired_offset := desired_euler - base_euler
	var rot_delta := desired_offset - _my_rotation_contribution

	# Pivot compensation (if configured)
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

	# Throttle debug to ~10% progress milestones
	var decile := int(progress * 10)
	if debug_enabled and decile != _debug_last_logged_decile:
		_debug_last_logged_decile = decile
		print("[%s] _apply_rotation_to_target: progress=%.2f, rotation=%s" % [
			name, progress, n3d.rotation_degrees])


## Compute scale offset: target's global scale converted to parent-local scale,
## minus the base scale.
func _compute_target_scale_offset(n3d: Node3D) -> Vector3:
	var target_global_scale := _target_ref.global_transform.basis.get_scale()
	var parent_scale := Vector3.ONE
	var parent := n3d.get_parent()
	if parent is Node3D:
		parent_scale = (parent as Node3D).global_transform.basis.get_scale()
	var desired_local := target_global_scale / parent_scale
	return desired_local - _base_scale


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
		TransformTarget.ROTATION:
			_base_transform = dict.get("transform", Transform3D.IDENTITY) as Transform3D
			_base_position = _base_transform.origin
			# Re-compute fixed pivot
			_fixed_pivot_parent = _base_transform.origin + _base_transform.basis * rotation_pivot_offset
		TransformTarget.SCALE:
			_base_scale = dict.get("scale", Vector3.ONE) as Vector3
			_base_position = dict.get("position", Vector3.ZERO) as Vector3

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
