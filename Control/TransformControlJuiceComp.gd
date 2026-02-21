## TransformControlJuiceComp.gd
## ============================================================================
## WHAT: Consolidated deterministic transform effect for Control nodes. Combines
##       position, rotation, and scale animation into a single component with a
##       TransformTarget selector. Uses _get_property_list() to conditionally
##       show only relevant exports in the inspector.
## WHY: Replaces 3 separate scripts (PositionControlJuiceComp, RotationControlJuiceComp,
##      ScaleControlJuiceComp) with one unified component, reducing file count and
##      ensuring consistent behavior across transform types.
## SYSTEM: Juicing System (addons/juice/) - Control Domain
## DOES NOT: Handle Node2D or Node3D targets (use Transform2D/Transform3D).
## DOES NOT: Handle procedural effects like shake or noise (use Shake/Noise comps).
## DOES NOT: Handle arbitrary property animation (use PropertyShake/PropertyNoise).
## ============================================================================
##
## TRANSFORM TARGETS:
## - POSITION: Animates Control.position with Vector2 offset + OffsetUnit system.
##   Supports PIXELS, FRACTION_OWN, FRACTION_PARENT, FRACTION_VIEWPORT units.
## - ROTATION: Animates Control.rotation with float offset (degrees) + pivot mode.
##   Uses native Control.pivot_offset for rotation origin.
## - SCALE: Animates Control.scale with Vector2 offset + pivot mode.
##   Uses native Control.pivot_offset for scaling origin.
##
## PIVOT (ROTATION and SCALE only):
## Uses the native Control.pivot_offset property via PivotMode enum:
## - AUTO_CENTER: Sets pivot to center of Control (size / 2)
## - INHERIT: Keeps existing pivot_offset unchanged
## - CUSTOM: Sets pivot using normalized coordinates (0-1)
##
## TRANSFORM TARGET NODE (optional):
## When transform_target_node points to a Control node, manual offset fields are
## ignored. Instead, the offset is computed per-frame from the animated node's
## base transform to the target node's current global transform. Supports moving targets.
##
## CONDITIONAL EXPORTS:
## Changing transform_target triggers notify_property_list_changed() which
## shows/hides the relevant parameters via _get_property_list(). Properties
## added this way appear AFTER all @export properties in the inspector.
## ============================================================================

@tool
class_name TransformControlJuiceComp
extends JuiceCompBase

# =============================================================================
# TRANSFORM TARGET SELECTION
# =============================================================================

## Which transform property to animate
enum TransformTarget {
	POSITION,  ## Animate Control.position with offset + unit
	ROTATION,  ## Animate Control.rotation (single-axis Z, degrees)
	SCALE      ## Animate Control.scale with offset
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
	AUTO_CENTER,  ## Automatically center pivot (most common for UI)
	INHERIT,      ## Use the node's existing pivot_offset
	CUSTOM        ## Use custom_pivot values below
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

# --- SCALE ---
## How much to change scale at progress=1.0 (added to base scale)
var scale_offset: Vector2 = Vector2(0.1, 0.1)

# --- TRANSFORM TARGET NODE ---
## Optional: drag a Control node here to animate TOWARD its transform.
## When set, manual offset fields are ignored — offset is computed per-frame
## from the animated node's base to the target node's current global transform.
var transform_target_node: NodePath

# --- PIVOT (ROTATION + SCALE) ---
var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()
## Custom pivot in normalized coordinates (0-1). (0.5, 0.5) = center.
var custom_pivot: Vector2 = Vector2(0.5, 0.5)

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _base_position: Vector2 = Vector2.ZERO
var _base_rotation_radians: float = 0.0
var _base_scale: Vector2 = Vector2.ONE

## Whether base has been captured
var _has_base: bool = false

## Whether pivot has been applied for current target
var _pivot_applied: bool = false

## Resolved reference to the transform target node (cached at animation start)
var _target_ref: Control = null
## Whether to use target node offset instead of manual offset
var _use_target_node: bool = false


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# Transform target node slot — always visible, type-safe to Control only
	props.append({
		"name": "transform_target_node",
		"type": TYPE_NODE_PATH,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		"hint_string": "Control",
	})

	match transform_target:
		TransformTarget.POSITION:
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
			props.append({
				"name": "rotation_offset_degrees",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})
			# Pivot exports for rotation
			props.append_array(_get_pivot_properties())

