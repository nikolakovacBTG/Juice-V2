## Scene Management for Designers — handles game flow actions with integrated transitions.
##
## Executes scene switching, overlaying, reloading, and quitting with visual transitions.
## Designed for non-programmers to build complete interactive demos using only the inspector.

# ============================================================================
# WHAT: Executes scene management actions (switch, overlay, reload, quit) with
#       optional visual transitions and time manipulation — all inspector-driven.
# WHY:  Allows artists and designers to build complete game flow without code.
#       Combined with existing Juice components, enables a full interactive demo.
# SYSTEM: Juicing System (addons/Juice_V1/Utilities/)
# SYSTEM: Juice System (addons/Juice_V1/Utilities/)
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
#   SWITCH_SCENE (THIS_SCENE mode):
#     Creates _JuiceTransitionHandler on tree root (survives scene destruction).
#     Handler manages cover → action → reveal → self-destruct.
#   SWITCH_SCENE (SCENE_IN_TREE mode):
#     Swaps a specific scene node in the tree with a new PackedScene instance.
#     Utility survives (main scene persists). Manages transition inline.
#     Use case: persistent HUD with swappable content areas (2D/3D levels).
#   SWITCH_SCENE (FIRST_SCENE_IN_CONTAINER mode):
#     Swaps the first child of a parent container with a new PackedScene instance.
#     Runtime-agnostic: you assign the container, not the child. The child is
#     discovered at trigger time. Use case: persistent-parent architectures where
#     one or more permanent parents hold dynamic scenes (GUI, 2D levels, 3D worlds).
#   OVERLAY_SCENE:
#     Utility survives (no scene change). Manages overlay lifecycle directly.
#     animate_in() = show overlay, animate_out() = hide overlay (toggle-friendly).
#   RELOAD_SCENE / QUIT_GAME:
#     Creates _JuiceTransitionHandler on tree root (survives scene destruction).
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceUtilityMethods.svg")
class_name SceneActionJuiceUtility
extends Node

# Preload the internal handler script (no class_name, so we load it directly)
const _TransitionHandler := preload("res://addons/Juice_V1/Utilities/_JuiceTransitionHandler.gd")


# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when the action starts (before transition).
signal started()
## Emitted when the action completes (after reveal transition).
signal completed()
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

## Where to switch from when action is SWITCH_SCENE.
enum SwitchFrom {
	THIS_SCENE,              ## Replaces the entire current scene tree (full scene change)
	SCENE_IN_TREE,           ## Swaps a specific scene node in the tree with the To scene
	FIRST_SCENE_IN_CONTAINER,## Swaps the first child of a parent container with the To scene
}

## What happens to the old scene after the switch.
## Applies to Scene In Tree and First Scene In Container modes.
enum OldScenePostSwitchAction {
	FREE,            ## Permanently destroys the old scene. Cannot be recovered.
	HIDE,            ## Keeps the old scene in the tree but invisible and paused. Useful for quick tab-switching.
	REMOVE_FROM_TREE,## Detaches the old scene from the tree. The utility holds a reference; the scene can be re-added later.
}


# =============================================================================
# CONFIGURATION — Timing (was inherited from JuiceCompBase in V0)
# =============================================================================

@export_group("Timing")
## Delay before the action triggers after animate_in() is called.
@export_range(0.0, 10.0, 0.01, "suffix:s") var start_delay: float = 0.0

