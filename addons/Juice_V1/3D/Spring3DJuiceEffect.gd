## Reactive physics-based spring animation for Node3D nodes.
# ============================================================================
# WHAT: Drives position, rotation, or scale of a Node3D with spring physics.
#       Purely reactive — sits idle until external displacement from stacked
#       Transform effects, other Juice nodes, or game logic.
# WHY: Unified spring component — one effect handles all transform targets.
# SYSTEM: Juicing System (addons/Juice_V1/)
# DOES NOT: Handle Control or Node2D targets — use SpringControl/Spring2DJuiceEffect.
# ============================================================================
#
# WRITE PATTERN: Delta-first. Spring simulation runs internally, delta stored
#   in _pos_delta / _rot_delta / _scale_delta. Domain node writes once per frame.
#
# PIVOT: Node3D has no native pivot. Rotation uses rotation_pivot_offset.
#   Scale uses PivotMode enum with position compensation.
#
# KEY CONCEPTS:
#   - Spring does NOT use easing curves or progress interpolation.
#   - Progress only serves as a maximum timeout.
#   - Spring settles when velocity and displacement drop below thresholds.
#   - Rotation can cross-read position displacement as torque when
#     center_of_gravity is offset from rotation pivot.
#   - Swing range provides a soft clamp: restoring force increases non-linearly
#     near the boundary, preventing runaway oscillation.
#   - Torque uses normalized arm (center_of_gravity is already in local units).
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name Spring3DJuiceEffect
extends Juice3DTransformEffect


# =============================================================================
# ENUMS
# =============================================================================

## Which transform channel this spring reacts to.
enum TransformTarget {
	POSITION,
	ROTATION,
	SCALE
}

## How the scale pivot is determined.
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

## Per-axis maximum displacement in world units before soft clamp engages.
var swing_range: Vector3 = Vector3(1.0, 1.0, 1.0)

## Per-axis maximum rotation swing in degrees before soft clamp engages.
var swing_range_degrees: Vector3 = Vector3(45.0, 45.0, 45.0)

# --- Rotation pivot ---
## Rotation pivot offset in local space. Rotation happens around this point.
var rotation_pivot_offset: Vector3 = Vector3.ZERO

# --- Scale pivot ---
## How the scale pivot is determined.
var scale_pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		scale_pivot_mode = value
		notify_property_list_changed()

## Custom scale pivot in local space.
var scale_custom_pivot: Vector3 = Vector3.ZERO

