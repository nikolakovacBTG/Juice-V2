## JuiceScreenOverlayProvider - Shared Screen Overlay Utility
## ============================================================================
## PURPOSE:
## Provides a shared, auto-created screen overlay for flash and fade effects.
## This is a static utility class - no instance needed.
##
## SYSTEM: Juice System
##
## WHY THIS EXISTS:
## Flash and fade effects need a full-screen ColorRect on a high CanvasLayer.
## Instead of requiring manual setup, this class creates the overlay on first use.
## Multiple components share the same overlay to prevent z-fighting.
##
## USAGE:
## var overlay: ColorRect = JuiceScreenOverlay.get_overlay()
## overlay.color = Color(1, 0, 0, 0.5)  # Semi-transparent red
##
## DOES NOT HANDLE:
## - Multiple simultaneous overlays (last effect wins)
## - Custom overlay positioning (always full screen)
## - Post-processing effects (those use WorldEnvironment)
## ============================================================================

@tool
class_name JuiceScreenOverlayProvider
extends RefCounted


# =============================================================================
# STATIC STATE
# =============================================================================

## The singleton CanvasLayer that holds the overlay
static var _canvas_layer: CanvasLayer = null

## The ColorRect used for flash/fade effects
static var _overlay_rect: ColorRect = null

## Layer number for the overlay (high value to be on top of everything)
const OVERLAY_LAYER: int = 100


# =============================================================================
# PUBLIC API
# =============================================================================

## Get the shared screen overlay ColorRect
## Creates the overlay system on first call
static func get_overlay() -> ColorRect:
	if not is_instance_valid(_overlay_rect):
		_create_overlay_system()
	return _overlay_rect


## Reset overlay to transparent (convenience method)
static func clear() -> void:
	if is_instance_valid(_overlay_rect):
		_overlay_rect.color = Color.TRANSPARENT


## Check if overlay system exists
static func is_ready() -> bool:
	return is_instance_valid(_overlay_rect)


# =============================================================================
# INTERNAL
# =============================================================================

## Create the CanvasLayer and ColorRect for screen effects
static func _create_overlay_system() -> void:
	# Get the scene tree root
	var root = Engine.get_main_loop()
	if not root is SceneTree:
		push_error("[JuiceScreenOverlay] Cannot create overlay - no SceneTree available")
		return
	
	var scene_root = (root as SceneTree).root
	if not scene_root:
		push_error("[JuiceScreenOverlay] Cannot create overlay - SceneTree has no root")
		return
	
	# Create CanvasLayer on high layer to be above everything
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "JuiceScreenOverlay"
	_canvas_layer.layer = OVERLAY_LAYER
	
	# Create full-screen ColorRect
	_overlay_rect = ColorRect.new()
	_overlay_rect.name = "OverlayRect"
	_overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_rect.color = Color.TRANSPARENT
	# Ignore mouse so it doesn't block input
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Assemble hierarchy
	_canvas_layer.add_child(_overlay_rect)
	scene_root.add_child(_canvas_layer)
	
	# Ensure it persists across scene changes
	# The overlay is added to root, not current scene, so it survives scene switches
