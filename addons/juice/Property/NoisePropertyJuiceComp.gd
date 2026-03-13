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
## All conditional properties are @export with _validate_property() for visibility.
## Changing property_type, fractal_type, or domain_warp_enabled triggers
## conditional show/hide of relevant parameters.
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
# ENUMS
# =============================================================================

## Type of the property value — determines which amplitude export is shown
## and which math is used for oscillation.
enum PropertyType {
	FLOAT,
	VECTOR2,
	VECTOR3,
	COLOR
}

## Controls the direction of noise displacement
enum NoiseDirection {
	BOTH,           ## Full range: positive and negative displacement (-1 to 1)
	POSITIVE_ONLY,  ## One-directional: only positive displacement (0 to 1)
	NEGATIVE_ONLY   ## One-directional: only negative displacement (-1 to 0)
}

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
@export var property_type: PropertyType = PropertyType.FLOAT:
	set(value):
		property_type = value
		notify_property_list_changed()

# =============================================================================
# EFFECT CONFIGURATION
# =============================================================================

@export_group("Effect")

## Maximum noise offset for float properties.
## Hidden when property_type != FLOAT.
@export var float_amplitude: float = 0.5

## Maximum noise offset per axis for Vector2 properties.
## Hidden when property_type != VECTOR2.
@export var vector2_amplitude: Vector2 = Vector2(0.1, 0.1)

## Maximum noise offset per axis for Vector3 properties.
## Hidden when property_type != VECTOR3.
@export var vector3_amplitude: Vector3 = Vector3(0.1, 0.1, 0.1)

## Maximum noise offset per channel for Color properties (RGBA).
## Hidden when property_type != COLOR.
@export var color_amplitude: Color = Color(0.1, 0.1, 0.1, 0.0)

## How fast the noise evolves — higher = faster motion.
## This is temporal speed (how fast you move through the noise field).
## See also noise_frequency which controls spatial scale of the pattern.
@export var noise_speed: float = 1.0

## Controls the direction of noise displacement.
## BOTH: Full range positive and negative. POSITIVE_ONLY / NEGATIVE_ONLY: one-directional.
@export var noise_direction: NoiseDirection = NoiseDirection.BOTH

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

## Minimum noise output value (applied after direction, before amplitude).
@export var clamp_min: float = -1.0

## Maximum noise output value (applied after direction, before amplitude).
@export var clamp_max: float = 1.0

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
# CONDITIONAL PROPERTY VISIBILITY
# =============================================================================

func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)

	# Effect group: show only relevant amplitude per property type
	if property.name == "float_amplitude" and property_type != PropertyType.FLOAT:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "vector2_amplitude" and property_type != PropertyType.VECTOR2:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "vector3_amplitude" and property_type != PropertyType.VECTOR3:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "color_amplitude" and property_type != PropertyType.COLOR:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	# Fractal: hide detail settings when no fractal layering
	if property.name in ["fractal_octaves", "lacunarity", "fractal_gain"] and fractal_type == FastNoiseLite.FRACTAL_NONE:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	# Domain warp: hide settings when warp is disabled
	if property.name in ["domain_warp_amplitude", "domain_warp_frequency"] and not domain_warp_enabled:
		property.usage = PROPERTY_USAGE_NO_EDITOR

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
			_base_value, noise_speed
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

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if property_path.is_empty():
		warnings.append("property_path must be configured (e.g. 'position:x', 'modulate:r').")
	return warnings
