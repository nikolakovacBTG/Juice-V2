## TestPluginScripts.gd
## ============================================================================
## WHAT: Compilation smoke-test for all editor-only scripts (plugin, director,
##       context). These scripts are never loaded by the regular test runner
##       because they require the editor environment to instantiate — but their
##       GDScript syntax CAN be validated by load() in headless mode.
## WHY:  Plugin parse errors crash the editor silently. The regular test suites
##       only exercise logic classes (JuiceBase, effects, recipes) — they never
##       load juice_plugin.gd. This suite fills that gap: if load() returns null
##       a parse error exists and would disable the plugin at editor startup.
## SYSTEM: Tests (tests/suites/)
## DOES NOT: Test runtime behaviour of editor widgets — only script validity.
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "plugin_scripts"


func get_test_methods() -> Array[String]:
	return [
		"test_v1_plugin_script_loads",
		"test_preview_director_script_loads",
		"test_editor_context_script_loads",
		"test_juice_transport_dock_scene_loads",
		"test_all_v1_addon_scripts_load",
	]


# =============================================================================
# TESTS
# =============================================================================

func test_v1_plugin_script_loads() -> void:
	var script = load("res://addons/Juice_V1/juice_plugin.gd")
	assert_true(script != null,
		"Plugin script: res://addons/Juice_V1/juice_plugin.gd must load without parse errors")


func test_preview_director_script_loads() -> void:
	var script = load("res://addons/Juice_V1/Editor/JuicePreviewDirector.gd")
	assert_true(script != null,
		"Director script: JuicePreviewDirector.gd must load without parse errors")


func test_editor_context_script_loads() -> void:
	var script = load("res://addons/Juice_V1/Editor/JuiceEditorContext.gd")
	assert_true(script != null,
		"Context script: JuiceEditorContext.gd must load without parse errors")


func test_juice_transport_dock_scene_loads() -> void:
	# The .tscn is a PackedScene — load() returns null if the file or any
	# referenced script fails to parse.
	var scene = load("res://addons/Juice_V1/Editor/JuiceTransportDock.tscn")
	assert_true(scene != null,
		"Transport dock scene: JuiceTransportDock.tscn must load without errors")


func test_all_v1_addon_scripts_load() -> void:
	# Enumerate every .gd file under addons/Juice_V1/ and verify each loads.
	# This catches parse errors in ANY addon script, not just the hand-listed ones.
	var dir := DirAccess.open("res://addons/Juice_V1/")
	if dir == null:
		_fail("Cannot open res://addons/Juice_V1/ directory")
		return

	# Use Arrays as accumulators — GDScript ints are value types and would
	# not survive recursive calls. Arrays are reference types and work correctly.
	var failed: Array[String] = []
	var passed: Array[String] = []
	_scan_scripts(dir, "res://addons/Juice_V1/", failed, passed)

	assert_true(passed.size() > 0,
		"Script scan: must find at least 1 .gd file under addons/Juice_V1/ (found %d)" % passed.size())

	if failed.size() > 0:
		for path in failed:
			_fail("Script load FAILED (parse error): %s" % path)
	else:
		_pass("All %d V1 addon scripts loaded without parse errors" % passed.size())


# Recursive helper: scan a directory for .gd files and try to load each.
# Uses Array[String] accumulators (reference semantics) so results survive recursion.
func _scan_scripts(dir: DirAccess, base_path: String,
		failed: Array[String], passed: Array[String]) -> void:
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			var sub_dir := DirAccess.open(base_path + file_name + "/")
			if sub_dir:
				_scan_scripts(sub_dir, base_path + file_name + "/", failed, passed)
		elif file_name.ends_with(".gd"):
			var full_path := base_path + file_name
			var script = load(full_path)
			if script == null:
				failed.append(full_path)
			else:
				passed.append(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