@export_group("Transition Timing")
## Duration of the cover transition (screen hides before action).
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:s") var duration_in: float = 0.4
## Tween transition type for the cover phase.
@export_enum("Linear","Sine","Quint","Quart","Quad","Expo","Elastic","Cubic","Circ","Bounce","Back","Spring") var transition_in: int = Tween.TRANS_QUAD
## Ease type for the cover phase.
@export_enum("Ease In","Ease Out","Ease In Out","Ease Out In") var ease_in: int = Tween.EASE_OUT
## Optional custom curve for cover (overrides transition/ease).
@export var custom_curve_in: Curve = null
## Duration of the reveal transition (screen shows new content).
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:s") var duration_out: float = 0.4
## Tween transition type for the reveal phase.
@export_enum("Linear","Sine","Quint","Quart","Quad","Expo","Elastic","Cubic","Circ","Bounce","Back","Spring") var transition_out: int = Tween.TRANS_QUAD
## Ease type for the reveal phase.
@export_enum("Ease In","Ease Out","Ease In Out","Ease Out In") var ease_out: int = Tween.EASE_IN
## Optional custom curve for reveal (overrides transition/ease).
@export var custom_curve_out: Curve = null

@export_group("Debug")
## Enable debug output to console.
@export var debug_enabled: bool = false

# =============================================================================
# CONFIGURATION — Scene Action group
# =============================================================================

@export_group("Scene Action")

## Which action to perform when this component is triggered.
@export var action: SceneAction = SceneAction.SWITCH_SCENE:
	set(value):
		action = value
		notify_property_list_changed()
		update_configuration_warnings()

## Where to switch from (SWITCH_SCENE only).
## "This Scene" replaces the entire scene tree.
## "Scene In Tree" swaps a specific node, leaving the rest of the scene intact.
## "First Scene In Container" swaps the first child of a parent container (runtime-agnostic).
@export var from: SwitchFrom = SwitchFrom.THIS_SCENE:
	set(value):
		from = value
		notify_property_list_changed()
		update_configuration_warnings()

## Path to the scene node to replace. Drag a node from the Scene panel.
## Only used when From is set to "Scene In Tree".
@export var switch_from: NodePath = NodePath():
	set(value):
		switch_from = value
		update_configuration_warnings()

## The parent node whose first child will be swapped for the To scene.
## Drag a persistent container from the Scene panel.
## Only used when From is set to "First Scene In Container".
@export var container: NodePath = NodePath():
	set(value):
		container = value
		update_configuration_warnings()

## The scene to switch to or overlay. Drag a .tscn file here.
## Used by SWITCH_SCENE and OVERLAY_SCENE actions.
@export var to: PackedScene = null:
	set(value):
		to = value
		update_configuration_warnings()

## What happens to the old scene after the switch.
## Applies to Scene In Tree and First Scene In Container modes.
## FREE = permanently destroyed, cannot be recovered.
## HIDE = stays in tree but invisible and paused — useful for quick tab-switching.
## REMOVE FROM TREE = detached from tree, utility holds reference for re-insertion.
@export var old_scene_post_switch_action: OldScenePostSwitchAction = OldScenePostSwitchAction.FREE


# =============================================================================
# CONFIGURATION — Overlay Behavior group (OVERLAY_SCENE only)
# =============================================================================

@export_group("Overlay Behavior")

## CanvasLayer number for the overlaid scene. Higher = renders on top.
## Default 100 matches JuiceScreenOverlayProvider's layer.
@export var overlay_canvas_layer: int = 100

## Enable time manipulation on the base scene while overlay is active.
## When true, exposes TimeJuiceComp settings (pause, slow-mo, bullet-time).
@export var use_time_effect: bool = false:
	set(value):
		use_time_effect = value
		notify_property_list_changed()

@export_subgroup("Time Effect", "time_")

## Time manipulation mode (mirrors TimeJuiceComp.TimeMode).
@export_enum("Freeze", "Slow Mo", "Bullet Time") var time_mode: int = 0:
	set(value):
		time_mode = value
		notify_property_list_changed()

## Target time scale for SLOW_MO and BULLET_TIME (0.0 = frozen, 1.0 = normal).
@export_range(0.0, 2.0, 0.01) var time_target_scale: float = 0.3

## Whether to smoothly transition to target time scale (SLOW_MO / BULLET_TIME).
@export var time_smooth_transition: bool = true

