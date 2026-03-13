## Noise3DJuiceComp.gd
## ============================================================================
## WHAT: Consolidated noise effect for Node3D nodes. Combines position, rotation,
##       and scale noise into a single component with a TransformTarget selector.
##       Uses _validate_property() to conditionally show only relevant exports.
## WHY: Replaces 3 separate scripts (PositionNoise3D, RotationNoise3D,
##      ScaleNoise3D) with one unified component, reducing file count and
##      ensuring consistent behavior across transform types.
## SYSTEM: Juicing System (addons/juice/) - 3D Domain
## DOES NOT: Handle Control or Node2D targets (use NoiseControl/Noise2D).
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
## - POSITION: Displaces Node3D.position with per-axis Vector3 amplitude
## - ROTATION: Rotates Node3D.rotation with per-axis Vector3 amplitude (degrees)
##             + position compensation for custom pivot points
## - SCALE: Scales Node3D.scale with per-axis Vector3 amplitude + uniform option
##          + position compensation for custom pivot points
##
## PIVOT (ROTATION and SCALE only):
## Node3D has no native pivot, so AUTO_CENTER and CUSTOM use position
## compensation to simulate rotation/scale around an arbitrary point.
##
## CONDITIONAL EXPORTS:
## All conditional properties are @export with _validate_property() for visibility.
## Changing transform_target, fractal_type, domain_warp_enabled, scale_uniform,
## or pivot_mode triggers conditional show/hide.
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBase3D.svg")
class_name Noise3DJuiceComp
extends JuiceCompBase

# =============================================================================
# ENUMS
# =============================================================================

## Which transform property to drive with noise
enum TransformTarget {
	POSITION,  ## Displace Node3D.position (XYZ)
	ROTATION,  ## Rotate Node3D.rotation (XYZ Euler degrees)
	SCALE      ## Scale Node3D.scale (XYZ)
}

## Controls the direction of noise displacement
enum NoiseDirection {
	BOTH,           ## Full range: positive and negative displacement (-1 to 1)
	POSITIVE_ONLY,  ## One-directional: only positive displacement (0 to 1)
	NEGATIVE_ONLY   ## One-directional: only negative displacement (-1 to 0)
}

## Determines how the pivot point is calculated for rotation/scale.
## Node3D has no native pivot, so AUTO_CENTER and CUSTOM use position
## compensation to simulate the pivot.
enum PivotMode {
	AUTO_CENTER,  ## Rotates/scales around node's origin (typical for centered 3D meshes)
	INHERIT,      ## Same as AUTO_CENTER for 3D (pivot is always the origin)
	CUSTOM        ## Use custom_pivot_offset below
}

# =============================================================================
# EFFECT CONFIGURATION
# =============================================================================

@export_group("Effect")

## Which transform property to drive with noise.
## Changing this shows/hides the relevant amplitude, axis speed, and pivot settings.
@export var transform_target: TransformTarget = TransformTarget.POSITION:
	set(value):
		transform_target = value
		notify_property_list_changed()

## Maximum displacement per axis in world units.
## Hidden when transform_target != POSITION.
@export var position_amplitude: Vector3 = Vector3(0.5, 0.5, 0.5)

## Maximum rotation amplitude per axis in degrees.
## Hidden when transform_target != ROTATION.
@export var rotation_amplitude: Vector3 = Vector3(0.0, 5.0, 0.0)

## Maximum scale deviation per axis (added to base scale).
## Hidden when transform_target != SCALE.
@export var scale_amplitude: Vector3 = Vector3(0.1, 0.1, 0.1)

## How fast the noise evolves — higher = faster motion.
## This is temporal speed (how fast you move through the noise field).
## See also noise_frequency which controls spatial scale of the pattern.
@export var noise_speed: float = 1.0

## Controls the direction of noise displacement.
## BOTH: Full range positive and negative. POSITIVE_ONLY / NEGATIVE_ONLY: one-directional.
@export var noise_direction: NoiseDirection = NoiseDirection.BOTH

