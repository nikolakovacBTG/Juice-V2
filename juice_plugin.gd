## juice_plugin.gd
## EditorPlugin entry point for the Juice V1 addon.
##
## Registers editor inspector plugins so custom PropertyTarget rows show
## the [Pick…] button instead of raw string fields.
## Also provides the "Project → Tools → Export Juice Bug Report" menu action so
## developers can generate a self-contained JSON report after reproducing a bug.

@tool
extends EditorPlugin


# =============================================================================
# INTERNAL STATE
# =============================================================================

# PropertyPickerPlugin intercepts PropertyTarget resources in the inspector.
var _picker_plugin: PropertyPickerPlugin = null

# Menu item label — stored as a constant so _enter_tree and _exit_tree agree.
const _BUG_REPORT_MENU_LABEL := "Export Juice Bug Report"


# =============================================================================
# LIFECYCLE
# =============================================================================

func _enter_tree() -> void:
	# Register custom addon project settings
	JuiceProjectSettings.register_settings()

	_picker_plugin = PropertyPickerPlugin.new()
	add_inspector_plugin(_picker_plugin)
	# The dialog is a Window — it must live in the editor scene tree to popup.
	_picker_plugin.add_dialog_to_editor(get_editor_interface().get_base_control())

	# Register the bug report export action under Project → Tools.
	# In Godot 4, add_tool_menu_item() places items in the Tools submenu
	# nested under the Project top-level menu.
	# This gives developers a one-click way to export a JSON report after
	# reproducing a bug, without needing to dig through user:// paths manually.
	add_tool_menu_item(_BUG_REPORT_MENU_LABEL, _on_export_bug_report)


func _exit_tree() -> void:
	if _picker_plugin != null:
		remove_inspector_plugin(_picker_plugin)
		_picker_plugin.cleanup()
		_picker_plugin = null

	remove_tool_menu_item(_BUG_REPORT_MENU_LABEL)


# =============================================================================
# BUG REPORT
# =============================================================================

# Handles the "Export Juice Bug Report" menu action.
# Passes the currently edited scene root so JuiceDebugReport can inventory
# JuiceBase nodes. Prints the output path so the developer can find the file
# even if OS.shell_open is not supported on their platform.
func _on_export_bug_report() -> void:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		push_warning("[Juice] Export Bug Report: No scene is currently open in the editor.")
		return

	var abs_path := JuiceDebugReport.export(scene_root)
	if abs_path.is_empty():
		push_error("[Juice] Bug report export failed. See above for details.")
	else:
		print("[Juice] Bug report exported to: %s" % abs_path)
