## Progress2DJuiceComp.gd
## ============================================================================
## WHAT: Continuous accumulation effect for Node2D nodes. Accumulates position,
##       rotation, or scale change over time at a configurable rate.
##       Progress from base class acts as speed multiplier (0=stopped, 1=full).
## WHY: Generalizes Spin2DJuiceComp beyond rotation to all transform axes.
##      Supports bounded accumulation with configurable behaviors (reverse, wrap,
##      stop, etc.) for looping and finite-distance effects.
## SYSTEM: Juicing System (addons/juice/) - 2D Domain
## DOES NOT: Handle Control or Node3D targets (use ProgressControl/Progress3D).
## DOES NOT: Handle arbitrary property accumulation (use ProgressPropertyJuiceComp).
## DOES NOT: Handle one-shot triggered transforms (use Transform2DJuiceComp).
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
## Node2D has no native pivot property, so pivot is achieved by adjusting
## position: new_pos = fixed_pivot_parent - pivot.rotated(rotation) for rotation,
## and new_pos = fixed_pivot_parent - pivot * scale for scale.
## Size is inferred from child sprites/collision shapes for AUTO_CENTER.
##
## CONDITIONAL EXPORTS:
## Changing transform_target / bound_enabled / bound_mode triggers
## notify_property_list_changed() to show/hide relevant parameters.
## ============================================================================

@tool
class_name Progress2DJuiceComp
extends JuiceCompBase

# =============================================================================
# TRANSFORM TARGET SELECTION
# =============================================================================

## Which transform property to accumulate
enum TransformTarget {
	POSITION,  ## Accumulate Node2D.position
	ROTATION,  ## Accumulate Node2D.rotation (single-axis Z)
	SCALE      ## Accumulate Node2D.scale
}

@export var transform_target: TransformTarget = TransformTarget.ROTATION:
	set(value):
		transform_target = value
		notify_property_list_changed()

# =============================================================================
# ALWAYS-VISIBLE CONFIGURATION
# =============================================================================

@export_group("Progress")

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
	AUTO_CENTER,  ## Infer size from children and rotate/scale from center
	INHERIT,      ## Use node origin (no compensation)
	CUSTOM        ## Use custom_pivot (pixel coordinates in local space)
}

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — shown/hidden via _get_property_list()
# =============================================================================

# --- POSITION ---
## Pixels per second of position drift (Vector2)
var position_rate: Vector2 = Vector2(50.0, 0.0)

# --- ROTATION ---
## Degrees per second of rotation. Positive = clockwise.
var rotation_rate: float = 90.0

# --- SCALE ---
## Scale units per second of growth/shrink
var scale_rate: Vector2 = Vector2(0.1, 0.1)

# --- PIVOT (ROTATION + SCALE) ---
var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()
## Custom pivot in local-space pixel coordinates
var custom_pivot: Vector2 = Vector2.ZERO

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
var bound_value_vec2: Vector2 = Vector2(360.0, 360.0)
var bound_behaviour: int = BoundBehaviour.REVERSE

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Accumulated change from base
var _accumulated_position: Vector2 = Vector2.ZERO
var _accumulated_rotation: float = 0.0
var _accumulated_scale: Vector2 = Vector2.ZERO

## Direction multiplier: +1.0 or -1.0 (flipped by REVERSE bound behaviour)
var _current_direction: float = 1.0

## Captured base values of target
var _base_position: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _base_scale: Vector2 = Vector2.ONE

## Whether base has been captured
var _has_base: bool = false

## Pivot point in the target's local space (pixels)
var _pivot_point: Vector2 = Vector2.ZERO
var _pivot_resolved: bool = false

