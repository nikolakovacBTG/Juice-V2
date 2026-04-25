# ============================================================================
# JUICE SCENE ACTION ORCHESTRATOR — Internal Runtime Singleton
# ============================================================================
# WHAT: Manages the full cover → hold → action → reveal → cleanup lifecycle
#       for scene actions. Lives on SceneTree root so it persists across
#       scene changes. Self-destructs via queue_free() on completion.
# WHY:  SceneActionJuiceUtilityBase is a Resource without lifecycle. This
#       ephemeral Node is spawned by the effect to handle scene tree mutations
#       independently. A singleton guard prevents parallel scene actions.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# DOES NOT: Appear in the inspector or have a class_name (internal only).
# DOES NOT: Hold back-references to the triggering effect Resource.
# ============================================================================

extends Node


# =============================================================================
# ENUMS (mirrored from SceneActionJuiceUtilityBase — avoids circular deps)
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

enum SwitchFrom {
	THIS_SCENE,
	SCENE_IN_TREE,
	FIRST_SCENE_IN_CONTAINER,
}

enum OldScenePostSwitchAction {
	FREE,
	HIDE,
	REMOVE_FROM_TREE,
}


# =============================================================================
# STATIC STATE
# =============================================================================

## Singleton guard — prevents parallel scene actions.
static var _active_orchestrator: Node = null

## Tracks the most recently activated OVERLAY_SCENE orchestrator for the
## static close API. Allows overlay scenes to close themselves.
static var _active_overlay_orchestrator: Node = null


# =============================================================================
# CONFIGURATION (all stamped at spawn time — no back-references)
# =============================================================================

# --- Scene action ---
var scene_action: int = SceneAction.SWITCH_SCENE
var switch_from_mode: int = SwitchFrom.THIS_SCENE
var target_scene: PackedScene = null
var old_scene_post_switch_action: int = OldScenePostSwitchAction.FREE

# --- Resolved node references (resolved by effect before spawn) ---
var switch_from_node: Node = null
var container_node: Node = null

# --- Overlay behavior (OVERLAY_SCENE only) ---
var overlay_canvas_layer: int = 100
var use_time_effect: bool = false
var time_mode: int = 0
var time_target_scale: float = 0.3
var time_smooth_transition: bool = true
var time_freeze_frames: int = 3
var time_exempt_nodes: Array[NodePath] = []

# --- Transition overlay ---
var overlay_type: int = TransitionOverlay.NONE
var overlay_color: Color = Color.BLACK
var overlay_image: Texture2D = null
var overlay_blend_mode: int = 0
var transition_scene: PackedScene = null
var use_scene_timing: bool = true
var fallback_cover_duration: float = 0.5
var fallback_reveal_duration: float = 0.5

# --- Timing (copied from effect's base class Animate In/Out) ---
var cover_duration: float = 0.4
var cover_transition: int = Tween.TRANS_QUAD
var cover_ease: int = Tween.EASE_OUT
var cover_curve: Curve = null
var hold_duration: float = 0.0
var reveal_duration: float = 0.4
var reveal_transition: int = Tween.TRANS_QUAD
var reveal_ease: int = Tween.EASE_IN
var reveal_curve: Curve = null

# --- Callbacks ---
var action_executed_callback: Callable = Callable()
var completed_callback: Callable = Callable()

# --- Debug ---
var debug_enabled: bool = false


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _overlay_juice_node: JuiceControl = null  # JuiceControl with ScreenOverlay effect
var _overlay_dummy_parent: Control = null       # Dummy Control parent for JuiceControl
var _transition_canvas: CanvasLayer = null
var _transition_scene_instance: Node = null
var _active_overlay_instance: Node = null
var _active_canvas_layer: CanvasLayer = null
var _time_juice_node: JuiceControl = null  # JuiceControl with Time effect
var _time_dummy_parent: Control = null      # Dummy Control parent for time JuiceControl
var _generation: int = 0
var _removed_nodes: Dictionary = {}


# =============================================================================
# STATIC API
# =============================================================================

## Close the most recently opened overlay scene. Call from within an overlay
## scene (e.g., via CallMethodJuiceUtility on a "Close" button).
static func close_active_overlay() -> void:
	if _active_overlay_orchestrator != null and is_instance_valid(_active_overlay_orchestrator):
		_active_overlay_orchestrator._hide_overlay()


# =============================================================================
# PUBLIC API
# =============================================================================

