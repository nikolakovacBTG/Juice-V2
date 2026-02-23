## SoftTrigger3DJuiceUtility.gd
## ============================================================================
## WHAT: Proximity-driven continuous progress driver for the 3D domain.
##       Extends Area3D to detect mouse/body entry, then calculates a 0–1
##       progress value based on how deep inside the collision shape the
##       tracked entity is. Drives sibling JuiceCompBase nodes each frame
##       via set_external_progress().
##
## WHY: Enables Balatro-style hover effects where juice intensity is proportional
##      to spatial proximity, not just binary enter/exit. The spatial falloff
##      IS the easing — no timing system needed.
##
## SYSTEM: Juicing System (addons/juice/) - 3D Domain
##
## DOES NOT:
## - Apply any visual effect itself (it's a sensor/driver, not an effect)
## - Handle directional tilt (see future TiltTowardCursorComp)
## - Work with 2D/Control scenes (see SoftTrigger2DJuiceComp / Control variant)
##
## CONNECTIONS:
## - Sibling JuiceCompBase nodes: discovered via type-safe `is` traversal,
##   driven each frame via set_external_progress()
## - CollisionShape3D child: required for detection zone. Auto-created as
##   @tool feature if auto_create_shape is true and none exists.
##
## MOUSE TRACKING (3D):
## Uses the collision point from Area3D._input_event(). Because the hit
## is always ON the shape surface (never inside), the calculation uses
## surface-projection instead of volumetric distance:
## - SphereShape3D: dot product of surface normal vs view direction
##   (1 at visible center, 0 at visible edge)
## - BoxShape3D: project hit onto face plane, use 2D rectangular falloff
##   on the two parallel axes (ignore the perpendicular/surface axis)
## BODY mode uses volumetric distance (the body IS inside the volume).
##
## USAGE:
## 1. Add as sibling of a visual Node3D (MeshInstance3D, etc.)
## 2. Add or auto-create a CollisionShape3D child to define the detection zone
## 3. Add JuiceCompBase siblings — they'll be driven automatically
## 4. Set falloff_zone to control the gradient zone width
## ============================================================================

@tool
class_name SoftTrigger3DJuiceUtility
extends Area3D


# =============================================================================
# SIGNALS
# =============================================================================

## Emitted each frame while tracked entity is inside, with the current 0–1 progress.
signal progress_changed(value: float)

## Emitted when tracked entity enters the detection zone.
signal proximity_entered

## Emitted when tracked entity exits the detection zone.
signal proximity_exited


# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Detection")

## What to track for proximity calculation.
## MOUSE: track cursor via collision point from _input_event (Balatro-style hover).
## BODY: track physics body position (player walk-near).
enum TrackSource { MOUSE, BODY }

@export var track_source: TrackSource = TrackSource.MOUSE

## Normalized fraction of the detection zone used as the falloff gradient (0.0–1.0).
## 0.0 = no gradient (instant full progress on entry).
## 1.0 = entire zone is gradient (progress reaches 1.0 only at the exact center).
## 0.3 = outer 30% is gradient, inner 70% is full progress.
@export_range(0.0, 1.0) var falloff_zone: float = 0.3

## Optional non-linear falloff curve. Applied to the raw linear progress.
@export var falloff_curve: Curve

@export_group("Shape Auto-Create")

## If true and no CollisionShape3D child exists, auto-create one in editor.
@export var auto_create_shape: bool = true

## Size for auto-created BoxShape3D.
@export var detection_size: Vector3 = Vector3(2, 2, 2):
	set(value):
		detection_size = value
		_update_auto_shape_size()

@export_group("Debug")

@export var debug_enabled: bool = false


# =============================================================================
# PUBLIC STATE
# =============================================================================

## Current proximity progress (0.0 = at border or outside, 1.0 = deep inside).
var progress: float = 0.0


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _is_inside: bool = false
var _tracked_body: Node3D = null

## Last known collision point from _input_event (world space).
## Updated each time the mouse moves over this Area3D.
var _last_hit_point: Vector3 = Vector3.ZERO
var _last_hit_normal: Vector3 = Vector3.ZERO
var _last_camera: Camera3D = null
var _has_hit_point: bool = false

