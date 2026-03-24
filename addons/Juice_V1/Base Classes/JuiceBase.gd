## Base class for all Juice nodes. Use [JuiceControl], [Juice2D], or [Juice3D] instead.
##
## Drives [JuiceEffectBase] resources via a [JuiceRecipe]. Manages triggers,
## animation lifecycle, chaining, looping, and delta-first stacking. Supports
## STACK mode (single target) and SEQUENCER mode (multiple targets with stagger).

# ============================================================================
# WHAT: Unified base node that drives JuiceEffectBase resources via a recipe.
# WHY: Replaces per-effect Node architecture with a single node per target.
#      Manages triggers, animation lifecycle, chaining, and looping.
# SYSTEM: Juicing System (addons/Juice_V1/)
# DOES NOT: Know about domain specifics — subclasses (JuiceControl, Juice2D,
#           Juice3D) handle target type validation and domain auto-connect.
# ============================================================================
#
# MODES:
# - STACK: All effects target the parent node. Delta-first stacking.
#          Multiple Juice nodes on the same parent are allowed.
# - SEQUENCER: Effects target an array of NodePaths. Stagger, target order.
#
# TRIGGER FLOW:
# 1. Signal/event fires → _on_trigger_momentary() or _on_trigger_polarity()
# 2. _handle_trigger() dispatches based on trigger_behaviour
# 3. _start_effects() clones recipe, starts root effects
# 4. _process() ticks active effects each frame
# 5. On TickResult.COMPLETED → follow chain_to, handle loops
# ============================================================================

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
	SEQUENCER   ## Effects target multiple nodes. Stagger + target order.
}

## Where the sequencer sources its animations (SEQUENCER mode only).
enum JuiceSource {
	RECIPE,           ## Apply the node's own recipe to each target
	TARGETS_STACK,    ## Trigger JuiceBase nodes inside a named container on each target
	TARGETS_CHILDREN  ## Trigger JuiceBase children directly on each target
}

## What nodes to animate (SEQUENCER mode only).
enum TargetScope {
	SIBLINGS,  ## Animate siblings of this node (parent's other children)
	CHILDREN,  ## Animate children of parent
	CUSTOM     ## Use a manually authored list of targets
}