## Start the full transition sequence. Called once after configuration.
func execute() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "_JuiceSceneActionOrchestrator"

	# Singleton guard
	if _active_orchestrator != null and is_instance_valid(_active_orchestrator):
			JuiceLogger.warn(self, "SceneAction",
				"another orchestrator is active — aborting", debug_enabled)
		queue_free()
		return

	_active_orchestrator = self
	_generation += 1

	JuiceLogger.log_info(self, "SceneAction",
			"starting: action=%d overlay=%d" % [scene_action, overlay_type],
			debug_enabled)

	match scene_action:
		SceneAction.SWITCH_SCENE, SceneAction.RELOAD_SCENE, SceneAction.QUIT_GAME:
			await _execute_destructive_action()
		SceneAction.OVERLAY_SCENE:
			await _show_overlay()


# =============================================================================
# DESTRUCTIVE ACTIONS (SWITCH / RELOAD / QUIT)
# =============================================================================

# Handles terminal actions like quit or self-destruct that don't need complex sequencing.
func _execute_destructive_action() -> void:
	# Inline swap modes: orchestrator manages transition inline
	if scene_action == SceneAction.SWITCH_SCENE and (
			switch_from_mode == SwitchFrom.SCENE_IN_TREE or
			switch_from_mode == SwitchFrom.FIRST_SCENE_IN_CONTAINER):
		await _execute_child_swap()
		return

	if overlay_type == TransitionOverlay.NONE:
		_emit_action_executed()
		_perform_direct_action()
		_emit_completed()
		_self_destruct()
		return

	match overlay_type:
		TransitionOverlay.SOLID_COLOR, TransitionOverlay.IMAGE:
			await _execute_overlay_transition()
		TransitionOverlay.SCENE:
			await _execute_scene_transition()


# The final execution step after covers/delays finish. Handles the actual tree mutation (reload, change scene, open overlay).
func _perform_direct_action() -> void:
	match scene_action:
		SceneAction.SWITCH_SCENE:
			if target_scene == null:
				JuiceLogger.warn(self, "SceneAction",
					"cannot switch — target_scene is null", debug_enabled)
				return
			var loaded: PackedScene = _get_async_loaded(target_scene.resource_path)
			if loaded == null:
				loaded = target_scene
			get_tree().change_scene_to_packed(loaded)
			JuiceLogger.log_info(self, "SceneAction",
					"scene switched to: %s" % target_scene.resource_path,
					debug_enabled)

		SceneAction.RELOAD_SCENE:
			get_tree().reload_current_scene()
			JuiceLogger.log_info(self, "SceneAction",
					"scene reloaded", debug_enabled)

		SceneAction.QUIT_GAME:
			JuiceLogger.log_info(self, "SceneAction",
					"quitting game", debug_enabled)
			get_tree().quit()


# =============================================================================
# OVERLAY TRANSITION (SOLID_COLOR / IMAGE)
# =============================================================================

# Manages the sequence of opening or closing an overlay, including pausing the main tree and triggering in/out animations.
func _execute_overlay_transition() -> void:
	var my_gen := _generation

	# Phase 1: Start async loading (SWITCH_SCENE only)
	if scene_action == SceneAction.SWITCH_SCENE and target_scene != null:
		_start_async_load(target_scene.resource_path)

	# Phase 2: Cover
	var juice_node := await _create_overlay_juice_cover()
	if juice_node == null:
		JuiceLogger.warn(self, "SceneAction",
				"failed to create overlay — aborting", debug_enabled)
		_emit_completed()
		_self_destruct()
		return

	juice_node.animate_in()
	await juice_node.completed

	JuiceLogger.log_info(self, "SceneAction",
			"cover complete", debug_enabled)

	# Phase 3: Hold at peak (covered pause)
	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration, true, false, true).timeout
		JuiceLogger.log_info(self, "SceneAction",
				"hold complete (%.2fs)" % hold_duration, debug_enabled)

	# Phase 4: Ensure async load is ready
	if scene_action == SceneAction.SWITCH_SCENE and target_scene != null:
		await _await_async_load(target_scene.resource_path)

	# Phase 5: Execute the scene action
	_emit_action_executed()
	_perform_direct_action()

	# QUIT_GAME exits here
	if scene_action == SceneAction.QUIT_GAME:
		return

	# Phase 6: Wait one frame for scene change to settle
	await get_tree().process_frame

	# Phase 7: Reveal
	_configure_overlay_juice_reveal(juice_node)
	juice_node.animate_in()
	await juice_node.completed

	JuiceLogger.log_info(self, "SceneAction",
			"reveal complete", debug_enabled)

	# Phase 8: Cleanup
	if is_instance_valid(_overlay_dummy_parent):
		_overlay_dummy_parent.queue_free()
		_overlay_dummy_parent = null
	_overlay_juice_node = null

	_emit_completed()
	_self_destruct()


