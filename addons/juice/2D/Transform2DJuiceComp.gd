## Transform2DJuiceComp.gd
## ============================================================================
## WHAT: Consolidated deterministic transform effect for Node2D nodes. Combines
##       position, rotation, and scale animation into a single component with a
##       TransformTarget selector. Uses _get_property_list() to conditionally
##       show only relevant exports in the inspector.
## WHY: Replaces 3 separate scripts (Position2DJuiceComp, Rotation2DJuiceComp,
##      Scale2DJuiceComp) with one unified component, reducing file count and
##      ensuring consistent behavior across transform types.
##
## WRITE PATTERN: Delta-first. Each frame writes only the CHANGE in this comp's
##   contribution: node.property += (desired - _my_contribution). This enables
##   stacking with other effects and preserves external changes to the node.
## SYSTEM: Juicing System (addons/juice/) - 2D Domain
## DOES NOT: Handle Control or Node3D targets (use TransformControl/Transform3D).
## DOES NOT: Handle procedural effects like shake or noise (use Shake/Noise comps).
## DOES NOT: Handle arbitrary property animation (use PropertyShake/PropertyNoise).
## ============================================================================
##
## TRANSFORM TARGETS:
## - POSITION: Animates Node2D.position with Vector2 offset + OffsetUnit system.
##   Supports PIXELS, FRACTION_OWN, FRACTION_PARENT, FRACTION_VIEWPORT units.
##   Uses size inference (Sprite2D, AnimatedSprite2D, CollisionShape2D, Polygon2D,
##   recursive child bounds) for fraction-based offset resolution.
## - ROTATION: Animates Node2D.rotation with float offset (degrees) + pivot mode.
##   Node2D lacks native pivot_offset, so pivot is achieved by position
##   compensation: fixed_pivot = base_pos + pivot.rotated(base_rot),
##   new_pos = fixed_pivot - pivot.rotated(new_rot).
## - SCALE: Animates Node2D.scale with Vector2 offset + pivot mode.
##   Pivot compensation via: pos += pivot * (ONE - scale_ratio).
##
## PIVOT (ROTATION and SCALE only):
## - AUTO_CENTER: Infers visual center from Sprite2D/CollisionShape2D/etc.
##   Node2D content is typically centered at origin, so center is often (0,0).
## - INHERIT: No position compensation (rotate/scale from node origin).
## - CUSTOM: User-specified local-space pivot point (pixels).
##
## TRANSFORM TARGET NODE (optional):
## When transform_target_node points to a Node2D node, manual offset fields are
## ignored. Instead, the offset is computed per-frame from the animated node's
## base transform to the target node's current global transform. Supports moving targets.
##
## CONDITIONAL EXPORTS:
## Changing transform_target triggers notify_property_list_changed() which
## shows/hides the relevant parameters via _get_property_list(). Properties
## added this way appear AFTER all @export properties in the inspector.
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBase2D.svg")
class_name Transform2DJuiceComp
extends JuiceCompBase

# =============================================================================
# TRANSFORM TARGET SELECTION
# =============================================================================

## Which transform property to animate
enum TransformTarget {
	POSITION,  ## Animate Node2D.position with offset + unit
	ROTATION,  ## Animate Node2D.rotation (single-axis Z, degrees)
	SCALE      ## Animate Node2D.scale with offset
}

@export var transform_target: TransformTarget = TransformTarget.POSITION:
	set(value):
		transform_target = value
		notify_property_list_changed()

# =============================================================================
# PIVOT MODE (shown for ROTATION and SCALE only, via _get_property_list)
# =============================================================================

## Determines how the pivot point is calculated
enum PivotMode {
	AUTO_CENTER,  ## Infer visual center and compensate position (most common)
	INHERIT,      ## Rotate/scale from node origin (no compensation)
	CUSTOM        ## Rotate/scale from custom_pivot (local-space pixels)
}

