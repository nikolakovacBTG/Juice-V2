## SceneActionJuiceUtility — Scene Management for Designers
##
## Handles game flow actions (scene switching, overlaying, reloading, quitting)
## with integrated transition effects. Designed for non-programmers to build
## complete interactive demos using only the inspector.
##
## @tutorial(Juice System): https://github.com/user/juice

# ============================================================================
# SCENE ACTION JUICE UTILITY
# ============================================================================
# WHAT: Executes scene management actions (switch, overlay, reload, quit) with
#       optional visual transitions and time manipulation — all inspector-driven.
# WHY:  Allows artists and designers to build complete game flow without code.
#       Combined with existing Juice components, enables a full interactive demo.
# SYSTEM: Juice System (addons/juice/Utility/)
# DOES NOT HANDLE:
#   - Loading progress bars (async loading is internal only)
#   - Per-object time scaling (Godot engine limitation)
#   - Complex overlay shapes/wipes (use SCENE transition for that)
#
# LIFECYCLE:
#   Follows the Sequencer pattern — overrides animate_in()/animate_out()/stop()
#   and bypasses the base class animation loop. The base class is used for:
#   - Trigger infrastructure (auto-connect, signal wiring, _handle_trigger)
#   - Chaining (next_component, completed signal)
#   - Timing values (duration_in/out used as cover/reveal durations)
#   - All inherited groups remain visible and functional
#
# RUNTIME COMP REUSE:
#   - ScreenOverlayJuiceComp: instantiated at runtime for SOLID_COLOR/IMAGE
#     transitions (handler creates it, configures from inspector settings)
#   - TimeJuiceComp: instantiated at runtime for time manipulation during
#     OVERLAY_SCENE (pause, slow-mo, bullet-time)
#   These are NOT new implementations — existing battle-tested comps are reused.
#
# SCENE ACTION PATHS:
#   SWITCH_SCENE / RELOAD_SCENE / QUIT_GAME:
#     Creates _JuiceTransitionHandler on tree root (survives scene destruction).
#     Handler manages cover → action → reveal → self-destruct.
#   OVERLAY_SCENE:
#     Utility survives (no scene change). Manages overlay lifecycle directly.
#     animate_in() = show overlay, animate_out() = hide overlay (toggle-friendly).
# ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceUtilityMethods.svg")
class_name SceneActionJuiceUtility
extends JuiceCompBase

# Preload the internal handler script (no class_name, so we load it directly)
const _TransitionHandler := preload("res://addons/juice/Utility/_JuiceTransitionHandler.gd")


# =============================================================================
# SIGNALS
# =============================================================================

## Emitted at the exact moment the scene action executes (scene changes, quit
## fires, overlay instances). Useful for syncing SFX or analytics.
signal action_executed()


# =============================================================================
# ENUMS
# =============================================================================

## Which scene management action to perform when triggered.
enum SceneAction {
	SWITCH_SCENE,    ## Replace current scene with target (irreversible)
	OVERLAY_SCENE,   ## Add target scene on top of current (reversible, toggle-friendly)
	RELOAD_SCENE,    ## Reload current scene from disk
	QUIT_GAME,       ## Quit the application
}

## Visual transition type played before/after the scene action.
enum TransitionOverlay {
	NONE,            ## Instant cut — no visual transition
	SOLID_COLOR,     ## Fade through solid color (uses ScreenOverlayJuiceComp)
	IMAGE,           ## Fade through image/texture (uses ScreenOverlayJuiceComp)
	SCENE,           ## Custom animated transition scene (user-provided PackedScene)
}


# =============================================================================
# CONFIGURATION — Scene Action group
# =============================================================================

@export_group("Scene Action")

## Which action to perform when this component is triggered.
@export var action: SceneAction = SceneAction.SWITCH_SCENE:
	set(value):
		action = value
		notify_property_list_changed()

## The target scene to switch to or overlay. Drag a .tscn file here.
## Only used for SWITCH_SCENE and OVERLAY_SCENE actions.
var target_scene: PackedScene = null


# =============================================================================
# CONFIGURATION — Overlay Behavior group (OVERLAY_SCENE only)
# =============================================================================

