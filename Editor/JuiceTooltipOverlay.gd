## Transparent overlay providing rich, Godot-native-styled tooltips for
## sub-inspector EditorProperty nodes.
##
## Added as a SIBLING of the target EditorProperty (child of the same parent
## VBoxContainer) with top_level=true to position freely over the label area.
## EditorProperty forces ALL its children into the value area, so the overlay
## CANNOT be a child of EditorProperty — it must be a sibling.

# =============================================================================
# WHAT: Transparent Control overlay that renders rich tooltips via _make_custom_tooltip().
# WHY:  EditorInspector.new() doesn't expose set_use_doc_hints() to GDScript,
#       so sub-inspector properties lack native documentation tooltips. This
#       overlay fills that gap with a visually matching implementation built
#       entirely from editor theme tokens.
# SYSTEM: Juice Editor (addons/Juice_V2/Editor/)
# DOES NOT: Handle click events — positioned over the label area only.
#           Value widgets (right side) remain fully clickable.
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

# The target EditorProperty whose label area this overlay covers.
var _target_property: EditorProperty

# Cached reference to the nearest ScrollContainer ancestor of the target.
# Used for visibility clipping — overlays hide when target scrolls out of view.
var _clip_container: ScrollContainer


# =============================================================================
# PUBLIC API
# =============================================================================

## Configure the overlay with tooltip data and the target EditorProperty.
func setup(target: EditorProperty, p_name: String, p_type: String, p_value: String, p_desc: String) -> void:
	_target_property = target
	property_name = p_name
	type_name = p_type
	value_str = p_value
	description = p_desc
	# Non-empty tooltip_text is required to trigger _make_custom_tooltip.
	tooltip_text = "juice_tooltip"
	# PASS: receive hover for tooltips but let scroll events pass through
	# to the parent ScrollContainer. STOP would block mouse wheel scrolling
	# inside sub-inspectors.
	mouse_filter = Control.MOUSE_FILTER_PASS
	top_level = true
	# Cache the scroll container for visibility clipping.
	_clip_container = _find_scroll_container(target)


# =============================================================================
# LIFECYCLE
# =============================================================================

# Continuous repositioning via _process replaces signal-based approach.
# Signals (resized, item_rect_changed) don't fire during scrolling, which
# caused overlays to drift to wrong properties after scroll. _process()
# syncs position every frame — one Vector2 assignment per overlay, negligible.
func _process(_delta: float) -> void:
	_sync_position()


# Position over the label area of the target EditorProperty.
# Uses top_level=true so coordinates are in viewport space.
# Only covers the FIRST ROW height — excludes bottom editors (Vector3 sub-row).
# Clips to the visible scroll area to prevent cross-sub-inspector bleed.
func _sync_position() -> void:
	if not _target_property or not is_instance_valid(_target_property):
		visible = false
		return
	if not _target_property.is_inside_tree():
		visible = false
		return

	# --- Visibility clipping ---
	# Hide the overlay when the target property is scrolled outside
	# the visible area of its ScrollContainer. This prevents overlays
	# from one sub-inspector appearing over another sub-inspector's
	# properties (cross-contamination via top_level rendering).
	if _clip_container and is_instance_valid(_clip_container):
		var clip_rect := _clip_container.get_global_rect()
		var target_top: float = _target_property.global_position.y
		var target_bottom: float = target_top + _target_property.size.y
		if target_bottom < clip_rect.position.y or target_top > clip_rect.end.y:
			visible = false
			return

	# name_split_ratio defines where the label ends and value area begins.
	var split: float = _target_property.name_split_ratio

	# For multi-row properties (Vector3, etc.), only cover the label row height,
	# not the full EditorProperty height which includes the bottom editor.
	var row_height := _target_property.size.y
	for child in _target_property.get_children():
		if child is Control:
			var c := child as Control
			if c.position.y > 0 and c.size.y > 0:
				row_height = minf(row_height, c.position.y)

	global_position = _target_property.global_position
	size = Vector2(_target_property.size.x * split, row_height)
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


# Walk up the node tree from 'node' and return the first ScrollContainer ancestor.
# Returns null if none found. Used to determine the visible clipping area.
static func _find_scroll_container(node: Node) -> ScrollContainer:
	var current := node.get_parent()
	while current:
		if current is ScrollContainer:
			return current as ScrollContainer
		current = current.get_parent()
	return null

