## Camera3DJuiceComp.gd
## ============================================================================
## WHAT: Composable, single-axis deterministic camera effect for Camera3D.
##       Animates position offset, rotation offset, or FOV zoom on the active
##       Camera3D via its CameraJuiceUtility. Each instance handles ONE
##       target axis — stack multiple for compound effects.
##
## WHY: Replaces the monolithic Camera3DJuiceComp (5-mode switcher) with
##      composable single-axis components. Each instance is simple, stackable,
##      and uses JuiceCompBase's animation system for deterministic curves.
##
## WRITE PATTERN: Delta-first. Each frame writes only the CHANGE in this comp's
##   contribution: receiver.property += (desired - _my_contribution). This
##   enables safe stacking with other camera juice effects.
##
## SYSTEM: Juicing System (addons/juice/) - Camera 3D Domain
##
## DOES NOT: Handle procedural effects like shake or sway (use Shake/Noise comps).
## DOES NOT: Handle Camera2D (use Camera2DJuiceComp).
## DOES NOT: Handle screen-space effects (use ScreenMotionJuiceComp).
##
## REQUIREMENTS:
## The active Camera3D must have a CameraJuiceUtility child.
## This comp auto-discovers it at animation start via viewport.get_camera_3d().
##
## PLACEMENT:
## Add as child of the entity that triggers the camera effect (enemy, button,
## explosion, etc). NOT on the camera itself.
## ============================================================================

@tool
@icon("res://addons/Juice_V1/Icons/JuiceBaseCamera3D.svg")
class_name Camera3DJuiceComp
extends JuiceCompBase

# =============================================================================
# CAMERA TARGET SELECTION
# =============================================================================

## Which camera property to animate via the receiver
enum CameraTarget {
	POSITION,  ## Offset camera position (kick, dolly, push)
	ROTATION,  ## Offset camera rotation (tilt, dutch angle, lean)
	ZOOM       ## Offset camera FOV (zoom punch, hold, breathe)
}

@export_group("Effect")

@export var camera_target: CameraTarget = CameraTarget.POSITION:
	set(value):
		camera_target = value
		notify_property_list_changed()

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — they are shown/hidden via _get_property_list()
# =============================================================================

# --- POSITION ---
## Camera position offset at progress=1.0.
## When use_local_space=true: X = right, Y = up, Z = backward (camera-relative).
## When use_local_space=false: world-space offset.
var position_offset: Vector3 = Vector3(0, 0, 0.5)

## If true, position_offset is in camera-local space and gets transformed
## by the camera's basis each frame. This means a kick of (0,0,-1) always
## pushes "forward" from the camera's perspective, regardless of where
## the camera is looking. Default true — most intuitive for directional kicks.
var use_local_space: bool = true

# --- ROTATION ---
## Camera rotation offset at progress=1.0 (degrees)
## X = pitch, Y = yaw, Z = roll
var rotation_offset_degrees: Vector3 = Vector3(0, 0, 5.0)

# --- ZOOM ---
## FOV offset at progress=1.0 (degrees). Positive = wider, negative = narrower.
var fov_offset: float = -10.0

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Discovered receiver on the active Camera3D
var _receiver: CameraJuiceUtility = null

