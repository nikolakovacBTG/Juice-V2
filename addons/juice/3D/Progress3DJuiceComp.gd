## Progress3DJuiceComp.gd
## ============================================================================
## WHAT: Continuous accumulation effect for Node3D nodes. Accumulates position,
##       rotation, or scale change over time at a configurable rate.
##       Progress from base class acts as speed multiplier (0=stopped, 1=full).
## WHY: Generalizes Spin3DJuiceComp beyond rotation to all transform axes.
##      Supports bounded accumulation with configurable behaviors (reverse, wrap,
##      stop, etc.) for looping and finite-distance effects.
## SYSTEM: Juicing System (addons/juice/) - 3D Domain
## DOES NOT: Handle Control or Node2D targets (use ProgressControl/Progress2D).
## DOES NOT: Handle arbitrary property accumulation (use ProgressPropertyJuiceComp).
## DOES NOT: Handle one-shot triggered transforms (use Transform3DJuiceComp).
## ============================================================================
##
## KEY CONCEPT:
## Unlike Transform/Shake/Spring which animate to a target and stop, Progress
## accumulates value continuously: value += rate * delta * speed_multiplier.
## animate_in() ramps speed 0→1 (eased), animate_out() ramps 1→0 (eased).
## Accumulated value persists across transitions — no snap-back on animate_out.
##
## BOUND SYSTEM:
## When bound_enabled, accumulated distance is checked each frame. When reached:
## - EMIT_COMPLETED: fires completed signal (for chaining)
## - REVERSE: instant direction flip (ping-pong)
## - REVERSE_EASED: animate_out → flip → animate_in (smooth direction change)
## - WRAP: reset accumulated to 0, continue (looping)
## - STOP: halt at bound value
## - DESTROY_PARENT: queue_free() the parent node
##
## PIVOT (ROTATION and SCALE only):
## Node3D has no native pivot property, so pivot is achieved by adjusting
## position via Transform3D math:
##   new_origin = fixed_pivot_parent - new_basis * pivot_offset
## Size is inferred from MeshInstance3D/CollisionShape3D for AUTO_CENTER.
##
## CONDITIONAL EXPORTS:
## Changing transform_target / bound_enabled / bound_mode triggers
## notify_property_list_changed() to show/hide relevant parameters.
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBase3D.svg")
class_name Progress3DJuiceComp
extends JuiceCompBase

# =============================================================================
# TRANSFORM TARGET SELECTION
# =============================================================================

## Which transform property to accumulate
enum TransformTarget {
	POSITION,  ## Accumulate Node3D.position
	ROTATION,  ## Accumulate Node3D.rotation (3-axis via quaternion composition)
	SCALE      ## Accumulate Node3D.scale
}

@export_group("Effect")

@export var transform_target: TransformTarget = TransformTarget.ROTATION:
	set(value):
		transform_target = value
		notify_property_list_changed()

# =============================================================================
# ALWAYS-VISIBLE CONFIGURATION
# =============================================================================

## Start accumulating immediately when the scene starts (no animate_in needed).
## Sets speed multiplier to 1.0 instantly. Use trigger_on = ON_READY for eased start.
@export var auto_start: bool = false

# =============================================================================
# BOUND CONFIGURATION
# =============================================================================

## What to do when accumulated distance reaches the bound
enum BoundBehaviour {
	EMIT_COMPLETED,  ## Emit completed signal (fires chaining)
	REVERSE,         ## Instant direction flip (ping-pong)
	REVERSE_EASED,   ## Eased direction change via animate_out → flip → animate_in
	WRAP,            ## Reset accumulated to 0, continue (looping)
	STOP,            ## Stop accumulation, hold at bound value
	DESTROY_PARENT   ## queue_free() the parent node
}

## How to measure accumulated distance for bound checking
enum BoundMode {
	MAGNITUDE,  ## Single float compared to accumulated magnitude (default)
	PER_AXIS    ## Per-axis comparison — any axis hitting its bound triggers behaviour
}

