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
# SYSTEM: Juice System (addons/Juice_V2/Editor/) — EDITOR ONLY.
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
# The class name of the effect that opened the picker (e.g. "PropertyInterpolateControlJuiceEffect").
# Used to show per-family redirect notes for ledger-managed properties.
var _effect_family: String = ""

var _search_edit: LineEdit
var _restrict_check: CheckBox
var _tree: Tree
# Cached per open_for_node call: true when the parent effect is a Progress effect.
var _is_progress_family: bool = false


# =============================================================================
# LEDGER-MANAGED PROPERTIES
# =============================================================================

# Properties owned by the JuiceLedger — Juice writes them every frame as part
# of its delta-aggregation pipeline (position, rotation, scale, modulate, etc.).
# These CANNOT be animated via the Property family without conflicting with Juice's
# own writes. They are shown grayed-out in the picker so the designer knows to use
# a dedicated Juice effect instead.
# Key: root property name. Value: unused (notes are generated per effect family).
const LEDGER_MANAGED_PROPERTIES: Dictionary = {
	"position":          true,
	"rotation":          true,
	"rotation_degrees":  true,
	"scale":             true,
	"skew":              true,
	"modulate":          true,
	"self_modulate":     true,
}

# Returns the exact redirect note for a ledger-managed property.
# Derives the domain suffix (Control / 2D / 3D) from the opening effect's
# class name so the note names the EXACT Juice Effect class visible in the
# inspector "Add Effect" dropdown — no guessing.
func _get_ledger_note(prop: String, family: String) -> String:
	# Derive domain suffix from opening effect class name.
	var domain := ""
	if "Control" in family:
		domain = "Control"
	elif "2D" in family:
		domain = "2D"
	elif "3D" in family:
		domain = "3D"

	var is_transform := prop in ["position", "rotation", "rotation_degrees", "scale", "skew"]
	var is_appearance := prop in ["modulate", "self_modulate"]

	if is_transform:
		if domain.is_empty():
			return "→ Use Transform Effect (position / rotation / scale)"
		return "→ Use Transform%sJuiceEffect" % domain

	if is_appearance:
		if domain.is_empty():
			return "→ Use Appearance Effect (modulate / self_modulate)"
		return "→ Use Appearance%sJuiceEffect" % domain

	# Fallback for any future ledger-managed property.
	return "→ Managed by Juice — use the dedicated Effect for this property"



# Types that cannot be picked at all — they are internal engine handles with no
# inspector-configurable value and no meaningful animation target.
# Everything else (bool, string, object, packed arrays, etc.) is supported either
# as a full lerp/noise target or as a threshold-flip type per the agreed type table.
const UNSUPPORTED_TYPES: Array[int] = [
	TYPE_RID,       # Internal engine handle — cannot be set by user.
	TYPE_CALLABLE,  # Function reference — not serializable or inspectable.
	TYPE_SIGNAL,    # Signal reference — not inspectable.
]

# Types excluded from the picker when opening for a Progress (rate-accumulator)
# effect. These types have no meaningful additive rate operation.
# All numeric/math types (float, vectors, quaternion, basis, projection, plane,
# rect2, aabb, color) remain available.
const PROGRESS_EXCLUDED_TYPES: Array[int] = [
	TYPE_BOOL,
	TYPE_STRING,
	TYPE_STRING_NAME,
	TYPE_NODE_PATH,
	TYPE_OBJECT,
	TYPE_DICTIONARY,
	TYPE_ARRAY,
	TYPE_PACKED_BYTE_ARRAY,
	TYPE_PACKED_INT32_ARRAY,
	TYPE_PACKED_INT64_ARRAY,
	TYPE_PACKED_FLOAT32_ARRAY,
	TYPE_PACKED_FLOAT64_ARRAY,
	TYPE_PACKED_STRING_ARRAY,
	TYPE_PACKED_VECTOR2_ARRAY,
	TYPE_PACKED_VECTOR3_ARRAY,
	TYPE_PACKED_COLOR_ARRAY,
	TYPE_PACKED_VECTOR4_ARRAY,
]


# =============================================================================
# LIFECYCLE
# =============================================================================