var _juice_siblings: Array[JuiceCompBase] = []
var _juice_siblings_dirty: bool = true


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Enable ray picking so Godot's input system detects mouse on this Area3D
	input_ray_pickable = true

	if Engine.is_editor_hint():
		_ensure_collision_shape()
		set_process(false)
		return

	_ensure_collision_shape()

	# Connect signals based on track source
	if track_source == TrackSource.MOUSE:
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
	else:
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

	set_process(false)

	# Re-discover siblings when tree changes
	if get_parent():
		get_parent().child_order_changed.connect(_mark_siblings_dirty)

	if debug_enabled:
		print("[%s] SoftTrigger3D ready. Track: %s" % [name, TrackSource.keys()[track_source]])


func _process(_delta: float) -> void:
	if not _is_inside:
		return

	# Get tracked position in local coordinates
	var local_pos: Vector3
	if track_source == TrackSource.MOUSE:
		if not _has_hit_point:
			return
		local_pos = to_local(_last_hit_point)
	elif _tracked_body != null and is_instance_valid(_tracked_body):
		local_pos = to_local(_tracked_body.global_position)
	else:
		return

	# Calculate progress — mouse mode uses surface-projection (hit is ON
	# the surface), body mode uses volumetric distance (body is INSIDE)
	var new_progress: float
	if track_source == TrackSource.MOUSE:
		new_progress = _calculate_mouse_progress(local_pos)
	else:
		new_progress = _calculate_shape_progress(local_pos)

	# Apply optional falloff curve
	if falloff_curve != null and new_progress > 0.0 and new_progress < 1.0:
		new_progress = falloff_curve.sample(new_progress)

	progress = new_progress
	progress_changed.emit(progress)

	# Drive all discovered juice siblings
	_ensure_juice_siblings()
	for juice in _juice_siblings:
		if is_instance_valid(juice):
			juice.set_external_progress(progress)


## Area3D _input_event provides the 3D collision point where the mouse ray
## hits the shape surface. We capture this each frame for distance calculation.
func _input_event(camera: Node3D, event: InputEvent, hit_position: Vector3, hit_normal: Vector3, _shape_idx: int) -> void:
	if track_source != TrackSource.MOUSE:
		return

	# Update hit point, surface normal, and camera on any mouse motion
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_last_hit_point = hit_position
		_last_hit_normal = hit_normal
		_last_camera = camera as Camera3D
		_has_hit_point = true


# =============================================================================
# CALLBACKS
# =============================================================================

func _on_mouse_entered() -> void:
	_is_inside = true
	_has_hit_point = false
	set_process(true)
	proximity_entered.emit()
	if debug_enabled:
		print("[%s] Mouse entered" % name)


func _on_mouse_exited() -> void:
	_has_hit_point = false
	_last_hit_normal = Vector3.ZERO
	_last_camera = null
	_release_all()
	if debug_enabled:
		print("[%s] Mouse exited" % name)


func _on_body_entered(body: Node3D) -> void:
	if _tracked_body == null:
		_tracked_body = body
		_is_inside = true
		set_process(true)
		proximity_entered.emit()
		if debug_enabled:
			print("[%s] Body entered: %s" % [name, body.name])


func _on_body_exited(body: Node3D) -> void:
	if body == _tracked_body:
		_tracked_body = null
		_release_all()
		if debug_enabled:
			print("[%s] Body exited: %s" % [name, body.name])


func _release_all() -> void:
	_is_inside = false
	set_process(false)
	progress = 0.0
	progress_changed.emit(0.0)

	_ensure_juice_siblings()
	for juice in _juice_siblings:
		if is_instance_valid(juice):
			juice.set_external_progress(0.0)
			juice.set_external_progress(-1.0)

	proximity_exited.emit()


# =============================================================================
# DISTANCE CALCULATION
# =============================================================================

## Calculate 0–1 progress for MOUSE mode. Because _input_event hit position is
## always ON the shape surface, we use surface-projection: for sphere, the angle
## between the surface normal and view direction; for box, the 2D position on
## the hit face. This gives us "how centered is the hit" rather than "how deep
## inside the volume."
func _calculate_mouse_progress(local_pos: Vector3) -> float:
	var shape := _get_collision_shape()
	if shape == null:
		return 0.0

	if shape is SphereShape3D:
		return _progress_sphere_view_angle()
	elif shape is BoxShape3D:
		return _progress_box_face(local_pos, (shape as BoxShape3D).size)
	else:
		if debug_enabled:
			push_warning("[%s] Unsupported shape type '%s' for mouse mode" % [name, shape.get_class()])
		return 0.0


