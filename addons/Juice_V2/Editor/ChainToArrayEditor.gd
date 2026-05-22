## Custom array editor for the chain_to property on JuiceEffectBase.
## Replaces the native Godot array inspector with a sibling-picker popup
## that shows only the effects already present in the same recipe.
##
## Reuses JuiceResourceRow for each chain_to entry (same row UX as other
## Juice arrays — dark field, depth coloring, drag reorder, delete button).
## The "Add" button opens a multi-select PopupMenu listing every sibling
## effect in recipe order. Siblings already in chain_to are pre-checked.

# =============================================================================
# WHAT: EditorProperty for chain_to arrays. Shows a multi-select sibling
#       picker instead of the native "New sub-resource" popup.
# WHY:  chain_to entries must be REFERENCES to existing sibling effects in
#       the same recipe — not new instances. The native array editor shows
#       all JuiceEffectBase subclasses globally, which is completely wrong.
#       This editor discovers siblings via JuiceEditorContext, presents them
#       in recipe order, and writes shared references (not copies).
# SYSTEM: Juice System (addons/Juice_V2/Editor/) — EDITOR ONLY.
# DOES NOT: Create new effects — only references existing siblings.
# DOES NOT: Handle arrays of arbitrary resource types — that's JuiceArrayEditor.
# =============================================================================

@tool
class_name ChainToArrayEditor
extends EditorProperty


# =============================================================================
# SIGNALS (none — all mutations go through emit_changed)
# =============================================================================


# =============================================================================
# CONFIGURATION
# =============================================================================

## Color for the type-indicator strip on chain_to rows.
## Uses the same blue as JuiceEffectBase entries in the effects array.
const CHAIN_COLOR := Color(0.45, 0.55, 0.95)


# =============================================================================
# INTERNAL STATE
# =============================================================================

# UI containers.
var _main_vbox: VBoxContainer
var _header_hbox: HBoxContainer
var _rows_container: VBoxContainer
var _size_label: Label
var _add_button: Button

# Nesting depth for theme-based sub-inspector coloring.
# chain_to is always inside an effect sub-inspector, so minimum depth is 1.
var _depth: int = 0

# Per-row expand state tracking.
var _expanded: Dictionary = {}

# Maps array index → sub-inspector MarginContainer.
var _sub_inspectors: Dictionary = {}

# The sibling picker popup (created lazily).
var _picker_popup: PopupMenu = null

# Guard against re-entrant _update_property calls during our own emit_changed.
var _updating: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _init() -> void:
	label = ""
	_build_ui()


func _enter_tree() -> void:
	_depth = _compute_depth()


# =============================================================================
# EditorProperty API
# =============================================================================

## Called by the inspector whenever the property value changes.
## Rebuilds the row list from the current chain_to array.
func _update_property() -> void:
	if _updating:
		return
	_updating = true

	var array: Array = _get_current_array()

	# Update size display.
	_size_label.text = "Size: %d" % array.size()

	# Preserve expand state, clean up stale sub-inspectors.
	_cleanup_stale_inspectors(array.size())

	# Rebuild rows.
	_rebuild_rows(array)

	_updating = false


# =============================================================================
# UI CONSTRUCTION
# =============================================================================

# Build the editor layout:
#   [Header: "chain_to" label + size + Add button]
#   [Rows container: JuiceResourceRow per chain_to entry]
func _build_ui() -> void:
	_main_vbox = VBoxContainer.new()
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.add_theme_constant_override("separation", 0)

	# --- Header ---
	_header_hbox = HBoxContainer.new()
	_header_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_hbox.add_theme_constant_override("separation", 4)

	# Size label (read-only — user adds via the picker, not by typing a count).
	_size_label = Label.new()
	_size_label.text = "Size: 0"
	_size_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header_hbox.add_child(_size_label)

	# Spacer.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_hbox.add_child(spacer)

	# Add button — opens the sibling picker popup.
	_add_button = Button.new()
	_add_button.text = "+ Pick Siblings"
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


# Auto-detect nesting depth by counting ancestor JuiceArrayEditors and
# ChainToArrayEditors in the tree.
func _compute_depth() -> int:
	var depth := 0
	var node: Node = get_parent()
	while node != null:
		if node is JuiceArrayEditor or node is ChainToArrayEditor:
			depth += 1
		node = node.get_parent()
	return depth


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
		var effect: JuiceEffectBase = array[i] as JuiceEffectBase

		# Build the row.
		var row := JuiceResourceRow.new()
		_rows_container.add_child(row)
		# Pass empty base_type to prevent the EditorResourcePicker from offering
		# "New" popup — chain_to entries are sibling references, not new instances.
		row.setup(i, effect, CHAIN_COLOR, _depth + 1, "")

		# Restore expand state if previously expanded.
		row.is_expanded = _expanded.get(i, false)

		# Connect row signals.
		row.expand_toggled.connect(_on_row_expand_toggled)
		row.delete_requested.connect(_on_row_delete)
		row.drag_reorder_requested.connect(_on_row_reorder)
		# We intentionally do NOT connect resource_replaced — the picker's
		# New/Load menu is not useful here. Rows are populated via the
		# sibling picker popup only.

		# If expanded, create the sub-inspector below this row.
		if row.is_expanded and effect != null:
			_create_sub_inspector(i, effect)


