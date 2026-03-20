## Camera2DJuiceComp.gd
## ============================================================================
## WHAT: Composable, single-axis deterministic camera effect for Camera2D.
##       Animates position offset, rotation offset, or zoom on the active
##       Camera2D via its CameraJuiceUtility. Each instance handles ONE
##       target axis — stack multiple for compound effects.
##
## WHY: Replaces the monolithic Camera2DJuiceComp (5-mode switcher) with
##      composable single-axis components. Each instance is simple, stackable,
##      and uses JuiceCompBase's animation system for deterministic curves.
##
## WRITE PATTERN: Delta-first. Each frame writes only the CHANGE in this comp's
##   contribution: receiver.property += (desired - _my_contribution). This
##   enables safe stacking with other camera juice effects.
##
## SYSTEM: Juicing System (addons/juice/) - Camera 2D Domain
##
## DOES NOT: Handle procedural effects like shake or sway (use Shake/Noise comps).
## DOES NOT: Handle Camera3D (use CameraTransform3DJuiceComp).
## DOES NOT: Handle screen-space effects (use ScreenTransformJuiceComp).
##
## REQUIREMENTS:
## The active Camera2D must have a CameraJuiceUtility child.
## This comp auto-discovers it at animation start via viewport.get_camera_2d().
##
## PLACEMENT:
## Add as child of the entity that triggers the camera effect (enemy, button,
## explosion, etc). NOT on the camera itself.
## ============================================================================

@tool
class_name Camera2DJuiceComp
extends JuiceCompBase

# =============================================================================
# CAMERA TARGET SELECTION
# =============================================================================

## Which camera property to animate via the receiver
enum CameraTarget {
	POSITION,  ## Offset camera position (kick, dolly, push)
	ROTATION,  ## Offset camera rotation (tilt, dutch angle)
	ZOOM       ## Offset camera zoom (zoom punch, hold, breathe)
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
## Camera position offset at progress=1.0 (% of viewport size).
## E.g. Vector2(0, -5) = move camera up by 5% of viewport height.
## Converted to pixels at runtime — resolution-independent.
var position_offset_percent: Vector2 = Vector2(3, 0)

# --- ROTATION ---
## Camera rotation offset at progress=1.0 (degrees, Z-axis only for 2D)
var rotation_offset_degrees: float = 5.0

# --- ZOOM ---
## Zoom offset at progress=1.0. Positive = zoom in, negative = zoom out.
## Applied uniformly to Camera2D.zoom (both axes).
var zoom_offset: float = 0.2

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Discovered receiver on the active Camera2D
var _receiver: CameraJuiceUtility = null

## Delta-first contribution tracking.
## Position stored as Vector3 (X/Y used, Z=0) to match receiver's interface.
## Rotation stored as Vector3 (Z used) to match receiver's interface.
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
				"name": "position_offset_percent",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})

		CameraTarget.ROTATION:
			props.append({
				"name": "rotation_offset_degrees",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})

		CameraTarget.ZOOM:
			props.append({
				"name": "zoom_offset",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"position_offset_percent": position_offset_percent = value; return true
		&"rotation_offset_degrees": rotation_offset_degrees = value; return true
		&"zoom_offset": zoom_offset = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"position_offset_percent": return position_offset_percent
		&"rotation_offset_degrees": return rotation_offset_degrees
		&"zoom_offset": return zoom_offset
	return null

# =============================================================================
# LIFECYCLE OVERRIDES
# =============================================================================

func _on_animate_start() -> void:
	_find_receiver()

	if debug_enabled:
		var target_name: String = CameraTarget.keys()[camera_target]
		var recv_name := str(_receiver.name) if _receiver else "NONE"
		print("[%s] Camera2D start (%s), receiver=%s" % [
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
		print("[%s] Camera2D complete (out), contribution cleared" % name)


func _on_animate_in_complete() -> void:
	# Do NOT clear contribution here — effect should hold at full strength
	# for PLAY_IN_ONLY and TOGGLE scenarios.
	if debug_enabled:
		print("[%s] Camera2D holding at peak (in complete)" % name)


func _exit_tree() -> void:
	_remove_contribution()


func _invalidate_base_cache() -> void:
	_remove_contribution()
	_receiver = null

# =============================================================================
# POSITION EFFECT
# =============================================================================

func _apply_position_effect(progress: float) -> void:
	# Convert viewport percentage to pixels, then map to receiver's Vector3
	var viewport_size := get_viewport().get_visible_rect().size
	var pixel_offset := Vector2(
		position_offset_percent.x * viewport_size.x / 100.0,
		position_offset_percent.y * viewport_size.y / 100.0
	)
	var desired := Vector3(pixel_offset.x, pixel_offset.y, 0.0) * progress
	var delta := desired - _my_position_contribution
	_receiver.position_offset += delta
	_my_position_contribution = desired

# =============================================================================
# ROTATION EFFECT
# =============================================================================

func _apply_rotation_effect(progress: float) -> void:
	# Map single-axis rotation to receiver's Vector3 (Z-axis only for 2D)
	var desired := Vector3(0, 0, deg_to_rad(rotation_offset_degrees)) * progress
	var delta := desired - _my_rotation_contribution
	_receiver.rotation_offset += delta
	_my_rotation_contribution = desired

# =============================================================================
# ZOOM EFFECT
# =============================================================================

func _apply_zoom_effect(progress: float) -> void:
	var desired := zoom_offset * progress
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

## Finds the active Camera2D and its CameraJuiceUtility.
## Type-safe discovery: searches children by `is` check, not by name.
func _find_receiver() -> void:
	if is_instance_valid(_receiver):
		return

	var viewport := get_viewport()
	if not viewport:
		return

	var cam2d := viewport.get_camera_2d()
	if not cam2d:
		if debug_enabled:
			push_warning("[%s] No active Camera2D found" % name)
		return

	for child in cam2d.get_children():
		if child is CameraJuiceUtility:
			_receiver = child
			return

	if debug_enabled:
		push_warning("[%s] No CameraJuiceUtility found on Camera2D '%s'" % [name, cam2d.name])
