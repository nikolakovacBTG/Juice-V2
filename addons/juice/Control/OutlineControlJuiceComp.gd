## OutlineControlJuiceComp.gd
## ============================================================================
## WHAT: Animates a border outline on Control nodes using Godot's native StyleBox system.
## WHY: Highlight interactable UI elements on hover, selection feedback, focus state.
## SYSTEM: Juicing System (addons/juice/) - Control Domain
## DOES NOT: 3D outlines — use Outline3DJuiceComp (Inverted Hull) for that.
## DOES NOT: 2D sprite outlines — use Outline2DJuiceComp (shader-based) for that.
## ============================================================================
##
## ARCHITECTURE:
## - Uses Godot's native StyleBoxFlat border_width + expand_margin properties
## - Duplicates the target Control's existing StyleBox for each theme state,
##   adds an animated colored border, and applies as theme overrides
## - expand_margin pushes the border OUTSIDE the control's rect (no layout shift)
## - On animate_out_complete, restores original theme overrides
##
## WHY NOT SHADER?
## - Controls draw multiple primitives (nine-patch, text glyphs, icons) via theme.
##   A CanvasItem shader applies per-draw-call, distorting each primitive separately.
## - StyleBox borders are the Godot-native way to outline Controls.
##
## USAGE:
## - Add as child of Button, Panel, LineEdit, or any Control with StyleBox theming
## - Configure outline_color and outline_width
## - animate_in() shows outline, animate_out() hides it
## - Set trigger_on=ON_HOVER_START for hover outlines
##
## EXAMPLES:
## - Hover highlight: outline_color=Yellow, outline_width=3.0
## - Selection: outline_color=White, outline_width=4.0
## - Focus ring: outline_color=Cyan, outline_width=2.0
## ============================================================================

@tool
class_name OutlineControlJuiceComp
extends JuiceCompBase


# =============================================================================
# OUTLINE CONFIGURATION
# =============================================================================

@export_group("Outline Effect")

## Color of the outline border
@export var outline_color: Color = Color.YELLOW

## Maximum width of the outline border in pixels.
## Typical values: 1.0–4.0 for subtle, 4.0–8.0 for bold.
@export var outline_width: float = 3.0

## Corner radius for the outline border (0 = sharp corners).
## Set to -1 to inherit corner_radius from the existing StyleBox.
@export var corner_radius: int = -1


# =============================================================================
# INTERNAL STATE
# =============================================================================

## Theme states to override with bordered StyleBoxes.
## Covers Button, Panel, and most common Control states.
const THEME_STATES := ["normal", "hover", "pressed", "disabled", "focus", "panel"]

## Maps state_name → the StyleBoxFlat we created (with animated border)
var _outline_styles: Dictionary = {}

## Maps state_name → the original StyleBox override (or null if none existed)
var _original_overrides: Dictionary = {}

## Whether we've saved originals and created outline styles
var _is_setup: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()


# =============================================================================
# VIRTUAL METHOD IMPLEMENTATIONS
# =============================================================================

func _invalidate_base_cache() -> void:
	_is_setup = false
	_outline_styles.clear()
	_original_overrides.clear()


func _on_animate_start() -> void:
	if not _is_setup:
		_setup_outline()

	if _outline_styles.is_empty():
		if debug_enabled:
			push_warning("[%s] No outline styles available — target may not be a Control" % name)
		return

	if debug_enabled:
		print("[%s] Outline start: color=%s, width=%.1f, states=%d" % [
			name, outline_color, outline_width, _outline_styles.size()
		])


func _apply_effect(progress: float) -> void:
	var border_px := int(round(outline_width * progress))

	for state: String in _outline_styles:
		var style: StyleBoxFlat = _outline_styles[state]
		# Animate border width
		style.border_width_left = border_px
		style.border_width_top = border_px
		style.border_width_right = border_px
		style.border_width_bottom = border_px
		style.border_color = outline_color
		# Expand margin so border renders OUTSIDE the control rect
		style.expand_margin_left = border_px
		style.expand_margin_top = border_px
		style.expand_margin_right = border_px
		style.expand_margin_bottom = border_px


func _on_animate_out_complete() -> void:
	if not _target_node is Control:
		return

	var control := _target_node as Control

	# Restore original theme overrides (or remove ours)
	for state: String in _original_overrides:
		var original: Variant = _original_overrides[state]
		if original != null:
			control.add_theme_stylebox_override(state, original as StyleBox)
		else:
			control.remove_theme_stylebox_override(state)

	# Force re-setup on next trigger (our StyleBoxes are no longer applied)
	_is_setup = false
	_outline_styles.clear()

	if debug_enabled:
		print("[%s] Outline complete, restored original styles" % name)


# =============================================================================
# OUTLINE SETUP
# =============================================================================

## For each theme state the Control actually uses, duplicate its StyleBox,
## add a zero-width border (animated later), and apply as theme override.
func _setup_outline() -> void:
	if not _target_node is Control:
		if debug_enabled:
			push_warning("[%s] Target '%s' is not a Control — outline won't work" % [
				name, str(_target_node.name) if _target_node else "null"
			])
		return

	var control := _target_node as Control

	for state in THEME_STATES:
		# Only override states the control actually has a StyleBox for
		if not control.has_theme_stylebox(state):
			continue

		# Save original override (if any) for restoration
		if control.has_theme_stylebox_override(state):
			_original_overrides[state] = control.get_theme_stylebox(state)
		else:
			_original_overrides[state] = null

		# Get effective StyleBox and create our bordered version
		var base: StyleBox = control.get_theme_stylebox(state)
		var outline_style: StyleBoxFlat

		if base is StyleBoxFlat:
			outline_style = base.duplicate() as StyleBoxFlat
		else:
			# Non-flat StyleBox (StyleBoxTexture, etc.) — create a flat one
			# that preserves content margins
			outline_style = StyleBoxFlat.new()
			outline_style.bg_color = Color.TRANSPARENT
			if base:
				outline_style.content_margin_left = base.content_margin_left
				outline_style.content_margin_top = base.content_margin_top
				outline_style.content_margin_right = base.content_margin_right
				outline_style.content_margin_bottom = base.content_margin_bottom

		# Apply configured corner radius (or inherit from existing)
		if corner_radius >= 0:
			outline_style.corner_radius_top_left = corner_radius
			outline_style.corner_radius_top_right = corner_radius
			outline_style.corner_radius_bottom_left = corner_radius
			outline_style.corner_radius_bottom_right = corner_radius

		# Start with zero border (invisible — will be animated by _apply_effect)
		outline_style.border_width_left = 0
		outline_style.border_width_top = 0
		outline_style.border_width_right = 0
		outline_style.border_width_bottom = 0
		outline_style.border_color = outline_color

		_outline_styles[state] = outline_style
		control.add_theme_stylebox_override(state, outline_style)

	_is_setup = true

	if debug_enabled:
		print("[%s] Created outline StyleBoxes for %d states on '%s'" % [
			name, _outline_styles.size(), control.name
		])


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if _target_node and not _target_node is Control:
		warnings.append("Target node is not a Control. OutlineControlJuiceComp requires a Control target (Button, Panel, etc.).")

	return warnings
