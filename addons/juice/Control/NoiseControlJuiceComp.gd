## NoiseControlJuiceComp.gd
## ============================================================================
## WHAT: Consolidated noise effect for Control nodes. Combines position, rotation,
##       and scale noise into a single component with a TransformTarget selector.
##       Uses _get_property_list() to conditionally show only relevant exports.
## WHY: Replaces 3 separate scripts (PositionNoiseControl, RotationNoiseControl,
##      ScaleNoiseControl) with one unified component, reducing file count and
##      ensuring consistent behavior across transform types.
## SYSTEM: Juicing System (addons/juice/) - Control Domain
## DOES NOT: Handle Node2D or Node3D targets (use Noise2D/Noise3D).
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
## - POSITION: Displaces Control.position with per-axis Vector2 amplitude (pixels)
## - ROTATION: Rotates Control.rotation with float amplitude (degrees)
##             Uses native Control.pivot_offset with reactive resize updates
## - SCALE: Scales Control.scale with per-axis Vector2 amplitude + uniform option
##          Uses native Control.pivot_offset with reactive resize updates
##
## PIVOT (ROTATION and SCALE only):
## Control nodes have a native pivot_offset property. AUTO_CENTER sets it to the
## center of the control and updates reactively on resize. CUSTOM uses a fraction
## of the control's size. INHERIT leaves whatever pivot_offset is already set.
##
## CONDITIONAL EXPORTS:
## Changing transform_target triggers notify_property_list_changed() which
## shows/hides the relevant parameters via _get_property_list().
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBaseControl.svg")
class_name NoiseControlJuiceComp
extends JuiceCompBase

# =============================================================================
# TRANSFORM TARGET SELECTION
# =============================================================================

## Which transform property to drive with noise
enum TransformTarget {
	POSITION,  ## Displace Control.position (XY pixels)
	ROTATION,  ## Rotate Control.rotation (Z-axis degrees)
	SCALE      ## Scale Control.scale (XY)
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

## How the pivot point is determined for Control nodes.
## AUTO_CENTER: Automatically centers pivot on the control (updates on resize).
## INHERIT: Uses whatever pivot_offset the Control already has.
## CUSTOM: Uses the custom_pivot fraction (0.5, 0.5 = center).
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
var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()
## Custom pivot as a fraction of the control's size (only used when pivot_mode = CUSTOM)
var custom_pivot: Vector2 = Vector2(0.5, 0.5)

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

## Whether pivot has been applied for the current animation cycle
var _pivot_applied: bool = false

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
		&"position_amplitude": position_amplitude = value; return true
		&"position_speed_scale": position_speed_scale = value; return true
		&"rotation_amplitude": rotation_amplitude = value; return true
		&"scale_amplitude": scale_amplitude = value; return true
		&"scale_speed_scale": scale_speed_scale = value; return true
		&"scale_uniform": scale_uniform = value; return true
		&"pivot_mode": pivot_mode = value; return true
		&"custom_pivot": custom_pivot = value; return true
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
		&"custom_pivot": return custom_pivot
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

	if transform_target != TransformTarget.POSITION and not _pivot_applied:
		_apply_pivot_mode()
		_pivot_applied = true

	# Enable independent noise processing — runs alongside the base class
	# envelope animation during fade-in/out, and continues solo during sustain.
	set_physics_process(true)

	if debug_enabled:
		var target_name: String = TransformTarget.keys()[transform_target]
		print("[%s] Noise Control start (%s). Speed: %.2f" % [name, target_name, speed])


func _apply_effect(progress: float) -> void:
	# Store the base class envelope value for _physics_process() to read.
	# The actual noise application happens in _physics_process() — this keeps
	# noise evolution independent from the base class animation loop.
	_current_intensity = progress


## Independent noise processing — runs at physics rate, decoupled from the
## base class animation loop. Reads _current_intensity (set by _apply_effect)
## as the amplitude envelope, and evolves noise time continuously.
## This is what allows noise to keep running after animate_in completes
## without hacking base class state variables.
func _physics_process(delta: float) -> void:
	if _current_intensity <= 0.0:
		return

	if not is_instance_valid(_target_node) or not _target_node is Control:
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
	if not is_instance_valid(_target_node) or not _target_node is Control:
		return

	# Stop independent noise processing — no longer needed until next trigger
	_current_intensity = 0.0
	set_physics_process(false)