func _init() -> void:
	title = "Pick Properties"
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	# min_size covers the dialog chrome (title bar + buttons) plus tree content.
	# The tree itself has a custom_minimum_size set in _build_ui so the first
	# layout pass gives it meaningful height even before popup_centered fires.
	min_size = Vector2i(480, 560)
	max_size = Vector2i(700, 720)  # Hard cap: prevents unbounded growth on first layout pass.
	exclusive = true
	unresizable = false
	visible = false  # Hidden until explicitly opened via open_for_node().
	ok_button_text = "OK"

	# ConfirmationDialog signals.
	confirmed.connect(_on_ok_pressed)
	# close_requested is already handled by ConfirmationDialog (closes on X and Cancel).


# Deferred from _init() intentionally: _build_ui() relies on the editor theme
# (font sizes, colors, stylebox) which is only available AFTER the dialog has
# been added to the editor scene tree via add_dialog_to_editor().
# Godot calls _ready() at that point, guaranteeing a correct first layout pass.
func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Single VBoxContainer as the dialog's content root.
	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	_restrict_check.button_pressed = true
	_restrict_check.tooltip_text = (
		"ON: show only properties visible in the Inspector.\n"
		+ "OFF: show all non-internal properties (including storage-only vars).")
	top_bar.add_child(_restrict_check)

	# Tree directly in the VBoxContainer — no ScrollContainer wrapper.
	# Godot's Tree has built-in scrollbars and handles overflow correctly.
	# A ScrollContainer would give the Tree its full natural content height
	# as minimum size, causing the dialog to balloon off-screen on first open.
	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.custom_minimum_size = Vector2i(0, 300)  # Ensures useful minimum height.
	_tree.hide_root = true
	_tree.columns = 3
	_tree.set_column_title(0, "Property")
	_tree.set_column_title(1, "Type")
	_tree.set_column_title(2, "Note")
	_tree.set_column_titles_visible(true)
	_tree.set_column_expand(0, true)
	_tree.set_column_custom_minimum_width(0, 120)
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 68)
	_tree.set_column_expand(2, true)
	_tree.set_column_custom_minimum_width(2, 140)
	main_vbox.add_child(_tree)

	# --- Footer: selection hint ---
	var tip := Label.new()
	tip.text = "✓ = already in list  |  Check to add, uncheck to remove"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	main_vbox.add_child(tip)

	# --- Footer: ledger + unsupported notice (user-specified wording, smaller font) ---
	var ledger_tip := Label.new()
	ledger_tip.text = ("Properties that are grayed out are better animated by appropriate "
		+ "Juice Effects stated in the \"Note\" column.")
	ledger_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ledger_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ledger_tip.add_theme_color_override("font_color", Color(0.75, 0.55, 0.25))
	ledger_tip.add_theme_font_size_override("font_size", 11)
	main_vbox.add_child(ledger_tip)

	var unsupported_tip := Label.new()
	unsupported_tip.text = "Unsupported properties are not listed."
	unsupported_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unsupported_tip.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	unsupported_tip.add_theme_font_size_override("font_size", 11)
	main_vbox.add_child(unsupported_tip)

	# --- Connections ---
	_search_edit.text_changed.connect(func(_t): _populate_tree())
	_restrict_check.toggled.connect(func(_v): _populate_tree())


# =============================================================================
# PUBLIC API
# =============================================================================

## Open the dialog for a specific node, with optional pre-checked paths.
## node: the resolved PropertyTarget._resolved_node (or any Node).
## current_paths: Array[String] of already-configured property paths.
## effect_family: class_name of the opening effect (used to pick per-family ledger notes).
func open_for_node(node: Node, current_paths: Array[String], effect_family: String = "") -> void:
	_target_node = node
	_initial_paths = current_paths.duplicate()
	_effect_family = effect_family
	_populate_tree()
	# popup_centered_clamped clamps position so the window stays fully on-screen
	# even on the first open when Godot's layout pass hasn't finalised sizes yet.
	popup_centered_clamped(Vector2i(480, 560))


# =============================================================================
# TREE POPULATION
# =============================================================================

