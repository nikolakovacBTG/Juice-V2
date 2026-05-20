## EditorPlugin entry point for the Juice V1 addon.
##
## Registers editor inspector plugins, provides transport controls for
## in-editor animation previewing, and offers the bug report export action.

# ============================================================================
# WHAT: Master EditorPlugin for Juice V1.
# WHY:  Single entry point for all Juice editor features. Provides:
#       1. Transport controls (play/pause/stop/scrub) for editor preview
#       2. Bug report export via Project → Tools menu
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Implement effects (JuiceEffectBase subclasses), manage animation
#           state (JuicePreviewDirector), or handle undo/redo.
# ============================================================================

@tool
extends EditorPlugin

const DockScene := preload("res://addons/Juice_V1/Editor/JuiceTransportDock.tscn")
const InspectorPluginScript := preload("res://addons/Juice_V2/Editor/JuiceEditorInspectorPlugin.gd")
const PropertyPickerPluginScript := preload("res://addons/Juice_V2/Editor/PropertyPickerPlugin.gd")
const ArrayInspectorPluginScript := preload("res://addons/Juice_V2/Editor/JuiceArrayInspectorPlugin.gd")

# =============================================================================
# INTERNAL STATE
# =============================================================================

# Menu item label — stored as a constant so _enter_tree and _exit_tree agree.
const _BUG_REPORT_MENU_LABEL := "Export Juice Bug Report"

# --- Transport UI ---

## Root overlay (layout_mode=3 full-rect, loaded from .tscn to survive VBoxContainer).
var _dock: Control

## The preview director that manages animation state.
var _director: JuicePreviewDirector

# Inspector plugin instance — controls JuiceBase property visibility in editor.
var _inspector_plugin: EditorInspectorPlugin
# Property picker plugin — adds "Pick Property" button to PropertyTarget panels.
var _property_picker_plugin: EditorInspectorPlugin
# Array inspector plugin — replaces native array editors on Juice resources.
var _array_inspector_plugin: EditorInspectorPlugin

# --- Buttons ---
var _play_button: Button
var _play_in_button: Button
var _play_out_button: Button
var _pause_button: Button
var _stop_button: Button
var _loop_button: Button
var _siblings_button: Button

# --- Scrub ---
var _scrub_slider: HSlider
var _time_label: Label
var _title_label: Label

# --- Progress-effect notice ---
# Shown when the recipe contains SET_FROM_SOURCE effects, which have no finite
# duration and continue animating beyond the scrub bar range.
var _progress_warning_label: Label


# =============================================================================
# LIFECYCLE
# =============================================================================

func _enter_tree() -> void:
	# Register custom addon project settings
	JuiceProjectSettings.register_settings()

	# Register the bug report export action under Project → Tools.
	add_tool_menu_item(_BUG_REPORT_MENU_LABEL, _on_export_bug_report)

	# Register inspector plugin — controls property visibility for all JuiceBase nodes.
	# Must be registered before the editor opens any scene containing JuiceBase nodes.
	_inspector_plugin = InspectorPluginScript.new()
	add_inspector_plugin(_inspector_plugin)

	# Register property picker so PropertyTarget sub-inspectors show a Pick… editor property.
	# The picker uses a singleton dialog (created once in _init, reused per-open).
	# add_dialog_to_editor() parents the dialog to the editor base control so popups are modal.
	_property_picker_plugin = PropertyPickerPluginScript.new()
	add_inspector_plugin(_property_picker_plugin)
	_property_picker_plugin.add_dialog_to_editor(EditorInterface.get_base_control())

	# Register array inspector plugin — replaces native array editors on Juice objects
	# with JuiceArrayEditor for consistent row UX (type-coded strips, ⋮ menu, drag reorder).
	_array_inspector_plugin = ArrayInspectorPluginScript.new()
	add_inspector_plugin(_array_inspector_plugin)

	# Build transport UI and director
	_build_ui()
	_setup_director()
	_connect_signals()
	_dock.visible = false

	# Listen for selection changes in the editor
	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)
	# Also hide transport when the edited scene changes (prevents ghost visibility
	# between scene tabs).
	scene_changed.connect(_on_scene_changed)
	scene_closed.connect(_on_scene_closed)
	# Defer the initial check — calling _on_selection_changed synchronously here
	# fires before the editor selection system is settled, which causes the dock
	# to appear even when no Juice node is selected. Deferring lets the editor
	# finish its own initialization pass before we query selection state.
	call_deferred("_on_selection_changed")


