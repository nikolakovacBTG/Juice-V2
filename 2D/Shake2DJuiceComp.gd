## Shake2DJuiceComp.gd
## ============================================================================
## WHAT: Consolidated shake effect for Node2D nodes. Combines position, rotation,
##       and scale shake into a single component with a TransformTarget selector.
##       Uses _get_property_list() to conditionally show only relevant exports.
## WHY: Replaces 3 separate scripts (PositionShake2D, RotationShake2D,
##      ScaleShake2D) with one unified component, reducing file count and
##      ensuring consistent behavior across transform types.
## SYSTEM: Juicing System (addons/juice/) - 2D Domain
## DOES NOT: Handle Control or Node3D targets (use ShakeControl/Shake3D).
## DOES NOT: Handle arbitrary property shaking (use ShakePropertyJuiceComp).
## DOES NOT: Handle camera shake (use Camera2DJuiceComp / Camera3DJuiceComp).
## ============================================================================
##
## KEY CONCEPT:
## Shake is TIME-driven during animation, not progress-driven.
## Progress only controls the decay envelope (amplitude reduction).
## The actual oscillation comes from sin(time * frequency) blended with
## per-frame randomness.
##
## TRANSFORM TARGETS:
## - POSITION: Shakes Node2D.position with Vector2 strength + randomness
## - ROTATION: Shakes Node2D.rotation with float amplitude + direction randomization
## - SCALE: Shakes Node2D.scale with Vector2 amplitude + uniform option
##
## PIVOT (ROTATION and SCALE only):
## Node2D has no native pivot_offset, so AUTO_CENTER and CUSTOM use position
## compensation to simulate rotation/scale around an arbitrary point. The pivot
## point is inferred from child visual bounds (sprites, collision shapes, etc.).
##
## CONDITIONAL EXPORTS:
## Changing transform_target triggers notify_property_list_changed() which
## shows/hides the relevant parameters via _get_property_list(). Properties
## added this way appear AFTER all @export properties in the inspector.
## ============================================================================

@tool
class_name Shake2DJuiceComp
extends JuiceCompBase

# =============================================================================
# TRANSFORM TARGET SELECTION
# =============================================================================

## Which transform property to shake
enum TransformTarget {
	POSITION,  ## Shake Node2D.position
	ROTATION,  ## Shake Node2D.rotation (single-axis Z)
	SCALE      ## Shake Node2D.scale
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
## Node2D has no native pivot_offset, so AUTO_CENTER and CUSTOM use position
## compensation to simulate the pivot.
enum PivotMode {
	AUTO_CENTER,  ## Automatically center pivot on visual bounds
	INHERIT,      ## Rotate/scale around node's own origin (no compensation)
	CUSTOM        ## Use custom_pivot offset below
}

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — they are shown/hidden via _get_property_list()
# =============================================================================

# --- POSITION ---
var position_strength: Vector2 = Vector2(5.0, 5.0)
var position_randomness: float = 0.5

# --- ROTATION ---
var rotation_amplitude: float = 10.0
var rotation_randomize_direction: bool = true

# --- SCALE ---
var scale_amplitude: Vector2 = Vector2(0.15, 0.15)
var scale_randomness: float = 0.5
var scale_uniform: bool = true

# --- PIVOT (ROTATION + SCALE) ---
var pivot_mode: int = PivotMode.AUTO_CENTER
var custom_pivot: Vector2 = Vector2.ZERO

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _base_position: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _base_scale: Vector2 = Vector2.ONE

var _has_base: bool = false
var _shake_time: float = 0.0
var _shake_seed: float = 0.0

## Rotation direction randomization state
var _direction_multiplier: float = 1.0
var _last_sine_sign: float = 1.0

## Resolved pivot point in local space
var _pivot_point: Vector2 = Vector2.ZERO
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
				"type": TYPE_VECTOR2,
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
				"type": TYPE_FLOAT,
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
				"type": TYPE_VECTOR2,
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
			"type": TYPE_VECTOR2,
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
	_direction_multiplier = 1.0
	_last_sine_sign = 1.0

	if debug_enabled:
		var target_name: String = TransformTarget.keys()[transform_target]
		print("[%s] Shake start (2D, %s). Freq: %.1f Hz" % [name, target_name, shake_frequency])


func _apply_effect(progress: float) -> void:
	if not is_instance_valid(_target_node):
		return
	if not (_target_node is Node2D):
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
	if not is_instance_valid(_target_node) or not (_target_node is Node2D):
		return

