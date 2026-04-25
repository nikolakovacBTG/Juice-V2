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
	# Stored at pick time so _on_properties_confirmed can access them.
	var _current_target: PropertyTarget = null
	var _parent_effect: PropertyJuiceEffectBase = null

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
		if _dialog == null:
			push_error("[PropertyPickerPlugin] Dialog is null — plugin may not have initialized correctly.")
			return
		var target: PropertyTarget = get_edited_object() as PropertyTarget
		if target == null:
			return

		# Resolve the target node.
		# PropertyTarget.node_path is relative to the JuiceBase node that owns the
		# effect (because the inspector's NodePath picker stores paths relative to
		# the closest Node ancestor of the resource). We find the JuiceBase node
		# from the editor selection context.
		var node: Node = _resolve_target_node(target)

		if node == null:
			push_warning("[PropertyPickerPlugin] Cannot resolve node for property picker. "
				+ "Make sure node_path is set and the target node exists in the scene.")
			return

		# Cache references for use in _on_properties_confirmed.
		_current_target = target
		_parent_effect = _find_parent_effect()

		# Build the list of currently-configured paths for pre-checking.
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

		# Set the first path on the current PropertyTarget (normal single-select flow).
		emit_changed(get_edited_property(), paths[0])

		# For each additional selected path, create a sibling PropertyTarget on the parent effect.
		if paths.size() > 1 and _parent_effect != null and is_instance_valid(_parent_effect):
			for i in range(1, paths.size()):
				# Duplicate preserves node_path and any existing amplitude/strength config.
				var new_target: PropertyTarget = _current_target.duplicate()
				new_target.property_path = paths[i]
				_parent_effect.property_targets.append(new_target)

			# Notify Godot that property_targets changed so the inspector reflects new elements.
			_parent_effect.notify_property_list_changed()
			EditorInterface.get_inspector().refresh()

		# Clear cached references.
		_current_target = null
		_parent_effect = null

	# Find the PropertyJuiceEffectBase that owns the current PropertyTarget.
	# Returns null if the top-level inspected object isn't a PropertyJuiceEffectBase.
	func _find_parent_effect() -> PropertyJuiceEffectBase:
		var obj := EditorInterface.get_inspector().get_edited_object()
		if obj is PropertyJuiceEffectBase:
			return obj as PropertyJuiceEffectBase
		return null

	# Resolve the target node from the PropertyTarget's node_path.
	# node_path is relative to the JuiceBase node that owns the effect chain.
	func _resolve_target_node(target: PropertyTarget) -> Node:
		var scene_root := EditorInterface.get_edited_scene_root()
		if scene_root == null:
			return null

		# Strategy 1: Robust Context Discovery
		var context_host: Node = JuiceEditorContext.get_host_node(target)
		if context_host != null:
			if target.node_path == NodePath():
				return context_host
			var resolved := context_host.get_node_or_null(target.node_path)
			if resolved != null:
				return resolved

		# Strategy 2: Fragile Selection Discovery (fallback)
		var juice_node: Node = _find_juice_base_from_selection()

		if juice_node != null:
			if target.node_path == NodePath():
				# Empty = target the juiced node itself (same convention as runtime).
				return juice_node
			var resolved := juice_node.get_node_or_null(target.node_path)
			if resolved != null:
				return resolved

		# Strategy 3: Fallback — try resolving from scene root.
		# This handles cases where the node_path is an absolute scene path.
		if target.node_path != NodePath():
			var resolved := scene_root.get_node_or_null(target.node_path)
			if resolved != null:
				return resolved

		# Strategy 4: Last resort — use scene root.
		push_warning("[PropertyPickerPlugin] Could not resolve node_path '%s' from JuiceBase or scene root. "
			% str(target.node_path)
			+ "Showing scene root properties. Set node_path to the correct target node.")
		return scene_root

	# Find the JuiceBase node from the current editor selection.
	# The selected node is usually the target node (parent of JuiceBase) or
	# the JuiceBase itself.
	func _find_juice_base_from_selection() -> Node:
		var selection := EditorInterface.get_selection()
		var selected_nodes := selection.get_selected_nodes()

		for node in selected_nodes:
			# Check if the selected node IS a JuiceBase.
			if node is JuiceBase:
				return node
			# Check direct children for JuiceBase.
			for child in node.get_children():
				if child is JuiceBase:
					return child
		return null
