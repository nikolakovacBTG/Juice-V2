## Animates Camera2D position, rotation, or zoom via CameraJuiceUtility.
##
## Place this effect in any domain recipe on any entity. When triggered, it
## finds (or auto-creates) the active Camera2D's CameraJuiceUtility and applies
## the offset. No manual node setup required at runtime.

# ============================================================================
# WHAT: Meta effect that offsets Camera2D properties (position/rotation/zoom).
# WHY:  Camera shake and camera-space effects should be authored on the entity
#       that causes them (a chest, a door, an explosion) -- not on the camera.
#       This effect auto-discovers the active Camera2D each tick so camera
#       switches are handled correctly without any manual rewiring.
# SYSTEM: Juice System (addons/Juice_V1/Camera/)
# DOES NOT: Animate the JuiceBase target node -- writes to the camera only.
# DOES NOT: Handle Camera3D -- use Camera3DJuiceEffect for that.
# DOES NOT: Auto-bootstrap in the editor -- would dirty the scene on save.
#
# SETUP: None. Drop this effect in any recipe and it works at runtime.
#        Optionally add CameraJuiceUtility manually to a camera to tune limits.
#        On camera switch mid-animation, the new camera gets its own utility
#        on first use. Old utility persists idle at zero cost.
# ============================================================================

@tool
class_name Camera2DJuiceEffect
extends JuiceEffectBase


# =============================================================================
# ENUMS
# =============================================================================

## Which Camera2D property to animate.
enum Channel {
	POSITION,  ## Offset camera position (kick, dolly, push). % of viewport size.
	ROTATION,  ## Offset camera rotation (tilt, dutch angle).
	ZOOM,      ## Offset camera zoom (punch zoom, breathe).
}


# =============================================================================
# CONFIGURATION
# =============================================================================

## Which camera channel to animate.
var channel: int = Channel.POSITION:
	set(value):
		channel = value
		notify_property_list_changed()

## Camera position offset at progress=1.0 (% of viewport size).
## X = horizontal, Y = vertical. E.g. Vector2(3, 0) = 3% rightward kick.
var position_offset_percent: Vector2 = Vector2(3.0, 0.0)

## Camera rotation offset at progress=1.0 (degrees, Z-axis only for 2D).
var rotation_degrees: float = 5.0

## Camera zoom offset at progress=1.0. Positive = zoom in, negative = zoom out.
## Applied uniformly on Camera2D.zoom both axes.
var zoom_offset: float = 0.2


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

	match channel:
		Channel.POSITION:
			props.append({"name": "position_offset_percent", "type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT})
		Channel.ROTATION:
			props.append({"name": "rotation_degrees", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "-180.0,180.0,0.1,or_less,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})
		Channel.ZOOM:
			props.append({"name": "zoom_offset", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "-5.0,5.0,0.01,or_less,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})

	props.append_array(_get_effect_base_properties())
	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"channel":                  channel = value;                  return true
		&"position_offset_percent":  position_offset_percent = value;  return true
		&"rotation_degrees":         rotation_degrees = value;         return true
		&"zoom_offset":              zoom_offset = value;              return true
	return super._set(property, value)


func _get(property: StringName) -> Variant:
	match property:
		&"channel":                  return channel
		&"position_offset_percent":  return position_offset_percent
		&"rotation_degrees":         return rotation_degrees
		&"zoom_offset":              return zoom_offset
	return super._get(property)


# =============================================================================
# INTERNAL STATE
# =============================================================================

## Delta-first contribution tracking -- what THIS effect has written to the utility.
var _my_pos:  Vector3 = Vector3.ZERO
var _my_rot:  Vector3 = Vector3.ZERO
var _my_zoom: float   = 0.0


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

func _apply_effect(progress: float, _target: Node) -> void:
	# Re-discover (or bootstrap) utility every frame -- handles camera switches.
	var util := _find_or_create_utility()
	if not is_instance_valid(util):
		return

	match channel:
		Channel.POSITION: _apply_position(util, progress)
		Channel.ROTATION: _apply_rotation(util, progress)
		Channel.ZOOM:     _apply_zoom(util, progress)


func _on_animate_out_complete(_target: Node) -> void:
	_remove_contribution()


func _restore_to_natural(_target: Node) -> void:
	_remove_contribution()


# =============================================================================
# CHANNEL APPLY
# =============================================================================

func _apply_position(util: CameraJuiceUtility, progress: float) -> void:
	var viewport_size: Vector2 = _host_node.get_viewport().get_visible_rect().size
	var px := Vector2(
		position_offset_percent.x * viewport_size.x / 100.0,
		position_offset_percent.y * viewport_size.y / 100.0
	)
	var desired := Vector3(px.x, px.y, 0.0) * progress
	var delta   := desired - _my_pos
	util.position_offset += delta
	_my_pos = desired


func _apply_rotation(util: CameraJuiceUtility, progress: float) -> void:
	var desired := Vector3(0.0, 0.0, deg_to_rad(rotation_degrees)) * progress
	var delta   := desired - _my_rot
	util.rotation_offset += delta
	_my_rot = desired


func _apply_zoom(util: CameraJuiceUtility, progress: float) -> void:
	var desired := zoom_offset * progress
	var delta   := desired - _my_zoom
	util.zoom_offset += delta
	_my_zoom = desired


# =============================================================================
# CONTRIBUTION CLEANUP
# =============================================================================

func _remove_contribution() -> void:
	var util := _find_or_create_utility()
	if is_instance_valid(util):
		util.position_offset -= _my_pos
		util.rotation_offset -= _my_rot
		util.zoom_offset     -= _my_zoom
	_my_pos  = Vector3.ZERO
	_my_rot  = Vector3.ZERO
	_my_zoom = 0.0


# =============================================================================
# UTILITY DISCOVERY + AUTO-BOOTSTRAP
# =============================================================================

## Returns the active Camera2D's CameraJuiceUtility, creating one if absent.
## Re-discovers every call -- handles mid-animation camera switches at zero cost.
## Returns null in editor (would dirty the scene) or if no Camera2D exists.
func _find_or_create_utility() -> CameraJuiceUtility:
	# Guard: never auto-create in editor -- add_child would dirty/save the scene.
	if Engine.is_editor_hint():
		return null

	if not is_instance_valid(_host_node):
		return null

	var vp := _host_node.get_viewport()
	if not vp:
		return null

	var cam := vp.get_camera_2d()
	if not cam:
		if debug_enabled:
			push_warning("[Camera2DJuiceEffect] No active Camera2D found in viewport")
		return null

	# Fast path -- utility already exists on this camera.
	for child in cam.get_children():
		if child is CameraJuiceUtility:
			return child

	# Auto-bootstrap -- camera is active but has no utility yet.
	return _bootstrap_utility_on(cam)


## Creates and attaches a CameraJuiceUtility to the given camera.
## Forces initialization immediately so the utility is ready within this tick.
func _bootstrap_utility_on(cam: Camera2D) -> CameraJuiceUtility:
	var util := CameraJuiceUtility.new()
	util.name = "CameraJuiceUtility"
	cam.add_child(util)
	# _ready() may not have fired yet within this physics tick -- force init now.
	util._initialize_camera()

	if debug_enabled:
		print("[Camera2DJuiceEffect] Auto-bootstrapped CameraJuiceUtility on '%s'" % cam.name)

	return util
