## JuiceTestRunner.gd
## ============================================================================
## WHAT: Automated test runner for Juice V1 addon.
## WHY: Verify all properties are live, all effects work correctly across all
##      domains, and regressions are caught after refactors.
## SYSTEM: Tests (tests/)
## DOES NOT: Replace manual visual testing — complements it with automation.
## ============================================================================
##
## USAGE:
##   Headless:  godot --headless --path <project> res://tests/run_tests.tscn
##   Visual:    godot --path <project> res://tests/run_tests.tscn
##   Filter:    godot --path <project> res://tests/run_tests.tscn -- --suite=node_properties
##   One test:  godot --path <project> res://tests/run_tests.tscn -- --test=test_start_delay
##
## Results written to res://tests/results/*.log
## ============================================================================
extends Node

# --- Configuration ---
const RESULTS_DIR := "res://tests/results/"
const SUMMARY_FILE := "res://tests/results/summary.log"

# --- State ---
var _suites: Array = []
var _headless: bool = false
var _suite_filter: String = ""
var _test_filter: String = ""
var _total_pass: int = 0
var _total_fail: int = 0

# --- Visual mode UI ---
var _ui_root: CanvasLayer = null
var _status_label: Label = null
var _results_text: RichTextLabel = null
var _run_button: Button = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Detect headless mode
	_headless = DisplayServer.get_name() == "headless"

	# Parse user args (after -- on command line)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="):
			_suite_filter = arg.substr("--suite=".length())
		elif arg.begins_with("--test="):
			_test_filter = arg.substr("--test=".length())

	# Register all test suites
	_register_suites()

	if _headless:
		await _run_all_tests()
		_write_summary()
		var exit_code := 0 if _total_fail == 0 else 1
		print("Tests complete: %d passed, %d failed. Exit code: %d" % [
			_total_pass, _total_fail, exit_code])
		get_tree().quit(exit_code)
	else:
		_build_visual_ui()
		# Auto-run when played from editor (enables MCP-based test running)
		_on_run_all_pressed()


# =============================================================================
# SUITE REGISTRATION
# =============================================================================

func _register_suites() -> void:
	# --- Add new test suites here ---
	_suites.append(load("res://tests/suites/TestNodeProperties.gd").new())
	_suites.append(load("res://tests/suites/TestTransformControl.gd").new())
	_suites.append(load("res://tests/suites/TestTransform2D.gd").new())
	_suites.append(load("res://tests/suites/TestTransform3D.gd").new())
	_suites.append(load("res://tests/suites/TestSquashStretchControl.gd").new())
	_suites.append(load("res://tests/suites/TestSquashStretch2D.gd").new())
	_suites.append(load("res://tests/suites/TestSquashStretch3D.gd").new())

	# Apply suite filter
	if not _suite_filter.is_empty():
		var filtered: Array = []
		for suite in _suites:
			var sname: String = suite.get_suite_name()
			if sname.contains(_suite_filter):
				filtered.append(suite)
		_suites = filtered

# =============================================================================
# TEST EXECUTION
# =============================================================================

func _run_all_tests() -> void:
	_total_pass = 0
	_total_fail = 0

	# Ensure results directory exists
	DirAccess.make_dir_recursive_absolute(RESULTS_DIR)

	for suite in _suites:
		var suite_name: String = suite.get_suite_name()
		print("[Runner] Starting suite: %s" % suite_name)

		# Apply test filter if specified
		if not _test_filter.is_empty():
			var methods: Array[String] = suite.get_test_methods()
			var filtered: Array[String] = []
			for m in methods:
				if m.contains(_test_filter):
					filtered.append(m)
			if filtered.is_empty():
				print("[Runner] No tests match filter '%s' in suite '%s', skipping" % [
					_test_filter, suite_name])
				continue

		var results: Array[Dictionary] = await suite.run(self)
		_total_pass += suite.get_pass_count()
		_total_fail += suite.get_fail_count()

		# Write suite log file
		_write_suite_log(suite_name, results)

		print("[Runner] Suite '%s': %d passed, %d failed" % [
			suite_name, suite.get_pass_count(), suite.get_fail_count()])

		# Update visual UI if present
		if _status_label:
			_status_label.text = "Pass: %d  Fail: %d" % [_total_pass, _total_fail]
		if _results_text:
			_append_results_to_ui(suite_name, results)

