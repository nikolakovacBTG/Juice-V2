## Renders one row in a Juice array inspector: color strip, grab handle,
## index, context menu, icon + resource name, and delete button.
##
## A reusable, self-contained row component used by JuiceArrayEditor for
## every resource entry in any Juice typed array. Clicking the resource name
## expands/collapses the sub-inspector (matching native Godot convention).

# =============================================================================
# WHAT: Atomic row component for Juice array inspector entries.
# WHY:  All Juice typed arrays share the same row UX: consistent layout,
#       context menu for resource operations, and type-color coding. Building
#       one row component avoids duplicating layout logic across array types
#       and ensures a uniform inspector experience addon-wide.
# SYSTEM: Juice System (addons/Juice_V2/Editor/) — EDITOR ONLY.
# DOES NOT: Manage the array itself (add/remove/reorder logic lives in
#           JuiceArrayEditor). Does not handle sub-inspector embedding —
#           emits signals so the parent can manage expansion state.
# =============================================================================

@tool
class_name JuiceResourceRow
extends HBoxContainer


# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when the user clicks the resource name to expand/collapse.
signal expand_toggled(row_index: int)

## Emitted when the user clicks the delete button.
signal delete_requested(row_index: int)

## Emitted when the user selects an action from the ⋮ context menu.
## Actions: &"save", &"save_as", &"load", &"quick_load", &"copy", &"paste", &"clear"
signal menu_action_requested(row_index: int, action: StringName)

## Emitted when a row is dropped onto this row for reorder.
## from_index = the dragged row, to_index = this row (drop target).
signal drag_reorder_requested(from_index: int, to_index: int)


# =============================================================================
# CONFIGURATION
# =============================================================================

## Current array index of this row (0-based). Displayed as the index label.
var row_index: int = 0

## Color for the type-indicator strip on the left edge.
var type_color: Color = Color(0.4, 0.4, 0.4)

## Whether this row is currently expanded (showing sub-inspector below).
var is_expanded: bool = false


# =============================================================================
# INTERNAL STATE
# =============================================================================

# UI elements — created once in _build_ui(), updated in refresh().
var _color_strip: ColorRect
var _grab_handle: TextureRect
var _index_label: Label
var _menu_button: MenuButton
var _icon_rect: TextureRect
var _name_button: Button
var _delete_button: Button

# Cached resource reference for display updates.
var _resource: Resource = null

# Theme icon cache — populated on first _build_ui() call.
var _icon_triple_bar: Texture2D
var _icon_remove: Texture2D


# =============================================================================
# LIFECYCLE
# =============================================================================

func _init() -> void:
	# Build UI immediately so the row is ready when added to the tree.
	_build_ui()


func _ready() -> void:
	# Fetch editor theme icons once the node is in the scene tree.
	_cache_theme_icons()
	_apply_theme_icons()


# =============================================================================
# PUBLIC API
# =============================================================================

## Configure the row for a specific resource at a given array index.
## Call this after adding the row to the tree, or when the array reorders.
func setup(index: int, resource: Resource, color: Color) -> void:
	row_index = index
	_resource = resource
	type_color = color

	# Disconnect previous changed signal if any.
	if _resource != null and _resource.changed.is_connected(_on_resource_changed):
		_resource.changed.disconnect(_on_resource_changed)

	# Connect to resource changes for live label updates.
	if _resource != null:
		_resource.changed.connect(_on_resource_changed)

	refresh()


## Update the visual state of the row from the current resource data.
## Called after setup() and whenever the resource emits changed.
func refresh() -> void:
	if _index_label:
		_index_label.text = str(row_index)

	if _color_strip:
		_color_strip.color = type_color

	if _name_button:
		var display_name := _get_display_name()
		_name_button.text = display_name
		_name_button.tooltip_text = display_name if display_name.length() > 30 else ""

	if _icon_rect and _resource != null:
		var icon := _get_resource_icon()
		if icon:
			_icon_rect.texture = icon
			_icon_rect.visible = true
		else:
			_icon_rect.visible = false