## Reference type for Scale From/To axes
enum ScaleReference {
	CUSTOM,       ## Explicit scale value (Vector2)
	SELF,         ## This object's current scale (captured at capture_at moment)
	TARGET_NODE   ## Another object's scale (tracked live every frame)
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

# --- POSITION ---
## Offset to apply at progress=1.0. For fraction units, 0.5 = 50%.
var position_offset: Vector2 = Vector2(-50, 0)
## How to interpret the offset values
var position_offset_unit: int = OffsetUnit.FRACTION_OWN

# --- ROTATION ---
## Rotation offset in degrees applied at progress=1.0
var rotation_offset_degrees: float = 15.0

# --- SCALE (From/To model) ---
## Reference type for the From axis of the scale animation
var from_reference: int = ScaleReference.CUSTOM:
	set(value):
		from_reference = value
		notify_property_list_changed()
## Reference type for the To axis of the scale animation
var to_reference: int = ScaleReference.SELF:
	set(value):
		to_reference = value
		notify_property_list_changed()
## Custom From scale value (shown when from_reference == CUSTOM)
var from_scale: Vector2 = Vector2.ZERO
## Custom To scale value (shown when to_reference == CUSTOM)
var to_scale: Vector2 = Vector2.ONE
## Target node for From reference (shown when from_reference == TARGET_NODE)
var from_target_node: NodePath
## Target node for To reference (shown when to_reference == TARGET_NODE)
var to_target_node: NodePath
## When to capture Self's scale (shown inside From/To group when reference == SELF)
var capture_at: int = CaptureAt.TRIGGER

# --- TRANSFORM TARGET NODE (used by POSITION and ROTATION — old model) ---
## Optional: drag a Node2D here to animate TOWARD its transform.
## When set, manual offset fields are ignored — offset is computed per-frame
## from the animated node's base to the target node's current global transform.
var transform_target_node: NodePath

# --- PIVOT (ROTATION + SCALE) ---
var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()
## Custom pivot in local-space coordinates (pixels)
var custom_pivot: Vector2 = Vector2.ZERO

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _base_position: Vector2 = Vector2.ZERO
var _base_rotation_radians: float = 0.0
var _base_scale: Vector2 = Vector2.ONE

## Whether base has been captured
var _has_base: bool = false

## Resolved pivot point in target's local space (for rotation/scale)
var _pivot_point: Vector2 = Vector2.ZERO
var _pivot_resolved: bool = false

## Fixed pivot position in parent space (pre-computed at animation start for rotation)
var _fixed_pivot_parent: Vector2 = Vector2.ZERO

## Delta-first contribution tracking.
## Each tracks what THIS comp has contributed to the node's property.
## On each frame: delta = desired - contribution; node.prop += delta.
## On cleanup: node.prop -= contribution.
var _my_position_contribution: Vector2 = Vector2.ZERO
var _my_rotation_contribution: float = 0.0
var _my_scale_contribution: Vector2 = Vector2.ZERO

## Resolved reference to the transform target node (cached at animation start)
## Used by POSITION and ROTATION (old offset model)
var _target_ref: Node2D = null
## Whether to use target node offset instead of manual offset (POSITION/ROTATION)
var _use_target_node: bool = false

## Resolved references for Scale From/To target nodes (cached at animation start)
var _from_ref: Node2D = null
var _to_ref: Node2D = null
## Self scale snapshot — captured once at the moment chosen by capture_at
var _self_scale_snapshot: Vector2 = Vector2.ONE
var _has_self_scale_snapshot: bool = false


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	match transform_target:
		TransformTarget.POSITION:
			# Position still uses old offset model (Phase 2 will upgrade)
			props.append({
				"name": "transform_target_node",
				"type": TYPE_NODE_PATH,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
				"hint_string": "Node2D",
			})
			props.append({
				"name": "position_offset",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})
			props.append({
				"name": "position_offset_unit",
				"type": TYPE_INT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Pixels,Fraction Own,Fraction Parent,Fraction Viewport",
			})

		TransformTarget.ROTATION:
			# Rotation still uses old offset model (Phase 3 will upgrade)
			props.append({
				"name": "transform_target_node",
				"type": TYPE_NODE_PATH,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
				"hint_string": "Node2D",
			})
			props.append({
				"name": "rotation_offset_degrees",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})
			props.append_array(_get_pivot_properties())

		TransformTarget.SCALE:
			props.append_array(_get_scale_from_to_properties())
			props.append_array(_get_pivot_properties())