# =============================================================================
# LOG FILE OUTPUT
# =============================================================================

func _write_suite_log(suite_name: String, results: Array[Dictionary]) -> void:
	var path := RESULTS_DIR + suite_name + ".log"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[Runner] Failed to open log file: %s (error: %s)" % [
			path, FileAccess.get_open_error()])
		return

	file.store_line("# Juice V1 Test Results — Suite: %s" % suite_name)
	file.store_line("# Timestamp: %s" % Time.get_datetime_string_from_system())
	file.store_line("# ====================================================")
	file.store_line("")

	var current_test := ""
	for result in results:
		if result.test != current_test:
			current_test = result.test
			file.store_line("--- %s ---" % current_test)
		file.store_line("  [%s] %s" % [result.status, result.message])

	file.store_line("")
	file.store_line("# Summary: %d passed, %d failed out of %d assertions" % [
		results.filter(func(r): return r.status == "PASS").size(),
		results.filter(func(r): return r.status == "FAIL").size(),
		results.size()])

	file.close()
	print("[Runner] Wrote log: %s" % path)


func _write_summary() -> void:
	var file := FileAccess.open(SUMMARY_FILE, FileAccess.WRITE)
	if file == null:
		return

	file.store_line("# Juice V1 Test Summary")
	file.store_line("# Timestamp: %s" % Time.get_datetime_string_from_system())
	file.store_line("# ====================================================")
	file.store_line("")
	file.store_line("Total Pass: %d" % _total_pass)
	file.store_line("Total Fail: %d" % _total_fail)
	file.store_line("Result: %s" % ("ALL PASSED" if _total_fail == 0 else "FAILURES DETECTED"))
	file.store_line("")

	for suite in _suites:
		file.store_line("  Suite '%s': %d passed, %d failed" % [
			suite.get_suite_name(), suite.get_pass_count(), suite.get_fail_count()])

	file.close()

# =============================================================================
# VISUAL MODE
# =============================================================================

func _build_visual_ui() -> void:
	_ui_root = CanvasLayer.new()
	add_child(_ui_root)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	# --- Header bar ---
	var header := HBoxContainer.new()
	vbox.add_child(header)

	_run_button = Button.new()
	_run_button.text = "Run All Tests"
	_run_button.pressed.connect(_on_run_all_pressed)
	header.add_child(_run_button)

	_status_label = Label.new()
	_status_label.text = "Pass: 0  Fail: 0"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_status_label)

	var suite_info := Label.new()
	suite_info.text = "%d suites registered" % _suites.size()
	header.add_child(suite_info)

	# --- Separator ---
	vbox.add_child(HSeparator.new())

	# --- Results area ---
	_results_text = RichTextLabel.new()
	_results_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results_text.bbcode_enabled = true
	_results_text.scroll_following = true
	_results_text.text = "Click 'Run All Tests' to begin.\n"
	vbox.add_child(_results_text)


func _on_run_all_pressed() -> void:
	_run_button.disabled = true
	_results_text.text = ""
	_status_label.text = "Running..."
	await _run_all_tests()
	_write_summary()
	_run_button.disabled = false
	_status_label.text = "Done — Pass: %d  Fail: %d" % [_total_pass, _total_fail]


func _append_results_to_ui(suite_name: String, results: Array[Dictionary]) -> void:
	_results_text.append_text("\n[b]═══ %s ═══[/b]\n" % suite_name)
	var current_test := ""
	for result in results:
		if result.test != current_test:
			current_test = result.test
			_results_text.append_text("\n[u]%s[/u]\n" % current_test)
		if result.status == "PASS":
			_results_text.append_text("  [color=green][PASS][/color] %s\n" % result.message)
		else:
			_results_text.append_text("  [color=red][FAIL][/color] %s\n" % result.message)
