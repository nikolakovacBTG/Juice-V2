## Noise2DJuiceComp.gd
## ============================================================================
## WHAT: Consolidated noise effect for Node2D nodes. Combines position, rotation,
##       and scale noise into a single component with a TransformTarget selector.
##       Uses _get_property_list() to conditionally show only relevant exports.
## WHY: Replaces 3 separate scripts (PositionNoise2D, RotationNoise2D,
##      ScaleNoise2D) with one unified component, reducing file count and
##      ensuring consistent behavior across transform types.
## SYSTEM: Juicing System (addons/juice/) - 2D Domain
## DOES NOT: Handle Control or Node3D targets (use NoiseControl/Noise3D).
## DOES NOT: Handle arbitrary property noise (use NoisePropertyJuiceComp).
## ============================================================================
##
## KEY CONCEPT:
## Noise is CONTINUOUS. The base class animation loop provides a 0→1→0
## amplitude envelope via _apply_effect(progress). This comp runs its own
## _physics_process() to evolve the noise pattern independently — it reads
## the envelope as intensity but never writes base class state variables.
## Animate_out smoothly fades the offset to zero by freezing the noise
## sample and scaling intensity down.
##
## TRANSFORM TARGETS:
## - POSITION: Displaces Node2D.position with per-axis Vector2 amplitude
## - ROTATION: Rotates Node2D.rotation with float amplitude (degrees)
##             + position compensation for pivot (Node2D has no native pivot)
## - SCALE: Scales Node2D.scale with per-axis Vector2 amplitude + uniform option
##          + position compensation for pivot (Node2D has no native pivot)
##
## PIVOT (ROTATION and SCALE only):
## Node2D has no native pivot property. AUTO_CENTER estimates the visual center
## by finding a child Sprite2D. CUSTOM uses a pixel offset. Position compensation
## is applied to simulate rotation/scale around the pivot point.
##
## CONDITIONAL EXPORTS:
## Changing transform_target triggers notify_property_list_changed() which
## shows/hides the relevant parameters via _get_property_list().
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBase2D.svg")
class_name Noise2DJuiceComp
extends JuiceCompBase

# =============================================================================
# TRANSFORM TARGET SELECTION
# =============================================================================

## Which transform property to drive with noise
enum TransformTarget {
	POSITION,  ## Displace Node2D.position (XY)
	ROTATION,  ## Rotate Node2D.rotation (Z-axis degrees)
	SCALE      ## Scale Node2D.scale (XY)
}

@export var transform_target: TransformTarget = TransformTarget.POSITION:
	set(value):
		transform_target = value
		notify_property_list_changed()

# =============================================================================
# NOISE DESIGN (always visible)
# =============================================================================

@export_group("Noise Design")

## Which noise algorithm to use — each produces distinctly different motion character
## Simplex Smooth: Flowing, organic. Cellular: Quantized jumps. Value: Subtle jitter.
@export var noise_type: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

## Controls the spatial scale of the noise pattern
## Lower values = smoother, broader curves. Higher values = tighter, choppier motion.
@export var noise_frequency: float = 1.0

## Seed for reproducible noise. 0 = random seed at runtime.
@export var noise_seed: int = 0

@export_subgroup("Advanced Noise")

## Fractal layering mode — adds detail at multiple scales
## FBM: Rich organic detail. Ridged: Sharp direction changes. Ping Pong: Bouncy oscillation.
@export var fractal_type: FastNoiseLite.FractalType = FastNoiseLite.FRACTAL_NONE

## Number of fractal octaves (layers of detail). More = richer but costlier.
@export_range(1, 6) var octaves: int = 1

## Frequency multiplier per octave. Higher = more high-frequency detail per layer.
@export var lacunarity: float = 2.0

## Amplitude multiplier per octave. Lower = less influence from higher octaves.
@export var gain: float = 0.5

## Warp the noise input coordinates with another noise layer for swirling, flowing motion
@export var domain_warp_enabled: bool = false

## Strength of domain warp displacement
@export var domain_warp_amplitude: float = 30.0

## Frequency of the domain warp noise
@export var domain_warp_frequency: float = 0.5

