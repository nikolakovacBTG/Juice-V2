## Manages the lifecycle and state of in-editor animation previews for Juice nodes.
##
## The transport director is the brain behind the editor preview controls.
## It owns the list of preview nodes, drives play/pause/stop/scrub/loop, and
## coordinates with the save pipeline to prevent preview state from leaking
## into scene files.

# ============================================================================
# WHAT: Editor-only preview director for Juice V1 transport controls.
# WHY:  Decouples preview orchestration from the plugin UI. The plugin owns
#       buttons and layout; this script owns playback state and node lifecycle.
#       This separation keeps the plugin script clean and testable.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Build UI (that's juice_plugin.gd). Does not manage runtime
#           animation — only editor preview. Does not resolve chains
#           (V1 chaining is effect-internal, handled by JuiceBase/JuiceRecipe).
# ============================================================================

@tool
class_name JuicePreviewDirector
extends Node


# =============================================================================
# SIGNALS
# =============================================================================

## Emitted each frame during playback with current elapsed time and max duration.
## Used by the plugin to update the scrub slider position and time label.
signal time_updated(elapsed: float, max_duration: float)

## Emitted when playback state changes (play, pause, stop, select, deselect).
## Used by the plugin to enable/disable buttons and update UI state.
signal state_changed()


# =============================================================================
# CONFIGURATION
# =============================================================================

## Debug flag — prints lifecycle events via JuiceLogger.
var debug_enabled: bool = true


# =============================================================================
# INTERNAL STATE
# =============================================================================

# The user-selected JuiceBase node (the one the user clicked in the scene tree).
var _primary_node: JuiceBase = null

# All nodes being previewed: primary + optional siblings.
# These are the nodes that receive play/stop/scrub commands.
var _preview_nodes: Array = []

# Orchestrators managing each preview node's animation lifecycle.
# Keys: JuiceBase node. Values: JuiceOrchestrator (PREVIEW mode).
# Populated in _add_preview_node, torn down in deselect().
var _orchestrators: Dictionary = {}

## Whether the transport is currently playing.
var is_playing: bool = false

## Whether playback is paused.
var is_paused: bool = false

## Whether the loop toggle is enabled.
var loop_enabled: bool = false

## Whether sibling JuiceBase nodes are included in the preview.
var affect_siblings: bool = false

## Whether the current preview is scrubbable (false for SEQUENCER RANDOM).
var is_scrubbable: bool = true

## Wall-clock time elapsed since play started (seconds).
var _elapsed_time: float = 0.0

## Longest total duration across all preview nodes (for scrub range).
var _max_duration: float = 0.0

# Effect count snapshot — detects inspector changes during active preview (stale-recipe guard).
var _recipe_effects_count: int = 0

# Transient Camera/Screen utilities placed by play() — owner=null, not serialized, freed on stop.
var _preview_camera_util: CameraJuiceUtility = null   # placed on active Camera2D or Camera3D
var _preview_screen_canvas: CanvasLayer = null        # CanvasLayer wrapping ScreenJuiceUtility



# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not is_playing or is_paused:
		return
	# Stale-recipe guard: if the user removes or adds an effect in the inspector
	# while the transport is active, the recipe.effects array changes but no signal
	# fires to the director. We catch this by comparing the stored effect count.
	# On mismatch, emit state_changed so the plugin can refresh the UI.
	if _primary_node != null and is_instance_valid(_primary_node) \
			and _primary_node.recipe != null:
		var current_count := _primary_node.recipe.effects.size()
		if current_count != _recipe_effects_count:
			_recipe_effects_count = current_count
			_recalculate_max_duration()
			# Invalidate runtime effects by re-entering preview on the primary node
			# so the effect stack is fresh and matches the inspector.
			_primary_node._exit_editor_preview()
			_primary_node._enter_editor_preview()
			JuiceLogger.log_info(self, "Transport",
					"Recipe changed during preview (effect count: %d). Refreshed." % current_count,
					debug_enabled)
			state_changed.emit()
			return
	# Recalculate max duration each frame so live inspector edits to
	# duration_in/duration_out are reflected immediately in the scrubber.
	_recalculate_max_duration()
	_elapsed_time += delta
	# Only wrap elapsed time when loop is enabled. Without this check the scrubber
	# would always loop visually even when loop_enabled is false.
	if loop_enabled and _max_duration > 0.0 and _elapsed_time >= _max_duration:
		_elapsed_time = fmod(_elapsed_time, _max_duration)
	time_updated.emit(_elapsed_time, _max_duration)


