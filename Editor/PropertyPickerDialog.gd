## Editor-only dialog for picking properties from a node to populate a PropertyTarget.
##
## Opened by PropertyPickerPlugin when the user clicks [Pick…] in a PropertyTarget
## inspector row. Supports multi-select, search, and an "exports only" filter.

# =============================================================================
# WHAT: ConfirmationDialog that lists node properties in a checkable tree.
#       Multi-selection adds multiple PropertyTarget entries at once.
#       Already-picked paths are pre-checked.
# WHY:  Provides a better UX than typing property paths manually.
#       Mirrors the paradigm of recipe array items — visual list of configs.
# SYSTEM: Juice System (addons/Juice_V1/Editor/) — EDITOR ONLY.
# DOES NOT: Run in game — registered via juice_plugin.gd, stripped on export.
# DOES NOT: Support per-surface shader materials on MeshInstance3D (surface_material_override/N
#            is inaccessible via get_indexed — those require method calls, not property access).
# =============================================================================

@tool
class_name PropertyPickerDialog
extends ConfirmationDialog


# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when the user confirms. paths contains all checked property paths.
## Caller is responsible for updating the PropertyTarget entries.
signal properties_confirmed(paths: Array[String])


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _target_node: Node = null
var _initial_paths: Array[String] = []

var _search_edit: LineEdit
var _restrict_check: CheckBox
var _tree: Tree


# =============================================================================
# LIFECYCLE
# =============================================================================

func _init() -> void:
	title = "Pick Properties"
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	min_size = Vector2i(460, 540)
	exclusive = true
	unresizable = false
	visible = false  # Hidden until explicitly opened via open_for_node().
	ok_button_text = "OK"

	_build_ui()

	# ConfirmationDialog signals.
	confirmed.connect(_on_ok_pressed)
	# close_requested is already handled by ConfirmationDialog (closes on X and Cancel).


func _build_ui() -> void:
	# AcceptDialog / ConfirmationDialog (which inherit from Window) do not automatically
	# layout multiple custom children. We MUST wrap everything in a single container.
	var main_vbox := VBoxContainer.new()
	add_child(main_vbox)

	# --- Top bar: search + filter ---
	var top_bar := HBoxContainer.new()
	main_vbox.add_child(top_bar)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search properties…"
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.clear_button_enabled = true
	top_bar.add_child(_search_edit)

	_restrict_check = CheckBox.new()
	_restrict_check.text = "Exports only"
	_restrict_check.button_pressed = true  # ON by default
	_restrict_check.tooltip_text = (
		"ON: show only properties visible in the Inspector.\n"
		+ "OFF: show all non-internal properties (including storage-only vars).")
	top_bar.add_child(_restrict_check)

	# --- Property tree ---
	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.columns = 2
	_tree.set_column_title(0, "Property")
	_tree.set_column_title(1, "Type")
	_tree.set_column_titles_visible(true)
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 90)
	main_vbox.add_child(_tree)

	# Tip label
	var tip := Label.new()
	tip.text = "✓ = already in list  |  Check to add, uncheck to remove"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	main_vbox.add_child(tip)

	# --- Connections ---
	_search_edit.text_changed.connect(func(_t): _populate_tree())
	_restrict_check.toggled.connect(func(_v): _populate_tree())


# =============================================================================
# PUBLIC API
# =============================================================================

## Open the dialog for a specific node, with optional pre-checked paths.
## node: the resolved PropertyTarget._resolved_node (or any Node)
## current_paths: Array[String] of already-configured property paths
func open_for_node(node: Node, current_paths: Array[String]) -> void:
	_target_node = node
	_initial_paths = current_paths.duplicate()
	_populate_tree()
	popup_centered(Vector2i(460, 540))


# =============================================================================
# TREE POPULATION
# =============================================================================

func _populate_tree() -> void:
	_tree.clear()
	if not is_instance_valid(_target_node):
		return

	var filter := _search_edit.text.strip_edges().to_lower()
	var restrict := _restrict_check.button_pressed

	var root := _tree.create_item()

	# Section: Inspector-visible properties
	var exported_items: Array[Dictionary] = []
	var engine_items: Array[Dictionary] = []

	for prop: Dictionary in _target_node.get_property_list():
		var usage: int = prop.get("usage", 0)
		var name: String = prop.get("name", "")

		# Always exclude internal engine properties.
		if usage & PROPERTY_USAGE_INTERNAL:
			continue
		# Exclude group/category markers (no actual value).
		if usage & PROPERTY_USAGE_GROUP or usage & PROPERTY_USAGE_CATEGORY:
			continue
		if name.is_empty() or name.begins_with("_"):
			continue

		# Apply search filter.
		if not filter.is_empty() and not name.to_lower().contains(filter):
			continue

		if usage & PROPERTY_USAGE_EDITOR:
			exported_items.append(prop)
		else:
			engine_items.append(prop)

	_add_tree_section("Inspector Properties", exported_items)

	# Engine properties section only shown when restrict is OFF.
	if not restrict and not engine_items.is_empty():
		_add_tree_section("Engine / Storage Properties", engine_items)

	# Shader parameters — always shown regardless of the restrict toggle.
	# Checks material, material_override, and material_overlay independently.
	_add_shader_params_section(filter)


