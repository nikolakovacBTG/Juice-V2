## Animates Camera2D position, rotation, or zoom via CameraJuiceUtility.
##
## Place this effect in any domain recipe on any entity. When triggered, it
## finds (or auto-creates) the active Camera2D's CameraJuiceUtility and applies
## the offset. No manual node setup required at runtime.

# ============================================================================
# WHAT: Meta effect that offsets Camera2D properties (position/rotation/zoom)
#       via CameraJuiceUtility. Two animation modes: Deterministic (smooth curve)
#       or Shake (chaotic noise-driven with curve envelope).
# WHY:  Camera shake is authored on the entity that causes it — a chest, a sword,
#       an explosion — not on the camera itself. This effect auto-discovers the
#       active Camera2D, so camera switches mid-animation work automatically.
# SYSTEM: Juice System (addons/Juice_V1/Camera/)
# DOES NOT: Animate the JuiceBase target node — writes to camera only.
# DOES NOT: Handle Camera3D — use Camera3DJuiceEffect for that.
# DOES NOT: Auto-bootstrap in the editor — would dirty the scene on save.
#
# SETUP: None. Drop in any recipe. Works at runtime automatically.
#        Optionally add CameraJuiceUtility manually to tune limits.
# ============================================================================

@icon("res://addons/Juice_V1/icons/JuiceBaseCamera2D.svg")
@tool
class_name Camera2DJuiceEffect
extends JuiceEffectBase


# =============================================================================
# ENUMS
# =============================================================================

## Which Camera2D property to animate.
enum Channel {
	POSITION,  ## Offset camera position (kick, dolly). Unit controlled by position_unit.
	ROTATION,  ## Offset camera rotation (tilt, dutch angle). Always in degrees.
	ZOOM,      ## Offset camera zoom (punch zoom, breathe).
}

## Unit for the POSITION channel.
enum PositionUnit {
	PIXELS,           ## Direct pixels — absolute, viewport-size-dependent.
	PERCENT_VIEWPORT, ## Percent of viewport size — resolution independent.
}

## Animation mode. Deterministic plays a smooth curve-shaped ramp.
## Shake adds a multi-frequency noise oscillator whose amplitude is the curve.
enum AnimationMode {
	DETERMINISTIC, ## Smooth ramp: 0 → value → 0. Curve shapes the motion.
	SHAKE,         ## Chaotic: value = max amplitude, curve = amplitude envelope.
}


# =============================================================================
# CONFIGURATION
# =============================================================================

## Which camera channel to animate.
var channel: int = Channel.POSITION:
	set(value):
		channel = value
		notify_property_list_changed()

## Animation mode.
var animation_mode: int = AnimationMode.DETERMINISTIC:
	set(value):
		animation_mode = value
		notify_property_list_changed()

# --- Channel-specific values (shown/hidden by _get_property_list) ---

## POSITION: Camera position offset at peak. Interpretation depends on position_unit.
var position_offset: Vector2 = Vector2(3.0, 0.0)

## POSITION: Unit for position_offset.
var position_unit: int = PositionUnit.PERCENT_VIEWPORT:
	set(value):
		position_unit = value
		notify_property_list_changed()

## ROTATION: Camera rotation offset at peak (degrees, Z-axis).
var rotation_degrees: float = 5.0

## ZOOM: Camera zoom offset at peak. Positive = zoom in (larger zoom value on Camera2D).
var zoom_offset: float = 0.2

# --- Shake parameters (visible only when animation_mode == SHAKE) ---

## SHAKE: Oscillation frequency (cycles per second). Higher = more frantic.
var shake_frequency: float = 8.0

## SHAKE: Seed for the noise field. Different seeds produce different oscillation character.
var shake_seed: float = 0.0

