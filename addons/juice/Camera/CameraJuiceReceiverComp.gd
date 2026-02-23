extends Node
class_name CameraJuiceReceiverComp
## ============================================================================
## CAMERA JUICE RECEIVER COMPONENT
## ============================================================================
## Receives and applies juice offsets to its parent camera (2D or 3D).
## This component allows camera juice effects to work WITHOUT modifying
## the user's camera script - just attach this as a child of any camera.
##
## RESPONSIBILITIES:
## - Accumulate position, rotation, and zoom offsets from juice components
## - Clamp offsets to configured limits (prevent overboard stacking)
## - Apply offsets additively on top of camera's normal behavior
##
## HOW IT WORKS:
## 1. Camera's own script runs its follow/movement logic
## 2. This receiver runs in _physics_process() AFTER
## 3. Receiver calculates true base (subtracting previous offset)
## 4. Receiver applies new clamped offset on top
## Result: Camera follows + juice offsets layered seamlessly
##
## DOES NOT HANDLE:
## - Camera follow logic (user's responsibility)
## - Juice effect timing (juice components handle that)
## - Camera switching (one receiver per camera that needs effects)
##
## CONNECTIONS:
## - Camera3DJuiceComp: Writes to position_offset, rotation_offset, fov_offset, or zoom_offset
##   depending on its camera_target setting (POSITION, ROTATION, FOV, ZOOM)
## - Camera2DJuiceComp: Writes to position_offset, rotation_offset, or zoom_offset
## - Any future camera juice: Same pattern
##
## SETUP:
## 1. Add this component as child of your Camera3D or Camera2D
## 2. Configure max_position_offset and max_rotation_offset in inspector
## 3. Done - camera juice effects will now work additively
## ============================================================================

# =============================================================================
# CONFIGURATION
# =============================================================================

## 3D defaults (meters / degrees / FOV). Used to detect unconfigured receivers
## so we can auto-adjust for Camera2D (which uses pixels instead of meters).
const _3D_DEFAULT_MAX_POS := Vector3(10.0, 10.0, 5.0)
const _3D_DEFAULT_MAX_ZOOM := 30.0

## 2D defaults (pixels / degrees / zoom-scale). Applied automatically when
## parented to a Camera2D and the user hasn't overridden the 3D defaults.
const _2D_DEFAULT_MAX_POS := Vector3(500.0, 500.0, 0.0)
const _2D_DEFAULT_MAX_ZOOM := 2.0

@export_group("Offset Limits")

## Maximum position offset allowed (prevents stacking from going overboard).
## Camera3D: meters (X = left/right, Y = up/down, Z = forward/back).
## Camera2D: pixels (X = horizontal, Y = vertical, Z unused).
## Auto-adjusted for Camera2D if left at the 3D default.
@export var max_position_offset: Vector3 = _3D_DEFAULT_MAX_POS

## Maximum rotation offset in degrees.
## X = pitch, Y = yaw, Z = roll. Generous default for all camera types.
@export var max_rotation_offset_degrees: Vector3 = Vector3(45.0, 45.0, 45.0)

## Maximum zoom offset allowed.
## Camera3D: FOV offset in degrees (e.g., 30 = ±30° FOV change).
## Camera2D: Uniform zoom magnitude (e.g., 2.0 = ±2.0 zoom change).
## Auto-adjusted for Camera2D if left at the 3D default.
@export var max_zoom_offset: float = _3D_DEFAULT_MAX_ZOOM

@export_group("Debug")

## Enable debug output for offset values
@export var debug_enabled: bool = false

# =============================================================================
# PUBLIC STATE (Written by juice components)
# =============================================================================

## Current accumulated position offset from all juice effects.
## Juice components add/subtract their deltas to this value.
var position_offset: Vector3 = Vector3.ZERO

## Current accumulated rotation offset from all juice effects (radians).
## Juice components add/subtract their deltas to this value.
var rotation_offset: Vector3 = Vector3.ZERO

