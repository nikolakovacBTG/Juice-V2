## Editor plugin that replaces the property_path text field on PropertyTarget
## sub-resources with a [Pick…] button that opens PropertyPickerDialog.

# =============================================================================
# WHAT: EditorInspectorPlugin that intercepts PropertyTarget resources in the
#       inspector. Replaces the raw "property_path" string field with a button
#       that opens the visual property picker dialog.
# WHY:  Browsing available properties from a dropdown is far better UX than
#       typing indexed paths manually.
# SYSTEM: Juice System (addons/Juice_V1/Editor/) — EDITOR ONLY.
# DOES NOT: Run at runtime — registered/deregistered via juice_plugin.gd.
# DOES NOT: Handle the dialog UI itself — that lives in PropertyPickerDialog.
# =============================================================================

@tool
class_name PropertyPickerPlugin
extends EditorInspectorPlugin


# =============================================================================
# SINGLETON DIALOG
# =============================================================================

# One shared dialog instance reused for all PropertyTarget rows to avoid
# creating multiple windows. Owned by this plugin object.
var _dialog: PropertyPickerDialog = null


func _init() -> void:
	_dialog = PropertyPickerDialog.new()


## Must be added to the editor scene tree to function as a popup Window.
## Called by juice_plugin.gd after add_inspector_plugin().
func add_dialog_to_editor(editor_base: Control) -> void:
	if _dialog.get_parent() == null:
		editor_base.add_child(_dialog)


func cleanup() -> void:
	if is_instance_valid(_dialog) and _dialog.get_parent() != null:
		_dialog.get_parent().remove_child(_dialog)
	_dialog = null


# =============================================================================
# EditorInspectorPlugin API
# =============================================================================

func _can_handle(object: Object) -> bool:
	# Only intercept PropertyTarget resources (and subclasses).
	return object is PropertyTarget


func _parse_property(
	object: Object,
	_type: Variant.Type,
	name: String,
	_hint_type: PropertyHint,
	_hint_string: String,
	_usage_flags: int,
	_wide: bool
) -> bool:
	if name == "property_path":
		# Replace the default string field with our custom button editor.
		var editor := PropertyPathEditorProperty.new(_dialog)
		add_property_editor("property_path", editor)
		return true  # Consume — prevent default string field from rendering.
	return false


# =============================================================================
# CUSTOM EDITOR PROPERTY (inner class)
# =============================================================================

## Custom inspector row for "property_path" — shows a button that opens the
## property picker dialog instead of a raw editable string field.
class PropertyPathEditorProperty extends EditorProperty:

	var _dialog: PropertyPickerDialog
	var _btn: Button
	var _updating := false

	func _init(dialog: PropertyPickerDialog) -> void:
		_dialog = dialog

		# Button fills the row label area.
		_btn = Button.new()
		_btn.text = "Pick…"
		_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_btn.clip_text = true
		_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_btn.pressed.connect(_on_pick_pressed)
		add_child(_btn)

	## Called by the inspector to sync the button label with the current value.
	func update_property() -> void:
		_updating = true
		var current: String = get_edited_object().get(get_edited_property())
		if current.is_empty():
			_btn.text = "Pick…"
			_btn.tooltip_text = "No property selected. Click to browse."
		else:
			_btn.text = current
			_btn.tooltip_text = "Current: %s\nClick to change." % current
		_updating = false

	func _on_pick_pressed() -> void:
		var target: PropertyTarget = get_edited_object() as PropertyTarget
		if target == null:
			return

		# Resolve the target node from the edited scene root.
		# We need the node to enumerate its properties in the dialog.
		var scene_root := EditorInterface.get_edited_scene_root()
		if scene_root == null:
			return

		var node: Node
		if target.node_path == NodePath():
			# Empty node_path = intending to target the juiced node.
			# Open dialog on scene root as a fallback since we don't know the
			# host JuiceBase from here. User can still pick a property name.
			node = scene_root
		else:
			node = scene_root.get_node_or_null(target.node_path)

		if node == null:
			push_warning("[PropertyPickerPlugin] Cannot resolve node_path '%s'. "
				% str(target.node_path) +
				"Set node_path first, then click Pick.")
			return

		# Build the list of currently-configured paths for pre-checking.
		# We only have the current single path here (one PropertyTarget = one property).
		var current_paths: Array[String] = []
		var cur: String = target.get("property_path")
		if not cur.is_empty():
			current_paths.append(cur)

		# Disconnect any previous confirmation signal to avoid stacking.
		if _dialog.properties_confirmed.is_connected(_on_properties_confirmed):
			_dialog.properties_confirmed.disconnect(_on_properties_confirmed)

		_dialog.properties_confirmed.connect(_on_properties_confirmed, CONNECT_ONE_SHOT)
		_dialog.open_for_node(node, current_paths)

	func _on_properties_confirmed(paths: Array[String]) -> void:
		if paths.is_empty():
			return
		# Use the first selected path for this single PropertyTarget.
		# If multiple were selected, the caller (parent effect) should handle
		# appending additional entries — for now we set the first.
		emit_changed(get_edited_property(), paths[0])
