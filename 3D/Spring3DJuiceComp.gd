## Spring3DJuiceComp.gd
## ============================================================================
## WHAT: Physics-based spring animation for Node3D nodes. Combines position,
##       rotation, and scale spring into a single component with a TransformTarget
##       selector. Uses _get_property_list() to conditionally show only relevant
##       exports in the inspector.
## WHY: Replaces the TRANSFORM mode of the unified SpringJuiceComp for Node3D
##      nodes. Clean inspector — only shows 3D-relevant exports (Vector3
##      offsets, Euler rotation, AABB-based pivot).
## SYSTEM: Juicing System (addons/juice/) - 3D Domain
## DOES NOT: Handle Control or Node2D targets (use SpringControl/Spring2D).
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
## - POSITION: Springs Node3D.position with Vector3 offset
## - ROTATION: Springs Node3D.rotation_degrees with Vector3 offset (Euler)
## - SCALE: Springs Node3D.scale with Vector3 offset + pivot compensation
##
## PIVOT (ROTATION):
## Uses rotation_pivot_offset (Vector3, local space). Fixed in parent space at
## animation start: fixed_pivot = base_origin + base_basis * pivot_offset,
## new_origin = fixed_pivot - new_basis * pivot_offset.
##
## PIVOT (SCALE):
## - AUTO_CENTER: Infer center from MeshInstance3D AABB / CollisionShape3D.
## - INHERIT: Scale from node origin (no compensation).
## - CUSTOM: Scale from scale_custom_pivot (local-space world units).
##
## CONDITIONAL EXPORTS:
## Changing transform_target triggers notify_property_list_changed() which
## shows/hides the relevant parameters via _get_property_list().
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBase3D.svg")
class_name Spring3DJuiceComp
extends JuiceCompBase

# =============================================================================
# TRANSFORM TARGET SELECTION
# =============================================================================

## Which transform property to spring
enum TransformTarget {
	POSITION,  ## Spring Node3D.position
	ROTATION,  ## Spring Node3D.rotation_degrees (Euler)
	SCALE      ## Spring Node3D.scale
}

@export var transform_target: TransformTarget = TransformTarget.POSITION:
	set(value):
		transform_target = value
		notify_property_list_changed()

# =============================================================================
# SPRING PHYSICS CONFIGURATION (always visible)
# =============================================================================

@export_group("Spring Physics")

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
# ENUMS
# =============================================================================

## Determines how the pivot point is calculated for scaling
enum PivotMode {
	AUTO_CENTER,  ## Infer center from AABB and compensate position
	INHERIT,      ## Scale from node origin (no compensation)
	CUSTOM        ## Scale from custom_pivot (local-space world units)
}

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# =============================================================================

# --- POSITION ---
## Offset to spring towards
var position_offset: Vector3 = Vector3(0, 0.5, 0)

# --- ROTATION ---
## Rotation offset in degrees to spring towards (Euler angles)
var rotation_offset: Vector3 = Vector3(0, 15, 0)
## Pivot point offset from node origin (local space) for rotation
var rotation_pivot_offset: Vector3 = Vector3.ZERO

# --- SCALE ---
## Scale offset to spring towards (added to base scale)
var scale_offset: Vector3 = Vector3(0.2, 0.2, 0.2)
## Pivot mode for scaling
var scale_pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		scale_pivot_mode = value
		notify_property_list_changed()
## Custom pivot in local-space coordinates (world units)
var scale_custom_pivot: Vector3 = Vector3.ZERO

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _base_position: Vector3 = Vector3.ZERO
var _base_transform: Transform3D = Transform3D.IDENTITY
var _base_rotation_degrees: Vector3 = Vector3.ZERO
var _base_scale: Vector3 = Vector3.ONE

var _has_base: bool = false

## Fixed pivot position in parent space (for rotation, computed once at start)
var _fixed_pivot_parent: Vector3 = Vector3.ZERO

## Resolved pivot point for scale (local space)
var _scale_pivot_point: Vector3 = Vector3.ZERO
var _scale_pivot_resolved: bool = false

## Current spring value (what we're animating) — always Vector3 in 3D
var _current_value: Vector3

## Target value we're springing towards
var _spring_target_value: Vector3

