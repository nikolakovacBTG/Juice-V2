## Custom array editor for Juice typed Resource arrays. Replaces the native
## Godot array inspector with a unified row-based UI using JuiceResourceRow.
##
## Handles single-type auto-creation, multi-type picker popup,
## inline expand/collapse, delete, and drag-to-reorder.

# =============================================================================
# WHAT: EditorProperty that replaces Godot's default array inspector for Juice
#       typed Resource arrays. Renders each element as a JuiceResourceRow with
#       consistent UX across all Juice arrays.
# WHY:  Godot's native array editor shows raw class names, requires multiple
#       clicks to add resources, and wastes horizontal space. This editor shows
#       resource_name labels, auto-creates single-type entries on one click,
#       and provides a ⋮ context menu for resource operations — all in a
#       uniform layout that matches Godot conventions.
# SYSTEM: Juice System (addons/Juice_V2/Editor/) — EDITOR ONLY.
# DOES NOT: Handle chain_to sibling-reference arrays (Phase 3). Does not
#           modify the resource data model — only reads/writes the array.
# =============================================================================

@tool
class_name JuiceArrayEditor
extends EditorProperty


# =============================================================================
# CONFIGURATION
# =============================================================================

## The base class name from the array hint_string (e.g. "InterpolatePropertyTarget").
var _element_class_name: String = ""

## Concrete class names for multi-type arrays (parsed from comma-separated hint).
var _concrete_classes: PackedStringArray = []

## Whether this array accepts only one concrete type (auto-create on Add).
var _is_single_type: bool = true

## Color for the type-indicator strip on row left edges.
var _type_color: Color = Color(0.4, 0.4, 0.4)

## Label for the add button (e.g. "+ Add Juice", "+ Add Method").
var _add_label: String = "+ Add Element"


# =============================================================================
# INTERNAL STATE
# =============================================================================

# UI containers.
var _main_vbox: VBoxContainer
var _header_hbox: HBoxContainer
var _rows_container: VBoxContainer
var _size_spin: SpinBox
var _add_button: Button

# Per-row state tracking.
# Maps array index → bool (true = expanded).
var _expanded: Dictionary = {}

# Maps array index → EditorInspector (created on expand, freed on collapse).
var _sub_inspectors: Dictionary = {}

# Multi-type popup menu (created lazily).
var _type_popup: PopupMenu = null

# File dialog for Save As / Load (created lazily, reused).
var _file_dialog: EditorFileDialog = null

# Tracks which action the file dialog is performing and for which index.
var _file_dialog_action: StringName = &""
var _file_dialog_index: int = -1

# Tracks which array index the type picker should fill (-1 = append mode).
var _type_picker_target_index: int = -1

# Guard against re-entrant _update_property calls during our own emit_changed.
var _updating: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _init() -> void:
	# EditorProperty label configuration.
	# We draw no label on the left — the array header handles that.
	label = ""
	_build_ui()


# =============================================================================
# PUBLIC API
# =============================================================================

## Configure the editor for a specific array property.
## Called by the inspector plugin after creating this editor.
## [param element_hint]: The hint_string from _parse_property (class name or
##   comma-separated "Class1,Class2,..." format after normalization).
## [param hint_type]: The PropertyHint enum value.
## [param color]: Type-color for the row strips.
## [param add_label]: Label for the add button (e.g. "+ Add Juice").
func configure(element_hint: String, hint_type: int, color: Color, add_label: String = "+ Add Element") -> void:
	_type_color = color
	_add_label = add_label
	if _add_button:
		_add_button.text = add_label

	# Parse the hint_string to determine element type(s).
	# After normalization in the plugin, element_hint is always a plain class
	# name or comma-separated list (the "24/17:" prefix has been stripped).
	if "," in element_hint:
		# Multi-type: "Class1,Class2,..."
		_concrete_classes = element_hint.split(",", false)
		_is_single_type = _concrete_classes.size() <= 1
		if _concrete_classes.size() > 0:
			_element_class_name = _concrete_classes[0]
	else:
		# Single class name.
		_element_class_name = element_hint.strip_edges()
		_concrete_classes = PackedStringArray([_element_class_name])
		_is_single_type = true


