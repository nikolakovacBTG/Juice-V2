## Shake3DJuiceComp.gd
## ============================================================================
## WHAT: Consolidated shake effect for Node3D nodes. Combines position, rotation,
##       and scale shake into a single component with a TransformTarget selector.
##       Uses _get_property_list() to conditionally show only relevant exports.
## WHY: Replaces 3 separate scripts (PositionShake3D, RotationShake3D,
##      ScaleShake3D) with one unified component, reducing file count and
##      ensuring consistent behavior across transform types.
## SYSTEM: Juicing System (addons/juice/) - 3D Domain
## DOES NOT: Handle Control or Node2D targets (use ShakeControl/Shake2D).
## DOES NOT: Handle arbitrary property shaking (use ShakePropertyJuiceComp).
## DOES NOT: Handle camera shake (use Camera3DJuiceComp / Camera2DJuiceComp).
## ============================================================================
##
## KEY CONCEPT:
## Shake is TIME-driven during animation, not progress-driven.
## Progress only controls the decay envelope (amplitude reduction).
## The actual oscillation comes from sin(time * frequency) blended with
## per-frame randomness.
##
## TRANSFORM TARGETS:
## - POSITION: Shakes Node3D.position with Vector3 strength + randomness
## - ROTATION: Shakes Node3D.rotation with Vector3 amplitude (per-axis degrees)
##             + direction randomization per axis
## - SCALE: Shakes Node3D.scale with Vector3 amplitude + uniform option
##
## PIVOT (ROTATION and SCALE only):
## Node3D has no native pivot, so AUTO_CENTER and CUSTOM use position
## compensation to simulate rotation/scale around an arbitrary point. The pivot
## point is inferred from child mesh AABBs and collision shapes.
##
## CONDITIONAL EXPORTS:
## Changing transform_target triggers notify_property_list_changed() which
## shows/hides the relevant parameters via _get_property_list(). Properties
## added this way appear AFTER all @export properties in the inspector.
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBase3D.svg")
class_name Shake3DJuiceComp
extends JuiceCompBase

# =============================================================================
# TRANSFORM TARGET SELECTION
# =============================================================================

## Which transform property to shake
enum TransformTarget {
	POSITION,  ## Shake Node3D.position (XYZ)
	ROTATION,  ## Shake Node3D.rotation (XYZ Euler degrees)
	SCALE      ## Shake Node3D.scale (XYZ)
}

@export var transform_target: TransformTarget = TransformTarget.POSITION:
	set(value):
		transform_target = value
		notify_property_list_changed()

# =============================================================================
# SHARED SHAKE CONFIGURATION (always visible)
# =============================================================================

@export_group("Shake")

## Oscillations per second (Hz) — higher = more frantic
@export var shake_frequency: float = 20.0

## If true, shake intensity decreases over duration (recommended for impacts)
@export var decay: bool = true

# =============================================================================
# PIVOT MODE (shown for ROTATION and SCALE only, via _get_property_list)
# =============================================================================

## Determines how the pivot point is calculated for rotation/scale.
## Node3D has no native pivot, so AUTO_CENTER and CUSTOM use position
## compensation to simulate the pivot.
enum PivotMode {
	AUTO_CENTER,  ## Automatically center pivot on visual bounds (AABB)
	INHERIT,      ## Rotate/scale around node's own origin (no compensation)
	CUSTOM        ## Use custom_pivot offset below
}

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — they are shown/hidden via _get_property_list()
# =============================================================================

# --- POSITION ---
var position_strength: Vector3 = Vector3(0.2, 0.2, 0.2)
var position_randomness: float = 0.5

# --- ROTATION ---
## Per-axis amplitude in degrees. Set individual axes to 0 to disable.
var rotation_amplitude: Vector3 = Vector3(10.0, 10.0, 0.0)
var rotation_randomize_direction: bool = true

# --- SCALE ---
var scale_amplitude: Vector3 = Vector3(0.15, 0.15, 0.15)
var scale_randomness: float = 0.5
var scale_uniform: bool = true

