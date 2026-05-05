## Proximity-driven continuous progress driver for the Control domain.
##
## based on how deep the mouse cursor is inside this Control's rect, 
## and drives sibling JuiceBase nodes each frame via set_external_progress().

# ============================================================================
# WHAT: Proximity-driven continuous progress driver for the Control domain.
# WHY: Enables Balatro-style hover effects where juice intensity is proportional
#      to spatial proximity, not just binary enter/exit. The spatial falloff
#      IS the easing — no timing system needed.
# SYSTEM: Juice System (addons/Juice_V1/) - Control Domain
#
# DOES NOT:
# - Apply any visual effect itself (it's a sensor/driver, not an effect)
# - Handle directional tilt (see future TiltTowardCursorComp)
# - Track physics bodies (Control domain is mouse-only)
#
# CONNECTIONS:
# - Sibling JuiceBase nodes: discovered via type-safe `is` traversal,
#   driven each frame via set_external_progress()
# - Signals: progress_changed for custom scripts, proximity_entered/exited
#   for polarity-based listeners
#
# USAGE:
# 1. Add as sibling of a visual Control (Button, TextureRect, etc.)
# 2. Size this Control's rect to define the detection zone (can be larger)
# 3. Add JuiceBase children/siblings — they'll be driven automatically
# 4. Set falloff_zone to control the gradient zone width
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceUtilityTriggerControl.svg")
class_name SoftTriggerControlJuiceUtility
extends Control


# =============================================================================
# SIGNALS
# =============================================================================

## Emitted each frame while mouse is inside, with the current 0–1 progress.
## Custom scripts can connect to this for non-juice-comp use cases.
signal progress_changed(value: float)

## Emitted when mouse enters the detection zone.
signal proximity_entered

## Emitted when mouse exits the detection zone.
signal proximity_exited


# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Detection")

## Normalized fraction of the detection zone used as the falloff gradient (0.0–1.0).
## 0.0 = no gradient (instant full progress on entry).
## 1.0 = entire zone is gradient (progress reaches 1.0 only at the exact center).
## 0.3 = outer 30% is gradient, inner 70% is full progress.
@export_range(0.0, 1.0) var falloff_zone: float = 0.3

## Optional non-linear falloff curve. Applied to the raw linear progress.
## Defaults to Smoothstep — replace or clear via the inspector if needed.
@export var falloff_curve: Curve

@export_group("Debug")

## Enable debug output for this component
@export var debug_enabled: bool = false


# =============================================================================
# PUBLIC STATE
# =============================================================================

## Current proximity progress (0.0 = at border or outside, 1.0 = deep inside).
## Read this from custom scripts for non-juice-comp use cases.
var progress: float = 0.0


# =============================================================================
# INTERNAL STATE
# =============================================================================

## Whether the mouse is currently inside this Control's rect
var _is_inside: bool = false

## Cached list of sibling JuiceBase nodes to drive.
## Rebuilt lazily when null (set to null on tree changes).
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
	# Invisible at runtime — this Control only exists as a detection zone.
	# MOUSE_FILTER_PASS receives mouse events but doesn't block them from
	# reaching siblings/parent underneath.
	mouse_filter = Control.MOUSE_FILTER_PASS

	if Engine.is_editor_hint():
		set_process(false)
		return

	# Connect to own mouse signals for enter/exit detection
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	# Start with processing off — only process while mouse is inside
	set_process(false)

	# Re-discover siblings when tree changes
	child_order_changed.connect(_mark_siblings_dirty)
	if get_parent():
		get_parent().child_order_changed.connect(_mark_siblings_dirty)

	JuiceLogger.log_info(self, "SoftTrigger",
			"SoftTriggerControl ready. Rect: %s" % str(size), debug_enabled)


