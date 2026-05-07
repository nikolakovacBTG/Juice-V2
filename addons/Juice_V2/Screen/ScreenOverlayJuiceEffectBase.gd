## Fades a full-screen color or texture overlay in and out over the screen.
##
## Animates a screen-covering [ColorRect] via [JuiceScreenOverlayProvider].
## The Juice target node is ignored — the overlay always covers the entire screen.

# ============================================================================
# WHAT: Shared base for all three domain ScreenOverlay effects (Control/2D/3D).
#       Animates a full-screen ColorRect via JuiceScreenOverlayProvider.
#       Target node is ignored — the overlay covers the entire screen.
# WHY: Screen flash and fade are global effects, not node-specific.
#      Centralising the logic here keeps the three domain wrappers as thin
#      class_name stubs, avoiding multiple-inheritance workarounds.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Write to the target node — always uses JuiceScreenOverlayProvider.
# DOES NOT: Support multiple simultaneous overlays (last-write wins).
# ============================================================================
#
# USAGE IN TRANSITIONS: Used by _JuiceTransitionHandler which ticks this effect
#   manually (no host Juice node required). Pass null as target to start/tick.
#
# DIRECTION SEMANTICS:
#   TO_COLOR: progress 0→1 = alpha 0→max_alpha   (cover/fade-in to overlay)
#   TO_CLEAR: progress 0→1 = alpha max_alpha→0   (reveal/fade-out from overlay)
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceUtilityScreen.svg")
class_name ScreenOverlayJuiceEffectBase
extends JuiceEffectBase


# =============================================================================
# ENUMS
# =============================================================================

## Direction of the overlay during animate_in().
enum OverlayDirection {
	TO_COLOR, ## alpha: 0 → max_alpha (cover the screen)
	TO_CLEAR, ## alpha: max_alpha → 0 (reveal the screen)
}

## Blend mode applied to the overlay ColorRect.
enum OverlayBlendMode {
	MIX,
	ADD,
	SUB,
	MUL,
	PREMULT_ALPHA,
}


# =============================================================================
# CONFIGURATION
# =============================================================================

## Color of the overlay. Alpha channel is driven by animation progress.
var overlay_color: Color = Color.BLACK
## Maximum alpha at progress=1.0 for TO_COLOR, or starting alpha for TO_CLEAR.
var max_alpha: float = 1.0
## Direction of alpha change during animate_in().
var direction: int = OverlayDirection.TO_COLOR:
	set(value):
		direction = value
		notify_property_list_changed()

## Optional texture drawn on top of the overlay (TextureRect child of ColorRect).
var overlay_texture: Texture2D = null:
	set(value):
		overlay_texture = value
		notify_property_list_changed()
## How the overlay texture tiles across the full-screen rect.
var overlay_texture_repeat: int = CanvasItem.TEXTURE_REPEAT_DISABLED
## Filtering mode for the overlay texture.
var overlay_texture_filter: int = CanvasItem.TEXTURE_FILTER_LINEAR

## Blend mode applied to the overlay canvas item.
var blend_mode: int = OverlayBlendMode.MIX


func _init() -> void:
	_subclass_owns_effect_group = true


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	props.append({"name": "Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "overlay_color", "type": TYPE_COLOR,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "max_alpha", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "direction", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "To Color,To Clear",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "blend_mode", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Mix,Add,Sub,Mul,Premult Alpha",
		"usage": PROPERTY_USAGE_DEFAULT})

	props.append({"name": "Texture Overlay", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_SUBGROUP, "hint_string": ""})
	props.append({"name": "overlay_texture", "type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string": "Texture2D",
		"usage": PROPERTY_USAGE_DEFAULT})
	if overlay_texture != null:
		props.append({"name": "overlay_texture_repeat", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Disabled,Enabled,Mirror,Mirror Clamp",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "overlay_texture_filter", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Inherit,Nearest,Linear,Nearest Mipmap,Linear Mipmap,Nearest Mipmap Anisotropy,Linear Mipmap Anisotropy",
			"usage": PROPERTY_USAGE_DEFAULT})

	props.append_array(_get_effect_base_properties())

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"overlay_color": overlay_color = value; return true
		&"max_alpha": max_alpha = value; return true
		&"direction": direction = value; return true
		&"blend_mode": blend_mode = value; return true
		&"overlay_texture": overlay_texture = value; return true
		&"overlay_texture_repeat": overlay_texture_repeat = value; return true
		&"overlay_texture_filter": overlay_texture_filter = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"overlay_color": return overlay_color
		&"max_alpha": return max_alpha
		&"direction": return direction
		&"blend_mode": return blend_mode
		&"overlay_texture": return overlay_texture
		&"overlay_texture_repeat": return overlay_texture_repeat
		&"overlay_texture_filter": return overlay_texture_filter
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

# Cached reference to the shared provider overlay. Re-fetched on each animate start.
var _overlay: ColorRect = null
# TextureRect child created when overlay_texture is set.
var _overlay_texture_rect: TextureRect = null


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