# =============================================================================
# PIVOT MODE (shown for ROTATION and SCALE only, via _get_property_list)
# =============================================================================

## Determines how the pivot point is calculated for rotation/scale
enum PivotMode {
	AUTO_CENTER,  ## Infer size from meshes/shapes and rotate/scale from center
	INHERIT,      ## Use node origin (no compensation)
	CUSTOM        ## Use custom_pivot (local-space world units)
}

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — shown/hidden via _get_property_list()
# =============================================================================

# --- POSITION ---
## Units per second of position drift (Vector3)
var position_rate: Vector3 = Vector3(0.0, 1.0, 0.0)

# --- ROTATION ---
## Degrees per second of rotation per axis. Applied in YXZ order (Godot default).
var rotation_rate: Vector3 = Vector3(0.0, 90.0, 0.0)

# --- SCALE ---
## Scale units per second of growth/shrink per axis
var scale_rate: Vector3 = Vector3(0.1, 0.1, 0.1)

# --- PIVOT (ROTATION + SCALE) ---
var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()
## Custom pivot in local-space coordinates (world units)
var custom_pivot: Vector3 = Vector3.ZERO

# --- BOUND ---
var bound_enabled: bool = false:
	set(value):
		bound_enabled = value
		notify_property_list_changed()
var bound_mode: int = BoundMode.MAGNITUDE:
	set(value):
		bound_mode = value
		notify_property_list_changed()
var bound_value: float = 360.0
var bound_value_vec3: Vector3 = Vector3(360.0, 360.0, 360.0)
var bound_behaviour: int = BoundBehaviour.REVERSE

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Accumulated change from base (radians for rotation)
var _accumulated_position: Vector3 = Vector3.ZERO
var _accumulated_rotation: Vector3 = Vector3.ZERO
var _accumulated_scale: Vector3 = Vector3.ZERO

## Direction multiplier: +1.0 or -1.0 (flipped by REVERSE bound behaviour)
var _current_direction: float = 1.0

## Captured base values
var _base_position: Vector3 = Vector3.ZERO
var _base_rotation: Vector3 = Vector3.ZERO
var _base_scale: Vector3 = Vector3.ONE
var _base_transform: Transform3D = Transform3D.IDENTITY

## Whether base has been captured
var _has_base: bool = false

## Pivot point in the target's local space
var _pivot_point: Vector3 = Vector3.ZERO
var _pivot_resolved: bool = false

## Fixed pivot position in parent space (computed once at animation start)
var _fixed_pivot_parent: Vector3 = Vector3.ZERO

## State flag for REVERSE_EASED
var _awaiting_reverse_restart: bool = false

# =============================================================================
# READ-ONLY PUBLIC PROPERTY
# =============================================================================

