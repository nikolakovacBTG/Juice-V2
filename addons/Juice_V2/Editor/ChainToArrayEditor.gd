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

# Debug toggle — set true to print sibling discovery and picker decisions.
const DEBUG := false

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

# NOTE: chain_to rows are NOT expandable. They are references to sibling
# effects, not owned sub-resources. Expanding them would create recursive
# sub-inspectors (effect A → chain_to → effect B → chain_to → effect A)
# which crashes Godot with infinite recursion.

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


func _notification(what: int) -> void:
	if what == NOTIFICATION_POST_ENTER_TREE:
		_depth = _count_editor_depth()


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


# Count EditorInspector ancestors to determine nesting depth.
# Same algorithm as JuiceArrayEditor._count_editor_depth().
func _count_editor_depth() -> int:
	var count := 0
	var node: Node = get_parent()
	while node != null:
		if node is EditorInspector:
			count += 1
		node = node.get_parent()
	# Subtract 1: the outermost EditorInspector is the main dock inspector.
	return maxi(count - 1, 0)


# =============================================================================
# ROW MANAGEMENT
# =============================================================================

# Clear existing rows and rebuild from the array data.
func _rebuild_rows(array: Array) -> void:
	# Remove old rows and sub-inspectors from the container.
	for child in _rows_container.get_children():
		_rows_container.remove_child(child)
		child.queue_free()



	# Create a row for each element.
	for i in range(array.size()):
		var effect: JuiceEffectBase = array[i] as JuiceEffectBase

		# Build the row.
		var row := JuiceResourceRow.new()
		_rows_container.add_child(row)
		# Pass empty base_type to prevent the EditorResourcePicker from offering
		# "New" popup — chain_to entries are sibling references, not new instances.
		row.setup(i, effect, CHAIN_COLOR, _depth, "")

		# chain_to rows are NOT expandable and NOT editable — they are shared
		# references to sibling effects, not owned sub-resources. Disabling
		# toggle_mode prevents infinite recursion (effect → chain_to → effect).
		# Disabling editable hides the non-unique chain icon and "Make Unique"
		# popup, which would be counterproductive for intentionally shared refs.
		row._resource_picker.toggle_mode = false
		row._resource_picker.editable = false

		# Connect row signals — only delete and reorder, NOT expand_toggled.
		row.delete_requested.connect(_on_row_delete)
		row.drag_reorder_requested.connect(_on_row_reorder)


# NOTE: No sub-inspector section. chain_to rows are reference-only and
# must NOT be expanded to avoid infinite recursion crashes.


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
# Falls back to walking the scene tree if the context doesn't have this effect
# registered (e.g. after plugin reload creates fresh effect instances).
func _find_parent_recipe() -> JuiceRecipe:
	var effect := get_edited_object() as JuiceEffectBase
	if effect == null:
		return null

	# Fast path: JuiceEditorContext lookup.
	var host: Node = JuiceEditorContext.get_host_node(effect)
	if host != null and host is JuiceBase:
		if DEBUG: print("[ChainToArrayEditor] Recipe found via JuiceEditorContext for %s." % host.name)
		return (host as JuiceBase).recipe

	# Fallback: walk the scene tree and search all JuiceBase recipes.
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		if DEBUG: print("[ChainToArrayEditor] No scene root — cannot discover recipe.")
		return null
	var result := _search_tree_for_recipe(root, effect)
	if DEBUG:
		if result: print("[ChainToArrayEditor] Recipe found via scene tree fallback.")
		else: print("[ChainToArrayEditor] Recipe NOT found for effect.")
	return result


# Recursively search the scene tree for a JuiceBase whose recipe contains
# the given effect. Also re-registers the recipe in JuiceEditorContext so
# subsequent lookups use the fast path.
func _search_tree_for_recipe(node: Node, effect: JuiceEffectBase) -> JuiceRecipe:
	if node is JuiceBase:
		var juice := node as JuiceBase
		if juice.recipe != null and effect in juice.recipe.effects:
			# Re-register so future lookups don't need the fallback.
			JuiceEditorContext.register_recipe(juice.recipe, juice)
			return juice.recipe
	for child in node.get_children():
		var result := _search_tree_for_recipe(child, effect)
		if result != null:
			return result
	return null


# Get the list of sibling effects from the parent recipe, excluding self.
# Returns effects in recipe order with their recipe indices preserved.
func _get_sibling_effects() -> Array[Dictionary]:
	var recipe := _find_parent_recipe()
	if recipe == null:
		if DEBUG: print("[ChainToArrayEditor] No recipe — returning empty siblings.")
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

	if DEBUG: print("[ChainToArrayEditor] Found %d siblings (recipe has %d effects)." % [siblings.size(), recipe.effects.size()])
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

# NOTE: No _on_row_expand_toggled handler. chain_to rows cannot be expanded.


# Row delete requested — remove from chain_to.
func _on_row_delete(index: int) -> void:
	var array := _get_current_array().duplicate()
	if index < 0 or index >= array.size():
		return

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
	_commit_array(array)
