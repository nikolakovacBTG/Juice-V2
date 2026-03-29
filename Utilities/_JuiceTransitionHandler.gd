# ============================================================================
# JUICE TRANSITION HANDLER — Internal Runtime Helper
# ============================================================================
# Manages the full cover → action → reveal → cleanup lifecycle for scene
# actions that destroy the triggering scene (SWITCH_SCENE, RELOAD_SCENE,
# QUIT_GAME). Lives on SceneTree root so it persists across scene changes.
#
# SYSTEM: Juice System (addons/Juice_V1/Utilities/)
#
# WHY THIS EXISTS:
# When switching/reloading scenes, the SceneActionJuiceUtility that triggered
# the transition gets destroyed along with its scene. This handler is added
# to the tree root BEFORE the scene change so it survives and can manage
# the full transition lifecycle (cover animation → scene action → reveal).
#
# DOES NOT HANDLE:
# - OVERLAY_SCENE (the utility survives for that, no handler needed)
# - Inspector configuration (all config is copied from the utility at creation)
# - Being user-facing (no class_name, underscore prefix = internal)
#
# RUNTIME COMP REUSE:
# Creates ScreenOverlayJuiceComp instances at runtime for SOLID_COLOR/IMAGE
# transitions. For SCENE transitions, instances the user's transition scene.
# This keeps all overlay logic in existing battle-tested components.
# ============================================================================

extends Node


# =============================================================================
# ENUMS (mirrors from SceneActionJuiceUtility — avoids circular dependency)
# =============================================================================

enum SceneAction {
	SWITCH_SCENE,
	OVERLAY_SCENE,
	RELOAD_SCENE,
	QUIT_GAME,
}

enum TransitionOverlay {
	NONE,
	SOLID_COLOR,
	IMAGE,
	SCENE,
}


# =============================================================================
# CONFIGURATION (copied from SceneActionJuiceUtility at creation time)
# =============================================================================

# Scene action
var scene_action: int = SceneAction.SWITCH_SCENE
var target_scene: PackedScene = null

# Transition overlay type
var overlay_type: int = TransitionOverlay.NONE

# ScreenOverlayJuiceComp settings (SOLID_COLOR / IMAGE)
var overlay_color: Color = Color.BLACK
var overlay_image: Texture2D = null
var overlay_blend_mode: int = 0  # ScreenOverlayJuiceComp.OverlayBlendMode.MIX

# Transition scene (SCENE overlay type)
var transition_scene: PackedScene = null
var use_scene_timing: bool = true
var fallback_cover_duration: float = 0.5
var fallback_reveal_duration: float = 0.5

# Timing (from JuiceCompBase Animate In/Out groups)
var cover_duration: float = 0.4
var cover_transition: int = Tween.TRANS_QUAD
var cover_ease: int = Tween.EASE_OUT
var cover_curve: Curve = null
var reveal_duration: float = 0.4
var reveal_transition: int = Tween.TRANS_QUAD
var reveal_ease: int = Tween.EASE_IN
var reveal_curve: Curve = null

# Overlay canvas layer
var overlay_canvas_layer: int = 100

# Debug
var debug_enabled: bool = false

# Callback to emit action_executed on the utility (if still valid)
var action_executed_callback: Callable = Callable()

# Callback to emit completed on the utility (if still valid)
var completed_callback: Callable = Callable()


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _overlay_comp: Node = null  # Runtime ScreenOverlayJuiceComp instance
var _transition_canvas: CanvasLayer = null
var _transition_scene_instance: Node = null


# =============================================================================
# PUBLIC API
# =============================================================================

## Start the full transition sequence. Called once after configuration.
func execute() -> void:
	# Must run even when time is paused (e.g., if game was paused before quit)
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "_JuiceTransitionHandler"

	if debug_enabled:
		print("[TransitionHandler] Starting: action=%d, overlay=%d" % [scene_action, overlay_type])

	match overlay_type:
		TransitionOverlay.NONE:
			await _execute_no_transition()
		TransitionOverlay.SOLID_COLOR, TransitionOverlay.IMAGE:
			await _execute_overlay_transition()
		TransitionOverlay.SCENE:
			await _execute_scene_transition()

	# Self-destruct
	queue_free()


