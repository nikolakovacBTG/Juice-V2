## Continuous-accumulation (Progress) effect for Control-domain nodes.
##
## Accumulates position, rotation, or scale at a configurable rate per second.
## progress acts as a speed multiplier (0=stopped, 1=full speed).

# =============================================================================
# WHAT: Control-domain continuous-accumulation (Progress) effect.
# WHY:  Defines a resource-based progress driver for Control targets.
# SYSTEM: Juice System (addons/Juice_V1/Control/)
# DOES NOT: Handle Node2D or Node3D targets.
# DOES NOT: Handle arbitrary property accumulation -- use ProgressPropertyJuiceEffectBase.
#
# PIVOT (ROTATION and SCALE only):
#   Uses the native Control.pivot_offset property. Reactive updates via the
#   Control's resized signal when auto-centering is active.
# =============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name ProgressControlJuiceEffect
extends JuiceControlTransformEffect


# =============================================================================
# ENUMS
# =============================================================================

# TransformTarget inherited from JuiceControlTransformEffect

# PivotMode inherited from JuiceControlTransformEffect

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
	PER_AXIS    ## Per-axis comparison (POSITION and SCALE only).
}


# =============================================================================
# CONFIGURATION
# =============================================================================

func _init() -> void:
	_subclass_owns_effect_group = true
	_leaf_owns_layout = true
	transform_target = TransformTarget.ROTATION  # Progress defaults to ROTATION not POSITION


# transform_target inherited from JuiceControlTransformEffect (default set to ROTATION in _init)

var auto_start: bool = false
var hold_on_stop: bool = true

# --- Rate vars ---
var position_rate: Vector2 = Vector2(50.0, 0.0)
var position_unit: int = PositionIn.PIXELS:
	set(value):
		position_unit = value
		notify_property_list_changed()
var rotation_rate: float = 90.0
var scale_rate: Vector2 = Vector2(0.1, 0.1)

# --- Pivot ---
# pivot_mode inherited from JuiceControlTransformEffect (default: AUTO_CENTER)
## Pivot in normalized Control size coords (0.5, 0.5 = center) for CUSTOM mode.
var custom_pivot: Vector2 = Vector2(0.5, 0.5)

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
var bound_value_vec2: Vector2 = Vector2(360.0, 360.0)


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
				"hint": PROPERTY_HINT_ENUM, "hint_string": "Pixels,Own Size,Parent Size,Viewport Size",
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "position_rate", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_DEFAULT})
		TransformTarget.ROTATION:
			props.append({"name": "rotation_rate", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_DEFAULT})
		TransformTarget.SCALE:
			props.append({"name": "scale_rate", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_DEFAULT})

	if transform_target != TransformTarget.POSITION:
		props.append({"name": "pivot_mode", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Auto Center,Inherit,Custom",
			"usage": PROPERTY_USAGE_DEFAULT})
		if pivot_mode == PivotMode.CUSTOM:
			props.append({"name": "custom_pivot", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_DEFAULT})

	props.append({"name": "bound_enabled", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})
	if bound_enabled:
		props.append({"name": "bound_behaviour", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Emit Completed,Reverse,Reverse Eased,Wrap,Stop,Destroy Parent",
			"usage": PROPERTY_USAGE_DEFAULT})
		if transform_target != TransformTarget.ROTATION:
			props.append({"name": "bound_mode", "type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM, "hint_string": "Magnitude,Per Axis",
				"usage": PROPERTY_USAGE_DEFAULT})
			if bound_mode == BoundMode.PER_AXIS:
				props.append({"name": "bound_value_vec2", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_DEFAULT})
			else:
				props.append({"name": "bound_value", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_DEFAULT})
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
		&"bound_value_vec2": bound_value_vec2 = value; return true
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
		&"bound_value_vec2": return bound_value_vec2
	return super._get(property)


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _accumulated_position: Vector2 = Vector2.ZERO
var _accumulated_rotation: float = 0.0  # radians
var _accumulated_scale: Vector2 = Vector2.ZERO
var _current_direction: float = 1.0
# _has_base inherited from JuiceControlTransformEffect
var _base_position: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0  # radians
var _base_scale: Vector2 = Vector2.ONE
var _pivot_resolved: bool = false
var _connected_control: Control = null
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

	_contributes_position = (transform_target == TransformTarget.POSITION)
	_contributes_rotation = (transform_target == TransformTarget.ROTATION)
	_contributes_scale = (transform_target == TransformTarget.SCALE)

	if debug_enabled:
		print("[ProgressControl] Start: %s dir=%.0f" % [TransformTarget.keys()[transform_target], _current_direction])


func _restore_to_natural(target: Node) -> void:
	_clear_deltas()
	if not hold_on_stop:
		_reset_accumulated()
		_has_base = false
		_pivot_resolved = false
		_disconnect_resized()


func _invalidate_base_cache() -> void:
	_has_base = false
	_pivot_resolved = false
	_disconnect_resized()
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
	var ctrl := target as Control
	if ctrl == null:
		return

	# When hold_on_stop=false and progress reaches 0 (animate_out at rest),
	# reset accumulated so the delta writes zero and target returns to natural.
	if not hold_on_stop and progress <= 0.0:
		_reset_accumulated()
		_clear_deltas()
		return

	var delta := _last_delta

	match transform_target:
		TransformTarget.POSITION:
			_accumulated_position += position_rate * delta * progress * _current_direction
			_pos_delta = _convert_to_pixels(_accumulated_position, position_unit, ctrl)

		TransformTarget.ROTATION:
			var speed_rad := deg_to_rad(rotation_rate) * progress * _current_direction
			_accumulated_rotation += speed_rad * delta
			_rot_delta = _accumulated_rotation

		TransformTarget.SCALE:
			_accumulated_scale += scale_rate * delta * progress * _current_direction
			_scale_delta = _accumulated_scale

	if bound_enabled and progress > 0.0:
		_check_bounds()


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
		print("[ProgressControl] Bound reached. Behaviour: %s" % BoundBehaviour.keys()[bound_behaviour])

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
			return _check_vec2_bound(_accumulated_position)
		TransformTarget.ROTATION:
			return absf(rad_to_deg(_accumulated_rotation)) > bound_value
		TransformTarget.SCALE:
			return _check_vec2_bound(_accumulated_scale)
	return false


