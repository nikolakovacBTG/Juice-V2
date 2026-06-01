## Transparent overlay providing rich, Godot-native-styled tooltips for
## sub-inspector EditorProperty nodes.
##
## Placed as a child of EditorProperty to intercept hover. Overrides
## _make_custom_tooltip() to render a styled tooltip matching Godot's native
## inspector format: blue "Property" header with code-formatted type info,
## plus rich description body with bold keyword support.

# =============================================================================
# WHAT: Transparent Control overlay that renders rich tooltips via _make_custom_tooltip().
# WHY:  EditorInspector.new() doesn't expose set_use_doc_hints() to GDScript,
#       so sub-inspector properties lack native documentation tooltips. This
#       overlay fills that gap with a visually matching implementation built
#       entirely from editor theme tokens.
# SYSTEM: Juice Editor (addons/Juice_V2/Editor/)
# DOES NOT: Handle click events — covers only the label area (left side)
#           so value widgets (dropdowns, checkboxes) remain fully clickable.
# =============================================================================

@tool
extends Control

# =============================================================================
# CONFIGURATION
# =============================================================================

# Property name as declared in GDScript (e.g., "transform_target").
var property_name: String

# Display type name (e.g., "TransformTarget", "float", "bool").
var type_name: String

# Current property value formatted as string.
var value_str: String

# Documentation description from ## doc comments.
var description: String

# =============================================================================
# PUBLIC API
# =============================================================================

## Configure the overlay with tooltip data and activate it.
func setup(p_name: String, p_type: String, p_value: String, p_desc: String) -> void:
	property_name = p_name
	type_name = p_type
	value_str = p_value
	description = p_desc
	# Non-empty tooltip_text is required to trigger _make_custom_tooltip.
	tooltip_text = "juice_tooltip"
	mouse_filter = Control.MOUSE_FILTER_PASS
	# Hidden until _override_layout positions us correctly. This prevents
	# the black flash when EditorProperty initially places us in the value area
	# before our deferred override moves us to the label area.
	visible = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_override_layout")


# Reposition to cover only the label area of the parent EditorProperty.
# Dynamically finds where value widgets start by scanning sibling positions
# instead of assuming a hardcoded 40% split. This prevents overlap with
# value input fields (e.g. the X component of a Vector3 SpinBox).
func _override_layout() -> void:
	var parent_ctrl := get_parent() as Control
	if not parent_ctrl or not is_instance_valid(parent_ctrl):
		return

	# Find where value widgets start by checking sibling positions.
	# EditorProperty places value widgets (SpinBox, CheckBox, etc.) at a
	# specific x offset. The label area ends where the first widget begins.
	var value_start_x := parent_ctrl.size.x
	for child in parent_ctrl.get_children():
		if child == self:
			continue
		if not child is Control:
			continue
		var c := child as Control
		if not c.visible or c.size.x <= 0:
			continue
		# Skip bottom editors (they span full width below the label row).
		if c.position.y >= parent_ctrl.size.y * 0.5:
			continue
		value_start_x = minf(value_start_x, c.position.x)

	if value_start_x <= 0.0:
		return

	position = Vector2.ZERO
	size = Vector2(value_start_x, parent_ctrl.size.y)
	visible = true


# =============================================================================
# TOOLTIP RENDERING
# =============================================================================

## Build and return a rich tooltip panel matching Godot's native inspector format.
func _make_custom_tooltip(for_text: String) -> Object:
	if for_text != "juice_tooltip":
		return null
	return _build_tooltip_panel()