# =============================================================================
# TRANSITION PATHS
# =============================================================================

func _execute_no_transition() -> void:
	# Instant cut — no visual transition
	_emit_action_executed()
	_perform_scene_action()
	# Wait one frame for scene change to process
	if scene_action != SceneAction.QUIT_GAME:
		await get_tree().process_frame
	_emit_completed()


func _execute_overlay_transition() -> void:
	# Phase 1: Start async loading (SWITCH_SCENE only)
	if scene_action == SceneAction.SWITCH_SCENE and target_scene != null:
		_start_async_load(target_scene.resource_path)

	# Phase 2: Cover — create runtime ScreenOverlayJuiceComp and fade to opaque
	_overlay_comp = await _create_overlay_comp_cover()
	if _overlay_comp == null:
		push_warning("[TransitionHandler] Failed to create overlay comp — aborting")
		_emit_completed()
		return

	_overlay_comp.animate_in()
	await _overlay_comp.completed

	if debug_enabled:
		print("[TransitionHandler] Cover complete")

	# Phase 3: Ensure async load is ready
	if scene_action == SceneAction.SWITCH_SCENE and target_scene != null:
		await _await_async_load(target_scene.resource_path)

	# Phase 4: Execute the scene action
	_emit_action_executed()
	_perform_scene_action()

	# QUIT_GAME exits here — no reveal needed
	if scene_action == SceneAction.QUIT_GAME:
		return

	# Phase 5: Wait one frame for scene change to settle
	await get_tree().process_frame

	# Phase 6: Reveal — reconfigure overlay comp and fade to transparent
	_configure_overlay_comp_reveal(_overlay_comp)
	_overlay_comp.animate_in()
	await _overlay_comp.completed

	if debug_enabled:
		print("[TransitionHandler] Reveal complete")

	# Phase 7: Clean up overlay comp
	_overlay_comp.queue_free()
	_overlay_comp = null

	_emit_completed()


func _execute_scene_transition() -> void:
	if transition_scene == null:
		push_warning("[TransitionHandler] transition_scene is null — falling back to NONE")
		await _execute_no_transition()
		return

	# Phase 1: Start async loading (SWITCH_SCENE only)
	if scene_action == SceneAction.SWITCH_SCENE and target_scene != null:
		_start_async_load(target_scene.resource_path)

	# Phase 2: Instance transition scene on a CanvasLayer
	_transition_canvas = CanvasLayer.new()
	_transition_canvas.layer = overlay_canvas_layer
	_transition_canvas.name = "_JuiceTransitionCanvas"
	_transition_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_transition_canvas)

	_transition_scene_instance = transition_scene.instantiate()
	_transition_scene_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	_transition_canvas.add_child(_transition_scene_instance)

	if debug_enabled:
		print("[TransitionHandler] Transition scene instanced")

	# Phase 3: Wait for cover
	if use_scene_timing and _transition_scene_instance.has_signal("screen_covered"):
		await _transition_scene_instance.screen_covered
	else:
		if use_scene_timing and not _transition_scene_instance.has_signal("screen_covered"):
			push_warning("[TransitionHandler] Transition scene missing 'screen_covered' signal — using fallback timer")
		await get_tree().create_timer(fallback_cover_duration, true, false, true).timeout

	if debug_enabled:
		print("[TransitionHandler] Cover phase complete (scene transition)")

	# Phase 4: Ensure async load is ready
	if scene_action == SceneAction.SWITCH_SCENE and target_scene != null:
		await _await_async_load(target_scene.resource_path)

	# Phase 5: Execute scene action
	_emit_action_executed()
	_perform_scene_action()

	if scene_action == SceneAction.QUIT_GAME:
		return

	# Phase 6: Wait for reveal
	await get_tree().process_frame

	if use_scene_timing and _transition_scene_instance.has_signal("transition_finished"):
		await _transition_scene_instance.transition_finished
	else:
		if use_scene_timing and not _transition_scene_instance.has_signal("transition_finished"):
			push_warning("[TransitionHandler] Transition scene missing 'transition_finished' signal — using fallback timer")
		await get_tree().create_timer(fallback_reveal_duration, true, false, true).timeout

	if debug_enabled:
		print("[TransitionHandler] Reveal phase complete (scene transition)")

	# Phase 7: Clean up
	if is_instance_valid(_transition_scene_instance):
		_transition_scene_instance.queue_free()
	if is_instance_valid(_transition_canvas):
		_transition_canvas.queue_free()
	_transition_scene_instance = null
	_transition_canvas = null

	_emit_completed()


