## F1_fresh_juice_node.gd
## ============================================================================
## Scenario: F1 — Developer inspects a freshly added JuiceControl
## Family: F — Inspector Plugin property visibility
##
## What a developer does:
##   Adds a new JuiceControl to a scene. No recipe assigned, all settings
##   at defaults (trigger_source = PARENT, loop_count = 1, mode = STACK).
##   Inspects the node and expects a clean, uncluttered inspector.
##
## What to assert:
##   - trigger_source_path is hidden (PARENT source, no path needed)
##   - loop_delay is hidden (loop_count == 1, no looping)
##   - seq_custom_targets is hidden (mode == STACK, no sequencer)
##   - manual_trigger_signal is hidden (trigger_on == ON_READY, not MANUAL)
##   - _get_configuration_warnings() contains a recipe-missing warning
##
## Pre-conditions:
##   - Any scene is open in the editor (scene root must exist)
##   - A JuiceControl will be created and cleaned up by this test
## ============================================================================
func run():
	var scene_root = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return {"error": "No scene open in editor — open any scene first"}

	# Create a fresh JuiceControl at default settings.
	# Defaults: trigger_source = PARENT, loop_count = 1, mode = STACK,
	#           trigger_on = ON_READY, no recipe.
	var node := JuiceControl.new()
	node.name = "F1_TestJuiceControl"
	scene_root.add_child(node)
	node.owner = scene_root

	# Instantiate plugin to test _parse_property visibility decisions.
	var plugin_script = load("res://addons/Juice_V2/Editor/JuiceEditorInspectorPlugin.gd")
	var plugin = plugin_script.new()

	# Helper: call _parse_property with dummy type/hint — plugin ignores them.
	var _h := func(prop: String) -> bool:
		return plugin._parse_property(node, TYPE_INT, prop,
			PROPERTY_HINT_NONE, "", PROPERTY_USAGE_DEFAULT, false)

	var results := {
		# Inspector plugin show/hide checks
		"trigger_source_path_hidden": _h.call("trigger_source_path"),
		"loop_delay_hidden": _h.call("loop_delay"),
		"seq_custom_targets_hidden": _h.call("seq_custom_targets"),
		"manual_trigger_signal_hidden": _h.call("manual_trigger_signal"),
		"auto_connect_parent_visible": not _h.call("auto_connect_parent"),
		# Configuration warnings — a fresh node with no recipe should warn
		"config_warnings": node._get_configuration_warnings(),
		"has_recipe_warning": false,
	}

	# Check if any warning mentions "recipe"
	for warning in results["config_warnings"]:
		if "recipe" in warning.to_lower() or "Recipe" in warning:
			results["has_recipe_warning"] = true
			break

	results["all_visibility_correct"] = (
		results["trigger_source_path_hidden"] and
		results["loop_delay_hidden"] and
		results["seq_custom_targets_hidden"] and
		results["manual_trigger_signal_hidden"] and
		results["auto_connect_parent_visible"]
	)

	# Clean up — remove the test node
	node.queue_free()

	return results