# --- PIVOT (ROTATION + SCALE) ---
var pivot_mode: int = PivotMode.AUTO_CENTER
var custom_pivot: Vector3 = Vector3.ZERO

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _base_position: Vector3 = Vector3.ZERO
var _base_rotation: Vector3 = Vector3.ZERO
var _base_scale: Vector3 = Vector3.ONE

var _has_base: bool = false
var _shake_time: float = 0.0
var _shake_seed: float = 0.0

## Per-axis direction multipliers for rotation (+1 or -1)
var _direction_multiplier: Vector3 = Vector3.ONE
var _last_sine_sign: Vector3 = Vector3.ONE

## Resolved pivot point in local space
var _pivot_point: Vector3 = Vector3.ZERO
var _pivot_resolved: bool = false

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	match transform_target:
		TransformTarget.POSITION:
			props.append({
				"name": "position_strength",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
			props.append({
				"name": "position_randomness",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,1.0,0.01",
			})

		TransformTarget.ROTATION:
			props.append({
				"name": "rotation_amplitude",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
			props.append({
				"name": "rotation_randomize_direction",
				"type": TYPE_BOOL,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
			props.append_array(_get_pivot_properties())

		TransformTarget.SCALE:
			props.append({
				"name": "scale_amplitude",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
			props.append({
				"name": "scale_randomness",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,1.0,0.01",
			})
			props.append({
				"name": "scale_uniform",
				"type": TYPE_BOOL,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
			props.append_array(_get_pivot_properties())

	return props


func _get_pivot_properties() -> Array[Dictionary]:
	return [
		{
			"name": "pivot_mode",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Auto Center,Inherit,Custom",
		},
		{
			"name": "custom_pivot",
			"type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT,
		},
	]


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"position_strength": position_strength = value; return true
		&"position_randomness": position_randomness = value; return true
		&"rotation_amplitude": rotation_amplitude = value; return true
		&"rotation_randomize_direction": rotation_randomize_direction = value; return true
		&"scale_amplitude": scale_amplitude = value; return true
		&"scale_randomness": scale_randomness = value; return true
		&"scale_uniform": scale_uniform = value; return true
		&"pivot_mode": pivot_mode = value; return true
		&"custom_pivot": custom_pivot = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"position_strength": return position_strength
		&"position_randomness": return position_randomness
		&"rotation_amplitude": return rotation_amplitude
		&"rotation_randomize_direction": return rotation_randomize_direction
		&"scale_amplitude": return scale_amplitude
		&"scale_randomness": return scale_randomness
		&"scale_uniform": return scale_uniform
		&"pivot_mode": return pivot_mode
		&"custom_pivot": return custom_pivot
	return null

# =============================================================================
# LIFECYCLE OVERRIDES
# =============================================================================

func _ready() -> void:
	super._ready()


func _on_animate_start() -> void:
	if not _has_base:
		_capture_base()

	if transform_target != TransformTarget.POSITION and not _pivot_resolved:
		_resolve_pivot()

	_shake_seed = randf() * 1000.0
	_shake_time = 0.0
	_direction_multiplier = Vector3.ONE
	_last_sine_sign = Vector3.ONE

	if debug_enabled:
		var target_name: String = TransformTarget.keys()[transform_target]
		print("[%s] Shake start (3D, %s). Freq: %.1f Hz" % [name, target_name, shake_frequency])


func _apply_effect(progress: float) -> void:
	if not is_instance_valid(_target_node):
		return
	if not (_target_node is Node3D):
		return

	_shake_time += get_process_delta_time()

	var decay_mult := 1.0
	if decay:
		decay_mult = 1.0 - progress

	match transform_target:
		TransformTarget.POSITION:
			_apply_position_shake(decay_mult)
		TransformTarget.ROTATION:
			_apply_rotation_shake(decay_mult)
		TransformTarget.SCALE:
			_apply_scale_shake(decay_mult)


func _on_animate_out_complete() -> void:
	if not is_instance_valid(_target_node) or not (_target_node is Node3D):
		return

	var n3d := _target_node as Node3D
	match transform_target:
		TransformTarget.POSITION:
			n3d.position = _base_position
		TransformTarget.ROTATION:
			n3d.rotation = _base_rotation
			n3d.position = _base_position
		TransformTarget.SCALE:
			n3d.scale = _base_scale
			n3d.position = _base_position

	if debug_enabled:
		print("[%s] Shake complete, returned to base" % name)


func _invalidate_base_cache() -> void:
	_has_base = false
	_pivot_resolved = false
	if debug_enabled:
		print("[%s] Base cache invalidated" % name)

# =============================================================================
# POSITION SHAKE
# =============================================================================

func _apply_position_shake(intensity: float) -> void:
	var freq_mult := _shake_time * shake_frequency * TAU
	var sine_x := sin(freq_mult + _shake_seed)
	var sine_y := sin(freq_mult * 1.3 + _shake_seed + 100.0)
	var sine_z := sin(freq_mult * 0.7 + _shake_seed + 200.0)

	var random_x := randf_range(-1.0, 1.0)
	var random_y := randf_range(-1.0, 1.0)
	var random_z := randf_range(-1.0, 1.0)

	var final_x := lerpf(sine_x, random_x, position_randomness)
	var final_y := lerpf(sine_y, random_y, position_randomness)
	var final_z := lerpf(sine_z, random_z, position_randomness)

	var offset := Vector3(
		final_x * position_strength.x * intensity,
		final_y * position_strength.y * intensity,
		final_z * position_strength.z * intensity
	)

	(_target_node as Node3D).position = _base_position + offset

# =============================================================================
# ROTATION SHAKE (per-axis with position compensation for pivot)
# =============================================================================

func _apply_rotation_shake(intensity: float) -> void:
	var n3d := _target_node as Node3D
	var freq_base := _shake_time * shake_frequency * TAU

	# Per-axis sine values with slight frequency offsets for variety
	var sine_x := sin(freq_base)
	var sine_y := sin(freq_base * 1.3 + 100.0)
	var sine_z := sin(freq_base * 0.7 + 200.0)

	# Detect zero-crossings for direction randomization (per axis)
	if rotation_randomize_direction:
		_update_direction_axis(sine_x, 0)
		_update_direction_axis(sine_y, 1)
		_update_direction_axis(sine_z, 2)

	var current_amplitude := rotation_amplitude * intensity

	var shake_degrees := Vector3(
		sine_x * current_amplitude.x * _direction_multiplier.x,
		sine_y * current_amplitude.y * _direction_multiplier.y,
		sine_z * current_amplitude.z * _direction_multiplier.z
	)
	var shake_radians := Vector3(
		deg_to_rad(shake_degrees.x),
		deg_to_rad(shake_degrees.y),
		deg_to_rad(shake_degrees.z)
	)

	var new_rotation := _base_rotation + shake_radians

	# Apply rotation with position compensation for pivot
	if _pivot_point != Vector3.ZERO:
		var rotation_delta := new_rotation - _base_rotation
		var basis_delta := Basis.from_euler(rotation_delta)
		var offset := _pivot_point - basis_delta * _pivot_point
		n3d.rotation = new_rotation
		n3d.position = _base_position + offset
	else:
		n3d.rotation = new_rotation

# =============================================================================
# SCALE SHAKE (with position compensation for pivot)
# =============================================================================

func _apply_scale_shake(intensity: float) -> void:
	var n3d := _target_node as Node3D
	var freq_mult := _shake_time * shake_frequency * TAU
	var offset: Vector3

	if scale_uniform:
		var sine_val := sin(freq_mult + _shake_seed)
		var random_val := randf_range(-1.0, 1.0)
		var final_val := lerpf(sine_val, random_val, scale_randomness)
		var offset_val := final_val * scale_amplitude.x * intensity
		offset = Vector3(offset_val, offset_val, offset_val)
	else:
		var sine_x := sin(freq_mult + _shake_seed)
		var sine_y := sin(freq_mult * 1.3 + _shake_seed + 100.0)
		var sine_z := sin(freq_mult * 0.7 + _shake_seed + 200.0)
		var random_x := randf_range(-1.0, 1.0)
		var random_y := randf_range(-1.0, 1.0)
		var random_z := randf_range(-1.0, 1.0)
		var final_x := lerpf(sine_x, random_x, scale_randomness)
		var final_y := lerpf(sine_y, random_y, scale_randomness)
		var final_z := lerpf(sine_z, random_z, scale_randomness)
		offset = Vector3(
			final_x * scale_amplitude.x * intensity,
			final_y * scale_amplitude.y * intensity,
			final_z * scale_amplitude.z * intensity
		)

	var new_scale := _base_scale + offset

	# Apply scale with position compensation for pivot
	if _pivot_point != Vector3.ZERO:
		var scale_ratio := new_scale / _base_scale
		var pos_offset := _pivot_point - _pivot_point * scale_ratio
		n3d.scale = new_scale
		n3d.position = _base_position + pos_offset
	else:
		n3d.scale = new_scale

# =============================================================================
# BASE CAPTURE
# =============================================================================

func _capture_base() -> void:
	if _has_base:
		return

	if _target_node is Node3D:
		var n3d := _target_node as Node3D
		_base_position = n3d.position
		_base_rotation = n3d.rotation
		_base_scale = n3d.scale
	else:
		_base_position = Vector3.ZERO
		_base_rotation = Vector3.ZERO
		_base_scale = Vector3.ONE
		if debug_enabled and _target_node != null:
			push_warning("[%s] Target '%s' is not Node3D" % [name, str(_target_node.name)])

	_has_base = true

	if debug_enabled:
		print("[%s] Captured base — pos: %s, rot: %s, scale: %s" % [
			name, _base_position, _base_rotation, _base_scale
		])

# =============================================================================
# ROTATION DIRECTION RANDOMIZATION HELPER
# =============================================================================

## Update direction multiplier for a single axis on zero-crossing
func _update_direction_axis(sine_value: float, axis: int) -> void:
	var current_sign := signf(sine_value)
	var last_sign: float
	match axis:
		0: last_sign = _last_sine_sign.x
		1: last_sign = _last_sine_sign.y
		2: last_sign = _last_sine_sign.z
		_: return

	if current_sign != last_sign and current_sign != 0.0:
		if randf() > 0.5:
			match axis:
				0: _direction_multiplier.x *= -1.0
				1: _direction_multiplier.y *= -1.0
				2: _direction_multiplier.z *= -1.0
		match axis:
			0: _last_sine_sign.x = current_sign
			1: _last_sine_sign.y = current_sign
			2: _last_sine_sign.z = current_sign

# =============================================================================
# PIVOT HANDLING — Transform-based position compensation for Node3D
# =============================================================================

func _resolve_pivot() -> void:
	match pivot_mode:
		PivotMode.AUTO_CENTER:
			_pivot_point = _infer_center_offset()
		PivotMode.INHERIT:
			_pivot_point = Vector3.ZERO
		PivotMode.CUSTOM:
			_pivot_point = custom_pivot

	_pivot_resolved = true

	if debug_enabled:
		print("[%s] Pivot resolved: %s (mode: %s)" % [
			name, _pivot_point, PivotMode.keys()[pivot_mode]
		])


func _infer_center_offset() -> Vector3:
	if not is_instance_valid(_target_node) or not (_target_node is Node3D):
		return Vector3.ZERO

	var n3d := _target_node as Node3D
	var bounds := _infer_node3d_bounds_recursive(n3d)
	if bounds.size == Vector3.ZERO:
		return Vector3.ZERO

	return bounds.position + bounds.size * 0.5


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
				return {"rotation": n3d.rotation, "position": n3d.position}
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
			_base_rotation = dict.get("rotation", Vector3.ZERO) as Vector3
			_base_position = dict.get("position", Vector3.ZERO) as Vector3
		TransformTarget.SCALE:
			_base_scale = dict.get("scale", Vector3.ONE) as Vector3
			_base_position = dict.get("position", Vector3.ZERO) as Vector3

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
			n3d.rotation = dict.get("rotation", Vector3.ZERO) as Vector3
			n3d.position = dict.get("position", Vector3.ZERO) as Vector3
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
		warnings.append("Parent must be a Node3D node. Use ShakeControl/Shake2D for other domains.")
	return warnings