# =============================================================================
# SCENE TRANSITION (custom animated scene)
# =============================================================================

# Orchestrates full scene swaps, managing transition animations, asynchronous loading, and the final scene tree swap.
func _execute_scene_transition() -> void:
	if transition_scene == null:
		JuiceLogger.warn(self, "SceneAction",
				"transition_scene is null — falling back to NONE", debug_enabled)
		_emit_action_executed()
		_perform_direct_action()
		_emit_completed()
		_self_destruct()
		return

	# Phase 1: Start async loading
	if scene_action == SceneAction.SWITCH_SCENE and target_scene != null:
		_start_async_load(target_scene.resource_path)

	# Phase 2: Instance transition scene on CanvasLayer
	_transition_canvas = CanvasLayer.new()
	_transition_canvas.layer = overlay_canvas_layer
	_transition_canvas.name = "_JuiceTransitionCanvas"
	_transition_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_transition_canvas)

	_transition_scene_instance = transition_scene.instantiate()
	_transition_scene_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	_transition_canvas.add_child(_transition_scene_instance)

	JuiceLogger.log_info(self, "SceneAction",
			"transition scene instanced", debug_enabled)

	# Phase 3: Wait for cover
	if use_scene_timing and _transition_scene_instance.has_signal("screen_covered"):
		await _transition_scene_instance.screen_covered
	else:
		if use_scene_timing and not _transition_scene_instance.has_signal("screen_covered"):
			JuiceLogger.warn(self, "SceneAction",
					"transition scene missing 'screen_covered' signal — using fallback",
					debug_enabled)
		await get_tree().create_timer(fallback_cover_duration, true, false, true).timeout

	JuiceLogger.log_info(self, "SceneAction",
			"cover phase complete (scene transition)", debug_enabled)

	# Phase 3b: Hold at peak
	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration, true, false, true).timeout

	# Phase 4: Ensure async load
	if scene_action == SceneAction.SWITCH_SCENE and target_scene != null:
		await _await_async_load(target_scene.resource_path)

	# Phase 5: Execute scene action
	_emit_action_executed()
	_perform_direct_action()

	if scene_action == SceneAction.QUIT_GAME:
		return

	# Phase 6: Wait for reveal
	await get_tree().process_frame

	if use_scene_timing and _transition_scene_instance.has_signal("transition_finished"):
		await _transition_scene_instance.transition_finished
	else:
		if use_scene_timing and not _transition_scene_instance.has_signal("transition_finished"):
			JuiceLogger.warn(self, "SceneAction",
					"transition scene missing 'transition_finished' signal — using fallback",
					debug_enabled)
		await get_tree().create_timer(fallback_reveal_duration, true, false, true).timeout

	JuiceLogger.log_info(self, "SceneAction",
			"reveal phase complete (scene transition)", debug_enabled)

	# Phase 7: Cleanup
	if is_instance_valid(_transition_scene_instance):
		_transition_scene_instance.queue_free()
	if is_instance_valid(_transition_canvas):
		_transition_canvas.queue_free()
	_transition_scene_instance = null
	_transition_canvas = null

	_emit_completed()
	_self_destruct()


# =============================================================================
# INLINE SCENE SWAP (SCENE_IN_TREE / FIRST_SCENE_IN_CONTAINER)
# =============================================================================