## How targets are ordered and timed during the sequence.
enum SequenceType {
	STAGGER_FORWARD,  ## First to last with delay between each
	STAGGER_REVERSE,  ## Last to first with delay between each
	RANDOM,           ## Random order with delay between each
	ALL_AT_ONCE       ## All targets fire simultaneously
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
@export_range(0.0, 100.0, 0.01, "or_greater") var start_delay: float = 0.0

## How to handle re-triggers while playing.
@export var retrigger_policy: RetriggerPolicy = RetriggerPolicy.RESTART

@export_group("Sequencer")

## Where this sequencer sources its animations (SEQUENCER mode only).
@export var juice_source: JuiceSource = JuiceSource.RECIPE:
	set(value):
		juice_source = value
		notify_property_list_changed()

## Which nodes to target for animation (SEQUENCER mode only).
@export var target_scope: TargetScope = TargetScope.SIBLINGS:
	set(value):
		target_scope = value
		notify_property_list_changed()

## Manually authored list of target nodes (visible when target_scope == CUSTOM).
@export var seq_custom_targets: Array[NodePath] = []

## Name of the container node holding juice on each target
## (visible when juice_source == TARGETS_STACK).
@export var seq_stack_name: String = ""

## Order and timing strategy for the sequence.
@export var sequence_type: SequenceType = SequenceType.STAGGER_FORWARD:
	set(value):
		sequence_type = value
		notify_property_list_changed()

## Time delay between targets (stagger delay). Hidden for ALL_AT_ONCE.
@export_range(0.0, 100.0, 0.01, "or_greater") var seq_stagger_delay: float = 0.1

## Mirror the stagger direction when playing the exit animation.
## Example: Stagger Forward on entry → Stagger Reverse on exit.
@export var seq_mirror_stagger_on_exit: bool = true

## Skip targets that are not visible.
@export var seq_skip_invisible: bool = true

## Skip self when targeting siblings (almost always true).
@export var seq_skip_self: bool = true

## Skip targets that are JuiceBase nodes (don't animate our own juice siblings).
@export var seq_skip_juice_nodes: bool = true

## When the exit animation completes, hide the parent node.
@export var seq_hide_parent_on_reverse_complete: bool = false

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
		if Engine.is_editor_hint():
			update_configuration_warnings()

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
	var _seq_props := [
		"juice_source", "target_scope", "seq_custom_targets", "seq_stack_name",
		"sequence_type", "seq_stagger_delay", "seq_mirror_stagger_on_exit",
		"seq_skip_invisible", "seq_skip_self", "seq_skip_juice_nodes",
		"seq_hide_parent_on_reverse_complete",
	]
	if mode == Mode.STACK and property.name in _seq_props:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	# --- Within SEQUENCER mode: conditional visibility ---
	if mode == Mode.SEQUENCER:
		# custom_targets only when target_scope == CUSTOM
		if property.name == "seq_custom_targets" and target_scope != TargetScope.CUSTOM:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		# stack_name only when juice_source == TARGETS_STACK
		if property.name == "seq_stack_name" and juice_source != JuiceSource.TARGETS_STACK:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		# stagger_delay hidden for ALL_AT_ONCE
		if property.name == "seq_stagger_delay" and sequence_type == SequenceType.ALL_AT_ONCE:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		# mirror_stagger_on_exit only for directional stagger types
		if property.name == "seq_mirror_stagger_on_exit" \
				and sequence_type not in [SequenceType.STAGGER_FORWARD, SequenceType.STAGGER_REVERSE]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

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

# --- Sequencer-specific state (SEQUENCER mode only) ---

## Coroutine generation counter. Incremented on stop() and new sequence starts.
## Each coroutine captures its generation at birth; if the global counter has
## advanced past it after an await, the coroutine aborts silently.
var _seq_generation: int = 0

## Number of active animations being tracked for completion in current sequence pass.
var _seq_active_animations: int = 0

## True when currently playing in reverse (exit animation).
var _seq_playing_reverse: bool = false

## The direction of the initial trigger. Used to restart loops from the correct direction.
var _seq_initial_reverse: bool = false

## Non-ping-pong loop counter for sequencer.
var _seq_current_loop: int = 0

## Ping-pong state for sequencer: true = forward leg, false = reverse leg.
var _seq_pp_forward: bool = true

## Counts completed full ping-pong cycles (forward + reverse = 1 cycle).
var _seq_pp_current_cycle: int = 0

## Per-target runtime effect clones for RECIPE mode.
## Keys: target Node, Values: Array[JuiceEffectBase] (cloned effects for that target).
var _seq_target_effects: Dictionary = {}

## Per-target active effect indices (which clones are being ticked).
## Keys: target Node, Values: Array[int] (indices into that target's effects array).
var _seq_target_active_indices: Dictionary = {}

## Held entries for Container hold pattern (RECIPE mode, Control targets).
## Each entry: { "target": Node, "effects": Array[JuiceEffectBase] }
## Effects are continuously re-applied at From state every frame until released.
var _seq_held_entries: Array[Dictionary] = []

## Per-target contribution tracking for Container-safe writes.
## Maps target Node → { "pos": Vector2/3, "rot": float/Vector3, "scale": Vector2/3 }
## Used by domain _seq_post_tick_write_target to compute:
##   natural = current - last_contribution; write = natural + new_delta
var _seq_target_contributions: Dictionary = {}

## Per-target expected values after our last write. Used for external-reset detection.
## Maps target Node → { "property_name": expected_value_after_write }
## If the actual value differs from expected, an external system reset the property
## and our stored contribution is stale — must be cleared before computing natural.
var _seq_expected_after_write: Dictionary = {}

# =============================================================================
# LIFECYCLE
# =============================================================================

func _notification(what: int) -> void:
	# Forward EDITOR_PRE_SAVE to effects so they can bake editor caches
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		# In editor, _runtime_effects is empty (_ready returns early).
		# Use recipe.effects directly for editor cache baking.
		var target := _target_node
		if target == null:
			target = _resolve_target()
		if target == null or recipe == null:
			return
		for effect in recipe.effects:
			if effect != null:
				effect._on_editor_pre_save(target)


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return

	# Resolve target (what effects animate)
	# STACK: single parent target. SEQUENCER: null here (targets resolved per-sequence).
	_target_node = _resolve_target()
	if _target_node == null and mode == Mode.STACK:
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

	# Capture natural state before any effects modify the target (STACK only)
	if _target_node != null:
		_capture_base_values()

	# Forward _on_host_ready to all effects (for CaptureAt.READY etc.) — STACK only
	if _target_node != null:
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

	# --- SEQUENCER mode: tick per-target effects ---
	if mode == Mode.SEQUENCER:
		_seq_process_tick(delta)
		return

	# --- STACK mode below ---

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

	# --- Two-phase tick: non-reactive first, then reactive ---
	var all_done := true
	var newly_completed: Array[int] = []
	var has_reactive := false

	# Phase 1: Tick non-reactive effects
	for idx in _active_effect_indices:
		if idx < 0 or idx >= _runtime_effects.size():
			continue
		var effect := _runtime_effects[idx]
		if effect == null or not effect.is_playing():
			continue
		if effect._is_reactive():
			has_reactive = true
			all_done = false
			continue