## CanvasLayer number for the overlaid scene. Higher = renders on top.
## Default 100 matches JuiceScreenOverlayProvider's layer.
var overlay_canvas_layer: int = 100

## Enable time manipulation on the base scene while overlay is active.
## When true, exposes TimeJuiceComp settings (pause, slow-mo, bullet-time).
var use_time_effect: bool = false:
	set(value):
		use_time_effect = value
		notify_property_list_changed()

## Time manipulation mode (mirrors TimeJuiceComp.TimeMode).
var time_mode: int = 0:  # TimeJuiceComp.TimeMode.FREEZE
	set(value):
		time_mode = value
		notify_property_list_changed()

## Target time scale for SLOW_MO and BULLET_TIME (0.0 = frozen, 1.0 = normal).
var time_target_scale: float = 0.3

## Whether to smoothly transition to target time scale (SLOW_MO / BULLET_TIME).
var time_smooth_transition: bool = true

## Number of frames to freeze (FREEZE mode). At 60fps, 3 frames = 0.05s.
var time_freeze_frames: int = 3

## Nodes exempt from time slowdown (BULLET_TIME only).
var time_exempt_nodes: Array[NodePath] = []


# =============================================================================
# CONFIGURATION — Transition group
# =============================================================================

## Visual transition overlay type. NONE = instant cut, SOLID_COLOR/IMAGE use
## ScreenOverlayJuiceComp, SCENE loads a custom animated transition scene.
var overlay_type: TransitionOverlay = TransitionOverlay.NONE:
	set(value):
		overlay_type = value
		notify_property_list_changed()

## Overlay color for SOLID_COLOR transitions.
var overlay_color: Color = Color.BLACK

## Overlay image/texture for IMAGE transitions.
var overlay_image: Texture2D = null

## Blend mode for SOLID_COLOR and IMAGE overlays.
var overlay_blend_mode: int = 0  # ScreenOverlayJuiceComp.OverlayBlendMode.MIX

## Custom animated transition scene for SCENE overlay type.
## The scene should emit "screen_covered" and "transition_finished" signals
## for precise timing control. Without them, fallback timers are used.
var transition_scene: PackedScene = null

## If true, trust the transition scene's signals for timing.
## If false (or if signals are missing), use fallback durations instead.
var use_scene_timing: bool = true:
	set(value):
		use_scene_timing = value
		notify_property_list_changed()

## Fallback cover duration when use_scene_timing is off or signals are missing.
var fallback_cover_duration: float = 0.5

## Fallback reveal duration when use_scene_timing is off or signals are missing.
var fallback_reveal_duration: float = 0.5


# =============================================================================
# STATIC STATE
# =============================================================================

## Tracks the most recently activated OVERLAY_SCENE utility for the static
## close API. Allows overlay scenes to close themselves without direct references.
static var _active_overlay_utility: SceneActionJuiceUtility = null


# =============================================================================
# INTERNAL STATE (runtime-only, not saved)
# =============================================================================

## Guard against double-trigger during an active transition
var _is_transitioning: bool = false

## Reference to the currently overlaid scene instance (OVERLAY_SCENE only)
var _active_overlay_instance: Node = null

## The CanvasLayer holding the overlay scene
var _active_canvas_layer: CanvasLayer = null

## Runtime TimeJuiceComp instance for time manipulation (OVERLAY_SCENE only)
var _time_comp: TimeJuiceComp = null

## Runtime ScreenOverlayJuiceComp for OVERLAY_SCENE transitions
var _overlay_comp: ScreenOverlayJuiceComp = null

## Transition scene instance for OVERLAY_SCENE with SCENE overlay type
var _transition_scene_instance: Node = null
var _transition_canvas: CanvasLayer = null

## Coroutine generation counter — incremented on stop() and new triggers.
## Used to abort stale coroutines after awaits.
var _generation: int = 0


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()


# =============================================================================
# PUBLIC API — Sequencer pattern: bypass base class animation loop
# =============================================================================

