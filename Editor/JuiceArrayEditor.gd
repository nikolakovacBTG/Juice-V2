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
# DOES NOT: Handle chain_to sibling-reference arrays (see ChainToArrayEditor). Does not
#           modify the resource data model — only reads/writes the array.
# =============================================================================

@tool
class_name JuiceArrayEditor
extends EditorProperty


# Debug toggle — set true to print interception and instantiation decisions.
const DEBUG := false

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

## Nesting depth for sub-inspector depth coloring.
## 0 = top-level array, 1 = nested inside a sub-inspector, etc.
var _depth: int = 0


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


# Auto-detect nesting depth when added to the scene tree.
# Walks the parent chain and counts EditorInspector ancestors — each one
# represents a sub-inspector we are nested inside. Top-level arrays have
# depth 0, arrays inside an expanded sub-inspector have depth 1, etc.
# This makes depth coloring work automatically without the plugin needing
# to pass depth explicitly.
func _notification(what: int) -> void:
	if what == NOTIFICATION_POST_ENTER_TREE:
		_depth = _count_editor_depth()


# Count EditorInspector ancestors to determine nesting depth.
# The main inspector (dock-level) doesn't count — only embedded
# sub-inspectors created by _create_sub_inspector do.
func _count_editor_depth() -> int:
	var count := 0
	var node: Node = get_parent()
	while node != null:
		if node is EditorInspector:
			count += 1
		node = node.get_parent()
	# Subtract 1: the outermost EditorInspector is the main dock inspector,
	# not a sub-inspector. Arrays inside it are at depth 0.
	return maxi(count - 1, 0)


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
## [param depth]: Nesting depth for sub-inspector depth coloring (0 = top-level).
func configure(element_hint: String, hint_type: int, color: Color, add_label: String = "+ Add Element", depth: int = 0) -> void:
	_type_color = color
	_add_label = add_label
	_depth = depth
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
		row.setup(i, resource, _type_color, _depth, ",".join(_concrete_classes))

		# Restore expand state if previously expanded.
		row.is_expanded = _expanded.get(i, false)

		# Connect row signals.
		row.expand_toggled.connect(_on_row_expand_toggled)
		row.delete_requested.connect(_on_row_delete)
		row.resource_replaced.connect(_on_row_resource_replaced)
		row.drag_reorder_requested.connect(_on_row_reorder)
		row.empty_slot_clicked.connect(_on_row_empty_slot_clicked)

		# If expanded, create the sub-inspector below this row.
		if row.is_expanded and resource != null:
			_create_sub_inspector(i, resource)