# =============================================================================
# SELECTION
# =============================================================================

## Called by the plugin when a JuiceBase is selected in the editor.
## Enters preview mode for the node (and siblings if affect_siblings is on).
func select(node: JuiceBase) -> void:
	deselect()
	_primary_node = node
	_add_preview_node(node)
	if affect_siblings:
		_add_sibling_nodes(node)
	_recalculate_max_duration()
	# Snapshot effect count for stale-recipe detection in _process
	_recipe_effects_count = node.recipe.effects.size() if node.recipe != null else 0
	# Determine scrubbability: always true unless SEQUENCER RANDOM
	is_scrubbable = _check_scrubbable(node)
	JuiceLogger.log_info(self, "Transport",
			"Selected: %s | preview_count=%d | max_dur=%.2fs | scrubbable=%s" % [
			node.name, _preview_nodes.size(), _max_duration, is_scrubbable],
			debug_enabled)
	state_changed.emit()


## Called by the plugin when selection changes away from a juice node.
## Stops all previews, tears down orchestrators, and restores targets to natural state.
func deselect() -> void:
	if _primary_node != null:
		JuiceLogger.log_info(self, "Transport",
				"Deselecting: %s" % _primary_node.name, debug_enabled)
	_stop_internal()
	for node in _preview_nodes:
		if is_instance_valid(node):
			_disconnect_node_signals(node)
			node._exit_editor_preview()
		var orch: JuiceOrchestrator = _orchestrators.get(node)
		if orch and is_instance_valid(orch):
			orch.teardown()
	_preview_nodes.clear()
	_orchestrators.clear()
	_primary_node = null
	state_changed.emit()


# =============================================================================
# TRANSPORT CONTROLS
# =============================================================================

## Main Play button — full fidelity preview.
## Routes through the orchestrator which delegates to _handle_trigger().
func play() -> void:
	_stop_internal()
	_recalculate_max_duration()
	is_playing = true
	is_paused = false
	_elapsed_time = 0.0
	set_process(true)
	for node in _preview_nodes:
		if is_instance_valid(node):
			var orch: JuiceOrchestrator = _orchestrators.get(node)
			if orch:
				orch.play()
	_bootstrap_preview_utilities()
	JuiceLogger.log_info(self, "Transport",
			"Play started | loop=%s | siblings=%s | preview_count=%d | max_dur=%.2fs" % [
			"ON" if loop_enabled else "OFF",
			"ON" if affect_siblings else "OFF",
			_preview_nodes.size(), _max_duration],
			debug_enabled)
	state_changed.emit()


## Quick IN preview — bypasses trigger pipeline (no start_delay, no trigger_behaviour).
func play_in() -> void:
	_stop_internal()
	_recalculate_max_duration()
	is_playing = true
	is_paused = false
	_elapsed_time = 0.0
	set_process(true)
	for node in _preview_nodes:
		if is_instance_valid(node):
			var orch: JuiceOrchestrator = _orchestrators.get(node)
			if orch:
				orch.play_in()
	_bootstrap_preview_utilities()
	JuiceLogger.log_info(self, "Transport",
			"Play IN started | preview_count=%d" % _preview_nodes.size(),
			debug_enabled)
	state_changed.emit()


## Quick OUT preview — bypasses trigger pipeline (no start_delay, no trigger_behaviour).
func play_out() -> void:
	_stop_internal()
	_recalculate_max_duration()
	is_playing = true
	is_paused = false
	_elapsed_time = 0.0
	set_process(true)
	for node in _preview_nodes:
		if is_instance_valid(node):
			var orch: JuiceOrchestrator = _orchestrators.get(node)
			if orch:
				orch.play_out()
	_bootstrap_preview_utilities()
	JuiceLogger.log_info(self, "Transport",
			"Play OUT started | preview_count=%d" % _preview_nodes.size(),
			debug_enabled)
	state_changed.emit()