## Current accumulated zoom offset from all juice effects.
## For Camera3D: Added to Camera3D.fov (degrees).
## For Camera2D: Added to Camera2D.zoom as Vector2(zoom, zoom).
var zoom_offset: float = 0.0

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Parent camera reference (Camera2D or Camera3D)
var _camera: Node = null

## True if parent is Camera3D, false if Camera2D
var _is_3d: bool = true

## The offset we actually applied last frame.
## Used to calculate the true base position before our modification.
var _applied_position_offset: Vector3 = Vector3.ZERO
var _applied_rotation_offset: Vector3 = Vector3.ZERO
var _applied_zoom_offset: float = 0.0

## Whether we've successfully initialized
var _initialized: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_initialize_camera()
	
	if debug_enabled and _initialized:
		print("[%s] Ready. Parent: %s (%s)" % [
			name,
			_camera.name,
			"3D" if _is_3d else "2D"
		])


func _initialize_camera() -> void:
	## Finds and validates the parent camera.
	
	var parent = get_parent()
	
	if parent is Camera3D:
		_camera = parent
		_is_3d = true
		_initialized = true
	elif parent is Camera2D:
		_camera = parent
		_is_3d = false
		_initialized = true
		# Camera2D uses pixels for position and linear scale for zoom,
		# not meters and FOV degrees. Auto-adjust if still at 3D defaults.
		if max_position_offset == _3D_DEFAULT_MAX_POS:
			max_position_offset = _2D_DEFAULT_MAX_POS
		if max_zoom_offset == _3D_DEFAULT_MAX_ZOOM:
			max_zoom_offset = _2D_DEFAULT_MAX_ZOOM
	else:
		push_warning("[%s] Parent is not a camera (got %s). Must be child of Camera2D or Camera3D." % [
			name,
			parent.get_class() if parent else "null"
		])
		_initialized = false


func _physics_process(_delta: float) -> void:
	if not _initialized:
		return
	
	# Early exit if no juice active and nothing applied
	# This optimization prevents unnecessary work when idle
	var has_offset := position_offset != Vector3.ZERO or rotation_offset != Vector3.ZERO or zoom_offset != 0.0
	var has_applied := _applied_position_offset != Vector3.ZERO or _applied_rotation_offset != Vector3.ZERO or _applied_zoom_offset != 0.0
	
	if not has_offset and not has_applied:
		return
	
	# Apply offsets to camera
	if _is_3d:
		_apply_to_3d_camera()
	else:
		_apply_to_2d_camera()
	
	if debug_enabled and has_offset:
		print("[%s] Offset pos: %s, rot: %s, zoom: %.4f" % [
			name,
			position_offset,
			rotation_offset,
			zoom_offset
		])


func _apply_to_3d_camera() -> void:
	## Applies juice offsets to a Camera3D parent.
	
	var cam := _camera as Camera3D
	
	# Calculate the camera's true position (before our offset)
	# We subtract what we previously applied to find the base
	var true_base_position := cam.global_position - _applied_position_offset
	var true_base_rotation := cam.rotation - _applied_rotation_offset
	
	# Clamp accumulated offsets to configured limits
	var clamped_pos := position_offset.clamp(-max_position_offset, max_position_offset)
	var max_rot_rad := Vector3(
		deg_to_rad(max_rotation_offset_degrees.x),
		deg_to_rad(max_rotation_offset_degrees.y),
		deg_to_rad(max_rotation_offset_degrees.z)
	)
	var clamped_rot := rotation_offset.clamp(-max_rot_rad, max_rot_rad)
	var clamped_zoom := clampf(zoom_offset, -max_zoom_offset, max_zoom_offset)
	
	# Apply juice offsets on top of true base
	cam.global_position = true_base_position + clamped_pos
	cam.rotation = true_base_rotation + clamped_rot
	
	# FOV: subtract previous, add new
	cam.fov = cam.fov - _applied_zoom_offset + clamped_zoom
	
	# Track what we applied (for next frame's base calculation)
	_applied_position_offset = clamped_pos
	_applied_rotation_offset = clamped_rot
	_applied_zoom_offset = clamped_zoom