## Current accumulated change from base. External systems can query this.
var accumulated_value: Variant:
	get:
		match transform_target:
			TransformTarget.POSITION:
				return _accumulated_position
			TransformTarget.ROTATION:
				return _accumulated_rotation
			TransformTarget.SCALE:
				return _accumulated_scale
		return null

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	match transform_target:
		TransformTarget.POSITION:
			props.append({
				"name": "position_rate",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
		TransformTarget.ROTATION:
			props.append({
				"name": "rotation_rate",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
			props.append_array(_get_pivot_properties())
		TransformTarget.SCALE:
			props.append({
				"name": "scale_rate",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
			props.append_array(_get_pivot_properties())

	# --- Bound system ---
	props.append({
		"name": "bound_enabled",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT,
	})

	if bound_enabled:
		props.append({
			"name": "bound_behaviour",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Emit Completed,Reverse,Reverse Eased,Wrap,Stop,Destroy Parent",
		})
		props.append({
			"name": "bound_mode",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Magnitude,Per Axis",
		})
		if bound_mode == BoundMode.PER_AXIS:
			props.append({
				"name": "bound_value_vec3",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
		else:
			props.append({
				"name": "bound_value",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
			})

	return props


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
	if pivot_mode == PivotMode.CUSTOM:
		pivot_props.append({
			"name": "custom_pivot",
			"type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	return pivot_props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"position_rate": position_rate = value; return true
		&"rotation_rate": rotation_rate = value; return true
		&"scale_rate": scale_rate = value; return true
		&"pivot_mode": pivot_mode = value; return true
		&"custom_pivot": custom_pivot = value; return true
		&"bound_enabled": bound_enabled = value; return true
		&"bound_mode": bound_mode = value; return true
		&"bound_value": bound_value = value; return true
		&"bound_value_vec3": bound_value_vec3 = value; return true
		&"bound_behaviour": bound_behaviour = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"position_rate": return position_rate
		&"rotation_rate": return rotation_rate
		&"scale_rate": return scale_rate
		&"pivot_mode": return pivot_mode
		&"custom_pivot": return custom_pivot
		&"bound_enabled": return bound_enabled
		&"bound_mode": return bound_mode
		&"bound_value": return bound_value
		&"bound_value_vec3": return bound_value_vec3
		&"bound_behaviour": return bound_behaviour
	return null

# =============================================================================
# LIFECYCLE OVERRIDES
# =============================================================================

func _ready() -> void:
	super._ready()
	if auto_start and not Engine.is_editor_hint():
		call_deferred("_start_auto_progress")


func _start_auto_progress() -> void:
	_capture_base()
	_reset_accumulated()
	_current_direction = 1.0
	_awaiting_reverse_restart = false

	if transform_target != TransformTarget.POSITION and not _pivot_resolved:
		_resolve_pivot()
		_pivot_resolved = true

	# Pre-compute fixed pivot in parent space
	_fixed_pivot_parent = _base_transform.origin + _base_transform.basis * _pivot_point

	_animation_progress = 1.0
	_target_progress = 1.0
	_is_playing = true
	set_process(true)

	if debug_enabled:
		print("[%s] Auto-started progress (%s), pivot=%s" % [
			name, TransformTarget.keys()[transform_target], _pivot_point])


## When already playing, retrigger acts as a toggle-stop:
## - Sustaining: animate_out for graceful deceleration to stop.
## - Mid ease-out (REVERSE_EASED): clear the flag so the existing ease-out
##   completes as a full stop instead of reversing direction.
## When not playing, falls through to base class to start normally.
func _handle_trigger(trigger: Dictionary) -> void:
	if _is_playing:
		if _awaiting_reverse_restart:
			_awaiting_reverse_restart = false
		else:
			animate_out()
		return
	super._handle_trigger(trigger)


## Progress overrides _process to bypass the base class easing/loop cycle.
## Value accumulates continuously via delta time — progress is just a speed
## multiplier that ramps during transitions and holds steady during sustained
## accumulation.
func _process(delta: float) -> void:
	if not _is_playing:
		return

	if absf(_animation_progress - _target_progress) > 0.0001:
		_elapsed += delta
		var current_duration := _get_current_duration()
		var t: float = clampf(_elapsed / current_duration, 0.0, 1.0) if current_duration > 0.0 else 1.0
		_animation_progress = lerpf(_start_progress, _target_progress, _apply_easing(t))

		if _elapsed >= current_duration:
			_animation_progress = _target_progress
			if _target_progress <= 0.0:
				# REVERSE_EASED: deceleration complete — absorb overshoot into
				# base, flip direction, and ease back in. Don't stop or emit
				# completed — the ping-pong continues seamlessly.
				if _awaiting_reverse_restart:
					if debug_enabled:
						print("[%s] ◆ EASE-OUT DONE (pre-absorb) | dir=%.0f | acc_pos=%s acc_rot=%s acc_scale=%s | base_pos=%s base_rot=%s base_scale=%s" % [
							name, _current_direction, _accumulated_position, _accumulated_rotation, _accumulated_scale,
							_base_position, _base_rotation, _base_scale])
					_awaiting_reverse_restart = false
					_absorb_accumulated_into_base()
					_current_direction *= -1.0
					if debug_enabled:
						print("[%s] ◆ ABSORBED + FLIPPED | new_dir=%.0f | acc_pos=%s acc_rot=%s acc_scale=%s | base_pos=%s base_rot=%s base_scale=%s" % [
							name, _current_direction, _accumulated_position, _accumulated_rotation, _accumulated_scale,
							_base_position, _base_rotation, _base_scale])
					_start_progress = 0.0
					_target_progress = 1.0
					_elapsed = 0.0
					_animation_progress = 0.0
					return
				# Normal animate_out — fully stop accumulation
				_apply_effect(0.0)
				_is_playing = false
				set_process(false)
				_on_animate_out_complete()
				completed.emit()
				return
			else:
				if debug_enabled:
					print("[%s] ◆ EASE-IN DONE → sustaining | dir=%.0f | acc_pos=%s acc_rot=%s acc_scale=%s | base_pos=%s base_rot=%s base_scale=%s" % [
						name, _current_direction, _accumulated_position, _accumulated_rotation, _accumulated_scale,
						_base_position, _base_rotation, _base_scale])
				completed.emit()

	elif _target_progress <= 0.0:
		# Edge case: easing curve brought progress within epsilon of target before
		# _elapsed reached current_duration. The outer absf guard skipped the block,
		# so _elapsed stopped incrementing and the completion code never fired.
		# Force completion now to avoid getting stuck.
		_animation_progress = _target_progress
		if _awaiting_reverse_restart:
			if debug_enabled:
				print("[%s] ◆ EASE-OUT DONE (early) | dir=%.0f | acc_pos=%s acc_rot=%s acc_scale=%s | base_pos=%s base_rot=%s base_scale=%s" % [
					name, _current_direction, _accumulated_position, _accumulated_rotation, _accumulated_scale,
					_base_position, _base_rotation, _base_scale])
			_awaiting_reverse_restart = false
			_absorb_accumulated_into_base()
			_current_direction *= -1.0
			if debug_enabled:
				print("[%s] ◆ ABSORBED + FLIPPED | new_dir=%.0f | acc_pos=%s acc_rot=%s acc_scale=%s | base_pos=%s base_rot=%s base_scale=%s" % [
					name, _current_direction, _accumulated_position, _accumulated_rotation, _accumulated_scale,
					_base_position, _base_rotation, _base_scale])
			_start_progress = 0.0
			_target_progress = 1.0
			_elapsed = 0.0
			_animation_progress = 0.0
			return
		_apply_effect(0.0)
		_is_playing = false
		set_process(false)
		_on_animate_out_complete()
		completed.emit()
		return

	_apply_effect(_animation_progress)

# =============================================================================
# VIRTUAL METHOD IMPLEMENTATIONS
# =============================================================================

func _invalidate_base_cache() -> void:
	_has_base = false
	_pivot_resolved = false
	if debug_enabled:
		print("[%s] Base cache invalidated" % name)


func _on_animate_start() -> void:
	if not _has_base:
		_capture_base()

	if transform_target != TransformTarget.POSITION and not _pivot_resolved:
		_resolve_pivot()
		_pivot_resolved = true

	# Pre-compute fixed pivot in parent space
	_fixed_pivot_parent = _base_transform.origin + _base_transform.basis * _pivot_point

	if debug_enabled:
		var target_name: String = TransformTarget.keys()[transform_target]
		print("[%s] Progress start (3D, %s). Direction: %.0f, pivot=%s" % [
			name, target_name, _current_direction, _pivot_point])


func _apply_effect(progress: float) -> void:
	if not is_instance_valid(_target_node):
		return
	if not (_target_node is Node3D):
		return

	var n3d := _target_node as Node3D
	var delta := get_process_delta_time()

	match transform_target:
		TransformTarget.POSITION:
			_accumulated_position += position_rate * delta * progress * _current_direction
			n3d.position = _base_position + _accumulated_position

		TransformTarget.ROTATION:
			# Convert degrees/second to radians, scaled by progress as speed multiplier
			var speed_rad := Vector3(
				deg_to_rad(rotation_rate.x),
				deg_to_rad(rotation_rate.y),
				deg_to_rad(rotation_rate.z)
			) * progress * _current_direction
			_accumulated_rotation += speed_rad * delta

			# Compose rotation using quaternions for smooth multi-axis behavior
			var base_quat := _base_transform.basis.get_rotation_quaternion()
			var accumulated_quat := Quaternion.from_euler(_accumulated_rotation)
			var target_quat := base_quat * accumulated_quat

			if _pivot_point != Vector3.ZERO:
				# Rotation around pivot point using transform math
				var new_basis := Basis(target_quat)
				var new_origin := _fixed_pivot_parent - new_basis * _pivot_point
				n3d.transform = Transform3D(new_basis, new_origin)
			else:
				# Simple rotation around origin
				var total_rotation := _base_rotation + _accumulated_rotation
				n3d.rotation = total_rotation

		TransformTarget.SCALE:
			_accumulated_scale += scale_rate * delta * progress * _current_direction
			var new_scale := _base_scale + _accumulated_scale
			n3d.scale = new_scale

			if _pivot_point != Vector3.ZERO:
				# Pivot compensation: adjust position so pivot point stays stationary
				var new_origin := _fixed_pivot_parent - _pivot_point * new_scale
				n3d.position = new_origin

	if bound_enabled and progress > 0.0:
		_check_bounds()


func _on_animate_out_complete() -> void:
	if debug_enabled:
		print("[%s] Progress stopped (holding accumulated state)" % name)


# =============================================================================
# BOUND CHECKING
# =============================================================================

func _check_bounds() -> void:
	# Guard: skip re-entrant bound check when REVERSE_EASED animate_out is
	# already in progress — prevents infinite recursion via _animate_to → _apply_effect
	if _awaiting_reverse_restart:
		return

	var exceeded := false

	match transform_target:
		TransformTarget.POSITION:
			exceeded = _check_vector3_bound(_accumulated_position)
		TransformTarget.ROTATION:
			# Convert accumulated radians to degrees for bound comparison
			var acc_deg := Vector3(
				rad_to_deg(_accumulated_rotation.x),
				rad_to_deg(_accumulated_rotation.y),
				rad_to_deg(_accumulated_rotation.z)
			)
			exceeded = _check_vector3_bound(acc_deg)
		TransformTarget.SCALE:
			exceeded = _check_vector3_bound(_accumulated_scale)

	if not exceeded:
		return

	_clamp_to_bound()

	if debug_enabled:
		print("[%s] Bound reached (%.1f). Behaviour: %s" % [
			name, bound_value, BoundBehaviour.keys()[bound_behaviour]])

	match bound_behaviour:
		BoundBehaviour.EMIT_COMPLETED:
			completed.emit()
		BoundBehaviour.REVERSE:
			_absorb_accumulated_into_base()
			_current_direction *= -1.0
		BoundBehaviour.REVERSE_EASED:
			if debug_enabled:
				print("[%s] ◆ BOUND HIT → REVERSE_EASED | dir=%.0f | acc_pos=%s acc_rot=%s acc_scale=%s | base_pos=%s base_rot=%s base_scale=%s | anim_prog=%.3f" % [
					name, _current_direction, _accumulated_position, _accumulated_rotation, _accumulated_scale,
					_base_position, _base_rotation, _base_scale, _animation_progress])
			_awaiting_reverse_restart = true
			animate_out()
		BoundBehaviour.WRAP:
			_wrap_accumulated()
		BoundBehaviour.STOP:
			_is_playing = false
			set_process(false)
			completed.emit()
		BoundBehaviour.DESTROY_PARENT:
			if is_instance_valid(_target_node):
				_target_node.queue_free()


func _check_vector3_bound(accumulated: Vector3) -> bool:
	if bound_mode == BoundMode.PER_AXIS:
		return absf(accumulated.x) > absf(bound_value_vec3.x) or \
			   absf(accumulated.y) > absf(bound_value_vec3.y) or \
			   absf(accumulated.z) > absf(bound_value_vec3.z)
	else:
		return accumulated.length() > bound_value


func _clamp_to_bound() -> void:
	match transform_target:
		TransformTarget.POSITION:
			_accumulated_position = _clamp_vector3(_accumulated_position)
		TransformTarget.ROTATION:
			# Clamp in degrees, store in radians
			var acc_deg := Vector3(
				rad_to_deg(_accumulated_rotation.x),
				rad_to_deg(_accumulated_rotation.y),
				rad_to_deg(_accumulated_rotation.z)
			)
			acc_deg = _clamp_vector3(acc_deg)
			_accumulated_rotation = Vector3(
				deg_to_rad(acc_deg.x),
				deg_to_rad(acc_deg.y),
				deg_to_rad(acc_deg.z)
			)
		TransformTarget.SCALE:
			_accumulated_scale = _clamp_vector3(_accumulated_scale)


func _clamp_vector3(accumulated: Vector3) -> Vector3:
	if bound_mode == BoundMode.PER_AXIS:
		return Vector3(
			clampf(accumulated.x, -absf(bound_value_vec3.x), absf(bound_value_vec3.x)),
			clampf(accumulated.y, -absf(bound_value_vec3.y), absf(bound_value_vec3.y)),
			clampf(accumulated.z, -absf(bound_value_vec3.z), absf(bound_value_vec3.z))
		)
	else:
		var length := accumulated.length()
		if length > bound_value and length > 0.0:
			return accumulated.normalized() * bound_value
		return accumulated


func _wrap_accumulated() -> void:
	match transform_target:
		TransformTarget.POSITION:
			_accumulated_position = _wrap_vector3(_accumulated_position)
		TransformTarget.ROTATION:
			var acc_deg := Vector3(
				rad_to_deg(_accumulated_rotation.x),
				rad_to_deg(_accumulated_rotation.y),
				rad_to_deg(_accumulated_rotation.z)
			)
			acc_deg = _wrap_vector3(acc_deg)
			_accumulated_rotation = Vector3(
				deg_to_rad(acc_deg.x),
				deg_to_rad(acc_deg.y),
				deg_to_rad(acc_deg.z)
			)
		TransformTarget.SCALE:
			_accumulated_scale = _wrap_vector3(_accumulated_scale)


func _wrap_vector3(accumulated: Vector3) -> Vector3:
	if bound_mode == BoundMode.PER_AXIS:
		return Vector3(
			fmod(accumulated.x, absf(bound_value_vec3.x)) if absf(bound_value_vec3.x) > 0.0 else 0.0,
			fmod(accumulated.y, absf(bound_value_vec3.y)) if absf(bound_value_vec3.y) > 0.0 else 0.0,
			fmod(accumulated.z, absf(bound_value_vec3.z)) if absf(bound_value_vec3.z) > 0.0 else 0.0
		)
	else:
		return Vector3.ZERO

# =============================================================================
# HELPERS
# =============================================================================

## Absorb accumulated value into the base, resetting accumulated to zero.
## This makes the current position the new "start" for bound measurement,
## enabling correct ping-pong between [start, start+bound] instead of [-bound, +bound].
func _absorb_accumulated_into_base() -> void:
	match transform_target:
		TransformTarget.POSITION:
			_base_position += _accumulated_position
			_accumulated_position = Vector3.ZERO
		TransformTarget.ROTATION:
			# Use quaternion composition for correct multi-axis rotation absorb.
			# Euler angle addition is NOT equivalent to quaternion multiplication,
			# so we compose the base quaternion with the accumulated rotation and
			# extract a new euler for the non-pivot path.
			var old_scale := _base_transform.basis.get_scale()
			var new_quat := _base_transform.basis.get_rotation_quaternion() * Quaternion.from_euler(_accumulated_rotation)
			_base_transform.basis = Basis(new_quat).scaled(old_scale)
			_base_rotation = new_quat.get_euler()
			_accumulated_rotation = Vector3.ZERO
		TransformTarget.SCALE:
			_base_scale += _accumulated_scale
			_accumulated_scale = Vector3.ZERO


func _reset_accumulated() -> void:
	_accumulated_position = Vector3.ZERO
	_accumulated_rotation = Vector3.ZERO
	_accumulated_scale = Vector3.ZERO


func _capture_base() -> void:
	if _has_base:
		return

	if not is_instance_valid(_target_node):
		push_warning("[%s] Cannot capture base - no valid target" % name)
		return

	if _target_node is Node3D:
		var n3d := _target_node as Node3D
		_base_position = n3d.position
		_base_rotation = n3d.rotation
		_base_scale = n3d.scale
		_base_transform = n3d.transform
	else:
		_base_position = Vector3.ZERO
		_base_rotation = Vector3.ZERO
		_base_scale = Vector3.ONE
		_base_transform = Transform3D.IDENTITY
		if debug_enabled:
			push_warning("[%s] Target '%s' is not Node3D" % [name, _target_node.name])

	_has_base = true

	if debug_enabled:
		print("[%s] Captured base — pos: %s, rot: %s, scale: %s" % [
			name, _base_position, _base_rotation, _base_scale
		])

# =============================================================================
# PIVOT HANDLING — Transform3D position compensation for Node3D
# =============================================================================

func _resolve_pivot() -> void:
	match pivot_mode:
		PivotMode.AUTO_CENTER:
			if _target_node is Node3D:
				var n3d := _target_node as Node3D
				# Try direct local bounds on the target itself first
				var bounds := _infer_node3d_local_bounds(n3d)
				if bounds.size == Vector3.ZERO:
					# Container fallback: compute merged bounds from children
					bounds = _infer_node3d_bounds_recursive(n3d)
				if bounds.size != Vector3.ZERO:
					_pivot_point = bounds.get_center()
				else:
					_pivot_point = Vector3.ZERO
				if debug_enabled:
					print("[%s] Auto-center pivot: bounds=%s, center=%s" % [name, bounds, _pivot_point])
			else:
				_pivot_point = Vector3.ZERO
		PivotMode.INHERIT:
			_pivot_point = Vector3.ZERO
		PivotMode.CUSTOM:
			_pivot_point = custom_pivot


# -----------------------------------------------------------------------------
# Size inference for AUTO_CENTER pivot (reused from Spin3DJuiceComp pattern)
# -----------------------------------------------------------------------------

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

	# Local bounds centered on the node origin.
	return AABB(-size * 0.5, size)

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
				return {"rotation": n3d.rotation, "transform": n3d.transform}
			TransformTarget.SCALE:
				return {"scale": n3d.scale}
	return null


func _recipe_apply_natural(_target: Node, natural: Variant) -> void:
	if not (natural is Dictionary):
		return
	var dict := natural as Dictionary

	match transform_target:
		TransformTarget.POSITION:
			_base_position = dict.get("position", Vector3.ZERO) as Vector3
		TransformTarget.ROTATION:
			_base_rotation = dict.get("rotation", Vector3.ZERO) as Vector3
			if dict.has("transform"):
				_base_transform = dict.get("transform") as Transform3D
		TransformTarget.SCALE:
			_base_scale = dict.get("scale", Vector3.ONE) as Vector3

	_has_base = true
	_pivot_resolved = false


func _recipe_restore_natural(target: Node, natural: Variant) -> void:
	if not (natural is Dictionary) or not (target is Node3D):
		return
	var dict := natural as Dictionary
	var n3d := target as Node3D

	match transform_target:
		TransformTarget.POSITION:
			n3d.position = dict.get("position", Vector3.ZERO) as Vector3
		TransformTarget.ROTATION:
			if dict.has("transform"):
				n3d.transform = dict.get("transform") as Transform3D
			else:
				n3d.rotation = dict.get("rotation", Vector3.ZERO) as Vector3
		TransformTarget.SCALE:
			n3d.scale = dict.get("scale", Vector3.ONE) as Vector3

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent := get_parent()
	if parent and not parent is Node3D:
		warnings.append("Parent must be a Node3D node. Use ProgressControl/Progress2D for other domains. (ignore if comp is a child of a sequencer)")
	return warnings