# Swaps a localized child node instead of the entire scene, useful for sub-menus or localized content changes.
func _execute_child_swap() -> void:
	var my_gen := _generation

	# Resolve from_scene based on mode
	var from_scene: Node = null

	if switch_from_mode == SwitchFrom.SCENE_IN_TREE:
		from_scene = switch_from_node
		if from_scene == null:
			JuiceLogger.warn(self, "SceneAction",
					"cannot swap — switch_from_node not resolved", debug_enabled)
			_emit_completed()
			_self_destruct()
			return

	elif switch_from_mode == SwitchFrom.FIRST_SCENE_IN_CONTAINER:
		if container_node == null:
			JuiceLogger.warn(self, "SceneAction",
					"cannot swap — container_node not resolved", debug_enabled)
			_emit_completed()
			_self_destruct()
			return
		if container_node.get_child_count() == 0:
			JuiceLogger.warn(self, "SceneAction",
					"cannot swap — container '%s' has no children" % container_node.name,
					debug_enabled)
			_emit_completed()
			_self_destruct()
			return
		from_scene = container_node.get_child(0)

	if target_scene == null:
		JuiceLogger.warn(self, "SceneAction",
				"cannot swap — target_scene is null", debug_enabled)
		_emit_completed()
		_self_destruct()
		return

	# Phase 1: Cover transition
	if overlay_type != TransitionOverlay.NONE:
		await _play_overlay_cover()
		if _generation != my_gen:
			return

	# Phase 1b: Hold at peak
	if hold_duration > 0.0:
		await get_tree().create_timer(hold_duration, true, false, true).timeout

	# Phase 2: Capture position in parent
	var parent := from_scene.get_parent()
	var child_index := from_scene.get_index()

	# Phase 3: Handle old scene
	match old_scene_post_switch_action:
		OldScenePostSwitchAction.FREE:
			from_scene.queue_free()
		OldScenePostSwitchAction.HIDE:
			from_scene.visible = false
			from_scene.process_mode = Node.PROCESS_MODE_DISABLED
		OldScenePostSwitchAction.REMOVE_FROM_TREE:
			parent.remove_child(from_scene)
			_removed_nodes[from_scene.name] = from_scene

	# Phase 4: Instance new scene at same position
	var new_instance := target_scene.instantiate()
	parent.add_child(new_instance)
	parent.move_child(new_instance, child_index)

	JuiceLogger.log_info(self, "SceneAction",
			"scene swap: '%s' → '%s' (post_action=%s)" % [
			from_scene.name, new_instance.name,
			OldScenePostSwitchAction.keys()[old_scene_post_switch_action]],
			debug_enabled)

	_emit_action_executed()

	# Phase 5: Reveal transition
	if overlay_type != TransitionOverlay.NONE:
		await _play_overlay_reveal()
		if _generation != my_gen:
			return

	# Phase 6: Cleanup
	_cleanup_transition_resources()

	_emit_completed()
	_self_destruct()


# =============================================================================
# OVERLAY SCENE (toggle-friendly)
# =============================================================================

# Instantiates the overlay scene, pauses the main tree, and plays the reveal animation.
func _show_overlay() -> void:
	_active_overlay_orchestrator = self

	# Phase 1: Cover
	if overlay_type != TransitionOverlay.NONE:
		await _play_overlay_cover()

	# Phase 2: Instance overlay on CanvasLayer
	if target_scene == null:
		JuiceLogger.warn(self, "SceneAction",
				"cannot overlay — target_scene is null", debug_enabled)
		_emit_completed()
		_self_destruct()
		return

	_active_canvas_layer = CanvasLayer.new()
	_active_canvas_layer.layer = overlay_canvas_layer
	_active_canvas_layer.name = "_JuiceOverlayCanvas"
	_active_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_active_canvas_layer)

	_active_overlay_instance = target_scene.instantiate()
	_active_overlay_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	_active_canvas_layer.add_child(_active_overlay_instance)

	JuiceLogger.log_info(self, "SceneAction",
			"overlay scene instanced on CanvasLayer %d" % overlay_canvas_layer,
			debug_enabled)

	# Phase 3: Time effect
	if use_time_effect:
		_create_time_juice_node()

	# Phase 4: Emit action_executed
	_emit_action_executed()

	# Phase 5: Reveal (fade out cover to show overlay scene)
	if overlay_type != TransitionOverlay.NONE:
		await _play_overlay_reveal()

	_emit_completed()

	JuiceLogger.log_info(self, "SceneAction",
			"overlay show complete", debug_enabled)

	# Note: orchestrator stays alive for _hide_overlay() call


