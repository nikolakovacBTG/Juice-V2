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
#           other plugins like PropertyPickerPlugin). Does not handle chain_to
#           arrays — those need a custom sibling-picker (Phase 3).
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

# Property names to SKIP — they need specialized editors (Phase 3+).
const SKIP_PROPERTIES: Array[String] = [
	"chain_to",
]


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

	# Skip properties that need specialized editors.
	if name in SKIP_PROPERTIES:
		return false

	# Only intercept arrays with a typed resource hint.
	# Two formats:
	#   PROPERTY_HINT_ARRAY_TYPE (31): hint_string = "ClassName"
	#   PROPERTY_HINT_TYPE_STRING (23): hint_string = "24/17:Class1,Class2,..."
	var is_resource_array := false

	if hint_type == PROPERTY_HINT_ARRAY_TYPE and not hint_string.is_empty():
		# Check if the class name references a Resource-derived class.
		is_resource_array = _is_juice_resource_class(hint_string)
	elif hint_type == PROPERTY_HINT_TYPE_STRING and ":" in hint_string:
		# Parse "24/17:ClassName,..." format.
		# The "24" is TYPE_OBJECT and "17" is PROPERTY_HINT_RESOURCE_TYPE.
		var prefix: String = hint_string.get_slice(":", 0)
		if prefix.begins_with(str(TYPE_OBJECT)):
			var class_list: String = hint_string.get_slice(":", 1)
			if not class_list.is_empty():
				is_resource_array = true

	if not is_resource_array:
		return false

	# --- Intercepted: create our custom array editor ---
	var editor := JuiceArrayEditor.new()
	editor.configure(hint_string, hint_type, _get_type_color(hint_string))
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
