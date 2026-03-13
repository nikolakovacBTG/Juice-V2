## Spring2DJuiceComp.gd
## ============================================================================
## WHAT: Physics-based spring animation for Node2D nodes. Combines position,
##       rotation, and scale spring into a single component with a TransformTarget
##       selector. Uses _get_property_list() to conditionally show only relevant
##       exports in the inspector.
## WHY: Replaces the TRANSFORM mode of the unified SpringJuiceComp for Node2D
##      nodes. Clean inspector — only shows Node2D-relevant exports.
## SYSTEM: Juicing System (addons/juice/) - 2D Domain
## DOES NOT: Handle Control or Node3D targets (use SpringControl/Spring3D).
## DOES NOT: Handle arbitrary property springing (use SpringPropertyJuiceComp).
## ============================================================================
##
## KEY DIFFERENCE FROM OTHER JUICE:
## Spring does NOT use easing curves. It uses physics simulation:
## - Stiffness controls how fast it tries to reach target (oscillation speed)
## - Damping controls how quickly oscillations die down
## - Mass affects momentum and response time
##
## The component completes when velocity drops below threshold, not after a
## fixed duration. Duration acts as a maximum timeout.
##
## TRANSFORM TARGETS:
## - POSITION: Springs Node2D.position with Vector2 offset
## - ROTATION: Springs Node2D.rotation with float offset (degrees) + pivot comp
## - SCALE: Springs Node2D.scale with Vector2 offset + pivot compensation
##
## PIVOT (ROTATION and SCALE only):
## Node2D lacks native pivot_offset. Pivot is achieved via position compensation:
## - Rotation: fixed_pivot = base_pos + pivot.rotated(base_rot),
##             new_pos = fixed_pivot - pivot.rotated(new_rot)
## - Scale:    pos += pivot * (ONE - scale_ratio)
## AUTO_CENTER infers visual center from Sprite2D/CollisionShape2D/etc.
##
## CONDITIONAL EXPORTS:
## Changing transform_target triggers notify_property_list_changed() which
## shows/hides the relevant parameters via _get_property_list().
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBase2D.svg")
class_name Spring2DJuiceComp
extends JuiceCompBase

# =============================================================================
# TRANSFORM TARGET SELECTION
# =============================================================================

## Which transform property to spring
enum TransformTarget {
	POSITION,  ## Spring Node2D.position
	ROTATION,  ## Spring Node2D.rotation (single-axis Z)
	SCALE      ## Spring Node2D.scale
}

@export_group("Effect")

@export var transform_target: TransformTarget = TransformTarget.POSITION:
	set(value):
		transform_target = value
		notify_property_list_changed()

# =============================================================================
# SPRING PHYSICS CONFIGURATION (always visible)
# =============================================================================

## Spring stiffness - higher = faster oscillation, snappier response
@export_range(1.0, 1000.0) var stiffness: float = 300.0

## Damping factor - higher = less bounce, faster settling
@export_range(0.0, 50.0) var damping: float = 10.0

## Mass - higher = more momentum, slower initial response
@export_range(0.1, 10.0) var mass: float = 1.0

@export_group("Settlement")

## Velocity threshold for considering spring "settled"
@export var velocity_threshold: float = 0.5

## Position/value threshold for considering spring "at target"
@export var value_threshold: float = 0.1

## Use physics process instead of regular process
@export var use_physics_process: bool = false

@export_group("Re-trigger Prevention")

## Cooldown time after triggering before accepting new triggers
@export var trigger_cooldown: float = 0.0

# =============================================================================
# PIVOT MODE (shown for ROTATION and SCALE only, via _get_property_list)
# =============================================================================

enum PivotMode {
	AUTO_CENTER,  ## Infer visual center and compensate position (most common)
	INHERIT,      ## Rotate/scale from node origin (no compensation)
	CUSTOM        ## Rotate/scale from custom_pivot (local-space pixels)
}

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# =============================================================================

# --- POSITION ---
var position_offset: Vector2 = Vector2(0, -20)

# --- ROTATION ---
var rotation_offset_degrees: float = 15.0

# --- SCALE ---
var scale_offset: Vector2 = Vector2(0.2, 0.2)

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
var _base_rotation: float = 0.0
var _base_scale: Vector2 = Vector2.ONE

var _has_base: bool = false

## Resolved pivot point in target's local space (for rotation/scale)
var _pivot_point: Vector2 = Vector2.ZERO
var _pivot_resolved: bool = false

## Fixed pivot position in parent space (pre-computed at animation start for rotation)
var _fixed_pivot_parent: Vector2 = Vector2.ZERO