# Construct the tooltip panel using editor theme tokens.
# Layout mirrors native Godot inspector tooltips:
# ┌─────────────────────────────────────────────────────┐
# │ Property prop_name: TypeName = value                │ ← darker header
# ├─────────────────────────────────────────────────────┤
# │ Description text with bold Keyword: formatting...   │ ← description body
# └─────────────────────────────────────────────────────┘
func _build_tooltip_panel() -> Control:
	var theme := EditorInterface.get_editor_theme()
	if not theme:
		return null

	# --- Theme tokens (all from EditorInterface.get_editor_theme()) ---
	var title_color := theme.get_color("title_color", "EditorHelp")
	var headline_color := theme.get_color("headline_color", "EditorHelp")
	var type_color := theme.get_color("type_color", "EditorHelp")
	var text_color := theme.get_color("font_color", "TooltipLabel")
	# doc_source is the correct monospace font — "doc_code_font" triggers
	# engine warnings despite has_font() reporting it as found.
	var code_font: Font = theme.get_font("doc_source", "EditorFonts")

	# --- Tooltip background color ---
	# Read the bg_color from the native TooltipPanel stylebox so our header
	# can be darker than the body (matching native Godot ordering).
	var tooltip_style: StyleBox = theme.get_stylebox("panel", "TooltipPanel")
	var tooltip_bg_color := Color(0.07, 0.07, 0.07)  # safe fallback
	if tooltip_style is StyleBoxFlat:
		tooltip_bg_color = tooltip_style.bg_color

	# --- Single outer panel (no nested PanelContainers = no extra margins) ---
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = tooltip_bg_color
	panel_style.corner_radius_top_left = 3
	panel_style.corner_radius_top_right = 3
	panel_style.corner_radius_bottom_left = 3
	panel_style.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	# --- Header row (darker than tooltip body) ---
	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 8)
	header_margin.add_theme_constant_override("margin_right", 8)
	header_margin.add_theme_constant_override("margin_top", 6)
	header_margin.add_theme_constant_override("margin_bottom", 6)
	vbox.add_child(header_margin)

	# Draw the darker header background behind the margin container.
	var header_bg := Panel.new()
	header_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var header_bg_style := StyleBoxFlat.new()
	header_bg_style.bg_color = tooltip_bg_color.darkened(0.3)
	header_bg.add_theme_stylebox_override("panel", header_bg_style)
	header_margin.add_child(header_bg)
	# Move bg behind text (z_index won't work, use child order + show_behind_parent).
	header_bg.show_behind_parent = true

	var header := RichTextLabel.new()
	header.fit_content = true
	header.scroll_active = false
	header.autowrap_mode = TextServer.AUTOWRAP_OFF
	header_margin.add_child(header)

	# "Property" in blue bold
	header.push_color(title_color)
	header.push_bold()
	header.add_text("Property")
	header.pop()  # bold
	header.pop()  # color
	header.add_text(" ")
	# Property name in bold white
	header.push_color(headline_color)
	header.push_bold()
	header.add_text(property_name)
	header.pop()  # bold
	header.pop()  # color
	# ": TypeName = value" in code font, type color
	if not type_name.is_empty():
		header.add_text(": ")
		header.push_color(type_color)
		if code_font:
			header.push_font(code_font)
		header.add_text("%s = %s" % [type_name, value_str])
		if code_font:
			header.pop()  # font
		header.pop()  # color

	# --- Description body ---
	if not description.is_empty():
		var body_margin := MarginContainer.new()
		body_margin.add_theme_constant_override("margin_left", 8)
		body_margin.add_theme_constant_override("margin_right", 8)
		body_margin.add_theme_constant_override("margin_top", 6)
		body_margin.add_theme_constant_override("margin_bottom", 6)
		vbox.add_child(body_margin)

		var body := RichTextLabel.new()
		body.fit_content = true
		body.scroll_active = false
		body.custom_minimum_size.x = 300.0
		# Increase line spacing for readability.
		body.add_theme_constant_override("line_separation", 4)
		body_margin.add_child(body)

		body.push_color(text_color)
		_add_description_text(body, description, headline_color)
		body.pop()  # text_color

	return panel


# Add description text with bold keyword detection.
# Lines matching "Keyword:" pattern (single word before colon, <25 chars) get
# bold formatting on the keyword — matching how native Godot tooltips render
# enum value descriptions (e.g., "Parent: description").
# push_bold() is safe: the editor theme provides bold_font for RichTextLabel.
static func _add_description_text(rtl: RichTextLabel, text: String, bold_color: Color) -> void:
	var lines := text.split("\n")
	for i in range(lines.size()):
		if i > 0:
			rtl.newline()
		var line: String = lines[i].strip_edges()
		if line.is_empty():
			continue
		# Detect "Keyword:" at line start — bold the keyword portion.
		var colon_idx := line.find(":")
		if colon_idx > 0 and colon_idx < 25:
			var keyword := line.left(colon_idx)
			if not " " in keyword and not keyword.is_empty():
				rtl.push_color(bold_color)
				rtl.push_bold()
				rtl.add_text(keyword + ":")
				rtl.pop()  # bold
				rtl.pop()  # color
				rtl.add_text(line.substr(colon_idx + 1))
				continue
		rtl.add_text(line)
