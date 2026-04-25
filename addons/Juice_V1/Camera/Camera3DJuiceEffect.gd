## Animates Camera3D position, rotation, or FOV via CameraJuiceUtility.
##
## Place this effect in any domain recipe on any entity. When triggered, it
## finds (or auto-creates) the active Camera3D's CameraJuiceUtility and applies
## the offset. No manual node setup required at runtime.

# ============================================================================
# WHAT: Meta effect that offsets Camera3D properties (position/rotation/FOV).
# WHY:  Camera shake and camera-space effects should be authored on the entity
#       that causes them (a boss, a door, an explosion) -- not on the camera.
#       This effect auto-discovers the active Camera3D each tick so camera
#       switches are handled correctly without any manual rewiring.
# SYSTEM: Juice System (addons/Juice_V1/Camera/)
# DOES NOT: Animate the JuiceBase target node -- writes to the camera only.
# DOES NOT: Handle Camera2D -- use Camera2DJuiceEffect for that.
# DOES NOT: Auto-bootstrap in the editor -- would dirty the scene on save.
#
# SETUP: None. Drop this effect in any recipe and it works at runtime.
#        Optionally add CameraJuiceUtility manually to tune offset limits.
#        Camera switches mid-animation are handled -- new camera gets its own
#        utility on first use. Old utility persists idle at zero cost.
# ============================================================================

@icon("res://addons/Juice_V1/icons/JuiceBaseCamera3D.svg")
@tool
class_name Camera3DJuiceEffect
extends JuiceEffectBase


# =============================================================================
# ENUMS
# =============================================================================

## Which Camera3D property to animate.
enum Channel {
	POSITION,  ## Offset camera position (kick, dolly). World or local space.
	ROTATION,  ## Offset camera rotation (tilt, roll, lean).
	FOV,       ## Offset field of view (zoom punch, breathe).
}

## Animation mode.
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

## Position offset at progress=1.0 (world-space meters, or camera-local if use_local_space).
var position_offset: Vector3 = Vector3(0.0, 0.0, 0.5)

## If true, position_offset is in camera-local space.
var use_local_space: bool = true

## Camera rotation offset at progress=1.0 (degrees). X=pitch, Y=yaw, Z=roll.
var rotation_offset_degrees: Vector3 = Vector3(0.0, 0.0, 5.0)

## FOV offset at progress=1.0 (degrees). Positive = wider, negative = narrower.
var fov_offset: float = -10.0

