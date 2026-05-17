## Editor plugin that replaces the property_path text field on PropertyTarget
## sub-resources with a [Pick…] button that opens PropertyPickerDialog.

# =============================================================================
# WHAT: EditorInspectorPlugin that intercepts PropertyTarget resources in the
#       inspector. Replaces the raw "property_path" string field with a button
#       that opens the visual property picker dialog.
# WHY:  Browsing available properties from a dropdown is far better UX than
#       typing indexed paths manually.
# SYSTEM: Juice System (addons/Juice_V2/Editor/) — EDITOR ONLY.
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

## Custom inspector row for "property_path" — shows a read-only LineEdit that
## opens the property picker dialog when clicked.
## A LineEdit is used (not a Button) because its .text property updates reliably
## across inspector rebuilds — Button.text can get stuck when Godot creates a
## new EditorProperty instance after emit_changed fires.
class PropertyPathEditorProperty extends EditorProperty:

	var _dialog: PropertyPickerDialog
	var _display: LineEdit
	var _updating := false
	# Stored at pick time so _on_properties_confirmed can access them.
	var _current_target: PropertyTarget = null
	var _parent_effect: PropertyJuiceEffectBase = null
	# Paths already configured when the picker was opened (all sibling paths).
	# Used by _on_properties_confirmed to compute which paths are newly selected
	# vs already present, so we don't create duplicate targets on OK.
	var _initial_paths: Array[String] = []

	func _init(dialog: PropertyPickerDialog) -> void:
		_dialog = dialog

		# Read-only LineEdit acts as the value display.
		# editable=false prevents typing but the gui_input still fires for click.
		_display = LineEdit.new()
		_display.placeholder_text = "Pick…"
		_display.editable = false
		_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_display.tooltip_text = "Click to browse available properties."
		# Route mouse clicks through to our handler.
		_display.gui_input.connect(_on_display_gui_input)
		add_child(_display)

	## Called by the inspector to sync the display field with the current resource value.
	## This runs on every inspector rebuild (including after emit_changed fires a new
	## EditorProperty instance) — so the text always reflects the true resource state.
	func _update_property() -> void:
		_updating = true
		var current: String = get_edited_object().get(get_edited_property())
		if current.is_empty():
			_display.text = ""
			_display.placeholder_text = "Pick…"
			_display.tooltip_text = "No property selected. Click to browse."
			# Dim placeholder color — nothing selected yet.
			_display.add_theme_color_override("font_uneditable_color", Color(0.45, 0.45, 0.45))
		else:
			_display.text = current
			_display.tooltip_text = "Current: %s\nClick to change." % current
			# Bright color so the selected property name is clearly visible.
			_display.add_theme_color_override("font_uneditable_color", Color(0.85, 0.95, 1.0))
		_updating = false

	# Opens the picker dialog on left-click. Right-click and other events pass through.
	func _on_display_gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_pick_pressed()

	func _on_pick_pressed() -> void:
		if _dialog == null:
			push_error("[PropertyPickerPlugin] Dialog is null — plugin may not have initialized correctly.")
			return
		var target: PropertyTarget = get_edited_object() as PropertyTarget
		if target == null:
			return

		var node: Node = _resolve_target_node(target)
		if node == null:
			push_warning("[PropertyPickerPlugin] Cannot resolve node for property picker. "
				+ "Make sure node_path is set and the target node exists in the scene.")
			return

		_current_target = target
		_parent_effect = _find_parent_effect()

		# Bug 6 fix: collect paths from ALL sibling property_targets so the picker
		# pre-checks every property already in the effect, not just the clicked one.
		var current_paths: Array[String] = []
		if _parent_effect != null:
			var targets = _parent_effect.get("property_targets")
			if targets is Array:
				for t in targets:
					var p: String = t.get("property_path") if t != null else ""
					if not p.is_empty():
						current_paths.append(p)
		else:
			var cur: String = target.get("property_path")
			if not cur.is_empty():
				current_paths.append(cur)

		# Cache for use in _on_properties_confirmed — must be set before dialog opens.
		_initial_paths = current_paths.duplicate()

		if _dialog.properties_confirmed.is_connected(_on_properties_confirmed):
			_dialog.properties_confirmed.disconnect(_on_properties_confirmed)

		_dialog.properties_confirmed.connect(_on_properties_confirmed, CONNECT_ONE_SHOT)
		# get_class() returns the native base ("Resource") for GDScript objects.
		# Use get_script().get_global_name() to get the actual class_name.
		var family: String = ""
		if _parent_effect != null and _parent_effect.get_script() != null:
			family = _parent_effect.get_script().get_global_name()
		_dialog.open_for_node(node, current_paths, family)

	func _on_properties_confirmed(paths: Array[String]) -> void:
		# Full sync model: after confirmation the array mirrors exactly what's
		# checked in the picker.  Newly checked → added as siblings,
		# unchecked → removed from the array, current target's own path is
		# preserved when still checked.

		# Compute deltas.
		var newly_added: Array[String] = []
		for p in paths:
			if p not in _initial_paths:
				newly_added.append(p)
		var removed: Array[String] = []
		for p in _initial_paths:
			if p not in paths:
				removed.append(p)

		# If nothing changed at all, bail early.
		if newly_added.is_empty() and removed.is_empty():
			_current_target = null
			_parent_effect = null
			return

		var current_path: String = ""
		if _current_target != null:
			current_path = _current_target.get("property_path")

		# Only set when the array structure changes (siblings added/removed).
		# A simple single-target pick only needs emit_changed, not a full
		# inspector rebuild (which collapses the sub-resource fold state).
		var array_changed: bool = false

		# --- Remove unchecked targets from the array ---
		if not removed.is_empty() and _parent_effect != null and is_instance_valid(_parent_effect):
			var targets_arr = _parent_effect.get("property_targets")
			if targets_arr is Array:
				# Walk backwards so indices stay valid during removal.
				for i in range(targets_arr.size() - 1, -1, -1):
					var t = targets_arr[i]
					if t == null:
						continue
					var t_path: String = t.get("property_path")
					if t_path in removed:
						# Don't remove the current target object — clear its path instead.
						if t == _current_target:
							_current_target.set("property_path", "")
							emit_changed(get_edited_property(), "")
							current_path = ""
						else:
							targets_arr.remove_at(i)
				array_changed = true

		# --- Handle current target's path ---
		if current_path.is_empty() and not newly_added.is_empty():
			# Empty target (first-time pick or just cleared) — assign first new pick.
			var primary: String = newly_added.pop_front()
			# Direct write ensures update_property() on the rebuilt inspector
			# reads the correct value (emit_changed → undo/redo timing gap).
			_current_target.set("property_path", primary)
			emit_changed(get_edited_property(), primary)

		# --- Add remaining newly checked paths as sibling targets ---
		if not newly_added.is_empty() and _parent_effect != null and is_instance_valid(_parent_effect):
			for p in newly_added:
				var new_target: PropertyTarget = _current_target.duplicate()
				new_target.property_path = p
				_parent_effect.property_targets.append(new_target)
			array_changed = true

		if array_changed and _parent_effect != null and is_instance_valid(_parent_effect):
			_parent_effect.notify_property_list_changed()
			EditorInterface.get_inspector().refresh()

		_current_target = null
		_parent_effect = null

	# Find the PropertyJuiceEffectBase that owns the current PropertyTarget.
	# When the inspector drills into a PropertyTarget sub-resource, get_edited_object()
	# returns the PropertyTarget, not the parent effect. We walk up the ownership
	# chain by checking if the edited object itself IS the effect, or by scanning
	# the JuiceBase recipe for an effect that contains _current_target.
	func _find_parent_effect() -> PropertyJuiceEffectBase:
		# Case 1: inspector is showing the effect directly (normal top-level edit).
		var obj := EditorInterface.get_inspector().get_edited_object()
		if obj is PropertyJuiceEffectBase:
			return obj as PropertyJuiceEffectBase

		# Case 2: inspector drilled into a sub-resource — walk recipe.effects to find
		# the effect whose property_targets array contains _current_target.
		var juice_node := _find_juice_base_from_selection()
		if juice_node == null:
			return null
		var recipe = juice_node.get("recipe")
		if recipe == null:
			return null
		var effects = recipe.get("effects")
		if not effects is Array:
			return null
		for effect in effects:
			if not effect is PropertyJuiceEffectBase:
				continue
			var targets = (effect as PropertyJuiceEffectBase).get("property_targets")
			if targets is Array:
				for t in targets:
					if t == _current_target:
						return effect as PropertyJuiceEffectBase
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