	return props


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

	if from_reference == ScaleReference.CUSTOM:
		scale_props.append({
			"name": "from_scale",
			"type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif from_reference == ScaleReference.SELF:
		scale_props.append({
			"name": "capture_at",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready",
		})
	elif from_reference == ScaleReference.TARGET_NODE:
		scale_props.append({
			"name": "from_target_node",
			"type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D",
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

	if to_reference == ScaleReference.CUSTOM:
		scale_props.append({
			"name": "to_scale",
			"type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif to_reference == ScaleReference.SELF:
		scale_props.append({
			"name": "capture_at",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready",
		})
	elif to_reference == ScaleReference.TARGET_NODE:
		scale_props.append({
			"name": "to_target_node",
			"type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D",
		})

	return scale_props


## Shared pivot properties used by both ROTATION and SCALE targets
func _get_pivot_properties() -> Array[Dictionary]:
	var pivot_props: Array[Dictionary] = [
		{
			"name": "pivot_mode",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Auto Center,Inherit,Custom",
		},
	]
	# Only show custom_pivot input when pivot_mode is CUSTOM
	if pivot_mode == PivotMode.CUSTOM:
		pivot_props.append({
			"name": "custom_pivot",
			"type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE,
		})
	return pivot_props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		# Position (old model)
		&"position_offset": position_offset = value; return true
		&"position_offset_unit": position_offset_unit = value; return true
		# Rotation (old model)
		&"rotation_offset_degrees": rotation_offset_degrees = value; return true
		# Scale (From/To model)
		&"from_reference": from_reference = value; return true
		&"to_reference": to_reference = value; return true
		&"from_scale": from_scale = value; return true
		&"to_scale": to_scale = value; return true
		&"from_target_node": from_target_node = value; return true
		&"to_target_node": to_target_node = value; return true
		&"capture_at": capture_at = value; return true
		# Legacy: old scenes may have scale_offset — accept but ignore
		&"scale_offset": return true
		# Pivot
		&"pivot_mode": pivot_mode = value; return true
		&"custom_pivot": custom_pivot = value; return true
		# Transform target node (position/rotation old model)
		&"transform_target_node": transform_target_node = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		# Position (old model)
		&"position_offset": return position_offset
		&"position_offset_unit": return position_offset_unit
		# Rotation (old model)
		&"rotation_offset_degrees": return rotation_offset_degrees
		# Scale (From/To model)
		&"from_reference": return from_reference
		&"to_reference": return to_reference
		&"from_scale": return from_scale
		&"to_scale": return to_scale
		&"from_target_node": return from_target_node
		&"to_target_node": return to_target_node
		&"capture_at": return capture_at
		# Pivot
		&"pivot_mode": return pivot_mode
		&"custom_pivot": return custom_pivot
		# Transform target node (position/rotation old model)
		&"transform_target_node": return transform_target_node
	return null


# =============================================================================
# LIFECYCLE OVERRIDES
# =============================================================================

func _ready() -> void:
	super._ready()
	if transform_target == TransformTarget.SCALE:
		call_deferred("_capture_base")
		# If Self reference uses CaptureAt.READY, snapshot scale now
		if capture_at == CaptureAt.READY:
			call_deferred("_capture_self_scale_snapshot")


func _invalidate_base_cache() -> void:
	_has_base = false
	_pivot_resolved = false
	_use_target_node = false
	_from_ref = null
	_to_ref = null
	_has_self_scale_snapshot = false
	_my_position_contribution = Vector2.ZERO
	_my_rotation_contribution = 0.0
	_my_scale_contribution = Vector2.ZERO


func _get_interrupt_identity() -> Variant:
	return [get_script(), transform_target]


func _exit_tree() -> void:
	# Clean up our delta contribution if freed mid-animation
	var target := _get_target_node2d()
	if target == null:
		return
	match transform_target:
		TransformTarget.POSITION:
			target.position -= _my_position_contribution
		TransformTarget.ROTATION:
			target.rotation -= _my_rotation_contribution
			if _pivot_point != Vector2.ZERO:
				target.position -= _my_position_contribution
		TransformTarget.SCALE:
			target.scale -= _my_scale_contribution
			if _pivot_point != Vector2.ZERO:
				target.position -= _my_position_contribution
	_my_position_contribution = Vector2.ZERO
	_my_rotation_contribution = 0.0
	_my_scale_contribution = Vector2.ZERO


func _on_animate_start() -> void:
	if not _has_base:
		_capture_base()

	match transform_target:
		TransformTarget.POSITION, TransformTarget.ROTATION:
			# Position/Rotation still use old offset model
			_resolve_transform_target()
		TransformTarget.SCALE:
			# Scale uses new From/To model — resolve reference nodes
			_resolve_scale_refs()
			# Capture Self snapshot at trigger time if configured
			if capture_at == CaptureAt.TRIGGER:
				_capture_self_scale_snapshot()

	# Resolve pivot for rotation/scale targets
	if transform_target != TransformTarget.POSITION and not _pivot_resolved:
		_resolve_pivot()
		_pivot_resolved = true

	# Pre-compute fixed pivot in parent space for rotation
	if transform_target == TransformTarget.ROTATION:
		_fixed_pivot_parent = _base_position + _pivot_point.rotated(_base_rotation_radians)

	if debug_enabled:
		var target_name: String = TransformTarget.keys()[transform_target]
		print("[%s] Transform start (2D, %s)" % [name, target_name])


func _apply_effect(progress: float) -> void:
	var target := _get_target_node2d()
	if target == null:
		return

	match transform_target:
		TransformTarget.POSITION:
			_apply_position_effect(progress, target)
		TransformTarget.ROTATION:
			_apply_rotation_effect(progress, target)
		TransformTarget.SCALE:
			_apply_scale_effect(progress, target)


# =============================================================================
# POSITION EFFECT
# =============================================================================

func _apply_position_effect(progress: float, target: Node2D) -> void:
	var actual_offset: Vector2
	if _use_target_node and is_instance_valid(_target_ref):
		actual_offset = _compute_target_position_offset(target)
	else:
		actual_offset = _calculate_position_offset()
	var desired := actual_offset * progress
	var delta := desired - _my_position_contribution
	target.position += delta
	_my_position_contribution = desired


## Resolve position offset using the configured unit
func _calculate_position_offset() -> Vector2:
	match position_offset_unit:
		OffsetUnit.PIXELS:
			return position_offset
		OffsetUnit.FRACTION_OWN:
			var size := _infer_node2d_size(_target_node as Node2D)
			return Vector2(position_offset.x * size.x, position_offset.y * size.y)
		OffsetUnit.FRACTION_PARENT:
			var size := _infer_parent_size()
			return Vector2(position_offset.x * size.x, position_offset.y * size.y)
		OffsetUnit.FRACTION_VIEWPORT:
			var size := _get_viewport_size()
			return Vector2(position_offset.x * size.x, position_offset.y * size.y)
	return position_offset


# =============================================================================
# ROTATION EFFECT
# =============================================================================

## Apply rotation with pivot compensation. Node2D lacks native pivot_offset,
## so we adjust position to keep the pivot point stationary during rotation:
##   fixed_pivot = base_pos + pivot.rotated(base_rot)
##   new_pos = fixed_pivot - pivot.rotated(new_rot)
func _apply_rotation_effect(progress: float, target: Node2D) -> void:
	var offset_radians: float
	if _use_target_node and is_instance_valid(_target_ref):
		offset_radians = _compute_target_rotation_offset(target)
	else:
		offset_radians = deg_to_rad(rotation_offset_degrees)
	var desired_rot := offset_radians * progress
	var rot_delta := desired_rot - _my_rotation_contribution
	target.rotation += rot_delta
	_my_rotation_contribution = desired_rot

	# Pivot compensation: position depends on the full rotation.
	# Use the base reference to compute exact pivot-compensated position,
	# then write position as a delta.
	if _pivot_point != Vector2.ZERO:
		var full_rotation := _base_rotation_radians + desired_rot
		var desired_pos := _fixed_pivot_parent - _pivot_point.rotated(full_rotation)
		var desired_pos_offset := desired_pos - _base_position
		var pos_delta := desired_pos_offset - _my_position_contribution
		target.position += pos_delta
		_my_position_contribution = desired_pos_offset


# =============================================================================
# SCALE EFFECT
# =============================================================================

## Apply scale using From/To lerp model with pivot compensation.
## Node2D lacks native pivot_offset, so we adjust position to keep
## the pivot point stationary during scaling:
##   pos += pivot * (ONE - scale_ratio)
func _apply_scale_effect(progress: float, target: Node2D) -> void:
	# Resolve absolute From and To values, then lerp between them
	var from_value := _resolve_from_scale(target)
	var to_value := _resolve_to_scale(target)
	var desired_absolute := from_value.lerp(to_value, progress)

	# Convert absolute scale to delta from base (for delta-first write pattern)
	var desired_offset := desired_absolute - _base_scale
	var scale_delta := desired_offset - _my_scale_contribution

	# Pivot compensation: adjust position so the pivot point stays stationary
	if _pivot_point != Vector2.ZERO:
		var scale_ratio := desired_absolute / _base_scale
		var desired_pos_offset := _pivot_point * (Vector2.ONE - scale_ratio)
		var pos_delta := desired_pos_offset - _my_position_contribution
		target.position += pos_delta
		_my_position_contribution = desired_pos_offset

	target.scale += scale_delta
	_my_scale_contribution = desired_offset


## Resolve the From scale value to an absolute Vector2 based on from_reference
func _resolve_from_scale(animated: Node2D) -> Vector2:
	match from_reference:
		ScaleReference.CUSTOM:
			return from_scale
		ScaleReference.SELF:
			return _self_scale_snapshot
		ScaleReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_scale(_from_ref, animated)
			return _base_scale
	return _base_scale


## Resolve the To scale value to an absolute Vector2 based on to_reference
func _resolve_to_scale(animated: Node2D) -> Vector2:
	match to_reference:
		ScaleReference.CUSTOM:
			return to_scale
		ScaleReference.SELF:
			return _self_scale_snapshot
		ScaleReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_scale(_to_ref, animated)
			return _base_scale
	return _base_scale


## Convert a reference node's global scale to the animated node's parent-local scale
func _get_ref_local_scale(ref: Node2D, animated: Node2D) -> Vector2:
	var ref_global_scale := ref.global_scale
	var parent_scale := Vector2.ONE
	var parent := animated.get_parent()
	if parent is Node2D:
		parent_scale = (parent as Node2D).global_scale
	return ref_global_scale / parent_scale


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
	if not (resolved is Node2D):
		if debug_enabled:
			push_warning("[%s] transform_target_node '%s' is not a Node2D (is %s)" % [name, resolved.name, resolved.get_class()])
		return
	if resolved == _target_node:
		if debug_enabled:
			push_warning("[%s] transform_target_node points to self — offset will be zero" % [name])
	_target_ref = resolved as Node2D
	_use_target_node = true
	if debug_enabled:
		print("[%s] Resolved transform target: '%s'" % [name, resolved.name])


## Compute position offset: target's global position converted to animated node's parent space,
## minus the base position. Recomputed every frame to support moving targets.
func _compute_target_position_offset(animated: Node2D) -> Vector2:
	var parent := animated.get_parent()
	var target_in_parent: Vector2
	if parent is Node2D:
		target_in_parent = (parent as Node2D).global_transform.affine_inverse() * _target_ref.global_position
	elif parent is Control:
		target_in_parent = (parent as Control).get_global_transform().affine_inverse() * _target_ref.global_position
	else:
		target_in_parent = _target_ref.global_position
	return target_in_parent - _base_position


## Compute rotation offset: difference between target's global rotation and
## animated node's base global rotation, yielding the local-space radians needed.
func _compute_target_rotation_offset(animated: Node2D) -> float:
	var target_global_rot := _target_ref.global_rotation
	var parent_global_rot: float = 0.0
	var parent := animated.get_parent()
	if parent is Node2D:
		parent_global_rot = (parent as Node2D).global_rotation
	# desired_local = target_global - parent_global; offset = desired_local - base
	return (target_global_rot - parent_global_rot) - _base_rotation_radians


# =============================================================================
# SCALE REFERENCE RESOLUTION (From/To model)
# =============================================================================

## Resolve from_target_node and to_target_node NodePaths to cached references.
## Called once per animation start when transform_target == SCALE.
func _resolve_scale_refs() -> void:
	_from_ref = null
	_to_ref = null
	if from_reference == ScaleReference.TARGET_NODE:
		_from_ref = _resolve_node_path_to_node2d(from_target_node, "from_target_node")
	if to_reference == ScaleReference.TARGET_NODE:
		_to_ref = _resolve_node_path_to_node2d(to_target_node, "to_target_node")


## Capture Self's current scale as a stable snapshot for use during animation.
## Called at the moment chosen by capture_at (READY or TRIGGER).
func _capture_self_scale_snapshot() -> void:
	if _has_self_scale_snapshot:
		return
	var target := _get_target_node2d()
	if target == null:
		_self_scale_snapshot = Vector2.ONE
	else:
		_self_scale_snapshot = target.scale
	_has_self_scale_snapshot = true
	if debug_enabled:
		print("[%s] Captured self scale snapshot: %s" % [name, _self_scale_snapshot])


## Helper: resolve a NodePath to a Node2D, with debug warnings on failure.
## Returns null if the path is empty, unresolvable, or not a Node2D.
func _resolve_node_path_to_node2d(path: NodePath, path_name: String) -> Node2D:
	if path.is_empty():
		return null
	var resolved := get_node_or_null(path)
	if resolved == null:
		if debug_enabled:
			push_warning("[%s] %s path '%s' could not be resolved" % [name, path_name, path])
		return null
	if not (resolved is Node2D):
		if debug_enabled:
			push_warning("[%s] %s '%s' is not a Node2D (is %s)" % [name, path_name, resolved.name, resolved.get_class()])
		return null
	if debug_enabled:
		print("[%s] Resolved %s: '%s'" % [name, path_name, resolved.name])
	return resolved as Node2D


# =============================================================================
# BASE CAPTURE
# =============================================================================

func _capture_base() -> void:
	if _has_base:
		return

	var target := _get_target_node2d()
	if target == null:
		if debug_enabled and _target_node != null:
			push_warning("[%s] Target '%s' is not Node2D" % [name, _target_node.name])
		_has_base = true
		return

	_base_position = target.position
	_base_rotation_radians = target.rotation
	_base_scale = target.scale
	_has_base = true

	if debug_enabled:
		print("[%s] Captured base: pos=%s, rot=%.1f°, scale=%s" % [
			name, _base_position, rad_to_deg(_base_rotation_radians), _base_scale
		])


# =============================================================================
# PIVOT RESOLUTION (ROTATION and SCALE)
# =============================================================================

## Resolve the pivot point based on pivot_mode. Node2D has no native
## pivot_offset, so AUTO_CENTER infers visual bounds from child nodes.
func _resolve_pivot() -> void:
	match pivot_mode:
		PivotMode.AUTO_CENTER:
			# Compute the visual center of the target in local space.
			# Node2D content (Sprite2D, shapes, etc.) is typically centered at origin,
			# so the center is often (0,0) — meaning no position compensation is needed.
			if _target_node is Node2D:
				var n2d := _target_node as Node2D
				var bounds := _infer_node2d_local_bounds(n2d)
				if bounds.size == Vector2.ZERO:
					# Container fallback: compute merged bounds from children
					bounds = _infer_node2d_bounds_recursive(n2d)
				if bounds.size != Vector2.ZERO:
					_pivot_point = bounds.get_center()
				else:
					_pivot_point = Vector2.ZERO
				if debug_enabled:
					print("[%s] Auto-center pivot: bounds=%s, center=%s" % [name, bounds, _pivot_point])
			else:
				_pivot_point = Vector2.ZERO
		PivotMode.INHERIT:
			_pivot_point = Vector2.ZERO
		PivotMode.CUSTOM:
			_pivot_point = custom_pivot


# =============================================================================
# SIZE INFERENCE (shared between position offset units and pivot resolution)
# =============================================================================

func _infer_parent_size() -> Vector2:
	if _target_node == null:
		return Vector2.ZERO
	var parent := _target_node.get_parent()
	if parent is Control:
		return (parent as Control).size
	if parent is Node2D:
		return _infer_node2d_size(parent as Node2D)
	return Vector2.ZERO


func _infer_node2d_size(node: Node2D) -> Vector2:
	if node == null:
		return Vector2.ZERO

	if node is Sprite2D:
		var spr := node as Sprite2D
		var tex := spr.texture
		if tex != null:
			var size := tex.get_size()
			if spr.region_enabled:
				size = spr.region_rect.size
			var sc := spr.scale
			return Vector2(absf(sc.x) * size.x, absf(sc.y) * size.y)

	if node is AnimatedSprite2D:
		var anim := node as AnimatedSprite2D
		if anim.sprite_frames != null:
			var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
			if tex != null:
				var size := tex.get_size()
				var sc := anim.scale
				return Vector2(absf(sc.x) * size.x, absf(sc.y) * size.y)

	if node is CollisionShape2D:
		var col := node as CollisionShape2D
		if col.shape != null:
			var shape := col.shape
			if shape is RectangleShape2D:
				return (shape as RectangleShape2D).size
			if shape is CircleShape2D:
				var r := (shape as CircleShape2D).radius
				return Vector2(r * 2.0, r * 2.0)
			if shape is CapsuleShape2D:
				var cap := shape as CapsuleShape2D
				return Vector2(cap.radius * 2.0, cap.height + cap.radius * 2.0)

	if node is Polygon2D:
		var poly := node as Polygon2D
		if poly.polygon.size() > 0:
			var min_x := poly.polygon[0].x
			var max_x := poly.polygon[0].x
			var min_y := poly.polygon[0].y
			var max_y := poly.polygon[0].y
			for p in poly.polygon:
				min_x = minf(min_x, p.x)
				max_x = maxf(max_x, p.x)
				min_y = minf(min_y, p.y)
				max_y = maxf(max_y, p.y)
			return Vector2(max_x - min_x, max_y - min_y)

	# Container fallback: infer a bounding box from all descendant Node2D children
	var bounds := _infer_node2d_bounds_recursive(node)
	if bounds.size != Vector2.ZERO:
		return bounds.size

	if debug_enabled:
		push_warning("[%s] Cannot infer Node2D size on '%s' (%s)" % [name, node.name, node.get_class()])
	return Vector2.ZERO


func _infer_node2d_bounds_recursive(root: Node2D) -> Rect2:
	var has_any: bool = false
	var combined := Rect2(Vector2.ZERO, Vector2.ZERO)

	for child in root.get_children():
		if not (child is Node2D):
			continue
		var child_n2d := child as Node2D
		var child_local_bounds := _infer_node2d_local_bounds(child_n2d)
		if child_local_bounds.size != Vector2.ZERO:
			child_local_bounds.position += child_n2d.position
			if not has_any:
				has_any = true
				combined = child_local_bounds
			else:
				combined = combined.merge(child_local_bounds)

		var grandchild_bounds := _infer_node2d_bounds_recursive(child_n2d)
		if grandchild_bounds.size != Vector2.ZERO:
			grandchild_bounds.position += child_n2d.position
			if not has_any:
				has_any = true
				combined = grandchild_bounds
			else:
				combined = combined.merge(grandchild_bounds)

	if not has_any:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return combined


func _infer_node2d_local_bounds(node: Node2D) -> Rect2:
	var size := Vector2.ZERO

	if node is Sprite2D:
		var spr := node as Sprite2D
		var tex := spr.texture
		if tex != null:
			size = tex.get_size()
			if spr.region_enabled:
				size = spr.region_rect.size
			var sc := spr.scale
			size = Vector2(absf(sc.x) * size.x, absf(sc.y) * size.y)

	elif node is AnimatedSprite2D:
		var anim := node as AnimatedSprite2D
		if anim.sprite_frames != null:
			var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
			if tex != null:
				size = tex.get_size()
				var sc := anim.scale
				size = Vector2(absf(sc.x) * size.x, absf(sc.y) * size.y)

	elif node is CollisionShape2D:
		var col := node as CollisionShape2D
		if col.shape != null:
			var shape := col.shape
			if shape is RectangleShape2D:
				size = (shape as RectangleShape2D).size
			elif shape is CircleShape2D:
				var r := (shape as CircleShape2D).radius
				size = Vector2(r * 2.0, r * 2.0)
			elif shape is CapsuleShape2D:
				var cap := shape as CapsuleShape2D
				size = Vector2(cap.radius * 2.0, cap.height + cap.radius * 2.0)

	elif node is Polygon2D:
		var poly := node as Polygon2D
		if poly.polygon.size() > 0:
			var min_x := poly.polygon[0].x
			var max_x := poly.polygon[0].x
			var min_y := poly.polygon[0].y
			var max_y := poly.polygon[0].y
			for p in poly.polygon:
				min_x = minf(min_x, p.x)
				max_x = maxf(max_x, p.x)
				min_y = minf(min_y, p.y)
				max_y = maxf(max_y, p.y)
			size = Vector2(max_x - min_x, max_y - min_y)

	if size == Vector2.ZERO:
		return Rect2(Vector2.ZERO, Vector2.ZERO)

	# Local bounds centered on the node's origin
	return Rect2(-size * 0.5, size)


# =============================================================================
# HELPERS
# =============================================================================

func _get_target_node2d() -> Node2D:
	if not is_instance_valid(_target_node):
		return null
	if _target_node is Node2D:
		return _target_node as Node2D
	if debug_enabled:
		push_warning("[%s] Target '%s' is not Node2D" % [name, _target_node.name])
	return null


# =============================================================================
# SEQUENCER RECIPE CONTRACT
# =============================================================================

func _recipe_capture_natural(target: Node) -> Variant:
	if target is Node2D:
		var n2d := target as Node2D
		match transform_target:
			TransformTarget.POSITION:
				return {"position": n2d.position}
			TransformTarget.ROTATION:
				# Rotation with pivot needs position too for compensation
				return {"rotation": n2d.rotation, "position": n2d.position}
			TransformTarget.SCALE:
				# Scale with pivot needs position too for compensation
				return {"scale": n2d.scale, "position": n2d.position}
	return null


func _recipe_apply_natural(_target: Node, natural: Variant) -> void:
	if not (natural is Dictionary):
		return
	var dict := natural as Dictionary

	match transform_target:
		TransformTarget.POSITION:
			_base_position = dict.get("position", Vector2.ZERO) as Vector2
		TransformTarget.ROTATION:
			_base_rotation_radians = dict.get("rotation", 0.0) as float
			_base_position = dict.get("position", Vector2.ZERO) as Vector2
		TransformTarget.SCALE:
			_base_scale = dict.get("scale", Vector2.ONE) as Vector2
			_base_position = dict.get("position", Vector2.ZERO) as Vector2
			# Reset self snapshot so it gets re-captured for this target
			_has_self_scale_snapshot = false

	_has_base = true
	_pivot_resolved = false


func _recipe_restore_natural(target: Node, natural: Variant) -> void:
	if not (natural is Dictionary) or not (target is Node2D):
		return
	var dict := natural as Dictionary
	var n2d := target as Node2D

	match transform_target:
		TransformTarget.POSITION:
			n2d.position = dict.get("position", Vector2.ZERO) as Vector2
		TransformTarget.ROTATION:
			n2d.rotation = dict.get("rotation", 0.0) as float
			n2d.position = dict.get("position", Vector2.ZERO) as Vector2
		TransformTarget.SCALE:
			n2d.scale = dict.get("scale", Vector2.ONE) as Vector2
			n2d.position = dict.get("position", Vector2.ZERO) as Vector2

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent := get_parent()
	if parent and not parent is Node2D:
		warnings.append("Parent must be a Node2D node. Use TransformControl/Transform3D for other domains. (ignore if comp is a child of a sequencer)")
	# Scale From/To: warn if both reference Self (no visible effect)
	if transform_target == TransformTarget.SCALE:
		if from_reference == ScaleReference.SELF and to_reference == ScaleReference.SELF:
			warnings.append("Both From and To reference Self \u2014 animation will have no visible effect.")
	return warnings
