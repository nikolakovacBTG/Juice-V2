## Intercepts Juice typed Resource arrays and replaces the native array editor
## with JuiceArrayEditor for consistent row-based UX across all Juice arrays.
##
## Registered alongside JuiceEditorInspectorPlugin in juice_plugin.gd.

# =============================================================================
# WHAT: EditorInspectorPlugin that intercepts TYPE_ARRAY properties on Juice
#       Resources and JuiceBase nodes, replacing the native editor with
#       JuiceArrayEditor for a unified row UX.
# WHY:  Godot's native array editor shows raw class names, requires multiple
#       clicks to add typed resources, and gives no context-menu for resource
#       operations. By intercepting at the property parsing level, we swap in
#       JuiceArrayEditor which provides type-aware auto-add, ⋮ menus, drag
#       reorder, and inline sub-inspectors — all from a single component.
# SYSTEM: Juice System (addons/Juice_V2/Editor/) — EDITOR ONLY.
# DOES NOT: Handle non-array properties (those use the default inspector or
#           other plugins like PropertyPickerPlugin).
# =============================================================================

@tool
extends EditorInspectorPlugin


# =============================================================================
# CONFIGURATION
# =============================================================================

# Class names whose typed arrays we intercept.
# Any object that `is` one of these types gets our custom array editor.
const JUICE_BASE_CLASSES: Array[String] = [
	"JuiceBase",
	"JuiceEffectBase",
	"JuiceRecipe",
]

# Preloaded script for the chain_to sibling picker editor.
const ChainToArrayEditorScript := preload("res://addons/Juice_V2/Editor/ChainToArrayEditor.gd")


# =============================================================================
# ENTRY POINT
# =============================================================================

# Accept all Juice base classes and their subclasses.
# This covers JuiceBase nodes, JuiceEffectBase resources, and JuiceRecipe resources.
func _can_handle(object: Object) -> bool:
	if object is JuiceBase:
		return true
	if object is JuiceEffectBase:
		return true
	if object is JuiceRecipe:
		return true
	return false


# =============================================================================
# PROPERTY INTERCEPTION
# =============================================================================

# Called for every property on the inspected object.
# Return true to consume the property (replace with our custom editor).
# Return false to let the default inspector handle it.
func _parse_property(object: Object, type: Variant.Type, name: String,
		hint_type: PropertyHint, hint_string: String,
		_usage_flags: int, _wide: bool) -> bool:

	# Only intercept array properties.
	if type != TYPE_ARRAY:
		return false

	# chain_to uses a specialized sibling-picker editor instead of the
	# generic JuiceArrayEditor. It shows only sibling effects from the
	# same recipe in a multi-select popup.
	if name == "chain_to" and object is JuiceEffectBase:
		var chain_editor := ChainToArrayEditorScript.new()
		add_property_editor(name, chain_editor)
		return true

	# Only intercept arrays with a typed resource hint.
	# Two formats arrive via _get_property_list():
	#   PROPERTY_HINT_ARRAY_TYPE: hint_string = "ClassName"
	#     OR the composite format: "24/17:ClassName" (TYPE_OBJECT/RESOURCE_TYPE:class)
	#   PROPERTY_HINT_TYPE_STRING: hint_string = "24/17:Class1,Class2,..."
	# Both formats can contain the "24/17:" prefix. We normalize first.
	var is_resource_array := false
	var normalized_hint := hint_string

	# Strip the "TYPE_OBJECT/HINT:ClassName" prefix if present.
	# This handles both PROPERTY_HINT_ARRAY_TYPE and PROPERTY_HINT_TYPE_STRING
	# when _get_property_list() uses the composite format.
	if ":" in hint_string:
		var prefix: String = hint_string.get_slice(":", 0)
		if prefix.begins_with(str(TYPE_OBJECT)):
			normalized_hint = hint_string.get_slice(":", 1)

	if (hint_type == PROPERTY_HINT_ARRAY_TYPE or hint_type == PROPERTY_HINT_TYPE_STRING) \
			and not normalized_hint.is_empty():
		# Check if the first class in the hint is a Juice Resource-derived class.
		var first_class := normalized_hint.get_slice(",", 0)
		is_resource_array = _is_juice_resource_class(first_class)

	if not is_resource_array:
		return false

	# --- Intercepted: create our custom array editor ---
	# Pass normalized_hint (prefix stripped) so JuiceArrayEditor can parse class names.
	var editor := JuiceArrayEditor.new()
	var add_label := _get_add_button_label(normalized_hint, name)
	editor.configure(normalized_hint, hint_type, _get_type_color(normalized_hint), add_label)
	add_property_editor(name, editor)
	return true


# =============================================================================
# HELPERS
# =============================================================================

# Check if a class name is a Juice resource type (or subclass thereof).
# Searches both ClassDB (native) and ProjectSettings global classes (GDScript).
func _is_juice_resource_class(class_name_str: String) -> bool:
	# Check native ClassDB first.
	if ClassDB.class_exists(class_name_str):
		return ClassDB.is_parent_class(class_name_str, "Resource")

	# Check GDScript global classes — walk the inheritance chain.
	var global_classes: Array[Dictionary] = ProjectSettings.get_global_class_list()
	var current := class_name_str
	for _depth in range(20):  # Guard against infinite loops.
		var found := false
		for cls: Dictionary in global_classes:
			if cls.get("class", "") == current:
				var base: String = cls.get("base", "")
				if base == "Resource" or ClassDB.is_parent_class(base, "Resource"):
					return true
				current = base
				found = true
				break
		if not found:
			break
	return false


# Assign a type-color based on the resource class family.
# Phase 5 will finalize the palette; these are reasonable defaults.
func _get_type_color(hint_string: String) -> Color:
	var class_name_str: String
	if ":" in hint_string:
		class_name_str = hint_string.get_slice(":", 1).get_slice(",", 0)
	else:
		class_name_str = hint_string

	# Match against known Juice resource families.
	if "PropertyTarget" in class_name_str:
		return Color(0.35, 0.75, 0.55)  # Green — property targets.
	if "JuiceEffect" in class_name_str:
		return Color(0.45, 0.55, 0.95)  # Blue — effects in recipe.
	if "CallMethodEntry" in class_name_str:
		return Color(0.85, 0.65, 0.35)  # Orange — method calls.
	if "SignalEmitEntry" in class_name_str:
		return Color(0.75, 0.45, 0.75)  # Purple — signal emissions.

	# Default neutral strip for unrecognized types.
	return Color(0.4, 0.4, 0.4)


# Derive a context-appropriate label for the array's Add button.
# Uses the property name first (most specific), then falls back to the
# class family in the hint_string. This gives designers clear, action-oriented
# buttons: "+ Add Juice", "+ Add Target", "+ Add Method", "+ Add Signal".
func _get_add_button_label(hint_string: String, property_name: String) -> String:
	# Property name is the most reliable discriminator.
	match property_name:
		"effects":
			return "+ Add Juice"
		"property_targets":
			return "+ Add Target"
		"methods":
			return "+ Add Method"

	# Fallback: check the class family in the hint_string.
	var class_name_str: String
	if ":" in hint_string:
		class_name_str = hint_string.get_slice(":", 1).get_slice(",", 0)
	else:
		class_name_str = hint_string

	if "PropertyTarget" in class_name_str:
		return "+ Add Target"
	if "JuiceEffect" in class_name_str:
		return "+ Add Juice"
	if "CallMethodEntry" in class_name_str:
		return "+ Add Method"
	if "SignalEmitEntry" in class_name_str:
		return "+ Add Signal"

	return "+ Add Element"
