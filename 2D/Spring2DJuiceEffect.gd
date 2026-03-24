## Reactive physics-based spring animation for Node2D nodes.
# ============================================================================
# WHAT: Drives position, rotation, or scale of a Node2D with spring physics.
#       Purely reactive — sits idle until external displacement from stacked
#       Transform effects, other Juice nodes, or game logic.
# WHY: Unified spring component — one effect handles all transform targets.
# SYSTEM: Juicing System (addons/Juice_V1/)
# DOES NOT: Handle Control or Node3D targets — use SpringControl/Spring3DJuiceEffect.
# ============================================================================
#
# WRITE PATTERN: Delta-first. Spring simulation runs internally, delta stored
#   in _pos_delta / _rot_delta / _scale_delta. Domain node writes once per frame.
#
# PIVOT: Node2D has no native pivot. Position compensation simulates
#   rotation/scale around the pivot point — stored in _pos_delta.
#
# KEY CONCEPTS:
#   - Spring does NOT use easing curves or progress interpolation.
#   - Progress only serves as a maximum timeout.
#   - Spring settles when velocity and displacement drop below thresholds.
#   - Rotation can cross-read position displacement as torque when
#     center_of_gravity is offset from pivot.
#   - Swing range provides a soft clamp: restoring force increases non-linearly
#     near the boundary, preventing runaway oscillation.
#   - All torque calculations use ratios (fraction of bounding box), not pixels.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase2D.svg")
class_name Spring2DJuiceEffect
extends Juice2DTransformEffect


# =============================================================================
# ENUMS
# =============================================================================

## Which transform channel this spring reacts to.
enum TransformTarget {
	POSITION,
	ROTATION,
	SCALE
}

## How the visual pivot is determined for rotation/scale.
enum PivotMode {
	AUTO_CENTER,
	INHERIT,
	CUSTOM
}


# =============================================================================
# CONFIGURATION
# =============================================================================

## Which transform property this spring reacts to (position, rotation, or scale).
var transform_target: int = TransformTarget.POSITION:
	set(value):
		transform_target = value
		notify_property_list_changed()

# --- Spring physics ---
## Spring stiffness — higher values = faster return to rest, snappier feel.
var stiffness: float = 300.0
## Damping coefficient — higher values = less oscillation, faster settling.
var damping: float = 10.0
## Mass of the spring — higher values = slower, heavier movement.
var mass: float = 1.0

## How to interpret swing_range values for position mode.
var swing_range_in: int = OffsetUnit.PIXELS

## Per-axis maximum displacement before soft clamp engages.
## Position: interpreted per swing_range_in. Scale: absolute scale units.
var swing_range: Vector2 = Vector2(100.0, 100.0)

## Maximum rotation swing in degrees before soft clamp engages. Zero = unlimited.
var swing_range_degrees: float = 45.0

# --- Pivot (rotation/scale visual center) ---
## How the pivot point is calculated for rotation/scale transforms.
var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()

## Custom pivot offset in local pixels (Node2D has no native pivot).
var custom_pivot: Vector2 = Vector2.ZERO

## Center of gravity as fraction of bounding box (rotation only).
## Default (0.5, 0.5) = box center = balanced, no torque from position.
## Offset from pivot creates torque from position displacement.
var center_of_gravity: Vector2 = Vector2(0.5, 0.5)

# --- Settlement (Advanced) ---
## Velocity below this threshold is considered settled.
var velocity_threshold: float = 0.5
## Displacement below this threshold is considered settled.
var value_threshold: float = 0.1