# =============================================================================
# SHARED MOTION (always visible)
# =============================================================================

@export_group("Motion")

## How fast we traverse the noise field — higher = faster motion
@export var speed: float = 1.0

@export_subgroup("Advanced Motion")

## When enabled, noise output is [0, 1] instead of [-1, 1]
## Creates one-directional displacement (only positive offset)
@export var absolute_mode: bool = false

## Invert noise output — flips displacement direction
@export var invert_output: bool = false

## Clamp noise output minimum (applied after absolute/invert, before amplitude)
@export var output_min: float = -1.0

## Clamp noise output maximum (applied after absolute/invert, before amplitude)
@export var output_max: float = 1.0

# =============================================================================
# PIVOT MODE (shown for ROTATION and SCALE only, via _get_property_list)
# =============================================================================

## How the pivot point is determined for Node2D nodes.
## AUTO_CENTER: Estimates visual center from child Sprite2D bounds.
## INHERIT: Rotates/scales around node's origin (default Node2D behavior).
## CUSTOM: Uses custom_pivot_offset in local pixels.
enum PivotMode {
	AUTO_CENTER,
	INHERIT,
	CUSTOM
}

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — they are shown/hidden via _get_property_list()
# =============================================================================

# --- POSITION ---
## Maximum displacement per axis in pixels
var position_amplitude: Vector2 = Vector2(5.0, 5.0)
## Per-axis speed multiplier — e.g., fast horizontal jitter + slow vertical drift
var position_speed_scale: Vector2 = Vector2(1.0, 1.0)

# --- ROTATION ---
## Maximum rotation amplitude in degrees
var rotation_amplitude: float = 5.0

# --- SCALE ---
## Maximum scale deviation per axis (added to base scale)
var scale_amplitude: Vector2 = Vector2(0.1, 0.1)
## Per-axis speed multiplier
var scale_speed_scale: Vector2 = Vector2(1.0, 1.0)
## Sample the same noise value for all axes — preserves aspect ratio
var scale_uniform: bool = true

# --- PIVOT (ROTATION + SCALE) ---
var pivot_mode: int = PivotMode.AUTO_CENTER
var custom_pivot_offset: Vector2 = Vector2.ZERO

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _noise: FastNoiseLite
var _noise_time: float = 0.0

## Current amplitude envelope value from the base class animation loop.
## Stored by _apply_effect(), read by _physics_process() to scale noise output.
var _current_intensity: float = 0.0

var _base_position: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _has_base: bool = false

