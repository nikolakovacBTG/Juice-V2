## JuicePreviewDirector.gd
## ============================================================================
## WHAT: Manages the preview lifecycle for Juice Transport Controls.
## WHY: Centralizes play/pause/stop/scrub logic so the master plugin only
##      handles UI wiring and selection, not animation state.
## SYSTEM: Juice System — Editor Tooling (addons/juice/Editor/)
## DOES NOT: Own UI elements, modify comp inspector settings, or handle undo/redo.
## ============================================================================
##
## CONNECTIONS:
## - JuiceCompBase: Calls _enter/_exit_editor_preview(), animate_in/out(),
##   stop(), set_progress(), _handle_trigger(), get_progress_at_time(),
##   get_total_preview_duration(). Connects to `completed` signal to detect
##   when the comp finishes all its loops. Looping is delegated to the comp's
##   own loop_count — the director sets it to -1 (infinite) or 1 (one cycle)
##   based on the transport Loop button.
## - JuicePlugin (juice_plugin.gd): Emits time_updated and state_changed signals
##   so the plugin can update the scrub slider and button states.
## ============================================================================

@tool
class_name JuicePreviewDirector
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted each frame during playback with current elapsed time and max duration.
## The plugin uses this to update the scrub slider position.
signal time_updated(elapsed: float, max_duration: float)

## Emitted when play state changes (play/pause/stop/select/deselect).
## The plugin uses this to update button enabled/disabled states.
signal state_changed()

# =============================================================================
# STATE
# =============================================================================

## Comps that are directly triggered by play() (primary + siblings).
var _preview_comps: Array[JuiceCompBase] = []

## Comps discovered via chain traversal — preview-initialized but NOT
## directly triggered by play(). They animate through the chain itself.
## Separate from _preview_comps to prevent double-triggering.
var _chain_comps: Array[JuiceCompBase] = []

## The comp that was directly selected by the user.
var _primary_comp: JuiceCompBase = null

## Whether preview is actively animating (comps are processing).
var is_playing: bool = false

## Whether preview is frozen mid-animation.
var is_paused: bool = false

## Whether the comp should loop infinitely. Controls comp.loop_count:
## true = -1 (infinite), false = 1 (one cycle then completed fires).
var loop_enabled: bool = false

## Whether sibling juice comps are included in the preview.
var affect_siblings: bool = false

## Whether the current preview is scrubbable.
## True only when a single comp is selected with no chain comps.
var is_scrubbable: bool = true

## Wall-clock time elapsed since play started (seconds).
var _elapsed_time: float = 0.0

## Longest total duration across all preview comps (for scrub range).
var _max_duration: float = 0.0

## Debug flag — prints lifecycle events to the Godot output log.
var debug_enabled: bool = true

# =============================================================================
# SELECTION
# =============================================================================

## Called by the plugin when a JuiceCompBase is selected in the editor.
## Enters preview mode for the comp (and siblings if affect_siblings is on).
func select(comp: JuiceCompBase) -> void:
	deselect()
	_primary_comp = comp
	_add_preview_comp(comp)
	if affect_siblings:
		_add_sibling_comps(comp)
	# Resolve entire chain for all trigger comps: follow next_component,
	# loop_target, and JuiceCompBase children recursively.
	for trigger_comp in _preview_comps.duplicate():
		_resolve_chain_comps(trigger_comp)
	_recalculate_max_duration()
	is_scrubbable = (_preview_comps.size() == 1 and _chain_comps.size() == 0)
	if debug_enabled:
		print("[Transport] Selected: %s | trigger=%d chain=%d | max_dur=%.2f | scrubbable=%s" % [
			comp.name, _preview_comps.size(), _chain_comps.size(), _max_duration, is_scrubbable])
	state_changed.emit()


## Called by the plugin when selection changes away from a juice comp.
## Stops all previews and restores targets to natural state.
func deselect() -> void:
	if debug_enabled and _primary_comp:
		print("[Transport] Deselecting: %s" % _primary_comp.name)
	_stop_internal()
	for comp in _preview_comps:
		if is_instance_valid(comp):
			_disconnect_comp_signals(comp)
			comp._exit_editor_preview()
	for comp in _chain_comps:
		if is_instance_valid(comp):
			_disconnect_comp_signals(comp)
			comp._exit_editor_preview()
	_preview_comps.clear()
	_chain_comps.clear()
	_primary_comp = null
	state_changed.emit()