		all_done = false
		var result := effect.tick(delta, _target_node)
		if result == JuiceEffectBase.TickResult.COMPLETED:
			newly_completed.append(idx)

	# Mid-phase: Notify reactive effects of sibling delta changes
	if has_reactive:
		_compute_sibling_displacement()

	# Phase 2: Tick reactive effects
	if has_reactive:
		for idx in _active_effect_indices:
			if idx < 0 or idx >= _runtime_effects.size():
				continue
			var effect := _runtime_effects[idx]
			if effect == null or not effect.is_playing():
				continue
			if not effect._is_reactive():
				continue
			var result := effect.tick(delta, _target_node)
			if result == JuiceEffectBase.TickResult.COMPLETED:
				newly_completed.append(idx)

	# --- Chained preroll: start chained effects early for overlap ---
	for idx in _active_effect_indices:
		if idx < 0 or idx >= _runtime_effects.size():
			continue
		var effect := _runtime_effects[idx]
		if effect == null or not effect.is_playing():
			continue
		if effect.chain_to == null or effect.chained_preroll <= 0.0:
			continue
		if effect._chained_preroll_triggered:
			continue
		if effect._get_time_to_completion() <= effect.chained_preroll:
			var chain_idx := _runtime_effects.find(effect.chain_to)
			if chain_idx >= 0:
				var chained := _runtime_effects[chain_idx]
				if chained != null:
					var play_in := effect._animation_progress >= 0.5
					chained.start(_target_node, play_in, false, self)
					if chain_idx not in _active_effect_indices:
						_active_effect_indices.append(chain_idx)
					effect._chained_preroll_triggered = true
					if debug_enabled:
						print("[%s] Chained preroll: effect %d → %d (%.2fs early)" % [
							name, idx, chain_idx, effect.chained_preroll])

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
	if mode == Mode.SEQUENCER:
		_seq_stop()
		return
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

	# --- SEQUENCER mode: delegate to sequencer flow ---
	if mode == Mode.SEQUENCER:
		var is_reverse := not resolved_play_in
		var is_one_shot_return: bool = trigger_info.get("is_one_shot_return", false)
		_seq_request_sequence(is_reverse, is_one_shot_return)
		return

	# --- STACK mode below ---

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

	# Always start effects immediately (FFR applies From delta)
	_start_effects(resolved_play_in)

	# Node-level start_delay: hold at From state before ticking effects
	if start_delay > 0.0:
		_in_node_start_delay = true
		_node_delay_elapsed = 0.0
		if debug_enabled:
			print("[%s] Node start_delay=%.2f, holding at From state" % [name, start_delay])

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

	# Write immediately so first-frame state is correct. With contribution
	# tracking this applies: target = target - old(0) + new(first_delta),
	# ensuring the target is at the correct position before the first _process.
	_post_tick_write()

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

	# Follow chain_to (skip if chained_preroll already started it)
	if effect.chain_to != null and not effect._chained_preroll_triggered:
		var chain_idx := _runtime_effects.find(effect.chain_to)
		if chain_idx >= 0:
			var chained := _runtime_effects[chain_idx]
			if chained != null:
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
# SEQUENCER LOGIC (mode == SEQUENCER only)
# =============================================================================

## Sequencer retrigger gate — mirrors STACK's retrigger logic but for sequences.
func _seq_request_sequence(is_reverse: bool, is_one_shot_return: bool = false) -> void:
	if _is_playing:
		match retrigger_policy:
			RetriggerPolicy.IGNORE:
				if debug_enabled:
					print("[%s] Seq retrigger IGNORED" % name)
				return
			RetriggerPolicy.QUEUE:
				_queued_trigger = {"play_in": not is_reverse, "is_one_shot_return": is_one_shot_return}
				if debug_enabled:
					print("[%s] Seq retrigger QUEUED" % name)
				return
			RetriggerPolicy.RESTART:
				if debug_enabled:
					print("[%s] Seq retrigger RESTART" % name)
				_seq_stop()

	# Initialize loop/ping-pong state on fresh triggers (not internal restarts)
	if not is_one_shot_return and _seq_current_loop == 0 and _seq_pp_current_cycle == 0:
		_seq_playing_reverse = is_reverse
		_seq_initial_reverse = is_reverse
		_seq_pp_forward = true

	_seq_start_sequence(is_reverse, is_one_shot_return)


## Stop all sequencer animations cleanly.
func _seq_stop() -> void:
	_seq_generation += 1  # Abort any in-flight coroutines
	_is_playing = false
	_queued_trigger = {}
	_seq_active_animations = 0
	_seq_pp_forward = true
	_seq_pp_current_cycle = 0
	_seq_current_loop = 0
	_seq_target_active_indices.clear()
	_seq_held_entries.clear()
	_seq_target_contributions.clear()
	_seq_expected_after_write.clear()