# Triggers the overlay's cover animation before unpausing the tree and destroying the overlay.
func _hide_overlay() -> void:
	_generation += 1

	# Phase 1: Restore time
	if _time_juice_node != null and is_instance_valid(_time_juice_node):
		_time_juice_node.animate_out()
		await _time_juice_node.completed
		if is_instance_valid(_time_dummy_parent):
			_time_dummy_parent.queue_free()
			_time_dummy_parent = null
		_time_juice_node = null

	# Phase 2: Cover (cover overlay scene before removing)
	if overlay_type != TransitionOverlay.NONE:
		await _play_overlay_cover()

	# Phase 3: Remove overlay scene
	if is_instance_valid(_active_overlay_instance):
		_active_overlay_instance.queue_free()
		_active_overlay_instance = null
	if is_instance_valid(_active_canvas_layer):
		_active_canvas_layer.queue_free()
		_active_canvas_layer = null

	# Phase 4: Reveal (reveal base scene)
	if overlay_type != TransitionOverlay.NONE:
		await _play_overlay_reveal()

	# Phase 5: Cleanup
	_cleanup_transition_resources()
	_active_overlay_orchestrator = null

	JuiceLogger.log_info(self, "SceneAction",
			"overlay hide complete", debug_enabled)

	_self_destruct()


# =============================================================================
# OVERLAY TRANSITION HELPERS
# =============================================================================

# Spawns the dynamic Juice node to animate the overlay out.
func _play_overlay_cover() -> void:
	match overlay_type:
		TransitionOverlay.SOLID_COLOR, TransitionOverlay.IMAGE:
			var juice_node := await _create_overlay_juice_cover()
			if juice_node == null:
				return
			juice_node.animate_in()
			await juice_node.completed

		TransitionOverlay.SCENE:
			await _play_transition_scene_cover()


# Spawns the dynamic Juice node to animate the overlay in.
func _play_overlay_reveal() -> void:
	match overlay_type:
		TransitionOverlay.SOLID_COLOR, TransitionOverlay.IMAGE:
			if _overlay_juice_node != null and is_instance_valid(_overlay_juice_node):
				_configure_overlay_juice_reveal(_overlay_juice_node)
				_overlay_juice_node.animate_in()
				await _overlay_juice_node.completed

		TransitionOverlay.SCENE:
			await _play_transition_scene_reveal()


# Instantiates the transition scene layer to visually block the screen before a full scene swap.
func _play_transition_scene_cover() -> void:
	if transition_scene == null:
		JuiceLogger.warn(self, "SceneAction",
				"transition_scene is null — skipping SCENE transition", debug_enabled)
		return

	_transition_canvas = CanvasLayer.new()
	_transition_canvas.layer = overlay_canvas_layer
	_transition_canvas.name = "_JuiceTransitionCanvas"
	_transition_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_transition_canvas)

	_transition_scene_instance = transition_scene.instantiate()
	_transition_scene_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	_transition_canvas.add_child(_transition_scene_instance)

	if use_scene_timing and _transition_scene_instance.has_signal("screen_covered"):
		await _transition_scene_instance.screen_covered
	else:
		if use_scene_timing and not _transition_scene_instance.has_signal("screen_covered"):
			JuiceLogger.warn(self, "SceneAction",
					"transition scene missing 'screen_covered' signal — using fallback",
					debug_enabled)
		await get_tree().create_timer(fallback_cover_duration, true, false, true).timeout


# Triggers the transition scene to un-block the screen after the new scene has loaded.
func _play_transition_scene_reveal() -> void:
	if _transition_scene_instance == null or not is_instance_valid(_transition_scene_instance):
		return

	if use_scene_timing and _transition_scene_instance.has_signal("transition_finished"):
		await _transition_scene_instance.transition_finished
	else:
		if use_scene_timing and not _transition_scene_instance.has_signal("transition_finished"):
			JuiceLogger.warn(self, "SceneAction",
					"transition scene missing 'transition_finished' signal — using fallback",
					debug_enabled)
		await get_tree().create_timer(fallback_reveal_duration, true, false, true).timeout

	if is_instance_valid(_transition_scene_instance):
		_transition_scene_instance.queue_free()
		_transition_scene_instance = null
	if is_instance_valid(_transition_canvas):
		_transition_canvas.queue_free()
		_transition_canvas = null


# =============================================================================
# RUNTIME NODE CREATION
# =============================================================================

