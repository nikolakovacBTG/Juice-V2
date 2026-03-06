## ScreenOverlayJuiceComp - Unified Screen Color Overlay (Flash/Fade)
## ============================================================================
## PURPOSE:
## Provides a single, unified screen overlay juice component.
## It replaces the separate "flash" vs "fade" component split by making the
## behavior a matter of configuration (one_shot, bidirectional, triggers).
##
## SYSTEM: Juice System (Screen overlay effects)
##
## WHY THIS EXISTS:
## - Screen flash and screen fade are conceptually the same effect:
##   a full-screen ColorRect overlay whose alpha is animated.
## - With JuiceCompBase supporting one_shot + bidirectional, "flash" vs "fade"
##   is already a configuration decision.
## - This component adds an overlay blend mode dropdown so the same overlay can
##   be used for normal fades, additive flashes, multiply tints, etc.
##
## DOES NOT HANDLE:
## - True "fade the rendered scene into transparency" (viewport/postprocess).
## - Multiple simultaneous overlays (the last effect that writes wins).
## - Complex overlay shapes/patterns (wipes, radial fades, masks).
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceUtilityScreen.svg")
class_name ScreenOverlayJuiceComp
extends JuiceCompBase


# =============================================================================
# OVERLAY CONFIGURATION
# =============================================================================

@export_group("Overlay")

## Color of the overlay. Alpha is controlled by this component.
@export var overlay_color: Color = Color.BLACK

## Maximum alpha applied at progress=1.0.
@export_range(0.0, 1.0) var max_alpha: float = 1.0

## Direction of the overlay during animate_in():
## - TO_COLOR: alpha goes from 0 -> max_alpha
## - TO_CLEAR: alpha goes from max_alpha -> 0
enum OverlayDirection {
	TO_COLOR,
	TO_CLEAR
}

@export var direction: OverlayDirection = OverlayDirection.TO_COLOR


# =============================================================================
# TEXTURE OVERLAY (OPTIONAL)
# =============================================================================

@export_group("Texture Overlay")

## Optional texture to draw on the overlay.
## When set, the overlay becomes a tinted texture overlay (ColorRect.texture).
## Alpha animation still uses the ColorRect color alpha.
@export var overlay_texture: Texture2D = null

## How the overlay texture repeats across the full-screen overlay rect.
@export var overlay_texture_repeat: CanvasItem.TextureRepeat = CanvasItem.TEXTURE_REPEAT_DISABLED

## Filtering mode for the overlay texture (useful for pixel art vs smooth textures).
@export var overlay_texture_filter: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_LINEAR


# =============================================================================
# BLEND MODE (CANVAS ITEM)
# =============================================================================

@export_group("Blend")

## Blend mode applied to the shared overlay ColorRect.
## NOTE: The overlay is shared via JuiceScreenOverlayProvider.
## When multiple overlay effects run, whichever runs last will control the
## overlay material settings.
enum OverlayBlendMode {
	MIX,
	ADD,
	SUB,
	MUL,
	PREMULT_ALPHA
}

@export var blend_mode: OverlayBlendMode = OverlayBlendMode.MIX


# =============================================================================
# INTERNAL STATE
# =============================================================================

## Reference to the shared screen overlay.
var _overlay: ColorRect = null

## Optional TextureRect used when overlay_texture is enabled.
## This is created as a child of the shared ColorRect so we keep the existing
## JuiceScreenOverlayProvider implementation intact.
var _overlay_texture_rect: TextureRect = null


# =============================================================================
# JUICECOMPBASE OVERRIDES
# =============================================================================

func _on_animate_start() -> void:
	_overlay = JuiceScreenOverlayProvider.get_overlay()
	if not is_instance_valid(_overlay):
		if debug_enabled:
			push_warning("[%s] Could not create screen overlay" % name)
		return

	# Avoid resetting state during the one_shot auto-return phase.
	# This prevents a visible flicker when the base class immediately reverses.
	if _is_one_shot_return:
		if debug_enabled:
			print("[%s] Auto-reverse starting - keeping current overlay state" % name)
		return

	_apply_texture_settings_to_overlay()
	_apply_blend_mode_to_overlay()

	# Initialize a correct visual state immediately.
	_apply_effect(_animation_progress)

	if debug_enabled:
		print("[%s] Overlay started - color=%s, max_alpha=%.2f, direction=%s, blend=%s" % [
			name,
			overlay_color,
			max_alpha,
			OverlayDirection.keys()[direction],
			OverlayBlendMode.keys()[blend_mode]
		])


