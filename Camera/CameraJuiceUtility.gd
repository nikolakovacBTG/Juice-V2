## Accumulates and applies Juice camera offsets to a parent Camera2D or Camera3D.
##
## Place this as a direct child of your camera. Camera juice effects placed on
## any entity in the scene will auto-discover this utility via the active camera.

# ============================================================================
# WHAT: Receiver node that applies accumulated juice offsets to its parent camera.
# WHY:  Camera juice effects must not modify the camera directly — they would
#       fight the camera's own follow/movement logic. This utility layers offsets
#       additively on top of whatever the camera script is doing, then removes
#       them next frame before the camera script runs again.
# SYSTEM: Juice System (addons/Juice_V1/Camera/)
# DOES NOT: Run any camera follow/movement logic — that is the user's script.
# DOES NOT: Discover which camera to use — it IS the camera (via get_parent()).
# DOES NOT: Limit which juice effects can write to it — effects self-register.
#
# SETUP: Camera juice effects auto-add this to the active camera on first use.
#        Optionally place manually as a camera child to customise offset limits.
# ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBaseCamera.svg")
class_name CameraJuiceUtility
extends Node


# =============================================================================
# CONFIGURATION
# =============================================================================

## 3D defaults (meters / degrees / FOV). Detect unconfigured → auto-adjust for 2D.
const _3D_DEFAULT_MAX_POS  := Vector3(10.0, 10.0, 5.0)
const _3D_DEFAULT_MAX_ZOOM := 30.0

## 2D defaults (pixels / degrees / zoom-scale). Applied when parent is Camera2D.
const _2D_DEFAULT_MAX_POS  := Vector3(500.0, 500.0, 0.0)
const _2D_DEFAULT_MAX_ZOOM := 2.0

@export_group("Offset Limits")

## Max position offset. Camera3D: meters (X/Y/Z). Camera2D: pixels (X/Y, Z unused).
## Auto-adjusted for Camera2D if left at the 3D default value.
@export var max_position_offset: Vector3 = _3D_DEFAULT_MAX_POS

## Max rotation offset in degrees (X=pitch, Y=yaw, Z=roll / Z=2D tilt).
@export var max_rotation_offset_degrees: Vector3 = Vector3(45.0, 45.0, 45.0)

## Max zoom offset. Camera3D: FOV degrees (±30). Camera2D: linear scale (±2.0).
## Auto-adjusted for Camera2D if left at the 3D default value.
@export var max_zoom_offset: float = _3D_DEFAULT_MAX_ZOOM

@export_group("Debug")
@export var debug_enabled: bool = false


# =============================================================================
# PUBLIC OFFSETS (written by Camera juice effects each frame)
# =============================================================================

## Accumulated position offset from all active juice effects.
var position_offset: Vector3 = Vector3.ZERO

## Accumulated rotation offset from all active juice effects (radians).
var rotation_offset: Vector3 = Vector3.ZERO

## Accumulated zoom offset from all active juice effects.
## Camera3D: added to fov (degrees).  Camera2D: added to zoom as Vector2(z, z).
var zoom_offset: float = 0.0


# =============================================================================
# INTERNAL STATE
# =============================================================================

## Parent camera reference — Camera2D or Camera3D.
var _camera: Node = null

## True when parent is Camera3D.
var _is_3d: bool = true

## Offsets actually applied last frame (for undo before next apply).
var _applied_position_offset: Vector3 = Vector3.ZERO
var _applied_rotation_offset: Vector3 = Vector3.ZERO
var _applied_zoom_offset:     float  = 0.0

var _initialized: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_initialize_camera()
	# Register to group so editor tooling can discover CameraJuiceUtility nodes.
	add_to_group("juice_camera", true)

	if debug_enabled and _initialized:
		print("[%s] Ready on %s (%s)" % [name, _camera.name, "3D" if _is_3d else "2D"])


func _initialize_camera() -> void:
	if _initialized:
		return  # Idempotent — safe to call from bootstrap before _ready() fires.
	var parent := get_parent()

	if parent is Camera3D:
		_camera      = parent
		_is_3d       = true
		_initialized = true

	elif parent is Camera2D:
		_camera      = parent
		_is_3d       = false
		_initialized = true
		# Camera2D works in pixels + linear zoom — adjust defaults if still 3D values.
		if max_position_offset == _3D_DEFAULT_MAX_POS:
			max_position_offset = _2D_DEFAULT_MAX_POS
		if max_zoom_offset == _3D_DEFAULT_MAX_ZOOM:
			max_zoom_offset = _2D_DEFAULT_MAX_ZOOM

	else:
		push_warning("[%s] Parent is not a Camera2D or Camera3D (got %s). Must be a direct camera child." % [
			name,
			parent.get_class() if parent else "null"
		])
		_initialized = false


