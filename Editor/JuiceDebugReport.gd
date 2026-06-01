## Assembles and exports a Juice V1 bug report as a JSON file.
##
## Call [method export] from the editor plugin menu to generate the report.
## The report is written to [code]user://juice_debug_report.json[/code]
## and opened in the OS default application immediately.

# ============================================================================
# WHAT: Static utility that collects system context, Juice project settings,
#       a JuiceBase node inventory from the current scene, and the runtime
#       debug log, then writes them to a self-contained JSON file.
# WHY:  Bug reports from Juice users need to be machine-parseable. A single
#       JSON file can be attached to a bug report and read by AI agents or
#       support tooling without requiring manual log extraction or screenshots.
#       JSON is preferred over plain text so field access is unambiguous.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Capture runtime animation state (effects ticking mid-frame) —
#            that is the log file's job. Does not work in release builds.
#            Does not clear the log file after export — that is a user action.
# ============================================================================
#
# USER FLOW:
# 1. In Project Settings, enable juice/debug/log_to_file = true
# 2. Enable debug_enabled on the relevant JuiceBase node (or enable the
#    global master switch juice/debug/enabled)
# 3. Run the scene and reproduce the bug
# 4. Stop the scene
# 5. Tools → Export Juice Bug Report
# 6. juice_debug_report.json opens — attach it to the bug report
#
# WHY log_to_file is required: JuiceLogger stores the ring buffer in a static
# var that resets when the game stops in the editor. The log FILE persists
# after stop, so the report always reads from the file, not the ring buffer.
# ============================================================================

class_name JuiceDebugReport
extends RefCounted

# =============================================================================
# CONFIGURATION
# =============================================================================

## Report schema version. Increment when the JSON structure changes.
const REPORT_VERSION := "1.0"

## Output path for the generated report.
const REPORT_PATH := "user://juice_debug_report.json"


# =============================================================================
# PUBLIC API
# =============================================================================

## Assemble and export a bug report JSON to user://juice_debug_report.json.
##
## Pass the currently edited scene root so JuiceBase nodes can be inventoried.
## The scene root is provided by the caller (juice_plugin.gd) because this
## static class has no access to EditorInterface.
##
## Returns the absolute filesystem path the report was written to,
## or an empty string if the export failed (error is pushed to the Godot log).
static func export(scene_root: Node) -> String:
	if not OS.is_debug_build():
		push_warning("[Juice] JuiceDebugReport.export() called in a non-debug build. Aborted.")
		return ""

	var report := _build_report(scene_root)
	var json_string := JSON.stringify(report, "\t")

	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[Juice] JuiceDebugReport: Could not open %s for writing. Error: %s" % [
			REPORT_PATH, FileAccess.get_open_error()])
		return ""

	file.store_string(json_string)
	# Explicitly null the reference to flush and close the file handle.
	file = null

	var abs_path := ProjectSettings.globalize_path(REPORT_PATH)
	OS.shell_open(abs_path)
	return abs_path


# =============================================================================
# CORE LOGIC
# =============================================================================

# Assembles the full report dictionary from all data sources.
static func _build_report(scene_root: Node) -> Dictionary:
	return {
		"report_version": REPORT_VERSION,
		"generated": Time.get_datetime_string_from_system(),
		"godot_version": Engine.get_version_info().get("string", "unknown"),
		"os": OS.get_name(),
		"project": ProjectSettings.get_setting("application/config/name", "Unknown"),
		"juice_settings": _collect_juice_settings(),
		"juice_nodes": _collect_juice_nodes(scene_root),
		"log_source": JuiceLogger.LOG_FILE_PATH,
		"log": _read_log_file(),
	}


# Collects the current state of all Juice-related project settings.
# These tell us how logging was configured when the bug was reproduced —
# a common oversight is reporting a bug with log_to_file disabled.
static func _collect_juice_settings() -> Dictionary:
	return {
		"debug_enabled": JuiceProjectSettings.get_debug_enabled(),
		"log_to_file": JuiceProjectSettings.get_debug_log_to_file(),
		"verbose": JuiceProjectSettings.get_debug_verbose(),
	}


# Walks the scene tree and returns an inventory of all JuiceBase nodes.
# This tells us which nodes existed in the scene and how they were configured,
# independently of what the log recorded at runtime.
static func _collect_juice_nodes(scene_root: Node) -> Array:
	var nodes: Array = []
	if scene_root == null:
		return nodes
	_walk_for_juice_nodes(scene_root, scene_root, nodes)
	return nodes


# Recursive depth-first walk that finds every JuiceBase in the subtree.
# Using the `is` operator for type-safe discovery — never string-matching node names.
static func _walk_for_juice_nodes(node: Node, scene_root: Node, result: Array) -> void:
	if node is JuiceBase:
		result.append(_describe_juice_node(node, scene_root))
	for child in node.get_children():
		_walk_for_juice_nodes(child, scene_root, result)


# Extracts a description dictionary from a single JuiceBase node.
# Captures static inspector config, not runtime animation state.
static func _describe_juice_node(juice_node: JuiceBase, scene_root: Node) -> Dictionary:
	# Use scene_root.get_path_to() so the path is relative to the scene root,
	# matching what appears in the Godot scene dock — easier for bug triage.
	var scene_path := str(scene_root.get_path_to(juice_node))

	var recipe_name := ""
	var effect_names: Array = []
	var effect_count := 0

	var recipe: JuiceRecipe = juice_node.recipe
	if recipe != null:
		# Prefer resource_name (user-authored) over the script class name.
		if not recipe.resource_name.is_empty():
			recipe_name = recipe.resource_name
		else:
			var script: Script = recipe.get_script()
			if script != null:
				recipe_name = script.get_global_name()

		effect_count = recipe.effects.size()
		for effect in recipe.effects:
			if effect == null:
				continue
			var effect_script: Script = effect.get_script()
			if effect_script != null:
				effect_names.append(effect_script.get_global_name())
			else:
				effect_names.append(effect.get_class())

	return {
		"scene_path": scene_path,
		"mode": JuiceBase.Mode.keys()[juice_node.mode],
		"debug_enabled": juice_node.debug_enabled,
		"trigger_on": JuiceBase.TriggerEvent.keys()[juice_node.trigger_on],
		"recipe": recipe_name,
		"effect_count": effect_count,
		"effects": effect_names,
	}


# Reads the log file written by JuiceLogger and returns its lines as an Array.
# Returns a diagnostic message array if the file does not exist, so the report
# is still useful for diagnosing the missing-log case itself.
static func _read_log_file() -> Array:
	if not FileAccess.file_exists(JuiceLogger.LOG_FILE_PATH):
		return [
			"[JuiceDebugReport] No log file found at: %s" % JuiceLogger.LOG_FILE_PATH,
			"[JuiceDebugReport] To capture logs: enable juice/debug/log_to_file in Project Settings,"
			+ " then reproduce the bug, then export this report."
		]

	var file := FileAccess.open(JuiceLogger.LOG_FILE_PATH, FileAccess.READ)
	if file == null:
		return [
			"[JuiceDebugReport] Could not open log file at: %s (error: %s)" % [
				JuiceLogger.LOG_FILE_PATH, FileAccess.get_open_error()]
		]

	var lines: Array = []
	while not file.eof_reached():
		var line := file.get_line()
		if not line.is_empty():
			lines.append(line)
	return lines