# =============================================================================
# SCENE ACTIONS
# =============================================================================

func _perform_scene_action() -> void:
	match scene_action:
		SceneAction.SWITCH_SCENE:
			if target_scene == null:
				push_error("[TransitionHandler] Cannot switch — target_scene is null")
				return
			# Use async-loaded resource if available, otherwise use PackedScene directly
			var loaded: PackedScene = _get_async_loaded(target_scene.resource_path)
			if loaded == null:
				loaded = target_scene
			get_tree().change_scene_to_packed(loaded)
			if debug_enabled:
				print("[TransitionHandler] Scene switched to: %s" % target_scene.resource_path)

		SceneAction.RELOAD_SCENE:
			get_tree().reload_current_scene()
			if debug_enabled:
				print("[TransitionHandler] Scene reloaded")

		SceneAction.QUIT_GAME:
			if debug_enabled:
				print("[TransitionHandler] Quitting game")
			get_tree().quit()

		_:
			push_error("[TransitionHandler] Unknown scene_action: %d" % scene_action)


# =============================================================================
# RUNTIME OVERLAY COMP CREATION (ScreenOverlayJuiceComp reuse)
# =============================================================================

func _create_overlay_comp_cover() -> Node:
	# STUB: ScreenOverlayJuiceComp is not yet ported to V1.
	# SOLID_COLOR and IMAGE transitions are not functional until Screen effects are ported.
	push_warning("[TransitionHandler] SOLID_COLOR/IMAGE transitions require ScreenOverlayJuiceComp (not yet ported to V1). Transition will be instant.")
	return null


func _configure_overlay_comp_reveal(_comp: Node) -> void:
	# STUB: No-op until ScreenOverlayJuiceComp is ported.
	pass


# =============================================================================
# ASYNC SCENE LOADING
# =============================================================================

func _start_async_load(path: String) -> void:
	if path.is_empty():
		return
	# Check if already loaded (embedded PackedScene)
	if ResourceLoader.has_cached(path):
		if debug_enabled:
			print("[TransitionHandler] Scene already cached: %s" % path)
		return
	ResourceLoader.load_threaded_request(path)
	if debug_enabled:
		print("[TransitionHandler] Async load started: %s" % path)


func _await_async_load(path: String) -> void:
	if path.is_empty():
		return
	if ResourceLoader.has_cached(path):
		return
	# Poll until loaded
	var status := ResourceLoader.load_threaded_get_status(path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_FAILED:
		push_error("[TransitionHandler] Async load FAILED: %s" % path)
	elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("[TransitionHandler] Invalid resource: %s" % path)
	elif debug_enabled:
		print("[TransitionHandler] Async load complete: %s" % path)


func _get_async_loaded(path: String) -> PackedScene:
	if path.is_empty():
		return null
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		return ResourceLoader.load_threaded_get(path) as PackedScene
	return null


# =============================================================================
# SIGNAL HELPERS
# =============================================================================

func _emit_action_executed() -> void:
	if action_executed_callback.is_valid():
		action_executed_callback.call()


func _emit_completed() -> void:
	if completed_callback.is_valid():
		completed_callback.call()
