## ScreenJuiceUtility — Full-Screen Post-Process Juice Accumulator
## ============================================================================
## PURPOSE:
## A full-screen ColorRect overlay that reads the final composited screen image
## via a hint_screen_texture shader and manipulates UV sampling. This enables
## true screen-space effects (shake, kick, zoom, tilt, sway) that affect the
## ENTIRE rendered output — 3D world, 2D sprites, AND UI together as one image.
##
## SYSTEM: Juice System (Screen Effects)
##
## HOW IT WORKS:
## 1. This node must be a child of a CanvasLayer (layer=100 recommended)
## 2. It covers the entire viewport via full_rect anchors
## 3. ScreenMotionJuiceComp(s) anywhere in the scene tree find this receiver
##    via the static `instance` variable and write delta offsets
## 4. Each frame, this receiver reads the accumulated values and sets shader
##    uniforms — the shader manipulates UV to create the visual effect
## 5. When all values are at zero/identity, the shader is a perfect passthrough
##
## DISCOVERY:
## Uses a static instance pattern — zero autoload dependency, works in any project.
## ScreenMotionJuiceComp accesses via: ScreenJuiceUtility.instance
##
## PLACEMENT:
## Add as child of a CanvasLayer with a high layer number (e.g., 100) so it
## renders on top of everything. The CanvasLayer must be in the scene tree
## (e.g., in MainGame, or any persistent scene).
##
## DOES NOT HANDLE:
## - Camera-specific effects (use Camera2D/3DJuiceComp for those)
## - Depth-sensitive effects (future CompositorEffect tier)
## - Per-layer effects (this affects everything uniformly)
## - Juice timing or triggering (ScreenMotionJuiceComp handles that)
## ============================================================================

@icon("res://addons/juice/Icons/JuiceUtilityScreen.svg")
class_name ScreenJuiceUtility
extends ColorRect


# =============================================================================
# STATIC INSTANCE (singleton-like discovery — no autoload dependency)
# =============================================================================

## Global reference for ScreenMotionJuiceComp to find the receiver.
## Only one ScreenJuiceUtility should exist at a time.
static var instance: ScreenJuiceUtility = null


# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Debug")

## Enable debug output for accumulated values
@export var debug_enabled: bool = false


# =============================================================================
# PUBLIC STATE (Written by ScreenMotionJuiceComp via deltas)
# =============================================================================

## Accumulated UV offset from all active screen juice effects.
## Values are in normalized screen coordinates (small values like 0.01).
var offset: Vector2 = Vector2.ZERO

## Accumulated rotation from all active screen juice effects (radians).
var rotation_amount: float = 0.0

## Accumulated zoom offset from all active screen juice effects.
## 0.0 = no zoom. Positive = zoom in. The shader receives 1.0 + this value.
var zoom_offset: float = 0.0

## Tracks whether any effect was active last frame, so we know when to
## reset shader params to identity (passthrough). Without this, stale
## shader uniforms persist after all effects end.
var _was_active: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	if instance != null and instance != self:
		if debug_enabled:
			print("[%s] Replacing previous ScreenJuiceReceiver instance (expected during scene transitions)." % name)

	instance = self

	# Full-screen overlay must not block mouse input to the game underneath
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Process after juice components so we read fresh values each frame.
	# Default process_priority is 0; juice comps run at 0, we run later.
	process_priority = 100

	# Ensure we have the shader material assigned
	if not material or not material is ShaderMaterial:
		push_warning("[%s] No ShaderMaterial assigned — screen juice effects will not render." % name)

	if debug_enabled:
		print("[%s] ScreenJuiceReceiver ready (static instance registered)" % name)


func _exit_tree() -> void:
	if instance == self:
		instance = null
		if debug_enabled:
			print("[%s] ScreenJuiceReceiver removed (static instance cleared)" % name)


func _process(_delta: float) -> void:
	var mat := material as ShaderMaterial
	if not mat:
		return

	var has_effect := offset != Vector2.ZERO or rotation_amount != 0.0 or zoom_offset != 0.0

	if not has_effect:
		# Reset shader to perfect passthrough on the first idle frame after an effect.
		# Without this, stale uniform values keep the screen shifted/rotated/zoomed.
		if _was_active:
			mat.set_shader_parameter("offset", Vector2.ZERO)
			mat.set_shader_parameter("rotation_angle", 0.0)
			mat.set_shader_parameter("zoom_amount", 1.0)
			_was_active = false
			if debug_enabled:
				print("[%s] Shader reset to passthrough" % name)
		return

	_was_active = true

	# Write accumulated values to shader uniforms
	mat.set_shader_parameter("offset", offset)
	mat.set_shader_parameter("rotation_angle", rotation_amount)
	mat.set_shader_parameter("zoom_amount", 1.0 + zoom_offset)

	if debug_enabled:
		print("[%s] Shader uniforms: offset=%s, rot=%.4f, zoom=%.4f" % [
			name, offset, rotation_amount, 1.0 + zoom_offset
		])


# =============================================================================
# PUBLIC API
# =============================================================================

func reset_all() -> void:
	## Instantly clears all accumulated juice offsets.
	## Call this for emergency reset (e.g., scene transition).
	offset = Vector2.ZERO
	rotation_amount = 0.0
	zoom_offset = 0.0

	# Also reset shader uniforms immediately
	var mat := material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("offset", Vector2.ZERO)
		mat.set_shader_parameter("rotation_angle", 0.0)
		mat.set_shader_parameter("zoom_amount", 1.0)

	if debug_enabled:
		print("[%s] All offsets reset" % name)