## Called by Godot BEFORE saving the project (Ctrl+S, tab switch, etc.).
## Temporarily snaps all previewed nodes to natural state so the .tscn gets
## clean values. Then re-applies the current preview progress via call_deferred
## so the animation keeps running without interruption.
func _apply_changes() -> void:
	if _director and _director._preview_nodes.size() > 0:
		_director.temporarily_restore_natural()
		call_deferred("_deferred_restore_preview")


## Re-applies the current animation progress after the save pipeline completes.
## Called via call_deferred from _apply_changes() so the .tscn is already on disk.
func _deferred_restore_preview() -> void:
	if _director:
		_director.restore_preview_visual()


func _exit_tree() -> void:
	remove_tool_menu_item(_BUG_REPORT_MENU_LABEL)

	# Unregister inspector plugin so Godot cleans up the plugin instance.
	if _inspector_plugin:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null
	if _property_picker_plugin:
		# cleanup() removes the singleton dialog from the editor tree before deregistration.
		_property_picker_plugin.cleanup()
		remove_inspector_plugin(_property_picker_plugin)
		_property_picker_plugin = null
	if _array_inspector_plugin:
		remove_inspector_plugin(_array_inspector_plugin)
		_array_inspector_plugin = null

	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if scene_closed.is_connected(_on_scene_closed):
		scene_closed.disconnect(_on_scene_closed)

	if _dock:
		_dock.queue_free()
		_dock = null
	if _director:
		_director.deselect()
		_director.queue_free()
		_director = null


# =============================================================================
# UI CONSTRUCTION
# =============================================================================

## Builds the transport bar UI programmatically.
## Uses editor theme icons for a native look. Copied from V0 with V1 adaptations.
func _build_ui() -> void:
	# Instantiate the dock scene (layout_mode=3, FULL_RECT).
	# This overlay fills the editor main screen area without being managed
	# by the VBoxContainer parent.
	var main_screen := get_editor_interface().get_editor_main_screen()
	_dock = DockScene.instantiate()
	main_screen.add_child(_dock)

	# Content wrapper — PanelContainer with semi-transparent black StyleBox.
	# Anchored bottom-right of the viewport overlay.
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -260.0
	panel.offset_top = -105.0
	panel.offset_right = -16.0
	panel.offset_bottom = -16.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	_dock.add_child(panel)

	# Vertical layout inside the panel
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)

	# Title label
	_title_label = Label.new()
	_title_label.text = "Juice Preview"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 11)
	_title_label.clip_text = true
	content.add_child(_title_label)

	# Button row — Play, Pause, Stop | Quick IN, Quick OUT | Loop, Siblings
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 2)
	button_row.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(button_row)

	_play_button = _create_icon_button(main_screen, "Play", "Play (as configured)")
	button_row.add_child(_play_button)

	_pause_button = _create_icon_button(main_screen, "Pause", "Pause")
	_pause_button.toggle_mode = true
	button_row.add_child(_pause_button)

	_stop_button = _create_icon_button(main_screen, "Stop", "Stop")
	button_row.add_child(_stop_button)

	var sep1 := VSeparator.new()
	button_row.add_child(sep1)

	_play_in_button = _create_icon_button(main_screen, "PlayStart", "Quick Play IN")
	button_row.add_child(_play_in_button)

	_play_out_button = _create_icon_button(main_screen, "PlayStartBackwards", "Quick Play OUT")
	button_row.add_child(_play_out_button)

	var sep2 := VSeparator.new()
	button_row.add_child(sep2)

	_loop_button = _create_icon_button(main_screen, "Loop", "Loop")
	_loop_button.toggle_mode = true
	button_row.add_child(_loop_button)

	_siblings_button = _create_icon_button(main_screen, "AnimationTrackList", "Affect Siblings")
	_siblings_button.toggle_mode = true
	button_row.add_child(_siblings_button)

	# Scrub slider — full width for easier grabbing
	_scrub_slider = HSlider.new()
	_scrub_slider.min_value = 0.0
	_scrub_slider.max_value = 1.0
	_scrub_slider.step = 0.0
	_scrub_slider.editable = true
	_scrub_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Use KeyValue icon scaled 1.5x for a bigger, easier-to-grab handle
	var base_icon: Texture2D = main_screen.get_theme_icon("KeyValue", "EditorIcons")
	if base_icon:
		var img := base_icon.get_image()
		var new_size := Vector2i(int(img.get_width() * 1.5), int(img.get_height() * 1.5))
		img.resize(new_size.x, new_size.y, Image.INTERPOLATE_LANCZOS)
		var grabber_icon := ImageTexture.create_from_image(img)
		_scrub_slider.add_theme_icon_override("grabber", grabber_icon)
		_scrub_slider.add_theme_icon_override("grabber_disabled", grabber_icon)
		_scrub_slider.add_theme_icon_override("grabber_highlight", grabber_icon)
	content.add_child(_scrub_slider)

	# Time counter below the slider
	_time_label = Label.new()
	_time_label.text = "0.00s / 0.00s"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 11)
	content.add_child(_time_label)

	# Sustained-effect notice — amber, compact, hidden by default.
	# Appears when the recipe contains any sustained effect (_needs_sustain() = true)
	# — Progress, Noise, Shake, Camera effects — to warn the designer that the
	# scrubber range does not fully represent the animation.
	_progress_warning_label = Label.new()
	_progress_warning_label.text = char(0x26A0) + " Sustained effect detected in recipe, scrub range shows unsustained effects only"
	_progress_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_warning_label.add_theme_font_size_override("font_size", 10)
	_progress_warning_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.1))
	_progress_warning_label.tooltip_text = "One or more effects in this recipe are sustained (Progress, Noise, Shake, Camera).\nSustained effects run indefinitely after animate_in — they have no fixed end time.\nThe scrub bar only covers the time-bounded portion of the animation."
	_progress_warning_label.visible = false
	_progress_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(_progress_warning_label)