# Called at animation start. Fetches the overlay from JuiceScreenOverlayProvider
# (not a static singleton — provider owns lifecycle). Skips texture/blend-mode
# setup during the auto-reverse phase (_is_one_shot_return) to prevent a flicker
# from re-applying settings while the overlay is already on screen.
func _on_animate_start(_target: Node) -> void:
	_overlay = JuiceScreenOverlayProvider.get_overlay()
	if not is_instance_valid(_overlay):
		JuiceLogger.warn(self, _get_domain_tag(),
				"could not get screen overlay from provider",
				debug_enabled)
		return

	# Skip resetting state during auto-reverse phase to prevent visible flicker.
	if _is_one_shot_return:
		return

	_apply_texture_settings_to_overlay()
	_apply_blend_mode_to_overlay()

	JuiceLogger.log_info(self, _get_domain_tag(),
			"start: color=%s max_alpha=%.2f direction=%s blend=%s" % [
			overlay_color,
			max_alpha,
			OverlayDirection.keys()[direction],
			OverlayBlendMode.keys()[blend_mode]],
			debug_enabled)


# Drives overlay alpha each frame. TO_COLOR: alpha rises with progress (0→max).
# TO_CLEAR: alpha falls as progress rises (max→0). Handles TextureRect vs
# ColorRect visual: if a texture is set, modulate the TextureRect and keep
# the ColorRect transparent; otherwise write directly to ColorRect.color.
func _apply_effect(progress: float, _target: Node) -> void:
	if not is_instance_valid(_overlay):
		_overlay = JuiceScreenOverlayProvider.get_overlay()
	if not is_instance_valid(_overlay):
		return

	var alpha: float = 0.0
	match direction:
		OverlayDirection.TO_COLOR:
			alpha = max_alpha * progress
		OverlayDirection.TO_CLEAR:
			alpha = max_alpha * (1.0 - progress)

	var clamped_alpha: float = clampf(alpha, 0.0, 1.0)

	if overlay_texture != null:
		_ensure_texture_rect()
		if is_instance_valid(_overlay_texture_rect):
			var mod := overlay_color
			mod.a = clamped_alpha
			_overlay_texture_rect.modulate = mod
		# Keep the ColorRect transparent — TextureRect is the visual.
		_overlay.color = Color.TRANSPARENT
	else:
		var current := overlay_color
		current.a = clamped_alpha
		_overlay.color = current
		# Hide any TextureRect left over from a previous texture-mode run.
		if is_instance_valid(_overlay_texture_rect):
			_overlay_texture_rect.visible = false


# Locks the overlay at peak alpha (progress=1.0). Called when animate_in
# completes so the overlay stays visible even if the curve drifts off 1.0.
func _on_animate_in_complete(_target: Node) -> void:
	_apply_effect(1.0, null)


# Ensures the overlay is fully transparent (progress=0.0) after animate_out.
# Mirrors _on_animate_in_complete — prevents alpha lingering from float imprecision.
func _on_animate_out_complete(_target: Node) -> void:
	_apply_effect(0.0, null)


# Clears the provider's overlay so the screen-covering ColorRect is hidden.
# Does not destroy the node — provider manages the node lifecycle.
func _restore_to_natural(_target: Node) -> void:
	# Clear the overlay when the effect stops.
	JuiceScreenOverlayProvider.clear()
	_overlay = null


# Returns the script class as the interrupt identity so all three domain
# subclasses (Control/2D/3D) interrupt each other. Two overlay effects running
# simultaneously would fight for the same ColorRect alpha.
func _get_interrupt_identity() -> Variant:
	return get_script()


# =============================================================================
# HELPERS
# =============================================================================

func _apply_blend_mode_to_overlay() -> void:
	if not is_instance_valid(_overlay):
		return

	# Apply blend mode to whichever canvas item is currently the visual.
	var target_item: CanvasItem = _overlay
	if overlay_texture != null:
		_ensure_texture_rect()
		if is_instance_valid(_overlay_texture_rect):
			target_item = _overlay_texture_rect

	var mat := target_item.material as CanvasItemMaterial
	if mat == null:
		mat = CanvasItemMaterial.new()
		target_item.material = mat

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

	if overlay_texture == null:
		if is_instance_valid(_overlay_texture_rect):
			_overlay_texture_rect.visible = false
		return

	_ensure_texture_rect()
	if not is_instance_valid(_overlay_texture_rect):
		return

	_overlay_texture_rect.visible = true
	_overlay_texture_rect.texture = overlay_texture
	_overlay_texture_rect.texture_repeat = overlay_texture_repeat as CanvasItem.TextureRepeat
	_overlay_texture_rect.texture_filter = overlay_texture_filter as CanvasItem.TextureFilter
	_overlay_texture_rect.modulate = overlay_color
	_overlay_texture_rect.modulate.a = 0.0
	# ColorRect stays transparent while TextureRect provides the visual.
	_overlay.color = Color.TRANSPARENT


func _ensure_texture_rect() -> void:
	if is_instance_valid(_overlay_texture_rect):
		return
	if not is_instance_valid(_overlay):
		return

	# Reuse an existing TextureRect child if present.
	for child in _overlay.get_children():
		if child is TextureRect:
			_overlay_texture_rect = child as TextureRect
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
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	return []