## Number of frames to freeze (FREEZE mode). At 60fps, 3 frames = 0.05s.
@export var time_freeze_frames: int = 3

## Nodes exempt from time slowdown (BULLET_TIME only).
@export var time_exempt_nodes: Array[NodePath] = []


# =============================================================================
# CONFIGURATION — Transition group
# =============================================================================

@export_group("Transition")

## Visual transition overlay type. NONE = instant cut, SOLID_COLOR/IMAGE use
## ScreenOverlayJuiceComp, SCENE loads a custom animated transition scene.
@export var overlay_type: TransitionOverlay = TransitionOverlay.NONE:
	set(value):
		overlay_type = value
		notify_property_list_changed()
		update_configuration_warnings()

## Overlay color for SOLID_COLOR and IMAGE transitions.
@export var overlay_color: Color = Color.BLACK

## Overlay image/texture for IMAGE transitions.
@export var overlay_image: Texture2D = null

## Blend mode for SOLID_COLOR and IMAGE overlays.
@export_enum("Mix", "Add", "Sub", "Mul", "Premult Alpha") var overlay_blend_mode: int = 0

## Custom animated transition scene for SCENE overlay type.
## The scene should emit "screen_covered" and "transition_finished" signals
## for precise timing control. Without them, fallback timers are used.
@export var transition_scene: PackedScene = null:
	set(value):
		transition_scene = value
		update_configuration_warnings()

## If true, trust the transition scene's signals for timing.
## If false (or if signals are missing), use fallback durations instead.
@export var use_scene_timing: bool = true:
	set(value):
		use_scene_timing = value
		notify_property_list_changed()

## Fallback cover duration when use_scene_timing is off or signals are missing.
@export_range(0.0, 10.0, 0.05, "or_greater") var fallback_cover_duration: float = 0.5

## Fallback reveal duration when use_scene_timing is off or signals are missing.
@export_range(0.0, 10.0, 0.05, "or_greater") var fallback_reveal_duration: float = 0.5


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

## Runtime time comp instance (TimeJuiceComp — unported, stubbed with warning)
var _time_comp: Node = null

## Runtime overlay comp (ScreenOverlayJuiceComp — unported, stubbed with warning)
var _overlay_comp: Node = null

## Is the action currently playing
var _is_playing: bool = false

## Transition scene instance for OVERLAY_SCENE with SCENE overlay type
var _transition_scene_instance: Node = null
var _transition_canvas: CanvasLayer = null

## Coroutine generation counter — incremented on stop() and new triggers.
## Used to abort stale coroutines after awaits.
var _generation: int = 0

## Holds scenes removed via OldScenePostSwitchAction.REMOVE_FROM_TREE, keyed by path.
## These become orphans if the utility is freed — _notification(PREDELETE)
## frees them as a safety net.
var _removed_nodes: Dictionary = {}


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	pass  # V1: self-contained Node, no base class setup needed


# =============================================================================
# PUBLIC API — Sequencer pattern: bypass base class animation loop
# =============================================================================

## Trigger the scene action (or show overlay). Connect to any JuiceBase signal
## or call directly from code. Wire to buttons via Godot signals in the inspector.
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
	started.emit()  # Emitted here — connect game logic to this signal

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

	# Release references to removed scenes (Scene In Tree mode).
	# Note: this does NOT re-add or free them — they become truly orphaned.
	# A full scene manager would handle re-insertion; this utility does not.
	_removed_nodes.clear()



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

