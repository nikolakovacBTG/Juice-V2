## Draws a Line2D trail that follows a Node2D or Control target over time.
##
## Place in a Juice2D recipe on any Node2D or Control target.
## animate_in() starts trail collection; animate_out() fades and removes it.

# ============================================================================
# WHAT: 2D-only runtime trail effect. Creates a Line2D during animate_in,
#       appends points at the target's position every tick, and fades it out
#       on animate_out.
# WHY:  Trail is rendered as a Line2D — a fundamentally 2D primitive with no
#       3D equivalent. Domain-agnostic registration is not appropriate here.
#       The effect registers only in Juice2DRecipe so it never appears on 3D nodes.
# SYSTEM: Juice System (addons/Juice_V2/Meta/)
# DOES NOT: Handle 3D trails. Does not compute any transform delta.
#           Does not use _physics_process — point accumulation runs inside
#           _apply_effect() which the host ticks every frame, matching V0 behavior.
#
# APPROVED EXCEPTION: Like VFXJuiceEffect, this class fires side-effects
#   (_on_animate_start creates a Line2D node) rather than delta aggregation.
#   Trail points are added inside _apply_effect() because the method is called
#   every frame, satisfying the same rate as V0's _physics_process.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseVFX.svg")
class_name TrailJuiceEffect
extends JuiceEffectBase


# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Trail")

## Maximum number of points kept in the trail at once.
@export var trail_length: int = 20

## Width of the trail in pixels.
@export var trail_width: float = 4.0

## Base color of the trail. Ignored if trail_gradient is set.
@export var trail_color: Color = Color.WHITE

## If true, trail fades from full opacity (head) to transparent (tail).
@export var fade_over_lifetime: bool = true

## Optional gradient for the trail color. Overrides trail_color when set.
@export var trail_gradient: Gradient

## Optional curve shaping trail width from tail (0.0) to head (1.0).
## Multiplied against trail_width to produce custom taper profiles.
@export var trail_width_curve: Curve

@export_group("Trail Rendering")

## Optional texture mapped along the trail (fire, lightning, smoke, etc.).
@export var trail_texture: Texture2D

## How the texture is mapped along the trail.
@export var texture_mode: Line2D.LineTextureMode = Line2D.LINE_TEXTURE_STRETCH

## How line joints (bends) are rendered.
@export var joint_mode: Line2D.LineJointMode = Line2D.LINE_JOINT_ROUND

## Cap style at the tail of the trail.
@export var begin_cap_mode: Line2D.LineCapMode = Line2D.LINE_CAP_ROUND

## Cap style at the head (newest point) of the trail.
@export var end_cap_mode: Line2D.LineCapMode = Line2D.LINE_CAP_ROUND

## If true, smooth trail edges using anti-aliasing.
@export var antialiased: bool = false

## Optional material for custom shader effects (UV panning, distortion).
@export var trail_material: Material

@export_group("Trail Behavior")

## Minimum seconds between point samples.
## Lower = smoother trail with more points.
@export var point_interval: float = 0.02

## Minimum pixel distance the target must move before a new point is recorded.
## Prevents point bunching when the target is stationary.
@export var min_distance_threshold: float = 1.0

## If true, trail points are placed in world space and do not move with the target.
## If false, trail is placed as a sibling of the target and moves with the scene.
@export var world_space_trail: bool = true

## If true, trail width is modulated by animation progress.
## Trail grows from zero to full width during animate_in and shrinks during animate_out.
@export var modulate_width_by_progress: bool = true


# =============================================================================
# INTERNAL STATE
# =============================================================================

# The Line2D node created at animate_start and freed at animate_out_complete.
var _trail_line_2d: Line2D = null

# Accumulated time since the last point was added.
# Compared against point_interval each _apply_effect call.
var _point_timer: float = 0.0

# Last position recorded for min_distance_threshold checking.
var _last_point_position: Vector2 = Vector2.ZERO

# Whether the trail is actively collecting new points.
var _trail_active: bool = false

# Guards the distance threshold on the very first point (no previous position yet).
var _has_start_position: bool = false

# Delta captured by tick() override for use in _apply_effect().
# Effects are Resources — they have no _process() or _physics_process().
# The L3 contract requires storing delta in tick() then reading it in _apply_effect().
var _last_delta: float = 0.0


# =============================================================================
# TICK OVERRIDE (for per-frame delta access)
# =============================================================================

## Capture the per-frame delta so _apply_effect() can use it for point timing.
## Effects are Resources and have no _process(); this is the approved pattern
## for effects that need time accumulation inside _apply_effect().
func tick(delta: float, target: Node) -> TickResult:
	_last_delta = delta
	return super.tick(delta, target)


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

## Create the Line2D node and start collecting trail points.
func _on_animate_start(target: Node) -> void:
	if target == null:
		return
	_create_trail(target)
	_trail_active = true
	_point_timer = 0.0
	_has_start_position = false
	JuiceLogger.log_info(self, _get_domain_tag(),
			"trail started on '%s'" % target.name, debug_enabled)