# Create an embedded EditorInspector below the row at the given index.
# - Scrolling is DISABLED so the inspector expands to full content height.
# - A theme-driven gray foundation (Editor.base_color) is placed underneath
#   so the semi-transparent depth StyleBoxes composite correctly.
# - Background uses Godot's theme-native sub_inspector_bg{depth} StyleBox
#   for proper depth coloring that works with all editor themes.
func _create_sub_inspector(index: int, resource: Resource) -> void:
	var sub_inspector := EditorInspector.new()
	sub_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# CRITICAL: Disable scrolling so the inspector sizes to its content
	# instead of clipping into a fixed scroll area. This matches how Godot's
	# native array inspector embeds sub-resource editors inline.
	sub_inspector.set_vertical_scroll_mode(ScrollContainer.SCROLL_MODE_DISABLED)
	sub_inspector.set_horizontal_scroll_mode(ScrollContainer.SCROLL_MODE_DISABLED)
	# EditorInspector inherits ScrollContainer which has an opaque background
	# style. Override it to transparent so the depth-colored panel behind it
	# shows through for proper depth tinting.
	sub_inspector.add_theme_stylebox_override("background", StyleBoxEmpty.new())

	var editor_theme := EditorInterface.get_editor_theme()

	# --- Gray foundation layer ---
	# Native Godot inspector sits on Editor.base_color (#292929 in default theme).
	# The depth StyleBoxes use semi-transparent colors that composite on top of
	# this gray. Without it, they blend against the too-dark dock panel (#1b1b1b)
	# and appear washed-out. This foundation ensures correct color compositing
	# regardless of which dock the inspector is placed in.
	var foundation := PanelContainer.new()
	foundation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foundation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if editor_theme:
		var base_style := StyleBoxFlat.new()
		base_style.bg_color = editor_theme.get_color("base_color", "Editor")
		foundation.add_theme_stylebox_override("panel", base_style)

	# --- Depth-colored overlay ---
	# Uses sub_inspector_bg{depth} from Godot's EditorStyles — each depth level
	# has a progressively different tint (blue → purple → pink) so users can
	# visually distinguish nesting levels.
	var depth_panel := PanelContainer.new()
	depth_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	depth_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if editor_theme:
		# Sub-inspector matches the depth of its parent array's rows.
		# maxi(1) avoids sub_inspector_bg0 which has a transparent background.
		var depth_key := "sub_inspector_bg%d" % clampi(maxi(_depth, 1), 0, 16)
		var depth_style := editor_theme.get_stylebox(depth_key, "EditorStyles")
		if depth_style:
			depth_panel.add_theme_stylebox_override("panel", depth_style)

	# Stack: foundation > depth overlay > sub-inspector
	depth_panel.add_child(sub_inspector)
	foundation.add_child(depth_panel)

	# Wrap in a MarginContainer for layout control in the VBox.
	# No extra left margin — the depth-colored StyleBox's own content_margin
	# provides sufficient visual nesting indent.
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(foundation)

	# Insert the margin container right after the row in the VBox.
	var row_node := _get_row_at(index)
	if row_node:
		var row_idx := row_node.get_index()
		_rows_container.add_child(margin)
		_rows_container.move_child(margin, row_idx + 1)

	# Defer edit() so the inspector has time to be added to the tree first.
	sub_inspector.call_deferred("edit", resource)
	# Post-process the sub-inspector after edit() populates it:
	# 1. Fold all section groups (compact layout)
	# 2. Bridge ## doc-comment tooltips to EditorProperty children
	# edit() is deferred, so sections won't exist until ≥1 frame later.
	# Uses string-based call_deferred for reliable execution.
	call_deferred("_post_process_sub_inspector", sub_inspector, resource)
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
# SUB-INSPECTOR FOLDING
# =============================================================================

# Post-process a sub-inspector after edit() populates its UI tree.
# Handles both folding (compact layout) and tooltip bridging in one pass.
# Called via call_deferred so the EditorProperty nodes exist.
func _post_process_sub_inspector(inspector: EditorInspector, resource: Resource) -> void:
	if not is_instance_valid(inspector):
		return
	# EditorInspector may need one more frame after edit() to populate.
	# If no sections found on first try, wait a frame and retry once.
	var found := _fold_sections_recursive(inspector)
	if not found and inspector.is_inside_tree():
		await inspector.get_tree().process_frame
		_fold_sections_recursive(inspector)
	# Now bridge ## doc-comment tooltips. At this point EditorProperty nodes
	# are guaranteed to exist (we just folded their sections).
	_apply_tooltips(inspector, resource)


# Walk a node tree and fold() every EditorInspectorSection. Returns true
# if at least one section was found (regardless of fold result).
# EditorInspectorSection is not exposed to GDScript's type system, so we
# use string-based class checking via get_class() and call fold() dynamically.
func _fold_sections_recursive(node: Node) -> bool:
	var found := false
	for child in node.get_children():
		if child.get_class() == "EditorInspectorSection":
			found = true
			child.call("fold")
		# Recurse into containers that may hold sections (VBoxContainer, etc.)
		if child.get_child_count() > 0:
			if _fold_sections_recursive(child):
				found = true
	return found