## Resolved pivot point in local space
var _pivot_offset: Vector2 = Vector2.ZERO

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	match transform_target:
		TransformTarget.POSITION:
			props.append({
				"name": "position_amplitude",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
			props.append({
				"name": "position_speed_scale",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT,
			})

		TransformTarget.ROTATION:
			props.append({
				"name": "rotation_amplitude",
				"type": TYPE_FLOAT,
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
				"name": "scale_speed_scale",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT,
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
			"name": "custom_pivot_offset",
			"type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
		},
	]


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"position_amplitude": position_amplitude = value; return true
		&"position_speed_scale": position_speed_scale = value; return true
		&"rotation_amplitude": rotation_amplitude = value; return true
		&"scale_amplitude": scale_amplitude = value; return true
		&"scale_speed_scale": scale_speed_scale = value; return true
		&"scale_uniform": scale_uniform = value; return true
		&"pivot_mode": pivot_mode = value; return true
		&"custom_pivot_offset": custom_pivot_offset = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"position_amplitude": return position_amplitude
		&"position_speed_scale": return position_speed_scale
		&"rotation_amplitude": return rotation_amplitude
		&"scale_amplitude": return scale_amplitude
		&"scale_speed_scale": return scale_speed_scale
		&"scale_uniform": return scale_uniform
		&"pivot_mode": return pivot_mode
		&"custom_pivot_offset": return custom_pivot_offset
	return null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()
	# Noise evolution runs in _physics_process, independent of the base class
	# animation loop. Disabled until an animation starts.
	set_physics_process(false)

# =============================================================================
# ANIMATION HOOKS
# =============================================================================

func _on_animate_start() -> void:
	_capture_base_values()
	# Only reset noise when animating IN — during fade-out, freeze the current noise state
	# so the offset smoothly returns to base instead of jumping to a new random value
	if _target_progress > 0.0:
		_noise_time = 0.0
		_setup_noise()

	if transform_target != TransformTarget.POSITION:
		_compute_pivot_offset()

	# Enable independent noise processing — runs alongside the base class
	# envelope animation during fade-in/out, and continues solo during sustain.
	set_physics_process(true)

	if debug_enabled:
		var target_name: String = TransformTarget.keys()[transform_target]
		print("[%s] Noise 2D start (%s). Speed: %.2f" % [name, target_name, speed])


func _apply_effect(progress: float) -> void:
	# Store the base class envelope value for _physics_process() to read.
	# The actual noise application happens in _physics_process() — this keeps
	# noise evolution independent from the base class animation loop.
	_current_intensity = progress


## Independent noise processing — runs at physics rate, decoupled from the
## base class animation loop. Reads _current_intensity (set by _apply_effect)
## as the amplitude envelope, and evolves noise time continuously.
func _physics_process(delta: float) -> void:
	if _current_intensity <= 0.0:
		return

	if not is_instance_valid(_target_node) or not _target_node is Node2D:
		return

	# Don't advance noise time during fade-out — freeze the noise sample
	# so intensity smoothly scales the current offset down to zero
	if _target_progress > 0.0:
		_noise_time += delta

	match transform_target:
		TransformTarget.POSITION:
			_apply_position_noise(_current_intensity)
		TransformTarget.ROTATION:
			_apply_rotation_noise(_current_intensity)
		TransformTarget.SCALE:
			_apply_scale_noise(_current_intensity)


func _on_animate_out_complete() -> void:
	if not is_instance_valid(_target_node) or not _target_node is Node2D:
		return

	# Stop independent noise processing
	_current_intensity = 0.0
	set_physics_process(false)

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

	_has_base = false


func _invalidate_base_cache() -> void:
	_has_base = false

# =============================================================================
# SEQUENCER RECIPE CONTRACT
# =============================================================================

func _recipe_capture_natural(target: Node) -> Variant:
	if not target is Node2D:
		return null
	var n2d := target as Node2D
	match transform_target:
		TransformTarget.POSITION:
			return n2d.position
		TransformTarget.ROTATION:
			return {"rotation": n2d.rotation, "position": n2d.position}
		TransformTarget.SCALE:
			return {"scale": n2d.scale, "position": n2d.position}
	return null


func _recipe_apply_natural(target: Node, natural: Variant) -> void:
	if not target is Node2D:
		return
	var n2d := target as Node2D
	match transform_target:
		TransformTarget.POSITION:
			if natural is Vector2:
				n2d.position = natural
		TransformTarget.ROTATION:
			if natural is Dictionary:
				n2d.rotation = natural.get("rotation", 0.0)
				n2d.position = natural.get("position", Vector2.ZERO)
		TransformTarget.SCALE:
			if natural is Dictionary:
				n2d.scale = natural.get("scale", Vector2.ONE)
				n2d.position = natural.get("position", Vector2.ZERO)


func _recipe_restore_natural(target: Node, natural: Variant) -> void:
	_recipe_apply_natural(target, natural)

# =============================================================================
# POSITION NOISE
# =============================================================================

func _apply_position_noise(intensity: float) -> void:
	var n2d := _target_node as Node2D

	var sample_x := _sample_noise(0.0, position_speed_scale.x)
	var sample_y := _sample_noise(100.0, position_speed_scale.y)

	var offset := Vector2(
		position_amplitude.x * sample_x * intensity,
		position_amplitude.y * sample_y * intensity
	)

	n2d.position = _base_position + offset

# =============================================================================
# ROTATION NOISE (single Z-axis with position compensation for pivot)
# =============================================================================

func _apply_rotation_noise(intensity: float) -> void:
	var n2d := _target_node as Node2D

	var sample := _sample_noise(0.0, 1.0)
	var angle_offset := deg_to_rad(rotation_amplitude * sample * intensity)

	n2d.rotation = _base_rotation + angle_offset

	# Position compensation: rotate the pivot offset vector and adjust position
	# so the node appears to rotate around the pivot point rather than its origin
	if _pivot_offset != Vector2.ZERO:
		var rotated_pivot := _pivot_offset.rotated(_base_rotation + angle_offset)
		var original_pivot := _pivot_offset.rotated(_base_rotation)
		n2d.position = _base_position + (original_pivot - rotated_pivot)

# =============================================================================
# SCALE NOISE (with position compensation for pivot)
# =============================================================================

func _apply_scale_noise(intensity: float) -> void:
	var n2d := _target_node as Node2D

	var sample_x: float
	var sample_y: float

	if scale_uniform:
		var sample := _sample_noise(0.0, 1.0)
		sample_x = sample
		sample_y = sample
	else:
		sample_x = _sample_noise(0.0, scale_speed_scale.x)
		sample_y = _sample_noise(100.0, scale_speed_scale.y)

	var scale_offset := Vector2(
		scale_amplitude.x * sample_x * intensity,
		scale_amplitude.y * sample_y * intensity
	)

	var new_scale := _base_scale + scale_offset
	n2d.scale = new_scale

	# Position compensation: when scaling around a pivot that isn't the origin,
	# adjust position so the visual center stays in place
	if _pivot_offset != Vector2.ZERO:
		var scale_ratio := new_scale / _base_scale
		var compensated_pivot := _pivot_offset * scale_ratio
		n2d.position = _base_position + (_pivot_offset - compensated_pivot)

# =============================================================================
# PIVOT HELPERS
# =============================================================================

func _compute_pivot_offset() -> void:
	match pivot_mode:
		PivotMode.INHERIT:
			_pivot_offset = Vector2.ZERO
		PivotMode.CUSTOM:
			_pivot_offset = custom_pivot_offset
		PivotMode.AUTO_CENTER:
			_pivot_offset = _estimate_visual_center()


## Estimate the visual center by looking for a Sprite2D child with a texture
func _estimate_visual_center() -> Vector2:
	if not is_instance_valid(_target_node):
		return Vector2.ZERO
	for child in _target_node.get_children():
		if child is Sprite2D and (child as Sprite2D).texture != null:
			var spr := child as Sprite2D
			var tex_size := spr.texture.get_size()
			if spr.centered:
				return spr.position
			else:
				return spr.position + tex_size / 2.0
	return Vector2.ZERO

# =============================================================================
# NOISE HELPERS
# =============================================================================

func _setup_noise() -> void:
	if _noise == null:
		_noise = FastNoiseLite.new()

	_noise.noise_type = noise_type
	_noise.frequency = noise_frequency
	_noise.seed = noise_seed if noise_seed != 0 else randi()

	_noise.fractal_type = fractal_type
	_noise.fractal_octaves = octaves
	_noise.fractal_lacunarity = lacunarity
	_noise.fractal_gain = gain

	if domain_warp_enabled:
		_noise.domain_warp_enabled = true
		_noise.domain_warp_amplitude = domain_warp_amplitude
		_noise.domain_warp_frequency = domain_warp_frequency
	else:
		_noise.domain_warp_enabled = false


## Sample noise at the current time with per-axis Y-offset for decorrelated motion
func _sample_noise(y_offset: float, axis_speed: float) -> float:
	var t := _noise_time * speed * axis_speed
	var raw := _noise.get_noise_2d(t, y_offset)

	if absolute_mode:
		raw = absf(raw)
	if invert_output:
		raw = -raw

	raw = clampf(raw, output_min, output_max)
	return raw


func _capture_base_values() -> void:
	if _has_base:
		return
	if not is_instance_valid(_target_node) or not _target_node is Node2D:
		return
	var n2d := _target_node as Node2D
	_base_position = n2d.position
	_base_rotation = n2d.rotation
	_base_scale = n2d.scale
	_has_base = true

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent := get_parent()
	if parent and not parent is Node2D:
		warnings.append("Parent must be a Node2D node. Use NoiseControl/Noise3D for other domains.")
	return warnings