## Helper to create a button with an editor theme icon.
func _create_icon_button(theme_source: Control, icon_name: String, tooltip: String) -> Button:
	var btn := Button.new()
	btn.icon = theme_source.get_theme_icon(icon_name, "EditorIcons")
	btn.tooltip_text = tooltip
	btn.flat = true
	return btn


# =============================================================================
# DIRECTOR SETUP
# =============================================================================

func _setup_director() -> void:
	_director = JuicePreviewDirector.new()
	_director.name = "JuicePreviewDirector"
	add_child(_director)


func _connect_signals() -> void:
	# Button signals
	_play_button.pressed.connect(_on_play_pressed)
	_play_in_button.pressed.connect(_on_play_in_pressed)
	_play_out_button.pressed.connect(_on_play_out_pressed)
	_pause_button.pressed.connect(_on_pause_pressed)
	_stop_button.pressed.connect(_on_stop_pressed)
	_loop_button.toggled.connect(_on_loop_toggled)
	_siblings_button.toggled.connect(_on_siblings_toggled)

	# Scrub slider
	_scrub_slider.value_changed.connect(_on_scrub_value_changed)

	# Director signals
	_director.time_updated.connect(_on_time_updated)
	_director.state_changed.connect(_on_state_changed)


# =============================================================================
# SELECTION HANDLING
# =============================================================================

## Handles editor selection changes. Activates transport ONLY when a JuiceBase is
## directly selected. Smart target discovery (showing transport when a target node
## is selected) has been intentionally removed — a target may have multiple Juice
## nodes with different triggers, making simultaneous playback ambiguous.
func _on_selection_changed() -> void:
	if not _director or not _dock:
		return
	var was_playing: bool = _director.is_playing

	var selection: Array[Node] = get_editor_interface().get_selection().get_selected_nodes()

	var juice_node: JuiceBase = null

	# Only activate for single direct JuiceBase selection.
	# Multi-selection and non-Juice selection always hide the transport.
	if selection.size() == 1 and selection[0] is JuiceBase:
		juice_node = selection[0] as JuiceBase

	# Explicitly hide for every non-matching case (empty selection, multi-selection,
	# non-Juice node). This ensures the dock is never left visible from a prior selection.
	if juice_node and juice_node._supports_editor_preview() and juice_node.get_parent() != null:
		_director.select(juice_node)
		_update_title(juice_node)
		_update_out_button_visibility(juice_node)
		if was_playing:
			_director.play()
		_dock.visible = true
	else:
		_director.deselect()
		_dock.visible = false