func _process(_delta: float) -> void:
	if not _is_inside:
		return

	# Get mouse position in local coordinates of this Control
	var local_mouse := get_local_mouse_position()

	# Calculate proximity progress from rect border
	var new_progress := _calculate_rect_progress(local_mouse, size)

	# Apply optional falloff curve for non-linear response
	if falloff_curve != null and new_progress > 0.0 and new_progress < 1.0:
		new_progress = falloff_curve.sample(new_progress)

	progress = new_progress
	progress_changed.emit(progress)

	# Drive all discovered juice siblings
	_ensure_juice_siblings()
	for juice in _juice_siblings:
		if is_instance_valid(juice):
			juice.set_external_progress(progress)

	JuiceLogger.log_delta(self, "SoftTrigger", new_progress,
			{"rect_size": size, "curve": "yes" if falloff_curve != null else "none"},
			name, debug_enabled)


# =============================================================================
# MOUSE CALLBACKS
# =============================================================================

func _on_mouse_entered() -> void:
	_is_inside = true
	set_process(true)
	proximity_entered.emit()

	JuiceLogger.log_info(self, "SoftTrigger", "Mouse entered detection zone", debug_enabled)


# Two-step external release: 0.0 first (effect returns to rest state while still
# in external mode), then -1.0 to relinquish external control entirely so
# JuiceBase can respond to animate_in/out calls again.
func _on_mouse_exited() -> void:
	_is_inside = false
	set_process(false)

	# Snap progress to 0 and release external control on all driven comps
	progress = 0.0
	progress_changed.emit(0.0)

	_ensure_juice_siblings()
	for juice in _juice_siblings:
		if is_instance_valid(juice):
			juice.set_external_progress(0.0)
			juice.set_external_progress(-1.0)

	proximity_exited.emit()

	JuiceLogger.log_info(self, "SoftTrigger", "Mouse exited detection zone", debug_enabled)


# =============================================================================
# DISTANCE CALCULATION
# =============================================================================

# Calculate 0–1 progress from a point inside a rectangle.
# 0.0 at the border, 1.0 in the inner region past the falloff zone.
func _calculate_rect_progress(local_pos: Vector2, rect_size: Vector2) -> float:
	if rect_size.x <= 0.0 or rect_size.y <= 0.0:
		return 0.0

	var half := rect_size * 0.5

	# Distance from center, normalized to 0–1 where 1 = at border
	var center_offset := local_pos - half
	var dx := absf(center_offset.x)
	var dy := absf(center_offset.y)

	# How far past the inner boundary (in the falloff zone) is the point?
	# Inner boundary = half * (1 - falloff_zone)
	var falloff_x := half.x * falloff_zone
	var falloff_y := half.y * falloff_zone
	var inner_x := half.x - falloff_x
	var inner_y := half.y - falloff_y

	# If inside inner region, progress = 1.0
	if dx <= inner_x and dy <= inner_y:
		return 1.0

	# Calculate per-axis progress through the falloff zone
	var prog_x := 1.0
	if falloff_x > 0.0 and dx > inner_x:
		prog_x = 1.0 - clampf((dx - inner_x) / falloff_x, 0.0, 1.0)

	var prog_y := 1.0
	if falloff_y > 0.0 and dy > inner_y:
		prog_y = 1.0 - clampf((dy - inner_y) / falloff_y, 0.0, 1.0)

	# Use minimum of both axes — corners are the weakest point
	return minf(prog_x, prog_y)


# =============================================================================
# SIBLING DISCOVERY
# =============================================================================

# Find all sibling JuiceBase nodes (type-safe discovery).
# Called lazily — only rebuilds when _juice_siblings_dirty is true.
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
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	# Check that we have at least one JuiceBase sibling
	if not Engine.is_editor_hint():
		return warnings

	var parent := get_parent()
	if parent == null:
		warnings.append("SoftTriggerControlJuiceUtility needs a parent node with JuiceBase siblings to drive.")
		return warnings

	var has_juice_sibling := false
	for sibling in parent.get_children():
		if sibling is JuiceBase and sibling != self:
			has_juice_sibling = true
			break

	if not has_juice_sibling:
		warnings.append("No JuiceBase siblings found. Add JuiceControl/Juice2D/Juice3D nodes as siblings to be driven by this trigger.")

	return warnings
