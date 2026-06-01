## Internal runtime helper for scene transition lifecycle management.
##
## Manages the full cover → action → reveal → cleanup lifecycle for scene actions.
## Lives on the SceneTree root so it survives during scene switching or reloading.
##
## WHY THIS EXISTS:
## When switching/reloading scenes, the SceneActionJuiceUtility that triggered
## the transition gets destroyed along with its scene. This handler is added
## to the tree root BEFORE the scene change so it survives and can manage
## the full transition lifecycle (cover animation → scene action → reveal).

# ============================================================================
# JUICE TRANSITION HANDLER — Internal Runtime Helper
# ============================================================================
# SYSTEM: Juice System (addons/Juice_V2/Utilities/)
# DOES NOT HANDLE:
# - OVERLAY_SCENE (the utility survives for that, no handler needed)
# - Inspector configuration (all config is copied from the utility at creation)
# - Being user-facing (no class_name, underscore prefix = internal)
#
# RUNTIME COMP REUSE:
# Creates ScreenOverlayJuiceEffectBase instances at runtime for SOLID_COLOR/IMAGE
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

# Timing (from JuiceBase Animate In/Out groups)
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

var _overlay_effect: ScreenOverlayJuiceEffectBase = null  # Ticked manually in _process()
var _transition_canvas: CanvasLayer = null
var _transition_scene_instance: Node = null

# Emitted from _process() when the currently ticking overlay effect completes.
signal _overlay_animation_completed


# =============================================================================
# PUBLIC API
# =============================================================================

# =============================================================================
# LIFECYCLE
# =============================================================================

# Ticks _overlay_effect manually each frame. The effect is NOT in the scene
# tree — it is a detached resource instantiated by _create_overlay_effect_cover.
# When tick() returns COMPLETED, emits _overlay_animation_completed so the
# awaiting coroutine in _execute_overlay_transition can advance.
func _process(delta: float) -> void:
	if _overlay_effect == null or not _overlay_effect.is_playing():
		return
	var result := _overlay_effect.tick(delta, null)
	if result == JuiceEffectBase.TickResult.COMPLETED:
		_overlay_animation_completed.emit()


## Start the full transition sequence. Called once after configuration.
func execute() -> void:
	# Must run even when time is paused (e.g., if game was paused before quit)
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "_JuiceTransitionHandler"

	JuiceLogger.log_info(self, "Transition",
			"Starting: action=%d, overlay=%d" % [scene_action, overlay_type],
			debug_enabled)

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

# Instant cut: performs the scene action immediately with no overlay.
# Waits one process_frame after the action so the scene tree has settled
# (nodes replaced, deferred calls flushed) before emitting completed.
# QUIT_GAME skips the frame wait — the process is about to exit anyway.
func _execute_no_transition() -> void:
	# Instant cut — no visual transition
	_emit_action_executed()
	_perform_scene_action()
	# Wait one frame for scene change to process
	if scene_action != SceneAction.QUIT_GAME:
		await get_tree().process_frame
	_emit_completed()


# 7-phase cover → action → reveal sequence with async load overlap:
# Phase 1: Kick off background load (SWITCH_SCENE only) during cover.
# Phase 2-3: Cover animation — blocks until _overlay_animation_completed.
# Phase 4: Wait for async load to finish (overlapped with cover duration).
# Phase 5: Execute scene action. QUIT_GAME exits early here.
# Phase 6-7: Reveal — same effect instance reconfigured to TO_CLEAR direction.
# Phase 8: Clean up overlay provider and emit completed.
func _execute_overlay_transition() -> void:
	# Phase 1: Start async loading (SWITCH_SCENE only)
	if scene_action == SceneAction.SWITCH_SCENE and target_scene != null:
		_start_async_load(target_scene.resource_path)

	# Phase 2: Cover — create cover effect and tick until complete
	_overlay_effect = _create_overlay_effect_cover()
	if _overlay_effect == null:
		JuiceLogger.warn(self, "Transition",
				"Failed to create overlay effect — aborting", debug_enabled)
		_emit_completed()
		return

	_overlay_effect.start(null, true, false)
	await _overlay_animation_completed

	JuiceLogger.log_info(self, "Transition", "Cover complete", debug_enabled)

	# Phase 3: Ensure async load is ready
	if scene_action == SceneAction.SWITCH_SCENE and target_scene != null:
		await _await_async_load(target_scene.resource_path)

	# Phase 4: Execute the scene action
	_emit_action_executed()
	_perform_scene_action()

	# QUIT_GAME exits here — clear overlay and leave
	if scene_action == SceneAction.QUIT_GAME:
		JuiceScreenOverlayProvider.clear()
		return

	# Phase 5: Wait one frame for scene change to settle
	await get_tree().process_frame

	# Phase 6: Reveal — reconfigure to TO_CLEAR direction and animate
	_configure_overlay_effect_reveal(_overlay_effect)
	_overlay_effect.start(null, true, false)
	await _overlay_animation_completed

	JuiceLogger.log_info(self, "Transition", "Reveal complete", debug_enabled)

	# Phase 7: Clean up
	JuiceScreenOverlayProvider.clear()
	_overlay_effect = null

	_emit_completed()