func _physics_process(_delta: float) -> void:
	if not _initialized:
		return

	# Skip work when idle — no offsets pending and nothing was applied.
	var has_offset   := position_offset != Vector3.ZERO or rotation_offset != Vector3.ZERO or zoom_offset != 0.0
	var has_applied  := _applied_position_offset != Vector3.ZERO or _applied_rotation_offset != Vector3.ZERO or _applied_zoom_offset != 0.0

	if not has_offset and not has_applied:
		return

	if _is_3d:
		_apply_to_3d()
	else:
		_apply_to_2d()

	if debug_enabled and has_offset:
		print("[%s] pos=%s rot=%s zoom=%.4f" % [name, position_offset, rotation_offset, zoom_offset])


# =============================================================================
# APPLY
# =============================================================================

func _apply_to_3d() -> void:
	var cam := _camera as Camera3D

	# True base = camera's written value minus what WE applied last frame.
	var true_pos := cam.global_position - _applied_position_offset
	var true_rot := cam.rotation - _applied_rotation_offset

	# Clamp all contributions to configured limits.
	var clamped_pos  := position_offset.clamp(-max_position_offset, max_position_offset)
	var max_rot_rad  := Vector3(
		deg_to_rad(max_rotation_offset_degrees.x),
		deg_to_rad(max_rotation_offset_degrees.y),
		deg_to_rad(max_rotation_offset_degrees.z)
	)
	var clamped_rot  := rotation_offset.clamp(-max_rot_rad, max_rot_rad)
	var clamped_zoom := clampf(zoom_offset, -max_zoom_offset, max_zoom_offset)

	# Apply: true base + clamped offset.
	cam.global_position = true_pos + clamped_pos
	cam.rotation        = true_rot + clamped_rot
	cam.fov             = cam.fov - _applied_zoom_offset + clamped_zoom

	_applied_position_offset = clamped_pos
	_applied_rotation_offset = clamped_rot
	_applied_zoom_offset     = clamped_zoom


func _apply_to_2d() -> void:
	var cam := _camera as Camera2D

	# Camera2D: position goes to cam.offset, rotation to cam.rotation (Z only).
	var pos_2d         := Vector2(position_offset.x, position_offset.y)
	var applied_pos_2d := Vector2(_applied_position_offset.x, _applied_position_offset.y)

	var true_offset   := cam.offset - applied_pos_2d
	var true_rotation := cam.rotation - _applied_rotation_offset.z

	var max_pos_2d    := Vector2(max_position_offset.x, max_position_offset.y)
	var clamped_pos   := pos_2d.clamp(-max_pos_2d, max_pos_2d)
	var max_rot_z     := deg_to_rad(max_rotation_offset_degrees.z)
	var clamped_rot   := clampf(rotation_offset.z, -max_rot_z, max_rot_z)
	var clamped_zoom  := clampf(zoom_offset, -max_zoom_offset, max_zoom_offset)

	cam.offset   = true_offset + clamped_pos
	cam.rotation = true_rotation + clamped_rot

	# Zoom is a Vector2 on Camera2D — apply uniformly on both axes.
	var zoom_vec      := Vector2(clamped_zoom, clamped_zoom)
	var prev_zoom_vec := Vector2(_applied_zoom_offset, _applied_zoom_offset)
	cam.zoom = cam.zoom - prev_zoom_vec + zoom_vec

	_applied_position_offset = Vector3(clamped_pos.x, clamped_pos.y, 0.0)
	_applied_rotation_offset = Vector3(0.0, 0.0, clamped_rot)
	_applied_zoom_offset     = clamped_zoom


# =============================================================================
# PUBLIC API
# =============================================================================

## Instantly clears all juice offsets and restores the camera.
## Call on scene transitions or emergency resets.
func reset_offsets() -> void:
	if _initialized:
		if _is_3d:
			var cam := _camera as Camera3D
			cam.global_position -= _applied_position_offset
			cam.rotation        -= _applied_rotation_offset
			cam.fov             -= _applied_zoom_offset
		else:
			var cam := _camera as Camera2D
			cam.offset   -= Vector2(_applied_position_offset.x, _applied_position_offset.y)
			cam.rotation -= _applied_rotation_offset.z
			cam.zoom     -= Vector2(_applied_zoom_offset, _applied_zoom_offset)

	position_offset          = Vector3.ZERO
	rotation_offset          = Vector3.ZERO
	zoom_offset              = 0.0
	_applied_position_offset = Vector3.ZERO
	_applied_rotation_offset = Vector3.ZERO
	_applied_zoom_offset     = 0.0

	if debug_enabled:
		print("[%s] Offsets reset" % name)