# =============================================================================
# SUB-INSPECTOR (same pattern as JuiceArrayEditor)
# =============================================================================

# Create an embedded EditorInspector below the row at the given index.
# Identical to JuiceArrayEditor._create_sub_inspector — factored for reuse.
func _create_sub_inspector(index: int, resource: Resource) -> void:
	var sub_inspector := EditorInspector.new()
	sub_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sub_inspector.set_vertical_scroll_mode(ScrollContainer.SCROLL_MODE_DISABLED)
	sub_inspector.set_horizontal_scroll_mode(ScrollContainer.SCROLL_MODE_DISABLED)
	sub_inspector.add_theme_stylebox_override("background", StyleBoxEmpty.new())

	var editor_theme := EditorInterface.get_editor_theme()

	# Gray foundation layer.
	var foundation := PanelContainer.new()
	foundation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foundation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if editor_theme:
		var base_style := StyleBoxFlat.new()
		base_style.bg_color = editor_theme.get_color("base_color", "Editor")
		foundation.add_theme_stylebox_override("panel", base_style)

	# Depth-colored overlay.
	var depth_panel := PanelContainer.new()
	depth_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	depth_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if editor_theme:
		var depth_key := "sub_inspector_bg%d" % clampi(_depth + 1, 0, 16)
		var depth_style := editor_theme.get_stylebox(depth_key, "EditorStyles")
		if depth_style:
			depth_panel.add_theme_stylebox_override("panel", depth_style)

	# Stack: foundation > depth overlay > sub-inspector
	depth_panel.add_child(sub_inspector)
	foundation.add_child(depth_panel)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(foundation)

	# Insert after the row in the VBox.
	var row_node := _get_row_at(index)
	if row_node:
		var row_idx := row_node.get_index()
		_rows_container.add_child(margin)
		_rows_container.move_child(margin, row_idx + 1)

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

# Get the current chain_to array value from the edited object.
func _get_current_array() -> Array:
	var obj := get_edited_object()
	if obj == null:
		return []
	var val = obj.get(get_edited_property())
	if val is Array:
		return val
	return []


# Commit a new chain_to array value to the edited object.
func _commit_array(new_array: Array) -> void:
	emit_changed(get_edited_property(), new_array)


# =============================================================================
# SIBLING DISCOVERY
# =============================================================================

# Find the parent recipe that contains the effect we are editing.
# Uses JuiceEditorContext to find the host JuiceBase node, then reads its recipe.
func _find_parent_recipe() -> JuiceRecipe:
	var effect := get_edited_object() as JuiceEffectBase
	if effect == null:
		return null

	var host: Node = JuiceEditorContext.get_host_node(effect)
	if host == null or not host is JuiceBase:
		return null

	return (host as JuiceBase).recipe


# Get the list of sibling effects from the parent recipe, excluding self.
# Returns effects in recipe order with their recipe indices preserved.
func _get_sibling_effects() -> Array[Dictionary]:
	var recipe := _find_parent_recipe()
	if recipe == null:
		return []

	var self_effect := get_edited_object() as JuiceEffectBase
	var siblings: Array[Dictionary] = []

	for i in range(recipe.effects.size()):
		var effect: JuiceEffectBase = recipe.effects[i]
		if effect == null:
			continue
		# Exclude self from the sibling list.
		if effect == self_effect:
			continue
		siblings.append({
			"index": i,
			"effect": effect,
			"label": _get_effect_display_name(effect, i),
		})

	return siblings


# Build a human-readable display name for an effect.
# Priority: resource_name > script class_name > index fallback.
func _get_effect_display_name(effect: JuiceEffectBase, recipe_index: int) -> String:
	if effect == null:
		return "[%d] (null)" % recipe_index

	# Try resource_name first (set by Phase 1 for some resource types).
	if not effect.resource_name.is_empty():
		return "[%d] %s" % [recipe_index, effect.resource_name]

	# Fallback to the GDScript class_name.
	var script := effect.get_script() as GDScript
	if script != null:
		var global_name := script.get_global_name()
		if not global_name.is_empty():
			return "[%d] %s" % [recipe_index, global_name]

	return "[%d] %s" % [recipe_index, effect.get_class()]


# =============================================================================
# SIBLING PICKER POPUP
# =============================================================================

