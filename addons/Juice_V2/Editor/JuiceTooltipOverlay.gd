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
	# STOP: this control owns hover in the label area. It's a sibling of the
	# EditorProperty (not a child), so EditorProperty's layout doesn't touch it.
	# top_level=true takes it out of the parent VBox's stacking.
	mouse_filter = Control.MOUSE_FILTER_STOP
	top_level = true

# =============================================================================
# LIFECYCLE
# =============================================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_POST_ENTER_TREE:
		if _target_property and is_instance_valid(_target_property):
			if not _target_property.resized.is_connected(_override_layout):
				_target_property.resized.connect(_override_layout)
			if not _target_property.item_rect_changed.is_connected(_override_layout):
				_target_property.item_rect_changed.connect(_override_layout)
			call_deferred("_override_layout")
	elif what == NOTIFICATION_EXIT_TREE:
		if _target_property and is_instance_valid(_target_property):
			if _target_property.resized.is_connected(_override_layout):
				_target_property.resized.disconnect(_override_layout)
			if _target_property.item_rect_changed.is_connected(_override_layout):
				_target_property.item_rect_changed.disconnect(_override_layout)


# Position over the label area of the target EditorProperty.
# Uses top_level=true so coordinates are in viewport space.
# Only covers the FIRST ROW height — excludes bottom editors (Vector3 sub-row).
func _override_layout() -> void:
	if not _target_property or not is_instance_valid(_target_property):
		visible = false
		return
	if not _target_property.is_inside_tree():
		visible = false
		return

	# name_split_ratio defines where the label ends and value area begins.
	var split: float = _target_property.name_split_ratio

	# For multi-row properties (Vector3, etc.), only cover the label row height,
	# not the full EditorProperty height which includes the bottom editor.
	# The label row height is the minimum size of a single inspector row.
	var row_height := _target_property.size.y
	# Check for bottom editor children that extend the property vertically.
	for child in _target_property.get_children():
		if child is Control:
			var c := child as Control
			if c.position.y > 0 and c.size.y > 0:
				# This child is below the label row — cap our height before it.
				row_height = minf(row_height, c.position.y)

	global_position = _target_property.global_position
	size = Vector2(_target_property.size.x * split, row_height)
	visible = true


# =============================================================================
# TOOLTIP RENDERING
# =============================================================================

## Returns a richly formatted tooltip matching Godot's native inspector style.
## Called by the engine when the mouse hovers over this overlay's label area.
func _make_custom_tooltip(for_text: String) -> Object:
	if for_text != "juice_tooltip":
		return null

	# Build the tooltip using editor theme tokens for consistent styling.
	var editor_theme := EditorInterface.get_editor_theme()
	if editor_theme == null:
		return null

	# --- Tooltip container ---
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# --- Header: "Property property_name: TypeName = value" ---
	var header := RichTextLabel.new()
	header.bbcode_enabled = true
	header.fit_content = true
	header.scroll_active = false
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.autowrap_mode = TextServer.AUTOWRAP_OFF

	# Use doc-comment color for the "Property" keyword.
	var doc_comment_color := editor_theme.get_color("doc_comment_color", "EditorHelp")
	if doc_comment_color == Color.BLACK:
		doc_comment_color = Color(0.34, 0.67, 1.0)  # Fallback blue.

	var code_font := editor_theme.get_font("doc_source", "EditorFonts")
	var code_size := editor_theme.get_font_size("doc_source_size", "EditorFonts")
	if code_size <= 0:
		code_size = 13

	# Format: "Property property_name: TypeName = value"
	var header_text := "[color=#%s]Property[/color] " % doc_comment_color.to_html(false)
	header_text += "[b]%s[/b]" % property_name
	if not type_name.is_empty():
		header_text += ": [font=%s][font_size=%d]%s = %s[/font_size][/font]" % [
			_get_font_path(code_font), code_size, type_name, value_str
		]
	header.text = header_text
	vbox.add_child(header)

	# --- Separator ---
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	# --- Description body ---
	if not description.is_empty():
		var body := RichTextLabel.new()
		body.bbcode_enabled = true
		body.fit_content = true
		body.scroll_active = false
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.custom_minimum_size.x = 350
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		# Bold keywords wrapped in ** **.
		var formatted := description
		var regex := RegEx.new()
		regex.compile("\\*\\*(.+?)\\*\\*")
		formatted = regex.sub(formatted, "[b]$1[/b]", true)
		body.text = formatted
		vbox.add_child(body)

	return vbox


# Get the resource path of a font, or empty string if unavailable.
func _get_font_path(font: Font) -> String:
	if font and font.resource_path and not font.resource_path.is_empty():
		return font.resource_path
	return ""