# =============================================================================
# UI CONSTRUCTION
# =============================================================================

# Builds the row layout:
# [▌color strip] [≡ grab] [#idx] [⋮ menu] [icon + name ————————] [🗑 delete]
func _build_ui() -> void:
	# Row container settings
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 2)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# --- Color strip ---
	# Thin vertical bar on the far left indicating the Juice resource family.
	_color_strip = ColorRect.new()
	_color_strip.custom_minimum_size = Vector2(3, 0)
	_color_strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_color_strip.color = type_color
	add_child(_color_strip)

	# --- Grab handle ---
	# Three-line icon for drag-to-reorder. Matches native Godot array convention.
	# The grab handle is the drag source; the entire row is the drop target.
	_grab_handle = TextureRect.new()
	_grab_handle.custom_minimum_size = Vector2(16, 16)
	_grab_handle.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_grab_handle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_grab_handle.tooltip_text = "Drag to reorder"
	_grab_handle.mouse_default_cursor_shape = Control.CURSOR_DRAG
	add_child(_grab_handle)

	# --- Index label ---
	# Array index number for coder reference.
	_index_label = Label.new()
	_index_label.text = "0"
	_index_label.custom_minimum_size = Vector2(20, 0)
	_index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_index_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_index_label.add_theme_font_size_override("font_size", 11)
	_index_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.5))
	add_child(_index_label)

	# --- Context menu (⋮) ---
	# MenuButton for resource operations: Save, Save As, Load, Quick Load,
	# Copy, Paste, Clear. Placed left of the name, away from the delete button.
	_menu_button = MenuButton.new()
	_menu_button.flat = true
	_menu_button.tooltip_text = "Resource actions"
	_menu_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Populate menu items.
	var popup := _menu_button.get_popup()
	popup.add_item("Save", 0)
	popup.add_item("Save As...", 1)
	popup.add_separator()
	popup.add_item("Load...", 2)
	popup.add_item("Quick Load...", 3)
	popup.add_separator()
	popup.add_item("Copy", 4)
	popup.add_item("Paste", 5)
	popup.add_separator()
	popup.add_item("Clear", 6)
	popup.id_pressed.connect(_on_menu_id_pressed)
	add_child(_menu_button)

	# --- Resource icon ---
	# Shows the class-specific icon next to the name.
	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(16, 16)
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_rect.visible = false
	add_child(_icon_rect)

	# --- Resource name button ---
	# Displays resource_name or class_name fallback. Click toggles expand.
	# Stretches to fill all remaining horizontal space (no wasted width).
	_name_button = Button.new()
	_name_button.flat = true
	_name_button.text = ""
	_name_button.clip_text = true
	_name_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_button.pressed.connect(_on_name_pressed)
	add_child(_name_button)

	# --- Delete button ---
	# Trash icon on the far right. Visually separated from the ⋮ menu.
	_delete_button = Button.new()
	_delete_button.flat = true
	_delete_button.tooltip_text = "Remove element"
	_delete_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_delete_button.pressed.connect(_on_delete_pressed)
	add_child(_delete_button)


# =============================================================================
# THEME
# =============================================================================

# Cache editor theme icons so we don't fetch them every frame.
func _cache_theme_icons() -> void:
	var base := _get_theme_source()
	if base == null:
		return
	_icon_triple_bar = base.get_theme_icon("TripleBar", "EditorIcons")
	_icon_remove = base.get_theme_icon("Remove", "EditorIcons")