## Creates a JuiceControl + ScreenOverlayControlJuiceEffect configured for cover.
## Returns the JuiceControl node (await its `completed` signal after `animate_in()`).
func _create_overlay_juice_cover() -> JuiceControl:
	# Build the effect Resource
	var effect := ScreenOverlayControlJuiceEffect.new()
	effect.overlay_color = overlay_color
	effect.max_alpha = 1.0
	effect.direction = ScreenOverlayJuiceEffectBase.OverlayDirection.TO_COLOR

	if overlay_type == TransitionOverlay.IMAGE and overlay_image != null:
		effect.overlay_texture = overlay_image

	effect.blend_mode = overlay_blend_mode

	# Timing — cover phase uses Animate In
	effect.duration_in = cover_duration
	effect.transition_in = cover_transition
	effect.ease_in = cover_ease
	effect.custom_curve_in = cover_curve

	# Build recipe
	var recipe := JuiceControlRecipe.new()
	recipe.effects = [effect]

	# Build dummy Control parent (JuiceControl requires a Control parent)
	_overlay_dummy_parent = Control.new()
	_overlay_dummy_parent.name = "_OverlayDummyParent"
	_overlay_dummy_parent.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay_dummy_parent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay_dummy_parent)

	# Build JuiceControl node
	var juice_node := JuiceControl.new()
	juice_node.name = "_TransitionOverlay"
	juice_node.process_mode = Node.PROCESS_MODE_ALWAYS
	juice_node.recipe = recipe
	juice_node.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice_node.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	juice_node.auto_connect_parent = false

	_overlay_dummy_parent.add_child(juice_node)

	# Wait one frame for _ready to resolve target and clone effects
	await get_tree().process_frame

	JuiceLogger.log_info(self, "SceneAction",
			"cover overlay created (duration=%.2f)" % cover_duration,
			debug_enabled)

	_overlay_juice_node = juice_node
	return juice_node


## Reconfigures the existing overlay JuiceControl for the reveal phase.
## Swaps direction to TO_CLEAR and applies reveal timing.
func _configure_overlay_juice_reveal(juice_node: JuiceControl) -> void:
	if juice_node.recipe == null or juice_node.recipe.effects.is_empty():
		return

	# Access the original effect (recipe.effects is the template — _runtime_effects
	# are clones, but we need to reconfigure the source so a fresh start() picks it up).
	# However, runtime effects are clones — we must modify the clone directly.
	for rt_effect in juice_node._runtime_effects:
		var overlay_effect := rt_effect as ScreenOverlayJuiceEffectBase
		if overlay_effect == null:
			continue

		# Swap direction
		overlay_effect.direction = ScreenOverlayJuiceEffectBase.OverlayDirection.TO_CLEAR

		# Swap timing to reveal
		overlay_effect.duration_in = reveal_duration
		overlay_effect.transition_in = reveal_transition
		overlay_effect.ease_in = reveal_ease
		overlay_effect.custom_curve_in = reveal_curve

	JuiceLogger.log_info(self, "SceneAction",
			"reveal overlay configured (duration=%.2f)" % reveal_duration,
			debug_enabled)


## Creates a JuiceControl + TimeControlJuiceEffect for time manipulation.
func _create_time_juice_node() -> void:
	# Build the effect Resource
	var effect := TimeControlJuiceEffect.new()
	effect.time_mode = time_mode

	match time_mode:
		TimeJuiceEffectBase.TimeMode.FREEZE:
			effect.freeze_frames = time_freeze_frames
		TimeJuiceEffectBase.TimeMode.SLOW_MO:
			effect.target_scale = time_target_scale
			effect.smooth_transition = time_smooth_transition
		TimeJuiceEffectBase.TimeMode.BULLET_TIME:
			effect.target_scale = time_target_scale
			effect.smooth_transition = time_smooth_transition
			effect.exempt_nodes = time_exempt_nodes

	effect.duration_in = cover_duration
	effect.transition_in = cover_transition
	effect.ease_in = cover_ease
	effect.duration_out = reveal_duration
	effect.transition_out = reveal_transition
	effect.ease_out = reveal_ease

	# Build recipe
	var recipe := JuiceControlRecipe.new()
	recipe.effects = [effect]

	# Build dummy Control parent
	_time_dummy_parent = Control.new()
	_time_dummy_parent.name = "_TimeDummyParent"
	_time_dummy_parent.process_mode = Node.PROCESS_MODE_ALWAYS
	_time_dummy_parent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_time_dummy_parent)

	# Build JuiceControl node
	_time_juice_node = JuiceControl.new()
	_time_juice_node.name = "_RuntimeTimeJuice"
	_time_juice_node.process_mode = Node.PROCESS_MODE_ALWAYS
	_time_juice_node.recipe = recipe
	_time_juice_node.trigger_on = JuiceBase.TriggerEvent.MANUAL
	_time_juice_node.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	_time_juice_node.auto_connect_parent = false

	_time_dummy_parent.add_child(_time_juice_node)

	await get_tree().process_frame
	_time_juice_node.animate_in()

	JuiceLogger.log_info(self, "SceneAction",
			"time juice node created (mode=%d)" % time_mode,
			debug_enabled)