# =============================================================================
# TRANSPORT CONTROLS
# =============================================================================

## Main Play button — full fidelity preview.
## Routes through _handle_trigger() so trigger_behaviour and start_delay are respected.
func play() -> void:
	_stop_internal()
	_recalculate_max_duration()
	is_playing = true
	is_paused = false
	_elapsed_time = 0.0
	set_process(true)
	# Only trigger preview comps directly — chain comps are triggered by the chain.
	for comp in _preview_comps:
		if is_instance_valid(comp):
			comp._handle_trigger({"kind": "momentary"})
	if debug_enabled:
		print("[Transport] Play started | trigger=%d chain=%d | max_dur=%.2f" % [
			_preview_comps.size(), _chain_comps.size(), _max_duration])
	state_changed.emit()


## Quick IN preview — bypasses trigger pipeline (no start_delay, no trigger_behaviour).
func play_in() -> void:
	_stop_internal()
	_recalculate_max_duration()
	is_playing = true
	is_paused = false
	_elapsed_time = 0.0
	set_process(true)
	for comp in _preview_comps:
		if is_instance_valid(comp):
			comp.animate_in()
	if debug_enabled:
		print("[Transport] Play IN started | trigger=%d" % _preview_comps.size())
	state_changed.emit()


## Quick OUT preview — bypasses trigger pipeline (no start_delay, no trigger_behaviour).
func play_out() -> void:
	_stop_internal()
	_recalculate_max_duration()
	is_playing = true
	is_paused = false
	_elapsed_time = 0.0
	set_process(true)
	for comp in _preview_comps:
		if is_instance_valid(comp):
			comp.animate_out()
	if debug_enabled:
		print("[Transport] Play OUT started | trigger=%d" % _preview_comps.size())
	state_changed.emit()


## Freeze all preview comps at their current progress.
func pause() -> void:
	if not is_playing:
		return
	is_paused = true
	for comp in _preview_comps:
		if is_instance_valid(comp):
			comp.set_process(false)
	for comp in _chain_comps:
		if is_instance_valid(comp):
			comp.set_process(false)
	set_process(false)
	state_changed.emit()


## Resume from paused state.
func unpause() -> void:
	if not is_paused:
		return
	is_paused = false
	for comp in _preview_comps:
		if is_instance_valid(comp) and comp.is_playing():
			comp.set_process(true)
	for comp in _chain_comps:
		if is_instance_valid(comp) and comp.is_playing():
			comp.set_process(true)
	set_process(true)
	state_changed.emit()


## Stop all preview comps and reset to natural state.
func stop() -> void:
	_stop_internal()
	state_changed.emit()


## Scrub all preview comps to a specific wall-clock time.
## Each comp maps the time to its own progress using get_progress_at_time(),
## which accounts for start_delay, duration_in/out, and easing.
## Only meaningful when paused.
func scrub_to_time(time: float) -> void:
	_elapsed_time = clampf(time, 0.0, _max_duration)
	for comp in _preview_comps:
		if is_instance_valid(comp):
			var progress := comp.get_progress_at_time(_elapsed_time)
			# set_progress() directly applies the effect. Base state was already
			# captured by _enter_editor_preview() → _on_animate_start().
			comp.set_progress(progress)
	time_updated.emit(_elapsed_time, _max_duration)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Toggle looping. Updates all preview comps' loop_count so the comp handles
## looping internally. -1 = infinite (comp loops forever), 1 = one cycle
## (comp emits `completed` when done → director stops playback).
func set_loop_enabled(enabled: bool) -> void:
	loop_enabled = enabled
	var target_loop_count := -1 if enabled else 1
	for comp in _preview_comps:
		if is_instance_valid(comp):
			comp.loop_count = target_loop_count
	if debug_enabled:
		print("[Transport] Loop %s | loop_count set to %d on %d comps" % [
			"ON" if enabled else "OFF", target_loop_count, _preview_comps.size()])


