## Continuous-accumulation (Progress) helper for 2D-domain transform effects.
##
## Handles speed-multiplier accumulation, bound system, auto_start, hold_on_stop,
## and REVERSE_EASED ping-pong for Node2D position/rotation/scale targets.

# =============================================================================
# WHAT: 2D-domain continuous-accumulation (Progress) effect.
# WHY:  Ports Progress2DJuiceComp to V1 Resource architecture.
#       Uses Juice2DTransformEffect delta system for stackable, host-written output.
#       progress = speed multiplier (not lerp factor):
#       value += rate * delta * progress * direction
# SYSTEM: Juice System (addons/Juice_V1/2D/)
# DOES NOT: Handle Control or Node3D transforms.
# DOES NOT: Handle arbitrary property accumulation -- use ProgressPropertyJuiceEffectBase.
#
# SUSTAIN MODEL:
#   _needs_sustain() returns true -- host keeps ticking at progress=1.0 indefinitely.
#   animate_out() ramps progress 1-0 (deceleration), holding accumulated state.
#
# BOUND SYSTEM:
#   Checks accumulated magnitude each frame. On REVERSE_EASED, effect absorbs
#   accumulated into base, flips direction, returns RESTART_REVERSED so the host
#   restarts animate_in for seamless ping-pong.
#
# PIVOT (ROTATION + SCALE):
#   Node2D has no native pivot. Pivot is simulated via position compensation:
#   Rotation: new_pos = fixed_pivot - pivot.rotated(new_rotation)
#   Scale:    new_pos = fixed_pivot - pivot * new_scale_ratio
#   AUTO_CENTER infers visual center from Sprite2D/CollisionShape2D/etc.
# =============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase2D.svg")
class_name Progress2DJuiceEffect
extends Juice2DTransformEffect


# =============================================================================
# ENUMS
# =============================================================================

## Which transform property to accumulate.
enum TransformTarget {
	POSITION,  ## Accumulate Node2D.position (Vector2 drift).
	ROTATION,  ## Accumulate Node2D.rotation (single-axis Z, degrees/sec).
	SCALE      ## Accumulate Node2D.scale (Vector2 growth/shrink).
}

## How the pivot point is determined for rotation/scale.
enum PivotMode {
	AUTO_CENTER,  ## Infer visual center from Sprite2D/CollisionShape2D/Polygon2D.
	INHERIT,      ## Rotate/scale from node origin (no position compensation).
	CUSTOM        ## Rotate/scale from custom_pivot (local pixels).
}

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


# --- Transform target selector (always visible) ---
## Which transform property to accumulate.
var transform_target: int = TransformTarget.ROTATION:
	set(value):
		transform_target = value
		notify_property_list_changed()

## Start accumulating at full speed immediately when the scene starts,
## without an explicit animate_in() call.
var auto_start: bool = false

## When true (default), stopping the effect holds the accumulated visual state.
## When false, stop() snaps back to the original natural state.
var hold_on_stop: bool = true

# --- Rate vars (shown per target via _get_property_list) ---
## Units per second of position drift.
var position_rate: Vector2 = Vector2(50.0, 0.0)
var position_unit: int = PositionIn.PIXELS:
	set(value):
		position_unit = value
		notify_property_list_changed()
## Degrees per second of rotation. Positive = clockwise.
var rotation_rate: float = 90.0
## Scale units per second of growth/shrink per axis.
var scale_rate: Vector2 = Vector2(0.1, 0.1)

# --- Pivot (shown for ROTATION and SCALE) ---
## How the pivot is determined.
var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()
## Pivot in local-space pixels when pivot_mode = CUSTOM.
var custom_pivot: Vector2 = Vector2.ZERO

# --- Bound vars (shown conditionally) ---
## Enable bound checking.
var bound_enabled: bool = false:
	set(value):
		bound_enabled = value
		notify_property_list_changed()
## What happens when the bound is reached.
var bound_behaviour: int = BoundBehaviour.REVERSE
## How the bound distance is measured (POSITION and SCALE only).
var bound_mode: int = BoundMode.MAGNITUDE:
	set(value):
		bound_mode = value
		notify_property_list_changed()
