## Proximity-driven continuous progress driver for the 2D domain.
##
## Extends Area2D to detect mouse/body/area entry, then calculates a 0–1 progress value
## based on how deep inside the collision shape the tracked entity is.
## Drives sibling JuiceBase nodes each frame via set_external_progress().
## Multiple detection modes can be active simultaneously (e.g. bodies + areas).

# ============================================================================
# WHAT: Proximity-driven continuous progress driver for the 2D domain.
# WHY: Enables Balatro-style hover effects where juice intensity is proportional
#      to spatial proximity, not just binary enter/exit. The spatial falloff
#      IS the easing — no timing system needed.
# SYSTEM: Juice System (addons/Juice_V1/) - 2D Domain
#
# DOES NOT:
# - Apply any visual effect itself (it's a sensor/driver, not an effect)
# - Handle directional tilt (see future TiltTowardCursorComp)
# - Work with 3D scenes (see SoftTrigger3DJuiceComp)
#
# CONNECTIONS:
# - Sibling JuiceBase nodes: discovered via type-safe `is` traversal,
#   driven each frame via set_external_progress()
# - CollisionShape2D child: required for detection zone. Auto-created as
#   @tool feature if auto_create_shape is true and none exists.
#
# USAGE:
# 1. Add as sibling of a visual Node2D (Sprite2D, etc.)
# 2. Add or auto-create a CollisionShape2D child to define the detection zone
# 3. Add JuiceBase siblings — they'll be driven automatically
# 4. Set falloff_zone to control the gradient zone width
# ====================================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceUtilityArea2D.svg")
class_name SoftTrigger2DJuiceUtility
extends Area2D


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

## Track mouse cursor position for proximity calculation (Balatro-style hover).
@export var detect_mouse: bool = false

## Track PhysicsBody2D nodes (CharacterBody2D, RigidBody2D, etc.) entering the zone.
@export var detect_bodies: bool = true

## Track Area2D nodes entering the zone.
## Enable when the tracked entity carries an Area2D (not just a physics body).
@export var detect_areas: bool = false

## Normalized fraction of the detection zone used as the falloff gradient (0.0–1.0).
## 0.0 = no gradient (instant full progress on entry).
## 1.0 = entire zone is gradient (progress reaches 1.0 only at the exact center).
## 0.3 = outer 30% is gradient, inner 70% is full progress.
@export_range(0.0, 1.0) var falloff_zone: float = 0.3

## Optional non-linear falloff curve. Applied to the raw linear progress.
@export var falloff_curve: Curve

@export_group("Shape Auto-Create")

## If true and no CollisionShape2D child exists, auto-create one in editor.
## This is a @tool QOL feature — the shape is visible and editable in the editor.
@export var auto_create_shape: bool = true

## Size for auto-created RectangleShape2D.
@export var detection_size: Vector2 = Vector2(128, 128):
	set(value):
		detection_size = value
		_update_auto_shape_size()

@export_group("Debug")
## Prints detailed state changes and logic paths to the console.
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
# Unified tracked node — works for both PhysicsBody2D and Area2D.
var _tracked_node: Node2D = null

var _juice_siblings: Array[JuiceBase] = []
var _juice_siblings_dirty: bool = true


# =============================================================================
# LIFECYCLE
# =============================================================================

func _init() -> void:
	# Pre-populate falloff_curve with Godot's Smoothstep preset:
	# two points at (0,0) and (1,1), both TANGENT_FREE with tangent=0.
	# This gives an S-curve identical to the editor Presets > Smoothstep pick.
	# Users can replace or clear it via the inspector at any time.
	if falloff_curve == null:
		var c := Curve.new()
		c.add_point(Vector2(0.0, 0.0), 0.0, 0.0, Curve.TANGENT_FREE, Curve.TANGENT_FREE)
		c.add_point(Vector2(1.0, 1.0), 0.0, 0.0, Curve.TANGENT_FREE, Curve.TANGENT_FREE)
		falloff_curve = c


func _ready() -> void:
	# Enable input picking so Godot's mouse system can detect this Area2D
	input_pickable = true

	if Engine.is_editor_hint():
		_ensure_collision_shape()
		set_process(false)
		return

	_ensure_collision_shape()

	# Connect signals based on enabled detection flags
	if detect_mouse:
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
	if detect_bodies:
		body_entered.connect(_on_object_entered)
		body_exited.connect(_on_object_exited)
	if detect_areas:
		area_entered.connect(_on_object_entered)
		area_exited.connect(_on_object_exited)

	set_process(false)

	# Re-discover siblings when tree changes
	if get_parent():
		get_parent().child_order_changed.connect(_mark_siblings_dirty)

	var modes := []
	if detect_mouse: modes.append("Mouse")
	if detect_bodies: modes.append("Bodies")
	if detect_areas: modes.append("Areas")
	JuiceLogger.log_info(self, "SoftTrigger",
			"SoftTrigger2D ready. Detecting: %s" % [", ".join(modes) if not modes.is_empty() else "nothing"],
			debug_enabled)