## Trigger the scene action (or show overlay). Overrides base class to bypass
## the animation loop. The base class trigger infrastructure (_handle_trigger)
## calls this, so all trigger wiring works unchanged.
func animate_in() -> void:
	if Engine.is_editor_hint():
		return

	_generation += 1
	var my_gen := _generation

	# Respect start_delay from base class
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
		if _generation != my_gen:
			return

	# Guard against double-trigger
	if _is_transitioning:
		if debug_enabled:
			print("[%s] Already transitioning — ignoring trigger" % name)
		return

	_is_transitioning = true
	_is_playing = true
	started.emit()

	if debug_enabled:
		print("[%s] animate_in() — action=%s, overlay=%s" % [
			name, SceneAction.keys()[action], TransitionOverlay.keys()[overlay_type]])

	match action:
		SceneAction.SWITCH_SCENE, SceneAction.RELOAD_SCENE, SceneAction.QUIT_GAME:
			_execute_destructive_action()
		SceneAction.OVERLAY_SCENE:
			await _show_overlay()


## Hide the overlay scene (OVERLAY_SCENE only). For irreversible actions
## (SWITCH/RELOAD/QUIT), this is a no-op with a warning.
func animate_out(_is_one_shot: bool = false) -> void:
	if Engine.is_editor_hint():
		return

	if action != SceneAction.OVERLAY_SCENE:
		push_warning("[%s] Cannot animate_out — %s is irreversible" % [
			name, SceneAction.keys()[action]])
		return

	if not _is_transitioning:
		if debug_enabled:
			print("[%s] animate_out() — no active overlay to hide" % name)
		return

	_generation += 1

	if debug_enabled:
		print("[%s] animate_out() — hiding overlay" % name)

	await _hide_overlay()


## Stop immediately. Increments generation to abort pending coroutines.
func stop() -> void:
	_generation += 1
	_is_playing = false
	_is_transitioning = false

	# Clean up any active overlay
	_cleanup_overlay()


## No visual effect — this is a control/flow component.
func _apply_effect(_progress: float) -> void:
	pass


# =============================================================================
# STATIC API — Close overlay from within the overlaid scene
# =============================================================================

## Call this from within an overlay scene (e.g., via CallMethodJuiceUtility on
## a "Resume" or "Close" button) to close the most recent overlay.
## Zero code needed — works entirely from inspector.
static func remove_active_overlay() -> void:
	if _active_overlay_utility != null and is_instance_valid(_active_overlay_utility):
		_active_overlay_utility.animate_out()


# =============================================================================
# DESTRUCTIVE ACTIONS (SWITCH / RELOAD / QUIT)
# =============================================================================

## Creates a _JuiceTransitionHandler on tree root and delegates the full
## transition lifecycle. The handler survives scene destruction.
func _execute_destructive_action() -> void:
	if overlay_type == TransitionOverlay.NONE:
		# Instant — no handler needed
		action_executed.emit()
		_perform_direct_action()
		_is_playing = false
		completed.emit()
		_trigger_next_component()
		return

	# Create handler on tree root
	var handler := _TransitionHandler.new()
	handler.scene_action = action
	handler.target_scene = target_scene
	handler.overlay_type = overlay_type
	handler.overlay_color = overlay_color
	handler.overlay_image = overlay_image
	handler.overlay_blend_mode = overlay_blend_mode
	handler.transition_scene = transition_scene
	handler.use_scene_timing = use_scene_timing
	handler.fallback_cover_duration = fallback_cover_duration
	handler.fallback_reveal_duration = fallback_reveal_duration
	handler.overlay_canvas_layer = overlay_canvas_layer
	handler.debug_enabled = debug_enabled

	# Map Animate In group → cover timing, Animate Out group → reveal timing
	handler.cover_duration = duration_in
	handler.cover_transition = transition_in
	handler.cover_ease = ease_in
	handler.cover_curve = custom_curve_in
	handler.reveal_duration = duration_out
	handler.reveal_transition = transition_out
	handler.reveal_ease = ease_out
	handler.reveal_curve = custom_curve_out

	# Wire callbacks so handler can emit our signals even after scene dies
	handler.action_executed_callback = Callable(self, "_on_handler_action_executed")
	handler.completed_callback = Callable(self, "_on_handler_completed")

	get_tree().root.add_child(handler)

	if debug_enabled:
		print("[%s] Handler created on root — delegating transition" % name)

	# Fire and forget — handler manages its own lifecycle
	handler.execute()


