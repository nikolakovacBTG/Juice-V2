## JuiceBase.gd
## ============================================================================
## WHAT: Unified base node that drives JuiceEffectBase resources via a recipe.
## WHY: Replaces per-effect Node architecture with a single node per target.
##      Manages triggers, animation lifecycle, chaining, and looping.
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Know about domain specifics — subclasses (ControlJuice, Juice2D,
##           Juice3D) handle target type validation and domain auto-connect.
## ============================================================================
##
## MODES:
## - STACK: All effects target the parent node. Delta-first stacking.
##          Multiple Juice nodes on the same parent are allowed.
## - SEQUENCER: Effects target an array of NodePaths. Stagger, target order.
##              (Implemented in Phase 5)
##
## TRIGGER FLOW:
## 1. Signal/event fires → _on_trigger_momentary() or _on_trigger_polarity()
## 2. _handle_trigger() dispatches based on trigger_behaviour
## 3. _start_effects() clones recipe, starts root effects
## 4. _process() ticks active effects each frame
## 5. On TickResult.COMPLETED → follow chain_to, handle loops
## ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase.svg")
class_name JuiceBase
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when all effects in the recipe have completed.
signal completed

## Emitted when animate_in starts.
signal animate_in_started

## Emitted when animate_out starts.
signal animate_out_started

# =============================================================================
# ENUMS
# =============================================================================

## Operating mode for this node.
enum Mode {
	STACK,      ## All effects target the parent. Delta-first stacking.
	SEQUENCER   ## Effects target NodePath array. Stagger + target order. (Phase 5)
}

## How triggers map to animation direction.
enum TriggerBehaviour {
	PLAY_IN_AND_OUT,  ## Trigger → animate in, then auto-reverse to out
	PLAY_IN_ONLY,     ## Trigger → animate in only (hold at peak)
	PLAY_OUT_ONLY,    ## Trigger → animate out only (start from peak)
	TOGGLE,           ## Trigger alternates between in and out
	SET_FROM_SOURCE,  ## External progress source controls direction
}

## What event triggers the animation.
enum TriggerEvent {
	MANUAL,           ## No auto-trigger — call animate_in()/animate_out() from code
	ON_READY,         ## Trigger on _ready()
	ON_PRESS,         ## Mouse press or body/area entered
	ON_RELEASE,       ## Mouse release or body/area exited
	ON_HOVER_START,   ## Mouse entered
	ON_HOVER_END,     ## Mouse exited
	ON_FOCUS,         ## Focus entered
	ON_UNFOCUS,       ## Focus exited
	ON_LEFT_CLICK,    ## Left mouse button
	ON_RIGHT_CLICK,   ## Right mouse button
	ON_MIDDLE_CLICK,  ## Middle mouse button
	ON_BODY_ENTERED,  ## Area body entered
	ON_BODY_EXITED,   ## Area body exited
	ON_AREA_ENTERED,  ## Area area entered
	ON_AREA_EXITED,   ## Area area exited
	ON_SHOW,          ## Target became visible
	ON_HIDE,          ## Target became hidden
	ON_SIGNAL,        ## Custom signal name
}

## How to handle re-trigger while playing.
enum RetriggerPolicy {
	RESTART,   ## Stop current, restart from beginning
	QUEUE,     ## Queue trigger, execute when current finishes
	IGNORE,    ## Ignore re-trigger while playing
}

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Mode")

## Operating mode: STACK (effects on parent) or SEQUENCER (effects on targets).
@export var mode: Mode = Mode.STACK:
	set(value):
		mode = value
		notify_property_list_changed()

@export_group("Trigger")

## What event triggers the animation.
@export var trigger_on: TriggerEvent = TriggerEvent.MANUAL:
	set(value):
		trigger_on = value
		notify_property_list_changed()

## How the trigger maps to animation direction.
@export var trigger_behaviour: TriggerBehaviour = TriggerBehaviour.PLAY_IN_AND_OUT

## Auto-connect to parent's signals based on trigger_on.
@export var auto_connect: bool = true

## How to handle re-triggers while playing.
@export var retrigger_policy: RetriggerPolicy = RetriggerPolicy.RESTART

## Delay before animation starts after trigger (seconds).
@export var start_delay: float = 0.0

## Path to trigger source node (empty = parent).
@export var trigger_source_path: NodePath

## Signal name for ON_SIGNAL trigger.
@export var manual_trigger_signal: String

@export_group("Loop")

## Number of times to repeat the full recipe (-1 = infinite, 1 = no loop).
@export_range(-1, 999) var loop_count: int = 1:
	set(value):
		loop_count = value
		notify_property_list_changed()

## Delay between recipe iterations.
@export var loop_delay: float = 0.0

@export_group("Recipe")

## The recipe containing effects to play.
@export var recipe: JuiceRecipe:
	set(value):
		recipe = value
		_invalidate_runtime_effects()

@export_group("Debug")

## Print debug information to console.
@export var debug_enabled: bool = false

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _validate_property(property: Dictionary) -> void:
	# --- Trigger group ---
	# Hide manual_trigger_signal unless ON_SIGNAL
	if property.name == "manual_trigger_signal" and trigger_on != TriggerEvent.ON_SIGNAL:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	# Hide trigger_source_path unless ON_SIGNAL
	if property.name == "trigger_source_path" and trigger_on != TriggerEvent.ON_SIGNAL:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	# --- Loop group ---
	# Hide loop_delay when not looping
	if property.name == "loop_delay" and loop_count == 1:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	# --- Mode-specific: SEQUENCER settings hidden in STACK mode ---
	# (Sequencer-specific exports will be added in Phase 5.
	#  For now this serves as the pattern for future settings.)

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Runtime-cloned effects from the recipe (independent state per node).
var _runtime_effects: Array[JuiceEffectBase] = []

## Which effects are currently active (being ticked).
var _active_effect_indices: Array[int] = []

## Target node (resolved at _ready or start).
var _target_node: Node = null

## Current toggle state for TOGGLE behaviour.
var _toggle_state: bool = false

## Whether any effects are currently playing.
var _is_playing: bool = false

## Current recipe iteration count.
var _current_iteration: int = 0

## Iteration delay tracking.
var _in_loop_delay: bool = false
var _loop_delay_elapsed: float = 0.0

## Queued trigger for RetriggerPolicy.QUEUE
var _queued_trigger: Dictionary = {}

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return

	# Resolve target
	_target_node = _resolve_target()
	if _target_node == null:
		if debug_enabled:
			push_warning("[%s] No valid target node found" % name)
		return

	# Clone recipe effects for independent state
	_invalidate_runtime_effects()

	# Auto-connect signals
	if auto_connect and trigger_on != TriggerEvent.MANUAL:
		_try_auto_connect()

	# Handle ON_READY trigger
	if trigger_on == TriggerEvent.ON_READY:
		_handle_trigger({"play_in": true})

	set_process(false)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# --- Iteration delay ---
	if _in_loop_delay:
		_loop_delay_elapsed += delta
		if _loop_delay_elapsed < loop_delay:
			return
		_in_loop_delay = false
		_start_effects(true)
		return

	# --- Tick active effects ---
	var all_done := true
	var newly_completed: Array[int] = []

	for idx in _active_effect_indices:
		if idx < 0 or idx >= _runtime_effects.size():
			continue
		var effect := _runtime_effects[idx]
		if effect == null or not effect.is_playing():
			continue

		all_done = false
		var result := effect.tick(delta, _target_node)

		if result == JuiceEffectBase.TickResult.COMPLETED:
			newly_completed.append(idx)

	# --- Handle completions (chaining) ---
	for idx in newly_completed:
		_on_effect_completed(idx)

	# --- Check if ALL effects are done ---
	if all_done and not newly_completed.is_empty():
		_on_all_effects_completed()
	elif all_done and _active_effect_indices.is_empty():
		_on_all_effects_completed()

	# Re-check: are ALL effects truly done?
	var any_playing := false
	for idx in _active_effect_indices:
		if idx >= 0 and idx < _runtime_effects.size():
			var eff := _runtime_effects[idx]
			if eff != null and eff.is_playing():
				any_playing = true
				break

	if not any_playing and not _in_loop_delay:
		_on_all_effects_completed()


func _exit_tree() -> void:
	# Clean up: stop all effects and restore natural state
	if _target_node != null:
		for effect in _runtime_effects:
			if effect != null and effect.is_playing():
				effect.stop(_target_node)
	_active_effect_indices.clear()
	set_process(false)

# =============================================================================
# PUBLIC API
# =============================================================================

## Trigger animate_in on all root effects in the recipe.
func animate_in() -> void:
	_handle_trigger({"play_in": true})


## Trigger animate_out on all root effects in the recipe.
func animate_out(is_one_shot_return: bool = false) -> void:
	_handle_trigger({"play_in": false, "is_one_shot_return": is_one_shot_return})


## Stop all effects and restore to natural state.
func stop() -> void:
	for effect in _runtime_effects:
		if effect != null:
			effect.stop(_target_node)
	_active_effect_indices.clear()
	_is_playing = false
	_in_loop_delay = false
	set_process(false)
	if debug_enabled:
		print("[%s] Stopped" % name)


## Stop all effects but keep current visual state.
func stop_and_hold() -> void:
	for effect in _runtime_effects:
		if effect != null:
			effect.stop_and_hold()
	_active_effect_indices.clear()
	_is_playing = false
	_in_loop_delay = false
	set_process(false)


## Toggle between animate_in and animate_out.
func toggle() -> void:
	_toggle_state = not _toggle_state
	if _toggle_state:
		animate_in()
	else:
		animate_out()


## Set external progress on all effects (for SET_FROM_SOURCE).
func set_external_progress(value: float) -> void:
	for effect in _runtime_effects:
		if effect != null:
			effect.set_progress(value, _target_node)

# =============================================================================
# TRIGGER HANDLING
# =============================================================================

func _handle_trigger(trigger_info: Dictionary) -> void:
	var play_in: bool = trigger_info.get("play_in", true)

	# Retrigger policy
	if _is_playing:
		match retrigger_policy:
			RetriggerPolicy.IGNORE:
				if debug_enabled:
					print("[%s] Trigger ignored (playing)" % name)
				return
			RetriggerPolicy.QUEUE:
				_queued_trigger = trigger_info
				if debug_enabled:
					print("[%s] Trigger queued" % name)
				return
			RetriggerPolicy.RESTART:
				_stop_all_effects_silent()

	match trigger_behaviour:
		TriggerBehaviour.PLAY_IN_AND_OUT:
			_start_effects(true)
		TriggerBehaviour.PLAY_IN_ONLY:
			_start_effects(true)
		TriggerBehaviour.PLAY_OUT_ONLY:
			_start_effects(false)
		TriggerBehaviour.TOGGLE:
			_toggle_state = not _toggle_state
			_start_effects(_toggle_state)
		TriggerBehaviour.SET_FROM_SOURCE:
			# SET_FROM_SOURCE doesn't use start — it uses set_external_progress
			pass

	if debug_enabled:
		print("[%s] Trigger handled: play_in=%s, behaviour=%s" % [
			name, play_in, TriggerBehaviour.keys()[trigger_behaviour]])

# =============================================================================
# CORE LOGIC
# =============================================================================

func _start_effects(play_in: bool) -> void:
	if recipe == null or _runtime_effects.is_empty():
		if debug_enabled:
			push_warning("[%s] No recipe or effects to play" % name)
		return

	if _target_node == null:
		_target_node = _resolve_target()
		if _target_node == null:
			return

	_is_playing = true
	_active_effect_indices.clear()
	_current_iteration = 0

	if play_in:
		animate_in_started.emit()
	else:
		animate_out_started.emit()

	# Find root effects (those not chained from another)
	var root_indices := _get_root_effect_indices()

	for idx in root_indices:
		var effect := _runtime_effects[idx]
		if effect == null:
			continue
		effect.start(_target_node, play_in, start_delay)
		_active_effect_indices.append(idx)

	set_process(true)

	if debug_enabled:
		print("[%s] Started %d root effects (play_in=%s)" % [
			name, root_indices.size(), play_in])


func _on_effect_completed(idx: int) -> void:
	if idx < 0 or idx >= _runtime_effects.size():
		return

	var effect := _runtime_effects[idx]
	if effect == null:
		return

	if debug_enabled:
		print("[%s] Effect %d completed" % [name, idx])

	# Follow chain_to
	if effect.chain_to != null:
		var chain_idx := _runtime_effects.find(effect.chain_to)
		if chain_idx >= 0:
			var chained := _runtime_effects[chain_idx]
			if chained != null:
				# Determine direction: chained effect inherits the direction
				# For now, use the same direction as the trigger
				var play_in := effect._animation_progress >= 0.5
				chained.start(_target_node, play_in, 0.0)
				if chain_idx not in _active_effect_indices:
					_active_effect_indices.append(chain_idx)
				if debug_enabled:
					print("[%s] Chained to effect %d" % [name, chain_idx])


func _on_all_effects_completed() -> void:
	_is_playing = false
	set_process(false)

	_current_iteration += 1

	# Check recipe-level looping
	var should_loop := false
	if loop_count < 0:
		should_loop = true
	elif _current_iteration < loop_count:
		should_loop = true

	if should_loop:
		if loop_delay > 0.0:
			_in_loop_delay = true
			_loop_delay_elapsed = 0.0
			_is_playing = true
			set_process(true)
		else:
			_start_effects(true)
		return

	completed.emit()

	if debug_enabled:
		print("[%s] All effects completed (iterations=%d)" % [name, _current_iteration])

	# Execute queued trigger
	if not _queued_trigger.is_empty():
		var queued := _queued_trigger
		_queued_trigger = {}
		_handle_trigger(queued)


func _stop_all_effects_silent() -> void:
	for effect in _runtime_effects:
		if effect != null and effect.is_playing():
			effect.stop_and_hold()
	_active_effect_indices.clear()
	_is_playing = false

# =============================================================================
# HELPERS
# =============================================================================

## Resolve the target node based on mode.
## Subclasses override to validate domain (Control, Node2D, Node3D).
func _resolve_target() -> Node:
	if mode == Mode.STACK:
		return get_parent()
	return null  # SEQUENCER resolves per-target (Phase 5)


## Clone recipe effects for independent runtime state.
func _invalidate_runtime_effects() -> void:
	_runtime_effects.clear()
	_active_effect_indices.clear()
	if recipe != null:
		_runtime_effects = recipe.create_runtime_effects()


## Get indices of root effects (not chained from any other effect).
func _get_root_effect_indices() -> Array[int]:
	var chained_targets: Array[JuiceEffectBase] = []
	for effect in _runtime_effects:
		if effect != null and effect.chain_to != null:
			chained_targets.append(effect.chain_to)

	var roots: Array[int] = []
	for i in _runtime_effects.size():
		if _runtime_effects[i] != null and _runtime_effects[i] not in chained_targets:
			roots.append(i)
	return roots

# =============================================================================
# AUTO-CONNECT (Domain-agnostic base — subclasses extend for domain signals)
# =============================================================================

## Try to auto-connect trigger signals. Subclasses add domain-specific logic.
func _try_auto_connect() -> void:
	if trigger_on == TriggerEvent.ON_SIGNAL:
		_connect_manual_signal()
		return

	if trigger_on == TriggerEvent.ON_READY:
		return  # ON_READY handled in _ready()

	if _target_node == null:
		return

	# Visibility triggers (work on any CanvasItem)
	if trigger_on in [TriggerEvent.ON_SHOW, TriggerEvent.ON_HIDE]:
		if _target_node is CanvasItem:
			_connect_visibility_signals(_target_node as CanvasItem)
		return

	# Subclasses handle domain-specific signal connection
	_auto_connect_domain_signals()


## Override in subclasses to connect domain-specific signals (Button, Area3D, etc.)
func _auto_connect_domain_signals() -> void:
	pass  # ControlJuice, Juice2D, Juice3D implement


func _connect_visibility_signals(canvas_item: CanvasItem) -> void:
	if not canvas_item.visibility_changed.is_connected(_on_visibility_changed):
		canvas_item.visibility_changed.connect(_on_visibility_changed)


func _connect_manual_signal() -> void:
	var source: Node
	if trigger_source_path.is_empty():
		source = get_parent()
	else:
		source = get_node_or_null(trigger_source_path)
	if source == null:
		if debug_enabled:
			push_warning("[%s] Manual trigger source not found: %s" % [name, trigger_source_path])
		return
	if source.has_signal(manual_trigger_signal):
		if not source.is_connected(manual_trigger_signal, _on_trigger_momentary):
			source.connect(manual_trigger_signal, _on_trigger_momentary)

# =============================================================================
# SIGNAL CALLBACKS
# =============================================================================

func _on_trigger_momentary() -> void:
	_handle_trigger({"play_in": true})


func _on_trigger_polarity_on() -> void:
	_on_trigger_polarity(true)


func _on_trigger_polarity_off() -> void:
	_on_trigger_polarity(false)


func _on_trigger_polarity(is_on: bool) -> void:
	match trigger_behaviour:
		TriggerBehaviour.PLAY_IN_AND_OUT:
			_handle_trigger({"play_in": is_on})
		TriggerBehaviour.PLAY_IN_ONLY:
			if is_on: _handle_trigger({"play_in": true})
		TriggerBehaviour.PLAY_OUT_ONLY:
			if not is_on: _handle_trigger({"play_in": false})
		TriggerBehaviour.TOGGLE:
			_handle_trigger({"play_in": is_on})
		_:
			_handle_trigger({"play_in": is_on})


func _on_visibility_changed() -> void:
	var is_now_visible: bool = _target_node.is_visible() if _target_node else false
	match trigger_on:
		TriggerEvent.ON_SHOW:
			_on_trigger_polarity(is_now_visible)
		TriggerEvent.ON_HIDE:
			_on_trigger_polarity(not is_now_visible)


## Callbacks for collision/input events (used by Juice2D, Juice3D subclasses)
func _on_area_body_entered(_body: Node) -> void:
	_on_trigger_momentary()

func _on_area_body_exited(_body: Node) -> void:
	_on_trigger_momentary()

func _on_area_area_entered(_area: Node) -> void:
	_on_trigger_momentary()

func _on_area_area_exited(_area: Node) -> void:
	_on_trigger_momentary()

func _on_collision_input_press_3d(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_trigger_momentary()

func _on_collision_input_release_3d(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and not event.pressed:
		_on_trigger_momentary()

func _on_collision_input_press_2d(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_trigger_momentary()

func _on_collision_input_release_2d(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and not event.pressed:
		_on_trigger_momentary()

func _on_collision_input_filtered_3d(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var mb := event as InputEventMouseButton
	match trigger_on:
		TriggerEvent.ON_LEFT_CLICK:
			if mb.button_index == MOUSE_BUTTON_LEFT: _on_trigger_momentary()
		TriggerEvent.ON_RIGHT_CLICK:
			if mb.button_index == MOUSE_BUTTON_RIGHT: _on_trigger_momentary()
		TriggerEvent.ON_MIDDLE_CLICK:
			if mb.button_index == MOUSE_BUTTON_MIDDLE: _on_trigger_momentary()

func _on_collision_input_filtered_2d(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var mb := event as InputEventMouseButton
	match trigger_on:
		TriggerEvent.ON_LEFT_CLICK:
			if mb.button_index == MOUSE_BUTTON_LEFT: _on_trigger_momentary()
		TriggerEvent.ON_RIGHT_CLICK:
			if mb.button_index == MOUSE_BUTTON_RIGHT: _on_trigger_momentary()
		TriggerEvent.ON_MIDDLE_CLICK:
			if mb.button_index == MOUSE_BUTTON_MIDDLE: _on_trigger_momentary()

func _on_control_gui_input_press(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_trigger_momentary()

func _on_control_gui_input_release(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		_on_trigger_momentary()

func _on_animation_finished(_anim_name: StringName) -> void:
	_on_trigger_momentary()

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if recipe == null:
		warnings.append("No recipe assigned. Add a JuiceRecipe to get started.")
	elif recipe.effects.is_empty():
		warnings.append("Recipe has no effects. Add JuiceEffectBase resources to the recipe.")
	if mode == Mode.STACK and get_parent() == null:
		warnings.append("STACK mode requires a parent node as the target.")
	return warnings