# =============================================================================
# EditorProperty API
# =============================================================================

## Called by the inspector whenever the property value changes.
## Rebuilds the row list from the current array data.
func _update_property() -> void:
	if _updating:
		return
	_updating = true

	var array: Array = _get_current_array()

	# Update size display.
	_size_spin.set_value_no_signal(array.size())

	# Preserve expand state, clean up stale sub-inspectors.
	_cleanup_stale_inspectors(array.size())

	# Rebuild rows.
	_rebuild_rows(array)

	_updating = false


# =============================================================================
# UI CONSTRUCTION
# =============================================================================

# Build the editor layout:
#   [Header: Size spinner + Add button]
#   [Rows container: JuiceResourceRow per element]
func _build_ui() -> void:
	_main_vbox = VBoxContainer.new()
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.add_theme_constant_override("separation", 0)

	# --- Header ---
	_header_hbox = HBoxContainer.new()
	_header_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_hbox.add_theme_constant_override("separation", 4)

	# Size label + spinner.
	var size_label := Label.new()
	size_label.text = "Size:"
	size_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header_hbox.add_child(size_label)

	_size_spin = SpinBox.new()
	_size_spin.min_value = 0
	_size_spin.max_value = 999
	_size_spin.step = 1
	_size_spin.custom_minimum_size.x = 60
	_size_spin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_size_spin.value_changed.connect(_on_size_changed)
	_header_hbox.add_child(_size_spin)

	# Spacer.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_hbox.add_child(spacer)

	# Add button.
	_add_button = Button.new()
	_add_button.text = _add_label
	_add_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_add_button.pressed.connect(_on_add_pressed)
	_header_hbox.add_child(_add_button)

	_main_vbox.add_child(_header_hbox)

	# --- Rows container ---
	_rows_container = VBoxContainer.new()
	_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_container.add_theme_constant_override("separation", 1)
	_main_vbox.add_child(_rows_container)

	# Place the whole layout below the property label line.
	add_child(_main_vbox)
	set_bottom_editor(_main_vbox)


# =============================================================================
# ROW MANAGEMENT
# =============================================================================

# Clear existing rows and rebuild from the array data.
func _rebuild_rows(array: Array) -> void:
	# Remove old rows and sub-inspectors from the container.
	for child in _rows_container.get_children():
		_rows_container.remove_child(child)
		child.queue_free()

	# Clear sub-inspector references (they were just freed above).
	_sub_inspectors.clear()

	# Create a row for each element.
	for i in range(array.size()):
		var resource: Resource = array[i] as Resource

		# Build the row.
		var row := JuiceResourceRow.new()
		_rows_container.add_child(row)
		row.setup(i, resource, _type_color)

		# Restore expand state if previously expanded.
		row.is_expanded = _expanded.get(i, false)

		# Connect row signals.
		row.expand_toggled.connect(_on_row_expand_toggled)
		row.delete_requested.connect(_on_row_delete)
		row.resource_replaced.connect(_on_row_resource_replaced)
		row.drag_reorder_requested.connect(_on_row_reorder)

		# If expanded, create the sub-inspector below this row.
		if row.is_expanded and resource != null:
			_create_sub_inspector(i, resource)