## Sphere progress for mouse mode: uses the dot product between the surface
## normal and the view direction to determine "centrality" on the visible face.
## At the visible center: normal aligns with view → dot ≈ 1 → progress = 1
## At the visible edge: normal perpendicular to view → dot ≈ 0 → progress = 0
func _progress_sphere_view_angle() -> float:
	if _last_camera == null or not is_instance_valid(_last_camera):
		return 0.0

	# View direction: from camera toward the hit point
	var view_dir := (_last_hit_point - _last_camera.global_position).normalized()

	# Dot product: 1.0 at visible center, 0.0 at visible edge
	var centrality := absf(_last_hit_normal.dot(-view_dir))

	# Convert to screen-space edge fraction via sin(acos(centrality)).
	# The raw dot product (cosine) is non-linear with visual distance —
	# 80%+ of the visible sphere has dot > 0.5, compressing the gradient
	# into a pixel-thin sliver at the edge. Using sqrt(1 - dot²) maps to
	# the projected 2D distance from center, giving perceptually linear falloff.
	var edge_fraction := sqrt(maxf(1.0 - centrality * centrality, 0.0))

	if falloff_zone <= 0.0:
		return 1.0  # No gradient — entire shape is full progress

	# Inner boundary: the fraction of the projected radius that's full progress
	var inner_boundary := 1.0 - falloff_zone

	if edge_fraction <= inner_boundary:
		return 1.0  # Inside the inner zone

	# Gradient zone: linear ramp from 1 (inner boundary) to 0 (edge)
	return 1.0 - clampf((edge_fraction - inner_boundary) / falloff_zone, 0.0, 1.0)


## Box progress for mouse mode: determines which face was hit from the local
## hit position, then calculates 2D rectangular falloff on that face's plane.
## This avoids the perpendicular axis (which is always at max distance on
## the surface).
func _progress_box_face(local_pos: Vector3, box_size: Vector3) -> float:
	var half := box_size * 0.5
	if half.x <= 0.0 or half.y <= 0.0 or half.z <= 0.0:
		return 0.0

	# Determine hit face: the axis where |local_pos| / half is largest
	var ratio_x := absf(local_pos.x) / half.x
	var ratio_y := absf(local_pos.y) / half.y
	var ratio_z := absf(local_pos.z) / half.z

	# Project onto the hit face plane (use the two NON-hit axes)
	var pos_2d: Vector2
	var half_2d: Vector2

	if ratio_x >= ratio_y and ratio_x >= ratio_z:
		# X face — use Y and Z for 2D falloff
		pos_2d = Vector2(local_pos.y, local_pos.z)
		half_2d = Vector2(half.y, half.z)
	elif ratio_y >= ratio_z:
		# Y face — use X and Z for 2D falloff
		pos_2d = Vector2(local_pos.x, local_pos.z)
		half_2d = Vector2(half.x, half.z)
	else:
		# Z face — use X and Y for 2D falloff
		pos_2d = Vector2(local_pos.x, local_pos.y)
		half_2d = Vector2(half.x, half.y)

	return _progress_rect_2d(pos_2d, half_2d)


## 2D rectangular falloff — shared by box face projection.
func _progress_rect_2d(local_2d: Vector2, half_size: Vector2) -> float:
	if half_size.x <= 0.0 or half_size.y <= 0.0:
		return 0.0

	var dx := absf(local_2d.x)
	var dy := absf(local_2d.y)

	var falloff_x := half_size.x * falloff_zone
	var falloff_y := half_size.y * falloff_zone
	var inner_x := half_size.x - falloff_x
	var inner_y := half_size.y - falloff_y

	if dx <= inner_x and dy <= inner_y:
		return 1.0

	var prog_x := 1.0
	if falloff_x > 0.0 and dx > inner_x:
		prog_x = 1.0 - clampf((dx - inner_x) / falloff_x, 0.0, 1.0)

	var prog_y := 1.0
	if falloff_y > 0.0 and dy > inner_y:
		prog_y = 1.0 - clampf((dy - inner_y) / falloff_y, 0.0, 1.0)

	return minf(prog_x, prog_y)


## Calculate 0–1 progress from a local-space point inside the collision shape.
## Used for BODY mode where the tracked entity is truly inside the volume.
## Supports BoxShape3D and SphereShape3D. Falls back to sphere for others.
func _calculate_shape_progress(local_pos: Vector3) -> float:
	var shape := _get_collision_shape()
	if shape == null:
		return 0.0

	if shape is BoxShape3D:
		return _progress_box(local_pos, (shape as BoxShape3D).size)
	elif shape is SphereShape3D:
		return _progress_sphere(local_pos, (shape as SphereShape3D).radius)
	else:
		if debug_enabled:
			push_warning("[%s] Unsupported shape type '%s', using sphere fallback" % [name, shape.get_class()])
		return _progress_sphere(local_pos, 1.0)