## SHAKE: Oscillation frequency (cycles per second).
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

	props.append({"name": "Camera 3D Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "channel", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Position,Rotation,FOV",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "animation_mode", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Deterministic,Shake",
		"usage": PROPERTY_USAGE_DEFAULT})

	match channel:
		Channel.POSITION:
			props.append({"name": "position_offset", "type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "use_local_space", "type": TYPE_BOOL,
				"usage": PROPERTY_USAGE_DEFAULT})
		Channel.ROTATION:
			props.append({"name": "rotation_offset_degrees", "type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT})
		Channel.FOV:
			props.append({"name": "fov_offset", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "-60.0,60.0,0.5,or_less,or_greater",
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
		&"channel":                 channel = value;                return true
		&"animation_mode":          animation_mode = value;         return true
		&"position_offset":         position_offset = value;        return true
		&"use_local_space":         use_local_space = value;        return true
		&"rotation_offset_degrees": rotation_offset_degrees = value; return true
		&"fov_offset":              fov_offset = value;             return true
		&"shake_frequency":         shake_frequency = value;        return true
		&"shake_seed":              shake_seed = value;             return true
		&"shake_noise_type":        shake_noise_type = value;       return true
	return super._set(property, value)


func _get(property: StringName) -> Variant:
	match property:
		&"channel":                 return channel
		&"animation_mode":          return animation_mode
		&"position_offset":         return position_offset
		&"use_local_space":         return use_local_space
		&"rotation_offset_degrees": return rotation_offset_degrees
		&"fov_offset":              return fov_offset
		&"shake_frequency":         return shake_frequency
		&"shake_seed":              return shake_seed
		&"shake_noise_type":        return shake_noise_type
	return super._get(property)


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _my_pos: Vector3 = Vector3.ZERO
var _my_rot: Vector3 = Vector3.ZERO
var _my_fov: float   = 0.0

# FastNoiseLite instance — created at _on_animate_start for SHAKE mode.
var _shake_noise: FastNoiseLite = null


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

func _needs_sustain() -> bool:
	return animation_mode == AnimationMode.SHAKE


func _on_animate_start(_target: Node) -> void:
	if animation_mode != AnimationMode.SHAKE:
		return
	_shake_noise = FastNoiseLite.new()
	_shake_noise.noise_type = shake_noise_type
	_shake_noise.seed      = int(shake_seed)
	_shake_noise.frequency = 1.0  # Rate driven externally via t * shake_frequency


func _apply_effect(progress: float, _target: Node) -> void:
	var util := _find_or_create_utility()
	if not is_instance_valid(util):
		return

	match channel:
		Channel.POSITION: _apply_position(util, progress)
		Channel.ROTATION: _apply_rotation(util, progress)
		Channel.FOV:      _apply_fov(util, progress)


func _on_animate_out_complete(_target: Node) -> void:
	_remove_contribution()


func _restore_to_natural(_target: Node) -> void:
	_remove_contribution()


# =============================================================================
# CHANNEL APPLY
# =============================================================================

func _apply_position(util: CameraJuiceUtility, progress: float) -> void:
	var desired: Vector3
	if animation_mode == AnimationMode.SHAKE and _shake_noise != null:
		# Decorrelated X/Y/Z: each axis sampled from a different noise-field row
		# to prevent diagonal-locked motion from a single scalar multiply.
		var t := Time.get_ticks_msec() / 1000.0 * shake_frequency
		desired = Vector3(
			position_offset.x * _shake_noise.get_noise_2d(t, 0.0)   * progress,
			position_offset.y * _shake_noise.get_noise_2d(t, 100.0) * progress,
			position_offset.z * _shake_noise.get_noise_2d(t, 200.0) * progress)
		if use_local_space:
			var cam := _find_camera_3d()
			if cam:
				desired = cam.global_transform.basis * desired
	else:
		var s := _sample(progress, 0.0)
		desired = position_offset * s
		if use_local_space:
			var cam := _find_camera_3d()
			if cam:
				desired = cam.global_transform.basis * desired
	var delta := desired - _my_pos
	util.position_offset += delta
	_my_pos = desired


func _apply_rotation(util: CameraJuiceUtility, progress: float) -> void:
	var rad := Vector3(
		deg_to_rad(rotation_offset_degrees.x),
		deg_to_rad(rotation_offset_degrees.y),
		deg_to_rad(rotation_offset_degrees.z)
	)
	var desired := rad * _sample(progress, 200.0)
	var delta   := desired - _my_rot
	util.rotation_offset += delta
	_my_rot = desired


func _apply_fov(util: CameraJuiceUtility, progress: float) -> void:
	var desired := fov_offset * _sample(progress, 300.0)
	var delta   := desired - _my_fov
	util.zoom_offset += delta
	_my_fov = desired


# =============================================================================
# CONTRIBUTION CLEANUP
# =============================================================================

func _remove_contribution() -> void:
	var cam := _find_camera_3d()
	var util: CameraJuiceUtility = null
	if is_instance_valid(cam):
		for child in cam.get_children():
			if child is CameraJuiceUtility:
				util = child
				break
	if is_instance_valid(util):
		util.position_offset -= _my_pos
		util.rotation_offset -= _my_rot
		util.zoom_offset     -= _my_fov
	_my_pos = Vector3.ZERO
	_my_rot = Vector3.ZERO
	_my_fov = 0.0


# =============================================================================
# SHAKE OSCILLATOR
# =============================================================================

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

# Returns the active Camera3D's CameraJuiceUtility, creating one if absent.
# Re-discovers every call — handles mid-animation camera switches at zero cost.
# Returns null in editor (would dirty the scene) or if no Camera3D exists.
func _find_or_create_utility() -> CameraJuiceUtility:
	if Engine.is_editor_hint():
		return null

	var cam := _find_camera_3d()
	if not cam:
		return null

	for child in cam.get_children():
		if child is CameraJuiceUtility:
			return child

	return _bootstrap_utility_on(cam)


# Creates and attaches a CameraJuiceUtility to the given camera.
func _bootstrap_utility_on(cam: Camera3D) -> CameraJuiceUtility:
	var util := CameraJuiceUtility.new()
	util.name = "CameraJuiceUtility"
	cam.add_child(util)
	util._initialize_camera()

	JuiceLogger.log_info(self, _get_domain_tag(),
			"auto-bootstrapped CameraJuiceUtility on '%s'" % cam.name,
			debug_enabled)

	return util


func _find_camera_3d() -> Camera3D:
	if not is_instance_valid(_host_node):
		return null
	var vp := _host_node.get_viewport()
	if not vp:
		return null
	var cam := vp.get_camera_3d()
	if not cam:
		JuiceLogger.warn(self, _get_domain_tag(),
				"no active Camera3D found in viewport", debug_enabled)
	return cam