## Routes to the correct execution path based on the From setting.
## SCENE_IN_TREE / FIRST_SCENE_IN_CONTAINER: utility survives the swap, manages inline.
## THIS_SCENE (and RELOAD/QUIT): creates handler on root that survives scene death.
func _execute_destructive_action() -> void:
	# Inline swap modes: utility survives, manage transition inline (no handler needed)
	if action == SceneAction.SWITCH_SCENE and (
			from == SwitchFrom.SCENE_IN_TREE or from == SwitchFrom.FIRST_SCENE_IN_CONTAINER):
		await _execute_child_swap()
		return

	if overlay_type == TransitionOverlay.NONE:
		# Instant — no handler needed
		action_executed.emit()
		_perform_direct_action()
		_is_playing = false
		completed.emit()
		return

	# Create handler on tree root
	var handler := _TransitionHandler.new()
	handler.scene_action = action
	handler.target_scene = to
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
			if to == null:
				push_error("[%s] Cannot switch — to scene is null" % name)
				return
			get_tree().change_scene_to_packed(to)
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


# =============================================================================
# INLINE SCENE SWAP (SCENE_IN_TREE / FIRST_SCENE_IN_CONTAINER)
# =============================================================================

## Swap a scene node in the tree with a new scene instance. The utility survives
## because the main scene persists — no handler needed. Manages transition inline,
## reusing the same overlay cover/reveal helpers as OVERLAY_SCENE.
##
## Resolution varies by From mode:
## - SCENE_IN_TREE: switch_from NodePath → exact node to swap
## - FIRST_SCENE_IN_CONTAINER: container NodePath → first child of that parent
func _execute_child_swap() -> void:
	var my_gen := _generation

	# Resolve from_scene based on the From mode
	var from_scene: Node = null

	if from == SwitchFrom.SCENE_IN_TREE:
		from_scene = get_node_or_null(switch_from)
		if from_scene == null:
			push_error("[%s] Cannot swap — switch_from '%s' not found" % [name, switch_from])
			_is_transitioning = false
			_is_playing = false
			completed.emit()
			return

	elif from == SwitchFrom.FIRST_SCENE_IN_CONTAINER:
		var container_node := get_node_or_null(container)
		if container_node == null:
			push_error("[%s] Cannot swap — container '%s' not found" % [name, container])
			_is_transitioning = false
			_is_playing = false
			completed.emit()
			return
		if container_node.get_child_count() == 0:
			push_error("[%s] Cannot swap — container '%s' has no children" % [name, container_node.name])
			_is_transitioning = false
			_is_playing = false
			completed.emit()
			return
		from_scene = container_node.get_child(0)

	# Safety: swapping an ancestor of this utility would destroy us
	if from_scene.is_ancestor_of(self):
		push_error("[%s] Cannot swap — target '%s' is an ancestor of this utility" % [name, from_scene.name])
		_is_transitioning = false
		_is_playing = false
		completed.emit()
		return

	if to == null:
		push_error("[%s] Cannot swap — to scene is null" % name)
		_is_transitioning = false
		_is_playing = false
		completed.emit()
		return

	# Phase 1: Cover transition (hide old content before swapping)
	if overlay_type != TransitionOverlay.NONE:
		await _play_overlay_cover()
		if _generation != my_gen:
			return

	# Phase 2: Capture position in parent before removing old scene
	var parent := from_scene.get_parent()
	var child_index := from_scene.get_index()

	# Phase 3: Handle old scene per old_scene_post_switch_action
	match old_scene_post_switch_action:
		OldScenePostSwitchAction.FREE:
			from_scene.queue_free()
		OldScenePostSwitchAction.HIDE:
			from_scene.visible = false
			from_scene.process_mode = Node.PROCESS_MODE_DISABLED
		OldScenePostSwitchAction.REMOVE_FROM_TREE:
			parent.remove_child(from_scene)
			# Key by node name for container mode (child identity changes each swap)
			var removal_key: NodePath = switch_from if from == SwitchFrom.SCENE_IN_TREE else NodePath(from_scene.name)
			_removed_nodes[removal_key] = from_scene

	# Phase 4: Instance To scene and insert at the same position
	var new_instance := to.instantiate()
	parent.add_child(new_instance)
	parent.move_child(new_instance, child_index)

	if debug_enabled:
		print("[%s] Scene swap: '%s' → '%s' (old_action=%s)" % [
			name, from_scene.name, new_instance.name,
			OldScenePostSwitchAction.keys()[old_scene_post_switch_action]])

	action_executed.emit()

	# Phase 5: Reveal transition (show new content)
	if overlay_type != TransitionOverlay.NONE:
		await _play_overlay_reveal()
		if _generation != my_gen:
			return

	# Phase 6: Cleanup
	_cleanup_transition_resources()
	_is_transitioning = false
	_is_playing = false
	completed.emit()


