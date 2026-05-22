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

## Emitted when the user replaces the resource via the EditorResourcePicker
## (New, Load, Paste, Clear, etc.). The parent array editor commits this to the array.
signal resource_replaced(row_index: int, new_resource: Resource)

## Emitted when the user clicks an empty (null resource) slot.
## The parent array editor should show the type picker to fill this slot.
signal empty_slot_clicked(row_index: int)

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

## Nesting depth for theme background coloring. Received from parent
## JuiceArrayEditor which auto-detects it from the tree hierarchy.
var _depth: int = 0

## Cached background StyleBox from EditorStyles for this depth level.
var _row_bg_style: StyleBox = null


# =============================================================================
# INTERNAL STATE
# =============================================================================

# UI elements — created once in _build_ui(), updated in refresh().
var _color_strip: ColorRect
var _grab_handle: TextureRect
var _index_label: Label
var _resource_picker: EditorResourcePicker
var _picker_panel: PanelContainer
var _delete_button: Button

# Cached resource reference for display updates.
var _resource: Resource = null

# Comma-separated class names for the EditorResourcePicker's base_type.
var _base_type_string: String = ""

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
	_apply_picker_panel_style()


# =============================================================================
# PUBLIC API
# =============================================================================

## Configure the row for a specific resource at a given array index.
## Call this after adding the row to the tree, or when the array reorders.
## [param depth]: Nesting depth (0 = top-level array, 1 = nested, etc.).
##   Controls which sub_inspector_property_bg{N} StyleBox is used.
## [param base_type]: Comma-separated class names for the picker's allowed types.
func setup(index: int, resource: Resource, color: Color, depth: int = 0, base_type: String = "") -> void:
	row_index = index
	_resource = resource
	type_color = color
	_depth = depth
	_base_type_string = base_type

	# Disconnect previous changed signal if any.
	if _resource != null and _resource.changed.is_connected(_on_resource_changed):
		_resource.changed.disconnect(_on_resource_changed)

	# Connect to resource changes for live label updates.
	if _resource != null:
		_resource.changed.connect(_on_resource_changed)

	# Cache the depth-based row background StyleBox from the editor theme.
	_cache_row_bg_style()

	refresh()


## Update the visual state of the row from the current resource data.
## Called after setup() and whenever the resource emits changed.
func refresh() -> void:
	if _index_label:
		_index_label.text = str(row_index)

	if _color_strip:
		_color_strip.color = type_color

	if _resource_picker:
		_resource_picker.base_type = _base_type_string
		_resource_picker.edited_resource = _resource


# =============================================================================
# UI CONSTRUCTION
# =============================================================================

# Builds the row layout:
# [▌color strip] [≡ grab] [#idx] [EditorResourcePicker ————————] [🗑 delete]
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
	add_child(_index_label)

	# --- Resource picker (wrapped in dark panel) ---
	# Native Godot EditorResourcePicker provides: class icon, resource name,
	# and dropdown arrow with New/Load/Save/Copy/Paste/Clear.
	# Clicking the main field toggles expand/collapse (toggle_mode = true).
	# Wrapped in a PanelContainer that provides a dark gray (base_color)
	# background — the picker's flat buttons are transparent and show this
	# dark panel through, matching the native Recipe field's appearance.
	_resource_picker = EditorResourcePicker.new()
	_resource_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resource_picker.toggle_mode = true
	_resource_picker.resource_changed.connect(_on_picker_resource_changed)
	_resource_picker.resource_selected.connect(_on_picker_resource_selected)
	_picker_panel = PanelContainer.new()
	_picker_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_panel.add_child(_resource_picker)
	# Wrap in a margin container so the dark panel is 2px shorter than the row,
	# revealing thin horizontal lines of the row's depth color above/below.
	var picker_margin := MarginContainer.new()
	picker_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_margin.add_theme_constant_override("margin_top", 2)
	picker_margin.add_theme_constant_override("margin_bottom", 2)
	picker_margin.add_child(_picker_panel)
	add_child(picker_margin)

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


