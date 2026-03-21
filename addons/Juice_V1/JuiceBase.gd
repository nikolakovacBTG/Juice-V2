## JuiceBase.gd
## ============================================================================
## WHAT: Unified base node that drives JuiceEffectBase resources via a recipe.
## WHY: Replaces per-effect Node architecture with a single node per target.
##      Manages triggers, animation lifecycle, chaining, and looping.
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Know about domain specifics — subclasses (JuiceControl, Juice2D,
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

## What event triggers the animation.
enum TriggerEvent {
	ON_PRESS,          ## 0 - Button down, any collision click, Area body/area entered
	ON_RELEASE,        ## 1 - Button up, any collision click release, Area body/area exited
	ON_HOVER_START,    ## 2 - Mouse entered (any interactive node)
	ON_HOVER_END,      ## 3 - Mouse exited (any interactive node)
	ON_FOCUS,          ## 4 - Focus entered (Control/BaseButton)
	ON_UNFOCUS,        ## 5 - Focus exited (Control/BaseButton)
	ON_SHOW,           ## 6 - Node became visible (CanvasItem)
	ON_HIDE,           ## 7 - Node became hidden (CanvasItem)
	ON_READY,          ## 8 - Plays immediately when _ready() fires
	MANUAL,            ## 9 - Only via play() call or signal - no auto-connect
	ON_LEFT_CLICK,     ## 10 - Left mouse button press on CollisionObject
	ON_RIGHT_CLICK,    ## 11 - Right mouse button press on CollisionObject
	ON_MIDDLE_CLICK,   ## 12 - Middle mouse button press on CollisionObject
	ON_BODY_ENTERED,   ## 13 - Physics body entered Area (momentary trigger)
	ON_BODY_EXITED,    ## 14 - Physics body exited Area (momentary trigger)
	ON_AREA_ENTERED,   ## 15 - Another Area entered this Area (momentary trigger)
	ON_AREA_EXITED,    ## 16 - Another Area exited this Area (momentary trigger)
}

## How to handle re-trigger while playing.
enum RetriggerPolicy {
	RESTART,   ## Stop current, restart from beginning
	QUEUE,     ## Queue trigger, execute when current finishes
	IGNORE,    ## Ignore re-trigger while playing
}

## Where trigger signals come from.
enum TriggerSource {
	PARENT,  ## Parent node is the signal source (default).
	NODE,    ## A specific node referenced by trigger_source_path.
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

## Where trigger signals come from: PARENT uses the parent node, NODE uses a
## specific node referenced by trigger_source_path.
@export var trigger_source: TriggerSource = TriggerSource.PARENT:
	set(value):
		trigger_source = value
		notify_property_list_changed()

## If true, automatically connect to parent's signals based on its type.
@export var auto_connect_parent: bool = true

## Path to the node that provides trigger signals.
@export var trigger_source_path: NodePath

## What event triggers the animation. Options are filtered per domain.
@export var trigger_on: TriggerEvent = TriggerEvent.ON_READY:
	set(value):
		trigger_on = value
		notify_property_list_changed()

## Signal name to connect to on the source node (only for MANUAL trigger).
@export var manual_trigger_signal: String

## How the trigger maps to animation direction (default for all effects in recipe).
## Changing this in the editor also updates all effects in the recipe to match.
@export var trigger_behaviour: JuiceEffectBase.TriggerBehaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY:
	set(value):
		trigger_behaviour = value
		# In editor: squash all recipe effects to match the node's setting.
		# Effects can still be individually tweaked afterwards.
		if Engine.is_editor_hint() and recipe != null:
			for effect in recipe.effects:
				if effect != null:
					effect.trigger_behaviour = value

## Delay before the entire recipe starts after trigger (seconds).
@export var start_delay: float = 0.0

## How to handle re-triggers while playing.
@export var retrigger_policy: RetriggerPolicy = RetriggerPolicy.RESTART

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
	# --- Trigger group: inline conditional display ---
	# auto_connect_parent only relevant when source is PARENT
	if property.name == "auto_connect_parent" and trigger_source != TriggerSource.PARENT:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	# trigger_source_path only relevant when source is NODE
	if property.name == "trigger_source_path" and trigger_source != TriggerSource.NODE:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	# manual_trigger_signal only relevant when trigger_on is MANUAL
	if property.name == "manual_trigger_signal" and trigger_on != TriggerEvent.MANUAL:
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

## Target node — what effects animate (resolved at _ready).
var _target_node: Node = null

## Trigger source node — where signals come from (may differ from target).
var _trigger_source_node: Node = null

## Current toggle state for TOGGLE behaviour.
var _toggle_state: bool = false

## Whether any effects are currently playing.
var _is_playing: bool = false

## Current recipe iteration count.
var _current_iteration: int = 0

## Node-level start_delay tracking (delays entire recipe after trigger).
var _in_node_start_delay: bool = false
var _node_delay_elapsed: float = 0.0
var _pending_play_in: bool = true

## Iteration delay tracking.
var _in_loop_delay: bool = false
var _loop_delay_elapsed: float = 0.0

## Queued trigger for RetriggerPolicy.QUEUE
var _queued_trigger: Dictionary = {}

# =============================================================================
# LIFECYCLE
# =============================================================================

func _notification(what: int) -> void:
	# Forward EDITOR_PRE_SAVE to effects so they can bake editor caches
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		for effect in _runtime_effects:
			if effect != null and _target_node != null:
				effect._on_editor_pre_save(_target_node)


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return

	# Resolve target (what effects animate)
	_target_node = _resolve_target()
	if _target_node == null:
		if debug_enabled:
			push_warning("[%s] No valid target node found" % name)
		return

	# Resolve trigger source (where signals come from)
	match trigger_source:
		TriggerSource.PARENT:
			var parent_node := get_parent()
			_trigger_source_node = parent_node
			# M5: Sibling fallback — if parent isn't a recognized trigger source,
			# scan siblings for exactly one recognized source.
			if parent_node != null and auto_connect_parent \
					and trigger_on != TriggerEvent.MANUAL and trigger_on != TriggerEvent.ON_READY \
					and not _is_recognized_trigger_source(parent_node):
				var sibling_sources: Array[Node] = []
				for sibling in parent_node.get_children():
					if sibling == self:
						continue
					if _is_recognized_trigger_source(sibling):
						sibling_sources.append(sibling)
				if sibling_sources.size() == 1:
					_trigger_source_node = sibling_sources[0]
					if debug_enabled:
						print("[%s] Sibling auto-connect: using '%s' (%s)" % [
							name, _trigger_source_node.name, _trigger_source_node.get_class()])
				elif sibling_sources.size() > 1:
					if debug_enabled:
						var names := PackedStringArray()
						for s in sibling_sources:
							names.append(s.name)
						push_warning("[%s] Multiple sibling trigger sources (%s). Set trigger_source_path." % [
							name, ", ".join(names)])
		TriggerSource.NODE:
			_trigger_source_node = get_node_or_null(trigger_source_path)
			if _trigger_source_node == null and debug_enabled:
				push_warning("[%s] Trigger source node not found: %s" % [name, trigger_source_path])

	# Clone recipe effects for independent state
	_invalidate_runtime_effects()

	# Auto-connect signals based on trigger source and trigger event
	if trigger_on == TriggerEvent.MANUAL:
		# MANUAL: only connect if manual_trigger_signal is specified
		if not manual_trigger_signal.is_empty():
			_connect_manual_signal()
	elif trigger_source == TriggerSource.PARENT and auto_connect_parent:
		_try_auto_connect()
	elif trigger_source == TriggerSource.NODE and _trigger_source_node != null:
		_try_auto_connect()

	# Capture natural state before any effects modify the target
	_capture_base_values()

	# Forward _on_host_ready to all effects (for CaptureAt.READY etc.)
	for effect in _runtime_effects:
		if effect != null:
			effect._on_host_ready(_target_node, self)

	# Handle ON_READY trigger
	if trigger_on == TriggerEvent.ON_READY:
		_handle_trigger({"play_in": true})

	# Default to no processing — but don't kill a trigger that already started above
	if not _is_playing:
		set_process(false)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# --- Node-level start_delay: hold before starting effects ---
	if _in_node_start_delay:
		_node_delay_elapsed += delta
		if _node_delay_elapsed < start_delay:
			# Write base state every frame to beat Container re-sorts
			_post_tick_write()
			return
		_in_node_start_delay = false
		_start_effects(_pending_play_in)
		# Fall through to normal tick if effects started this frame

	# --- Iteration delay ---
	if _in_loop_delay:
		_loop_delay_elapsed += delta
		if _loop_delay_elapsed < loop_delay:
			return
		_in_loop_delay = false
		_start_effects(true)
		return

	# --- Pre-tick: domain-specific external-move detection ---
	_pre_tick()

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

	# --- Post-tick: domain-specific aggregation + write once ---
	_post_tick_write()

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
	# Clean up: undo contributions and stop all effects
	if _target_node != null:
		_temporarily_undo_visual()
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
	_in_node_start_delay = false
	_in_loop_delay = false
	# Write natural state (all effect contributions now cleared)
	_post_tick_write()
	set_process(false)
	if debug_enabled:
		print("[%s] Stopped" % name)


## Stop all effects but keep current visual state.
func stop_and_hold() -> void:
	_in_node_start_delay = false
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

	# Resolve direction from trigger_behaviour FIRST (needed by RESTART crossfade check)
	var resolved_play_in := true
	match trigger_behaviour:
		JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT:
			resolved_play_in = true
		JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY:
			resolved_play_in = true
		JuiceEffectBase.TriggerBehaviour.PLAY_OUT_ONLY:
			resolved_play_in = false
		JuiceEffectBase.TriggerBehaviour.TOGGLE:
			_toggle_state = not _toggle_state
			resolved_play_in = _toggle_state
		JuiceEffectBase.TriggerBehaviour.SET_FROM_SOURCE:
			# SET_FROM_SOURCE doesn't use start — it uses set_external_progress
			return

	var new_target := 1.0 if resolved_play_in else 0.0

	# Retrigger policy
	if _is_playing or _in_node_start_delay:
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
				_in_node_start_delay = false
				# D1+M3: Crossfade on direction switch — capture BEFORE stopping
				for effect in _runtime_effects:
					if effect == null or not effect.is_playing():
						continue
					if effect.crossfade_time > 0.0 and new_target != effect._target_progress:
						effect._is_crossfading = true
						effect._crossfade_elapsed = 0.0
						effect._crossfade_start_progress = effect._animation_progress
				_stop_all_effects_silent()
				# M1: Reset progress to direction origin (not always 0)
				# Effects with active crossfade keep their progress for smooth blend
				for effect in _runtime_effects:
					if effect == null or effect._is_crossfading:
						continue
					if new_target > 0.5:
						effect._animation_progress = 0.0
					else:
						effect._animation_progress = 1.0

	# M2: Already-at-target — spammable effects (RESTART only, even when idle)
	# When an effect sits at the target endpoint (e.g. progress=1.0 after PLAY_IN_ONLY),
	# re-triggering would be a no-op (1.0 → 1.0). Reset to the opposite endpoint so
	# punch/shake-style effects always produce motion on retrigger.
	if retrigger_policy == RetriggerPolicy.RESTART:
		var epsilon := 0.0001
		for effect in _runtime_effects:
			if effect == null or effect._is_crossfading:
				continue
			if absf(effect._animation_progress - new_target) <= epsilon:
				if new_target > 0.5:
					effect._animation_progress = 0.0
				else:
					effect._animation_progress = 1.0

	_current_iteration = 0

	# D2: Interrupt sibling JuiceBase nodes with matching effect identity
	_stop_matching_siblings()

	# Node-level start_delay: delay entire recipe before starting effects
	if start_delay > 0.0:
		_in_node_start_delay = true
		_node_delay_elapsed = 0.0
		_pending_play_in = resolved_play_in
		_is_playing = true
		set_process(true)
		if debug_enabled:
			print("[%s] Node start_delay=%.2f, deferring effects" % [name, start_delay])
	else:
		_start_effects(resolved_play_in)

	if debug_enabled:
		print("[%s] Trigger handled: play_in=%s, behaviour=%s" % [
			name, play_in, JuiceEffectBase.TriggerBehaviour.keys()[trigger_behaviour]])

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

	if play_in:
		animate_in_started.emit()
	else:
		animate_out_started.emit()

	# Find root effects (those not chained from another)
	var root_indices := _get_root_effect_indices()

	# Temporarily undo visuals so effects can capture natural state
	# in their _on_animate_start() callbacks
	_temporarily_undo_visual()

	for idx in root_indices:
		var effect := _runtime_effects[idx]
		if effect == null:
			continue
		effect.start(_target_node, play_in, true, self)
		_active_effect_indices.append(idx)

	# Reapply visuals after effects have captured their From/To references
	_temporarily_reapply_visual()

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
				chained.start(_target_node, play_in, false)
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


## D2: Stop sibling JuiceBase nodes whose effects share an interrupt identity
## with any effect in this node that has interrupt_siblings = true.
## Only called on new triggers (not loop restarts), matching V0's
## `interrupt_siblings and not is_one_shot_return` guard.
func _stop_matching_siblings() -> void:
	# Collect identities from our effects that want sibling interruption
	var my_identities: Array[Variant] = []
	for effect in _runtime_effects:
		if effect != null and effect.interrupt_siblings:
			my_identities.append(effect._get_interrupt_identity())
	if my_identities.is_empty():
		return

	var parent := get_parent()
	if parent == null:
		return

	for sibling in parent.get_children():
		if sibling == self or not (sibling is JuiceBase):
			continue
		var juice_sibling := sibling as JuiceBase
		if not juice_sibling._is_playing:
			continue
		# Check if any sibling effect has a matching identity
		for sib_effect in juice_sibling._runtime_effects:
			if sib_effect == null:
				continue
			var sib_identity: Variant = sib_effect._get_interrupt_identity()
			for my_id in my_identities:
				if typeof(sib_identity) == typeof(my_id) and sib_identity == my_id:
					juice_sibling.stop_and_hold()
					if debug_enabled:
						print("[%s] Interrupted sibling '%s'" % [name, sibling.name])
					break


func _stop_all_effects_silent() -> void:
	for effect in _runtime_effects:
		if effect != null and effect.is_playing():
			effect.stop_and_hold()
	_active_effect_indices.clear()
	_is_playing = false

# =============================================================================
# DOMAIN VIRTUAL HOOKS (Override in JuiceControl, Juice2D, Juice3D)
# =============================================================================

## Capture the target's natural position/rotation/scale before any effects.
## Called once in _ready() after target is resolved.
func _capture_base_values() -> void:
	pass


## Pre-tick hook: detect external moves (something else changed the target).
## Called once per frame BEFORE effects are ticked.
func _pre_tick() -> void:
	pass


## Post-tick hook: aggregate all effect deltas and write to target ONCE.
## Called once per frame AFTER all effects have been ticked.
## Also called by stop() to write natural state after contributions are cleared.
func _post_tick_write() -> void:
	pass


## Subtract all current contributions from target, restoring natural state.
## Used before effects capture From/To references and before editor save.
func _temporarily_undo_visual() -> void:
	pass


## Re-add all current contributions to target after temporary undo.
func _temporarily_reapply_visual() -> void:
	pass

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

	# M6: Warn about ambiguous sibling trigger sources
	if auto_connect_parent and trigger_source == TriggerSource.PARENT \
			and trigger_on != TriggerEvent.MANUAL and trigger_on != TriggerEvent.ON_READY:
		var parent_node := get_parent()
		if parent_node and not _is_recognized_trigger_source(parent_node):
			var sibling_sources: Array[Node] = []
			for sibling in parent_node.get_children():
				if sibling == self:
					continue
				if _is_recognized_trigger_source(sibling):
					sibling_sources.append(sibling)
			if sibling_sources.size() > 1:
				var names := PackedStringArray()
				for s in sibling_sources:
					names.append("%s (%s)" % [s.name, s.get_class()])
				warnings.append(
					"Multiple sibling trigger sources found: %s. " % ", ".join(names)
					+ "Auto-connect cannot determine which one to use. "
					+ "Set trigger_source to NODE and specify trigger_source_path.")

	return warnings

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
	if trigger_on == TriggerEvent.ON_READY:
		return  # ON_READY handled in _ready()

	if _trigger_source_node == null:
		return

	# Visibility triggers (work on CanvasItem and Node3D — both have visibility_changed)
	if trigger_on in [TriggerEvent.ON_SHOW, TriggerEvent.ON_HIDE]:
		_connect_visibility_signals(_trigger_source_node)
		return

	# Subclasses handle domain-specific signal connection
	_auto_connect_domain_signals()


## Override in subclasses to connect domain-specific signals (Button, Area3D, etc.)
func _auto_connect_domain_signals() -> void:
	pass  # JuiceControl, Juice2D, Juice3D implement


## M5: Check if a node is a recognized trigger source for this domain.
## Override in subclasses. Base returns false (unknown domain).
func _is_recognized_trigger_source(node: Node) -> bool:
	# Visibility triggers work on any CanvasItem or Node3D
	if trigger_on in [TriggerEvent.ON_SHOW, TriggerEvent.ON_HIDE]:
		return node is CanvasItem or node is Node3D
	return false  # Subclasses override for domain-specific types


## Connect visibility_changed signal. Works for both CanvasItem and Node3D.
func _connect_visibility_signals(node: Node) -> void:
	if node.has_signal("visibility_changed"):
		if not node.is_connected("visibility_changed", _on_visibility_changed):
			node.connect("visibility_changed", _on_visibility_changed)


func _connect_manual_signal() -> void:
	var source: Node
	match trigger_source:
		TriggerSource.PARENT:
			source = get_parent()
		TriggerSource.NODE:
			source = get_node_or_null(trigger_source_path)
	if source == null:
		if debug_enabled:
			push_warning("[%s] Manual trigger source not found" % name)
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
		JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT:
			_handle_trigger({"play_in": is_on})
		JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY:
			if is_on: _handle_trigger({"play_in": true})
		JuiceEffectBase.TriggerBehaviour.PLAY_OUT_ONLY:
			if not is_on: _handle_trigger({"play_in": false})
		JuiceEffectBase.TriggerBehaviour.TOGGLE:
			_handle_trigger({"play_in": is_on})
		_:
			_handle_trigger({"play_in": is_on})


func _on_visibility_changed() -> void:
	var is_now_visible := false
	if _trigger_source_node is CanvasItem:
		is_now_visible = (_trigger_source_node as CanvasItem).is_visible()
	elif _trigger_source_node is Node3D:
		is_now_visible = (_trigger_source_node as Node3D).is_visible()
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

## Filtered mouse button callback for Control gui_input (left/right/middle click).
func _on_control_gui_input_filtered(event: InputEvent) -> void:
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

func _on_animation_finished(_anim_name: StringName) -> void:
	_on_trigger_momentary()