func _process(_delta: float) -> void:
	if not _is_inside:
		return

	# Get tracked position in local coordinates.
	# For physics nodes, use the closest point on the tracked shape to our center.
	# This handles cases where the tracked node's origin is outside our zone but
	# its collision shape overlaps. Using the origin alone would yield progress=0.
	var local_pos: Vector2
	if _tracked_node != null and is_instance_valid(_tracked_node):
		local_pos = _get_tracked_local_pos(_tracked_node)
		JuiceLogger.log_info(self, "SoftTrigger",
				"Tracking node '%s' | local_pos=%s (origin=%s)" % [
				_tracked_node.name, local_pos,
				to_local(_tracked_node.global_position)],
				debug_enabled)
	elif detect_mouse:
		local_pos = to_local(get_global_mouse_position())
	else:
		JuiceLogger.log_info(self, "SoftTrigger",
				"_process: no tracked node and detect_mouse=false — skipping",
				debug_enabled)
		return

	# Calculate progress from the collision shape
	var raw_progress := _calculate_shape_progress(local_pos)
	var new_progress := raw_progress

	# Apply optional falloff curve
	if falloff_curve != null and new_progress > 0.0 and new_progress < 1.0:
		new_progress = falloff_curve.sample(new_progress)

	JuiceLogger.log_delta(self, "SoftTrigger", new_progress,
			{"raw": raw_progress, "falloff_zone": falloff_zone,
			"curve": "yes" if falloff_curve != null else "none"},
			name, debug_enabled)

	progress = new_progress
	progress_changed.emit(progress)

	# Drive all discovered juice siblings
	_ensure_juice_siblings()
	JuiceLogger.log_info(self, "SoftTrigger",
			"Driving %d sibling(s) with progress=%.3f" % [_juice_siblings.size(), progress],
			debug_enabled)
	for juice in _juice_siblings:
		if is_instance_valid(juice):
			juice.set_external_progress(progress)


# =============================================================================
# CALLBACKS
# =============================================================================

func _on_mouse_entered() -> void:
	_is_inside = true
	set_process(true)
	proximity_entered.emit()
	JuiceLogger.log_info(self, "SoftTrigger", "Mouse entered", debug_enabled)


func _on_mouse_exited() -> void:
	_release_all()
	JuiceLogger.log_info(self, "SoftTrigger", "Mouse exited", debug_enabled)


func _on_object_entered(object: Node2D) -> void:
	# Track the first body/area that enters (first-in wins).
	if _tracked_node == null:
		_tracked_node = object
		_is_inside = true
		set_process(true)
		proximity_entered.emit()
		JuiceLogger.log_info(self, "SoftTrigger",
				"Object entered: %s" % object.name, debug_enabled)


func _on_object_exited(object: Node2D) -> void:
	if object == _tracked_node:
		_tracked_node = null
		_release_all()
		JuiceLogger.log_info(self, "SoftTrigger",
				"Object exited: %s" % object.name, debug_enabled)


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

## Calculate 0–1 progress from a local-space point inside the collision shape.
## Supports RectangleShape2D and CircleShape2D. Falls back to circle for others.
func _calculate_shape_progress(local_pos: Vector2) -> float:
	var shape := _get_collision_shape()
	if shape == null:
		return 0.0

	if shape is RectangleShape2D:
		return _progress_rect(local_pos, (shape as RectangleShape2D).size)
	elif shape is CircleShape2D:
		return _progress_circle(local_pos, (shape as CircleShape2D).radius)
	else:
		# Fallback: treat unknown shapes as circle using the shape's rough extents
		# This handles CapsuleShape2D, ConvexPolygon, etc. approximately
		JuiceLogger.warn(self, "SoftTrigger",
			"Unsupported shape type '%s', using circle fallback" % shape.get_class(),
			debug_enabled)
		return _progress_circle(local_pos, 64.0)


## Get the local-space position to use for a tracked node.
## If the tracked node is an Area2D or PhysicsBody2D with a CollisionShape2D child,
## use the closest point on its collision boundary to our center.
## Falls back to the node's raw origin.
func _get_tracked_local_pos(tracked: Node2D) -> Vector2:
	# Try to find a collision shape on the tracked node
	var tracked_shape: Shape2D = null
	var tracked_col: CollisionShape2D = null
	for child in tracked.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
			tracked_col = child as CollisionShape2D
			tracked_shape = tracked_col.shape
			break

	if tracked_shape == null:
		# No shape found — fall back to raw origin
		return to_local(tracked.global_position)

	# Compute the tracked shape's center in global space
	# (the CollisionShape2D may have a local offset from its parent)
	var shape_center_global: Vector2 = tracked.global_transform * tracked_col.position

	# Our center in global space
	var our_center_global: Vector2 = global_position

	# Direction from tracked shape center to our center
	var dir_to_us: Vector2 = our_center_global - shape_center_global

	if dir_to_us.length_squared() < 0.001:
		# Essentially overlapping — return our center (will yield progress=1)
		return Vector2.ZERO

	# Compute the closest point on the tracked shape boundary toward our center.
	# For RectangleShape2D: clamp the direction to the rect boundary.
	# For CircleShape2D: scale the direction to radius.
	var closest_global: Vector2
	var dir_norm := dir_to_us.normalized()

	if tracked_shape is RectangleShape2D:
		var half := (tracked_shape as RectangleShape2D).size * 0.5
		# Point on the rect boundary in the direction toward us (local to tracked node)
		var local_dir := tracked.global_transform.basis_xform_inv(dir_norm)
		# Find the scale factor to reach the rect boundary
		var scale_x := absf(half.x / local_dir.x) if absf(local_dir.x) > 0.001 else INF
		var scale_y := absf(half.y / local_dir.y) if absf(local_dir.y) > 0.001 else INF
		var boundary_scale := minf(scale_x, scale_y)
		var boundary_local := local_dir * boundary_scale + tracked_col.position
		closest_global = tracked.global_transform * boundary_local
	elif tracked_shape is CircleShape2D:
		var radius := (tracked_shape as CircleShape2D).radius
		closest_global = shape_center_global + dir_norm * radius
	else:
		# Unknown shape — just use origin
		return to_local(tracked.global_position)

	return to_local(closest_global)