## Bound distance as a single magnitude (degrees for ROTATION, pixels/units for others).
var bound_value: float = 360.0
## Bound per-axis (used when bound_mode = PER_AXIS for POSITION/SCALE).
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

	props.append({"name": "Rate", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	match transform_target:
		TransformTarget.POSITION:
			props.append({"name": "position_rate", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "position_unit", "type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM, "hint_string": "Pixels,Own Size,Parent Size,Viewport Size",
				"usage": PROPERTY_USAGE_DEFAULT})
		TransformTarget.ROTATION:
			props.append({"name": "rotation_rate", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_DEFAULT})
		TransformTarget.SCALE:
			props.append({"name": "scale_rate", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_DEFAULT})

	if transform_target != TransformTarget.POSITION:
		props.append({"name": "Pivot", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
		props.append({"name": "pivot_mode", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Auto Center,Inherit,Custom",
			"usage": PROPERTY_USAGE_DEFAULT})
		if pivot_mode == PivotMode.CUSTOM:
			props.append({"name": "custom_pivot", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_DEFAULT})

	props.append({"name": "Bound", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
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

## Accumulated change from base (grows every frame at full speed).
var _accumulated_position: Vector2 = Vector2.ZERO
var _accumulated_rotation: float = 0.0  # radians
var _accumulated_scale: Vector2 = Vector2.ZERO

## Direction multiplier: +1.0 forward, -1.0 reverse (flipped by REVERSE bound).
var _current_direction: float = 1.0

## Whether base values have been captured.
var _has_base: bool = false

## Captured natural base values (captured once at animation start).
var _base_position: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0  # radians
var _base_scale: Vector2 = Vector2.ONE

## Resolved pivot point in target's local space.
var _pivot_point: Vector2 = Vector2.ZERO
var _pivot_resolved: bool = false

## Fixed pivot in parent space (pre-computed at animation start for correct arc).
var _fixed_pivot_parent: Vector2 = Vector2.ZERO

## Re-entrance guard: skip bound checks during REVERSE_EASED restart.
var _awaiting_reverse_eased: bool = false

## Signal to parent tick() that RESTART_REVERSED should be returned.
var _pending_restart_reversed: bool = false

## Stores delta from tick() for use in _apply_effect() -- Resources have no process().
var _last_delta: float = 0.0


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

## Progress effects need continuous ticking after animate_in completes.
func _needs_sustain() -> bool:
	return true


func _on_animate_start(target: Node) -> void:
	if not _has_base:
		_capture_base(target)
	# Resolve pivot for rotation/scale
	if transform_target != TransformTarget.POSITION and not _pivot_resolved:
		_resolve_pivot(target)
		_pivot_resolved = true
	# Pre-compute fixed pivot in parent space for correct rotation arc
	if transform_target == TransformTarget.ROTATION and _pivot_point != Vector2.ZERO:
		_fixed_pivot_parent = _base_position + _pivot_point.rotated(_base_rotation)
	elif transform_target == TransformTarget.SCALE and _pivot_point != Vector2.ZERO:
		_fixed_pivot_parent = _base_position + _pivot_point

	_contributes_position = (transform_target == TransformTarget.POSITION)
	_contributes_rotation = (transform_target == TransformTarget.ROTATION)
	_contributes_scale = (transform_target == TransformTarget.SCALE)
	# Pivot compensation contributes position even for rotation/scale targets
	if transform_target != TransformTarget.POSITION and _pivot_point != Vector2.ZERO:
		_contributes_position = true

	if debug_enabled:
		print("[Progress2D] Start: %s dir=%.0f" % [TransformTarget.keys()[transform_target], _current_direction])


## Sets deltas to 0 and optionally writes natural state back.
func _restore_to_natural(target: Node) -> void:
	_clear_deltas()
	if not hold_on_stop:
		_reset_accumulated()
		_has_base = false
		_pivot_resolved = false
		# Write natural state via domain node
		_pos_delta = Vector2.ZERO
		_rot_delta = 0.0
		_scale_delta = Vector2.ZERO


func _invalidate_base_cache() -> void:
	_has_base = false
	_pivot_resolved = false
	_clear_deltas()


## Progress tick: delegate to super (handles easing ramp), then propagate
## any RESTART_REVERSED flag set inside _apply_effect() - _check_bounds().
func tick(delta: float, target: Node) -> JuiceEffectBase.TickResult:
	_last_delta = delta
	_pending_restart_reversed = false
	var result := super.tick(delta, target)
	if _pending_restart_reversed:
		_pending_restart_reversed = false
		return JuiceEffectBase.TickResult.RESTART_REVERSED
	return result


# =============================================================================
# APPLY EFFECT -- accumulation per frame
# =============================================================================

## Called every tick by super.tick(). progress = speed multiplier (0..1).
## Accumulates transform, stores delta for domain node to write.
func _apply_effect(progress: float, target: Node) -> void:
	var n2d := target as Node2D
	if n2d == null:
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
			_pos_delta = _convert_to_world_pixels(_accumulated_position, position_unit, n2d)

		TransformTarget.ROTATION:
			var speed_rad := deg_to_rad(rotation_rate) * progress * _current_direction
			_accumulated_rotation += speed_rad * delta
			_rot_delta = _accumulated_rotation
			if _pivot_point != Vector2.ZERO:
				var new_rot := _base_rotation + _accumulated_rotation
				_pos_delta = _fixed_pivot_parent - _pivot_point.rotated(new_rot) - _base_position

		TransformTarget.SCALE:
			_accumulated_scale += scale_rate * delta * progress * _current_direction
			_scale_delta = _accumulated_scale
			if _pivot_point != Vector2.ZERO:
				var new_scale := _base_scale + _accumulated_scale
				var scale_ratio := new_scale / _base_scale if _base_scale != Vector2.ZERO else Vector2.ONE
				_pos_delta = _pivot_point * (Vector2.ONE - scale_ratio)

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
		print("[Progress2D] Bound reached. Behaviour: %s" % BoundBehaviour.keys()[bound_behaviour])

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

## Absorb accumulated into base, making current position the new pivot for bounds.
func _absorb_accumulated_into_base() -> void:
	match transform_target:
		TransformTarget.POSITION:
			_base_position += _accumulated_position
			_accumulated_position = Vector2.ZERO
		TransformTarget.ROTATION:
			_base_rotation += _accumulated_rotation
			_accumulated_rotation = 0.0
			# Recompute fixed pivot parent for the new base rotation
			if _pivot_point != Vector2.ZERO:
				_fixed_pivot_parent = _base_position + _pivot_point.rotated(_base_rotation)
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
	var n2d := target as Node2D
	if n2d == null:
		push_warning("[Progress2D] Cannot capture base -- target is not Node2D")
		return
	_base_position = n2d.position
	_base_rotation = n2d.rotation
	_base_scale = n2d.scale
	_has_base = true
	if debug_enabled:
		print("[Progress2D] Captured base -- pos:%s rot:%.1f- scale:%s" % [
			_base_position, rad_to_deg(_base_rotation), _base_scale])


# =============================================================================
# PIVOT HANDLING -- position compensation for Node2D (no native pivot_offset)
# =============================================================================

func _resolve_pivot(target: Node) -> void:
	var n2d := target as Node2D
	if n2d == null:
		return
	match pivot_mode:
		PivotMode.AUTO_CENTER:
			_pivot_point = _infer_node2d_center(n2d)
		PivotMode.INHERIT:
			_pivot_point = Vector2.ZERO
		PivotMode.CUSTOM:
			_pivot_point = custom_pivot


## Infer visual center from child/self Sprite2D, CollisionShape2D, Polygon2D, etc.
func _infer_node2d_center(node: Node2D) -> Vector2:
	# Check the node itself first
	var size := _get_node2d_size(node)
	if size != Vector2.ZERO:
		return size / 2.0
	# Check children
	for child in node.get_children():
		if child is Node2D:
			var child_size := _get_node2d_size(child as Node2D)
			if child_size != Vector2.ZERO:
				return (child as Node2D).position + child_size / 2.0
	return Vector2.ZERO


func _get_node2d_size(node: Node2D) -> Vector2:
	if node is Sprite2D:
		var spr := node as Sprite2D
		if spr.texture != null:
			var tex_size := Vector2(spr.texture.get_width(), spr.texture.get_height())
			if spr.region_enabled:
				tex_size = spr.region_rect.size
			return tex_size * spr.scale / float(spr.hframes) * Vector2(1.0 / spr.hframes, 1.0 / spr.vframes) * float(spr.hframes)
	elif node is CollisionShape2D:
		var cs := node as CollisionShape2D
		if cs.shape is RectangleShape2D:
			return (cs.shape as RectangleShape2D).size
		elif cs.shape is CircleShape2D:
			var r := (cs.shape as CircleShape2D).radius
			return Vector2(r * 2.0, r * 2.0)
		elif cs.shape is CapsuleShape2D:
			var cap := cs.shape as CapsuleShape2D
			return Vector2(cap.radius * 2.0, cap.height)
	return Vector2.ZERO


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if auto_start and not Engine.is_editor_hint():
		pass  # Valid usage -- no warning needed
	return warnings