## Freeze all preview nodes at their current progress.
func pause() -> void:
	if not is_playing:
		return
	is_paused = true
	for node in _preview_nodes:
		if is_instance_valid(node):
			node.set_process(false)
	set_process(false)
	JuiceLogger.log_info(self, "Transport", "Paused", debug_enabled)
	state_changed.emit()


## Resume from paused state.
func unpause() -> void:
	if not is_paused:
		return
	is_paused = false
	for node in _preview_nodes:
		if is_instance_valid(node) and node.is_playing():
			node.set_process(true)
	set_process(true)
	JuiceLogger.log_info(self, "Transport", "Unpaused", debug_enabled)
	state_changed.emit()


## Stop all preview nodes and reset to natural state.
func stop() -> void:
	_stop_internal()
	JuiceLogger.log_info(self, "Transport", "Stopped", debug_enabled)
	state_changed.emit()


## Scrub all preview nodes to a specific wall-clock time.
## Each node maps the time to per-effect progress internally using
## get_progress_at_time(), which accounts for start_delay, hold, and easing.
## Only meaningful when paused or stopped.
func scrub_to_time(time: float) -> void:
	_elapsed_time = clampf(time, 0.0, _max_duration)
	for node in _preview_nodes:
		if is_instance_valid(node):
			node.scrub_to_time(_elapsed_time)
	JuiceLogger.log_info(self, "Transport",
			"Scrubbed to %.2fs / %.2fs" % [_elapsed_time, _max_duration], debug_enabled)
	time_updated.emit(_elapsed_time, _max_duration)


# =============================================================================
# CONFIGURATION
# =============================================================================

## Toggle looping. Updates all preview nodes' loop_count so the node handles
## looping internally. -1 = infinite, 1 = one cycle.
func set_loop_enabled(enabled: bool) -> void:
	loop_enabled = enabled
	var target_loop_count := -1 if enabled else 1
	for node in _preview_nodes:
		if is_instance_valid(node):
			node.loop_count = target_loop_count
	JuiceLogger.log_info(self, "Transport",
			"Loop %s | loop_count=%d on %d nodes" % [
			"ON" if enabled else "OFF", target_loop_count, _preview_nodes.size()],
			debug_enabled)


## Toggle sibling inclusion. Re-selects the primary node to rebuild the list.
func set_affect_siblings(enabled: bool) -> void:
	affect_siblings = enabled
	JuiceLogger.log_info(self, "Transport",
			"Affect siblings: %s" % ("ON" if enabled else "OFF"), debug_enabled)
	if _primary_node and is_instance_valid(_primary_node):
		var was_playing := is_playing and not is_paused
		select(_primary_node)
		if was_playing:
			play()


# =============================================================================
# QUERIES (used by plugin for UI state)
# =============================================================================

## Returns true if any recipe effect runs indefinitely (_needs_sustain() = true).
## When true, the scrub bar range is incomplete — the plugin shows a warning label.
func has_sustained_effects() -> bool:
	if _primary_node == null or _primary_node.recipe == null:
		return false
	for effect in _primary_node.recipe.effects:
		if effect == null:
			continue
		if effect._needs_sustain():
			return true
	return false


## Whether there are any nodes ready to preview.
func can_play() -> bool:
	return _preview_nodes.size() > 0


## Current elapsed time in the preview.
func get_elapsed_time() -> float:
	return _elapsed_time


## Maximum preview duration across all preview nodes.
func get_max_duration() -> float:
	return _max_duration


## Returns the primary node (for reading trigger_behaviour, etc.)
func get_primary_node() -> JuiceBase:
	return _primary_node


# =============================================================================
# SAVE PIPELINE
# =============================================================================

## Temporarily undo each node's visual contribution on its target.
## Called by the plugin's _apply_changes() BEFORE Godot serializes the scene,
## so the saved .tscn contains clean values — not mid-animation positions.
func temporarily_restore_natural() -> void:
	for node in _preview_nodes:
		if is_instance_valid(node):
			node._temporarily_undo_visual()
	JuiceLogger.log_info(self, "Transport",
			"Temporarily restored natural state (for save)", debug_enabled)


## Re-apply each node's visual contribution after the save pipeline finishes.
## Called via call_deferred from the plugin so the .tscn is already on disk.
func restore_preview_visual() -> void:
	for node in _preview_nodes:
		if is_instance_valid(node):
			node._temporarily_reapply_visual()
	JuiceLogger.log_info(self, "Transport",
			"Restored preview visual (contribution re-applied)", debug_enabled)