## Safety net: free any removed scenes when this utility is destroyed.
## Without this, scenes stored via OldScenePostSwitchAction.REMOVE_FROM_TREE would leak.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for key in _removed_nodes.keys():
			var node: Node = _removed_nodes[key] as Node
			if node != null and is_instance_valid(node):
				node.free()
		_removed_nodes.clear()


# =============================================================================
# OVERLAY SCENE (utility survives — toggle-friendly)
# =============================================================================

func _show_overlay() -> void:
	_active_overlay_utility = self

	# Phase 1: Play cover transition (if not NONE)
	if overlay_type != TransitionOverlay.NONE:
		await _play_overlay_cover()

	# Phase 2: Instance target scene on CanvasLayer
	if to == null:
		push_error("[%s] Cannot overlay — to scene is null" % name)
		_is_transitioning = false
		_is_playing = false
		return

	_active_canvas_layer = CanvasLayer.new()
	_active_canvas_layer.layer = overlay_canvas_layer
	_active_canvas_layer.name = "_JuiceOverlayCanvas"
	_active_canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_active_canvas_layer)

	_active_overlay_instance = to.instantiate()
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


# =============================================================================
# OVERLAY TRANSITION HELPERS
# =============================================================================

func _play_overlay_cover() -> void:
	match overlay_type:
		TransitionOverlay.SOLID_COLOR, TransitionOverlay.IMAGE:
			# STUB: ScreenOverlayJuiceComp not yet ported — _create_runtime_overlay_comp returns null
			_overlay_comp = _create_runtime_overlay_comp(0, duration_in, transition_in, ease_in, custom_curve_in)
			if _overlay_comp != null:
				await get_tree().process_frame
				_overlay_comp.animate_in()
				await _overlay_comp.completed

		TransitionOverlay.SCENE:
			await _play_transition_scene_cover()


func _play_overlay_reveal() -> void:
	match overlay_type:
		TransitionOverlay.SOLID_COLOR, TransitionOverlay.IMAGE:
			# STUB: ScreenOverlayJuiceComp not yet ported — skip reveal
			if _overlay_comp != null and is_instance_valid(_overlay_comp):
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
	_direction: int,
	_dur: float,
	_trans: int,
	_ease_type: int,
	_curve: Curve
) -> Node:
	# STUB: ScreenOverlayJuiceComp is not yet ported to V1.
	# SOLID_COLOR and IMAGE transitions will log a warning and do nothing.
	push_warning("[%s] SOLID_COLOR/IMAGE transitions require ScreenOverlayJuiceComp (not yet ported to V1). Transition will be instant." % name)
	return null


func _create_time_comp() -> void:
	# STUB: TimeJuiceComp is not yet ported to V1.
	# Time manipulation during OVERLAY_SCENE will log a warning and be skipped.
	push_warning("[%s] use_time_effect requires TimeJuiceComp (not yet ported to V1). Time effect will be skipped." % name)
	_time_comp = null


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
# CONDITIONAL VISIBILITY (hybrid: @export + _validate_property)
# =============================================================================