## Use the same noise value for all axes — preserves proportions during scale noise.
## Hidden when transform_target != SCALE.
@export var scale_uniform: bool = true:
	set(value):
		scale_uniform = value
		notify_property_list_changed()

## How the pivot point is determined for rotation/scale transforms.
## Hidden when transform_target == POSITION (pivot is irrelevant for position noise).
@export var pivot_mode: PivotMode = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()

## Custom pivot offset in local space.
## Hidden when transform_target == POSITION or pivot_mode != CUSTOM.
@export var custom_pivot_offset: Vector3 = Vector3.ZERO

# =============================================================================
# NOISE PATTERN
# =============================================================================

@export_group("Noise Pattern")

## Which noise algorithm to use — each produces distinctly different motion character.
## Simplex Smooth: Flowing, organic. Cellular: Quantized jumps. Value: Subtle jitter.
@export var noise_type: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

## Spatial scale of the noise pattern — affects motion character.
## Lower = smoother, broader curves. Higher = tighter, choppier motion.
## This is different from noise_speed which controls temporal rate.
@export var noise_frequency: float = 1.0

## Seed for reproducible noise. 0 = random seed at runtime.
@export var noise_seed: int = 0

@export_subgroup("Fractal")

## Fractal layering mode — adds detail at multiple scales.
## None: Single noise layer. FBM: Rich organic detail.
## Ridged: Sharp direction changes. Ping Pong: Bouncy oscillation.
@export var fractal_type: FastNoiseLite.FractalType = FastNoiseLite.FRACTAL_NONE:
	set(value):
		fractal_type = value
		notify_property_list_changed()

## Number of fractal layers of detail. More = richer but costlier.
## Hidden when fractal_type == NONE.
@export_range(1, 6) var fractal_octaves: int = 1

## How much the frequency increases per octave. Higher = more fine detail per layer.
## Hidden when fractal_type == NONE.
@export var lacunarity: float = 2.0

## How much each octave contributes to the result. Lower = subtler higher octaves.
## Hidden when fractal_type == NONE.
@export var fractal_gain: float = 0.5

@export_subgroup("Domain Warp")

## Warp the noise input coordinates with another noise layer for swirling, flowing motion.
@export var domain_warp_enabled: bool = false:
	set(value):
		domain_warp_enabled = value
		notify_property_list_changed()

## Strength of domain warp displacement.
## Hidden when domain_warp_enabled == false.
@export var domain_warp_amplitude: float = 30.0

## Frequency of the domain warp noise.
## Hidden when domain_warp_enabled == false.
@export var domain_warp_frequency: float = 0.5

# =============================================================================
# ADVANCED
# =============================================================================

@export_group("Advanced")

## Per-axis speed relative to Noise Speed for position noise.
## (1,1,1) = uniform speed. (2, 0.5, 1) = X twice as fast, Y half, Z normal.
## Hidden when transform_target != POSITION.
@export var position_axis_speed: Vector3 = Vector3(1.0, 1.0, 1.0)

## Per-axis speed relative to Noise Speed for rotation noise.
## (1,1,1) = uniform speed. Controls pitch/yaw/roll speed independently.
## Hidden when transform_target != ROTATION.
@export var rotation_axis_speed: Vector3 = Vector3(1.0, 1.0, 1.0)

## Per-axis speed relative to Noise Speed for scale noise.
## Hidden when transform_target != SCALE or when scale_uniform == true.
@export var scale_axis_speed: Vector3 = Vector3(1.0, 1.0, 1.0)

## Minimum noise output value (applied after direction, before amplitude).
@export var clamp_min: float = -1.0

## Maximum noise output value (applied after direction, before amplitude).
@export var clamp_max: float = 1.0

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _noise: FastNoiseLite
var _noise_time: float = 0.0

## Current amplitude envelope value from the base class animation loop.
## Stored by _apply_effect(), read by _physics_process() to scale noise output.
var _current_intensity: float = 0.0

var _base_position: Vector3 = Vector3.ZERO
var _base_rotation: Vector3 = Vector3.ZERO
var _base_scale: Vector3 = Vector3.ONE
var _has_base: bool = false

## Resolved pivot point in local space
var _pivot_offset: Vector3 = Vector3.ZERO