# Create an embedded EditorInspector below the row at the given index.
# This shows the resource's properties inline, matching Godot's native
# sub-resource expansion behavior.
# - Scrolling is DISABLED so the inspector expands to full content height.
# - Background uses Godot's theme-native sub_inspector_bg StyleBox for
#   proper depth coloring that works with all editor themes.
func _create_sub_inspector(index: int, resource: Resource) -> void:
	var sub_inspector := EditorInspector.new()
	sub_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# CRITICAL: Disable scrolling so the inspector sizes to its content
	# instead of clipping into a fixed scroll area. This matches how Godot's
	# native array inspector embeds sub-resource editors inline.
	sub_inspector.set_vertical_scroll_mode(ScrollContainer.SCROLL_MODE_DISABLED)
	sub_inspector.set_horizontal_scroll_mode(ScrollContainer.SCROLL_MODE_DISABLED)

	# Wrap in a PanelContainer with the native sub-inspector depth background.
	# Godot provides sub_inspector_bg0..4 in EditorStyles for nested depth coloring.
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var editor_theme := EditorInterface.get_editor_theme()
	if editor_theme:
		# Use depth 1 by default (the first nesting level).
		var depth_style := editor_theme.get_stylebox("sub_inspector_bg1", "EditorStyles")
		if depth_style:
			panel.add_theme_stylebox_override("panel", depth_style)
	panel.add_child(sub_inspector)

	# Indent the panel to visually nest it under the row.
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(panel)

	# Insert the margin container right after the row in the VBox.
	var row_node := _get_row_at(index)
	if row_node:
		var row_idx := row_node.get_index()
		_rows_container.add_child(margin)
		_rows_container.move_child(margin, row_idx + 1)

	# Defer edit() so the inspector has time to be added to the tree first.
	sub_inspector.call_deferred("edit", resource)
	_sub_inspectors[index] = margin


# Remove sub-inspectors for indices that no longer exist.
func _cleanup_stale_inspectors(new_size: int) -> void:
	var to_remove: Array[int] = []
	for idx: int in _expanded.keys():
		if idx >= new_size:
			to_remove.append(idx)
	for idx in to_remove:
		_expanded.erase(idx)
		if _sub_inspectors.has(idx):
			var container = _sub_inspectors[idx]
			if is_instance_valid(container):
				container.queue_free()
			_sub_inspectors.erase(idx)


# Find the JuiceResourceRow node at the given array index.
func _get_row_at(index: int) -> JuiceResourceRow:
	for child in _rows_container.get_children():
		if child is JuiceResourceRow and child.row_index == index:
			return child
	return null


# =============================================================================
# ARRAY MUTATIONS
# =============================================================================

# Get the current array value from the edited object.
func _get_current_array() -> Array:
	var obj := get_edited_object()
	if obj == null:
		return []
	var val = obj.get(get_edited_property())
	if val is Array:
		return val
	return []


# Commit a new array value to the edited object.
# Uses emit_changed which integrates with the editor's undo/redo system.
func _commit_array(new_array: Array) -> void:
	emit_changed(get_edited_property(), new_array)


# =============================================================================
# RESOURCE INSTANTIATION
# =============================================================================

# Create a new instance of the given class name.
# Handles both native ClassDB classes and GDScript global classes.
func _instantiate_class(class_name_str: String) -> Resource:
	# Strategy 1: Native ClassDB.
	if ClassDB.class_exists(class_name_str) and ClassDB.can_instantiate(class_name_str):
		var instance = ClassDB.instantiate(class_name_str)
		if instance is Resource:
			return instance

	# Strategy 2: GDScript global classes — search ProjectSettings registry.
	for cls: Dictionary in ProjectSettings.get_global_class_list():
		if cls.get("class", "") == class_name_str:
			var script_path: String = cls.get("path", "")
			if script_path.is_empty():
				continue
			var script := load(script_path)
			if script is GDScript:
				var instance = script.new()
				if instance is Resource:
					return instance
			break

	push_warning("[JuiceArrayEditor] Cannot instantiate class '%s'." % class_name_str)
	return null


# =============================================================================
# SIGNAL HANDLERS — Header
# =============================================================================

# Size spinner changed — resize the array (add nulls or truncate).
func _on_size_changed(new_size: float) -> void:
	if _updating:
		return
	var array := _get_current_array().duplicate()
	var target := int(new_size)

	while array.size() < target:
		if _is_single_type and not _element_class_name.is_empty():
			array.append(_instantiate_class(_element_class_name))
		else:
			array.append(null)

	if array.size() > target:
		array.resize(target)

	_commit_array(array)


