## TestEditorInspectorPlugin.gd
## ============================================================================
## WHAT: Fast regression tests for the inspector changes made in Phase 3.
## WHY:  These headless checks catch the most common regressions after Phase 3:
##       (a) did _validate_property break, losing Toggle visibility logic?
##       (b) did domain node recipe narrowing survive the refactor?
##       (c) does the plugin script still load without parse errors?
##
##       This suite does NOT exercise the plugin's _parse_property show/hide
##       logic — EditorInspectorPlugin is an editor-only class not
##       instantiable in game/headless mode. That behaviour is covered by
##       Tier 2 MCP tests F1 and F2 in tests/mcp_editor/.
## SYSTEM: Tests (tests/)
## DOES NOT: Test property show/hide (that is Tier 2 / MCP only), transport
##           preview, or runtime animation behaviour.
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "editor_inspector_plugin"


func get_test_methods() -> Array[String]:
	return [
		"test_plugin_v2_script_loads",
		"test_trigger_behaviour_shows_toggle_for_press",
		"test_trigger_behaviour_shows_toggle_for_manual",
		"test_trigger_behaviour_hides_toggle_for_release",
		"test_trigger_behaviour_hides_toggle_for_on_ready",
		"test_recipe_hint_narrowed_to_control_recipe",
		"test_recipe_hint_narrowed_to_2d_recipe",
		"test_recipe_hint_narrowed_to_3d_recipe",
	]


# =============================================================================
# HELPERS
# =============================================================================

# Get the hint_string for a named property from a node's property list.
# _validate_property() fires during get_property_list() even in headless mode,
# so the returned hint_string reflects any dynamic mutations.
func _get_hint_string(node: Node, prop_name: String) -> String:
	for prop in node.get_property_list():
		if prop.name == prop_name:
			return prop.hint_string
	return ""


# =============================================================================
# TESTS — plugin script integrity
# =============================================================================

func test_plugin_v2_script_loads() -> void:
	# Regression: plugin parse errors crash the editor silently.
	var script = load("res://addons/Juice_V2/Editor/JuiceEditorInspectorPlugin.gd")
	assert_true(script != null,
		"V2 inspector plugin must load without parse errors")


# =============================================================================
# TESTS — trigger_behaviour Toggle hint mutation (_validate_property on JuiceBase)
# =============================================================================
#
# JuiceBase._validate_property() mutates trigger_behaviour's enum hint_string to
# include or exclude the "Toggle" option based on trigger_on.
# Triggers with a natural paired edge (ON_PRESS, ON_MOUSE_ENTERED, ON_FOCUS,
# MANUAL) support Toggle. All others (momentary, one-shot) do not.

func test_trigger_behaviour_shows_toggle_for_press() -> void:
	var node := JuiceControl.new()
	node.trigger_on = JuiceBase.TriggerEvent.ON_PRESS
	var hint := _get_hint_string(node, "trigger_behaviour")
	node.free()
	assert_true("Toggle" in hint,
		"trigger_behaviour hint must include Toggle when trigger_on == ON_PRESS " +
		"(has natural press/release pair). Got: '%s'" % hint)


func test_trigger_behaviour_shows_toggle_for_manual() -> void:
	var node := JuiceControl.new()
	node.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var hint := _get_hint_string(node, "trigger_behaviour")
	node.free()
	assert_true("Toggle" in hint,
		"trigger_behaviour hint must include Toggle when trigger_on == MANUAL " +
		"(caller supplies polarity). Got: '%s'" % hint)


func test_trigger_behaviour_hides_toggle_for_release() -> void:
	var node := JuiceControl.new()
	node.trigger_on = JuiceBase.TriggerEvent.ON_RELEASE
	var hint := _get_hint_string(node, "trigger_behaviour")
	node.free()
	assert_false("Toggle" in hint,
		"trigger_behaviour hint must NOT include Toggle for ON_RELEASE " +
		"(one-shot, no natural start edge). Got: '%s'" % hint)


func test_trigger_behaviour_hides_toggle_for_on_ready() -> void:
	var node := JuiceControl.new()
	node.trigger_on = JuiceBase.TriggerEvent.ON_READY
	var hint := _get_hint_string(node, "trigger_behaviour")
	node.free()
	assert_false("Toggle" in hint,
		"trigger_behaviour hint must NOT include Toggle for ON_READY " +
		"(fires once at startup, no counterpart). Got: '%s'" % hint)


# =============================================================================
# TESTS — recipe hint narrowing (_validate_property on domain nodes)
# =============================================================================
#
# Each domain node's _validate_property() narrows the recipe property's
# hint_string to the correct domain recipe type, so the inspector's
# resource picker only offers the matching recipe class.

func test_recipe_hint_narrowed_to_control_recipe() -> void:
	var node := JuiceControl.new()
	var hint := _get_hint_string(node, "recipe")
	node.free()
	assert_equal(hint, "JuiceControlRecipe",
		"JuiceControl recipe hint must be 'JuiceControlRecipe'")


func test_recipe_hint_narrowed_to_2d_recipe() -> void:
	var node := Juice2D.new()
	var hint := _get_hint_string(node, "recipe")
	node.free()
	assert_equal(hint, "Juice2DRecipe",
		"Juice2D recipe hint must be 'Juice2DRecipe'")


func test_recipe_hint_narrowed_to_3d_recipe() -> void:
	var node := Juice3D.new()
	var hint := _get_hint_string(node, "recipe")
	node.free()
	assert_equal(hint, "Juice3DRecipe",
		"Juice3D recipe hint must be 'Juice3DRecipe'")