# =============================================================================
# CONDITIONAL PROPERTY VISIBILITY
# =============================================================================

func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)

	var is_position := transform_target == TransformTarget.POSITION
	var is_rotation := transform_target == TransformTarget.ROTATION
	var is_scale := transform_target == TransformTarget.SCALE

	# Effect group: show only relevant amplitude/settings per transform target
	if property.name == "position_amplitude" and not is_position:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "rotation_amplitude" and not is_rotation:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "scale_amplitude" and not is_scale:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "scale_uniform" and not is_scale:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "pivot_mode" and is_position:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "custom_pivot_offset" and (is_position or pivot_mode != PivotMode.CUSTOM):
		property.usage = PROPERTY_USAGE_NO_EDITOR

	# Fractal: hide detail settings when no fractal layering
	if property.name in ["fractal_octaves", "lacunarity", "fractal_gain"] and fractal_type == FastNoiseLite.FRACTAL_NONE:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	# Domain warp: hide settings when warp is disabled
	if property.name in ["domain_warp_amplitude", "domain_warp_frequency"] and not domain_warp_enabled:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	# Advanced: show only relevant axis speed per transform target
	if property.name == "position_axis_speed" and not is_position:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "rotation_axis_speed" and not is_rotation:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "scale_axis_speed" and (not is_scale or scale_uniform):
		property.usage = PROPERTY_USAGE_NO_EDITOR

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
		print("[%s] Noise 3D start (%s). Speed: %.2f" % [name, target_name, noise_speed])


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

	if not is_instance_valid(_target_node) or not _target_node is Node3D:
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
	if not is_instance_valid(_target_node) or not _target_node is Node3D:
		return

	# Stop independent noise processing
	_current_intensity = 0.0
	set_physics_process(false)

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

	_has_base = false


func _invalidate_base_cache() -> void:
	_has_base = false

# =============================================================================
# SEQUENCER RECIPE CONTRACT
# =============================================================================

func _recipe_capture_natural(target: Node) -> Variant:
	if not target is Node3D:
		return null
	var n3d := target as Node3D
	match transform_target:
		TransformTarget.POSITION:
			return n3d.position
		TransformTarget.ROTATION:
			return {"rotation": n3d.rotation, "position": n3d.position}
		TransformTarget.SCALE:
			return {"scale": n3d.scale, "position": n3d.position}
	return null


func _recipe_apply_natural(target: Node, natural: Variant) -> void:
	if not target is Node3D:
		return
	var n3d := target as Node3D
	match transform_target:
		TransformTarget.POSITION:
			if natural is Vector3:
				n3d.position = natural
		TransformTarget.ROTATION:
			if natural is Dictionary:
				n3d.rotation = natural.get("rotation", Vector3.ZERO)
				n3d.position = natural.get("position", Vector3.ZERO)
		TransformTarget.SCALE:
			if natural is Dictionary:
				n3d.scale = natural.get("scale", Vector3.ONE)
				n3d.position = natural.get("position", Vector3.ZERO)


func _recipe_restore_natural(target: Node, natural: Variant) -> void:
	_recipe_apply_natural(target, natural)

# =============================================================================
# POSITION NOISE
# =============================================================================

func _apply_position_noise(intensity: float) -> void:
	var n3d := _target_node as Node3D

	var sample_x := _sample_noise(0.0, position_axis_speed.x)
	var sample_y := _sample_noise(100.0, position_axis_speed.y)
	var sample_z := _sample_noise(200.0, position_axis_speed.z)

	var offset := Vector3(
		position_amplitude.x * sample_x * intensity,
		position_amplitude.y * sample_y * intensity,
		position_amplitude.z * sample_z * intensity
	)

	n3d.position = _base_position + offset

# =============================================================================
# ROTATION NOISE (per-axis with position compensation for pivot)
# =============================================================================

