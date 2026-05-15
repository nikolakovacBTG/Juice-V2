## EditorInspectorPlugin that adds a "Pick Property" button to every
## PropertyTarget sub-resource inspector, opening [PropertyPickerDialog].

# ============================================================================
# WHAT: EditorInspectorPlugin that decorates PropertyTarget sub-resource panels
#       with a "Pick Property..." button above the property_path string field.
# WHY:  Property paths are typed manually by default, which is error-prone and
#       requires the user to know Godot's internal property names exactly. This
#       plugin surfaces a searchable picker so designers can browse the actual
#       target node's property set and click to select — no typos possible.
# SYSTEM: Juice System — Editor layer (addons/Juice_V2/Editor/)
# DOES NOT: Modify runtime behaviour or any non-editor code path.
#           Does not handle non-PropertyTarget resources.
#           Does not resolve which node will be animated at runtime — it uses
#           the currently selected editor node's parent as a best-guess source.
# ============================================================================

@tool
extends EditorInspectorPlugin

# Preload dialog so it is available without a global class_name, keeping the
# global class registry free of editor-only types.
const _DialogScript := preload("res://addons/Juice_V2/Editor/PropertyPickerDialog.gd")


# =============================================================================
# EDITOR INSPECTOR PLUGIN CONTRACT
# =============================================================================

# Activate this plugin only for PropertyTarget resources (and subclasses).
# Other resources are ignored — no performance cost for unrelated inspectors.
func _can_handle(object: Object) -> bool:
	return object is PropertyTarget


# Inserts the "Pick Property" button at the top of the PropertyTarget panel,
# above the property_path string field. The button is always visible so the
# designer always has a quick route to the picker regardless of current state.
func _parse_begin(object: Object) -> void:
	if not object is PropertyTarget:
		return

	var pt := object as PropertyTarget
	var btn := Button.new()
	btn.text = "Pick Property..."
	btn.tooltip_text = (
		"Opens a searchable list of the selected node's animatable properties.\n"
		+ "Select a JuiceBase (or its parent target) in the scene tree first."
	)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_open_picker.bind(pt))
	add_custom_control(btn)


# =============================================================================
# PICKER LOGIC
# =============================================================================

# Opens PropertyPickerDialog populated with the properties of the best-guess
# source node (see _find_source_node). Attaches the dialog to the editor's
# base control so it is modal and centred correctly. Queues free on hide.
func _open_picker(pt: PropertyTarget) -> void:
	var source_node := _find_source_node()
	if source_node == null:
		push_warning(
			"[Juice] PropertyPicker: No suitable node found. "
			+ "Select the target node (or its child JuiceBase) in the scene tree first."
		)
		return

	var dialog: ConfirmationDialog = _DialogScript.new()
	dialog.setup(source_node, pt)

	# Attach to the editor base control so the dialog is properly modal.
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(420, 520))

	# Clean up after the dialog is dismissed (OK, Cancel, or X button).
	dialog.popup_hide.connect(dialog.queue_free)


# =============================================================================
# HELPERS
# =============================================================================

# Resolves the best-guess node whose properties should be listed in the picker.
# Strategy:
#   1. If a single JuiceBase is selected → return its parent (the typical target).
#   2. If any other single node is selected → return that node directly.
#   3. Nothing selected or multi-selection → return null (caller shows warning).
func _find_source_node() -> Node:
	var selection := EditorInterface.get_selection().get_selected_nodes()
	if selection.is_empty():
		return null

	if selection.size() > 1:
		# Multi-selection is ambiguous — which node's properties would we show?
		return null

	var node := selection[0]
	if node is JuiceBase and node.get_parent() != null:
		# JuiceBase is typically a child of the node it animates.
		return node.get_parent()

	return node