func _apply_effect(progress: float) -> void:
	if not is_instance_valid(_overlay):
		return

	var alpha: float = 0.0
	match direction:
		OverlayDirection.TO_COLOR:
			alpha = max_alpha * progress
		OverlayDirection.TO_CLEAR:
			alpha = max_alpha * (1.0 - progress)

	var clamped_alpha: float = clamp(alpha, 0.0, 1.0)

	# When using a texture overlay, the TextureRect becomes the active visual and
	# the ColorRect must be kept transparent so we do not double-tint.
	if overlay_texture != null:
		_ensure_texture_rect()
		if is_instance_valid(_overlay_texture_rect):
			var mod := overlay_color
			mod.a = clamped_alpha
			_overlay_texture_rect.modulate = mod
		# Always keep the shared ColorRect fully transparent in texture mode.
		_overlay.color = Color.TRANSPARENT
	else:
		# Color-only overlay.
		var current := overlay_color
		current.a = clamped_alpha
		_overlay.color = current
		# If a texture rect exists from previous use, hide it.
		if is_instance_valid(_overlay_texture_rect):
			_overlay_texture_rect.visible = false


func _on_animate_in_complete() -> void:
	# Ensure exact end state.
	_apply_effect(1.0)


func _on_animate_out_complete() -> void:
	# Ensure exact end state.
	_apply_effect(0.0)


# =============================================================================
# INTERNAL HELPERS
# =============================================================================

func _apply_blend_mode_to_overlay() -> void:
	if not is_instance_valid(_overlay):
		return

	# Blend mode should apply to the visual that is currently drawing.
	# - Color-only: apply to the shared ColorRect.
	# - Texture overlay: apply to the TextureRect child.
	var target: CanvasItem = _overlay
	if overlay_texture != null:
		_ensure_texture_rect()
		if is_instance_valid(_overlay_texture_rect):
			target = _overlay_texture_rect

	var mat := target.material as CanvasItemMaterial
	if mat == null:
		mat = CanvasItemMaterial.new()
		target.material = mat

	match blend_mode:
		OverlayBlendMode.MIX:
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
		OverlayBlendMode.ADD:
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		OverlayBlendMode.SUB:
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
		OverlayBlendMode.MUL:
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		OverlayBlendMode.PREMULT_ALPHA:
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA


func _apply_texture_settings_to_overlay() -> void:
	if not is_instance_valid(_overlay):
		return

	# Texture overlays are implemented using a TextureRect child.
	# We cannot assign a texture directly to ColorRect in Godot 4.
	if overlay_texture == null:
		if is_instance_valid(_overlay_texture_rect):
			_overlay_texture_rect.visible = false
		return

	_ensure_texture_rect()
	if not is_instance_valid(_overlay_texture_rect):
		return

	_overlay_texture_rect.visible = true
	_overlay_texture_rect.texture = overlay_texture
	_overlay_texture_rect.texture_repeat = overlay_texture_repeat
	_overlay_texture_rect.texture_filter = overlay_texture_filter
	# Initial modulate is set by _apply_effect, but we set something safe here.
	_overlay_texture_rect.modulate = overlay_color
	_overlay_texture_rect.modulate.a = 0.0
	# ColorRect should not contribute color in texture mode.
	_overlay.color = Color.TRANSPARENT


func _ensure_texture_rect() -> void:
	if is_instance_valid(_overlay_texture_rect):
		return
	if not is_instance_valid(_overlay):
		return

	# Type-safe discovery: find any existing TextureRect child.
	for child in _overlay.get_children():
		if child is TextureRect:
			_overlay_texture_rect = child as TextureRect
			break

	if is_instance_valid(_overlay_texture_rect):
		return

	_overlay_texture_rect = TextureRect.new()
	_overlay_texture_rect.name = "OverlayTexture"
	_overlay_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_overlay_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_overlay_texture_rect.visible = false
	_overlay.add_child(_overlay_texture_rect)


# =============================================================================
# CONVENIENCE API (OPTIONAL)
# =============================================================================

## Immediately clear the overlay.
func set_clear() -> void:
	_overlay = JuiceScreenOverlayProvider.get_overlay()
	if is_instance_valid(_overlay):
		_overlay.color = Color.TRANSPARENT


## Immediately set overlay to fully applied state according to current settings.
func set_full() -> void:
	_overlay = JuiceScreenOverlayProvider.get_overlay()
	if is_instance_valid(_overlay):
		_apply_blend_mode_to_overlay()
		_apply_effect(1.0)