## Current velocity
var _velocity: Vector3

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
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})

		TransformTarget.ROTATION:
			props.append({
				"name": "rotation_offset",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})
			props.append({
				"name": "rotation_pivot_offset",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})

		TransformTarget.SCALE:
			props.append({
				"name": "scale_offset",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})
			props.append({
				"name": "scale_pivot_mode",
				"type": TYPE_INT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Auto Center,Inherit,Custom",
			})
			if scale_pivot_mode == PivotMode.CUSTOM:
				props.append({
					"name": "scale_custom_pivot",
					"type": TYPE_VECTOR3,
					"usage": PROPERTY_USAGE_DEFAULT,
					"hint": PROPERTY_HINT_NONE,
				})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		# Position
		&"position_offset": position_offset = value; return true
		# Rotation
		&"rotation_offset": rotation_offset = value; return true
		&"rotation_pivot_offset": rotation_pivot_offset = value; return true
		# Scale
		&"scale_offset": scale_offset = value; return true
		&"scale_pivot_mode": scale_pivot_mode = value; return true
		&"scale_custom_pivot": scale_custom_pivot = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		# Position
		&"position_offset": return position_offset
		# Rotation
		&"rotation_offset": return rotation_offset
		&"rotation_pivot_offset": return rotation_pivot_offset
		# Scale
		&"scale_offset": return scale_offset
		&"scale_pivot_mode": return scale_pivot_mode
		&"scale_custom_pivot": return scale_custom_pivot
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

	# Resolve scale pivot if needed
	if transform_target == TransformTarget.SCALE and not _scale_pivot_resolved:
		_resolve_scale_pivot()
		_scale_pivot_resolved = true

	_initialize_spring_state()

	if debug_enabled:
		var target_name: String = TransformTarget.keys()[transform_target]
		print("[%s] Spring start (3D, %s). Stiffness: %.0f, Damping: %.0f" % [
			name, target_name, stiffness, damping
		])


func _apply_effect(_progress_unused: float) -> void:
	if not is_instance_valid(_target_node) or not (_target_node is Node3D):
		return

	var delta := get_physics_process_delta_time() if use_physics_process else get_process_delta_time()

	_spring_step_vector3(delta)
	_apply_spring_value()

	if _is_settled_vector3():
		_current_value = _spring_target_value
		_apply_spring_value()

		if debug_enabled:
			print("[%s] Spring settled at target" % name)


func _on_animate_out_complete() -> void:
	if not is_instance_valid(_target_node) or not (_target_node is Node3D):
		return

	_current_value = _spring_target_value
	_apply_spring_value()

	if debug_enabled:
		print("[%s] Spring complete" % name)


func _invalidate_base_cache() -> void:
	_has_base = false
	_scale_pivot_resolved = false
	if debug_enabled:
		print("[%s] Spring base cache invalidated" % name)

# =============================================================================
# SPRING STATE INITIALIZATION
# =============================================================================

func _initialize_spring_state() -> void:
	_springing_to_offset = (_target_progress > 0.5)

	var n3d := _target_node as Node3D

	match transform_target:
		TransformTarget.POSITION:
			_current_value = n3d.position
			_spring_target_value = _base_position + position_offset if _springing_to_offset else _base_position
		TransformTarget.ROTATION:
			_current_value = n3d.rotation_degrees
			_spring_target_value = _base_rotation_degrees + rotation_offset if _springing_to_offset else _base_rotation_degrees
		TransformTarget.SCALE:
			_current_value = n3d.scale
			_spring_target_value = _base_scale + scale_offset if _springing_to_offset else _base_scale

	_velocity = Vector3.ZERO

	if debug_enabled:
		print("[%s] Spring initialized. To offset: %s, Current: %s, Target: %s" % [
			name, _springing_to_offset, _current_value, _spring_target_value
		])

# =============================================================================
# SPRING PHYSICS
# =============================================================================

func _spring_step_vector3(delta: float) -> void:
	var current := _current_value
	var target := _spring_target_value
	var vel := _velocity

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

func _is_settled_vector3() -> bool:
	return _velocity.length() < velocity_threshold and _current_value.distance_to(_spring_target_value) < value_threshold

# =============================================================================
# VALUE APPLICATION
# =============================================================================

