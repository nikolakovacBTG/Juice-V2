## Reactive physics-based spring animation for Control nodes.
# ============================================================================
# WHAT: Drives position, rotation, or scale of a Control with spring physics.
#       Purely reactive — sits idle until external displacement from stacked
#       Transform effects, other Juice nodes, or game logic.
# WHY: Unified spring component — one effect handles all transform targets.
# SYSTEM: Juicing System (addons/Juice_V1/)
# DOES NOT: Handle Node2D or Node3D targets — use Spring2D/3DJuiceEffect.
# ============================================================================
#
# WRITE PATTERN: Delta-first. Spring simulation runs internally, delta stored
#   in _pos_delta / _rot_delta / _scale_delta. Domain node writes once per frame.
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
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name SpringControlJuiceEffect
extends JuiceControlTransformEffect


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
var swing_range_in: int = OffsetUnit.OWN_SIZE

## Per-axis maximum displacement before soft clamp engages.
## Position: interpreted per swing_range_in. Scale: absolute scale units.
var swing_range: Vector2 = Vector2(1.0, 1.0)

## Maximum rotation swing in degrees before soft clamp engages. Zero = unlimited.
var swing_range_degrees: float = 45.0

# --- Pivot (rotation/scale visual center) ---
## How the pivot point is calculated for rotation/scale transforms.
var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()

## Custom pivot as fraction of Control size (0.5, 0.5 = center).
var custom_pivot: Vector2 = Vector2(0.5, 0.5)

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
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,100.0,0.01,or_greater",
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
var _pivot_applied: bool = false

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

# Cached torque arm in pixel space (from rotation pivot to CoG)
var _torque_arm: Vector2 = Vector2.ZERO
# Length squared of torque arm for moment of inertia normalization
var _torque_arm_len_sq: float = 0.0

# Frames remaining before settlement checks resume after last impulse.
# Prevents the spring from snapping to rest before visible overshoot.
var _impulse_cooldown: int = 0
const IMPULSE_COOLDOWN_FRAMES: int = 5


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
	_impulse_cooldown = IMPULSE_COOLDOWN_FRAMES
	match transform_target:
		TransformTarget.POSITION:
			if displacement.has("position"):
				_current_pos -= displacement["position"] as Vector2
		TransformTarget.ROTATION:
			if displacement.has("rotation"):
				_current_rot -= displacement["rotation"] as float
			# Torque from position displacement (pixel-space, moment of inertia normalized)
			if displacement.has("position") and _torque_arm != Vector2.ZERO and _torque_arm_len_sq > 0.0:
				var pos_disp := displacement["position"] as Vector2
				# 2D cross product: arm × displacement → torque (pixels²)
				var torque := _torque_arm.x * pos_disp.y - _torque_arm.y * pos_disp.x
				# Normalize by moment of inertia (mass * r²)
				_vel_rot += torque / (mass * _torque_arm_len_sq)
		TransformTarget.SCALE:
			if displacement.has("scale"):
				_current_scale -= displacement["scale"] as Vector2


func _on_animate_start(target: Node) -> void:
	_contributes_position = (transform_target == TransformTarget.POSITION)
	_contributes_rotation = (transform_target == TransformTarget.ROTATION)
	_contributes_scale = (transform_target == TransformTarget.SCALE)

	if transform_target != TransformTarget.POSITION and not _pivot_applied:
		_apply_pivot_mode(target)
		_pivot_applied = true

	# Resolve swing range to working units
	_resolve_swing_range(target)

	# Initialize at rest — spring is purely reactive
	_current_pos = Vector2.ZERO
	_current_rot = 0.0
	_current_scale = Vector2.ZERO
	_vel_pos = Vector2.ZERO
	_vel_rot = 0.0
	_vel_scale = Vector2.ZERO
	_impulse_cooldown = 0

	# Compute torque arm for rotation (pixel-space)
	_torque_arm = Vector2.ZERO
	_torque_arm_len_sq = 0.0
	if transform_target == TransformTarget.ROTATION:
		_compute_torque_arm(target)

	if debug_enabled:
		print("[SpringCtrl] Start: %s, stiffness=%.0f, damping=%.0f, arm=%s" % [
			TransformTarget.keys()[transform_target], stiffness, damping, _torque_arm])


func _apply_effect(progress: float, _target: Node) -> void:
	_spring_step(_tick_delta)
	_write_deltas()

	# Check settlement (skip while impulse cooldown is active)
	if _impulse_cooldown > 0:
		_impulse_cooldown -= 1
	elif _is_settled():
		_snap_to_rest()
		_write_deltas()


func _on_animate_in_complete(_target: Node) -> void:
	pass


func _on_animate_out_complete(_target: Node) -> void:
	_clear_deltas()
	_pivot_applied = false


func _restore_to_natural(_target: Node) -> void:
	_clear_deltas()


func _invalidate_base_cache() -> void:
	_pivot_applied = false
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
		TransformTarget.SCALE:
			_scale_delta = _current_scale


# =============================================================================
# SWING RANGE RESOLUTION
# =============================================================================

func _resolve_swing_range(target: Node) -> void:
	_resolved_swing_range_rot = deg_to_rad(swing_range_degrees)
	if transform_target != TransformTarget.POSITION:
		_resolved_swing_range = swing_range
		return
	# Position: resolve swing_range using OffsetUnit
	var ctrl := target as Control
	if ctrl == null:
		_resolved_swing_range = swing_range
		return
	match swing_range_in:
		OffsetUnit.PIXELS:
			_resolved_swing_range = swing_range
		OffsetUnit.OWN_SIZE:
			_resolved_swing_range = swing_range * ctrl.size
		OffsetUnit.PARENT_SIZE:
			var parent_ctrl := ctrl.get_parent() as Control
			if parent_ctrl != null:
				_resolved_swing_range = swing_range * parent_ctrl.size
			else:
				_resolved_swing_range = swing_range
		OffsetUnit.VIEWPORT_SIZE:
			var vp := ctrl.get_viewport()
			if vp != null:
				_resolved_swing_range = swing_range * Vector2(vp.get_visible_rect().size)
			else:
				_resolved_swing_range = swing_range


# =============================================================================
# TORQUE ARM — pixel-space (rotation only)
# =============================================================================

func _compute_torque_arm(target: Node) -> void:
	var ctrl := target as Control
	if ctrl == null:
		_torque_arm = Vector2.ZERO
		_torque_arm_len_sq = 0.0
		return
	var box_size := ctrl.size
	if box_size == Vector2.ZERO:
		_torque_arm = Vector2.ZERO
		_torque_arm_len_sq = 0.0
		return
	# CoG position in pixels
	var cog_px := center_of_gravity * box_size
	# Pivot position in pixels
	var pivot_px := ctrl.pivot_offset
	# Arm = CoG - pivot (pixel-space vector)
	_torque_arm = cog_px - pivot_px
	_torque_arm_len_sq = _torque_arm.length_squared()


# =============================================================================
# PIVOT (Control uses native pivot_offset)
# =============================================================================

func _apply_pivot_mode(target: Node) -> void:
	var ctrl := target as Control
	if ctrl == null:
		return
	match pivot_mode:
		PivotMode.AUTO_CENTER:
			ctrl.pivot_offset = ctrl.size / 2.0
		PivotMode.CUSTOM:
			ctrl.pivot_offset = ctrl.size * custom_pivot
		PivotMode.INHERIT:
			pass