func _populate_tree() -> void:
	_tree.clear()
	if not is_instance_valid(_target_node):
		return

	var filter := _search_edit.text.strip_edges().to_lower()
	var restrict := _restrict_check.button_pressed
	_is_progress_family = "Progress" in _effect_family

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

		var type_id: int = prop.get("type", TYPE_NIL)

		# Completely skip non-animatable engine-internal types (RID, Callable, Signal).
		# These have no inspector-configurable value — hiding them avoids confusion.
		if type_id in UNSUPPORTED_TYPES:
			continue

		# Progress-specific filter: exclude non-numeric types that can't
		# be rate-accumulated. Better UX than showing a "not applicable" note.
		if _is_progress_family and type_id in PROGRESS_EXCLUDED_TYPES:
			continue

		if usage & PROPERTY_USAGE_EDITOR:
			exported_items.append(prop)
		elif name in LEDGER_MANAGED_PROPERTIES:
			# Ledger-managed properties always appear in "Inspector Properties"
			# even if the engine marks them as storage-only. Without this, they
			# could be hidden by the "Exports only" toggle.
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
	header.set_selectable(2, false)
	header.set_text(0, section_name)
	header.set_custom_color(0, Color(0.7, 0.7, 0.7))
	header.set_cell_mode(0, TreeItem.CELL_MODE_STRING)
	header.collapsed = false

	for prop: Dictionary in items:
		var name: String = prop.get("name", "")
		var type_id: int = prop.get("type", TYPE_NIL)

		var item := _tree.create_item(header)

		# Ledger-managed: shown grayed and non-selectable. Note column explains
		# which specific Juice Effect handles this property for the current family.
		if name in LEDGER_MANAGED_PROPERTIES:
			item.set_cell_mode(0, TreeItem.CELL_MODE_STRING)
			item.set_selectable(0, false)
			item.set_selectable(1, false)
			item.set_selectable(2, false)
			item.set_text(0, name)
			item.set_custom_color(0, Color(0.5, 0.5, 0.5))
			item.set_text(1, type_string(type_id))
			item.set_custom_color(1, Color(0.5, 0.5, 0.5))
			item.set_text(2, _get_ledger_note(name, _effect_family))
			item.set_custom_color(2, Color(0.8, 0.6, 0.3))
			continue

		# Normal checkable item.
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_editable(0, true)
		item.set_selectable(0, true)   # checkbox col is intentionally selectable
		item.set_selectable(1, false)  # Type col: display only
		item.set_selectable(2, false)  # Note col: display only
		item.set_text(0, name)
		item.set_meta("property_path", name)

		# Pre-check if already in the list.
		var is_checked := name in _initial_paths
		item.set_checked(0, is_checked)
		if is_checked:
			item.set_custom_color(0, Color(0.4, 1.0, 0.5))

		# Type column — display only.
		item.set_text(1, type_string(type_id))
		item.set_custom_color(1, Color(0.6, 0.8, 1.0))


# =============================================================================
# SHADER PARAMETER SECTIONS
# =============================================================================

# Check all material-type properties on the target node and add a picker
# section for each one that holds a ShaderMaterial with a compiled shader.
func _add_shader_params_section(filter: String) -> void:
	if not is_instance_valid(_target_node):
		return
	for mat_prop: String in ["material", "material_override", "material_overlay"]:
		var material = _target_node.get(mat_prop)
		if material is ShaderMaterial and material.shader != null:
			_add_shader_section_for_material(mat_prop, material, filter)


# Populate one amber section in the tree for a specific ShaderMaterial.
# mat_prop: the node property name holding the material.
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
	var root := _tree.get_root()
	var header := _tree.create_item(root)
	header.set_selectable(0, false)
	header.set_selectable(1, false)
	header.set_selectable(2, false)
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
		item.set_selectable(1, false)
		item.set_selectable(2, false)
		if is_texture:
			# Sampler/texture uniforms cannot be lerped or noise-driven.
			item.set_cell_mode(0, TreeItem.CELL_MODE_STRING)
			item.set_selectable(0, false)
			item.set_text(0, uname + "  (sampler — not animatable)")
			item.set_custom_color(0, Color(0.5, 0.5, 0.5))
			item.set_text(1, type_string(utype))
			item.set_custom_color(1, Color(0.5, 0.5, 0.5))
		else:
			item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			item.set_editable(0, true)
			item.set_selectable(0, true)
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