	var n2d := _target_node as Node2D
	match transform_target:
		TransformTarget.POSITION:
			n2d.position = _base_position
		TransformTarget.ROTATION:
			n2d.rotation = _base_rotation
			n2d.position = _base_position
		TransformTarget.SCALE:
			n2d.scale = _base_scale
			n2d.position = _base_position

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

	var random_x := randf_range(-1.0, 1.0)
	var random_y := randf_range(-1.0, 1.0)

	var final_x := lerpf(sine_x, random_x, position_randomness)
	var final_y := lerpf(sine_y, random_y, position_randomness)

	var offset := Vector2(
		final_x * position_strength.x * intensity,
		final_y * position_strength.y * intensity
	)

	(_target_node as Node2D).position = _base_position + offset

# =============================================================================
# ROTATION SHAKE (with position compensation for pivot)
# =============================================================================

func _apply_rotation_shake(intensity: float) -> void:
	var n2d := _target_node as Node2D
	var sine_value := sin(_shake_time * shake_frequency * TAU)

	if rotation_randomize_direction:
		var current_sign := signf(sine_value)
		if current_sign != _last_sine_sign and current_sign != 0.0:
			if randf() > 0.5:
				_direction_multiplier *= -1.0
			_last_sine_sign = current_sign

	var current_amplitude := rotation_amplitude * intensity
	var shake_offset := sine_value * current_amplitude * _direction_multiplier
	var new_rotation := _base_rotation + deg_to_rad(shake_offset)

	# Apply rotation with position compensation for pivot
	if _pivot_point != Vector2.ZERO:
		var rotation_delta := new_rotation - _base_rotation
		var offset := _pivot_point - _pivot_point.rotated(rotation_delta)
		n2d.rotation = new_rotation
		n2d.position = _base_position + offset
	else:
		n2d.rotation = new_rotation

# =============================================================================
# SCALE SHAKE (with position compensation for pivot)
# =============================================================================

func _apply_scale_shake(intensity: float) -> void:
	var n2d := _target_node as Node2D
	var freq_mult := _shake_time * shake_frequency * TAU
	var offset: Vector2

	if scale_uniform:
		var sine_val := sin(freq_mult + _shake_seed)
		var random_val := randf_range(-1.0, 1.0)
		var final_val := lerpf(sine_val, random_val, scale_randomness)
		var offset_val := final_val * scale_amplitude.x * intensity
		offset = Vector2(offset_val, offset_val)
	else:
		var sine_x := sin(freq_mult + _shake_seed)
		var sine_y := sin(freq_mult * 1.3 + _shake_seed + 100.0)
		var random_x := randf_range(-1.0, 1.0)
		var random_y := randf_range(-1.0, 1.0)
		var final_x := lerpf(sine_x, random_x, scale_randomness)
		var final_y := lerpf(sine_y, random_y, scale_randomness)
		offset = Vector2(
			final_x * scale_amplitude.x * intensity,
			final_y * scale_amplitude.y * intensity
		)

	var new_scale := _base_scale + offset

	# Apply scale with position compensation for pivot
	if _pivot_point != Vector2.ZERO:
		var scale_ratio := new_scale / _base_scale
		var pos_offset := _pivot_point - _pivot_point * scale_ratio
		n2d.scale = new_scale
		n2d.position = _base_position + pos_offset
	else:
		n2d.scale = new_scale

# =============================================================================
# BASE CAPTURE
# =============================================================================

func _capture_base() -> void:
	if _has_base:
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
		if debug_enabled and _target_node != null:
			push_warning("[%s] Target '%s' is not Node2D" % [name, str(_target_node.name)])

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
			_pivot_point = _infer_center_offset()
		PivotMode.INHERIT:
			_pivot_point = Vector2.ZERO
		PivotMode.CUSTOM:
			_pivot_point = custom_pivot

	_pivot_resolved = true

	if debug_enabled:
		print("[%s] Pivot resolved: %s (mode: %s)" % [
			name, _pivot_point, PivotMode.keys()[pivot_mode]
		])


func _infer_center_offset() -> Vector2:
	if not is_instance_valid(_target_node) or not (_target_node is Node2D):
		return Vector2.ZERO

	var n2d := _target_node as Node2D
	var bounds := _infer_node2d_bounds_recursive(n2d)
	if bounds.size == Vector2.ZERO:
		return Vector2.ZERO

	return bounds.position + bounds.size * 0.5


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
	if parent and not parent is Node2D:
		warnings.append("Parent must be a Node2D node. Use ShakeControl/Shake3D for other domains.")
	return warnings
