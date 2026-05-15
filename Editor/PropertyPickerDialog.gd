## A searchable property picker dialog for PropertyTarget sub-resources.
##
## Shows all animatable properties of a given scene node. The user picks one
## and the selection is written back to [member PropertyTarget.property_path]
## with full undo/redo support.

# ============================================================================
# WHAT: ConfirmationDialog that lists a node's animatable properties so the
#       user can select one instead of typing a property path manually.
# WHY:  Typing property paths (e.g. "modulate:a", "custom_minimum_size:x") is
#       error-prone and undiscoverable. A searchable picker eliminates typos and
#       lets designers browse the property set of the actual target node.
# SYSTEM: Juice System — Editor layer (addons/Juice_V2/Editor/)
# DOES NOT: Handle runtime property resolution, nested sub-paths (e.g. "mat/param"),
#           or properties on nodes other than the one supplied via setup().
# ============================================================================

@tool
extends ConfirmationDialog


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _pt: PropertyTarget = null
var _search: LineEdit = null
var _list: ItemList = null
# Cached full list so search can re-filter without re-querying the node.
var _all_props: Array[Dictionary] = []


# =============================================================================
# PUBLIC API
# =============================================================================

## Initialise the dialog for [param source_node] and [param pt].
## Must be called before popup_centered(). Builds UI and populates the list.
func setup(source_node: Node, pt: PropertyTarget) -> void:
	_pt = pt
	title = "Pick Property — %s" % source_node.name
	min_size = Vector2i(420, 520)

	_all_props = _collect_animatable_props(source_node)
	_build_ui()
	_filter_list("")
	confirmed.connect(_on_confirmed)


# =============================================================================
# UI CONSTRUCTION
# =============================================================================

# Adds the search bar and property list to the dialog's content area.
# ConfirmationDialog places add_child() content above its OK/Cancel buttons.
func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)

	var hint := Label.new()
	hint.text = "Animatable properties (float, Vector, Color, bool):"
	hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(hint)

	_search = LineEdit.new()
	_search.placeholder_text = "Search properties..."
	_search.clear_button_enabled = true
	_search.text_changed.connect(_filter_list)
	vbox.add_child(_search)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_activated.connect(_on_item_activated)
	vbox.add_child(_list)


# =============================================================================
# CORE LOGIC
# =============================================================================

# Rebuilds the ItemList to show only properties whose names contain [param query].
# Selects the first match automatically so pressing OK works immediately.
func _filter_list(query: String) -> void:
	_list.clear()
	var lower := query.to_lower()
	for prop in _all_props:
		var pname: String = prop["name"]
		if query.is_empty() or pname.to_lower().contains(lower):
			var idx := _list.add_item("%s  [%s]" % [pname, _type_label(prop["type"])])
			_list.set_item_metadata(idx, pname)
	if _list.item_count > 0:
		_list.select(0)


# Returns the animatable property list for [param node], filtered to types that
# the JuiceLedger can handle (numeric, Color, bool).
# Excludes internal properties, Godot bookkeeping fields (script, owner, etc.),
# and group/subgroup headers (TYPE_NIL) to keep the list lean and relevant.
func _collect_animatable_props(node: Node) -> Array[Dictionary]:
	var animatable_types: Array[int] = [
		TYPE_FLOAT, TYPE_INT,
		TYPE_VECTOR2, TYPE_VECTOR2I,
		TYPE_VECTOR3, TYPE_VECTOR3I,
		TYPE_VECTOR4, TYPE_VECTOR4I,
		TYPE_QUATERNION,
		TYPE_COLOR,
		TYPE_BOOL,
	]
	var skip_names: Array[String] = [
		"script", "owner", "unique_name_in_owner",
		"scene_file_path", "multiplayer",
	]

	var props: Array[Dictionary] = []
	for prop in node.get_property_list():
		var pname: String = prop["name"]
		var ptype: int = prop["type"]
		var pusage: int = prop["usage"]

		if ptype == TYPE_NIL:
			continue  # Group / subgroup header
		if ptype not in animatable_types:
			continue
		if pusage & PROPERTY_USAGE_INTERNAL:
			continue
		if not (pusage & PROPERTY_USAGE_EDITOR):
			continue
		if pname.begins_with("_") or pname in skip_names:
			continue

		props.append({"name": pname, "type": ptype})

	# Sort alphabetically so the list is predictable.
	props.sort_custom(func(a, b): return a["name"] < b["name"])
	return props


# =============================================================================
# HELPERS
# =============================================================================

# Returns a short human-readable type label for the ItemList display.
func _type_label(t: int) -> String:
	match t:
		TYPE_FLOAT:      return "float"
		TYPE_INT:        return "int"
		TYPE_VECTOR2:    return "Vector2"
		TYPE_VECTOR2I:   return "Vector2i"
		TYPE_VECTOR3:    return "Vector3"
		TYPE_VECTOR3I:   return "Vector3i"
		TYPE_VECTOR4:    return "Vector4"
		TYPE_VECTOR4I:   return "Vector4i"
		TYPE_QUATERNION: return "Quaternion"
		TYPE_COLOR:      return "Color"
		TYPE_BOOL:       return "bool"
	return "?"


# Returns the raw property name stored as item metadata (strips the type suffix).
func _selected_property_name() -> String:
	var items := _list.get_selected_items()
	if items.is_empty():
		return ""
	return _list.get_item_metadata(items[0])


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

# Writes the selected property path to the PropertyTarget using UndoRedo so
# the action appears in Edit -> Undo and can be reverted cleanly.
func _on_confirmed() -> void:
	var prop_name := _selected_property_name()
	if prop_name.is_empty() or _pt == null:
		return

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Pick Property Path")
	undo_redo.add_do_property(_pt, "property_path", prop_name)
	undo_redo.add_undo_property(_pt, "property_path", _pt.property_path)
	undo_redo.commit_action()

	# Refresh the main inspector so the new path appears immediately.
	EditorInterface.get_inspector().refresh()


# Double-clicking a list item immediately confirms the selection and closes.
func _on_item_activated(_idx: int) -> void:
	_on_confirmed()
	hide()