	# Stop all per-target effect clones
	for target_variant: Variant in _seq_target_effects.keys():
		var target: Node = target_variant as Node
		var effects: Array = _seq_target_effects.get(target_variant, []) as Array
		for effect_variant: Variant in effects:
			var effect: JuiceEffectBase = effect_variant as JuiceEffectBase
			if effect != null and effect.is_playing() and target != null:
				effect.stop(target)

	set_process(false)

	if debug_enabled:
		print("[%s] Seq stopped" % name)


## Core sequencing coroutine — staggers animation across targets.
func _seq_start_sequence(is_reverse: bool, is_one_shot_return: bool = false) -> void:
	_is_playing = true
	_seq_playing_reverse = is_reverse

	# Capture generation for stale coroutine detection
	_seq_generation += 1
	var my_gen := _seq_generation

	# Get filtered and ordered targets early — needed for warmup before delay
	var targets := _get_seq_targets()

	if targets.is_empty():
		if debug_enabled:
			print("[%s] Seq: no targets found" % name)
		_is_playing = false
		completed.emit()
		return

	targets = _apply_seq_stagger_order(targets, is_reverse)
	_seq_active_animations = 0

	# Warmup BEFORE start_delay: pre-position targets at From state immediately
	# so they don't flash at Self/natural position during the delay window.
	# Hold pattern keeps Control targets enforced every frame (beats Container re-sort).
	if juice_source == JuiceSource.RECIPE:
		_seq_warmup_recipe_targets(targets, is_reverse)

	# Handle start delay (skip for one_shot return and internal loop/ping-pong restarts)
	if start_delay > 0.0 and not is_one_shot_return \
			and _seq_current_loop == 0 and _seq_pp_current_cycle == 0:
		await get_tree().create_timer(start_delay).timeout
		if _seq_generation != my_gen:
			return  # Aborted by retrigger

	# Emit started signal only on the very first pass
	if not is_one_shot_return and _seq_current_loop == 0 \
			and (not _seq_pp_forward or _seq_pp_current_cycle == 0):
		if is_reverse:
			animate_out_started.emit()
		else:
			animate_in_started.emit()

	if debug_enabled:
		print("[%s] Seq starting with %d targets, delay=%.2f, reverse=%s" % [
			name, targets.size(), seq_stagger_delay, is_reverse])

	# Animate each target with stagger delay
	for i in range(targets.size()):
		var target := targets[i]

		# Stagger delay between targets (not for first, not for ALL_AT_ONCE)
		if i > 0 and sequence_type != SequenceType.ALL_AT_ONCE and seq_stagger_delay > 0.0:
			await get_tree().create_timer(seq_stagger_delay).timeout
			if _seq_generation != my_gen:
				return

		# Animate this target
		_seq_animate_target(target, is_reverse)
		if _seq_generation != my_gen:
			return

	# Wait for all target animations to complete
	while _seq_active_animations > 0:
		await get_tree().process_frame
		if _seq_generation != my_gen:
			return

	# --- Sequence pass complete: handle looping/ping-pong/completion ---
	_seq_on_pass_complete(is_reverse, is_one_shot_return, my_gen)


## Animate a single target based on juice_source mode.
func _seq_animate_target(target: Node, is_reverse: bool) -> void:
	match juice_source:
		JuiceSource.RECIPE:
			_seq_animate_target_recipe(target, is_reverse)
		JuiceSource.TARGETS_STACK:
			_seq_animate_target_stack(target, is_reverse)
		JuiceSource.TARGETS_CHILDREN:
			_seq_animate_target_children(target, is_reverse)


## RECIPE mode: clone recipe effects per target and start them.
## Effects are ticked by _seq_process_tick() in _process().
func _seq_animate_target_recipe(target: Node, is_reverse: bool) -> void:
	if recipe == null:
		return

	var effects := _seq_get_or_create_target_effects(target)
	if effects.is_empty():
		return

	# Find root effect indices (not chained from another in this set)
	var chained_set: Array[JuiceEffectBase] = []
	for eff in effects:
		if eff != null and eff.chain_to != null:
			chained_set.append(eff.chain_to)
	var root_indices: Array[int] = []
	for i in effects.size():
		if effects[i] != null and effects[i] not in chained_set:
			root_indices.append(i)

	# Release held entry (warmup hold) before real animation starts
	_seq_release_held_for_target(target)

	# Undo warmup contribution so effects re-capture the natural base,
	# not the warmup-modified state. Same principle as _temporarily_undo_visual().
	_seq_restore_target_natural(target)

	# Start root effects and track active indices
	var play_in := not is_reverse
	var active_indices: Array[int] = []
	for idx in root_indices:
		effects[idx].start(target, play_in, true, self)
		active_indices.append(idx)