		TransformTarget.SCALE:
			props.append({
				"name": "scale_offset",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})
			# Pivot exports for scale
			props.append_array(_get_pivot_properties())

	return props


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
		# Position
		&"position_offset": position_offset = value; return true
		&"position_offset_unit": position_offset_unit = value; return true
		# Rotation
		&"rotation_offset_degrees": rotation_offset_degrees = value; return true
		# Scale
		&"scale_offset": scale_offset = value; return true
		# Pivot
		&"pivot_mode": pivot_mode = value; return true
		&"custom_pivot": custom_pivot = value; return true
		# Transform target node
		&"transform_target_node": transform_target_node = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		# Position
		&"position_offset": return position_offset
		&"position_offset_unit": return position_offset_unit
		# Rotation
		&"rotation_offset_degrees": return rotation_offset_degrees
		# Scale
		&"scale_offset": return scale_offset
		# Pivot
		&"pivot_mode": return pivot_mode
		&"custom_pivot": return custom_pivot
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
	_pivot_applied = false
	_use_target_node = false


func _get_interrupt_identity() -> Variant:
	return [get_script(), transform_target]


func _on_animate_start() -> void:
	if not _has_base:
		_capture_base()

	# Resolve transform target node if path is set
	_resolve_transform_target()

	# Resolve pivot for rotation/scale targets
	if transform_target != TransformTarget.POSITION and not _pivot_applied:
		_apply_pivot_mode()
		_pivot_applied = true

	if debug_enabled:
		var target_name: String = TransformTarget.keys()[transform_target]
		print("[%s] Transform start (Control, %s)" % [name, target_name])


func _apply_effect(progress: float) -> void:
	if not is_instance_valid(_target_node) or not (_target_node is Control):
		return

	match transform_target:
		TransformTarget.POSITION:
			_apply_position_effect(progress)
		TransformTarget.ROTATION:
			_apply_rotation_effect(progress)
		TransformTarget.SCALE:
			_apply_scale_effect(progress)


# =============================================================================
# POSITION EFFECT
# =============================================================================

func _apply_position_effect(progress: float) -> void:
	var ctrl := _target_node as Control
	var actual_offset: Vector2
	if _use_target_node and is_instance_valid(_target_ref):
		actual_offset = _compute_target_position_offset(ctrl)
	else:
		actual_offset = _calculate_position_offset()
	ctrl.position = _base_position + (actual_offset * progress)


## Resolve position offset using the configured unit
func _calculate_position_offset() -> Vector2:
	match position_offset_unit:
		OffsetUnit.PIXELS:
			return position_offset
		OffsetUnit.FRACTION_OWN:
			var size := _get_target_size()
			return Vector2(position_offset.x * size.x, position_offset.y * size.y)
		OffsetUnit.FRACTION_PARENT:
			var size := _get_parent_size()
			return Vector2(position_offset.x * size.x, position_offset.y * size.y)
		OffsetUnit.FRACTION_VIEWPORT:
			var size := _get_viewport_size()
			return Vector2(position_offset.x * size.x, position_offset.y * size.y)
	return position_offset


# =============================================================================
# ROTATION EFFECT
# =============================================================================

func _apply_rotation_effect(progress: float) -> void:
	var ctrl := _target_node as Control
	var offset_radians: float
	if _use_target_node and is_instance_valid(_target_ref):
		offset_radians = _compute_target_rotation_offset(ctrl)
	else:
		offset_radians = deg_to_rad(rotation_offset_degrees)
	ctrl.rotation = _base_rotation_radians + (offset_radians * progress)


# =============================================================================
# SCALE EFFECT
# =============================================================================

func _apply_scale_effect(progress: float) -> void:
	var ctrl := _target_node as Control
	var actual_offset: Vector2
	if _use_target_node and is_instance_valid(_target_ref):
		actual_offset = _compute_target_scale_offset(ctrl)
	else:
		actual_offset = scale_offset
	ctrl.scale = _base_scale + (actual_offset * progress)


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
	if not (resolved is Control):
		if debug_enabled:
			push_warning("[%s] transform_target_node '%s' is not a Control (is %s)" % [name, resolved.name, resolved.get_class()])
		return
	if resolved == _target_node:
		if debug_enabled:
			push_warning("[%s] transform_target_node points to self — offset will be zero" % [name])
	_target_ref = resolved as Control
	_use_target_node = true
	if debug_enabled:
		print("[%s] Resolved transform target: '%s'" % [name, resolved.name])


## Compute position offset: target's global position converted to animated node's parent space,
## minus the base position. Recomputed every frame to support moving targets.
func _compute_target_position_offset(ctrl: Control) -> Vector2:
	var parent_ctrl := ctrl.get_parent_control()
	var target_in_parent: Vector2
	if parent_ctrl:
		target_in_parent = parent_ctrl.get_global_transform().affine_inverse() * _target_ref.global_position
	else:
		target_in_parent = _target_ref.global_position
	return target_in_parent - _base_position


## Compute rotation offset: difference between target's global rotation and
## animated node's base global rotation, yielding the local-space radians needed.
func _compute_target_rotation_offset(ctrl: Control) -> float:
	var target_rot := _target_ref.get_global_transform().get_rotation()
	var parent_rot: float = 0.0
	var parent_ctrl := ctrl.get_parent_control()
	if parent_ctrl:
		parent_rot = parent_ctrl.get_global_transform().get_rotation()
	# desired_local_rotation = target_global - parent_global
	# offset = desired_local - base
	return (target_rot - parent_rot) - _base_rotation_radians


## Compute scale offset: target's global scale converted to parent-local scale,
## minus the base scale.
func _compute_target_scale_offset(ctrl: Control) -> Vector2:
	var target_global_scale := _target_ref.get_global_transform().get_scale()
	var parent_scale := Vector2.ONE
	var parent_ctrl := ctrl.get_parent_control()
	if parent_ctrl:
		parent_scale = parent_ctrl.get_global_transform().get_scale()
	var desired_local := target_global_scale / parent_scale
	return desired_local - _base_scale


# =============================================================================
# BASE CAPTURE
# =============================================================================

func _capture_base() -> void:
	if _has_base:
		return

