## Provides a shared, auto-created screen overlay ColorRect for screen flash and fade effects.
##
## Static utility — no instance needed. Multiple effects share the same overlay.

# ============================================================================
# WHAT: Provides a shared, auto-created screen overlay ColorRect for screen
#       flash and fade effects. Static utility — no instance needed.
# WHY: Flash/fade effects need a full-screen ColorRect on a high CanvasLayer.
#      Auto-creation on first use removes the need for manual scene setup.
#      Multiple effects share the same overlay to prevent z-fighting.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Support multiple simultaneous overlays (last-write wins).
# DOES NOT: Custom overlay positioning — always full screen.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceUtilityScreen.svg")
class_name JuiceScreenOverlayProvider
extends RefCounted


# =============================================================================
# STATIC STATE
# =============================================================================

static var _canvas_layer: CanvasLayer = null
static var _overlay_rect: ColorRect = null

## CanvasLayer index for the overlay (high value = renders above everything).
const OVERLAY_LAYER: int = 100


# =============================================================================
# PUBLIC API
# =============================================================================

## Get the shared screen overlay ColorRect. Creates the overlay system on first call.
static func get_overlay() -> ColorRect:
	if not is_instance_valid(_overlay_rect):
		_create_overlay_system()
	return _overlay_rect


## Reset overlay to fully transparent.
static func clear() -> void:
	if is_instance_valid(_overlay_rect):
		_overlay_rect.color = Color.TRANSPARENT


## Check if overlay system exists and is valid.
static func is_ready() -> bool:
	return is_instance_valid(_overlay_rect)


# =============================================================================
# INTERNAL
# =============================================================================

static func _create_overlay_system() -> void:
	var root: Object = Engine.get_main_loop()
	if not root is SceneTree:
		JuiceLogger.warn(null, "ScreenOverlay",
				"cannot create overlay — no SceneTree available", true)
		return
	var scene_root: Window = (root as SceneTree).root
	if scene_root == null:
		JuiceLogger.warn(null, "ScreenOverlay",
				"cannot create overlay — SceneTree has no root", true)
		return

	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "JuiceScreenOverlay"
	_canvas_layer.layer = OVERLAY_LAYER
	_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	_overlay_rect = ColorRect.new()
	_overlay_rect.name = "OverlayRect"
	_overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_rect.color = Color.TRANSPARENT
	# Ignore mouse so the overlay never blocks input.
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_canvas_layer.add_child(_overlay_rect)
	# Add to root (not current scene) so it survives scene switches.
	scene_root.add_child(_canvas_layer)