func _check_vec2_bound(accumulated: Vector2) -> bool:
	if bound_mode == BoundMode.PER_AXIS:
		return absf(accumulated.x) > absf(bound_value_vec2.x) or \
			   absf(accumulated.y) > absf(bound_value_vec2.y)
	return accumulated.length() > bound_value


func _clamp_to_bound() -> void:
	match transform_target:
		TransformTarget.POSITION:
			_accumulated_position = _clamp_vec2(_accumulated_position)
		TransformTarget.ROTATION:
			var max_rad := deg_to_rad(bound_value)
			_accumulated_rotation = clampf(_accumulated_rotation, -max_rad, max_rad)
		TransformTarget.SCALE:
			_accumulated_scale = _clamp_vec2(_accumulated_scale)


func _clamp_vec2(accumulated: Vector2) -> Vector2:
	if bound_mode == BoundMode.PER_AXIS:
		return Vector2(
			clampf(accumulated.x, -absf(bound_value_vec2.x), absf(bound_value_vec2.x)),
			clampf(accumulated.y, -absf(bound_value_vec2.y), absf(bound_value_vec2.y))
		)
	var length := accumulated.length()
	if length > bound_value and length > 0.0:
		return accumulated.normalized() * bound_value
	return accumulated


func _wrap_accumulated() -> void:
	match transform_target:
		TransformTarget.POSITION:
			if bound_mode == BoundMode.PER_AXIS:
				_accumulated_position.x = fmod(_accumulated_position.x, absf(bound_value_vec2.x)) if absf(bound_value_vec2.x) > 0.0 else 0.0
				_accumulated_position.y = fmod(_accumulated_position.y, absf(bound_value_vec2.y)) if absf(bound_value_vec2.y) > 0.0 else 0.0
			else:
				_accumulated_position = Vector2.ZERO
		TransformTarget.ROTATION:
			var max_rad := deg_to_rad(bound_value)
			_accumulated_rotation = fmod(_accumulated_rotation, max_rad) if max_rad > 0.0 else 0.0
		TransformTarget.SCALE:
			if bound_mode == BoundMode.PER_AXIS:
				_accumulated_scale.x = fmod(_accumulated_scale.x, absf(bound_value_vec2.x)) if absf(bound_value_vec2.x) > 0.0 else 0.0
				_accumulated_scale.y = fmod(_accumulated_scale.y, absf(bound_value_vec2.y)) if absf(bound_value_vec2.y) > 0.0 else 0.0
			else:
				_accumulated_scale = Vector2.ZERO


# =============================================================================
# HELPERS
# =============================================================================

func _absorb_accumulated_into_base() -> void:
	match transform_target:
		TransformTarget.POSITION:
			_base_position += _accumulated_position
			_accumulated_position = Vector2.ZERO
		TransformTarget.ROTATION:
			_base_rotation += _accumulated_rotation
			_accumulated_rotation = 0.0
		TransformTarget.SCALE:
			_base_scale += _accumulated_scale
			_accumulated_scale = Vector2.ZERO


func _reset_accumulated() -> void:
	_accumulated_position = Vector2.ZERO
	_accumulated_rotation = 0.0
	_accumulated_scale = Vector2.ZERO


func _capture_base(target: Node) -> void:
	if _has_base:
		return
	var ctrl := target as Control
	if ctrl == null:
		push_warning("[ProgressControl] Cannot capture base -- target is not Control")
		return
	_base_position = ctrl.position
	_base_rotation = ctrl.rotation
	_base_scale = ctrl.scale
	_has_base = true
	if debug_enabled:
		print("[ProgressControl] Captured base -- pos:%s rot:%.1f- scale:%s" % [
			_base_position, rad_to_deg(_base_rotation), _base_scale])


# =============================================================================
# PIVOT HANDLING -- uses native Control.pivot_offset (reactive via resized)
# =============================================================================

func _resolve_pivot(target: Node) -> void:
	var ctrl := target as Control
	if ctrl == null:
		return
	_apply_pivot_mode(ctrl)
	_pivot_resolved = true
	if _connected_control != ctrl:
		_disconnect_resized()
		if not ctrl.resized.is_connected(_on_target_resized):
			ctrl.resized.connect(_on_target_resized.bind(ctrl))
		_connected_control = ctrl


func _apply_pivot_mode(ctrl: Control) -> void:
	match pivot_mode:
		PivotMode.AUTO_CENTER:
			ctrl.pivot_offset = ctrl.size / 2.0
		PivotMode.INHERIT:
			pass  # Leave existing pivot_offset untouched
		PivotMode.CUSTOM:
			ctrl.pivot_offset = Vector2(ctrl.size.x * custom_pivot.x, ctrl.size.y * custom_pivot.y)
	if debug_enabled:
		print("[ProgressControl] Pivot set to: %s" % ctrl.pivot_offset)


func _on_target_resized(ctrl: Control) -> void:
	_apply_pivot_mode(ctrl)


func _disconnect_resized() -> void:
	if _connected_control != null and is_instance_valid(_connected_control):
		if _connected_control.resized.is_connected(_on_target_resized):
			_connected_control.resized.disconnect(_on_target_resized)
	_connected_control = null


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	return warnings