	if not (_target_node is Control):
		if debug_enabled and _target_node != null:
			push_warning("[%s] Target '%s' is not Control" % [name, _target_node.name])
		_has_base = true
		return

	var ctrl := _target_node as Control
	_base_position = ctrl.position
	_base_rotation_radians = ctrl.rotation
	_base_scale = ctrl.scale
	_has_base = true

	if debug_enabled:
		print("[%s] Captured base: pos=%s, rot=%.1f°, scale=%s" % [
			name, _base_position, rad_to_deg(_base_rotation_radians), _base_scale
		])


# =============================================================================
# PIVOT HANDLING (native Control.pivot_offset)
# =============================================================================

## Apply pivot mode to the Control node. Called once per animation start
## for ROTATION and SCALE targets. Control nodes have a native pivot_offset
## property, so no position compensation is needed.
func _apply_pivot_mode() -> void:
	if not (_target_node is Control):
		return

	var ctrl := _target_node as Control
	var old_pivot := ctrl.pivot_offset

	match pivot_mode:
		PivotMode.AUTO_CENTER:
			ctrl.pivot_offset = ctrl.size / 2.0
		PivotMode.INHERIT:
			return
		PivotMode.CUSTOM:
			ctrl.pivot_offset = Vector2(
				ctrl.size.x * custom_pivot.x,
				ctrl.size.y * custom_pivot.y
			)

	if debug_enabled:
		print("[%s] Pivot set to %s (was %s)" % [name, ctrl.pivot_offset, old_pivot])


# =============================================================================
# SEQUENCER RECIPE CONTRACT
# =============================================================================

func _recipe_capture_natural(target: Node) -> Variant:
	if target is Control:
		var ctrl := target as Control
		match transform_target:
			TransformTarget.POSITION:
				return {"position": ctrl.position}
			TransformTarget.ROTATION:
				return {"rotation": ctrl.rotation}
			TransformTarget.SCALE:
				return {"scale": ctrl.scale}
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
		TransformTarget.SCALE:
			_base_scale = dict.get("scale", Vector2.ONE) as Vector2

	_has_base = true
	_pivot_applied = false


func _recipe_restore_natural(target: Node, natural: Variant) -> void:
	if not (natural is Dictionary) or not (target is Control):
		return
	var dict := natural as Dictionary
	var ctrl := target as Control

	match transform_target:
		TransformTarget.POSITION:
			ctrl.position = dict.get("position", Vector2.ZERO) as Vector2
		TransformTarget.ROTATION:
			ctrl.rotation = dict.get("rotation", 0.0) as float
		TransformTarget.SCALE:
			ctrl.scale = dict.get("scale", Vector2.ONE) as Vector2