# Cache the depth-based row background StyleBox.
# Uses sub_inspector_property_bg{depth} from EditorStyles which provides the
# slightly tinted property-row background that distinguishes rows from their
# containing panel (sub_inspector_bg{depth}).
func _cache_row_bg_style() -> void:
	var editor_theme := EditorInterface.get_editor_theme()
	if editor_theme == null:
		return
	var key := "sub_inspector_property_bg%d" % clampi(_depth, 0, 16)
	_row_bg_style = editor_theme.get_stylebox(key, "EditorStyles")


# Style the PanelContainer wrapper around the EditorResourcePicker.
# Uses Editor.base_color (#292929) — the standard Godot inspector gray —
# so the picker field stands out from the colored row background (depth-tinted
# blue/purple). The picker's internal buttons are flat (transparent), so this
# panel's dark gray shows through them, matching the native Recipe field look.
func _apply_picker_panel_style() -> void:
	if _picker_panel == null:
		return
	var editor_theme := EditorInterface.get_editor_theme()
	if editor_theme == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = editor_theme.get_color("dark_color_1", "Editor")
	style.set_corner_radius_all(3)
	_picker_panel.add_theme_stylebox_override("panel", style)



# Paint the row background using the cached depth-based StyleBox.
# This runs every frame the row is visible, but StyleBox.draw() is a single
# GPU draw call — negligible cost.
func _draw() -> void:
	if _row_bg_style:
		_row_bg_style.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))


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
# Uses the @icon annotation from ProjectSettings global class list for GDScript
# classes, since they are not registered in the EditorIcons theme type.
func _get_resource_icon() -> Texture2D:
	if _resource == null:
		return null
	# For GDScript resources: check the global class list for an @icon path.
	var script := _resource.get_script() as GDScript
	if script != null:
		var global_name := script.get_global_name()
		if not global_name.is_empty():
			var icon_tex := _get_global_class_icon(global_name)
			if icon_tex:
				return icon_tex
	# Fallback: try native class icon from EditorIcons theme.
	var base := _get_theme_source()
	if base == null:
		return null
	var native_class := _resource.get_class()
	if base.has_theme_icon(native_class, "EditorIcons"):
		return base.get_theme_icon(native_class, "EditorIcons")
	return null


# Look up the @icon path for a GDScript global class name.
# Walks the inheritance chain to find the nearest class with an icon.
func _get_global_class_icon(class_name_str: String) -> Texture2D:
	var global_classes: Array[Dictionary] = ProjectSettings.get_global_class_list()
	var current := class_name_str
	for _depth in range(20):
		for cls: Dictionary in global_classes:
			if cls.get("class", "") == current:
				var icon_path: String = cls.get("icon", "")
				if not icon_path.is_empty():
					var tex := load(icon_path) as Texture2D
					if tex:
						return tex
				# No icon on this class — try the parent.
				current = cls.get("base", "")
				break
		if current.is_empty():
			break
	return null





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

# EditorResourcePicker — user selected a new resource (New, Load, Paste, etc.).
# The picker already holds the new resource internally. We emit a signal
# so the parent JuiceArrayEditor commits it to the backing array.
func _on_picker_resource_changed(new_resource: Resource) -> void:
	_resource = new_resource
	resource_replaced.emit(row_index, new_resource)


# EditorResourcePicker — user clicked the resource field to edit/inspect.
# With toggle_mode=true, this acts as expand/collapse for the sub-inspector.
# For empty slots (null resource), emit empty_slot_clicked so the parent
# can show a type picker instead of the native Quick Load/Load menu.
func _on_picker_resource_selected(_resource_arg: Resource, _inspect: bool) -> void:
	if _resource == null:
		empty_slot_clicked.emit(row_index)
		return
	is_expanded = not is_expanded
	expand_toggled.emit(row_index)


# Delete button click.
func _on_delete_pressed() -> void:
	delete_requested.emit(row_index)



# Resource changed — update the picker display in real time.
func _on_resource_changed() -> void:
	refresh()