	_seq_target_active_indices[target] = active_indices
	_seq_active_animations += 1  # One completion event per target
	set_process(true)

	if debug_enabled:
		print("[%s] Seq RECIPE: started %d roots on '%s'" % [name, root_indices.size(), target.name])


## TARGETS_STACK mode: find JuiceBase nodes inside a named container on target.
func _seq_animate_target_stack(target: Node, is_reverse: bool) -> void:
	var stack := target.get_node_or_null(seq_stack_name)
	if stack == null:
		if debug_enabled:
			print("[%s] Seq STACK: target '%s' has no stack '%s'" % [name, target.name, seq_stack_name])
		return

	var juice_nodes: Array[JuiceBase] = []
	for child in stack.get_children():
		if child is JuiceBase:
			juice_nodes.append(child as JuiceBase)

	if juice_nodes.is_empty():
		if debug_enabled:
			print("[%s] Seq STACK: stack '%s' on '%s' has no JuiceBase children" % [name, seq_stack_name, target.name])
		return

	_seq_trigger_juice_nodes(juice_nodes, is_reverse, target.name, "STACK")


## TARGETS_CHILDREN mode: find JuiceBase children directly on target.
func _seq_animate_target_children(target: Node, is_reverse: bool) -> void:
	var juice_nodes: Array[JuiceBase] = []
	for child in target.get_children():
		if child is JuiceBase:
			juice_nodes.append(child as JuiceBase)

	if juice_nodes.is_empty():
		if debug_enabled:
			print("[%s] Seq CHILDREN: target '%s' has no JuiceBase children" % [name, target.name])
		return

	_seq_trigger_juice_nodes(juice_nodes, is_reverse, target.name, "CHILDREN")


## Shared helper: trigger a list of JuiceBase nodes and track their completion.
func _seq_trigger_juice_nodes(juice_nodes: Array[JuiceBase], is_reverse: bool, target_name: String, mode_label: String) -> void:
	for juice in juice_nodes:
		_seq_active_animations += 1
		if not juice.completed.is_connected(_seq_on_ext_juice_completed):
			juice.completed.connect(_seq_on_ext_juice_completed)
		if is_reverse:
			juice.animate_out()
		else:
			juice.animate_in()

	if debug_enabled:
		print("[%s] Seq %s: triggered %d JuiceBase nodes on '%s'" % [name, mode_label, juice_nodes.size(), target_name])


## Callback when an externally-triggered JuiceBase node completes (STACK/CHILDREN modes).
func _seq_on_ext_juice_completed() -> void:
	_seq_active_animations = maxi(0, _seq_active_animations - 1)


## Get or create per-target runtime effect clones for RECIPE mode.
func _seq_get_or_create_target_effects(target: Node) -> Array[JuiceEffectBase]:
	if _seq_target_effects.has(target):
		return _seq_target_effects[target] as Array[JuiceEffectBase]

	if recipe == null:
		return []

	var clones: Array[JuiceEffectBase] = recipe.create_runtime_effects()
	_seq_target_effects[target] = clones

	if debug_enabled:
		print("[%s] Created %d effect clones for target '%s'" % [name, clones.size(), target.name])

	return clones


## Pre-position all targets at their From state before the stagger loop begins.
## For Control targets inside Containers, registers a hold entry so the From state
## is re-applied every frame (beating Container re-sort). 2D/3D get one-shot only.
func _seq_warmup_recipe_targets(targets: Array[Node], is_reverse: bool) -> void:
	_seq_held_entries.clear()
	var play_in := not is_reverse

	for target in targets:
		var effects := _seq_get_or_create_target_effects(target)
		if effects.is_empty():
			continue

		# Start effects at From state (progress 0.0 for in, 1.0 for out)
		# then write deltas to target as a one-shot.
		for eff in effects:
			eff._on_animate_start(target)
			var from_progress := 0.0 if play_in else 1.0
			eff._apply_effect(from_progress, target)
		_seq_post_tick_write_target(target, effects)

		# Control targets inside Containers need continuous hold
		if target is Control:
			_seq_held_entries.append({
				"target": target,
				"effects": effects,
				"play_in": play_in,
			})

	if not _seq_held_entries.is_empty():
		set_process(true)

