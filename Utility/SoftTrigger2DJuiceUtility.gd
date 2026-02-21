## SoftTrigger2DJuiceUtility.gd
## ============================================================================
## WHAT: Proximity-driven continuous progress driver for the 2D domain.
##       Extends Area2D to detect mouse/body entry, then calculates a 0–1
##       progress value based on how deep inside the collision shape the
##       tracked entity is. Drives sibling JuiceCompBase nodes each frame
##       via set_external_progress().
##
## WHY: Enables Balatro-style hover effects where juice intensity is proportional
##      to spatial proximity, not just binary enter/exit. The spatial falloff
##      IS the easing — no timing system needed.
##
## SYSTEM: Juicing System (addons/juice/) - 2D Domain
##
## DOES NOT:
## - Apply any visual effect itself (it's a sensor/driver, not an effect)
## - Handle directional tilt (see future TiltTowardCursorComp)
## - Work with 3D scenes (see SoftTrigger3DJuiceComp)
##
## CONNECTIONS:
## - Sibling JuiceCompBase nodes: discovered via type-safe `is` traversal,
##   driven each frame via set_external_progress()
## - CollisionShape2D child: required for detection zone. Auto-created as
##   @tool feature if auto_create_shape is true and none exists.
##
## USAGE:
## 1. Add as sibling of a visual Node2D (Sprite2D, etc.)
## 2. Add or auto-create a CollisionShape2D child to define the detection zone
## 3. Add JuiceCompBase siblings — they'll be driven automatically
## 4. Set falloff_zone to control the gradient zone width
## ============================================================================

@tool
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

## What to track for proximity calculation.
## MOUSE: track cursor position (Balatro-style hover).
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

## If true and no CollisionShape2D child exists, auto-create one in editor.
## This is a @tool QOL feature — the shape is visible and editable in the editor.
@export var auto_create_shape: bool = true

## Size for auto-created RectangleShape2D.
@export var detection_size: Vector2 = Vector2(128, 128):
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
var _tracked_body: Node2D = null

var _juice_siblings: Array[JuiceCompBase] = []
var _juice_siblings_dirty: bool = true


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Enable input picking so Godot's mouse system can detect this Area2D
	input_pickable = true

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
		print("[%s] SoftTrigger2D ready. Track: %s" % [name, TrackSource.keys()[track_source]])


func _process(_delta: float) -> void:
	if not _is_inside:
		return

	# Get tracked position in local coordinates
	var local_pos: Vector2
	if track_source == TrackSource.MOUSE:
		local_pos = to_local(get_global_mouse_position())
	elif _tracked_body != null and is_instance_valid(_tracked_body):
		local_pos = to_local(_tracked_body.global_position)
	else:
		return

	# Calculate progress from the collision shape
	var new_progress := _calculate_shape_progress(local_pos)

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


# =============================================================================
# CALLBACKS
# =============================================================================

func _on_mouse_entered() -> void:
	_is_inside = true
	set_process(true)
	proximity_entered.emit()
	if debug_enabled:
		print("[%s] Mouse entered" % name)


func _on_mouse_exited() -> void:
	_release_all()
	if debug_enabled:
		print("[%s] Mouse exited" % name)


func _on_body_entered(body: Node2D) -> void:
	# Track the first body that enters (or closest — simplified to first)
	if _tracked_body == null:
		_tracked_body = body
		_is_inside = true
		set_process(true)
		proximity_entered.emit()
		if debug_enabled:
			print("[%s] Body entered: %s" % [name, body.name])


func _on_body_exited(body: Node2D) -> void:
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
		if debug_enabled:
			push_warning("[%s] Unsupported shape type '%s', using circle fallback" % [name, shape.get_class()])
		return _progress_circle(local_pos, 64.0)


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
			push_warning("[%s] No CollisionShape2D child. Detection will not work." % name)
		return

	# Auto-create a CollisionShape2D with RectangleShape2D
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = detection_size
	col.shape = rect_shape
	add_child(col)

	# Set owner for editor serialization
	if Engine.is_editor_hint():
		var scene_root := get_tree().edited_scene_root if get_tree() else null
		if scene_root:
			col.owner = scene_root

	if debug_enabled:
		print("[%s] Auto-created CollisionShape2D with size %s" % [name, detection_size])


## Update the auto-created shape's size when detection_size changes in editor.
func _update_auto_shape_size() -> void:
	if not Engine.is_editor_hint():
		return
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
			if sibling is JuiceCompBase and sibling != self:
				has_juice = true
				break
		if not has_juice:
			warnings.append("No JuiceCompBase siblings found to drive.")

	return warnings