# =============================================================================
# SUB-INSPECTOR TOOLTIP BRIDGING
# =============================================================================

# Overlay script providing rich _make_custom_tooltip() for sub-inspector properties.
const _TooltipOverlay = preload("JuiceTooltipOverlay.gd")

# Cache of parsed tooltips per script resource_path. Avoids re-parsing the
# same script source every time a sub-inspector is expanded.
# Key: script.resource_path, Value: Dictionary { property_name: String → tooltip: String }
static var _tooltip_cache: Dictionary = {}


# Apply ## doc-comment tooltips to all EditorProperty children in a sub-inspector.
# Called via call_deferred after edit() so the EditorProperty nodes exist.
# Creates JuiceTooltipOverlay instances that intercept hover and render
# rich tooltips matching Godot's native inspector format.
func _apply_tooltips(inspector: EditorInspector, resource: Resource) -> void:
	if not is_instance_valid(inspector) or resource == null:
		return
	if not inspector.is_inside_tree():
		return
	var tooltips := _get_tooltips_for_resource(resource)
	if tooltips.is_empty():
		return
	# The EditorInspector overwrites tooltip data on children during its
	# multi-frame setup after edit(). Wait for it to fully stabilize before
	# adding our overlays so they don't get clobbered.
	for i in range(10):
		if not is_instance_valid(inspector) or not inspector.is_inside_tree():
			return
		await inspector.get_tree().process_frame
	_set_tooltips_recursive(inspector, tooltips, resource)


# Walk the node tree and add tooltip overlays to EditorProperty children.
# Returns the number of properties that received tooltips.
func _set_tooltips_recursive(node: Node, tooltips: Dictionary, resource: Resource) -> int:
	var count := 0
	for child in node.get_children():
		if child is EditorProperty:
			var prop_name: String = child.get_edited_property()
			if tooltips.has(prop_name):
				var tip: String = tooltips[prop_name]
				_set_tooltip_on_children(child, tip, resource)
				count += 1
		# Recurse into containers that hold EditorProperty nodes.
		if child.get_child_count() > 0:
			count += _set_tooltips_recursive(child, tooltips, resource)
	return count


# Add a rich tooltip overlay to an EditorProperty.
# The overlay intercepts hover and renders a styled tooltip matching Godot's
# native format via _make_custom_tooltip(). Clicks pass through to the value
# widgets underneath (mouse_filter = PASS).
func _set_tooltip_on_children(editor_property: EditorProperty, tip: String, resource: Resource) -> void:
	var prop_name: String = editor_property.get_edited_property()

	# Remove any previously added tooltip overlay (e.g., from a refresh).
	for child in editor_property.get_children():
		if child.name == "_juice_tooltip":
			child.queue_free()

	# Look up type and value from the resource's property list.
	var type_name := ""
	var value_str := ""
	for prop_info in resource.get_property_list():
		if prop_info.name == prop_name:
			type_name = _get_type_display_name(prop_info)
			value_str = _get_value_display(prop_info, resource)
			break

	# Create the transparent overlay with rich tooltip rendering.
	var overlay: Control = _TooltipOverlay.new()
	overlay.setup(prop_name, type_name, value_str, tip)
	overlay.name = "_juice_tooltip"
	editor_property.add_child(overlay)


# Convert a PropertyInfo dictionary to a human-readable type name.
# Handles enums, class names, and built-in types.
static func _get_type_display_name(prop_info: Dictionary) -> String:
	var type_int: int = prop_info.get("type", TYPE_NIL)
	var cn: String = prop_info.get("class_name", "")
	var hint: int = prop_info.get("hint", 0)

	# Class name takes priority (e.g., "JuiceRecipe", "Curve").
	if not cn.is_empty():
		return cn

	match type_int:
		TYPE_BOOL: return "bool"
		TYPE_INT:
			if hint == PROPERTY_HINT_ENUM:
				return "enum"
			return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR2I: return "Vector2i"
		TYPE_VECTOR3: return "Vector3"
		TYPE_VECTOR3I: return "Vector3i"
		TYPE_COLOR: return "Color"
		TYPE_NODE_PATH: return "NodePath"
		TYPE_OBJECT: return "Object"
		TYPE_ARRAY: return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		_: return ""


