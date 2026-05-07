## Handles registration and retrieval of Juice system project settings.
## A static utility to interact with Juice-specific Godot ProjectSettings.
## Provides safe fallbacks and typed getters for global addon configuration.

class_name JuiceProjectSettings
extends RefCounted

# ============================================================================
# WHAT: Wrapper for Juice-related ProjectSettings.
# WHY: Centralizes property names and types. Prevents typos. Allows us to
#      provide safe default values if the setting hasn't been registered yet.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Register the settings into Godot. That is done by juice_plugin.gd
# ============================================================================

const AUTO_LOCAL_TO_SCENE_KEY := "juice/config/auto_local_to_scene"

## Project Settings key for the global debug master switch.
## When enabled, all JuiceBase nodes log regardless of their per-node debug_enabled flag.
const DEBUG_ENABLED_KEY := "juice/debug/enabled"

## Project Settings key for writing debug logs to a file.
## When enabled, JuiceLogger writes to user://juice_debug.log in addition to console.
const DEBUG_LOG_TO_FILE_KEY := "juice/debug/log_to_file"

## Project Settings key for verbose per-frame console output.
## When false (default), log_delta and log_aggregation are file-only.
## Set to true only when you specifically need per-frame console tracing.
## Expect high console volume — the Godot output panel can overflow at 60fps.
const DEBUG_VERBOSE_KEY := "juice/debug/verbose"

## Returns whether the plugin should aggressively force resources to be
## local to the scene to prevent shared-state preset bugs.
## Default is true for safety.
static func get_auto_local_to_scene() -> bool:
	if ProjectSettings.has_setting(AUTO_LOCAL_TO_SCENE_KEY):
		return ProjectSettings.get_setting(AUTO_LOCAL_TO_SCENE_KEY)
	return true

## Returns whether the global debug master switch is enabled.
static func get_debug_enabled() -> bool:
	return ProjectSettings.get_setting(DEBUG_ENABLED_KEY, false)

## Returns whether file logging is enabled.
static func get_debug_log_to_file() -> bool:
	return ProjectSettings.get_setting(DEBUG_LOG_TO_FILE_KEY, false)

## Returns whether verbose per-frame console output is enabled.
static func get_debug_verbose() -> bool:
	return ProjectSettings.get_setting(DEBUG_VERBOSE_KEY, false)

## Register all Juice-specific settings into the ProjectSettings menu.
## Called by juice_plugin.gd's _enter_tree().
static func register_settings() -> void:
	# --- Config settings ---
	if not ProjectSettings.has_setting(AUTO_LOCAL_TO_SCENE_KEY):
		ProjectSettings.set_setting(AUTO_LOCAL_TO_SCENE_KEY, true)
	
	ProjectSettings.set_initial_value(AUTO_LOCAL_TO_SCENE_KEY, true)
	ProjectSettings.add_property_info({
		"name": AUTO_LOCAL_TO_SCENE_KEY,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "Automatically duplicate preset resources on assign to prevent shared-state modifications."
	})
	
	# --- Debug settings ---
	if not ProjectSettings.has_setting(DEBUG_ENABLED_KEY):
		ProjectSettings.set_setting(DEBUG_ENABLED_KEY, false)
	
	ProjectSettings.set_initial_value(DEBUG_ENABLED_KEY, false)
	ProjectSettings.add_property_info({
		"name": DEBUG_ENABLED_KEY,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "Enable debug logging for ALL Juice nodes. Overrides per-node debug_enabled."
	})
	
	if not ProjectSettings.has_setting(DEBUG_LOG_TO_FILE_KEY):
		ProjectSettings.set_setting(DEBUG_LOG_TO_FILE_KEY, false)
	
	ProjectSettings.set_initial_value(DEBUG_LOG_TO_FILE_KEY, false)
	ProjectSettings.add_property_info({
		"name": DEBUG_LOG_TO_FILE_KEY,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "Write debug logs to user://juice_debug.log in addition to console output."
	})

	if not ProjectSettings.has_setting(DEBUG_VERBOSE_KEY):
		ProjectSettings.set_setting(DEBUG_VERBOSE_KEY, false)
	
	ProjectSettings.set_initial_value(DEBUG_VERBOSE_KEY, false)
	ProjectSettings.add_property_info({
		"name": DEBUG_VERBOSE_KEY,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "Print per-frame delta logs (log_delta, log_aggregation) to the console. Default false prevents output overflow at 60fps. Enable only for interactive per-frame tracing."
	})