# =============================================================================
# INTERNAL HELPERS
# =============================================================================

# Stops all nodes without emitting state_changed (used internally before play/select).
# Routes through orchestrators so the lifecycle contract is maintained.
func _stop_internal() -> void:
	var was_playing := is_playing
	is_playing = false
	is_paused = false
	_elapsed_time = 0.0
	set_process(false)
	for node in _preview_nodes:
		if is_instance_valid(node):
			var orch: JuiceOrchestrator = _orchestrators.get(node)
			if orch and is_instance_valid(orch):
				orch.stop()
			else:
				node.stop()  # fallback: no orchestrator for this node
	_cleanup_preview_utilities()
	if debug_enabled and was_playing:
		JuiceLogger.log_info(self, "Transport", "Stopped (internal)", debug_enabled)


# Bootstraps transient Camera/Screen utilities before the first effect tick (owner=null — not serialized).
func _bootstrap_preview_utilities() -> void:
	_cleanup_preview_utilities()  # idempotent

	# --- Camera: place utility on active cam so _find_or_create_utility() finds it in editor context.
	if _primary_node != null and is_instance_valid(_primary_node):
		var vp := _primary_node.get_viewport()
		if vp:
			# Try Camera2D first, then Camera3D
			var cam2d := vp.get_camera_2d()
			var cam3d := vp.get_camera_3d()
			var cam: Node = cam2d if is_instance_valid(cam2d) else cam3d
			if not is_instance_valid(cam):
				JuiceLogger.log_info(self, "Transport",
						"No active camera in viewport — camera effects will not preview",
						debug_enabled)
			elif is_instance_valid(cam):
				# Only add if no utility exists yet (might be in scene already)
				var has_util := false
				for child in cam.get_children():
					if child is CameraJuiceUtility:
						has_util = true
						break
				if not has_util:
					_preview_camera_util = CameraJuiceUtility.new()
					_preview_camera_util.name = "_JuicePreviewCameraUtil"
					cam.add_child(_preview_camera_util)  # owner intentionally null — not saved
					_preview_camera_util._initialize_camera()
					JuiceLogger.log_info(self, "Transport",
							"Preview camera util placed on '%s'" % cam.name, debug_enabled)

	# --- Screen: bootstrap in editor viewport (not SceneTree.root) so it doesn't overlay editor chrome.
	if not is_instance_valid(ScreenJuiceUtility.instance):
		var editor_vp := EditorInterface.get_editor_viewport_2d()
		if not is_instance_valid(editor_vp):
			JuiceLogger.log_info(self, "Transport",
					"Editor viewport unavailable — screen effects will not preview", debug_enabled)
		elif is_instance_valid(editor_vp):
			var canvas := CanvasLayer.new()
			canvas.name = "_JuicePreviewScreenCanvas"
			canvas.layer = 128
			canvas.follow_viewport_enabled = false
			editor_vp.add_child(canvas)  # owner intentionally null — not saved

			var util := ScreenJuiceUtility.new()
			util.name = "_JuicePreviewScreenUtil"
			util.anchor_right  = 1.0
			util.anchor_bottom = 1.0
			util.mouse_filter  = Control.MOUSE_FILTER_IGNORE
			var mat := ShaderMaterial.new()
			mat.shader = load("res://addons/Juice_V1/Screen/screen_juice.gdshader")
			util.material = mat
			canvas.add_child(util)  # owner intentionally null — not saved
			ScreenJuiceUtility.instance = util
			util._ready()

			_preview_screen_canvas = canvas
			JuiceLogger.log_info(self, "Transport",
					"Preview screen util bootstrapped in editor viewport", debug_enabled)


# Remove all transient preview utilities. Called from _stop_internal() and deselect().
func _cleanup_preview_utilities() -> void:
	if is_instance_valid(_preview_camera_util):
		_preview_camera_util.queue_free()
		_preview_camera_util = null
		JuiceLogger.log_info(self, "Transport", "Preview camera util removed", debug_enabled)

	if is_instance_valid(_preview_screen_canvas):
		if ScreenJuiceUtility.instance != null \
				and _preview_screen_canvas.is_ancestor_of(ScreenJuiceUtility.instance):
			ScreenJuiceUtility.instance = null
		_preview_screen_canvas.queue_free()
		_preview_screen_canvas = null
		JuiceLogger.log_info(self, "Transport", "Preview screen util removed", debug_enabled)