## Accumulate trail points every frame and modulate width by animation progress.
## No transform delta is produced — this is an approved side-effect exception.
func _apply_effect(progress: float, target: Node) -> void:
	if _trail_line_2d == null or target == null:
		return

	if modulate_width_by_progress:
		_trail_line_2d.width = trail_width * progress

	if not _trail_active:
		return

	_point_timer += _last_delta
	if _point_timer >= point_interval:
		_point_timer = 0.0
		_try_add_trail_point(target)


## Keep ticking after animate_in so the trail continues past the in-phase.
func _needs_sustain() -> bool:
	return _trail_active


## Stop collecting points and fade out the trail when animate_out finishes.
func _on_animate_out_complete(_target: Node) -> void:
	_trail_active = false
	_fade_out_trail()
	JuiceLogger.log_info(self, _get_domain_tag(), "trail stopped — fading out", debug_enabled)


## Immediately remove the trail on explicit stop or scene cleanup.
func _restore_to_natural(_target: Node) -> void:
	_trail_active = false
	_cleanup_trail()


# =============================================================================
# TRAIL CREATION
# =============================================================================

# Create the Line2D with all configured appearance properties.
# Adds it to the current scene (world_space_trail=true) or as a sibling of the target.
func _create_trail(target: Node) -> void:
	if _trail_line_2d != null:
		return  # Already exists from a previous trigger.

	_trail_line_2d = Line2D.new()
	_trail_line_2d.name = "TrailLine2D"
	_trail_line_2d.width = trail_width
	_trail_line_2d.default_color = trail_color
	_trail_line_2d.joint_mode = joint_mode
	_trail_line_2d.begin_cap_mode = begin_cap_mode
	_trail_line_2d.end_cap_mode = end_cap_mode
	_trail_line_2d.antialiased = antialiased

	if trail_width_curve != null:
		_trail_line_2d.width_curve = trail_width_curve
	if trail_texture != null:
		_trail_line_2d.texture = trail_texture
		_trail_line_2d.texture_mode = texture_mode
	if trail_material != null:
		_trail_line_2d.material = trail_material

	if fade_over_lifetime or trail_gradient != null:
		_trail_line_2d.gradient = (trail_gradient if trail_gradient
			else _create_fade_gradient())

	# Placement: world space (scene root) or sibling of target (scene-local).
	if world_space_trail and is_instance_valid(_host_node):
		var scene := _host_node.get_tree().current_scene
		if scene:
			scene.add_child(_trail_line_2d)
	else:
		var parent := target.get_parent()
		if parent:
			parent.add_child(_trail_line_2d)


# Build a simple head-opaque, tail-transparent gradient for fade_over_lifetime.
func _create_fade_gradient() -> Gradient:
	var grad := Gradient.new()
	grad.set_color(0, Color(trail_color.r, trail_color.g, trail_color.b, 0.0))  # Tail
	grad.set_color(1, trail_color)                                               # Head
	return grad


# =============================================================================
# TRAIL POINT MANAGEMENT
# =============================================================================

# Sample the target's current world position and add a point if thresholds are met.
func _try_add_trail_point(target: Node) -> void:
	var current_pos: Vector2
	if target is Node2D:
		current_pos = (target as Node2D).global_position
	elif target is Control:
		current_pos = (target as Control).global_position
	else:
		return  # Unsupported target type.

	if _has_start_position:
		if current_pos.distance_to(_last_point_position) < min_distance_threshold:
			return
	_last_point_position = current_pos
	_has_start_position = true
	_add_trail_point(current_pos)


# Append a new point to the head of the trail and trim the tail if over limit.
func _add_trail_point(pos: Vector2) -> void:
	if _trail_line_2d == null:
		return
	_trail_line_2d.add_point(pos)
	while _trail_line_2d.get_point_count() > trail_length:
		_trail_line_2d.remove_point(0)


# =============================================================================
# TRAIL CLEANUP
# =============================================================================

# Tween the trail to transparent then free it.
# Uses host_node for tween creation since effects are Resources.
func _fade_out_trail() -> void:
	if _trail_line_2d == null or not is_instance_valid(_host_node):
		_cleanup_trail()
		return
	var tween := _host_node.create_tween()
	tween.tween_property(_trail_line_2d, "modulate:a", 0.0, duration_out)
	tween.tween_callback(_cleanup_trail)


# Immediately free the Line2D and reset all accumulation state.
func _cleanup_trail() -> void:
	if _trail_line_2d != null and is_instance_valid(_trail_line_2d):
		_trail_line_2d.queue_free()
	_trail_line_2d = null
	_last_point_position = Vector2.ZERO
	_has_start_position = false
	_point_timer = 0.0


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

## Warn if placed on a non-2D target domain (Trail requires Node2D or Control).
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if trail_length < 2:
		warnings.append("trail_length must be at least 2 to produce a visible line.")
	return warnings