## Fixed pivot position in parent space (computed once at animation start)
var _fixed_pivot_parent: Vector2 = Vector2.ZERO

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
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
		TransformTarget.ROTATION:
			props.append({
				"name": "rotation_rate",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
			props.append_array(_get_pivot_properties())
		TransformTarget.SCALE:
			props.append({
				"name": "scale_rate",
				"type": TYPE_VECTOR2,
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
		if transform_target != TransformTarget.ROTATION:
			props.append({
				"name": "bound_mode",
				"type": TYPE_INT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Magnitude,Per Axis",
			})
			if bound_mode == BoundMode.PER_AXIS:
				props.append({
					"name": "bound_value_vec2",
					"type": TYPE_VECTOR2,
					"usage": PROPERTY_USAGE_DEFAULT,
				})
			else:
				props.append({
					"name": "bound_value",
					"type": TYPE_FLOAT,
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
			"type": TYPE_VECTOR2,
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
		&"bound_value_vec2": bound_value_vec2 = value; return true
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
		&"bound_value_vec2": return bound_value_vec2
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
	_fixed_pivot_parent = _base_position + _pivot_point.rotated(_base_rotation)

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
						print("[%s] ◆ EASE-OUT DONE (pre-absorb) | dir=%.0f | acc_pos=%s acc_rot=%.3f acc_scale=%s | base_pos=%s base_rot=%.3f base_scale=%s" % [
							name, _current_direction, _accumulated_position, _accumulated_rotation, _accumulated_scale,
							_base_position, _base_rotation, _base_scale])
					_awaiting_reverse_restart = false
					_absorb_accumulated_into_base()
					_current_direction *= -1.0
					if debug_enabled:
						print("[%s] ◆ ABSORBED + FLIPPED | new_dir=%.0f | acc_pos=%s acc_rot=%.3f acc_scale=%s | base_pos=%s base_rot=%.3f base_scale=%s" % [
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
					print("[%s] ◆ EASE-IN DONE → sustaining | dir=%.0f | acc_pos=%s acc_rot=%.3f acc_scale=%s | base_pos=%s base_rot=%.3f base_scale=%s" % [
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
				print("[%s] ◆ EASE-OUT DONE (early) | dir=%.0f | acc_pos=%s acc_rot=%.3f acc_scale=%s | base_pos=%s base_rot=%.3f base_scale=%s" % [
					name, _current_direction, _accumulated_position, _accumulated_rotation, _accumulated_scale,
					_base_position, _base_rotation, _base_scale])
			_awaiting_reverse_restart = false
			_absorb_accumulated_into_base()
			_current_direction *= -1.0
			if debug_enabled:
				print("[%s] ◆ ABSORBED + FLIPPED | new_dir=%.0f | acc_pos=%s acc_rot=%.3f acc_scale=%s | base_pos=%s base_rot=%.3f base_scale=%s" % [
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
	_fixed_pivot_parent = _base_position + _pivot_point.rotated(_base_rotation)

	if debug_enabled:
		var target_name: String = TransformTarget.keys()[transform_target]
		print("[%s] Progress start (2D, %s). Direction: %.0f, pivot=%s" % [
			name, target_name, _current_direction, _pivot_point])


func _apply_effect(progress: float) -> void:
	if not is_instance_valid(_target_node):
		return
	if not (_target_node is Node2D):
		return

	var n2d := _target_node as Node2D
	var delta := get_process_delta_time()

	match transform_target:
		TransformTarget.POSITION:
			_accumulated_position += position_rate * delta * progress * _current_direction
			n2d.position = _base_position + _accumulated_position

		TransformTarget.ROTATION:
			var speed_rad := deg_to_rad(rotation_rate) * progress * _current_direction
			_accumulated_rotation += speed_rad * delta
			var new_rotation := _base_rotation + _accumulated_rotation
			n2d.rotation = new_rotation
			# Pivot compensation: adjust position so pivot point stays stationary
			if _pivot_point != Vector2.ZERO:
				n2d.position = _fixed_pivot_parent - _pivot_point.rotated(new_rotation)

		TransformTarget.SCALE:
			_accumulated_scale += scale_rate * delta * progress * _current_direction
			var new_scale := _base_scale + _accumulated_scale
			n2d.scale = new_scale
			# Pivot compensation: adjust position so pivot point stays stationary
			if _pivot_point != Vector2.ZERO:
				n2d.position = _fixed_pivot_parent - _pivot_point * new_scale

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
			exceeded = _check_vector2_bound(_accumulated_position)
		TransformTarget.ROTATION:
			exceeded = absf(rad_to_deg(_accumulated_rotation)) > bound_value
		TransformTarget.SCALE:
			exceeded = _check_vector2_bound(_accumulated_scale)

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
				print("[%s] ◆ BOUND HIT → REVERSE_EASED | dir=%.0f | acc_pos=%s acc_rot=%.3f acc_scale=%s | base_pos=%s base_rot=%.3f base_scale=%s | anim_prog=%.3f" % [
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


func _check_vector2_bound(accumulated: Vector2) -> bool:
	if bound_mode == BoundMode.PER_AXIS:
		return absf(accumulated.x) > absf(bound_value_vec2.x) or \
			   absf(accumulated.y) > absf(bound_value_vec2.y)
	else:
		return accumulated.length() > bound_value


func _clamp_to_bound() -> void:
	match transform_target:
		TransformTarget.POSITION:
			_clamp_vector2_to_bound(&"_accumulated_position")
		TransformTarget.ROTATION:
			var max_rad := deg_to_rad(bound_value)
			_accumulated_rotation = clampf(_accumulated_rotation, -max_rad, max_rad)
		TransformTarget.SCALE:
			_clamp_vector2_to_bound(&"_accumulated_scale")


func _clamp_vector2_to_bound(field_name: StringName) -> void:
	var accumulated: Vector2 = get(field_name)
	if bound_mode == BoundMode.PER_AXIS:
		accumulated.x = clampf(accumulated.x, -absf(bound_value_vec2.x), absf(bound_value_vec2.x))
		accumulated.y = clampf(accumulated.y, -absf(bound_value_vec2.y), absf(bound_value_vec2.y))
	else:
		var length := accumulated.length()
		if length > bound_value and length > 0.0:
			accumulated = accumulated.normalized() * bound_value
	set(field_name, accumulated)


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

## Absorb accumulated value into the base, resetting accumulated to zero.
## This makes the current position the new "start" for bound measurement,
## enabling correct ping-pong between [start, start+bound] instead of [-bound, +bound].
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


func _capture_base() -> void:
	if _has_base:
		return

	if not is_instance_valid(_target_node):
		push_warning("[%s] Cannot capture base - no valid target" % name)
		return

	if _target_node is Node2D:
		var n2d := _target_node as Node2D
		_base_position = n2d.position
		_base_rotation = n2d.rotation
		_base_scale = n2d.scale
	else:
		_base_position = Vector2.ZERO
		_base_rotation = 0.0
		_base_scale = Vector2.ONE
		if debug_enabled:
			push_warning("[%s] Target '%s' is not Node2D" % [name, _target_node.name])

	_has_base = true

	if debug_enabled:
		print("[%s] Captured base — pos: %s, rot: %.1f°, scale: %s" % [
			name, _base_position, rad_to_deg(_base_rotation), _base_scale
		])

# =============================================================================
# PIVOT HANDLING — Position compensation for Node2D
# =============================================================================

func _resolve_pivot() -> void:
	match pivot_mode:
		PivotMode.AUTO_CENTER:
			if _target_node is Node2D:
				_pivot_point = _infer_node2d_center(_target_node as Node2D)
				if debug_enabled:
					print("[%s] Auto-center pivot: %s" % [name, _pivot_point])
			else:
				_pivot_point = Vector2.ZERO
		PivotMode.INHERIT:
			_pivot_point = Vector2.ZERO
		PivotMode.CUSTOM:
			_pivot_point = custom_pivot


## Infer the visual center of a Node2D by checking common child types.
## Returns center in local space (pixels). Falls back to Vector2.ZERO if
## no measurable children are found.
func _infer_node2d_center(node: Node2D) -> Vector2:
	# Check the node itself first
	var size := _get_node2d_size(node)
	if size != Vector2.ZERO:
		return Vector2.ZERO  # Already centered on origin

	# Check children for visual bounds
	var has_any := false
	var combined := Rect2()
	for child in node.get_children():
		if not (child is Node2D):
			continue
		var child_size := _get_node2d_size(child)
		if child_size != Vector2.ZERO:
			var child_rect := Rect2(
				(child as Node2D).position - child_size * 0.5,
				child_size
			)
			if not has_any:
				has_any = true
				combined = child_rect
			else:
				combined = combined.merge(child_rect)

	if has_any:
		return combined.get_center()
	return Vector2.ZERO


## Get the visual size of a single Node2D (sprite, collision shape, etc.)
func _get_node2d_size(node: Node2D) -> Vector2:
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture != null:
			var tex_size := sprite.texture.get_size()
			if sprite.region_enabled:
				tex_size = sprite.region_rect.size
			return tex_size * node.scale
		return Vector2.ZERO

	if node is CollisionShape2D:
		var col := node as CollisionShape2D
		if col.shape != null:
			var shape := col.shape
			if shape is RectangleShape2D:
				return (shape as RectangleShape2D).size
			elif shape is CircleShape2D:
				var r := (shape as CircleShape2D).radius
				return Vector2(r * 2.0, r * 2.0)
			elif shape is CapsuleShape2D:
				var cap := shape as CapsuleShape2D
				return Vector2(cap.radius * 2.0, cap.height)
		return Vector2.ZERO

	return Vector2.ZERO

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
				return {"rotation": n2d.rotation}
			TransformTarget.SCALE:
				return {"scale": n2d.scale}
	return null


func _recipe_apply_natural(_target: Node, natural: Variant) -> void:
	if not (natural is Dictionary):
		return
	var dict := natural as Dictionary

	match transform_target:
		TransformTarget.POSITION:
			_base_position = dict.get("position", Vector2.ZERO) as Vector2
		TransformTarget.ROTATION:
			_base_rotation = dict.get("rotation", 0.0) as float
		TransformTarget.SCALE:
			_base_scale = dict.get("scale", Vector2.ONE) as Vector2

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
		TransformTarget.SCALE:
			n2d.scale = dict.get("scale", Vector2.ONE) as Vector2

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent := get_parent()
	if parent and not parent is Node2D:
		warnings.append("Parent must be a Node2D node. Use ProgressControl/Progress3D for other domains.")
	return warnings