func _add_tree_section(section_name: String, items: Array[Dictionary]) -> void:
	if items.is_empty():
		return

	var root := _tree.get_root()
	var header := _tree.create_item(root)
	header.set_selectable(0, false)
	header.set_selectable(1, false)
	header.set_text(0, section_name)
	header.set_custom_color(0, Color(0.7, 0.7, 0.7))
	header.set_cell_mode(0, TreeItem.CELL_MODE_STRING)
	header.collapsed = false

	for prop: Dictionary in items:
		var name: String = prop.get("name", "")
		var type_id: int = prop.get("type", TYPE_NIL)

		var item := _tree.create_item(header)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_editable(0, true)
		item.set_text(0, name)
		item.set_meta("property_path", name)

		# Pre-check if already in the list.
		var is_checked := name in _initial_paths
		item.set_checked(0, is_checked)
		if is_checked:
			item.set_custom_color(0, Color(0.4, 1.0, 0.5))

		# Type column.
		item.set_text(1, type_string(type_id))
		item.set_custom_color(1, Color(0.6, 0.8, 1.0))


# =============================================================================
# SHADER PARAMETER SECTIONS
# =============================================================================

## Check all material-type properties on the target node and add a picker
## section for each one that holds a ShaderMaterial with a compiled shader.
## Confirmed working via live editor-script test:
##   node.get("material")          → CanvasItem / Sprite2D / Label etc.
##   node.get("material_override") → MeshInstance3D / GeometryInstance3D
##   node.get("material_overlay")  → MeshInstance3D second overlay layer
func _add_shader_params_section(filter: String) -> void:
	if not is_instance_valid(_target_node):
		return
	for mat_prop: String in ["material", "material_override", "material_overlay"]:
		var material = _target_node.get(mat_prop)
		if material is ShaderMaterial and material.shader != null:
			_add_shader_section_for_material(mat_prop, material, filter)


## Populate one amber section in the tree for a specific ShaderMaterial.
## mat_prop: the node property name holding the material
## ("material", "material_override", or "material_overlay").
func _add_shader_section_for_material(
		mat_prop: String, material: ShaderMaterial, filter: String) -> void:

	# Build filtered uniform list.
	var filtered: Array[Dictionary] = []
	for u: Dictionary in material.shader.get_shader_uniform_list():
		var uname: String = u.get("name", "")
		if not filter.is_empty() and not uname.to_lower().contains(filter):
			continue
		filtered.append(u)
	if filtered.is_empty():
		return

	# Section header — amber colour distinguishes shader params from node props.
	# Label includes mat_prop so users know which material slot this targets.
	var root := _tree.get_root()
	var header := _tree.create_item(root)
	header.set_selectable(0, false)
	header.set_selectable(1, false)
	header.set_text(0, "Shader Parameters (%s)" % mat_prop)
	header.set_custom_color(0, Color(0.9, 0.75, 0.3))
	header.set_cell_mode(0, TreeItem.CELL_MODE_STRING)
	header.collapsed = false

	for u: Dictionary in filtered:
		var uname: String     = u.get("name", "")
		var utype: int        = u.get("type", TYPE_NIL)
		# Full path that get_indexed / set_indexed accepts at runtime.
		var full_path: String = mat_prop + ":shader_parameter/" + uname
		var is_texture: bool  = (utype == TYPE_OBJECT)

		var item := _tree.create_item(header)
		if is_texture:
			# Sampler/texture uniforms cannot be lerped or noise-driven.
			# Show them greyed and non-checkable so the user sees them but can't pick them.
			item.set_cell_mode(0, TreeItem.CELL_MODE_STRING)
			item.set_selectable(0, false)
			item.set_text(0, uname + "  (sampler — not animatable)")
			item.set_custom_color(0, Color(0.5, 0.5, 0.5))
			item.set_text(1, type_string(utype))
			item.set_custom_color(1, Color(0.5, 0.5, 0.5))
		else:
			item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			item.set_editable(0, true)
			item.set_text(0, uname)
			item.set_meta("property_path", full_path)
			var is_checked := full_path in _initial_paths
			item.set_checked(0, is_checked)
			if is_checked:
				item.set_custom_color(0, Color(0.4, 1.0, 0.5))
			item.set_text(1, type_string(utype))
			item.set_custom_color(1, Color(0.9, 0.75, 0.3))


# =============================================================================
# CONFIRM
# =============================================================================

func _on_ok_pressed() -> void:
	var confirmed_paths: Array[String] = []

	# Walk every item in the tree and collect checked ones.
	var root := _tree.get_root()
	if root == null:
		hide()
		return
	var section := root.get_first_child()
	while section != null:
		var item := section.get_first_child()
		while item != null:
			if item.is_checked(0):
				confirmed_paths.append(item.get_meta("property_path", ""))
			item = item.get_next()
		section = section.get_next()

	properties_confirmed.emit(confirmed_paths)
	hide()