# Add button pressed.
func _on_add_pressed() -> void:
	if _is_single_type:
		# Single-type: auto-create and append immediately.
		_add_single_type_element()
	else:
		# Multi-type: show picker popup.
		_show_type_picker()


# Single-type add: create the resource and append to the array.
func _add_single_type_element() -> void:
	if _element_class_name.is_empty():
		return
	var resource := _instantiate_class(_element_class_name)
	if resource == null:
		return
	var array := _get_current_array().duplicate()
	array.append(resource)
	_commit_array(array)


# Multi-type add: show a popup with available types.
func _show_type_picker() -> void:
	_type_picker_target_index = -1  # -1 = append mode
	_show_type_picker_at(_add_button)


# Multi-type replace: show a popup to fill an empty slot at a specific index.
func _show_type_picker_for_index(index: int) -> void:
	_type_picker_target_index = index
	var row := _get_row_at(index)
	if row:
		_show_type_picker_at(row)
	else:
		_show_type_picker_at(_add_button)


# Show the type picker popup positioned below the given control.
# In append mode (_type_picker_target_index == -1): multi-select with checkboxes.
#   The popup stays open so the user can check multiple types, then all checked
#   items are batch-created when the popup is dismissed.
# In replace mode (_type_picker_target_index >= 0): single-click instant create.
#   Clicking an item immediately fills that slot and closes the popup.
func _show_type_picker_at(anchor: Control) -> void:
	var is_multi_select := (_type_picker_target_index == -1)

	if _type_popup == null:
		_type_popup = PopupMenu.new()
		_type_popup.id_pressed.connect(_on_type_selected)
		add_child(_type_popup)

	# Multi-select: keep popup open on check; commit on dismiss.
	# Single-select: close on click (default behavior).
	_type_popup.hide_on_checkable_item_selection = false

	# Disconnect previous popup_hide to avoid stacking.
	if _type_popup.popup_hide.is_connected(_on_type_picker_closed):
		_type_popup.popup_hide.disconnect(_on_type_picker_closed)
	if is_multi_select:
		_type_popup.popup_hide.connect(_on_type_picker_closed)

	_type_popup.clear()
	for i in range(_concrete_classes.size()):
		var cls_name: String = _concrete_classes[i]
		var icon := _get_class_icon(cls_name)
		if is_multi_select:
			if icon:
				_type_popup.add_icon_check_item(icon, cls_name, i)
			else:
				_type_popup.add_check_item(cls_name, i)
		else:
			if icon:
				_type_popup.add_icon_item(icon, cls_name, i)
			else:
				_type_popup.add_item(cls_name, i)

	# Position the popup below the anchor control.
	var anchor_rect := anchor.get_global_rect()
	_type_popup.position = Vector2i(int(anchor_rect.position.x), int(anchor_rect.end.y))
	_type_popup.popup()


# Type picker selection callback.
# Replace mode: instant-create the selected class into the target slot.
# Multi-select append mode: toggle the checkbox; actual creation happens on dismiss.
func _on_type_selected(id: int) -> void:
	if id < 0 or id >= _concrete_classes.size():
		return

	# Multi-select append mode: just toggle the checkbox.
	if _type_picker_target_index == -1 and _type_popup != null:
		var item_idx := _type_popup.get_item_index(id)
		var currently_checked := _type_popup.is_item_checked(item_idx)
		_type_popup.set_item_checked(item_idx, not currently_checked)
		return

	# Replace mode: create one instance and fill the slot.
	var cls_name: String = _concrete_classes[id]
	var resource := _instantiate_class(cls_name)
	if resource == null:
		return
	var array := _get_current_array().duplicate()

	if _type_picker_target_index >= 0 and _type_picker_target_index < array.size():
		array[_type_picker_target_index] = resource
	else:
		array.append(resource)

	_commit_array(array)