func _perform_direct_action() -> void:
	# Direct scene action for NONE overlay type (no handler)
	match action:
		SceneAction.SWITCH_SCENE:
			if target_scene == null:
				push_error("[%s] Cannot switch — target_scene is null" % name)
				return
			get_tree().change_scene_to_packed(target_scene)
		SceneAction.RELOAD_SCENE:
			get_tree().reload_current_scene()
		SceneAction.QUIT_GAME:
			get_tree().quit()


func _on_handler_action_executed() -> void:
	action_executed.emit()


func _on_handler_completed() -> void:
	_is_playing = false
	_is_transitioning = false
	completed.emit()
	_trigger_next_component()


# =============================================================================
# OVERLAY SCENE (utility survives — toggle-friendly)
# =============================================================================

func _show_overlay() -> void:
	_active_overlay_utility = self

	# Phase 1: Play cover transition (if not NONE)
	if overlay_type != TransitionOverlay.NONE:
		await _play_overlay_cover()

	# Phase 2: Instance target scene on CanvasLayer
	if target_scene == null:
		push_error("[%s] Cannot overlay — target_scene is null" % name)
		_is_transitioning = false
		_is_playing = false
		return

	_active_canvas_layer = CanvasLayer.new()
	_active_canvas_layer.layer = overlay_canvas_layer
	_active_canvas_layer.name = "_JuiceOverlayCanvas"
	_active_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_active_canvas_layer)

	_active_overlay_instance = target_scene.instantiate()
	_active_overlay_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	_active_canvas_layer.add_child(_active_overlay_instance)

	if debug_enabled:
		print("[%s] Overlay scene instanced on CanvasLayer %d" % [name, overlay_canvas_layer])

	# Phase 3: Apply time effect (if enabled)
	if use_time_effect:
		_create_time_comp()

	# Phase 4: Emit action_executed at the moment the overlay is live
	action_executed.emit()

	# Phase 5: Play reveal transition (fade out cover to show overlay scene)
	if overlay_type != TransitionOverlay.NONE:
		await _play_overlay_reveal()

	_is_playing = false
	completed.emit()

	if debug_enabled:
		print("[%s] Overlay show complete" % name)

	_trigger_next_component()

	# Process queued trigger if one was stored by _handle_trigger()
	if not _queued_trigger.is_empty():
		var queued := _queued_trigger
		_queued_trigger = {}
		_handle_trigger(queued)


func _hide_overlay() -> void:
	_is_playing = true
	started.emit()

	# Phase 1: Restore time (if time effect was active)
	if _time_comp != null and is_instance_valid(_time_comp):
		_time_comp.animate_out()
		await _time_comp.completed
		_time_comp.queue_free()
		_time_comp = null

	# Phase 2: Play cover transition (cover the overlay scene before removing it)
	if overlay_type != TransitionOverlay.NONE:
		await _play_overlay_cover()

	# Phase 3: Remove overlay scene
	if is_instance_valid(_active_overlay_instance):
		_active_overlay_instance.queue_free()
		_active_overlay_instance = null
	if is_instance_valid(_active_canvas_layer):
		_active_canvas_layer.queue_free()
		_active_canvas_layer = null

	# Phase 4: Play reveal transition (reveal base scene)
	if overlay_type != TransitionOverlay.NONE:
		await _play_overlay_reveal()

	# Phase 5: Clean up transition resources
	_cleanup_transition_resources()

	_active_overlay_utility = null
	_is_transitioning = false
	_is_playing = false

	completed.emit()

	if debug_enabled:
		print("[%s] Overlay hide complete" % name)

	_trigger_next_component()

	if not _queued_trigger.is_empty():
		var queued := _queued_trigger
		_queued_trigger = {}
		_handle_trigger(queued)


# =============================================================================
# OVERLAY TRANSITION HELPERS
# =============================================================================