## Toggle sibling inclusion. Re-selects the primary comp to rebuild the list.
func set_affect_siblings(enabled: bool) -> void:
	affect_siblings = enabled
	if _primary_comp and is_instance_valid(_primary_comp):
		var was_playing := is_playing and not is_paused
		select(_primary_comp)
		if was_playing:
			play()

# =============================================================================
# QUERIES (used by plugin for UI state)
# =============================================================================

func can_play() -> bool:
	return _preview_comps.size() > 0


func get_elapsed_time() -> float:
	return _elapsed_time


func get_max_duration() -> float:
	return _max_duration


## Returns the primary comp (for reading trigger_behaviour, etc.)
func get_primary_comp() -> JuiceCompBase:
	return _primary_comp

# =============================================================================
# INTERNAL
# =============================================================================

func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not is_playing or is_paused:
		return
	# Recalculate max duration each frame so live inspector edits to
	# duration_in/duration_out are reflected immediately in the scrubber.
	_recalculate_max_duration()
	_elapsed_time += delta
	# Wrap elapsed time at cycle boundary so the scrubber visually loops.
	# The comp handles looping internally (loop_count = -1), so the scrubber
	# wraps independently based on wall-clock time.
	if _max_duration > 0.0 and _elapsed_time >= _max_duration:
		_elapsed_time = fmod(_elapsed_time, _max_duration)
	time_updated.emit(_elapsed_time, _max_duration)


## Stops all comps without emitting state_changed (used internally before play/select).
func _stop_internal() -> void:
	var was_playing := is_playing
	is_playing = false
	is_paused = false
	_elapsed_time = 0.0
	set_process(false)
	for comp in _preview_comps:
		if is_instance_valid(comp):
			comp.stop()
	for comp in _chain_comps:
		if is_instance_valid(comp):
			comp.stop()
	if debug_enabled and was_playing:
		print("[Transport] Stopped (internal)")


## Signal callback: fired when any comp (trigger or chain) emits `completed`.
## Defers the "is everyone done?" check to the end of the frame so that
## _trigger_next_component() has time to start the next comp in the chain.
## Without the defer, we'd see "nobody playing" in the gap between one comp
## completing and the next comp starting.
func _on_comp_completed() -> void:
	if debug_enabled:
		print("[Transport] Comp completed — deferring playback check")
	call_deferred("_check_playback_complete")


## Deferred check: if no comp in either list is still playing, stop playback.
## Runs at end-of-frame, after _trigger_next_component() has had a chance to
## start the next comp in the chain (setting _is_playing = true synchronously).
func _check_playback_complete() -> void:
	if not is_playing:
		return
	for comp in _preview_comps:
		if is_instance_valid(comp) and comp.is_playing():
			return
	for comp in _chain_comps:
		if is_instance_valid(comp) and comp.is_playing():
			return
	# Nobody playing — all done.
	if debug_enabled:
		print("[Transport] All comps finished | elapsed=%.2f" % _elapsed_time)
	is_playing = false
	set_process(false)
	state_changed.emit()


## Enter editor preview for a trigger comp and add it to _preview_comps.
## These comps are directly triggered by play() and tracked for completion.
## Connects `completed` signal for the deferred "all done?" check and
## `tree_exiting` for safeguard restoration on project reload/scene close.
func _add_preview_comp(comp: JuiceCompBase) -> void:
	if not comp._supports_editor_preview():
		return
	if comp.get_parent() == null:
		return
	comp._enter_editor_preview()
	_preview_comps.append(comp)
	_connect_comp_signals(comp)


## Enter editor preview for a chain-discovered comp and add it to _chain_comps.
## These comps are NOT directly triggered — the chain triggers them.
## Still connected to completed (for deferred "all done?" check) and
## tree_exiting (for safeguard restoration).
func _add_chain_comp(comp: JuiceCompBase) -> void:
	if not comp._supports_editor_preview():
		return
	if comp.get_parent() == null:
		return
	comp._enter_editor_preview()
	_chain_comps.append(comp)
	_connect_comp_signals(comp)


## Connect completed and tree_exiting signals for any comp (trigger or chain).
func _connect_comp_signals(comp: JuiceCompBase) -> void:
	if not comp.completed.is_connected(_on_comp_completed):
		comp.completed.connect(_on_comp_completed)
	if not comp.tree_exiting.is_connected(_on_comp_tree_exiting.bind(comp)):
		comp.tree_exiting.connect(_on_comp_tree_exiting.bind(comp))


