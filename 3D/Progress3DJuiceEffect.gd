## Continuous-accumulation (Progress) effect for 3D-domain nodes.
##
## Accumulates position, rotation, or scale at a configurable rate per second.
## progress acts as a speed multiplier (0=stopped, 1=full speed).

# =============================================================================
# WHAT: 3D-domain continuous-accumulation (Progress) effect.
# WHY:  Defines a resource-based progress driver for Node3D targets.
# SYSTEM: Juice System (addons/Juice_V1/3D/)
# DOES NOT: Handle Control or Node2D targets.
# DOES NOT: Handle arbitrary property accumulation -- use ProgressProperty3DJuiceEffect.
#
# PIVOT (ROTATION and SCALE only):
#   Node3D has no native pivot_offset. Pivot is simulated via Transform3D math:
#   For rotation: apply quaternion rotation around a world-space pivot point.
#   For scale: apply scale offset compensation via the pivot translation.
#   AUTO_CENTER infers the visual center by recursively sampling child AABB.
# =============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name Progress3DJuiceEffect
extends Juice3DTransformEffect


# =============================================================================
# ENUMS
# =============================================================================

# TransformTarget inherited from Juice3DTransformEffect

# PivotMode inherited from Juice3DTransformEffect

## What to do when accumulated distance reaches the bound.
enum BoundBehaviour {
	EMIT_COMPLETED,  ## Emit completed signal (fires chaining).
	REVERSE,         ## Instant direction flip (ping-pong).
	REVERSE_EASED,   ## Smooth direction change via eased deceleration + restart.
	WRAP,            ## Reset accumulated to 0, continue (looping).
	STOP,            ## Stop accumulation, hold at bound value.
	DESTROY_PARENT   ## queue_free() the parent node.
}

## How to measure accumulated distance for bound checking.
enum BoundMode {
	MAGNITUDE,  ## Accumulated magnitude compared to a single float.
	PER_AXIS    ## Per-axis comparison.
}


# =============================================================================
# CONFIGURATION
# =============================================================================

func _init() -> void:
	_subclass_owns_effect_group = true
	_leaf_owns_layout = true
	transform_target = TransformTarget.ROTATION  # Progress defaults to ROTATION not POSITION


# transform_target inherited from Juice3DTransformEffect (default set to ROTATION in _init)

var auto_start: bool = false
var hold_on_stop: bool = true

# --- Rate vars ---
## Position drift in local units per second.
var position_rate: Vector3 = Vector3(0.0, 0.0, 1.0)
var position_unit: int = PositionIn3D.WORLD_UNITS:
	set(value):
		position_unit = value
		notify_property_list_changed()
## Rotation in degrees per second per axis.
var rotation_rate: Vector3 = Vector3(0.0, 90.0, 0.0)
## Scale growth per second per axis.
var scale_rate: Vector3 = Vector3(0.1, 0.1, 0.1)

# --- Pivot ---
# pivot_mode inherited from Juice3DTransformEffect (default: AUTO_CENTER)
## Pivot in local-space units when pivot_mode = CUSTOM.
var custom_pivot: Vector3 = Vector3.ZERO

# --- Bound ---
## When enabled, the accumulated transform is tracked against [bound_value].
## When the limit is exceeded, [bound_behaviour] fires (reverse, wrap, stop, etc.).
## Useful for ping-pong loops (Reverse Eased), bounded orbits, or one-shot travel.
var bound_enabled: bool = false:
	set(value):
		bound_enabled = value
		notify_property_list_changed()
var bound_behaviour: int = BoundBehaviour.REVERSE
var bound_mode: int = BoundMode.MAGNITUDE:
	set(value):
		bound_mode = value
		notify_property_list_changed()