## Progress for BoxShape3D — 3-axis rectangular falloff.
func _progress_box(local_pos: Vector3, box_size: Vector3) -> float:
	if box_size.x <= 0.0 or box_size.y <= 0.0 or box_size.z <= 0.0:
		return 0.0

	var half := box_size * 0.5
	var dx := absf(local_pos.x)
	var dy := absf(local_pos.y)
	var dz := absf(local_pos.z)

	var falloff_x := half.x * falloff_zone
	var falloff_y := half.y * falloff_zone
	var falloff_z := half.z * falloff_zone
	var inner_x := half.x - falloff_x
	var inner_y := half.y - falloff_y
	var inner_z := half.z - falloff_z

	if dx <= inner_x and dy <= inner_y and dz <= inner_z:
		return 1.0

	var prog_x := 1.0
	if falloff_x > 0.0 and dx > inner_x:
		prog_x = 1.0 - clampf((dx - inner_x) / falloff_x, 0.0, 1.0)

	var prog_y := 1.0
	if falloff_y > 0.0 and dy > inner_y:
		prog_y = 1.0 - clampf((dy - inner_y) / falloff_y, 0.0, 1.0)

	var prog_z := 1.0
	if falloff_z > 0.0 and dz > inner_z:
		prog_z = 1.0 - clampf((dz - inner_z) / falloff_z, 0.0, 1.0)

	return minf(prog_x, minf(prog_y, prog_z))


## Progress for SphereShape3D — radial falloff from border to center.
func _progress_sphere(local_pos: Vector3, radius: float) -> float:
	if radius <= 0.0:
		return 0.0

	var dist := local_pos.length()
	var inner_radius := radius * (1.0 - falloff_zone)

	if dist <= inner_radius:
		return 1.0

	var falloff_dist := radius * falloff_zone
	if falloff_dist <= 0.0:
		return 1.0

	return 1.0 - clampf((dist - inner_radius) / falloff_dist, 0.0, 1.0)


# =============================================================================
# SHAPE AUTO-CREATION (@tool)
# =============================================================================

func _ensure_collision_shape() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			return

	if not auto_create_shape:
		if not Engine.is_editor_hint():
			push_warning("[%s] No CollisionShape3D child. Detection will not work." % name)
		return

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box_shape := BoxShape3D.new()
	box_shape.size = detection_size
	col.shape = box_shape
	add_child(col)

	if Engine.is_editor_hint():
		var scene_root := get_tree().edited_scene_root if get_tree() else null
		if scene_root:
			col.owner = scene_root

	if debug_enabled:
		print("[%s] Auto-created CollisionShape3D with size %s" % [name, detection_size])


func _update_auto_shape_size() -> void:
	if not Engine.is_editor_hint():
		return
	for child in get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D:
			(child.shape as BoxShape3D).size = detection_size
			break


# =============================================================================
# SIBLING DISCOVERY
# =============================================================================

func _ensure_juice_siblings() -> void:
	if not _juice_siblings_dirty:
		return

	_juice_siblings.clear()
	var parent := get_parent()
	if parent == null:
		return

	for sibling in parent.get_children():
		if sibling is JuiceCompBase and sibling != self:
			_juice_siblings.append(sibling as JuiceCompBase)

	_juice_siblings_dirty = false

	if debug_enabled:
		print("[%s] Discovered %d juice siblings" % [name, _juice_siblings.size()])


func _mark_siblings_dirty() -> void:
	_juice_siblings_dirty = true


# =============================================================================
# HELPERS
# =============================================================================

func _get_collision_shape() -> Shape3D:
	for child in get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape != null:
			return (child as CollisionShape3D).shape
	return null


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	var has_shape := false
	for child in get_children():
		if child is CollisionShape3D:
			has_shape = true
			break

	if not has_shape and not auto_create_shape:
		warnings.append("No CollisionShape3D child found. Add one or enable auto_create_shape.")

	if get_parent():
		var has_juice := false
		for sibling in get_parent().get_children():
			if sibling is JuiceCompBase and sibling != self:
				has_juice = true
				break
		if not has_juice:
			warnings.append("No JuiceCompBase siblings found to drive.")

	return warnings