func _play_overlay_cover() -> void:
	match overlay_type:
		TransitionOverlay.SOLID_COLOR, TransitionOverlay.IMAGE:
			_overlay_comp = _create_runtime_overlay_comp(
				ScreenOverlayJuiceComp.OverlayDirection.TO_COLOR,
				duration_in, transition_in, ease_in, custom_curve_in)
			# Wait a frame for _ready()
			await get_tree().process_frame
			_overlay_comp.animate_in()
			await _overlay_comp.completed

		TransitionOverlay.SCENE:
			await _play_transition_scene_cover()


func _play_overlay_reveal() -> void:
	match overlay_type:
		TransitionOverlay.SOLID_COLOR, TransitionOverlay.IMAGE:
			if _overlay_comp != null and is_instance_valid(_overlay_comp):
				# Reconfigure for reveal
				_overlay_comp.direction = ScreenOverlayJuiceComp.OverlayDirection.TO_CLEAR
				_overlay_comp.duration_in = duration_out
				_overlay_comp.transition_in = transition_out
				_overlay_comp.ease_in = ease_out
				_overlay_comp.custom_curve_in = custom_curve_out
				_overlay_comp.animate_in()
				await _overlay_comp.completed

		TransitionOverlay.SCENE:
			await _play_transition_scene_reveal()


func _play_transition_scene_cover() -> void:
	if transition_scene == null:
		push_warning("[%s] transition_scene is null — skipping SCENE transition" % name)
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
			push_warning("[%s] Transition scene missing 'screen_covered' signal — using fallback" % name)
		await get_tree().create_timer(fallback_cover_duration, true, false, true).timeout


func _play_transition_scene_reveal() -> void:
	if _transition_scene_instance == null or not is_instance_valid(_transition_scene_instance):
		return

	if use_scene_timing and _transition_scene_instance.has_signal("transition_finished"):
		await _transition_scene_instance.transition_finished
	else:
		if use_scene_timing and not _transition_scene_instance.has_signal("transition_finished"):
			push_warning("[%s] Transition scene missing 'transition_finished' signal — using fallback" % name)
		await get_tree().create_timer(fallback_reveal_duration, true, false, true).timeout

	# Clean up transition scene
	if is_instance_valid(_transition_scene_instance):
		_transition_scene_instance.queue_free()
		_transition_scene_instance = null
	if is_instance_valid(_transition_canvas):
		_transition_canvas.queue_free()
		_transition_canvas = null


# =============================================================================
# RUNTIME COMP CREATION
# =============================================================================

func _create_runtime_overlay_comp(
	direction: int,
	dur: float,
	trans: int,
	ease_type: int,
	curve: Curve
) -> ScreenOverlayJuiceComp:
	var comp := ScreenOverlayJuiceComp.new()
	comp.name = "_RuntimeOverlayComp"
	comp.process_mode = Node.PROCESS_MODE_ALWAYS

	comp.overlay_color = overlay_color
	comp.max_alpha = 1.0
	comp.direction = direction

	if overlay_type == TransitionOverlay.IMAGE and overlay_image != null:
		comp.overlay_texture = overlay_image

	comp.blend_mode = overlay_blend_mode

	comp.duration_in = dur
	comp.transition_in = trans
	comp.ease_in = ease_type
	comp.custom_curve_in = curve

	comp.trigger_behaviour = JuiceCompBase.TriggerBehaviour.PLAY_IN_ONLY
	comp.trigger_on = JuiceCompBase.TriggerEvent.MANUAL
	comp.auto_connect_parent = false

	# Add to tree root so it survives if scene changes (shouldn't for OVERLAY, but safety)
	get_tree().root.add_child(comp)

	if debug_enabled:
		print("[%s] Runtime overlay comp created (direction=%d, duration=%.2f)" % [
			name, direction, dur])

	return comp