# Multi-select popup dismissed: batch-create all checked types and append.
# Each checked item creates one new instance. This is a single undo/redo action.
func _on_type_picker_closed() -> void:
	if _type_popup == null:
		return

	var array := _get_current_array().duplicate()
	var added_any := false

	for i in range(_type_popup.get_item_count()):
		if _type_popup.is_item_checked(i):
			var id := _type_popup.get_item_id(i)
			if id >= 0 and id < _concrete_classes.size():
				var cls_name: String = _concrete_classes[id]
				var resource := _instantiate_class(cls_name)
				if resource != null:
					array.append(resource)
					added_any = true

	if added_any:
		_commit_array(array)


# =============================================================================
# SIGNAL HANDLERS — Row
# =============================================================================

# Row expand/collapse toggled.
# If the slot is empty (null resource) and this is a single-type array,
# auto-create a resource instead of trying to expand nothing.
func _on_row_expand_toggled(index: int) -> void:
	var array := _get_current_array()
	if index < 0 or index >= array.size():
		return

	# Handle empty slot: auto-create for single-type, show picker for multi-type.
	if array[index] == null:
		if _is_single_type and not _element_class_name.is_empty():
			var new_res := _instantiate_class(_element_class_name)
			if new_res:
				var new_array := array.duplicate()
				new_array[index] = new_res
				_commit_array(new_array)
		else:
			_show_type_picker_for_index(index)
		return

	var was_expanded: bool = _expanded.get(index, false)
	_expanded[index] = not was_expanded

	if _expanded[index]:
		# Expand: create sub-inspector.
		if array[index] is Resource:
			_create_sub_inspector(index, array[index] as Resource)
	else:
		# Collapse: remove sub-inspector.
		if _sub_inspectors.has(index):
			var container = _sub_inspectors[index]
			if is_instance_valid(container):
				_rows_container.remove_child(container)
				container.queue_free()
			_sub_inspectors.erase(index)


# Row delete requested.
func _on_row_delete(index: int) -> void:
	var array := _get_current_array().duplicate()
	if index < 0 or index >= array.size():
		return

	# Clean up expand state for this and shifted indices.
	_expanded.erase(index)
	var new_expanded: Dictionary = {}
	for key: int in _expanded.keys():
		if key > index:
			new_expanded[key - 1] = _expanded[key]
		else:
			new_expanded[key] = _expanded[key]
	_expanded = new_expanded

	array.remove_at(index)
	_commit_array(array)


# Row drag-reorder completed.
func _on_row_reorder(from_index: int, to_index: int) -> void:
	var array := _get_current_array().duplicate()
	if from_index < 0 or from_index >= array.size():
		return
	if to_index < 0 or to_index >= array.size():
		return
	var element = array[from_index]
	array.remove_at(from_index)
	array.insert(to_index, element)
	# Reset expand state — indices shifted.
	_expanded.clear()
	_commit_array(array)


# Row resource replaced via EditorResourcePicker (New, Load, Paste, etc.).
# Commits the new resource to the backing array at the given index.
func _on_row_resource_replaced(index: int, new_resource: Resource) -> void:
	var array := _get_current_array().duplicate()
	if index < 0 or index >= array.size():
		return
	array[index] = new_resource
	_commit_array(array)


# =============================================================================
# HELPERS
# =============================================================================

# Get the editor theme icon for a class name.
# Checks the @icon annotation in the global class list for GDScript classes,
# then falls back to EditorIcons for native classes.
func _get_class_icon(class_name_str: String) -> Texture2D:
	# Strategy 1: GDScript @icon annotation from global class list.
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
				current = cls.get("base", "")
				break
		if current.is_empty():
			break

	# Strategy 2: Native class icon from EditorIcons theme.
	var base := _get_theme_source()
	if base and base.has_theme_icon(class_name_str, "EditorIcons"):
		return base.get_theme_icon(class_name_str, "EditorIcons")
	return null


# Find a valid theme source control.
func _get_theme_source() -> Control:
	var node: Node = self
	while node != null:
		if node is Control:
			var ctrl := node as Control
			if ctrl.has_theme_icon("Resource", "EditorIcons"):
				return ctrl
		node = node.get_parent()
	return null