	var ctrl := _target_node as Control
	match transform_target:
		TransformTarget.POSITION:
			ctrl.position = _base_position
		TransformTarget.ROTATION:
			ctrl.rotation = _base_rotation
		TransformTarget.SCALE:
			ctrl.scale = _base_scale

	_has_base = false
	_pivot_applied = false


func _invalidate_base_cache() -> void:
	_has_base = false
	_pivot_applied = false

# =============================================================================
# SEQUENCER RECIPE CONTRACT
# =============================================================================

func _recipe_capture_natural(target: Node) -> Variant:
	if not target is Control:
		return null
	var ctrl := target as Control
	match transform_target:
		TransformTarget.POSITION:
			return ctrl.position
		TransformTarget.ROTATION:
			return ctrl.rotation
		TransformTarget.SCALE:
			return ctrl.scale
	return null


func _recipe_apply_natural(target: Node, natural: Variant) -> void:
	if not target is Control:
		return
	var ctrl := target as Control
	match transform_target:
		TransformTarget.POSITION:
			if natural is Vector2:
				ctrl.position = natural
		TransformTarget.ROTATION:
			if natural is float:
				ctrl.rotation = natural
		TransformTarget.SCALE:
			if natural is Vector2:
				ctrl.scale = natural


func _recipe_restore_natural(target: Node, natural: Variant) -> void:
	_recipe_apply_natural(target, natural)

# =============================================================================
# POSITION NOISE
# =============================================================================

func _apply_position_noise(intensity: float) -> void:
	var ctrl := _target_node as Control

	var sample_x := _sample_noise(0.0, position_speed_scale.x)
	var sample_y := _sample_noise(100.0, position_speed_scale.y)

	var offset := Vector2(
		position_amplitude.x * sample_x * intensity,
		position_amplitude.y * sample_y * intensity
	)

	ctrl.position = _base_position + offset

# =============================================================================
# ROTATION NOISE (single Z-axis, uses native pivot_offset)
# =============================================================================

func _apply_rotation_noise(intensity: float) -> void:
	var ctrl := _target_node as Control

	var sample := _sample_noise(0.0, 1.0)
	var rotation_offset := deg_to_rad(rotation_amplitude * sample * intensity)

	ctrl.rotation = _base_rotation + rotation_offset

# =============================================================================
# SCALE NOISE (uses native pivot_offset)
# =============================================================================

func _apply_scale_noise(intensity: float) -> void:
	var ctrl := _target_node as Control

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

	ctrl.scale = _base_scale + scale_offset

# =============================================================================
# PIVOT HANDLING (Control domain uses native pivot_offset)
# =============================================================================

## Apply pivot mode to the Control node's pivot_offset.
## AUTO_CENTER sets pivot to the center and listens to resized for reactive updates.
func _apply_pivot_mode() -> void:
	if not is_instance_valid(_target_node) or not _target_node is Control:
		return

	var ctrl := _target_node as Control

	match pivot_mode:
		PivotMode.AUTO_CENTER:
			ctrl.pivot_offset = ctrl.size / 2.0
			if not ctrl.resized.is_connected(_on_control_resized):
				ctrl.resized.connect(_on_control_resized)
		PivotMode.CUSTOM:
			ctrl.pivot_offset = ctrl.size * custom_pivot
			if not ctrl.resized.is_connected(_on_control_resized):
				ctrl.resized.connect(_on_control_resized)
		PivotMode.INHERIT:
			pass  # Use whatever pivot_offset is already set


func _on_control_resized() -> void:
	if not is_instance_valid(_target_node) or not _target_node is Control:
		return
	var ctrl := _target_node as Control
	match pivot_mode:
		PivotMode.AUTO_CENTER:
			ctrl.pivot_offset = ctrl.size / 2.0
		PivotMode.CUSTOM:
			ctrl.pivot_offset = ctrl.size * custom_pivot

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
	if not is_instance_valid(_target_node) or not _target_node is Control:
		return
	var ctrl := _target_node as Control
	_base_position = ctrl.position
	_base_rotation = ctrl.rotation
	_base_scale = ctrl.scale
	_has_base = true

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent := get_parent()
	if parent and not parent is Control:
		warnings.append("Parent must be a Control node. Use Noise2D/Noise3D for other domains. (ignore if comp is a child of a sequencer)")
	return warnings