# Instances the user's transition scene onto a dedicated CanvasLayer on root
# so it renders above all gameplay content and survives scene switching.
# Phase 3: Awaits 'screen_covered' signal OR a fallback timer if the scene
# doesn't declare the expected signal contract.
# Phase 6: Awaits 'transition_finished' OR a fallback timer — same duality.
# Both awaits log a warning when falling back, so users can see they need to
# add the signal contract to their custom transition scene.
func _execute_scene_transition() -> void:
	if transition_scene == null:
		JuiceLogger.warn(self, "Transition",
				"transition_scene is null — falling back to NONE", debug_enabled)
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

	JuiceLogger.log_info(self, "Transition", "Transition scene instanced", debug_enabled)

	# Phase 3: Wait for cover
	if use_scene_timing and _transition_scene_instance.has_signal("screen_covered"):
		await _transition_scene_instance.screen_covered
	else:
		if use_scene_timing and not _transition_scene_instance.has_signal("screen_covered"):
			JuiceLogger.warn(self, "Transition",
					"Transition scene missing 'screen_covered' signal — using fallback timer",
					debug_enabled)
		await get_tree().create_timer(fallback_cover_duration, true, false, true).timeout

	JuiceLogger.log_info(self, "Transition", "Cover phase complete (scene transition)", debug_enabled)

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
			JuiceLogger.warn(self, "Transition",
					"Transition scene missing 'transition_finished' signal — using fallback timer",
					debug_enabled)
		await get_tree().create_timer(fallback_reveal_duration, true, false, true).timeout

	JuiceLogger.log_info(self, "Transition", "Reveal phase complete (scene transition)", debug_enabled)

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

# Executes the configured scene action. For SWITCH_SCENE, prefers the
# async-loaded resource (already in memory from background load) over the
# original PackedScene reference to avoid a synchronous disk read.
func _perform_scene_action() -> void:
	match scene_action:
		SceneAction.SWITCH_SCENE:
			if target_scene == null:
				JuiceLogger.warn(self, "Transition",
					"cannot switch — target_scene is null", debug_enabled)
				return
			# Use async-loaded resource if available, otherwise use PackedScene directly
			var loaded: PackedScene = _get_async_loaded(target_scene.resource_path)
			if loaded == null:
				loaded = target_scene
			get_tree().change_scene_to_packed(loaded)
			JuiceLogger.log_info(self, "Transition",
					"Scene switched to: %s" % target_scene.resource_path,
					debug_enabled)

		SceneAction.RELOAD_SCENE:
			get_tree().reload_current_scene()
			JuiceLogger.log_info(self, "Transition", "Scene reloaded", debug_enabled)

		SceneAction.QUIT_GAME:
			JuiceLogger.log_info(self, "Transition", "Quitting game", debug_enabled)
			get_tree().quit()

		_:
			JuiceLogger.warn(self, "Transition",
					"unknown scene_action: %d" % scene_action, debug_enabled)


# =============================================================================
# OVERLAY EFFECT CREATION (ScreenOverlayJuiceEffectBase)
# =============================================================================

# Builds a ScreenOverlayJuiceEffectBase configured for the COVER direction:
# TO_COLOR (clear → opaque). Sets PLAY_IN_ONLY so the effect stops at full
# opacity rather than auto-reversing — the reveal is handled as a second
# animation pass by _configure_overlay_effect_reveal.
func _create_overlay_effect_cover() -> ScreenOverlayJuiceEffectBase:
	var effect := ScreenOverlayJuiceEffectBase.new()
	effect.overlay_color = overlay_color
	if overlay_image != null:
		effect.overlay_texture = overlay_image
	effect.blend_mode = overlay_blend_mode
	effect.max_alpha = 1.0
	effect.direction = ScreenOverlayJuiceEffectBase.OverlayDirection.TO_COLOR
	effect.duration_in = cover_duration
	effect.transition_in = cover_transition as Tween.TransitionType
	effect.ease_in = cover_ease as Tween.EaseType
	if cover_curve != null:
		effect.custom_curve_in = cover_curve
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.debug_enabled = debug_enabled
	return effect


# Mutates the existing cover effect in-place for the reveal pass.
# Flips direction to TO_CLEAR (opaque → clear) and applies reveal timing.
# Reusing the same instance avoids allocating a second effect and preserves
# the overlay's current visual state (already at full opacity after cover).
func _configure_overlay_effect_reveal(effect: ScreenOverlayJuiceEffectBase) -> void:
	effect.direction = ScreenOverlayJuiceEffectBase.OverlayDirection.TO_CLEAR
	effect.duration_in = reveal_duration
	effect.transition_in = reveal_transition as Tween.TransitionType
	effect.ease_in = reveal_ease as Tween.EaseType
	if reveal_curve != null:
		effect.custom_curve_in = reveal_curve


# =============================================================================
# ASYNC SCENE LOADING
# =============================================================================

# Kicks off a threaded background load. Skips if the resource is already
# in cache (embedded PackedScenes and recently loaded scenes are cached).
# The load runs concurrently with the cover animation to minimise stall time.
func _start_async_load(path: String) -> void:
	if path.is_empty():
		return
	# Check if already loaded (embedded PackedScene)
	if ResourceLoader.has_cached(path):
		JuiceLogger.log_info(self, "Transition",
				"Scene already cached: %s" % path, debug_enabled)
		return
	ResourceLoader.load_threaded_request(path)
	JuiceLogger.log_info(self, "Transition",
			"Async load started: %s" % path, debug_enabled)


# Frame-polling loop: yields to process_frame until ResourceLoader status
# leaves THREAD_LOAD_IN_PROGRESS. Logs FAILED / INVALID_RESOURCE warnings
# so users know when a scene path was invalid without a silent stall.
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
		JuiceLogger.warn(self, "Transition",
				"async load FAILED: %s" % path, debug_enabled)
	elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		JuiceLogger.warn(self, "Transition",
				"invalid resource: %s" % path, debug_enabled)
	else:
		JuiceLogger.log_info(self, "Transition",
				"Async load complete: %s" % path, debug_enabled)


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
