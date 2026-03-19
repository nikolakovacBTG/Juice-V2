## ShakeControlJuiceComp.gd
## ============================================================================
## WHAT: Consolidated shake effect for Control nodes. Combines position, rotation,
##       and scale shake into a single component with a TransformTarget selector.
##       Uses _get_property_list() to conditionally show only relevant exports.
## WHY: Replaces 3 separate scripts (PositionShakeControl, RotationShakeControl,
##      ScaleShakeControl) with one unified component, reducing file count and
##      ensuring consistent behavior across transform types.
## SYSTEM: Juicing System (addons/juice/) - Control Domain
## DOES NOT: Handle Node2D or Node3D targets (use Shake2D/Shake3D).
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
## - POSITION: Shakes Control.position with Vector2 strength + randomness
## - ROTATION: Shakes Control.rotation with float amplitude + direction randomization
## - SCALE: Shakes Control.scale with Vector2 amplitude + uniform option
##
## PIVOT (ROTATION and SCALE only):
## Uses the native Control.pivot_offset property via PivotMode enum.
## Reactive pivot updates via the Control's resized signal.
##
## CONDITIONAL EXPORTS:
## Changing transform_target triggers notify_property_list_changed() which
## shows/hides the relevant parameters via _get_property_list(). Properties
## added this way appear AFTER all @export properties in the inspector.
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBaseControl.svg")
class_name ShakeControlJuiceComp
extends JuiceCompBase

# =============================================================================
# TRANSFORM TARGET SELECTION
# =============================================================================

## Which transform property to shake
enum TransformTarget {
	POSITION,  ## Shake Control.position
	ROTATION,  ## Shake Control.rotation (single-axis Z)
	SCALE      ## Shake Control.scale
}

@export_group("Effect")

@export var transform_target: TransformTarget = TransformTarget.POSITION:
	set(value):
		transform_target = value
		notify_property_list_changed()

# =============================================================================
# SHARED SHAKE CONFIGURATION (always visible)
# =============================================================================

## Oscillations per second (Hz) — higher = more frantic
@export var shake_frequency: float = 20.0

## If true, shake intensity decreases over duration (recommended for impacts)
@export var decay: bool = true

# =============================================================================
# PIVOT MODE (shown for ROTATION and SCALE only, via _get_property_list)
# =============================================================================

## Determines how the pivot point is calculated
enum PivotMode {
	AUTO_CENTER,  ## Automatically center pivot (most common for UI)
	INHERIT,      ## Use the node's existing pivot_offset
	CUSTOM        ## Use custom_pivot values below
}

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — they are shown/hidden via _get_property_list()
# =============================================================================

# --- POSITION ---
## Maximum offset from original position in pixels
var position_strength: Vector2 = Vector2(5.0, 5.0)
## Blend between predictable sine wave (0) and fully random (1)
var position_randomness: float = 0.5

# --- ROTATION ---
## Maximum rotation amplitude in degrees
var rotation_amplitude: float = 10.0
## If true, randomize direction at each oscillation peak for chaos
var rotation_randomize_direction: bool = true

# --- SCALE ---
## Maximum scale offset from original scale
var scale_amplitude: Vector2 = Vector2(0.15, 0.15)
## Blend between sine and random for scale shake
var scale_randomness: float = 0.5
## When true, X amplitude drives all axes equally
var scale_uniform: bool = true

# --- PIVOT (ROTATION + SCALE) ---
var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()
## Custom pivot in normalized coordinates (0-1). (0.5, 0.5) = center.
var custom_pivot: Vector2 = Vector2(0.5, 0.5)

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Captured base values of target
var _base_position: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _base_scale: Vector2 = Vector2.ONE

## Whether base has been captured
var _has_base: bool = false

## Accumulated shake time (drives the oscillation independently of progress)
var _shake_time: float = 0.0

## Random seed for consistent-ish randomness per play
var _shake_seed: float = 0.0

## Random direction multiplier for rotation (+1 or -1)
var _direction_multiplier: float = 1.0

