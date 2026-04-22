## juice_plugin.gd
## EditorPlugin entry point for the Juice V1 addon.
##
## Registers editor inspector plugins so custom PropertyTarget rows show
## the [Pick…] button instead of raw string fields.

@tool
extends EditorPlugin


# =============================================================================
# INTERNAL STATE
# =============================================================================

# PropertyPickerPlugin intercepts PropertyTarget resources in the inspector.
var _picker_plugin: PropertyPickerPlugin = null


# =============================================================================
# LIFECYCLE
# =============================================================================

func _enter_tree() -> void:
	_picker_plugin = PropertyPickerPlugin.new()
	add_inspector_plugin(_picker_plugin)
	# The dialog is a Window — it must live in the editor scene tree to popup.
	_picker_plugin.add_dialog_to_editor(get_editor_interface().get_base_control())


func _exit_tree() -> void:
	if _picker_plugin != null:
		remove_inspector_plugin(_picker_plugin)
		_picker_plugin.cleanup()
		_picker_plugin = null