var bound_value: float = 360.0
var bound_value_vec3: Vector3 = Vector3(360.0, 360.0, 360.0)


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	props.append({"name": "Effect", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "transform_target", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Position,Rotation,Scale",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append_array(_get_effect_base_properties())
	props.append({"name": "auto_start", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "hold_on_stop", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})

	match transform_target:
		TransformTarget.POSITION:
			props.append({"name": "position_unit", "type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM, "hint_string": "World Units,Own Size,Parent Size",
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "position_rate", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_DEFAULT})
		TransformTarget.ROTATION:
			props.append({"name": "rotation_rate", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_DEFAULT})
		TransformTarget.SCALE:
			props.append({"name": "scale_rate", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_DEFAULT})

	if transform_target != TransformTarget.POSITION:
		props.append({"name": "pivot_mode", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Auto Center,Inherit,Custom",
			"usage": PROPERTY_USAGE_DEFAULT})
		if pivot_mode == PivotMode.CUSTOM:
			props.append({"name": "custom_pivot", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_DEFAULT})

	props.append({"name": "bound_enabled", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})
	if bound_enabled:
		props.append({"name": "bound_behaviour", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Emit Completed,Reverse,Reverse Eased,Wrap,Stop,Destroy Parent",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "bound_mode", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Magnitude,Per Axis",
			"usage": PROPERTY_USAGE_DEFAULT})
		if bound_mode == BoundMode.PER_AXIS:
			props.append({"name": "bound_value_vec3", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_DEFAULT})
		else:
			props.append({"name": "bound_value", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_DEFAULT})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"transform_target": transform_target = value; return true
		&"auto_start": auto_start = value; return true
		&"hold_on_stop": hold_on_stop = value; return true
		&"position_rate": position_rate = value; return true
		&"rotation_rate": rotation_rate = value; return true
		&"scale_rate": scale_rate = value; return true
		&"pivot_mode": pivot_mode = value; return true
		&"custom_pivot": custom_pivot = value; return true
		&"bound_enabled": bound_enabled = value; return true
		&"bound_behaviour": bound_behaviour = value; return true
		&"bound_mode": bound_mode = value; return true
		&"bound_value": bound_value = value; return true
		&"bound_value_vec3": bound_value_vec3 = value; return true
	return super._set(property, value)


func _get(property: StringName) -> Variant:
	match property:
		&"transform_target": return transform_target
		&"auto_start": return auto_start
		&"hold_on_stop": return hold_on_stop
		&"position_rate": return position_rate
		&"rotation_rate": return rotation_rate
		&"scale_rate": return scale_rate
		&"pivot_mode": return pivot_mode
		&"custom_pivot": return custom_pivot
		&"bound_enabled": return bound_enabled
		&"bound_behaviour": return bound_behaviour
		&"bound_mode": return bound_mode
		&"bound_value": return bound_value
		&"bound_value_vec3": return bound_value_vec3
	return super._get(property)


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _accumulated_position: Vector3 = Vector3.ZERO
var _accumulated_rotation: Vector3 = Vector3.ZERO  # radians per axis
var _accumulated_scale: Vector3 = Vector3.ZERO
var _current_direction: float = 1.0
# _has_base inherited from Juice3DTransformEffect
var _base_position: Vector3 = Vector3.ZERO
var _base_rotation: Vector3 = Vector3.ZERO  # radians per axis
var _base_scale: Vector3 = Vector3.ONE
var _pivot_point: Vector3 = Vector3.ZERO
var _pivot_resolved: bool = false
var _awaiting_reverse_eased: bool = false
var _pending_restart_reversed: bool = false
## Stores delta from tick() for use in _apply_effect() -- Resources have no process()
var _last_delta: float = 0.0


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

func _needs_sustain() -> bool:
	return true


func _on_animate_start(target: Node) -> void:
	if not _has_base:
		_capture_base(target)
	if transform_target != TransformTarget.POSITION and not _pivot_resolved:
		_resolve_pivot(target)
		_pivot_resolved = true

	_contributes_position = (transform_target == TransformTarget.POSITION)
	_contributes_rotation = (transform_target == TransformTarget.ROTATION)
	_contributes_scale = (transform_target == TransformTarget.SCALE)
	# Pivot compensation contributes to position even for rotation/scale
	if transform_target != TransformTarget.POSITION and _pivot_point != Vector3.ZERO:
		_contributes_position = true

	if debug_enabled:
		print("[Progress3D] Start: %s dir=%.0f" % [TransformTarget.keys()[transform_target], _current_direction])


func _restore_to_natural(target: Node) -> void:
	_clear_deltas()
	if not hold_on_stop:
		_reset_accumulated()
		_has_base = false
		_pivot_resolved = false


func _invalidate_base_cache() -> void:
	_has_base = false
	_pivot_resolved = false
	_clear_deltas()


func tick(delta: float, target: Node) -> JuiceEffectBase.TickResult:
	_last_delta = delta
	_pending_restart_reversed = false
	var result := super.tick(delta, target)
	if _pending_restart_reversed:
		_pending_restart_reversed = false
		return JuiceEffectBase.TickResult.RESTART_REVERSED
	return result


# =============================================================================
# APPLY EFFECT
# =============================================================================

func _apply_effect(progress: float, target: Node) -> void:
	var n3d := target as Node3D
	if n3d == null:
		return

	match transform_target:
		TransformTarget.POSITION:
			_accumulated_position += position_rate * _last_delta * progress * _current_direction
			_pos_delta = _convert_to_world_units(_accumulated_position, position_unit, n3d)

		TransformTarget.ROTATION:
			var rate_rad := Vector3(
				deg_to_rad(rotation_rate.x),
				deg_to_rad(rotation_rate.y),
				deg_to_rad(rotation_rate.z)
			)
			_accumulated_rotation += rate_rad * _last_delta * progress * _current_direction
			_rot_delta = _accumulated_rotation
			# Pivot position compensation via Transform3D math
			if _pivot_point != Vector3.ZERO:
				_pos_delta = _compute_pivot_position_delta()

		TransformTarget.SCALE:
			_accumulated_scale += scale_rate * _last_delta * progress * _current_direction
			_scale_delta = _accumulated_scale
			if _pivot_point != Vector3.ZERO:
				_pos_delta = _compute_scale_pivot_position_delta()

	if bound_enabled and progress > 0.0:
		_check_bounds()


## Compute position delta so rotation appears to happen around _pivot_point.
## Uses Basis to rotate the offset vector.
func _compute_pivot_position_delta() -> Vector3:
	var total_rot := _accumulated_rotation
	var basis := Basis.from_euler(total_rot)
	var pivot_world := _base_position + _pivot_point
	var new_pivot_pos := pivot_world - basis * _pivot_point
	return new_pivot_pos - _base_position


## Compute position delta so scaling appears to happen around _pivot_point.
func _compute_scale_pivot_position_delta() -> Vector3:
	var new_scale := _base_scale + _accumulated_scale
	var scale_ratio := Vector3(
		new_scale.x / _base_scale.x if _base_scale.x != 0.0 else 1.0,
		new_scale.y / _base_scale.y if _base_scale.y != 0.0 else 1.0,
		new_scale.z / _base_scale.z if _base_scale.z != 0.0 else 1.0
	)
	return _pivot_point * (Vector3.ONE - scale_ratio)


# =============================================================================
# BOUND CHECKING
# =============================================================================

func _check_bounds() -> void:
	if _awaiting_reverse_eased:
		return
	if not _is_bound_exceeded():
		return

	_clamp_to_bound()

	if debug_enabled:
		print("[Progress3D] Bound reached. Behaviour: %s" % BoundBehaviour.keys()[bound_behaviour])

	match bound_behaviour:
		BoundBehaviour.EMIT_COMPLETED:
			# Signal completion via _is_playing - host's tick loop detects COMPLETED
			_is_playing = false
		BoundBehaviour.REVERSE:
			_absorb_accumulated_into_base()
			_current_direction *= -1.0
		BoundBehaviour.REVERSE_EASED:
			_absorb_accumulated_into_base()
			_current_direction *= -1.0
			_pending_restart_reversed = true
		BoundBehaviour.WRAP:
			_wrap_accumulated()
		BoundBehaviour.STOP:
			_is_playing = false
		BoundBehaviour.DESTROY_PARENT:
			if _host_node != null and is_instance_valid(_host_node):
				var parent := _host_node.get_parent()
				if parent != null:
					parent.queue_free()


func _is_bound_exceeded() -> bool:
	match transform_target:
		TransformTarget.POSITION:
			return _check_vec3_bound(_accumulated_position)
		TransformTarget.ROTATION:
			# For rotation, compare per-axis degrees magnitude against bound_value
			if bound_mode == BoundMode.PER_AXIS:
				return (absf(rad_to_deg(_accumulated_rotation.x)) > absf(bound_value_vec3.x) or
						absf(rad_to_deg(_accumulated_rotation.y)) > absf(bound_value_vec3.y) or
						absf(rad_to_deg(_accumulated_rotation.z)) > absf(bound_value_vec3.z))
			return _accumulated_rotation.length() > deg_to_rad(bound_value)
		TransformTarget.SCALE:
			return _check_vec3_bound(_accumulated_scale)
	return false


func _check_vec3_bound(accumulated: Vector3) -> bool:
	if bound_mode == BoundMode.PER_AXIS:
		return (absf(accumulated.x) > absf(bound_value_vec3.x) or
				absf(accumulated.y) > absf(bound_value_vec3.y) or
				absf(accumulated.z) > absf(bound_value_vec3.z))
	return accumulated.length() > bound_value


func _clamp_to_bound() -> void:
	match transform_target:
		TransformTarget.POSITION:
			_accumulated_position = _clamp_vec3(_accumulated_position)
		TransformTarget.ROTATION:
			if bound_mode == BoundMode.PER_AXIS:
				_accumulated_rotation = Vector3(
					clampf(_accumulated_rotation.x, -deg_to_rad(absf(bound_value_vec3.x)), deg_to_rad(absf(bound_value_vec3.x))),
					clampf(_accumulated_rotation.y, -deg_to_rad(absf(bound_value_vec3.y)), deg_to_rad(absf(bound_value_vec3.y))),
					clampf(_accumulated_rotation.z, -deg_to_rad(absf(bound_value_vec3.z)), deg_to_rad(absf(bound_value_vec3.z)))
				)
			else:
				var max_rad := deg_to_rad(bound_value)
				var len := _accumulated_rotation.length()
				if len > max_rad and len > 0.0:
					_accumulated_rotation = _accumulated_rotation.normalized() * max_rad
		TransformTarget.SCALE:
			_accumulated_scale = _clamp_vec3(_accumulated_scale)


func _clamp_vec3(accumulated: Vector3) -> Vector3:
	if bound_mode == BoundMode.PER_AXIS:
		return Vector3(
			clampf(accumulated.x, -absf(bound_value_vec3.x), absf(bound_value_vec3.x)),
			clampf(accumulated.y, -absf(bound_value_vec3.y), absf(bound_value_vec3.y)),
			clampf(accumulated.z, -absf(bound_value_vec3.z), absf(bound_value_vec3.z))
		)
	var length := accumulated.length()
	if length > bound_value and length > 0.0:
		return accumulated.normalized() * bound_value
	return accumulated


func _wrap_accumulated() -> void:
	match transform_target:
		TransformTarget.POSITION:
			_accumulated_position = Vector3.ZERO
		TransformTarget.ROTATION:
			_accumulated_rotation = Vector3.ZERO
		TransformTarget.SCALE:
			_accumulated_scale = Vector3.ZERO


# =============================================================================
# HELPERS
# =============================================================================

func _absorb_accumulated_into_base() -> void:
	match transform_target:
		TransformTarget.POSITION:
			_base_position += _accumulated_position
			_accumulated_position = Vector3.ZERO
		TransformTarget.ROTATION:
			_base_rotation += _accumulated_rotation
			_accumulated_rotation = Vector3.ZERO
		TransformTarget.SCALE:
			_base_scale += _accumulated_scale
			_accumulated_scale = Vector3.ZERO


func _reset_accumulated() -> void:
	_accumulated_position = Vector3.ZERO
	_accumulated_rotation = Vector3.ZERO
	_accumulated_scale = Vector3.ZERO


func _capture_base(target: Node) -> void:
	if _has_base:
		return
	var n3d := target as Node3D
	if n3d == null:
		push_warning("[Progress3D] Cannot capture base -- target is not Node3D")
		return
	_base_position = n3d.position
	_base_rotation = n3d.rotation
	_base_scale = n3d.scale
	_has_base = true
	if debug_enabled:
		print("[Progress3D] Captured base -- pos:%s rot_rad:%s scale:%s" % [
			_base_position, _base_rotation, _base_scale])


# =============================================================================
# PIVOT HANDLING -- Transform3D-based compensation (no native pivot_offset in 3D)
# =============================================================================

func _resolve_pivot(target: Node) -> void:
	var n3d := target as Node3D
	if n3d == null:
		return
	match pivot_mode:
		PivotMode.AUTO_CENTER:
			_pivot_point = _infer_node3d_center(n3d)
		PivotMode.INHERIT:
			_pivot_point = Vector3.ZERO
		PivotMode.CUSTOM:
			_pivot_point = custom_pivot
	if debug_enabled:
		print("[Progress3D] Pivot: %s" % _pivot_point)


## Recursively sample child AABB to find visual center.
func _infer_node3d_center(node: Node3D) -> Vector3:
	var combined_aabb := AABB()
	var found := false
	_collect_aabb(node, node.global_transform, combined_aabb, found)
	if found:
		return node.to_local(combined_aabb.get_center())
	return Vector3.ZERO


func _collect_aabb(node: Node, root_transform: Transform3D, combined: AABB, found: bool) -> void:
	if node is VisualInstance3D:
		var vi := node as VisualInstance3D
		var local_aabb := vi.get_aabb()
		var world_origin := vi.global_transform.origin + local_aabb.position
		if not found:
			combined = AABB(world_origin, local_aabb.size)
			found = true
		else:
			combined = combined.merge(AABB(world_origin, local_aabb.size))
	for child in node.get_children():
		_collect_aabb(child, root_transform, combined, found)


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	return warnings