func _apply_rotation_noise(intensity: float) -> void:
	var n3d := _target_node as Node3D

	var sample_x := _sample_noise(0.0, rotation_axis_speed.x)
	var sample_y := _sample_noise(100.0, rotation_axis_speed.y)
	var sample_z := _sample_noise(200.0, rotation_axis_speed.z)

	var rotation_offset := Vector3(
		deg_to_rad(rotation_amplitude.x * sample_x * intensity),
		deg_to_rad(rotation_amplitude.y * sample_y * intensity),
		deg_to_rad(rotation_amplitude.z * sample_z * intensity)
	)

	n3d.rotation = _base_rotation + rotation_offset

	# Position compensation for custom pivot: rotate the pivot offset and adjust position
	if _pivot_offset != Vector3.ZERO:
		var base_basis := Basis.from_euler(_base_rotation)
		var new_basis := Basis.from_euler(_base_rotation + rotation_offset)
		var original_pivot := base_basis * _pivot_offset
		var rotated_pivot := new_basis * _pivot_offset
		n3d.position = _base_position + (original_pivot - rotated_pivot)

# =============================================================================
# SCALE NOISE (with position compensation for pivot)
# =============================================================================

func _apply_scale_noise(intensity: float) -> void:
	var n3d := _target_node as Node3D

	var sample_x: float
	var sample_y: float
	var sample_z: float

	if scale_uniform:
		var sample := _sample_noise(0.0, 1.0)
		sample_x = sample
		sample_y = sample
		sample_z = sample
	else:
		sample_x = _sample_noise(0.0, scale_axis_speed.x)
		sample_y = _sample_noise(100.0, scale_axis_speed.y)
		sample_z = _sample_noise(200.0, scale_axis_speed.z)

	var scale_offset := Vector3(
		scale_amplitude.x * sample_x * intensity,
		scale_amplitude.y * sample_y * intensity,
		scale_amplitude.z * sample_z * intensity
	)

	var new_scale := _base_scale + scale_offset
	n3d.scale = new_scale

	# Position compensation for custom pivot
	if _pivot_offset != Vector3.ZERO:
		var scale_ratio := new_scale / _base_scale
		var compensated_pivot := Vector3(
			_pivot_offset.x * scale_ratio.x,
			_pivot_offset.y * scale_ratio.y,
			_pivot_offset.z * scale_ratio.z
		)
		n3d.position = _base_position + (_pivot_offset - compensated_pivot)

# =============================================================================
# PIVOT HELPERS
# =============================================================================

func _compute_pivot_offset() -> void:
	match pivot_mode:
		PivotMode.AUTO_CENTER:
			_pivot_offset = Vector3.ZERO
		PivotMode.INHERIT:
			_pivot_offset = Vector3.ZERO
		PivotMode.CUSTOM:
			_pivot_offset = custom_pivot_offset

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
	_noise.fractal_octaves = fractal_octaves
	_noise.fractal_lacunarity = lacunarity
	_noise.fractal_gain = fractal_gain

	if domain_warp_enabled:
		_noise.domain_warp_enabled = true
		_noise.domain_warp_amplitude = domain_warp_amplitude
		_noise.domain_warp_frequency = domain_warp_frequency
	else:
		_noise.domain_warp_enabled = false


## Sample noise at the current time with per-axis Y-offset for decorrelated motion
func _sample_noise(y_offset: float, axis_speed: float) -> float:
	var t := _noise_time * noise_speed * axis_speed
	var raw := _noise.get_noise_2d(t, y_offset)

	match noise_direction:
		NoiseDirection.POSITIVE_ONLY:
			raw = absf(raw)
		NoiseDirection.NEGATIVE_ONLY:
			raw = -absf(raw)

	raw = clampf(raw, clamp_min, clamp_max)
	return raw


func _capture_base_values() -> void:
	if _has_base:
		return
	if not is_instance_valid(_target_node) or not _target_node is Node3D:
		return
	var n3d := _target_node as Node3D
	_base_position = n3d.position
	_base_rotation = n3d.rotation
	_base_scale = n3d.scale
	_has_base = true

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent := get_parent()
	if parent and not parent is Node3D:
		warnings.append("Parent must be a Node3D node. Use NoiseControl/Noise2D for other domains. (ignore if comp is a child of a sequencer)")
	return warnings