func _init() -> void:
	_subclass_owns_effect_group = true


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	var is_pos := transform_target == TransformTarget.POSITION
	var is_rot := transform_target == TransformTarget.ROTATION
	var is_scale := transform_target == TransformTarget.SCALE

	props.append({"name": "Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "transform_target", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Position,Rotation,Scale",
		"usage": PROPERTY_USAGE_DEFAULT})

	# Base effect properties (trigger_behaviour, start_delay, etc.) — BEFORE Advanced
	props.append_array(_get_effect_base_properties())

	# Spring physics (always visible)
	props.append({"name": "stiffness", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "1.0,1000.0,1.0,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "damping", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,50.0,0.1,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "mass", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,10.0,0.1",
		"usage": PROPERTY_USAGE_DEFAULT})

	# Swing range (per target type)
	if is_rot:
		props.append({"name": "swing_range_degrees", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,360.0,0.1,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT})
	elif is_pos:
		props.append({"name": "swing_range_in", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Pixels,Own Size,Parent Size,Viewport Size",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "swing_range", "type": TYPE_VECTOR2,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,10000.0,0.1,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT})
	else:  # SCALE
		props.append({"name": "swing_range", "type": TYPE_VECTOR2,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,10.0,0.01,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT})

	# Pivot for rotation/scale
	if not is_pos:
		props.append({"name": "pivot_mode", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Auto Center,Inherit,Custom",
			"usage": PROPERTY_USAGE_DEFAULT})
		if pivot_mode == PivotMode.CUSTOM:
			props.append({"name": "custom_pivot", "type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT})

	# Center of gravity (rotation only — for torque from position displacement)
	if is_rot:
		props.append({"name": "center_of_gravity", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT})

	# Advanced subgroup — settlement thresholds only
	props.append({"name": "Advanced", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_SUBGROUP, "hint_string": ""})
	props.append({"name": "velocity_threshold", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.01,10.0,0.01",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "value_threshold", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.001,5.0,0.001",
		"usage": PROPERTY_USAGE_DEFAULT})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"transform_target": transform_target = value; return true
		&"stiffness": stiffness = value; return true
		&"damping": damping = value; return true
		&"mass": mass = value; return true
		&"swing_range_in": swing_range_in = value; return true
		&"swing_range":
			var v := value as Vector2
			swing_range = Vector2(maxf(v.x, 0.0), maxf(v.y, 0.0))
			return true
		&"swing_range_degrees": swing_range_degrees = maxf(value, 0.0); return true
		&"velocity_threshold": velocity_threshold = value; return true
		&"value_threshold": value_threshold = value; return true
		&"pivot_mode": pivot_mode = value; return true
		&"custom_pivot": custom_pivot = value; return true
		&"center_of_gravity": center_of_gravity = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"transform_target": return transform_target
		&"stiffness": return stiffness
		&"damping": return damping
		&"mass": return mass
		&"swing_range_in": return swing_range_in
		&"swing_range": return swing_range
		&"swing_range_degrees": return swing_range_degrees
		&"velocity_threshold": return velocity_threshold
		&"value_threshold": return value_threshold
		&"pivot_mode": return pivot_mode
		&"custom_pivot": return custom_pivot
		&"center_of_gravity": return center_of_gravity
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _tick_delta: float = 0.0
var _pivot_offset: Vector2 = Vector2.ZERO
var _base_scale: Vector2 = Vector2.ONE

# Resolved swing range in pixels/radians (computed once at animate_start)
var _resolved_swing_range: Vector2 = Vector2.ZERO
var _resolved_swing_range_rot: float = 0.0

# Spring simulation state — all values are DELTAS from natural (rest = 0)
var _current_pos: Vector2 = Vector2.ZERO
var _current_rot: float = 0.0
var _current_scale: Vector2 = Vector2.ZERO
var _vel_pos: Vector2 = Vector2.ZERO
var _vel_rot: float = 0.0
var _vel_scale: Vector2 = Vector2.ZERO

# Cached torque arm as RATIO (fraction of bounding box, dimensionless)
var _torque_arm_ratio: Vector2 = Vector2.ZERO

# Cached bounding box size for displacement normalization (rotation torque)
var _box_size: Vector2 = Vector2.ZERO

# True when displacement was received this frame — skip settlement check
var _received_impulse: bool = false


# =============================================================================
# TICK OVERRIDE
# =============================================================================

func tick(delta: float, target: Node) -> TickResult:
	_tick_delta = delta
	var result := super.tick(delta, target)
	if _in_hold_at_peak and _is_playing:
		_spring_step(_tick_delta)
		_write_deltas()
	return result


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

func _is_reactive() -> bool:
	return true


func _needs_sustain() -> bool:
	return true


func _on_external_displacement(displacement: Dictionary) -> void:
	_handle_displacement(displacement)


func _on_sibling_displacement(displacement: Dictionary) -> void:
	_handle_displacement(displacement)


func _handle_displacement(displacement: Dictionary) -> void:
	_received_impulse = true
	match transform_target:
		TransformTarget.POSITION:
			if displacement.has("position"):
				_current_pos -= displacement["position"] as Vector2
		TransformTarget.ROTATION:
			if displacement.has("rotation"):
				_current_rot -= displacement["rotation"] as float
			# Torque from position displacement (ratio-based)
			if displacement.has("position") and _torque_arm_ratio != Vector2.ZERO:
				var pos_disp := displacement["position"] as Vector2
				var disp_ratio := Vector2.ZERO
				if _box_size.x > 0.0:
					disp_ratio.x = pos_disp.x / _box_size.x
				if _box_size.y > 0.0:
					disp_ratio.y = pos_disp.y / _box_size.y
				var torque := _torque_arm_ratio.x * disp_ratio.y - _torque_arm_ratio.y * disp_ratio.x
				_vel_rot += torque / mass
		TransformTarget.SCALE:
			if displacement.has("scale"):
				_current_scale -= displacement["scale"] as Vector2


func _on_animate_start(target: Node) -> void:
	_contributes_position = (transform_target == TransformTarget.POSITION)
	_contributes_rotation = (transform_target == TransformTarget.ROTATION)
	_contributes_scale = (transform_target == TransformTarget.SCALE)

	# Capture base scale for pivot compensation
	var n2d := target as Node2D
	if n2d != null:
		_base_scale = n2d.scale

	if transform_target != TransformTarget.POSITION:
		_compute_pivot_offset(target)
		_contributes_position = (_contributes_position or _pivot_offset != Vector2.ZERO)

	# Resolve swing range to working units
	_resolve_swing_range(target)

	# Initialize at rest — spring is purely reactive
	_current_pos = Vector2.ZERO
	_current_rot = 0.0
	_current_scale = Vector2.ZERO
	_vel_pos = Vector2.ZERO
	_vel_rot = 0.0
	_vel_scale = Vector2.ZERO

	# Compute torque arm ratio for rotation (dimensionless)
	_torque_arm_ratio = Vector2.ZERO
	_box_size = Vector2.ZERO
	if transform_target == TransformTarget.ROTATION:
		_compute_torque_arm_ratio(target)

	if debug_enabled:
		print("[Spring2D] Start: %s, stiffness=%.0f, damping=%.0f, arm_ratio=%s" % [
			TransformTarget.keys()[transform_target], stiffness, damping, _torque_arm_ratio])


func _apply_effect(progress: float, _target: Node) -> void:
	_spring_step(_tick_delta)
	_write_deltas()

	# Check settlement (skip on frames where we just received an impulse)
	if not _received_impulse and _is_settled():
		_snap_to_rest()
		_write_deltas()
	_received_impulse = false


func _on_animate_in_complete(_target: Node) -> void:
	pass


func _on_animate_out_complete(_target: Node) -> void:
	_clear_deltas()


func _restore_to_natural(_target: Node) -> void:
	_clear_deltas()


func _invalidate_base_cache() -> void:
	_clear_deltas()


func _get_interrupt_identity() -> Variant:
	return [get_script(), transform_target]


# =============================================================================
# SPRING SIMULATION
# =============================================================================

func _spring_step(delta: float) -> void:
	if delta <= 0.0:
		return
	match transform_target:
		TransformTarget.POSITION:
			_spring_step_pos(delta)
		TransformTarget.ROTATION:
			_spring_step_rot(delta)
		TransformTarget.SCALE:
			_spring_step_scale(delta)


func _spring_step_pos(delta: float) -> void:
	var eff_stiffness := _soft_clamp_stiffness_vec2(_current_pos, _resolved_swing_range)
	var acceleration := (-_current_pos * eff_stiffness - _vel_pos * damping) / mass
	_vel_pos += acceleration * delta
	_current_pos += _vel_pos * delta


func _spring_step_scale(delta: float) -> void:
	var eff_stiffness := _soft_clamp_stiffness_vec2(_current_scale, swing_range)
	var acceleration := (-_current_scale * eff_stiffness - _vel_scale * damping) / mass
	_vel_scale += acceleration * delta
	_current_scale += _vel_scale * delta


func _spring_step_rot(delta: float) -> void:
	var eff_stiffness := _soft_clamp_stiffness_float(_current_rot, _resolved_swing_range_rot)
	var acceleration := (-_current_rot * eff_stiffness - _vel_rot * damping) / mass
	_vel_rot += acceleration * delta
	_current_rot += _vel_rot * delta


# --- Soft clamp: non-linear stiffness increase near swing_range boundary ---

func _soft_clamp_stiffness_vec2(current: Vector2, range_limit: Vector2) -> Vector2:
	if range_limit == Vector2.ZERO:
		return Vector2(stiffness, stiffness)
	var ratio := Vector2(
		current.x / range_limit.x if range_limit.x != 0.0 else 0.0,
		current.y / range_limit.y if range_limit.y != 0.0 else 0.0)
	return Vector2(
		stiffness * (1.0 + ratio.x * ratio.x),
		stiffness * (1.0 + ratio.y * ratio.y))


func _soft_clamp_stiffness_float(current: float, range_limit: float) -> float:
	if range_limit <= 0.0:
		return stiffness
	var ratio := current / range_limit
	return stiffness * (1.0 + ratio * ratio)


# --- Settlement ---

func _is_settled() -> bool:
	match transform_target:
		TransformTarget.POSITION:
			return _vel_pos.length() < velocity_threshold and _current_pos.length() < value_threshold
		TransformTarget.ROTATION:
			return absf(_vel_rot) < velocity_threshold and absf(_current_rot) < value_threshold
		TransformTarget.SCALE:
			return _vel_scale.length() < velocity_threshold and _current_scale.length() < value_threshold
	return false


func _snap_to_rest() -> void:
	match transform_target:
		TransformTarget.POSITION:
			_current_pos = Vector2.ZERO; _vel_pos = Vector2.ZERO
		TransformTarget.ROTATION:
			_current_rot = 0.0; _vel_rot = 0.0
		TransformTarget.SCALE:
			_current_scale = Vector2.ZERO; _vel_scale = Vector2.ZERO


func _write_deltas() -> void:
	match transform_target:
		TransformTarget.POSITION:
			_pos_delta = _current_pos
		TransformTarget.ROTATION:
			_rot_delta = _current_rot
			# Position compensation for pivot
			if _pivot_offset != Vector2.ZERO:
				_pos_delta = _pivot_offset - _pivot_offset.rotated(_current_rot)
		TransformTarget.SCALE:
			_scale_delta = _current_scale
			# Position compensation for pivot
			if _pivot_offset != Vector2.ZERO:
				var new_scale := _base_scale + _current_scale
				var scale_ratio := new_scale / _base_scale
				_pos_delta = _pivot_offset - _pivot_offset * scale_ratio


# =============================================================================
# SWING RANGE RESOLUTION
# =============================================================================

func _resolve_swing_range(target: Node) -> void:
	_resolved_swing_range_rot = deg_to_rad(swing_range_degrees)
	if transform_target != TransformTarget.POSITION:
		_resolved_swing_range = swing_range
		return
	# Position: resolve swing_range using OffsetUnit
	match swing_range_in:
		OffsetUnit.PIXELS:
			_resolved_swing_range = swing_range
		OffsetUnit.OWN_SIZE:
			var box := _estimate_bounding_box(target)
			_resolved_swing_range = swing_range * box if box != Vector2.ZERO else swing_range
		OffsetUnit.PARENT_SIZE:
			var parent_n2d := target.get_parent() as Node2D if is_instance_valid(target) else null
			if parent_n2d != null:
				var parent_box := _estimate_bounding_box(parent_n2d)
				_resolved_swing_range = swing_range * parent_box if parent_box != Vector2.ZERO else swing_range
			else:
				_resolved_swing_range = swing_range
		OffsetUnit.VIEWPORT_SIZE:
			if is_instance_valid(target):
				var vp := target.get_viewport()
				if vp != null:
					_resolved_swing_range = swing_range * Vector2(vp.get_visible_rect().size)
				else:
					_resolved_swing_range = swing_range
			else:
				_resolved_swing_range = swing_range


# =============================================================================
# TORQUE ARM — ratio-based (rotation only)
# =============================================================================

func _compute_torque_arm_ratio(target: Node) -> void:
	_torque_arm_ratio = Vector2.ZERO
	if not is_instance_valid(target):
		return
	_box_size = _estimate_bounding_box(target)
	if _box_size == Vector2.ZERO:
		return
	# CoG as fraction (already 0–1)
	var cog_ratio := center_of_gravity
	# Pivot as fraction of bounding box
	# For Node2D with AUTO_CENTER pivot, pivot_offset is the visual center
	# which maps to (0.5, 0.5) ratio when centered
	var pivot_ratio := Vector2(0.5, 0.5)  # Default for AUTO_CENTER
	if pivot_mode == PivotMode.CUSTOM and _box_size != Vector2.ZERO:
		pivot_ratio = _pivot_offset / _box_size
	elif pivot_mode == PivotMode.INHERIT:
		pivot_ratio = Vector2.ZERO  # Origin
	_torque_arm_ratio = cog_ratio - pivot_ratio


func _estimate_bounding_box(target: Node) -> Vector2:
	for child in target.get_children():
		if child is Sprite2D and (child as Sprite2D).texture != null:
			return (child as Sprite2D).texture.get_size()
	return Vector2.ZERO


# =============================================================================
# PIVOT HELPERS
# =============================================================================

func _compute_pivot_offset(target: Node) -> void:
	match pivot_mode:
		PivotMode.INHERIT:
			_pivot_offset = Vector2.ZERO
		PivotMode.CUSTOM:
			_pivot_offset = custom_pivot
		PivotMode.AUTO_CENTER:
			_pivot_offset = _estimate_visual_center(target)


func _estimate_visual_center(target: Node) -> Vector2:
	if not is_instance_valid(target):
		return Vector2.ZERO
	for child in target.get_children():
		if child is Sprite2D and (child as Sprite2D).texture != null:
			var spr := child as Sprite2D
			if spr.centered:
				return spr.position
			else:
				return spr.position + spr.texture.get_size() / 2.0
	return Vector2.ZERO