func _create_time_comp() -> void:
	_time_comp = TimeJuiceComp.new()
	_time_comp.name = "_RuntimeTimeComp"
	_time_comp.process_mode = Node.PROCESS_MODE_ALWAYS

	# Configure from our inspector settings
	_time_comp.time_mode = time_mode

	# Set conditional properties via property path (they use _set/_get)
	match time_mode:
		0:  # TimeJuiceComp.TimeMode.FREEZE
			_time_comp.set("freeze_frames", time_freeze_frames)
		1:  # TimeJuiceComp.TimeMode.SLOW_MO
			_time_comp.set("target_scale", time_target_scale)
			_time_comp.set("smooth_transition", time_smooth_transition)
		2:  # TimeJuiceComp.TimeMode.BULLET_TIME
			_time_comp.set("target_scale", time_target_scale)
			_time_comp.set("smooth_transition", time_smooth_transition)
			_time_comp.set("exempt_nodes", time_exempt_nodes)

	# Use the utility's Animate In duration for the time effect ramp
	_time_comp.duration_in = duration_in
	_time_comp.transition_in = transition_in
	_time_comp.ease_in = ease_in
	_time_comp.duration_out = duration_out
	_time_comp.transition_out = transition_out
	_time_comp.ease_out = ease_out

	_time_comp.trigger_behaviour = JuiceCompBase.TriggerBehaviour.PLAY_IN_ONLY
	_time_comp.trigger_on = JuiceCompBase.TriggerEvent.MANUAL
	_time_comp.auto_connect_parent = false

	# Add as child of self (we survive for OVERLAY_SCENE)
	add_child(_time_comp)

	# Wait for _ready() to fire
	await get_tree().process_frame
	_time_comp.animate_in()

	if debug_enabled:
		print("[%s] Runtime time comp created (mode=%d)" % [name, time_mode])


# =============================================================================
# CLEANUP
# =============================================================================

func _cleanup_overlay() -> void:
	if _time_comp != null and is_instance_valid(_time_comp):
		_time_comp.queue_free()
		_time_comp = null
	_cleanup_transition_resources()
	if is_instance_valid(_active_overlay_instance):
		_active_overlay_instance.queue_free()
		_active_overlay_instance = null
	if is_instance_valid(_active_canvas_layer):
		_active_canvas_layer.queue_free()
		_active_canvas_layer = null
	if _active_overlay_utility == self:
		_active_overlay_utility = null


