## JuiceProjectSettings.gd
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

## Returns whether the plugin should aggressively force resources to be
## local to the scene to prevent shared-state preset bugs.
## Default is true for safety.
static func get_auto_local_to_scene() -> bool:
	if ProjectSettings.has_setting(AUTO_LOCAL_TO_SCENE_KEY):
		return ProjectSettings.get_setting(AUTO_LOCAL_TO_SCENE_KEY)
	return true

## Register all Juice-specific settings into the ProjectSettings menu.
## Called by juice_plugin.gd's _enter_tree().
static func register_settings() -> void:
	if not ProjectSettings.has_setting(AUTO_LOCAL_TO_SCENE_KEY):
		ProjectSettings.set_setting(AUTO_LOCAL_TO_SCENE_KEY, true)
	
	ProjectSettings.set_initial_value(AUTO_LOCAL_TO_SCENE_KEY, true)
	# Optional: you can set hints using ProjectSettings.add_property_info()
	var info = {
		"name": AUTO_LOCAL_TO_SCENE_KEY,
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "Automatically duplicate preset resources on assign to prevent shared-state modifications."
	}
	ProjectSettings.add_property_info(info)
	
	# Make sure the settings are saved if they were just created.
	# We don't want to call save() needlessly, but it's fine on first init.