func _apply_spring_value() -> void:
	var n3d := _target_node as Node3D

	match transform_target:
		TransformTarget.POSITION:
			n3d.position = _current_value
		TransformTarget.ROTATION:
			# Spring drives rotation_degrees directly (Euler).
			# Apply pivot compensation if rotation_pivot_offset is set.
			n3d.rotation_degrees = _current_value

			if rotation_pivot_offset != Vector3.ZERO:
				# Rotation around pivot:
				# new_origin = fixed_pivot - new_basis * pivot_offset
				var new_basis := n3d.transform.basis
				var new_origin := _fixed_pivot_parent - new_basis * rotation_pivot_offset
				n3d.position = new_origin
		TransformTarget.SCALE:
			# Pivot compensation for scale
			if _scale_pivot_point != Vector3.ZERO:
				var scale_ratio := _current_value / _base_scale
				var pivot_delta := _scale_pivot_point * (Vector3.ONE - scale_ratio)
				n3d.position = _base_position + pivot_delta
			n3d.scale = _current_value

# =============================================================================
# BASE CAPTURE
# =============================================================================

func _capture_base() -> void:
	if _has_base:
		return

	if not (_target_node is Node3D):
		if debug_enabled and _target_node != null:
			push_warning("[%s] Target '%s' is not Node3D" % [name, _target_node.name])
		_has_base = true
		return

	var n3d := _target_node as Node3D
	_base_position = n3d.position
	_base_transform = n3d.transform
	_base_rotation_degrees = n3d.rotation_degrees
	_base_scale = n3d.scale

	# Pre-compute the fixed pivot position in parent space for rotation
	_fixed_pivot_parent = _base_transform.origin + _base_transform.basis * rotation_pivot_offset

	_has_base = true

	if debug_enabled:
		print("[%s] Captured base: pos=%s, rot=%s°, scale=%s" % [
			name, _base_position, _base_rotation_degrees, _base_scale
		])

# =============================================================================
# SCALE PIVOT RESOLUTION
# =============================================================================

func _resolve_scale_pivot() -> void:
	match scale_pivot_mode:
		PivotMode.AUTO_CENTER:
			if _target_node is Node3D:
				var n3d := _target_node as Node3D
				var bounds := _infer_node3d_local_bounds(n3d)
				if bounds.size == Vector3.ZERO:
					bounds = _infer_node3d_bounds_recursive(n3d)
				if bounds.size != Vector3.ZERO:
					_scale_pivot_point = bounds.get_center()
				else:
					_scale_pivot_point = Vector3.ZERO
				if debug_enabled:
					print("[%s] Auto-center scale pivot: bounds=%s, center=%s" % [name, bounds, _scale_pivot_point])
			else:
				_scale_pivot_point = Vector3.ZERO
		PivotMode.INHERIT:
			_scale_pivot_point = Vector3.ZERO
		PivotMode.CUSTOM:
			_scale_pivot_point = scale_custom_pivot

# =============================================================================
# SIZE INFERENCE (for scale pivot resolution)
# =============================================================================

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
				return {"transform": n3d.transform}
			TransformTarget.SCALE:
				return {"scale": n3d.scale, "position": n3d.position}
	return null


func _recipe_apply_natural(_target: Node, natural: Variant) -> void:
	if not (natural is Dictionary):
		return
	var dict := natural as Dictionary

	match transform_target:
		TransformTarget.POSITION:
			_base_position = dict.get("position", Vector3.ZERO) as Vector3
		TransformTarget.ROTATION:
			_base_transform = dict.get("transform", Transform3D.IDENTITY) as Transform3D
			_base_position = _base_transform.origin
			_base_rotation_degrees = _base_transform.basis.get_euler() * (180.0 / PI)
			_fixed_pivot_parent = _base_transform.origin + _base_transform.basis * rotation_pivot_offset
		TransformTarget.SCALE:
			_base_scale = dict.get("scale", Vector3.ONE) as Vector3
			_base_position = dict.get("position", Vector3.ZERO) as Vector3

	_has_base = true
	_scale_pivot_resolved = false


func _recipe_restore_natural(target: Node, natural: Variant) -> void:
	if not (natural is Dictionary) or not (target is Node3D):
		return
	var dict := natural as Dictionary
	var n3d := target as Node3D

	match transform_target:
		TransformTarget.POSITION:
			n3d.position = dict.get("position", Vector3.ZERO) as Vector3
		TransformTarget.ROTATION:
			n3d.transform = dict.get("transform", Transform3D.IDENTITY) as Transform3D
		TransformTarget.SCALE:
			n3d.scale = dict.get("scale", Vector3.ONE) as Vector3
			n3d.position = dict.get("position", Vector3.ZERO) as Vector3

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent := get_parent()
	if parent and not parent is Node3D:
		warnings.append("Spring3DJuiceComp requires a Node3D parent.")
	return warnings