## Find and add all JuiceCompBase siblings of the given comp.
## Uses type-safe discovery (is JuiceCompBase), never string matching.
func _add_sibling_comps(comp: JuiceCompBase) -> void:
	var parent := comp.get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child == comp:
			continue
		if child is JuiceCompBase and not _preview_comps.has(child):
			_add_preview_comp(child)


## Disconnect completed and tree_exiting signals from a comp.
func _disconnect_comp_signals(comp: JuiceCompBase) -> void:
	if comp.completed.is_connected(_on_comp_completed):
		comp.completed.disconnect(_on_comp_completed)
	if comp.tree_exiting.is_connected(_on_comp_tree_exiting.bind(comp)):
		comp.tree_exiting.disconnect(_on_comp_tree_exiting.bind(comp))


## Safeguard callback: if a comp is about to leave the tree (project reload,
## scene close, etc.), force it back to natural state so the paused position
## doesn't get baked into the scene file.
func _on_comp_tree_exiting(comp: JuiceCompBase) -> void:
	if debug_enabled:
		print("[Transport] Comp tree_exiting safeguard: %s" % comp.name)
	if is_instance_valid(comp):
		comp.stop()
		comp._invalidate_base_cache()


## Temporarily snap all previewed comps to their natural state (progress 0.0).
## Called by the plugin's _apply_changes() BEFORE Godot serializes the scene,
## so the saved .tscn contains clean values — not mid-animation positions.
## Does NOT stop the animation — is_playing, set_process, and signals stay intact.
func temporarily_restore_natural() -> void:
	for comp in _preview_comps:
		if is_instance_valid(comp):
			comp._apply_effect(0.0)
	for comp in _chain_comps:
		if is_instance_valid(comp):
			comp._apply_effect(0.0)
	if debug_enabled:
		print("[Transport] Temporarily restored natural state (for save)")


## Re-apply each comp's current animation progress after the save pipeline finishes.
## Called via call_deferred from the plugin so the .tscn is already written to disk.
func restore_preview_visual() -> void:
	for comp in _preview_comps:
		if is_instance_valid(comp):
			comp._apply_effect(comp._animation_progress)
	for comp in _chain_comps:
		if is_instance_valid(comp):
			comp._apply_effect(comp._animation_progress)
	if debug_enabled:
		print("[Transport] Restored preview visual (progress re-applied)")


## Recursively discover all comps reachable from the given comp via
## next_component, loop_target, and JuiceCompBase children.
## Each discovered comp gets _enter_editor_preview() via _add_chain_comp().
## Checks both lists to prevent duplicates and infinite recursion on circular chains.
func _resolve_chain_comps(comp: JuiceCompBase) -> void:
	# Follow next_component chain
	if not comp.next_component.is_empty():
		var next_node := comp.get_node_or_null(comp.next_component)
		if next_node is JuiceCompBase and not _preview_comps.has(next_node) and not _chain_comps.has(next_node):
			_add_chain_comp(next_node)
			_resolve_chain_comps(next_node)
	
	# Follow loop_target (LooperJuiceComp)
	if comp is LooperJuiceComp and not comp.loop_target.is_empty():
		var loop_node := comp.get_node_or_null(comp.loop_target)
		if loop_node is JuiceCompBase and not _preview_comps.has(loop_node) and not _chain_comps.has(loop_node):
			_add_chain_comp(loop_node)
			_resolve_chain_comps(loop_node)
	
	# Follow JuiceCompBase children (RandomJuiceComp's children, etc.)
	for child in comp.get_children():
		if child is JuiceCompBase and not _preview_comps.has(child) and not _chain_comps.has(child):
			_add_chain_comp(child)
			_resolve_chain_comps(child)


## Recalculate the longest total duration across trigger comps.
## Used to set the scrub slider range (only meaningful when scrubbable).
func _recalculate_max_duration() -> void:
	_max_duration = 0.0
	for comp in _preview_comps:
		if is_instance_valid(comp):
			_max_duration = maxf(_max_duration, comp.get_total_preview_duration())