# Called when the edited scene root changes (tab switch, scene open, etc.).
# Hides the transport to prevent it lingering from the previous scene's selection.
func _on_scene_changed(_scene_root: Node) -> void:
	if _director:
		_director.deselect()
	if _dock:
		_dock.visible = false


# Called when a scene is closed. Same rationale as _on_scene_changed.
func _on_scene_closed(_filepath: String) -> void:
	if _director:
		_director.deselect()
	if _dock:
		_dock.visible = false


# =============================================================================
# BUTTON HANDLERS
# =============================================================================

func _on_play_pressed() -> void:
	_director.play()


func _on_play_in_pressed() -> void:
	_director.play_in()


func _on_play_out_pressed() -> void:
	_director.play_out()


func _on_pause_pressed() -> void:
	if _director.is_paused:
		_director.unpause()
	else:
		_director.pause()


func _on_stop_pressed() -> void:
	_director.stop()


func _on_loop_toggled(pressed: bool) -> void:
	_director.set_loop_enabled(pressed)


func _on_siblings_toggled(pressed: bool) -> void:
	_director.set_affect_siblings(pressed)


func _on_scrub_value_changed(value: float) -> void:
	# Auto-pause if the user grabs the slider during playback
	if _director.is_playing and not _director.is_paused:
		_director.pause()
	_director.scrub_to_time(value)


# =============================================================================
# DIRECTOR SIGNAL HANDLERS
# =============================================================================

func _on_time_updated(elapsed: float, max_duration: float) -> void:
	if _director.is_scrubbable:
		_scrub_slider.max_value = maxf(max_duration, 0.01)
		_scrub_slider.set_value_no_signal(elapsed)
		_time_label.text = "%.2fs / %.2fs" % [elapsed, max_duration]
	else:
		_time_label.text = "%.2fs elapsed" % elapsed


func _on_state_changed() -> void:
	var can_play: bool = _director.can_play()
	_play_button.disabled = not can_play
	_play_in_button.disabled = not can_play
	_play_out_button.disabled = not can_play
	_pause_button.disabled = not can_play
	_stop_button.disabled = not can_play

	# Pause button visual state
	_pause_button.button_pressed = _director.is_paused

	# Scrub slider visibility — always visible unless SEQUENCER RANDOM
	var scrubbable: bool = _director.is_scrubbable
	_scrub_slider.visible = scrubbable
	if scrubbable:
		_scrub_slider.max_value = maxf(_director.get_max_duration(), 0.01)
		_scrub_slider.set_value_no_signal(_director.get_elapsed_time())
		_time_label.text = "%.2fs / %.2fs" % [_director.get_elapsed_time(), _director.get_max_duration()]
	else:
		_time_label.text = "%.2fs elapsed" % _director.get_elapsed_time()

	_loop_button.button_pressed = _director.loop_enabled

	# Sustained-effect notice: visible when recipe has any _needs_sustain() effects
	if _progress_warning_label:
		_progress_warning_label.visible = _director.has_sustained_effects()


# =============================================================================
# UI HELPERS
# =============================================================================

## Update the title label with the selected node's name.
func _update_title(node: JuiceBase) -> void:
	_title_label.text = "Juice: %s" % str(node.name)


## Hide the OUT button if the recipe has no OUT-capable effects.
func _update_out_button_visibility(node: JuiceBase) -> void:
	var has_out := false
	if node.recipe != null:
		for effect in node.recipe.effects:
			if effect != null:
				if effect.trigger_behaviour == JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT \
					or effect.trigger_behaviour == JuiceEffectBase.TriggerBehaviour.PLAY_OUT_ONLY:
					has_out = true
					break
	_play_out_button.visible = has_out


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