func _validate_property(property: Dictionary) -> void:
	# --- Scene Action group ---
	if property.name == &"from":
		if action != SceneAction.SWITCH_SCENE:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	elif property.name == &"switch_from":
		if action != SceneAction.SWITCH_SCENE or from != SwitchFrom.SCENE_IN_TREE:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	elif property.name == &"container":
		if action != SceneAction.SWITCH_SCENE or from != SwitchFrom.FIRST_SCENE_IN_CONTAINER:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	elif property.name == &"to":
		if action != SceneAction.SWITCH_SCENE and action != SceneAction.OVERLAY_SCENE:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	elif property.name == &"old_scene_post_switch_action":
		if action != SceneAction.SWITCH_SCENE or from == SwitchFrom.THIS_SCENE:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# --- Overlay Behavior group (OVERLAY_SCENE only) ---
	elif property.name in [&"overlay_canvas_layer", &"use_time_effect"]:
		if action != SceneAction.OVERLAY_SCENE:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	elif property.name == &"time_mode":
		if action != SceneAction.OVERLAY_SCENE or not use_time_effect:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	elif property.name in [&"time_target_scale", &"time_smooth_transition"]:
		if action != SceneAction.OVERLAY_SCENE or not use_time_effect or time_mode == 0:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	elif property.name == &"time_freeze_frames":
		if action != SceneAction.OVERLAY_SCENE or not use_time_effect or time_mode != 0:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	elif property.name == &"time_exempt_nodes":
		if action != SceneAction.OVERLAY_SCENE or not use_time_effect or time_mode != 2:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# --- Transition group ---
	elif property.name == &"overlay_color":
		if overlay_type != TransitionOverlay.SOLID_COLOR and overlay_type != TransitionOverlay.IMAGE:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	elif property.name == &"overlay_image":
		if overlay_type != TransitionOverlay.IMAGE:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	elif property.name == &"overlay_blend_mode":
		if overlay_type != TransitionOverlay.SOLID_COLOR and overlay_type != TransitionOverlay.IMAGE:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	elif property.name == &"transition_scene":
		if overlay_type != TransitionOverlay.SCENE:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	elif property.name == &"use_scene_timing":
		if overlay_type != TransitionOverlay.SCENE:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	elif property.name in [&"fallback_cover_duration", &"fallback_reveal_duration"]:
		if overlay_type != TransitionOverlay.SCENE or use_scene_timing:
			property.usage = PROPERTY_USAGE_NO_EDITOR


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	# To scene required for SWITCH and OVERLAY actions
	if (action == SceneAction.SWITCH_SCENE or action == SceneAction.OVERLAY_SCENE) \
			and to == null:
		warnings.append("To scene is not set. No scene will be loaded.")

	# SCENE_IN_TREE mode: switch_from must be set
	if action == SceneAction.SWITCH_SCENE and from == SwitchFrom.SCENE_IN_TREE:
		if switch_from.is_empty():
			warnings.append("Scene In Tree mode requires Switch From to be set. Drag a node from the Scene panel.")
		else:
			# Check if switch_from is an ancestor of this utility (would destroy us)
			var from_scene := get_node_or_null(switch_from)
			if from_scene != null and from_scene.is_ancestor_of(self):
				warnings.append("Switch From '%s' is an ancestor of this utility. Swapping it would destroy this node." % switch_from)

	# FIRST_SCENE_IN_CONTAINER mode: container must be set
	if action == SceneAction.SWITCH_SCENE and from == SwitchFrom.FIRST_SCENE_IN_CONTAINER:
		if container.is_empty():
			warnings.append("First Scene In Container mode requires Container to be set. Drag a parent node from the Scene panel.")
		else:
			var container_node := get_node_or_null(container)
			if container_node != null and container_node.is_ancestor_of(self):
				warnings.append("Container '%s' is an ancestor of this utility. Swapping its child could destroy this node." % container)

	# Transition scene required for SCENE overlay type
	if overlay_type == TransitionOverlay.SCENE and transition_scene == null:
		warnings.append("overlay_type is SCENE but transition_scene is not set. Will fall back to NONE.")

	return warnings