## Center of gravity in local space (rotation only).
## Default (0,0,0) = at pivot = balanced, no torque from position.
## Offset from pivot creates torque from position displacement.
var center_of_gravity: Vector3 = Vector3.ZERO

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
	if is_pos:
		props.append({"name": "swing_range", "type": TYPE_VECTOR3,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,100.0,0.01,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT})
	elif is_rot:
		props.append({"name": "swing_range_degrees", "type": TYPE_VECTOR3,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,360.0,0.1,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT})
	elif is_scale:
		props.append({"name": "swing_range", "type": TYPE_VECTOR3,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,10.0,0.01,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT})

	# Rotation pivot + CoG
	if is_rot:
		props.append({"name": "rotation_pivot_offset", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "center_of_gravity", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT})

	# Scale pivot
	if is_scale:
		props.append({"name": "scale_pivot_mode", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Auto Center,Inherit,Custom",
			"usage": PROPERTY_USAGE_DEFAULT})
		if scale_pivot_mode == PivotMode.CUSTOM:
			props.append({"name": "scale_custom_pivot", "type": TYPE_VECTOR3,
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
		&"swing_range":
			var v := value as Vector3
			swing_range = Vector3(maxf(v.x, 0.0), maxf(v.y, 0.0), maxf(v.z, 0.0))
			return true
		&"swing_range_degrees":
			var v := value as Vector3
			swing_range_degrees = Vector3(maxf(v.x, 0.0), maxf(v.y, 0.0), maxf(v.z, 0.0))
			return true
		&"rotation_pivot_offset": rotation_pivot_offset = value; return true
		&"scale_pivot_mode": scale_pivot_mode = value; return true
		&"scale_custom_pivot": scale_custom_pivot = value; return true
		&"center_of_gravity": center_of_gravity = value; return true
		&"velocity_threshold": velocity_threshold = value; return true
		&"value_threshold": value_threshold = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"transform_target": return transform_target
		&"stiffness": return stiffness
		&"damping": return damping
		&"mass": return mass
		&"swing_range": return swing_range
		&"swing_range_degrees": return swing_range_degrees
		&"rotation_pivot_offset": return rotation_pivot_offset
		&"scale_pivot_mode": return scale_pivot_mode
		&"scale_custom_pivot": return scale_custom_pivot
		&"center_of_gravity": return center_of_gravity
		&"velocity_threshold": return velocity_threshold
		&"value_threshold": return value_threshold
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _tick_delta: float = 0.0
var _scale_pivot_point: Vector3 = Vector3.ZERO
var _base_scale: Vector3 = Vector3.ONE
var _base_basis: Basis = Basis.IDENTITY

# Resolved swing range in radians (rotation only)
var _resolved_swing_range_rot: Vector3 = Vector3.ZERO

# Spring simulation state — all values are DELTAS from natural (rest = 0)
var _current_pos: Vector3 = Vector3.ZERO
var _current_rot: Vector3 = Vector3.ZERO
var _current_scale: Vector3 = Vector3.ZERO
var _vel_pos: Vector3 = Vector3.ZERO
var _vel_rot: Vector3 = Vector3.ZERO
var _vel_scale: Vector3 = Vector3.ZERO

# Cached torque arm in local space (from rotation pivot to CoG)
var _torque_arm: Vector3 = Vector3.ZERO
# Length squared of torque arm for moment of inertia normalization
var _torque_arm_len_sq: float = 0.0

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
				_current_pos -= displacement["position"] as Vector3
		TransformTarget.ROTATION:
			if displacement.has("rotation"):
				_current_rot -= displacement["rotation"] as Vector3
			# Torque from position displacement (normalized by moment of inertia)
			if displacement.has("position") and _torque_arm != Vector3.ZERO and _torque_arm_len_sq > 0.0:
				var pos_disp := displacement["position"] as Vector3
				# 3D cross product: arm × displacement → torque vector
				var torque := _torque_arm.cross(pos_disp)
				# Normalize by moment of inertia (mass * r²)
				_vel_rot += torque / (mass * _torque_arm_len_sq)
		TransformTarget.SCALE:
			if displacement.has("scale"):
				_current_scale -= displacement["scale"] as Vector3


func _on_animate_start(target: Node) -> void:
	_contributes_position = (transform_target == TransformTarget.POSITION)
	_contributes_rotation = (transform_target == TransformTarget.ROTATION)
	_contributes_scale = (transform_target == TransformTarget.SCALE)

	var n3d := target as Node3D
	if n3d != null:
		_base_scale = n3d.scale
		_base_basis = n3d.transform.basis
		if transform_target == TransformTarget.ROTATION and rotation_pivot_offset != Vector3.ZERO:
			_contributes_position = true

	if transform_target == TransformTarget.SCALE:
		_resolve_scale_pivot(target)
		if _scale_pivot_point != Vector3.ZERO:
			_contributes_position = true

	# Resolve rotation swing range to radians
	_resolved_swing_range_rot = Vector3(
		deg_to_rad(swing_range_degrees.x),
		deg_to_rad(swing_range_degrees.y),
		deg_to_rad(swing_range_degrees.z))

	# Initialize at rest — spring is purely reactive
	_current_pos = Vector3.ZERO
	_current_rot = Vector3.ZERO
	_current_scale = Vector3.ZERO
	_vel_pos = Vector3.ZERO
	_vel_rot = Vector3.ZERO
	_vel_scale = Vector3.ZERO

	# Compute torque arm for rotation
	_torque_arm = Vector3.ZERO
	_torque_arm_len_sq = 0.0
	if transform_target == TransformTarget.ROTATION:
		_torque_arm = center_of_gravity  # Local space offset from pivot
		_torque_arm_len_sq = _torque_arm.length_squared()

	if debug_enabled:
		print("[Spring3D] Start: %s, stiffness=%.0f, damping=%.0f, arm=%s" % [
			TransformTarget.keys()[transform_target], stiffness, damping, _torque_arm])


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
	var eff_stiffness := _soft_clamp_stiffness_vec3(_current_pos, swing_range)
	var acceleration := (-_current_pos * eff_stiffness - _vel_pos * damping) / mass
	_vel_pos += acceleration * delta
	_current_pos += _vel_pos * delta


func _spring_step_rot(delta: float) -> void:
	var eff_stiffness := _soft_clamp_stiffness_vec3(_current_rot, _resolved_swing_range_rot)
	var acceleration := (-_current_rot * eff_stiffness - _vel_rot * damping) / mass
	_vel_rot += acceleration * delta
	_current_rot += _vel_rot * delta


func _spring_step_scale(delta: float) -> void:
	var eff_stiffness := _soft_clamp_stiffness_vec3(_current_scale, swing_range)
	var acceleration := (-_current_scale * eff_stiffness - _vel_scale * damping) / mass
	_vel_scale += acceleration * delta
	_current_scale += _vel_scale * delta


# --- Soft clamp: non-linear stiffness increase near swing_range boundary ---

func _soft_clamp_stiffness_vec3(current: Vector3, range_limit: Vector3) -> Vector3:
	if range_limit == Vector3.ZERO:
		return Vector3(stiffness, stiffness, stiffness)
	var result := Vector3.ZERO
	for i in 3:
		if range_limit[i] != 0.0:
			var ratio := current[i] / range_limit[i]
			result[i] = stiffness * (1.0 + ratio * ratio)
		else:
			result[i] = stiffness
	return result


# --- Settlement ---

func _is_settled() -> bool:
	match transform_target:
		TransformTarget.POSITION:
			return _vel_pos.length() < velocity_threshold and _current_pos.length() < value_threshold
		TransformTarget.ROTATION:
			return _vel_rot.length() < velocity_threshold and _current_rot.length() < value_threshold
		TransformTarget.SCALE:
			return _vel_scale.length() < velocity_threshold and _current_scale.length() < value_threshold
	return false


func _snap_to_rest() -> void:
	match transform_target:
		TransformTarget.POSITION:
			_current_pos = Vector3.ZERO; _vel_pos = Vector3.ZERO
		TransformTarget.ROTATION:
			_current_rot = Vector3.ZERO; _vel_rot = Vector3.ZERO
		TransformTarget.SCALE:
			_current_scale = Vector3.ZERO; _vel_scale = Vector3.ZERO


func _write_deltas() -> void:
	match transform_target:
		TransformTarget.POSITION:
			_pos_delta = _current_pos
		TransformTarget.ROTATION:
			_rot_delta = _current_rot
			# Position compensation for rotation pivot
			if rotation_pivot_offset != Vector3.ZERO:
				var new_basis := Basis.from_euler(_base_basis.get_euler() + _current_rot)
				_pos_delta = _base_basis * rotation_pivot_offset - new_basis * rotation_pivot_offset
		TransformTarget.SCALE:
			_scale_delta = _current_scale
			if _scale_pivot_point != Vector3.ZERO:
				var new_scale := _base_scale + _current_scale
				var scale_ratio := new_scale / _base_scale
				_pos_delta = _scale_pivot_point - Vector3(
					_scale_pivot_point.x * scale_ratio.x,
					_scale_pivot_point.y * scale_ratio.y,
					_scale_pivot_point.z * scale_ratio.z)


# =============================================================================
# SCALE PIVOT RESOLUTION
# =============================================================================

func _resolve_scale_pivot(target: Node) -> void:
	match scale_pivot_mode:
		PivotMode.INHERIT:
			_scale_pivot_point = Vector3.ZERO
		PivotMode.CUSTOM:
			_scale_pivot_point = scale_custom_pivot
		PivotMode.AUTO_CENTER:
			_scale_pivot_point = Vector3.ZERO  # No auto-detect without mesh children in headless