# Enter editor preview for a node, spawn its orchestrator, and add it to _preview_nodes.
func _add_preview_node(node: JuiceBase) -> void:
	if not node._supports_editor_preview():
		JuiceLogger.warn(self, "Transport",
				"Node '%s' skipped: _supports_editor_preview() = false" % node.name, debug_enabled)
		return
	if node.get_parent() == null:
		JuiceLogger.warn(self, "Transport",
				"Node '%s' skipped: has no parent in tree" % node.name, debug_enabled)
		return
	# Spawn PREVIEW orchestrator BEFORE calling _enter_editor_preview().
	# Order is critical: SEQUENCER mode calls _invalidate_runtime_effects() synchronously
	# inside _enter_editor_preview(). With _runtime_orchestrator set first, the computed
	# property routes array writes to the orch rather than silently discarding them.
	var orch := JuiceOrchestratorFactory.create(node, JuiceOrchestrator.Mode.PREVIEW)
	node._runtime_orchestrator = orch
	node.add_child(orch)
	node._enter_editor_preview()
	_orchestrators[node] = orch
	_preview_nodes.append(node)
	_connect_node_signals(node)


# Find and add all flat JuiceBase siblings of the given node.
# Uses type-safe discovery (is JuiceBase), never string matching.
func _add_sibling_nodes(node: JuiceBase) -> void:
	var parent := node.get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child == node:
			continue
		if child is JuiceBase and not _preview_nodes.has(child):
			_add_preview_node(child)


# Connect completed and tree_exiting signals for a preview node.
func _connect_node_signals(node: JuiceBase) -> void:
	if not node.completed.is_connected(_on_node_completed):
		node.completed.connect(_on_node_completed)
	if not node.tree_exiting.is_connected(_on_node_tree_exiting.bind(node)):
		node.tree_exiting.connect(_on_node_tree_exiting.bind(node))


# Disconnect signals from a preview node.
func _disconnect_node_signals(node: JuiceBase) -> void:
	if node.completed.is_connected(_on_node_completed):
		node.completed.disconnect(_on_node_completed)
	if node.tree_exiting.is_connected(_on_node_tree_exiting.bind(node)):
		node.tree_exiting.disconnect(_on_node_tree_exiting.bind(node))


# Signal callback: fired when any preview node emits `completed`.
# Defers the "is everyone done?" check to the end of the frame so that
# chained effects have time to start before we declare "all done".
func _on_node_completed() -> void:
	call_deferred("_check_playback_complete")


# Deferred check: if no node in the list is still playing, stop playback.
func _check_playback_complete() -> void:
	if not is_playing:
		return
	for node in _preview_nodes:
		if is_instance_valid(node) and node.is_playing():
			return
	# Nobody playing — all done.
	JuiceLogger.log_info(self, "Transport",
			"All nodes finished | elapsed=%.2fs" % _elapsed_time, debug_enabled)
	is_playing = false
	set_process(false)
	state_changed.emit()


# Safeguard callback: if a node is about to leave the tree (project reload,
# scene close, etc.), force it back to natural state so the paused position
# doesn't get baked into the scene file.
func _on_node_tree_exiting(node: JuiceBase) -> void:
	JuiceLogger.warn(self, "Transport",
			"Node tree_exiting safeguard: %s" % node.name, debug_enabled)
	if is_instance_valid(node):
		node.stop()


# Recalculate the longest total duration across preview nodes.
# Used to set the scrub slider range.
func _recalculate_max_duration() -> void:
	_max_duration = 0.0
	for node in _preview_nodes:
		if is_instance_valid(node):
			_max_duration = maxf(_max_duration, node.get_total_preview_duration())


# Check if the current selection is scrubbable.
# Always true in STACK mode. False for SEQUENCER with RANDOM ordering.
func _check_scrubbable(node: JuiceBase) -> bool:
	if node.mode == JuiceBase.Mode.SEQUENCER:
		# Check if any of the sequence types would make scrubbing unpredictable
		if node.sequence_type == JuiceBase.SequenceType.RANDOM:
			return false
	return true