# Apply cached icons to the UI elements.
func _apply_theme_icons() -> void:
	if _icon_triple_bar and _grab_handle:
		_grab_handle.texture = _icon_triple_bar
	if _icon_remove and _delete_button:
		_delete_button.icon = _icon_remove

	# ⋮ menu icon — use ContextMenu icon for the three-dot appearance.
	var base := _get_theme_source()
	if base and _menu_button:
		var ctx_icon := base.get_theme_icon("GuiTabMenuHl", "EditorIcons")
		if ctx_icon:
			_menu_button.icon = ctx_icon
		else:
			# Fallback: use the text "⋮" if the icon isn't available.
			_menu_button.text = "⋮"


# Find a valid theme source control for fetching editor icons.
func _get_theme_source() -> Control:
	# Walk up the tree to find an ancestor with theme data.
	var node: Node = self
	while node != null:
		if node is Control:
			var ctrl := node as Control
			if ctrl.has_theme_icon("TripleBar", "EditorIcons"):
				return ctrl
		node = node.get_parent()
	return null


# =============================================================================
# HELPERS
# =============================================================================

# Get a human-readable display name for the current resource.
# Priority: resource_name > script class_name > native class name > "(empty)"
func _get_display_name() -> String:
	if _resource == null:
		return "(empty)"
	if not _resource.resource_name.is_empty():
		return _resource.resource_name
	# Fallback to the script's class_name, which is more specific than
	# the native get_class() (which returns "Resource" for GDScript objects).
	var script := _resource.get_script() as GDScript
	if script != null:
		var global_name := script.get_global_name()
		if not global_name.is_empty():
			return global_name
	return _resource.get_class()


# Get the editor theme icon for the resource's class.
func _get_resource_icon() -> Texture2D:
	if _resource == null:
		return null
	var base := _get_theme_source()
	if base == null:
		return null
	# Try script class_name first (e.g. "InterpolatePropertyTarget").
	var script := _resource.get_script() as GDScript
	if script != null:
		var global_name := script.get_global_name()
		if not global_name.is_empty() and base.has_theme_icon(global_name, "EditorIcons"):
			return base.get_theme_icon(global_name, "EditorIcons")
	# Fallback to native class name.
	var native_class := _resource.get_class()
	if base.has_theme_icon(native_class, "EditorIcons"):
		return base.get_theme_icon(native_class, "EditorIcons")
	# Final fallback: generic Resource icon.
	return base.get_theme_icon("Resource", "EditorIcons")


# =============================================================================
# DRAG-AND-DROP REORDER
# =============================================================================

# Provide drag data when the user drags the grab handle.
# The entire row is the drag source; data carries the row_index.
func _get_drag_data(_at_position: Vector2) -> Variant:
	# Only allow dragging from the grab handle area (left 36px: strip + handle).
	if _at_position.x > 40:
		return null
	# Create a visual preview of the dragged row.
	var preview := Label.new()
	preview.text = _get_display_name()
	preview.add_theme_color_override("font_color", type_color)
	set_drag_preview(preview)
	return {"type": &"juice_row_reorder", "from_index": row_index}


# Accept drops from other JuiceResourceRows.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	return data.get("type", &"") == &"juice_row_reorder"


# Handle the drop — emit signal with from/to indices so the parent can reorder.
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	var from_index: int = data.get("from_index", -1)
	if from_index < 0 or from_index == row_index:
		return
	drag_reorder_requested.emit(from_index, row_index)


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

# Resource name click — toggle expand/collapse.
func _on_name_pressed() -> void:
	is_expanded = not is_expanded
	expand_toggled.emit(row_index)


# Delete button click.
func _on_delete_pressed() -> void:
	delete_requested.emit(row_index)


# Context menu item selected.
func _on_menu_id_pressed(id: int) -> void:
	var action_map: Dictionary = {
		0: &"save",
		1: &"save_as",
		2: &"load",
		3: &"quick_load",
		4: &"copy",
		5: &"paste",
		6: &"clear",
	}
	var action: StringName = action_map.get(id, &"")
	if not action.is_empty():
		menu_action_requested.emit(row_index, action)


# Resource changed — update the display label in real time.
func _on_resource_changed() -> void:
	refresh()