## Current spring value (what we're animating)
var _current_value: Variant

## Target value we're springing towards
var _spring_target_value: Variant

## Current velocity (same type as value)
var _velocity: Variant

## Whether we're springing towards offset (true) or back to base (false)
var _springing_to_offset: bool = true

## Timestamp of last trigger (for cooldown)
var _last_trigger_time: float = -INF

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	match transform_target:
		TransformTarget.POSITION:
			props.append({
				"name": "position_offset",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})

		TransformTarget.ROTATION:
			props.append({
				"name": "rotation_offset_degrees",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})
			props.append_array(_get_pivot_properties())

		TransformTarget.SCALE:
			props.append({
				"name": "scale_offset",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})
			props.append_array(_get_pivot_properties())

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
			"hint": PROPERTY_HINT_NONE,
		})
	return pivot_props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"position_offset": position_offset = value; return true
		&"rotation_offset_degrees": rotation_offset_degrees = value; return true
		&"scale_offset": scale_offset = value; return true
		&"pivot_mode": pivot_mode = value; return true
		&"custom_pivot": custom_pivot = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"position_offset": return position_offset
		&"rotation_offset_degrees": return rotation_offset_degrees
		&"scale_offset": return scale_offset
		&"pivot_mode": return pivot_mode
		&"custom_pivot": return custom_pivot
	return null

# =============================================================================
# LIFECYCLE OVERRIDES
# =============================================================================

func _ready() -> void:
	super._ready()


func _process(delta: float) -> void:
	if use_physics_process:
		return
	super._process(delta)


func _physics_process(_delta: float) -> void:
	if not use_physics_process:
		return
	if _is_playing:
		_apply_effect(_animation_progress)


func _on_animate_start() -> void:
	if trigger_cooldown > 0.0:
		var current_time := Time.get_ticks_msec() / 1000.0
		if current_time - _last_trigger_time < trigger_cooldown:
			if debug_enabled:
				print("[%s] Trigger blocked by cooldown (%.2fs remaining)" % [
					name, trigger_cooldown - (current_time - _last_trigger_time)
				])
			return
		_last_trigger_time = current_time

	if not _has_base:
		_capture_base()

	# Resolve pivot for rotation/scale targets
	if transform_target != TransformTarget.POSITION and not _pivot_resolved:
		_resolve_pivot()
		_pivot_resolved = true

	# Pre-compute fixed pivot in parent space for rotation
	if transform_target == TransformTarget.ROTATION:
		_fixed_pivot_parent = _base_position + _pivot_point.rotated(_base_rotation)

	_initialize_spring_state()

	if debug_enabled:
		var target_name: String = TransformTarget.keys()[transform_target]
		print("[%s] Spring start (2D, %s). Stiffness: %.0f, Damping: %.0f" % [
			name, target_name, stiffness, damping
		])


func _apply_effect(_progress_unused: float) -> void:
	var target := _get_target_node2d()
	if target == null:
		return

	var delta := get_physics_process_delta_time() if use_physics_process else get_process_delta_time()

	_spring_step(delta)
	_apply_spring_value()

	if _is_spring_settled():
		_current_value = _spring_target_value
		_apply_spring_value()

		if debug_enabled:
			print("[%s] Spring settled at target" % name)


func _on_animate_out_complete() -> void:
	var target := _get_target_node2d()
	if target == null:
		return

	_current_value = _spring_target_value
	_apply_spring_value()

	if debug_enabled:
		print("[%s] Spring complete" % name)


func _invalidate_base_cache() -> void:
	_has_base = false
	_pivot_resolved = false
	if debug_enabled:
		print("[%s] Spring base cache invalidated" % name)

# =============================================================================
# SPRING STATE INITIALIZATION
# =============================================================================

func _initialize_spring_state() -> void:
	_springing_to_offset = (_target_progress > 0.5)

	var target := _get_target_node2d()
	if target == null:
		return

	match transform_target:
		TransformTarget.POSITION:
			_current_value = target.position
			_spring_target_value = _base_position + position_offset if _springing_to_offset else _base_position
			_velocity = Vector2.ZERO
		TransformTarget.ROTATION:
			_current_value = target.rotation
			var offset_rad := deg_to_rad(rotation_offset_degrees)
			_spring_target_value = _base_rotation + offset_rad if _springing_to_offset else _base_rotation
			_velocity = 0.0
		TransformTarget.SCALE:
			_current_value = target.scale
			_spring_target_value = _base_scale + scale_offset if _springing_to_offset else _base_scale
			_velocity = Vector2.ZERO

	if debug_enabled:
		print("[%s] Spring initialized. To offset: %s, Current: %s, Target: %s" % [
			name, _springing_to_offset, _current_value, _spring_target_value
		])