# Open the multi-select sibling picker popup.
func _on_add_pressed() -> void:
	_show_sibling_picker()


# Build and show the multi-select popup listing all sibling effects.
func _show_sibling_picker() -> void:
	var siblings := _get_sibling_effects()
	if siblings.is_empty():
		push_warning("[ChainToArrayEditor] No sibling effects found in recipe.")
		return

	if _picker_popup == null:
		_picker_popup = PopupMenu.new()
		# hide_on_checkable_item_selection = false keeps the menu open after
		# each check/uncheck so the user can multi-select before dismissing.
		_picker_popup.hide_on_checkable_item_selection = false
		_picker_popup.id_pressed.connect(_on_picker_item_toggled)
		# Commit the selection when the popup is closed (user clicks away or
		# presses Escape after making their choices).
		_picker_popup.popup_hide.connect(_on_picker_closed)
		add_child(_picker_popup)

	_picker_popup.clear()

	# Current chain_to entries — used to pre-check already-chained siblings.
	var current_chain := _get_current_array()

	for sibling in siblings:
		var effect: JuiceEffectBase = sibling["effect"]
		var display_label: String = sibling["label"]
		var recipe_idx: int = sibling["index"]

		# Use the recipe index as the popup item ID so we can map back.
		var icon := _get_effect_icon(effect)
		if icon:
			_picker_popup.add_icon_check_item(icon, display_label, recipe_idx)
		else:
			_picker_popup.add_check_item(display_label, recipe_idx)

		# Pre-check if this sibling is already in chain_to.
		var is_checked := false
		for existing in current_chain:
			if existing == effect:
				is_checked = true
				break

		# Find the popup item index for the ID we just added.
		var item_idx := _picker_popup.get_item_index(recipe_idx)
		_picker_popup.set_item_checked(item_idx, is_checked)

	# Position below the Add button.
	var anchor_rect := _add_button.get_global_rect()
	_picker_popup.position = Vector2i(int(anchor_rect.position.x), int(anchor_rect.end.y))
	_picker_popup.popup()


# Toggle a sibling's checked state when clicked in the popup.
# Does NOT commit immediately — commit happens on popup_hide.
func _on_picker_item_toggled(id: int) -> void:
	if _picker_popup == null:
		return
	var item_idx := _picker_popup.get_item_index(id)
	var currently_checked := _picker_popup.is_item_checked(item_idx)
	_picker_popup.set_item_checked(item_idx, not currently_checked)


# When the popup is dismissed, read the checked state and commit the new
# chain_to array. This creates a single undo/redo action for the whole change.
func _on_picker_closed() -> void:
	if _picker_popup == null:
		return

	var recipe := _find_parent_recipe()
	if recipe == null:
		return

	# Build the new chain_to array from checked items.
	var new_chain: Array[JuiceEffectBase] = []
	for i in range(_picker_popup.get_item_count()):
		if _picker_popup.is_item_checked(i):
			var recipe_idx: int = _picker_popup.get_item_id(i)
			if recipe_idx >= 0 and recipe_idx < recipe.effects.size():
				var effect := recipe.effects[recipe_idx]
				if effect != null:
					new_chain.append(effect)

	_commit_array(new_chain)


# Get the editor theme icon for an effect's class.
func _get_effect_icon(effect: JuiceEffectBase) -> Texture2D:
	if effect == null:
		return null
	var script := effect.get_script() as GDScript
	if script != null:
		var global_name := script.get_global_name()
		if not global_name.is_empty():
			return _get_global_class_icon(global_name)
	return null


# Look up the @icon path for a GDScript global class name.
# Walks the inheritance chain to find the nearest class with an icon.
func _get_global_class_icon(class_name_str: String) -> Texture2D:
	var global_classes: Array[Dictionary] = ProjectSettings.get_global_class_list()
	var current := class_name_str
	for _i in range(20):
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
	return null


# =============================================================================
# SIGNAL HANDLERS — Row
# =============================================================================

# Row expand/collapse toggled.
func _on_row_expand_toggled(index: int) -> void:
	var array := _get_current_array()
	if index < 0 or index >= array.size():
		return

	# chain_to entries should never be null (they're references), but guard anyway.
	if array[index] == null:
		return

	var was_expanded: bool = _expanded.get(index, false)
	_expanded[index] = not was_expanded

	if _expanded[index]:
		if array[index] is Resource:
			_create_sub_inspector(index, array[index] as Resource)
	else:
		if _sub_inspectors.has(index):
			var container = _sub_inspectors[index]
			if is_instance_valid(container):
				_rows_container.remove_child(container)
				container.queue_free()
			_sub_inspectors.erase(index)


# Row delete requested — remove from chain_to.
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
	_expanded.clear()
	_commit_array(array)