## SHAKE: Noise algorithm that shapes the oscillator character.
## - Simplex Smooth: organic, flowing tremor (default)
## - Cellular:       twitchy, heartbeat-style glitch
## - Perlin:         classic gradient rumble
## - Value:          chunky, retro blocky shake
var shake_noise_type: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _init() -> void:
	_subclass_owns_effect_group = true


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	props.append({"name": "Camera 2D Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})

	props.append({"name": "channel", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Position,Rotation,Zoom",
		"usage": PROPERTY_USAGE_DEFAULT})

	props.append({"name": "animation_mode", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Deterministic,Shake",
		"usage": PROPERTY_USAGE_DEFAULT})

	match channel:
		Channel.POSITION:
			props.append({"name": "position_offset", "type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "position_unit", "type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM, "hint_string": "Pixels,Percent Viewport",
				"usage": PROPERTY_USAGE_DEFAULT})
		Channel.ROTATION:
			props.append({"name": "rotation_degrees", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "-180.0,180.0,0.1,or_less,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})
		Channel.ZOOM:
			props.append({"name": "zoom_offset", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "-5.0,5.0,0.01,or_less,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})

	if animation_mode == AnimationMode.SHAKE:
		props.append({"name": "shake_frequency", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.5,30.0,0.5",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "shake_seed", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1000.0,1.0",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "shake_noise_type", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Simplex Smooth:1,Simplex:0,Cellular:2,Perlin:3,Value:5,Value Cubic:6",
			"usage": PROPERTY_USAGE_DEFAULT})

	props.append_array(_get_effect_base_properties())
	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"channel":          channel = value;          return true
		&"animation_mode":   animation_mode = value;   return true
		&"position_offset":  position_offset = value;  return true
		&"position_unit":    position_unit = value;    return true
		&"rotation_degrees": rotation_degrees = value; return true
		&"zoom_offset":      zoom_offset = value;      return true
		&"shake_frequency":  shake_frequency = value;  return true
		&"shake_seed":       shake_seed = value;       return true
		&"shake_noise_type": shake_noise_type = value; return true
	return super._set(property, value)


func _get(property: StringName) -> Variant:
	match property:
		&"channel":          return channel
		&"animation_mode":   return animation_mode
		&"position_offset":  return position_offset
		&"position_unit":    return position_unit
		&"rotation_degrees": return rotation_degrees
		&"zoom_offset":      return zoom_offset
		&"shake_frequency":  return shake_frequency
		&"shake_seed":       return shake_seed
		&"shake_noise_type": return shake_noise_type
	return super._get(property)


# =============================================================================
# INTERNAL STATE
# =============================================================================

# Delta-first contribution tracking — what THIS effect has written to the utility this frame.
var _my_pos:  Vector3 = Vector3.ZERO
var _my_rot:  Vector3 = Vector3.ZERO
var _my_zoom: float   = 0.0

# FastNoiseLite instance — created at _on_animate_start for SHAKE mode.
var _shake_noise: FastNoiseLite = null



# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

# SHAKE mode has no fixed endpoint — it oscillates until the chain stops it.
# Sustain keeps _apply_effect ticking after animate_in peaks so the noise
# continues. DETERMINISTIC mode completes naturally at progress=1.0.
func _needs_sustain() -> bool:
	return animation_mode == AnimationMode.SHAKE


# Only runs for SHAKE mode: instantiates and configures the noise field used by _sample().
# DETERMINISTIC mode needs no noise — _apply_effect uses the base-class curve directly.
func _on_animate_start(_target: Node) -> void:
	if animation_mode != AnimationMode.SHAKE:
		return
	_shake_noise = FastNoiseLite.new()
	_shake_noise.noise_type = shake_noise_type
	_shake_noise.seed      = int(shake_seed)
	_shake_noise.frequency = 1.0  # Rate driven externally via t * shake_frequency


# Re-discovers (or bootstraps) CameraJuiceUtility every frame rather than caching it.
# This handles mid-animation camera switches transparently at the cost of one
# child-scan per frame — acceptable since Camera2D rarely has many children.
func _apply_effect(progress: float, _target: Node) -> void:
	# Re-discover (or bootstrap) utility every frame — handles camera switches.
	var util := _find_or_create_utility()
	if not is_instance_valid(util):
		return

	match channel:
		Channel.POSITION: _apply_position(util, progress)
		Channel.ROTATION: _apply_rotation(util, progress)
		Channel.ZOOM:     _apply_zoom(util, progress)


func _on_animate_out_complete(_target: Node) -> void:
	_remove_contribution()


# Removes this effect's accumulated delta from the utility so other effects
# and future animations start from an uncontaminated base. Skips if the
# utility was already freed (e.g. camera switched or scene unloaded).
func _restore_to_natural(_target: Node) -> void:
	_remove_contribution()


# =============================================================================
# CHANNEL APPLY METHODS
# =============================================================================

# SHAKE: samples decorrelated X and Y noise (different row offsets prevent
# diagonal lock-in from a single scalar multiply), scales by position_offset
# and viewport size if PERCENT_VIEWPORT, then multiplies by the progress envelope.
# DETERMINISTIC: evaluates the curve via _sample and scales by position_offset.
# Both paths write desired, compute delta from last frame's _my_pos, and
# accumulate into the utility — stacking correctly with other camera effects.
func _apply_position(util: CameraJuiceUtility, progress: float) -> void:
	var desired: Vector3
	if animation_mode == AnimationMode.SHAKE and _shake_noise != null:
		# Decorrelated X/Y: each axis sampled from a different noise-field row
		# to prevent diagonal-locked motion from a single scalar multiply.
		var t := Time.get_ticks_msec() / 1000.0 * shake_frequency
		var nx := _shake_noise.get_noise_2d(t, 0.0)
		var ny := _shake_noise.get_noise_2d(t, 100.0)
		var px: Vector2
		match position_unit:
			PositionUnit.PIXELS:
				px = Vector2(position_offset.x * nx, position_offset.y * ny) * progress
			PositionUnit.PERCENT_VIEWPORT:
				if is_instance_valid(_host_node):
					var vp_size := _host_node.get_viewport().get_visible_rect().size
					px = Vector2(
						position_offset.x * vp_size.x / 100.0 * nx,
						position_offset.y * vp_size.y / 100.0 * ny) * progress
				else:
					px = Vector2(position_offset.x * nx, position_offset.y * ny) * progress
		desired = Vector3(px.x, px.y, 0.0)
	else:
		var s := _sample(progress, 0.0)
		var px: Vector2
		match position_unit:
			PositionUnit.PIXELS:
				px = position_offset * s
			PositionUnit.PERCENT_VIEWPORT:
				if is_instance_valid(_host_node):
					var vp_size := _host_node.get_viewport().get_visible_rect().size
					px = Vector2(position_offset.x * vp_size.x / 100.0,
								 position_offset.y * vp_size.y / 100.0) * s
				else:
					px = position_offset * s
		desired = Vector3(px.x, px.y, 0.0)
	var delta   := desired - _my_pos
	util.position_offset += delta
	_my_pos = desired


func _apply_rotation(util: CameraJuiceUtility, progress: float) -> void:
	var desired := Vector3(0.0, 0.0, deg_to_rad(rotation_degrees) * _sample(progress, 200.0))
	var delta   := desired - _my_rot
	util.rotation_offset += delta
	_my_rot = desired


func _apply_zoom(util: CameraJuiceUtility, progress: float) -> void:
	var desired := zoom_offset * _sample(progress, 300.0)
	var delta   := desired - _my_zoom
	util.zoom_offset += delta
	_my_zoom = desired


# =============================================================================
# CONTRIBUTION CLEANUP
# =============================================================================

func _remove_contribution() -> void:
	var util := _find_utility()
	if is_instance_valid(util):
		util.position_offset -= _my_pos
		util.rotation_offset -= _my_rot
		util.zoom_offset     -= _my_zoom
	_my_pos  = Vector3.ZERO
	_my_rot  = Vector3.ZERO
	_my_zoom = 0.0


# =============================================================================
# SHAKE OSCILLATOR
# =============================================================================

# Returns effective multiplier. DETERMINISTIC = envelope; SHAKE = envelope × noise.
func _sample(envelope: float, seed_offset: float) -> float:
	match animation_mode:
		AnimationMode.DETERMINISTIC:
			return envelope
		AnimationMode.SHAKE:
			if _shake_noise == null:
				return envelope
			var t := Time.get_ticks_msec() / 1000.0 * shake_frequency
			return envelope * _shake_noise.get_noise_2d(t, seed_offset)
		_:
			return envelope


# =============================================================================
# UTILITY DISCOVERY + AUTO-BOOTSTRAP
# =============================================================================

# Fast path — returns existing utility without discovery overhead.
func _find_utility() -> CameraJuiceUtility:
	if not is_instance_valid(_host_node):
		return null
	var vp := _host_node.get_viewport()
	if not vp:
		return null
	var cam := vp.get_camera_2d()
	if not is_instance_valid(cam):
		return null
	for child in cam.get_children():
		if child is CameraJuiceUtility:
			return child
	return null


# Returns the active Camera2D's utility, creating one if absent.
# Fast-path: if a utility already exists (e.g. pre-placed by JuicePreviewDirector
# for editor preview), return it immediately — even in editor context. The guard
# below only prevents self-bootstrapping, which would dirty the scene.
func _find_or_create_utility() -> CameraJuiceUtility:
	if not is_instance_valid(_host_node):
		return null

	var vp := _host_node.get_viewport()
	if not vp:
		return null

	var cam := vp.get_camera_2d()
	if not is_instance_valid(cam):
		JuiceLogger.warn(self, _get_domain_tag(),
				"no enabled Camera2D found in viewport — add a Camera2D and set Enabled = true",
				debug_enabled)
		return null

	# Fast path — utility already exists (runtime-bootstrapped or Director-placed for preview)
	for child in cam.get_children():
		if child is CameraJuiceUtility:
			return child

	# Do not self-bootstrap in editor: add_child() would mark the scene dirty.
	# The Director bootstraps the utility before play() when in editor preview.
	if Engine.is_editor_hint():
		return null

	return _bootstrap_utility_on(cam)


# Creates and attaches a CameraJuiceUtility to the given camera.
func _bootstrap_utility_on(cam: Camera2D) -> CameraJuiceUtility:
	var util := CameraJuiceUtility.new()
	util.name = "CameraJuiceUtility"
	cam.add_child(util)
	util._initialize_camera()

	JuiceLogger.log_info(self, _get_domain_tag(),
			"auto-bootstrapped CameraJuiceUtility on '%s'" % cam.name,
			debug_enabled)

	return util