# =============================================================================
# SPRING PHYSICS
# =============================================================================

func _spring_step(delta: float) -> void:
	match transform_target:
		TransformTarget.POSITION, TransformTarget.SCALE:
			_spring_step_vector2(delta)
		TransformTarget.ROTATION:
			_spring_step_float(delta)


func _spring_step_float(delta: float) -> void:
	var current := _current_value as float
	var target := _spring_target_value as float
	var vel := _velocity as float

	var displacement := target - current
	var spring_force := displacement * stiffness
	var damping_force := vel * damping
	var acceleration := (spring_force - damping_force) / mass

	vel += acceleration * delta
	current += vel * delta

	_velocity = vel
	_current_value = current


func _spring_step_vector2(delta: float) -> void:
	var current := _current_value as Vector2
	var target := _spring_target_value as Vector2
	var vel := _velocity as Vector2

	var displacement := target - current
	var spring_force := displacement * stiffness
	var damping_force := vel * damping
	var acceleration := (spring_force - damping_force) / mass

	vel += acceleration * delta
	current += vel * delta

	_velocity = vel
	_current_value = current

# =============================================================================
# SETTLEMENT CHECK
# =============================================================================

func _is_spring_settled() -> bool:
	match transform_target:
		TransformTarget.POSITION, TransformTarget.SCALE:
			return _is_settled_vector2()
		TransformTarget.ROTATION:
			return _is_settled_float()
	return false


func _is_settled_float() -> bool:
	var vel := _velocity as float
	var current := _current_value as float
	var target := _spring_target_value as float
	return absf(vel) < velocity_threshold and absf(current - target) < value_threshold


func _is_settled_vector2() -> bool:
	var vel := _velocity as Vector2
	var current := _current_value as Vector2
	var target := _spring_target_value as Vector2
	return vel.length() < velocity_threshold and current.distance_to(target) < value_threshold

# =============================================================================
# VALUE APPLICATION (with pivot compensation for rotation/scale)
# =============================================================================

func _apply_spring_value() -> void:
	var target := _get_target_node2d()
	if target == null:
		return

	match transform_target:
		TransformTarget.POSITION:
			target.position = _current_value as Vector2
		TransformTarget.ROTATION:
			var new_rotation := _current_value as float
			target.rotation = new_rotation
			# Pivot compensation: adjust position so pivot point stays stationary
			if _pivot_point != Vector2.ZERO:
				target.position = _fixed_pivot_parent - _pivot_point.rotated(new_rotation)
		TransformTarget.SCALE:
			var new_scale := _current_value as Vector2
			# Pivot compensation: adjust position so pivot point stays stationary
			if _pivot_point != Vector2.ZERO:
				var scale_ratio := new_scale / _base_scale
				var pivot_delta := _pivot_point * (Vector2.ONE - scale_ratio)
				target.position = _base_position + pivot_delta
			target.scale = new_scale

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
	_base_rotation = target.rotation
	_base_scale = target.scale
	_has_base = true

	if debug_enabled:
		print("[%s] Captured base: pos=%s, rot=%.1f°, scale=%s" % [
			name, _base_position, rad_to_deg(_base_rotation), _base_scale
		])

# =============================================================================
# PIVOT RESOLUTION (ROTATION and SCALE)
# =============================================================================

## Resolve the pivot point based on pivot_mode. Node2D has no native
## pivot_offset, so AUTO_CENTER infers visual bounds from child nodes.
func _resolve_pivot() -> void:
	match pivot_mode:
		PivotMode.AUTO_CENTER:
			if _target_node is Node2D:
				var n2d := _target_node as Node2D
				var bounds := _infer_node2d_local_bounds(n2d)
				if bounds.size == Vector2.ZERO:
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
# SIZE INFERENCE (for pivot resolution)
# =============================================================================

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
				return {"rotation": n2d.rotation, "position": n2d.position}
			TransformTarget.SCALE:
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
			_base_rotation = dict.get("rotation", 0.0) as float
			_base_position = dict.get("position", Vector2.ZERO) as Vector2
		TransformTarget.SCALE:
			_base_scale = dict.get("scale", Vector2.ONE) as Vector2
			_base_position = dict.get("position", Vector2.ZERO) as Vector2

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
	if not (parent is Node2D):
		warnings.append("Spring2DJuiceComp requires a Node2D parent.")
	return warnings
