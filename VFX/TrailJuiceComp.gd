## TrailJuiceComp.gd
## ============================================================================
## WHAT: Spawns and manages a 2D visual trail that follows the parent node.
##       Creates a Line2D and adds points at the parent's position over time.
## WHY: Provides a marketable, drop-in trail effect for any moving 2D object
##       with configurable appearance and automatic lifecycle management.
## SYSTEM: Juicing System (addons/juice/VFX/)
## DOES NOT: Handle 3D trails - use a dedicated 3D trail addon for that.
## ============================================================================
##
## USAGE:
## 1. Add TrailJuiceComp as child of any Node2D or Control
## 2. Configure trail appearance (width, color, length)
## 3. animate_in() starts the trail, animate_out() fades it out
## 4. Trail automatically follows the parent node while active
## ============================================================================

@tool
class_name TrailJuiceComp
extends JuiceCompBase

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Trail Appearance")

## Maximum number of points in the trail
@export var trail_length: int = 20

## Width of the trail in pixels
@export var trail_width: float = 4.0

## Color of the trail
@export var trail_color: Color = Color.WHITE

## If true, trail fades from head (full opacity) to tail (transparent)
@export var fade_over_lifetime: bool = true

## Optional gradient for trail color (overrides trail_color if set)
@export var trail_gradient: Gradient

## Optional width curve — shapes trail width from tail (0.0) to head (1.0).
## Multiplied against trail_width. Allows custom taper profiles.
@export var trail_width_curve: Curve

@export_group("Trail Rendering")

## Optional texture mapped along the trail (fire, lightning, smoke, etc.)
@export var trail_texture: Texture2D

## How the texture is mapped along the trail
@export var texture_mode: Line2D.LineTextureMode = Line2D.LINE_TEXTURE_STRETCH

## How line joints (bends) are rendered
@export var joint_mode: Line2D.LineJointMode = Line2D.LINE_JOINT_ROUND

## Shape of the trail start (tail)
@export var begin_cap_mode: Line2D.LineCapMode = Line2D.LINE_CAP_ROUND

## Shape of the trail end (head)
@export var end_cap_mode: Line2D.LineCapMode = Line2D.LINE_CAP_ROUND

## Smooth trail edges
@export var antialiased: bool = false

## Optional material for custom shader effects (UV panning, distortion, etc.).
## A ready-made UV pan shader is shipped at VFX/trail_uv_pan.gdshader.
@export var trail_material: Material

@export_group("Trail Behavior")

## How often to add new trail points (seconds between points)
## Lower = smoother trail but more points
@export var point_interval: float = 0.02

## Minimum distance the parent must move before adding a new point
## Prevents bunching when stationary
@export var min_distance_threshold: float = 1.0

## If true, trail persists in world space (stays where drawn)
## If false, trail moves with parent (unusual but available)
@export var world_space_trail: bool = true

## If true, trail width is modulated by the animation envelope progress.
## Trail grows from zero to full width during animate_in, shrinks during animate_out.
@export var modulate_width_by_progress: bool = true

# =============================================================================
# INTERNAL STATE
# =============================================================================

## The Line2D node for the trail
var _trail_line_2d: Line2D = null

## Timer for adding trail points
var _point_timer: float = 0.0

## Last recorded position (to check min_distance_threshold)
var _last_point_position: Vector2 = Vector2.ZERO

## Is the trail currently active?
var _trail_active: bool = false

## Has a valid starting position been set?
var _has_start_position: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()
	
	# Validate parent is 2D
	if _target_node != null and not (_target_node is Node2D or _target_node is Control):
		push_warning("[%s] TrailJuiceComp requires Node2D or Control parent, got: %s" % [name, _target_node.get_class()])
	
	if debug_enabled:
		var target_name: String = str(_target_node.name) if _target_node != null else "none"
		print("[%s] Ready, parent: %s" % [name, target_name])


func _physics_process(delta: float) -> void:
	if not _trail_active:
		return
	
	_point_timer += delta
	
	if _point_timer >= point_interval:
		_point_timer = 0.0
		_try_add_trail_point()


func _exit_tree() -> void:
	_cleanup_trail()

# =============================================================================
# TRAIL CREATION
# =============================================================================

func _create_trail() -> void:
	_create_trail_2d()


