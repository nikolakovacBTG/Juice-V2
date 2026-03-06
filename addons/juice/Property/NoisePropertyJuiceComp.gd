## NoisePropertyJuiceComp.gd
## ============================================================================
## WHAT: Domain-agnostic noise effect for any property on any node.
##       Oscillates a property value around its base using FastNoiseLite,
##       with configurable noise type, frequency, speed, and amplitude.
## WHY: Extends the Noise family beyond transforms — noise-drive a light's energy,
##      a material's roughness, an audio bus volume, a shader parameter, etc.
##      This is the "+1" in the 3+1 architecture (domain-agnostic complement
##      to the 3 domain-specific noise scripts).
##
## WRITE PATTERN: Delta-first. Each frame writes only the CHANGE in this comp's
##   contribution: property += (new_offset - _my_contribution). This enables
##   stacking with other effects and preserves external changes to the property.
## SYSTEM: Juicing System (addons/juice/) - Property Domain
## DOES NOT: Handle transform noise (use NoiseControl/Noise2D/Noise3D).
## DOES NOT: Handle camera effects (use Camera3DJuiceComp / Camera2DJuiceComp).
##
## PLACEMENT:
## Add as child of (or in the same scene as) the node whose property you want
## to affect — property resolution uses NodePath, which requires scene-tree
## proximity. To trigger the effect from a remote source (e.g., an enemy hit
## triggering camera shake), keep the juice comp near the target and use
## manual_trigger_signal + trigger_source_path pointed at a SignalBus or
## relay node. This is standard Godot signal routing, not a workaround.
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
## PROPERTY ACCESS:
## Uses get_indexed() / set_indexed() to read/write any property by path.
## Supports nested paths like "modulate:a", "material:shader_parameter/dissolve".
## Property type must be specified so the correct noise math is applied.
##
## CONDITIONAL EXPORTS:
## Changing property_type triggers notify_property_list_changed() which
## shows/hides the relevant per-type amplitude values via _get_property_list().
##
## REFERENCE:
## Property resolution pattern adapted from ShakePropertyJuiceComp.
## Noise math adapted from the Noise family domain scripts.
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBaseProperty.svg")
class_name NoisePropertyJuiceComp
extends JuiceCompBase

# =============================================================================
# PROPERTY TARGET CONFIGURATION
# =============================================================================

@export_group("Property Target")

## Path to node containing the property.
## Leave empty to use parent node.
@export_node_path("Node") var target_node_path: NodePath

## Path to the property to drive with noise (e.g., "modulate:a", "light_energy")
## Supports nested paths like "material:shader_parameter/dissolve"
@export var property_path: String = ""

## Type of the property value — determines which amplitude export is shown
## and which math is used for oscillation.
enum PropertyType {
	FLOAT,
	VECTOR2,
	VECTOR3,
	COLOR
}

@export var property_type: PropertyType = PropertyType.FLOAT:
	set(value):
		property_type = value
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
@export var fractal_type: FastNoiseLite.FractalType = FastNoiseLite.FRACTAL_NONE

## Number of fractal octaves (layers of detail). More = richer but costlier.
@export_range(1, 6) var octaves: int = 1

## Frequency multiplier per octave.
@export var lacunarity: float = 2.0

## Amplitude multiplier per octave.
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
@export var absolute_mode: bool = false

## Invert noise output — flips displacement direction
@export var invert_output: bool = false

## Clamp noise output minimum (applied after absolute/invert, before amplitude)
@export var output_min: float = -1.0

## Clamp noise output maximum (applied after absolute/invert, before amplitude)
@export var output_max: float = 1.0

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — they are shown/hidden via _get_property_list()
# =============================================================================

## Maximum noise offset for float properties
var float_amplitude: float = 0.5

## Maximum noise offset per axis for Vector2 properties
var vector2_amplitude: Vector2 = Vector2(0.1, 0.1)

## Maximum noise offset per axis for Vector3 properties
var vector3_amplitude: Vector3 = Vector3(0.1, 0.1, 0.1)

## Maximum noise offset per channel for Color properties (RGBA)
var color_amplitude: Color = Color(0.1, 0.1, 0.1, 0.0)

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Resolved property target node
var _property_target_node: Node = null

## Captured base property value (type varies)
var _base_value: Variant = null

## Whether base has been captured
var _has_base: bool = false