	if debug_enabled:
		print("[%s] Seq warmup: %d targets, %d held" % [name, targets.size(), _seq_held_entries.size()])


## Release held entries for a target when its real animation starts.
func _seq_release_held_for_target(target: Node) -> void:
	for i in range(_seq_held_entries.size() - 1, -1, -1):
		if _seq_held_entries[i].get("target") == target:
			_seq_held_entries.remove_at(i)


## Tick all per-target effects in SEQUENCER RECIPE mode.
## Called from _process() when mode == SEQUENCER.
## Handles chaining and per-target completion tracking.
func _seq_process_tick(delta: float) -> void:
	# Enforce held entries (Control targets in Containers, pre-positioned at From)
	for entry in _seq_held_entries:
		var held_target: Node = entry.get("target")
		var held_effects: Array = entry.get("effects", [])
		var held_play_in: bool = entry.get("play_in", true)
		if held_target == null or not is_instance_valid(held_target):
			continue
		var from_progress := 0.0 if held_play_in else 1.0
		for eff_variant: Variant in held_effects:
			var eff: JuiceEffectBase = eff_variant as JuiceEffectBase
			if eff != null:
				eff._apply_effect(from_progress, held_target)
		_seq_post_tick_write_target(held_target, held_effects)

	var targets_done: Array[Node] = []

	for target_variant: Variant in _seq_target_active_indices.keys():
		var target: Node = target_variant as Node
		if target == null or not is_instance_valid(target):
			targets_done.append(target)
			continue

		var active_indices: Array = _seq_target_active_indices.get(target_variant, []) as Array
		var effects: Array = _seq_target_effects.get(target_variant, []) as Array
		var newly_completed: Array[int] = []
		var any_playing := false

		for idx_variant: Variant in active_indices:
			var idx: int = idx_variant as int
			if idx < 0 or idx >= effects.size():
				continue
			var effect: JuiceEffectBase = effects[idx] as JuiceEffectBase
			if effect == null or not effect.is_playing():
				continue

			any_playing = true
			var result := effect.tick(delta, target)
			if result == JuiceEffectBase.TickResult.COMPLETED:
				newly_completed.append(idx)

		# Chained preroll: start chained effects early for overlap
		for idx_variant2: Variant in active_indices:
			var pidx: int = idx_variant2 as int
			if pidx < 0 or pidx >= effects.size():
				continue
			var peff: JuiceEffectBase = effects[pidx] as JuiceEffectBase
			if peff == null or not peff.is_playing():
				continue
			if peff.chain_to == null or peff.chained_preroll <= 0.0:
				continue
			if peff._chained_preroll_triggered:
				continue
			if peff._get_time_to_completion() <= peff.chained_preroll:
				var chain_idx := effects.find(peff.chain_to)
				if chain_idx >= 0:
					var chained: JuiceEffectBase = effects[chain_idx] as JuiceEffectBase
					if chained != null:
						var play_in := peff._animation_progress >= 0.5
						chained.start(target, play_in, false)
						if chain_idx not in active_indices:
							active_indices.append(chain_idx)
						peff._chained_preroll_triggered = true
						any_playing = true

		# Write aggregated deltas to target (domain-specific)
		_seq_post_tick_write_target(target, effects)

		# Handle chaining within this target's effects (skip if preroll already started)
		for idx in newly_completed:
			var effect: JuiceEffectBase = effects[idx] as JuiceEffectBase
			if effect != null and effect.chain_to != null and not effect._chained_preroll_triggered:
				var chain_idx := effects.find(effect.chain_to)
				if chain_idx >= 0:
					var chained: JuiceEffectBase = effects[chain_idx] as JuiceEffectBase
					if chained != null:
						var play_in := effect._animation_progress >= 0.5
						chained.start(target, play_in, false)
						if chain_idx not in active_indices:
							active_indices.append(chain_idx)
						any_playing = true

		# Re-check: any still playing after chaining?
		if not any_playing and newly_completed.is_empty():
			targets_done.append(target)
		elif not any_playing:
			# All were done but chaining may have started new ones — recheck
			var still_playing := false
			for idx_variant2: Variant in active_indices:
				var idx2: int = idx_variant2 as int
				if idx2 >= 0 and idx2 < effects.size():
					var eff: JuiceEffectBase = effects[idx2] as JuiceEffectBase
					if eff != null and eff.is_playing():
						still_playing = true
						break
			if not still_playing:
				targets_done.append(target)

	# Remove completed targets and decrement counter
	for done_target in targets_done:
		_seq_target_active_indices.erase(done_target)
		_seq_active_animations = maxi(0, _seq_active_animations - 1)

	# Stop processing when no active targets remain
	if _seq_target_active_indices.is_empty():
		set_process(false)


## Called when a full sequence pass completes (all targets done).
## Handles ping-pong cycling, PLAY_IN_AND_OUT auto-reverse, non-ping-pong
## looping, hide_parent_on_reverse_complete, and final completion.
func _seq_on_pass_complete(is_reverse: bool, is_one_shot_return: bool, my_gen: int) -> void:
	if debug_enabled:
		print("[%s] Seq pass complete (reverse=%s, osr=%s)" % [name, is_reverse, is_one_shot_return])