## Clamp a local-space point to within rect bounds.
## Entities whose origin is outside the zone but whose shape overlaps
## are treated as sitting at the zone edge — progress=0 at boundary, rising to center.
func _clamp_to_rect(local_pos: Vector2, rect_size: Vector2) -> Vector2:
	var half := rect_size * 0.5
	return Vector2(clampf(local_pos.x, -half.x, half.x), clampf(local_pos.y, -half.y, half.y))


## Progress for RectangleShape2D — same math as Control variant.
func _progress_rect(local_pos: Vector2, rect_size: Vector2) -> float:
	if rect_size.x <= 0.0 or rect_size.y <= 0.0:
		return 0.0

	var half := rect_size * 0.5
	var dx := absf(local_pos.x)
	var dy := absf(local_pos.y)

	var falloff_x := half.x * falloff_zone
	var falloff_y := half.y * falloff_zone
	var inner_x := half.x - falloff_x
	var inner_y := half.y - falloff_y

	if dx <= inner_x and dy <= inner_y:
		return 1.0

	var prog_x := 1.0
	if falloff_x > 0.0 and dx > inner_x:
		prog_x = 1.0 - clampf((dx - inner_x) / falloff_x, 0.0, 1.0)

	var prog_y := 1.0
	if falloff_y > 0.0 and dy > inner_y:
		prog_y = 1.0 - clampf((dy - inner_y) / falloff_y, 0.0, 1.0)

	return minf(prog_x, prog_y)


## Progress for CircleShape2D — radial falloff from border to center.
func _progress_circle(local_pos: Vector2, radius: float) -> float:
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

## Ensure a CollisionShape2D child exists. If not and auto_create_shape is on,
## create one with a RectangleShape2D sized to detection_size.
func _ensure_collision_shape() -> void:
	# Check for existing shape
	for child in get_children():
		if child is CollisionShape2D:
			return

	if not auto_create_shape:
		if not Engine.is_editor_hint():
			JuiceLogger.warn(self, "SoftTrigger",
					"No CollisionShape2D child. Detection will not work.", debug_enabled)
		return

	# Auto-create a CollisionShape2D with RectangleShape2D
	var col := CollisionShape2D.new()
	col.name = "Juice_CollisionShape2D"
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = detection_size
	col.shape = rect_shape
	add_child(col)

	# Set owner for editor serialization
	if Engine.is_editor_hint():
		var scene_root := get_tree().edited_scene_root if get_tree() else null
		if scene_root:
			col.owner = scene_root

	JuiceLogger.log_info(self, "SoftTrigger",
			"Auto-created CollisionShape2D with size %s" % str(detection_size),
			debug_enabled)


## Update the auto-created shape's size when detection_size changes.
func _update_auto_shape_size() -> void:
	for child in get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			(child.shape as RectangleShape2D).size = detection_size
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
		if sibling is JuiceBase and sibling != self:
			_juice_siblings.append(sibling as JuiceBase)

	_juice_siblings_dirty = false

	JuiceLogger.log_info(self, "SoftTrigger",
			"Discovered %d juice siblings" % _juice_siblings.size(), debug_enabled)


func _mark_siblings_dirty() -> void:
	_juice_siblings_dirty = true


# =============================================================================
# HELPERS
# =============================================================================

## Get the Shape2D resource from the first CollisionShape2D child.
func _get_collision_shape() -> Shape2D:
	for child in get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
			return (child as CollisionShape2D).shape
	return null


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	var has_shape := false
	for child in get_children():
		if child is CollisionShape2D:
			has_shape = true
			break

	if not has_shape and not auto_create_shape:
		warnings.append("No CollisionShape2D child found. Add one or enable auto_create_shape.")

	if get_parent():
		var has_juice := false
		for sibling in get_parent().get_children():
			if sibling is JuiceBase and sibling != self:
				has_juice = true
				break
		if not has_juice:
			warnings.append("No JuiceBase siblings found to drive.")

	return warnings