func _apply_to_2d_camera() -> void:
	## Applies juice offsets to a Camera2D parent.
	## For 2D, we use the camera's offset property for position,
	## and rotation property for rotation.
	
	var cam := _camera as Camera2D
	
	# For Camera2D, position offset goes to the offset property
	var pos_offset_2d := Vector2(position_offset.x, position_offset.y)
	var applied_pos_2d := Vector2(_applied_position_offset.x, _applied_position_offset.y)
	
	# Calculate true base
	var true_base_offset := cam.offset - applied_pos_2d
	var true_base_rotation := cam.rotation - _applied_rotation_offset.z
	
	# Clamp
	var max_pos_2d := Vector2(max_position_offset.x, max_position_offset.y)
	var clamped_pos := pos_offset_2d.clamp(-max_pos_2d, max_pos_2d)
	var max_rot_rad_z := deg_to_rad(max_rotation_offset_degrees.z)
	var clamped_rot := clampf(rotation_offset.z, -max_rot_rad_z, max_rot_rad_z)
	var clamped_zoom := clampf(zoom_offset, -max_zoom_offset, max_zoom_offset)
	
	# Apply
	cam.offset = true_base_offset + clamped_pos
	cam.rotation = true_base_rotation + clamped_rot
	
	# Zoom: subtract previous, add new (uniform on both axes)
	var zoom_vec := Vector2(clamped_zoom, clamped_zoom)
	var prev_zoom_vec := Vector2(_applied_zoom_offset, _applied_zoom_offset)
	cam.zoom = cam.zoom - prev_zoom_vec + zoom_vec
	
	# Track
	_applied_position_offset = Vector3(clamped_pos.x, clamped_pos.y, 0.0)
	_applied_rotation_offset = Vector3(0.0, 0.0, clamped_rot)
	_applied_zoom_offset = clamped_zoom

# =============================================================================
# PUBLIC API
# =============================================================================

func reset_offsets() -> void:
	## Instantly clears all juice offsets.
	## Call this for emergency reset (e.g., scene transition).
	
	# First, undo our applied offset
	if _initialized:
		if _is_3d:
			var cam := _camera as Camera3D
			cam.global_position -= _applied_position_offset
			cam.rotation -= _applied_rotation_offset
			cam.fov -= _applied_zoom_offset
		else:
			var cam := _camera as Camera2D
			cam.offset -= Vector2(_applied_position_offset.x, _applied_position_offset.y)
			cam.rotation -= _applied_rotation_offset.z
			cam.zoom -= Vector2(_applied_zoom_offset, _applied_zoom_offset)
	
	# Clear all state
	position_offset = Vector3.ZERO
	rotation_offset = Vector3.ZERO
	zoom_offset = 0.0
	_applied_position_offset = Vector3.ZERO
	_applied_rotation_offset = Vector3.ZERO
	_applied_zoom_offset = 0.0
	
	if debug_enabled:
		print("[%s] Offsets reset" % name)


func get_clamped_position_offset() -> Vector3:
	## Returns the current position offset after clamping.
	return position_offset.clamp(-max_position_offset, max_position_offset)


func get_clamped_rotation_offset() -> Vector3:
	## Returns the current rotation offset after clamping (in radians).
	var max_rot_rad := Vector3(
		deg_to_rad(max_rotation_offset_degrees.x),
		deg_to_rad(max_rotation_offset_degrees.y),
		deg_to_rad(max_rotation_offset_degrees.z)
	)
	return rotation_offset.clamp(-max_rot_rad, max_rot_rad)