	# --- Ping-pong cycling ---
	# Forward leg → reverse leg = 1 cycle. Superset of PLAY_IN_AND_OUT auto-reverse.
	if trigger_behaviour == JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT \
			and not is_one_shot_return:
		if _seq_pp_forward:
			# Forward leg just completed → start reverse leg
			_seq_pp_forward = false
			if debug_enabled:
				print("[%s] Seq ping-pong: forward → reverse" % name)
			if loop_delay > 0.0:
				await get_tree().create_timer(loop_delay).timeout
				if _seq_generation != my_gen:
					return
			_seq_start_sequence(true)
			return
		else:
			# Reverse leg just completed → one full cycle done
			_seq_pp_current_cycle += 1
			_seq_pp_forward = true

			var should_continue := false
			if loop_count < 0:
				should_continue = true  # Infinite
			elif _seq_pp_current_cycle < loop_count:
				should_continue = true

			if should_continue:
				if debug_enabled:
					print("[%s] Seq ping-pong: cycle %d/%s → next" % [
						name, _seq_pp_current_cycle, str(loop_count)])
				if loop_delay > 0.0:
					await get_tree().create_timer(loop_delay).timeout
					if _seq_generation != my_gen:
						return
				_seq_start_sequence(false)
				return
			# else: all cycles done, fall through to completion

	# --- Non-ping-pong looping ---
	if trigger_behaviour != JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT \
			and loop_count != 1:
		_seq_current_loop += 1
		var should_loop := false
		if loop_count < 0:
			should_loop = true
		elif _seq_current_loop < loop_count:
			should_loop = true

		if should_loop:
			if debug_enabled:
				print("[%s] Seq loop: pass %d/%s → next" % [
					name, _seq_current_loop, str(loop_count)])
			if loop_delay > 0.0:
				await get_tree().create_timer(loop_delay).timeout
				if _seq_generation != my_gen:
					return
			# Restart from the initial trigger direction
			_seq_start_sequence(_seq_initial_reverse)
			return

	# --- Sequence fully complete ---
	_is_playing = false

	if debug_enabled:
		print("[%s] Seq fully complete" % name)

	# Handle hide_parent_on_reverse_complete (only after FINAL reverse)
	if is_reverse and seq_hide_parent_on_reverse_complete:
		var parent := get_parent()
		if parent and parent is CanvasItem:
			parent.hide()
			if debug_enabled:
				print("[%s] Hiding parent '%s' after reverse complete" % [name, parent.name])

	completed.emit()

	# Execute queued trigger
	if not _queued_trigger.is_empty():
		var queued := _queued_trigger
		_queued_trigger = {}
		_handle_trigger(queued)

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


## Mid-tick hook: compute sibling displacement for reactive effects.
## Called between Phase 1 (non-reactive tick) and Phase 2 (reactive tick).
## Domain nodes sum non-reactive deltas, compare to previous frame, and notify
## reactive effects via _on_sibling_displacement().
func _compute_sibling_displacement() -> void:
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


## Sequencer: undo warmup contribution on a target, restoring it to its natural
## (Container-managed / editor) state. Called before effects re-capture base for
## the real animation, preventing warmup contributions from polluting the base.
## Generic — works for any property channel effects report via _get_seq_contribution().
func _seq_restore_target_natural(target: Node) -> void:
	var contrib: Dictionary = _seq_target_contributions.get(target, {})
	var expected: Dictionary = _seq_expected_after_write.get(target, {})
	for prop_name: String in contrib:
		var actual: Variant = target.get(prop_name)
		# External-reset detection: if actual differs from what we wrote last,
		# an external system reset this property. Our contribution is no longer
		# baked into the current value — skip subtraction (value is already natural).
		if prop_name in expected and not _seq_values_approx_equal(actual, expected[prop_name]):
			continue
		target.set(prop_name, actual - contrib[prop_name])
	_seq_target_contributions.erase(target)
	_seq_expected_after_write.erase(target)


## Sequencer RECIPE mode: aggregate effect deltas and write to target.
## Generic — effects report their contributions via _get_seq_contribution()
## keyed by Godot property names. Domain nodes do NOT need to override this.
## Uses contribution-tracking pattern so Container re-sorts are automatically
## absorbed — same principle as STACK mode's external-move detection.
func _seq_post_tick_write_target(target: Node, effects: Array) -> void:
	# Aggregate all effect contributions keyed by property name
	var total := {}
	for eff: Variant in effects:
		if eff == null:
			continue
		var contrib: Dictionary = eff._get_seq_contribution()
		for key: String in contrib:
			if key in total:
				total[key] = total[key] + contrib[key]
			else:
				total[key] = contrib[key]

	# Retrieve our last contribution for this target
	var prev: Dictionary = _seq_target_contributions.get(target, {})