# =============================================================================
# ASYNC SCENE LOADING
# =============================================================================

# Kicks off background loading for the next scene so the game doesn't hitch during the transition cover.
func _start_async_load(path: String) -> void:
	if path.is_empty():
		return
	if ResourceLoader.has_cached(path):
		JuiceLogger.log_info(self, "SceneAction",
				"scene already cached: %s" % path, debug_enabled)
		return
	ResourceLoader.load_threaded_request(path)
	JuiceLogger.log_info(self, "SceneAction",
			"async load started: %s" % path, debug_enabled)


# Yields execution until the background loader finishes fetching the scene resource.
func _await_async_load(path: String) -> void:
	if path.is_empty():
		return
	if ResourceLoader.has_cached(path):
		return
	var status := ResourceLoader.load_threaded_get_status(path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_FAILED:
		JuiceLogger.warn(self, "SceneAction",
				"async load FAILED: %s" % path, debug_enabled)
	elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		JuiceLogger.warn(self, "SceneAction",
				"invalid resource: %s" % path, debug_enabled)
	else:
		JuiceLogger.log_info(self, "SceneAction",
				"async load complete: %s" % path, debug_enabled)


# Retrieves the fully loaded scene resource from the background loader cache.
func _get_async_loaded(path: String) -> PackedScene:
	if path.is_empty():
		return null
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		return ResourceLoader.load_threaded_get(path) as PackedScene
	return null


# =============================================================================
# CLEANUP
# =============================================================================

# Tears down the overlay instance, the dynamic Juice node, and unpauses the main game tree.
func _cleanup_overlay() -> void:
	if _time_juice_node != null and is_instance_valid(_time_juice_node):
		_time_juice_node.queue_free()
		_time_juice_node = null
	if _time_dummy_parent != null and is_instance_valid(_time_dummy_parent):
		_time_dummy_parent.queue_free()
		_time_dummy_parent = null
	_cleanup_transition_resources()
	if is_instance_valid(_active_overlay_instance):
		_active_overlay_instance.queue_free()
		_active_overlay_instance = null
	if is_instance_valid(_active_canvas_layer):
		_active_canvas_layer.queue_free()
		_active_canvas_layer = null
	if _active_overlay_orchestrator == self:
		_active_overlay_orchestrator = null


# Destroys the transition scene layer once the reveal animation completes.
func _cleanup_transition_resources() -> void:
	if _overlay_juice_node != null and is_instance_valid(_overlay_juice_node):
		_overlay_juice_node.queue_free()
		_overlay_juice_node = null
	if _overlay_dummy_parent != null and is_instance_valid(_overlay_dummy_parent):
		_overlay_dummy_parent.queue_free()
		_overlay_dummy_parent = null
	if is_instance_valid(_transition_scene_instance):
		_transition_scene_instance.queue_free()
		_transition_scene_instance = null
	if is_instance_valid(_transition_canvas):
		_transition_canvas.queue_free()
		_transition_canvas = null


# Final cleanup. Frees the orchestrator node since it is designed as an ephemeral, single-use worker.
func _self_destruct() -> void:
	_cleanup_overlay()
	if _active_orchestrator == self:
		_active_orchestrator = null
	queue_free()


# Safety net: free orphaned removed nodes on destruction.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for key in _removed_nodes.keys():
			var node: Node = _removed_nodes[key] as Node
			if node != null and is_instance_valid(node):
				node.free()
		_removed_nodes.clear()


# =============================================================================
# SIGNAL HELPERS
# =============================================================================

# Signals that the core mutation (scene load/swap) has occurred, but before the reveal animation finishes.
func _emit_action_executed() -> void:
	if action_executed_callback.is_valid():
		action_executed_callback.call()


# Signals the absolute end of the orchestration sequence (after reveal).
func _emit_completed() -> void:
	if completed_callback.is_valid():
		completed_callback.call()