func _cleanup_transition_resources() -> void:
	if _overlay_comp != null and is_instance_valid(_overlay_comp):
		_overlay_comp.queue_free()
		_overlay_comp = null
	if is_instance_valid(_transition_scene_instance):
		_transition_scene_instance.queue_free()
		_transition_scene_instance = null
	if is_instance_valid(_transition_canvas):
		_transition_canvas.queue_free()
		_transition_canvas = null


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# --- Scene Action group ---
	# (action is @export, so it's shown automatically)
	# target_scene: only for SWITCH_SCENE and OVERLAY_SCENE
	if action == SceneAction.SWITCH_SCENE or action == SceneAction.OVERLAY_SCENE:
		props.append({
			"name": "target_scene",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "PackedScene",
			"usage": PROPERTY_USAGE_DEFAULT,
		})

	# --- Overlay Behavior group (OVERLAY_SCENE only) ---
	if action == SceneAction.OVERLAY_SCENE:
		props.append({
			"name": "Overlay Behavior",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP,
			"hint_string": "",
		})
		props.append({
			"name": "overlay_canvas_layer",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		props.append({
			"name": "use_time_effect",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
		})

		if use_time_effect:
			props.append({
				"name": "Time Effect",
				"type": TYPE_NIL,
				"usage": PROPERTY_USAGE_SUBGROUP,
				"hint_string": "time_",
			})
			props.append({
				"name": "time_mode",
				"type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Freeze,Slow Mo,Bullet Time",
				"usage": PROPERTY_USAGE_DEFAULT,
			})

			# SLOW_MO and BULLET_TIME share target_scale and smooth_transition
			if time_mode != 0:  # Not FREEZE
				props.append({
					"name": "time_target_scale",
					"type": TYPE_FLOAT,
					"hint": PROPERTY_HINT_RANGE,
					"hint_string": "0.0,2.0,0.01",
					"usage": PROPERTY_USAGE_DEFAULT,
				})
				props.append({
					"name": "time_smooth_transition",
					"type": TYPE_BOOL,
					"usage": PROPERTY_USAGE_DEFAULT,
				})

			# FREEZE only
			if time_mode == 0:
				props.append({
					"name": "time_freeze_frames",
					"type": TYPE_INT,
					"usage": PROPERTY_USAGE_DEFAULT,
				})

			# BULLET_TIME only
			if time_mode == 2:
				props.append({
					"name": "time_exempt_nodes",
					"type": TYPE_ARRAY,
					"hint": PROPERTY_HINT_TYPE_STRING,
					"hint_string": "%d:" % TYPE_NODE_PATH,
					"usage": PROPERTY_USAGE_DEFAULT,
				})

	# --- Transition group ---
	props.append({
		"name": "Transition",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP,
		"hint_string": "",
	})
	props.append({
		"name": "overlay_type",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "None,Solid Color,Image,Scene",
		"usage": PROPERTY_USAGE_DEFAULT,
	})

	# SOLID_COLOR properties
	if overlay_type == TransitionOverlay.SOLID_COLOR:
		props.append({
			"name": "overlay_color",
			"type": TYPE_COLOR,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		props.append({
			"name": "overlay_blend_mode",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Mix,Add,Sub,Mul,Premult Alpha",
			"usage": PROPERTY_USAGE_DEFAULT,
		})

	# IMAGE properties
	if overlay_type == TransitionOverlay.IMAGE:
		props.append({
			"name": "overlay_color",
			"type": TYPE_COLOR,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		props.append({
			"name": "overlay_image",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "Texture2D",
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		props.append({
			"name": "overlay_blend_mode",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Mix,Add,Sub,Mul,Premult Alpha",
			"usage": PROPERTY_USAGE_DEFAULT,
		})

	# SCENE properties
	if overlay_type == TransitionOverlay.SCENE:
		props.append({
			"name": "transition_scene",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "PackedScene",
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		props.append({
			"name": "use_scene_timing",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
		if not use_scene_timing:
			props.append({
				"name": "fallback_cover_duration",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,10.0,0.05,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT,
			})
			props.append({
				"name": "fallback_reveal_duration",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,10.0,0.05,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT,
			})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		# Scene Action
		&"target_scene": target_scene = value; return true
		# Overlay Behavior
		&"overlay_canvas_layer": overlay_canvas_layer = value; return true
		&"use_time_effect": use_time_effect = value; return true
		&"time_mode": time_mode = value; return true
		&"time_target_scale": time_target_scale = value; return true
		&"time_smooth_transition": time_smooth_transition = value; return true
		&"time_freeze_frames": time_freeze_frames = value; return true
		&"time_exempt_nodes": time_exempt_nodes = value; return true
		# Transition
		&"overlay_type": overlay_type = value; return true
		&"overlay_color": overlay_color = value; return true
		&"overlay_image": overlay_image = value; return true
		&"overlay_blend_mode": overlay_blend_mode = value; return true
		&"transition_scene": transition_scene = value; return true
		&"use_scene_timing": use_scene_timing = value; return true
		&"fallback_cover_duration": fallback_cover_duration = value; return true
		&"fallback_reveal_duration": fallback_reveal_duration = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		# Scene Action
		&"target_scene": return target_scene
		# Overlay Behavior
		&"overlay_canvas_layer": return overlay_canvas_layer
		&"use_time_effect": return use_time_effect
		&"time_mode": return time_mode
		&"time_target_scale": return time_target_scale
		&"time_smooth_transition": return time_smooth_transition
		&"time_freeze_frames": return time_freeze_frames
		&"time_exempt_nodes": return time_exempt_nodes
		# Transition
		&"overlay_type": return overlay_type
		&"overlay_color": return overlay_color
		&"overlay_image": return overlay_image
		&"overlay_blend_mode": return overlay_blend_mode
		&"transition_scene": return transition_scene
		&"use_scene_timing": return use_scene_timing
		&"fallback_cover_duration": return fallback_cover_duration
		&"fallback_reveal_duration": return fallback_reveal_duration
	return null


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	# Target scene required for SWITCH and OVERLAY actions
	if (action == SceneAction.SWITCH_SCENE or action == SceneAction.OVERLAY_SCENE) \
			and target_scene == null:
		warnings.append("target_scene is not set. No scene will be loaded.")

	# Transition scene required for SCENE overlay type
	if overlay_type == TransitionOverlay.SCENE and transition_scene == null:
		warnings.append("overlay_type is SCENE but transition_scene is not set. Will fall back to NONE.")

	return warnings