## Whether configuration has been validated
var _is_valid: bool = false

## FastNoiseLite instance
var _noise: FastNoiseLite

## Accumulated noise time (drives the noise sampling)
var _noise_time: float = 0.0

## Current amplitude envelope value from the base class animation loop.
## Stored by _apply_effect(), read by _physics_process() to scale noise output.
var _current_intensity: float = 0.0

## Delta-first contribution tracking.
## Tracks what THIS comp last wrote as an offset so we can compute deltas.
## Type matches the property being driven (float, Vector2, Vector3, Color).
var _my_contribution: Variant = null

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	match property_type:
		PropertyType.FLOAT:
			props.append({
				"name": "float_amplitude",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
		PropertyType.VECTOR2:
			props.append({
				"name": "vector2_amplitude",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
		PropertyType.VECTOR3:
			props.append({
				"name": "vector3_amplitude",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
		PropertyType.COLOR:
			props.append({
				"name": "color_amplitude",
				"type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT,
			})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"float_amplitude": float_amplitude = value; return true
		&"vector2_amplitude": vector2_amplitude = value; return true
		&"vector3_amplitude": vector3_amplitude = value; return true
		&"color_amplitude": color_amplitude = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"float_amplitude": return float_amplitude
		&"vector2_amplitude": return vector2_amplitude
		&"vector3_amplitude": return vector3_amplitude
		&"color_amplitude": return color_amplitude
	return null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()
	_validate_configuration()
	# Noise evolution runs in _physics_process, independent of the base class
	# animation loop. Disabled until an animation starts.
	set_physics_process(false)


func _validate_configuration() -> void:
	_is_valid = true

	# Resolve target node
	if target_node_path.is_empty():
		_property_target_node = get_parent()
	else:
		_property_target_node = get_node_or_null(target_node_path)

	if _property_target_node == null:
		push_warning("[%s] PropertyNoise: target node not found" % name)
		_is_valid = false
	elif property_path.is_empty():
		push_warning("[%s] PropertyNoise: property_path is empty" % name)
		_is_valid = false

	if debug_enabled and _is_valid:
		var resolved_name: String = "null"
		if _property_target_node != null:
			resolved_name = str(_property_target_node.name)
		print("[%s] PropertyNoise validated. Target: %s, Path: %s, Type: %s" % [
			name, resolved_name, property_path, PropertyType.keys()[property_type]
		])


# =============================================================================
# ANIMATION HOOKS
# =============================================================================

func _on_animate_start() -> void:
	if not _is_valid:
		_validate_configuration()
	if not _is_valid:
		return

	if not _has_base:
		_capture_base()

	# Only reset noise when animating IN — during fade-out, freeze the current noise state
	# so the offset smoothly returns to base instead of jumping to a new random value
	if _target_progress > 0.0:
		_noise_time = 0.0
		_setup_noise()

	# Enable independent noise processing — runs alongside the base class
	# envelope animation during fade-in/out, and continues solo during sustain.
	set_physics_process(true)

	if debug_enabled:
		print("[%s] PropertyNoise start. Path: %s, Type: %s, Base: %s, Speed: %.2f" % [
			name, property_path, PropertyType.keys()[property_type],
			_base_value, speed
		])


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

	if not _is_valid or not is_instance_valid(_property_target_node):
		return

	# Don't advance noise time during fade-out — freeze the noise sample
	# so intensity smoothly scales the current offset down to zero
	if _target_progress > 0.0:
		_noise_time += delta

	match property_type:
		PropertyType.FLOAT:
			_apply_float_noise(_current_intensity)
		PropertyType.VECTOR2:
			_apply_vector2_noise(_current_intensity)
		PropertyType.VECTOR3:
			_apply_vector3_noise(_current_intensity)
		PropertyType.COLOR:
			_apply_color_noise(_current_intensity)


func _on_animate_out_complete() -> void:
	# Stop independent noise processing
	_current_intensity = 0.0
	set_physics_process(false)
	# Safety cleanup: remove any remaining contribution
	_remove_contribution()


func _exit_tree() -> void:
	# Clean up our delta contribution if freed mid-animation
	_remove_contribution()


func _invalidate_base_cache() -> void:
	_has_base = false
	_my_contribution = null


## Subtract our current contribution from the property and reset tracking.
## Safe to call even if no contribution was made (_my_contribution == null).
func _remove_contribution() -> void:
	if _my_contribution == null:
		return
	if not is_instance_valid(_property_target_node):
		_my_contribution = null
		return

	var current: Variant = _property_target_node.get_indexed(property_path)
	match property_type:
		PropertyType.FLOAT:
			var prev: float = _my_contribution as float
			_property_target_node.set_indexed(property_path, (current as float) - prev)
		PropertyType.VECTOR2:
			var prev: Vector2 = _my_contribution as Vector2
			_property_target_node.set_indexed(property_path, (current as Vector2) - prev)
		PropertyType.VECTOR3:
			var prev: Vector3 = _my_contribution as Vector3
			_property_target_node.set_indexed(property_path, (current as Vector3) - prev)
		PropertyType.COLOR:
			var prev: Color = _my_contribution as Color
			var cur: Color = current as Color
			_property_target_node.set_indexed(property_path, Color(
				cur.r - prev.r, cur.g - prev.g, cur.b - prev.b, cur.a - prev.a
			))
	_my_contribution = null

# =============================================================================
# PER-TYPE NOISE APPLICATION
# =============================================================================

func _apply_float_noise(intensity: float) -> void:
	var sample := _sample_noise(0.0, 1.0)
	var offset := float_amplitude * sample * intensity
	var prev: float = _my_contribution if _my_contribution is float else 0.0
	var current: float = _property_target_node.get_indexed(property_path)
	_property_target_node.set_indexed(property_path, current + offset - prev)
	_my_contribution = offset


func _apply_vector2_noise(intensity: float) -> void:
	var sample_x := _sample_noise(0.0, 1.0)
	var sample_y := _sample_noise(100.0, 1.0)
	var offset := Vector2(
		vector2_amplitude.x * sample_x * intensity,
		vector2_amplitude.y * sample_y * intensity
	)
	var prev: Vector2 = _my_contribution if _my_contribution is Vector2 else Vector2.ZERO
	var current: Vector2 = _property_target_node.get_indexed(property_path)
	_property_target_node.set_indexed(property_path, current + offset - prev)
	_my_contribution = offset


func _apply_vector3_noise(intensity: float) -> void:
	var sample_x := _sample_noise(0.0, 1.0)
	var sample_y := _sample_noise(100.0, 1.0)
	var sample_z := _sample_noise(200.0, 1.0)
	var offset := Vector3(
		vector3_amplitude.x * sample_x * intensity,
		vector3_amplitude.y * sample_y * intensity,
		vector3_amplitude.z * sample_z * intensity
	)
	var prev: Vector3 = _my_contribution if _my_contribution is Vector3 else Vector3.ZERO
	var current: Vector3 = _property_target_node.get_indexed(property_path)
	_property_target_node.set_indexed(property_path, current + offset - prev)
	_my_contribution = offset


func _apply_color_noise(intensity: float) -> void:
	var sample_r := _sample_noise(0.0, 1.0)
	var sample_g := _sample_noise(100.0, 1.0)
	var sample_b := _sample_noise(200.0, 1.0)
	var sample_a := _sample_noise(300.0, 1.0)
	var offset := Color(
		color_amplitude.r * sample_r * intensity,
		color_amplitude.g * sample_g * intensity,
		color_amplitude.b * sample_b * intensity,
		color_amplitude.a * sample_a * intensity
	)
	var prev: Color = _my_contribution if _my_contribution is Color else Color(0, 0, 0, 0)
	var current: Color = _property_target_node.get_indexed(property_path)
	var delta := Color(offset.r - prev.r, offset.g - prev.g, offset.b - prev.b, offset.a - prev.a)
	_property_target_node.set_indexed(property_path, Color(
		current.r + delta.r, current.g + delta.g,
		current.b + delta.b, current.a + delta.a
	))
	_my_contribution = offset

# =============================================================================
# BASE VALUE CAPTURE
# =============================================================================

func _capture_base() -> void:
	if not is_instance_valid(_property_target_node):
		return

	_base_value = _property_target_node.get_indexed(property_path)
	_has_base = _base_value != null

	if debug_enabled:
		print("[%s] Captured property base: %s = %s" % [name, property_path, _base_value])

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

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if property_path.is_empty():
		warnings.append("property_path must be configured (e.g. 'position:x', 'modulate:r').")
	return warnings