## Last sign of sine wave (for detecting zero-crossings in rotation mode)
var _last_sine_sign: float = 1.0

## Whether pivot has been resolved for current target
var _pivot_resolved: bool = false

## Reference to the connected Control for resized signal cleanup
var _connected_control: Control = null

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
				"hint": PROPERTY_HINT_NONE,
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
				"hint": PROPERTY_HINT_NONE,
			})
			props.append({
				"name": "rotation_randomize_direction",
				"type": TYPE_BOOL,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
			# Pivot exports for rotation
			props.append_array(_get_pivot_properties())

		TransformTarget.SCALE:
			props.append({
				"name": "scale_amplitude",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
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
			# Pivot exports for scale
			props.append_array(_get_pivot_properties())

	return props


## Shared pivot properties used by both ROTATION and SCALE targets
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
		# Position
		&"position_strength": position_strength = value; return true
		&"position_randomness": position_randomness = value; return true
		# Rotation
		&"rotation_amplitude": rotation_amplitude = value; return true
		&"rotation_randomize_direction": rotation_randomize_direction = value; return true
		# Scale
		&"scale_amplitude": scale_amplitude = value; return true
		&"scale_randomness": scale_randomness = value; return true
		&"scale_uniform": scale_uniform = value; return true
		# Pivot
		&"pivot_mode": pivot_mode = value; return true
		&"custom_pivot": custom_pivot = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		# Position
		&"position_strength": return position_strength
		&"position_randomness": return position_randomness
		# Rotation
		&"rotation_amplitude": return rotation_amplitude
		&"rotation_randomize_direction": return rotation_randomize_direction
		# Scale
		&"scale_amplitude": return scale_amplitude
		&"scale_randomness": return scale_randomness
		&"scale_uniform": return scale_uniform
		# Pivot
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

	# Resolve pivot for rotation/scale targets
	if transform_target != TransformTarget.POSITION and not _pivot_resolved:
		_resolve_pivot()

	_shake_seed = randf() * 1000.0
	_shake_time = 0.0
	_direction_multiplier = 1.0
	_last_sine_sign = 1.0

	if debug_enabled:
		var target_name: String = TransformTarget.keys()[transform_target]
		print("[%s] Shake start (Control, %s). Freq: %.1f Hz" % [name, target_name, shake_frequency])


func _apply_effect(progress: float) -> void:
	if not is_instance_valid(_target_node):
		return
	if not (_target_node is Control):
		return

	# Accumulate time for oscillation (independent of progress)
	_shake_time += get_process_delta_time()

	# Calculate decay multiplier (1.0 → 0.0 over duration if decay enabled)
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
	if not is_instance_valid(_target_node) or not (_target_node is Control):
		return

	var ctrl := _target_node as Control
	match transform_target:
		TransformTarget.POSITION:
			ctrl.position = _base_position
		TransformTarget.ROTATION:
			ctrl.rotation = _base_rotation
		TransformTarget.SCALE:
			ctrl.scale = _base_scale

	if debug_enabled:
		print("[%s] Shake complete, returned to base" % name)


func _restore_to_natural() -> void:
	if not is_instance_valid(_target_node) or not (_target_node is Control):
		return
	if not _has_base:
		return
	var ctrl := _target_node as Control
	match transform_target:
		TransformTarget.POSITION:
			ctrl.position = _base_position
		TransformTarget.ROTATION:
			ctrl.rotation = _base_rotation
		TransformTarget.SCALE:
			ctrl.scale = _base_scale


func _invalidate_base_cache() -> void:
	_has_base = false
	_pivot_resolved = false
	_disconnect_resized()
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

	(_target_node as Control).position = _base_position + offset

# =============================================================================
# ROTATION SHAKE
# =============================================================================

func _apply_rotation_shake(intensity: float) -> void:
	var sine_value := sin(_shake_time * shake_frequency * TAU)

	# Detect zero-crossings for direction randomization
	if rotation_randomize_direction:
		var current_sign := signf(sine_value)
		if current_sign != _last_sine_sign and current_sign != 0.0:
			if randf() > 0.5:
				_direction_multiplier *= -1.0
			_last_sine_sign = current_sign

	var current_amplitude := rotation_amplitude
	if decay:
		# Decay is already factored into intensity, but rotation uses its own
		# amplitude variable directly — apply intensity as the decay envelope
		current_amplitude *= intensity

	var shake_offset := sine_value * current_amplitude * _direction_multiplier
	(_target_node as Control).rotation = _base_rotation + deg_to_rad(shake_offset)

# =============================================================================
# SCALE SHAKE
# =============================================================================

func _apply_scale_shake(intensity: float) -> void:
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

	(_target_node as Control).scale = _base_scale + offset

# =============================================================================
# BASE CAPTURE
# =============================================================================

func _capture_base() -> void:
	if _has_base:
		return

	if _target_node is Control:
		var ctrl := _target_node as Control
		_base_position = ctrl.position
		_base_rotation = ctrl.rotation
		_base_scale = ctrl.scale
	else:
		_base_position = Vector2.ZERO
		_base_rotation = 0.0
		_base_scale = Vector2.ONE
		if debug_enabled and _target_node != null:
			push_warning("[%s] Target '%s' is not Control" % [name, str(_target_node.name)])

	_has_base = true

	if debug_enabled:
		print("[%s] Captured base — pos: %s, rot: %.1f°, scale: %s" % [
			name, _base_position, rad_to_deg(_base_rotation), _base_scale
		])

# =============================================================================
# PIVOT HANDLING — Uses native Control.pivot_offset
# =============================================================================

func _resolve_pivot() -> void:
	if not (_target_node is Control):
		return

	_apply_pivot_mode()
	_pivot_resolved = true

	# Connect to resized signal for reactive pivot updates
	var ctrl := _target_node as Control
	if _connected_control != ctrl:
		_disconnect_resized()
		if not ctrl.resized.is_connected(_on_target_resized):
			ctrl.resized.connect(_on_target_resized)
		_connected_control = ctrl


func _apply_pivot_mode() -> void:
	if not (_target_node is Control):
		return

	var ctrl := _target_node as Control

	match pivot_mode:
		PivotMode.AUTO_CENTER:
			ctrl.pivot_offset = ctrl.size / 2.0
		PivotMode.INHERIT:
			return
		PivotMode.CUSTOM:
			ctrl.pivot_offset = Vector2(
				ctrl.size.x * custom_pivot.x,
				ctrl.size.y * custom_pivot.y
			)

	if debug_enabled:
		print("[%s] Pivot set to %s" % [name, ctrl.pivot_offset])


func _on_target_resized() -> void:
	_apply_pivot_mode()


func _disconnect_resized() -> void:
	if _connected_control != null and is_instance_valid(_connected_control):
		if _connected_control.resized.is_connected(_on_target_resized):
			_connected_control.resized.disconnect(_on_target_resized)
	_connected_control = null

# =============================================================================
# SEQUENCER RECIPE CONTRACT
# =============================================================================

func _recipe_capture_natural(target: Node) -> Variant:
	if target is Control:
		var ctrl := target as Control
		match transform_target:
			TransformTarget.POSITION:
				return {"position": ctrl.position}
			TransformTarget.ROTATION:
				return {"rotation": ctrl.rotation}
			TransformTarget.SCALE:
				return {"scale": ctrl.scale}
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
	if not (natural is Dictionary) or not (target is Control):
		return
	var dict := natural as Dictionary
	var ctrl := target as Control

	match transform_target:
		TransformTarget.POSITION:
			ctrl.position = dict.get("position", Vector2.ZERO) as Vector2
		TransformTarget.ROTATION:
			ctrl.rotation = dict.get("rotation", 0.0) as float
		TransformTarget.SCALE:
			ctrl.scale = dict.get("scale", Vector2.ONE) as Vector2

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent := get_parent()
	if parent and not parent is Control:
		warnings.append("Parent must be a Control node. Use Shake2D/Shake3D for other domains. (ignore if comp is a child of a sequencer)")
	return warnings
