## Full-screen post-process accumulator for Juice screen effects.
##
## Sits as a ColorRect inside a CanvasLayer at layer=128, reading the final
## composited screen image via the bundled screen_juice shader and manipulating
## UV sampling. Anything rendered underneath — 3D, 2D, HUD — moves as one image.

# ============================================================================
# WHAT: Receiver that applies accumulated screen offsets (position/rotation/zoom)
#       via shader uniforms to a full-screen ColorRect overlay.
# WHY:  Screen-space effects must composite AFTER everything renders. A ColorRect
#       with hint_screen_texture reads the final frame and re-samples it with
#       UV transforms — this is the correct Godot pattern for fullscreen effects.
# SYSTEM: Juice System (addons/Juice_V1/Screen/)
# DOES NOT: Handle Juice timing or triggering — ScreenMotionJuiceEffect does that.
# DOES NOT: Handle per-layer or depth-sensitive effects.
# DOES NOT: Need manual placement — ScreenMotionJuiceEffect auto-bootstraps this.
#           Optionally add manually to a CanvasLayer for custom layer/shader control.
#
# DISCOVERY: Effects find this via the static `instance` variable — zero autoload
#            dependency, zero scene coupling.
#
# SETUP (manual, optional): Add as child of CanvasLayer (layer >= 128).
#        Assign a ShaderMaterial using addons/Juice_V1/Screen/screen_juice.gdshader.
#        Auto-bootstrap creates this entire hierarchy at runtime if absent.
# ============================================================================

@icon("res://addons/juice/Icons/JuiceUtilityScreen.svg")
class_name ScreenJuiceUtility
extends ColorRect


# =============================================================================
# STATIC INSTANCE (singleton-like discovery — no autoload dependency)
# =============================================================================

## Global reference for ScreenMotionJuiceEffect to find the receiver.
## Set in _ready() and by auto-bootstrap before _ready() fires.
## Only one ScreenJuiceUtility should exist at a time.
static var instance: ScreenJuiceUtility = null


# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Debug")

## Enable debug output for accumulated values and shader writes.
@export var debug_enabled: bool = false


# =============================================================================
# PUBLIC OFFSETS (written by ScreenMotionJuiceEffect via delta-first writes)
# =============================================================================

## Accumulated UV offset from all active screen juice effects.
## Values are in normalized screen coordinates (small values like 0.01).
var offset: Vector2 = Vector2.ZERO

## Accumulated rotation from all active screen juice effects (radians).
var rotation_amount: float = 0.0

## Accumulated zoom scale offset. 0.0 = no zoom. Positive = zoom in.
## Shader receives 1.0 + this value. Keep values small (e.g. -0.2 to 0.2).
var zoom_offset: float = 0.0


# =============================================================================
# INTERNAL STATE
# =============================================================================

## Tracks whether any effect was active last frame.
## Used to reset shader uniforms to passthrough when all effects finish.
var _was_active: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	if instance != null and instance != self:
		if debug_enabled:
			print("[ScreenJuiceUtility] Replacing previous instance (expected during scene transitions).")

	instance = self

	# Must not block mouse input to the game underneath.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Process AFTER juice effects so we read fresh accumulated values each frame.
	# Effects run at process_priority 0 by default; we run after them.
	process_priority = 100

	if not material or not material is ShaderMaterial:
		push_warning("[ScreenJuiceUtility] No ShaderMaterial assigned — screen effects will not render. " +
			"If auto-bootstrapped, this is a bug in ScreenMotionJuiceEffect._bootstrap_utility().")

	if debug_enabled:
		print("[ScreenJuiceUtility] Ready (static instance registered)")


func _exit_tree() -> void:
	if instance == self:
		instance = null
		if debug_enabled:
			print("[ScreenJuiceUtility] Removed (static instance cleared)")


func _process(_delta: float) -> void:
	var mat := material as ShaderMaterial
	if not mat:
		return

	var has_effect := offset != Vector2.ZERO or rotation_amount != 0.0 or zoom_offset != 0.0

	if not has_effect:
		# Reset shader to perfect passthrough on the first idle frame after effects end.
		# Without this, stale uniform values keep the screen shifted/rotated/zoomed.
		if _was_active:
			mat.set_shader_parameter("offset", Vector2.ZERO)
			mat.set_shader_parameter("rotation_angle", 0.0)
			mat.set_shader_parameter("zoom_amount", 1.0)
			_was_active = false
			if debug_enabled:
				print("[ScreenJuiceUtility] Shader reset to passthrough")
		return

	_was_active = true

	# Write accumulated values to shader uniforms.
	mat.set_shader_parameter("offset", offset)
	mat.set_shader_parameter("rotation_angle", rotation_amount)
	mat.set_shader_parameter("zoom_amount", 1.0 + zoom_offset)

	if debug_enabled:
		print("[ScreenJuiceUtility] Shader uniforms: offset=%s, rot=%.4f, zoom=%.4f" % [
			offset, rotation_amount, 1.0 + zoom_offset
		])


# =============================================================================
# PUBLIC API
# =============================================================================

## Instantly clears all accumulated juice offsets and resets shader to passthrough.
## Call on scene transitions or emergency resets.
func reset_all() -> void:
	offset         = Vector2.ZERO
	rotation_amount = 0.0
	zoom_offset    = 0.0

	var mat := material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("offset", Vector2.ZERO)
		mat.set_shader_parameter("rotation_angle", 0.0)
		mat.set_shader_parameter("zoom_amount", 1.0)

	if debug_enabled:
		print("[ScreenJuiceUtility] All offsets reset")