# Format the current property value for display in the tooltip header.
# For enums, resolves the int value to its name (e.g., "Position (1)").
static func _get_value_display(prop_info: Dictionary, resource: Resource) -> String:
	var prop_name: String = prop_info.get("name", "")
	var value = resource.get(prop_name)
	var hint: int = prop_info.get("hint", 0)
	var hint_string: String = prop_info.get("hint_string", "")

	# For enum properties, resolve the int to its human-readable name.
	if hint == PROPERTY_HINT_ENUM and value is int and not hint_string.is_empty():
		var entries := hint_string.split(",")
		for entry in entries:
			var parts := entry.split(":")
			if parts.size() == 2 and int(parts[1]) == value:
				return "%s (%d)" % [parts[0].strip_edges(), value]

	return str(value)


# Build a merged tooltip dictionary for a resource by walking its script
# inheritance chain. Subclass tooltips override base class tooltips for
# the same property name.
func _get_tooltips_for_resource(resource: Resource) -> Dictionary:
	var merged: Dictionary = {}
	var script: GDScript = resource.get_script() as GDScript
	while script != null:
		var path: String = script.resource_path
		if not path.is_empty():
			if not _tooltip_cache.has(path):
				_tooltip_cache[path] = _parse_doc_comments(script)
			var script_tips: Dictionary = _tooltip_cache[path]
			# Base class tooltips go in first, subclass overrides on top.
			for key in script_tips:
				merged[key] = script_tips[key]
		script = script.get_base_script()
	return merged


# Parse ## doc comments from a GDScript's source_code.
# Returns { property_name: tooltip_text } for every var declaration
# preceded by one or more ## comment lines.
static func _parse_doc_comments(script: GDScript) -> Dictionary:
	var tooltips: Dictionary = {}
	var source := String(script.source_code)
	if source.is_empty():
		return tooltips
	var lines := source.split("\n")
	var doc_lines: Array[String] = []
	for i in range(lines.size()):
		var line: String = lines[i].strip_edges()
		if line.begins_with("## ") or line == "##":
			var text: String = line.substr(2).strip_edges()
			if not text.is_empty():
				doc_lines.append(text)
		elif ("var " in line) and not line.begins_with("#"):
			if doc_lines.size() > 0:
				var var_idx: int = line.find("var ") + 4
				var rest: String = line.substr(var_idx)
				var name_end: int = rest.length()
				for j in range(rest.length()):
					if rest[j] == ":" or rest[j] == " " or rest[j] == "=":
						name_end = j
						break
				var var_name: String = rest.left(name_end)
				tooltips[var_name] = " ".join(doc_lines)
			doc_lines.clear()
		else:
			doc_lines.clear()
	return tooltips


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
			if DEBUG: print("[JuiceArrayEditor] Instantiated '%s' via ClassDB." % class_name_str)
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
					if DEBUG: print("[JuiceArrayEditor] Instantiated '%s' via GDScript (%s)." % [class_name_str, script_path])
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


# Row empty slot clicked — user clicked on a null resource slot.
# For multi-type arrays, show the type picker to fill the slot.
# For single-type arrays, auto-create the resource immediately.
func _on_row_empty_slot_clicked(index: int) -> void:
	if _is_single_type:
		# Auto-create and fill the slot.
		var resource := _instantiate_class(_element_class_name)
		if resource != null:
			var array := _get_current_array().duplicate()
			if index >= 0 and index < array.size():
				array[index] = resource
				_commit_array(array)
	else:
		# Multi-type: show the type picker positioned at this row.
		_show_type_picker_for_index(index)

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