	# External-reset detection: if the current value differs from what we wrote
	# last frame, an external system changed the property. Our stored contribution
	# is stale — clear it so we derive natural correctly from the reset value.
	var expected: Dictionary = _seq_expected_after_write.get(target, {})
	for key: String in prev:
		if key in expected:
			var actual: Variant = target.get(key)
			if not _seq_values_approx_equal(actual, expected[key]):
				prev.erase(key)

	# For each property we're contributing to now: derive natural, then write
	for key: String in total:
		var prev_val: Variant = prev.get(key, _seq_zero_for(total[key]))
		var natural: Variant = target.get(key) - prev_val
		target.set(key, natural + total[key])

	# Restore any properties we contributed to last frame but no longer do
	for key: String in prev:
		if key not in total:
			target.set(key, target.get(key) - prev[key])

	_seq_target_contributions[target] = total

	# Store expected values after write for next frame's external-reset detection
	var new_expected := {}
	for key: String in total:
		new_expected[key] = target.get(key)
	_seq_expected_after_write[target] = new_expected


## Return the zero value for the same type as the given Variant.
## Used by contribution-tracking when no previous contribution exists.
static func _seq_zero_for(val: Variant) -> Variant:
	match typeof(val):
		TYPE_FLOAT: return 0.0
		TYPE_VECTOR2: return Vector2.ZERO
		TYPE_VECTOR3: return Vector3.ZERO
		TYPE_COLOR: return Color(0, 0, 0, 0)
	return val - val  # fallback for other numeric types


## Compare two Variant values with approximate equality.
## Used by external-reset detection to avoid false positives from float imprecision.
static func _seq_values_approx_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	match typeof(a):
		TYPE_FLOAT:
			return is_equal_approx(a, b)
		TYPE_VECTOR2:
			return (a as Vector2).is_equal_approx(b as Vector2)
		TYPE_VECTOR3:
			return (a as Vector3).is_equal_approx(b as Vector3)
		TYPE_COLOR:
			return (a as Color).is_equal_approx(b as Color)
	return a == b

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	if recipe == null:
		warnings.append("No recipe assigned. Add a JuiceRecipe to get started.")
	elif recipe.effects.is_empty():
		warnings.append("Recipe has no effects. Add JuiceEffectBase resources to the recipe.")
	elif recipe.effects.has(null):
		var null_count := 0
		for eff in recipe.effects:
			if eff == null:
				null_count += 1
		warnings.append("Recipe has %d empty effect slot(s). They will be ignored at runtime." % null_count)
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
	return null  # SEQUENCER resolves per-target dynamically


## Get filtered list of target nodes for SEQUENCER mode based on target_scope.
func _get_seq_targets() -> Array[Node]:
	var targets: Array[Node] = []
	var parent := get_parent()
	if parent == null:
		return targets

	# Get candidate nodes based on scope
	var candidates: Array[Node] = []
	match target_scope:
		TargetScope.SIBLINGS, TargetScope.CHILDREN:
			for child in parent.get_children():
				candidates.append(child)
		TargetScope.CUSTOM:
			for path in seq_custom_targets:
				var node := get_node_or_null(path)
				if node == null:
					if debug_enabled:
						print("[%s] CUSTOM target not found: %s" % [name, str(path)])
					continue
				candidates.append(node)

	# Apply filters
	for node in candidates:
		if seq_skip_self and node == self:
			continue
		if seq_skip_invisible:
			if node is CanvasItem and not node.visible:
				continue
			if node is Node3D and not node.visible:
				continue
		if seq_skip_juice_nodes and node is JuiceBase:
			continue
		targets.append(node)

	return targets


## Apply sequence ordering to target list, with optional mirror on exit.
func _apply_seq_stagger_order(targets: Array[Node], is_reverse: bool) -> Array[Node]:
	var ordered := targets.duplicate()

	var effective_type: SequenceType = sequence_type

	# Mirror stagger direction on exit if enabled
	if is_reverse and seq_mirror_stagger_on_exit:
		match sequence_type:
			SequenceType.STAGGER_FORWARD:
				effective_type = SequenceType.STAGGER_REVERSE
			SequenceType.STAGGER_REVERSE:
				effective_type = SequenceType.STAGGER_FORWARD

	match effective_type:
		SequenceType.STAGGER_FORWARD, SequenceType.ALL_AT_ONCE:
			pass  # Keep forward order
		SequenceType.STAGGER_REVERSE:
			ordered.reverse()
		SequenceType.RANDOM:
			ordered.shuffle()

	return ordered


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

	# AnimationPlayer: cross-domain, connect animation_finished
	if _trigger_source_node is AnimationPlayer:
		var anim := _trigger_source_node as AnimationPlayer
		if not anim.animation_finished.is_connected(_on_animation_finished):
			anim.animation_finished.connect(_on_animation_finished)
		if debug_enabled:
			print("[%s] Auto-connected to AnimationPlayer '%s'" % [name, anim.name])
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