func _create_trail_2d() -> void:
	if _trail_line_2d != null:
		return  # Already exists
	
	_trail_line_2d = Line2D.new()
	_trail_line_2d.name = "TrailLine2D"
	_trail_line_2d.width = trail_width
	_trail_line_2d.default_color = trail_color
	_trail_line_2d.joint_mode = joint_mode
	_trail_line_2d.begin_cap_mode = begin_cap_mode
	_trail_line_2d.end_cap_mode = end_cap_mode
	_trail_line_2d.antialiased = antialiased
	
	# Width taper curve — shapes the trail profile from tail to head
	if trail_width_curve != null:
		_trail_line_2d.width_curve = trail_width_curve
	
	# Texture mapping — fire, lightning, smoke, etc.
	if trail_texture != null:
		_trail_line_2d.texture = trail_texture
		_trail_line_2d.texture_mode = texture_mode
	
	# Custom material — for UV panning, distortion, or any shader effect
	if trail_material != null:
		_trail_line_2d.material = trail_material
	
	# Setup gradient for fading
	if fade_over_lifetime or trail_gradient != null:
		var grad := trail_gradient if trail_gradient else _create_fade_gradient()
		_trail_line_2d.gradient = grad
	
	# Add to scene - world space or as sibling
	if world_space_trail:
		var scene_root := get_tree().current_scene
		if scene_root:
			scene_root.add_child(_trail_line_2d)
	else:
		var parent_of_target := _target_node.get_parent()
		if parent_of_target:
			parent_of_target.add_child(_trail_line_2d)
	
	if debug_enabled:
		print("[%s] Created 2D trail (Line2D)" % name)



func _create_fade_gradient() -> Gradient:
	var grad := Gradient.new()
	# Head of trail (newest points) = full color
	# Tail of trail (oldest points) = transparent
	grad.set_color(0, Color(trail_color.r, trail_color.g, trail_color.b, 0.0))  # Tail
	grad.set_color(1, trail_color)  # Head
	return grad

# =============================================================================
# TRAIL POINT MANAGEMENT
# =============================================================================

func _try_add_trail_point() -> void:
	if _target_node == null:
		return
	
	# Get current position from parent (Node2D or Control)
	var current_pos: Vector2
	if _target_node is Node2D:
		current_pos = (_target_node as Node2D).global_position
	elif _target_node is Control:
		current_pos = (_target_node as Control).global_position
	else:
		return
	
	# Check minimum distance threshold
	if _has_start_position:
		var distance := current_pos.distance_to(_last_point_position)
		if distance < min_distance_threshold:
			return  # Haven't moved enough
	
	_last_point_position = current_pos
	_has_start_position = true
	
	# Add the point
	_add_trail_point_2d(current_pos)


func _add_trail_point_2d(pos: Vector2) -> void:
	if _trail_line_2d == null:
		return
	
	# Add new point at the end (head of trail)
	_trail_line_2d.add_point(pos)
	
	# Remove oldest points if over limit
	while _trail_line_2d.get_point_count() > trail_length:
		_trail_line_2d.remove_point(0)
	
	if debug_enabled and (Engine.get_process_frames() % 30 == 0):
		print("[%s] Trail points: %d" % [name, _trail_line_2d.get_point_count()])


# =============================================================================
# TRAIL CLEANUP
# =============================================================================

func _cleanup_trail() -> void:
	if _trail_line_2d != null and is_instance_valid(_trail_line_2d):
		_trail_line_2d.queue_free()
		_trail_line_2d = null
	
	_last_point_position = Vector2.ZERO
	_has_start_position = false
	_point_timer = 0.0


func _fade_out_trail_2d() -> void:
	if _trail_line_2d == null:
		return
	
	# Create a tween to fade out and remove points gradually
	var tween := create_tween()
	tween.tween_property(_trail_line_2d, "modulate:a", 0.0, duration_out)
	tween.tween_callback(_cleanup_trail)


# =============================================================================
# JUICE IMPLEMENTATION
# =============================================================================

func _on_animate_start() -> void:
	# Only start trail when animating IN
	if _target_progress > 0.5:  # Animating IN
		_create_trail()
		_trail_active = true
		_point_timer = 0.0
		
		if debug_enabled:
			print("[%s] Trail started" % name)


func _apply_effect(progress: float) -> void:
	if _trail_line_2d == null or not modulate_width_by_progress:
		return
	## Smoothly modulate trail width based on animation envelope progress.
	## During animate_in: progress ramps 0→1, trail grows from zero to full width.
	## During animate_out: progress ramps 1→0, trail shrinks to zero.
	_trail_line_2d.width = trail_width * progress


func _on_animate_in_complete() -> void:
	# Trail continues running after animate_in completes
	# (continuous mode: trail stays active until animate_out)
	pass


func _on_animate_out_complete() -> void:
	_trail_active = false
	
	# Fade out the trail gracefully
	_fade_out_trail_2d()
	
	if debug_enabled:
		print("[%s] Trail stopping (fade out)" % name)