## Delta-first contribution tracking.
## Each tracks what THIS comp has contributed to the receiver's property.
var _my_position_contribution: Vector3 = Vector3.ZERO
var _my_rotation_contribution: Vector3 = Vector3.ZERO
var _my_zoom_contribution: float = 0.0

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	match camera_target:
		CameraTarget.POSITION:
			props.append({
				"name": "position_offset",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})
			props.append({
				"name": "use_local_space",
				"type": TYPE_BOOL,
				"usage": PROPERTY_USAGE_DEFAULT,
			})

		CameraTarget.ROTATION:
			props.append({
				"name": "rotation_offset_degrees",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})

		CameraTarget.ZOOM:
			props.append({
				"name": "fov_offset",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"position_offset": position_offset = value; return true
		&"use_local_space": use_local_space = value; return true
		&"rotation_offset_degrees": rotation_offset_degrees = value; return true
		&"fov_offset": fov_offset = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"position_offset": return position_offset
		&"use_local_space": return use_local_space
		&"rotation_offset_degrees": return rotation_offset_degrees
		&"fov_offset": return fov_offset
	return null

# =============================================================================
# LIFECYCLE OVERRIDES
# =============================================================================

func _on_animate_start() -> void:
	_find_receiver()

	if debug_enabled:
		var target_name: String = CameraTarget.keys()[camera_target]
		var recv_name := str(_receiver.name) if _receiver else "NONE"
		print("[%s] Camera3D start (%s), receiver=%s" % [
			name, target_name, recv_name
		])


func _apply_effect(progress: float) -> void:
	if not is_instance_valid(_receiver):
		return

	match camera_target:
		CameraTarget.POSITION:
			_apply_position_effect(progress)
		CameraTarget.ROTATION:
			_apply_rotation_effect(progress)
		CameraTarget.ZOOM:
			_apply_zoom_effect(progress)


func _on_animate_out_complete() -> void:
	_remove_contribution()
	if debug_enabled:
		print("[%s] Camera3D complete (out), contribution cleared" % name)


func _on_animate_in_complete() -> void:
	# Do NOT clear contribution here — effect should hold at full strength
	# for PLAY_IN_ONLY and TOGGLE scenarios.
	if debug_enabled:
		print("[%s] Camera3D holding at peak (in complete)" % name)


func _exit_tree() -> void:
	_remove_contribution()


func _invalidate_base_cache() -> void:
	_remove_contribution()
	_receiver = null

# =============================================================================
# POSITION EFFECT
# =============================================================================

func _apply_position_effect(progress: float) -> void:
	var desired := position_offset * progress

	# When local space is enabled, transform the offset by the camera's basis
	# so the kick direction follows the camera's facing. E.g., (0,0,-1) always
	# pushes forward from the camera's perspective, regardless of world rotation.
	if use_local_space:
		var cam := _receiver.get_parent() as Camera3D
		if cam:
			desired = cam.global_transform.basis * desired

	var delta := desired - _my_position_contribution
	_receiver.position_offset += delta
	_my_position_contribution = desired

# =============================================================================
# ROTATION EFFECT
# =============================================================================

func _apply_rotation_effect(progress: float) -> void:
	var offset_rad := Vector3(
		deg_to_rad(rotation_offset_degrees.x),
		deg_to_rad(rotation_offset_degrees.y),
		deg_to_rad(rotation_offset_degrees.z)
	)
	var desired := offset_rad * progress
	var delta := desired - _my_rotation_contribution
	_receiver.rotation_offset += delta
	_my_rotation_contribution = desired

# =============================================================================
# ZOOM EFFECT
# =============================================================================

func _apply_zoom_effect(progress: float) -> void:
	var desired := fov_offset * progress
	var delta := desired - _my_zoom_contribution
	_receiver.zoom_offset += delta
	_my_zoom_contribution = desired

# =============================================================================
# CONTRIBUTION CLEANUP
# =============================================================================

## Remove our contribution from the receiver and reset tracking.
func _remove_contribution() -> void:
	if not is_instance_valid(_receiver):
		_my_position_contribution = Vector3.ZERO
		_my_rotation_contribution = Vector3.ZERO
		_my_zoom_contribution = 0.0
		return

	match camera_target:
		CameraTarget.POSITION:
			_receiver.position_offset -= _my_position_contribution
		CameraTarget.ROTATION:
			_receiver.rotation_offset -= _my_rotation_contribution
		CameraTarget.ZOOM:
			_receiver.zoom_offset -= _my_zoom_contribution

	_my_position_contribution = Vector3.ZERO
	_my_rotation_contribution = Vector3.ZERO
	_my_zoom_contribution = 0.0

# =============================================================================
# RECEIVER DISCOVERY
# =============================================================================

## Finds the active Camera3D and its CameraJuiceUtility.
## Type-safe discovery: searches children by `is` check, not by name.
func _find_receiver() -> void:
	if is_instance_valid(_receiver):
		return

	var viewport := get_viewport()
	if not viewport:
		return

	var cam3d := viewport.get_camera_3d()
	if not cam3d:
		if debug_enabled:
			push_warning("[%s] No active Camera3D found" % name)
		return

	for child in cam3d.get_children():
		if child is CameraJuiceUtility:
			_receiver = child
			return

	if debug_enabled:
		push_warning("[%s] No CameraJuiceUtility found on Camera3D '%s'" % [name, cam3d.name])
