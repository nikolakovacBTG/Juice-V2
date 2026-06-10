## Base class for all Juice nodes. Use [JuiceControl], [Juice2D], or [Juice3D] instead.
##
## Drives [JuiceEffectBase] resources via a [JuiceRecipe]. Manages triggers,
## animation lifecycle, chaining, looping, and delta-first stacking. Supports
## STACK mode (single target) and SEQUENCER mode (multiple targets with stagger).

# ============================================================================
# WHAT: Unified base node that drives JuiceEffectBase resources via a recipe.
# WHY: Replaces per-effect Node architecture with a single node per target.
#      Manages triggers, animation lifecycle, chaining, and looping.
# SYSTEM: Juice System (addons/Juice_V2/)
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
@icon("res://addons/Juice_V2/icons/JuiceBase.svg")
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
	ON_MOUSE_ENTERED,  ## 2 - Mouse entered — start of hover pair, supports Toggle
	ON_MOUSE_EXITED,   ## 3 - Mouse exited — end of hover pair
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

@export_subgroup("Sequencer Options")

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
@export var trigger_source_path: NodePath:
	set(value):
		trigger_source_path = value
		notify_property_list_changed()

## What event triggers the animation. Options are filtered per domain.
@export var trigger_on: TriggerEvent = TriggerEvent.ON_READY:
	set(value):
		trigger_on = value
		notify_property_list_changed()

## Signal name to connect to on the source node (only for MANUAL trigger).
@export var manual_trigger_signal: String

## How the trigger maps to animation direction. Default for all effects in recipe;
## individual effects can still override this after assignment.
## Toggle is only available on triggers marked (toggleable) — polarity-capable start events
## (On Press, On Mouse Entered, On Focus, Manual) where a natural paired counterpart exists.
## On those triggers, Toggle uses the signal direction: enter = animate in, exit = animate out.
## On all other triggers Toggle is hidden — it cannot be meaningfully used there.
@export var trigger_behaviour: JuiceEffectBase.TriggerBehaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY:
	set(value):
		trigger_behaviour = value
		# In editor: squash all recipe effects to match the node's setting.
		# Effects can still be individually tweaked afterwards.
		if Engine.is_editor_hint() and recipe != null:
			for effect in recipe.effects:
				if effect != null:
					effect.trigger_behaviour = value
		notify_property_list_changed()

## Delay before the entire recipe starts after trigger (seconds).
@export_range(0.0, 100.0, 0.01, "or_greater") var start_delay: float = 0.0

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

@export_group("")

## The recipe containing effects to play.
@export var recipe: JuiceRecipe:
	set(value):
		# Disconnect from the old recipe before replacing it.
		# Without this, a recipe removed from this node would still trigger
		# stale warning refreshes if it continues to live elsewhere.
		if Engine.is_editor_hint() and recipe != null:
			if recipe.changed.is_connected(_on_recipe_changed):
				recipe.changed.disconnect(_on_recipe_changed)
				
		# --- Preset Safety Mechanism ---
		# If the user assigns a recipe, ensure it doesn't accidentally share state 
		# across multiple JuiceBase instances unless explicitly permitted by config.
		if Engine.is_editor_hint() and value != null:
			if JuiceProjectSettings.get_auto_local_to_scene() and not value.resource_local_to_scene:
				var safe_copy := value.duplicate(true) as JuiceRecipe
				safe_copy.resource_local_to_scene = true
				value = safe_copy
				
		recipe = value
		_invalidate_runtime_effects()
		if Engine.is_editor_hint():
			update_configuration_warnings()
			# Watch for any sub-resource edits (effects added, removed, modified)
			# so warnings refresh without requiring the user to re-assign the recipe.
			if recipe != null and not recipe.changed.is_connected(_on_recipe_changed):
				recipe.changed.connect(_on_recipe_changed)
			# Register the new recipe via editor bridge so sub-resources can resolve their host
			if _editor_register_recipe.is_valid():
				_editor_register_recipe.call(recipe, self)

@export_group("Debug")

## Print debug information to console.
@export var debug_enabled: bool = false

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

# Mutates trigger_behaviour's enum hint_string to show or hide the Toggle option.
# Toggle only makes sense on triggers that have a natural paired counterpart:
# ON_PRESS/ON_MOUSE_ENTERED/ON_FOCUS have a release/exit/unfocus counterpart;
# MANUAL lets the caller supply the polarity. All other triggers are one-shot
# with no natural reverse edge, so Toggle is meaningless for them.
# Note: show/hide of ALL properties is handled by JuiceEditorInspectorPlugin,
# not here. This method only mutates hint_string — EditorInspectorPlugin
# cannot do that from _parse_property (receives hint as a value copy).
func _validate_property(property: Dictionary) -> void:
	# Hide the "Sequencer Options" subgroup header in STACK mode.
	# @export_subgroup entries appear in _validate_property with PROPERTY_USAGE_SUBGROUP,
	# so we suppress them here the same way as any regular property.
	if property.name == "Sequencer Options" and mode == Mode.STACK:
		property.usage = PROPERTY_USAGE_NO_EDITOR
		return

	if property.name == "trigger_behaviour":
		var supports_toggle := trigger_on in [
			TriggerEvent.ON_PRESS,
			TriggerEvent.ON_MOUSE_ENTERED,
			TriggerEvent.ON_FOCUS,
			TriggerEvent.MANUAL,
		]
		property.hint = PROPERTY_HINT_ENUM
		if supports_toggle:
			property.hint_string = "Play In And Out:0,Play In Only:1,Play Out Only:2,Toggle:3,Set From Source:4"
		else:
			property.hint_string = "Play In And Out:0,Play In Only:1,Play Out Only:2,Set From Source:4"

# =============================================================================
# EDITOR CALLABLE HOOKS
# =============================================================================

## Editor-time recipe registration. Injected by juice_plugin.gd at _enter_tree().
## Signature: func(recipe: Resource, host: Node) -> void
static var _editor_register_recipe: Callable

## Editor-time preview flag setter. Injected by juice_plugin.gd at _enter_tree().
## Signature: func(node: Node, active: bool) -> void
static var _editor_set_previewing: Callable

# =============================================================================
# INTERNAL STATE
# =============================================================================


# Runtime-cloned effects — stored on the active orchestrator, not JuiceBase.
# Computed property delegates to _runtime_orchestrator.runtime_effects so all 50+
# existing callers in JuiceBase work unchanged. Returns [] when orch is absent
# (non-preview editor context where _ready() returns early).
var _runtime_effects: Array[JuiceEffectBase]:
	get:
		if _runtime_orchestrator != null and is_instance_valid(_runtime_orchestrator):
			return _runtime_orchestrator.runtime_effects
		return []
	set(v):
		if _runtime_orchestrator != null and is_instance_valid(_runtime_orchestrator):
			_runtime_orchestrator.runtime_effects = v

# True after set_external_progress has initialised effects for the first time.
var _external_progress_initialized: bool = false


# Active effect indices — stored on the orchestrator alongside runtime_effects.
# Computed property for zero-change migration: all callers use _active_effect_indices
# as before; reads and writes are transparently forwarded to the orch.
var _active_effect_indices: Array[int]:
	get:
		if _runtime_orchestrator != null and is_instance_valid(_runtime_orchestrator):
			return _runtime_orchestrator.active_effect_indices
		return []
	set(v):
		if _runtime_orchestrator != null and is_instance_valid(_runtime_orchestrator):
			_runtime_orchestrator.active_effect_indices = v

# Target node — what effects animate (resolved at _ready).
var _target_node: Node = null

# Trigger source node — where signals come from (may differ from target).
var _trigger_source_node: Node = null

# Current toggle state for TOGGLE behaviour.
var _toggle_state: bool = false

# Whether any effects are currently playing.
var _is_playing: bool = false

# Current recipe iteration count.
var _current_iteration: int = 0

# Node-level start_delay tracking (delays entire recipe after trigger).
var _in_node_start_delay: bool = false
var _node_delay_elapsed: float = 0.0
var _pending_play_in: bool = true

# Iteration delay tracking.
var _in_loop_delay: bool = false
var _loop_delay_elapsed: float = 0.0

# Queued trigger for RetriggerPolicy.QUEUE
var _queued_trigger: Dictionary = {}

# True while the Preview Director has this node in editor preview mode.
# Set by _enter/_exit_editor_preview(). Used to prevent _ready() from
# short-circuiting in editor and to gate preview-only code paths.
var _editor_preview_active: bool = false
# Holds the RUNTIME orchestrator driving tick() for STACK-mode animations.
# Alive from first play until JuiceBase exits the scene tree (freed automatically as a child).
# Never freed mid-session — retriggers reuse the same instance (zero-allocation, no GC stutter).
var _runtime_orchestrator: JuiceOrchestrator = null

# --- Sequencer-specific state (SEQUENCER mode only) ---

# Coroutine generation counter. Incremented on stop() and new sequence starts.
# Each coroutine captures its generation at birth; if the global counter has
# advanced past it after an await, the coroutine aborts silently.
var _seq_generation: int = 0

# Number of active animations being tracked for completion in current sequence pass.
var _seq_active_animations: int = 0

# True when currently playing in reverse (exit animation).
var _seq_playing_reverse: bool = false

# The direction of the initial trigger. Used to restart loops from the correct direction.
var _seq_initial_reverse: bool = false

# Non-ping-pong loop counter for sequencer.
var _seq_current_loop: int = 0

# Ping-pong state for sequencer: true = forward leg, false = reverse leg.
var _seq_pp_forward: bool = true

# Counts completed full ping-pong cycles (forward + reverse = 1 cycle).
var _seq_pp_current_cycle: int = 0

# Per-target runtime effect clones for RECIPE mode.
# Keys: target Node, Values: Array[JuiceEffectBase] (cloned effects for that target).
var _seq_target_effects: Dictionary = {}

# Per-target active effect indices (which clones are being ticked).
# Keys: target Node, Values: Array[int] (indices into that target's effects array).
var _seq_target_active_indices: Dictionary = {}

# Held entries for Container hold pattern (RECIPE mode, Control targets).
# Each entry: { "target": Node, "effects": Array[JuiceEffectBase] }
# Effects are continuously re-applied at From state every frame until released.
var _seq_held_entries: Array[Dictionary] = []

# _seq_target_contributions and _seq_expected_after_write were removed.
# The Centralized Metadata Ledger (LEDGER_KEY on each target) now owns this state,
# keyed by source instance_id. _seq_post_tick_write_target clears our source slice
# via _ledger_cleanup_source before re-registering current-frame deltas.

# =============================================================================
# LIFECYCLE
# =============================================================================

func _notification(what: int) -> void:
	# Forward EDITOR_PRE_SAVE to effects so they can bake editor caches
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		# Refresh warnings at save time — catches any recipe or config change
		# that happened since the last recipe re-assignment.
		update_configuration_warnings()
		# In editor, _runtime_effects is empty (_ready returns early).
		# Use recipe.effects directly for editor cache baking.
		# STACK mode only: in Sequencer mode each target has its own per-target ledger
		# base snapshot at runtime, so IN_EDITOR capture reads from the ledger instead
		# of the baked editor cache (see _capture_*_self_*_snapshot in concrete classes).
		if recipe == null or mode != Mode.STACK:
			return
		var target := _target_node
		if target == null:
			target = _resolve_target()
		if target == null:
			return
		for effect in recipe.effects:
			if effect != null:
				effect._on_editor_pre_save(target)


func _ready() -> void:
	if Engine.is_editor_hint():
		if recipe != null and _editor_register_recipe.is_valid():
			_editor_register_recipe.call(recipe, self)
		return

	# Resolve target before creating the orchestrator. The factory now requires
	# callers to provide target explicitly (no internal reads from the node).
	# SEQUENCER resolves targets per-entry at runtime, so null here is valid.
	_target_node = _resolve_target()
	if _target_node == null and mode == Mode.STACK:
		JuiceLogger.warn(self, _get_domain_tag(), "No valid target node found", debug_enabled)
		return

	# Create RUNTIME orchestrator eagerly with the resolved target.
	# Eager creation ensures _runtime_effects computed property has a home before
	# _invalidate_runtime_effects() fires (via deferred _post_ready_init).
	_runtime_orchestrator = JuiceOrchestratorFactory.create(self, recipe, _target_node, JuiceOrchestrator.Mode.RUNTIME)
	add_child(_runtime_orchestrator)

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
					JuiceLogger.log_info(self, _get_domain_tag(),
						"Sibling auto-connect: using '%s' (%s)" % [
						_trigger_source_node.name, _trigger_source_node.get_class()],
						debug_enabled)
				elif sibling_sources.size() > 1:
					var names := PackedStringArray()
					for s in sibling_sources:
						names.append(s.name)
					JuiceLogger.warn(self, _get_domain_tag(),
							"Multiple sibling trigger sources (%s). Set trigger_source_path." % [
							", ".join(names)],
							debug_enabled)
		TriggerSource.NODE:
			_trigger_source_node = get_node_or_null(trigger_source_path)
			if _trigger_source_node == null:
				JuiceLogger.warn(self, _get_domain_tag(),
						"Trigger source node not found: %s" % trigger_source_path,
						debug_enabled)

	# Clone recipe effects for independent state
	_invalidate_runtime_effects()

	# Register dynamic signals from effects BEFORE trigger wiring.
	# SignalEmit effects register their user-defined signals on `self` here,
	# ensuring they exist when JuiceTriggerRouter.wire_manual() runs below.
	for effect in _runtime_effects:
		if effect != null:
			effect._register_early_signals(self)

	# Auto-connect signals based on trigger source and trigger event
	if trigger_on == TriggerEvent.MANUAL:
		# MANUAL: defer wiring so all nodes have completed _ready() first.
		# Dynamic signals (e.g. "Used") are registered in _ready() via
		# _register_early_signals(). If the emitter sits later in the tree,
		# its signal won't exist yet during OUR _ready(). Deferring guarantees
		# all signals are registered before any wiring is attempted.
		if not manual_trigger_signal.is_empty():
			(func():
				var manual_source: Node = get_parent() \
					if trigger_source == TriggerSource.PARENT \
					else get_node_or_null(trigger_source_path)
				if manual_source != null:
					JuiceTriggerRouter.wire_manual(
						manual_source, manual_trigger_signal,
						_on_trigger_momentary, set_external_progress,
						name if debug_enabled else "")
				else:
					JuiceLogger.warn(self, _get_domain_tag(),
							"Manual trigger source not found", debug_enabled)
			).call_deferred()
	elif trigger_source == TriggerSource.PARENT and auto_connect_parent:
		_try_auto_connect()
	elif trigger_source == TriggerSource.NODE and _trigger_source_node != null:
		_try_auto_connect()

	# DEFERRED: Do NOT capture the base or fire ON_READY here.
	# At this point the scene tree has not finished _ready() for all nodes, and
	# Containers have not yet run their deferred _sort_children. Reading
	# ctrl.position here would return (0, 0) for every button regardless of its
	# real Container slot. call_deferred schedules _post_ready_init to run after
	# the current frame's deferred queue — by then, Container._sort_children has
	# already fired, so positions are correct.
	call_deferred("_post_ready_init")



func _exit_tree() -> void:
	# Clean up: undo contributions and stop all effects
	if _target_node != null:
		_temporarily_undo_visual()
		for effect in _runtime_effects:
			if effect != null and effect.is_playing():
				effect.stop(_target_node)
	_active_effect_indices.clear()


# Deferred counterpart to _ready().
# Runs after the Container engine has finished sorting its children for the
# current frame (Container._sort_children is deferred before JuiceControl.
# _ready() executes, so it fires first in the deferred queue). This guarantees
# that _capture_base_values reads the real Container-managed ctrl.position
# rather than the pre-layout (0, 0) that all buttons share before first sort.
# Effects that use CaptureAt.READY likewise see the correct position here.
func _post_ready_init() -> void:
	# Capture natural state after Container has sorted (STACK only).
	# In SEQUENCER mode _target_node is null, so this is a no-op.
	if _target_node != null:
		_capture_base_values()
		# Confirm target identity after Container deferred layout resolves.
		# This is the earliest point where target.position is Container-accurate.
		JuiceLogger.log_info(self, _get_domain_tag(),
				"post_ready: target=%s (%d effects ready)" % [
				_target_node.name, _runtime_effects.size()],
				debug_enabled)

	# Forward _on_host_ready so effects with CaptureAt.READY snapshot the
	# real, Container-managed position rather than the pre-layout (0, 0).
	if _target_node != null:
		for effect in _runtime_effects:
			if effect != null:
				# Inject ledger base so CaptureAt.READY snapshots read the true natural
				# position from the ledger rather than a potentially dirty target.property.
				effect._ledger_base_snapshot = JuiceLedger.get_base_dict(_target_node)
				effect._on_host_ready(_target_node, self)

	# Handle ON_READY trigger. Also deferred so the From/To snapshots inside
	# _start_effects see the correct position when CaptureAt == READY.
	if trigger_on == TriggerEvent.ON_READY:
		_handle_trigger({"play_in": true})





# =============================================================================
# PUBLIC API
# =============================================================================

## Trigger animate_in on all root effects in the recipe.
## The primary entry point for starting effects in the forward direction. Dispatches to _handle_trigger to apply retrigger policies.
func animate_in() -> void:
	_handle_trigger({"play_in": true})


## Trigger animate_out on all root effects in the recipe.
## The primary entry point for starting effects in the reverse direction. Typically invoked by release events (e.g., button up, mouse exit).
func animate_out(is_one_shot_return: bool = false) -> void:
	_handle_trigger({"play_in": false, "is_one_shot_return": is_one_shot_return})


## Stop all effects and restore to natural state.
## Instantly terminates all active animations and forces a rewrite of the natural state, wiping any active deltas. Used to hard-cancel juice before state changes.
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
	JuiceLogger.log_info(self, _get_domain_tag(), "Stopped", debug_enabled)


## Stop all effects but keep current visual state.
## Freezes animations without reverting them. Useful for pausing juice during hitstops or menu overlays.
func stop_and_hold() -> void:
	_in_node_start_delay = false
	for effect in _runtime_effects:
		if effect != null:
			effect.stop_and_hold()
	_active_effect_indices.clear()
	_is_playing = false
	_in_loop_delay = false



## Toggle between animate_in and animate_out.
## Flips the internal direction state. Primarily used for UI components that act as binary switches where no polarity signal exists.
func toggle() -> void:
	_toggle_state = not _toggle_state
	if _toggle_state:
		animate_in()
	else:
		animate_out()


## Set external progress on all effects (for SET_FROM_SOURCE).
## Bypasses the standard animation loop to allow external systems to drive the effect dynamically. 
## It initializes effects on the first call, then manually sets progress and writes deltas directly to the target node, 
## avoiding reliance on `_process` (which intentionally self-terminates when no effects are actively ticking).
func set_external_progress(value: float) -> void:
	if _target_node == null:
		return
	if value < 0.0:
		# Release: clear external driving, restore natural state
		if _external_progress_initialized:
			_external_progress_initialized = false
			for effect in _runtime_effects:
				if effect != null:
					effect._restore_to_natural(_target_node)
			_post_tick_write()
		return
	# First call: initialise all effects so From/To snapshots and contribution flags are set.
	if not _external_progress_initialized:
		_external_progress_initialized = true
		for effect in _runtime_effects:
			if effect != null:
				# Inject ledger base: this path bypasses JuiceEffectBase.start() so injection is manual.
				effect._ledger_base_snapshot = JuiceLedger.get_base_dict(_target_node)
				effect._on_animate_start(_target_node)
	# Set progress on all effects (computes deltas)
	for effect in _runtime_effects:
		if effect != null:
			effect.set_progress(value, _target_node)
	# Write deltas to target node directly — no _process dependency
	_pre_tick()
	_post_tick_write()
	JuiceLogger.log_info(self, _get_domain_tag(),
			"External progress=%.3f (initialized=%s)" % [value, _external_progress_initialized],
			debug_enabled)

# =============================================================================
# EDITOR PREVIEW API
# =============================================================================

## Enter editor preview mode. Called by the Preview Director when this node is
## selected for in-editor animation previewing.
##
## Resolves the target node, captures base values, and initializes runtime
## effects so the node is ready for play/scrub without running the game.
func _enter_editor_preview() -> void:
	if _editor_preview_active:
		return
	_editor_preview_active = true

	if mode == Mode.SEQUENCER:
		# SEQUENCER mode has no single target node — it resolves per-target dynamically
		# each time animate_in() fires. We cannot resolve a target here, but we CAN
		# clone the runtime effects and set the preview flag so the transport's
		# play() button correctly triggers the sequencer's own animate path.
		_invalidate_runtime_effects()
		if _editor_set_previewing.is_valid():
			_editor_set_previewing.call(self, true)
		JuiceLogger.log_info(self, _get_domain_tag(),
				"Entered editor preview (SEQUENCER mode)", debug_enabled)
		return

	# STACK mode: resolve single target node as normal
	_target_node = _resolve_target()
	if _target_node == null:
		_editor_preview_active = false
		return

	# DEFERRED: Capture base values after the current frame finishes.
	# Some Godot-internal @tool nodes (e.g. TileMapLayer) use deferred init —
	# reading their position synchronously here returns (0,0) before their own
	# tool script has settled. Deferring matches the _post_ready_init() pattern,
	# ensuring the ledger base is always the true editor-visible position.
	call_deferred("_deferred_editor_preview_init")


func _deferred_editor_preview_init() -> void:
	# Guard: if the user deselected before the deferred call fired, abort.
	if not _editor_preview_active or _target_node == null:
		return


	# Capture base values (domain subclasses: position, rotation, scale).
	# At this point all deferred @tool inits have run, so position is correct.
	_capture_base_values()

	# Clone recipe effects into _runtime_effects for independent state
	_invalidate_runtime_effects()

	# Initialize effects with target (call _on_host_ready so From/To capture works)
	for effect in _runtime_effects:
		if effect != null:
			effect._on_host_ready(_target_node, self)

	# Register with JuiceEditorContext for smart selection discovery
	if _editor_set_previewing.is_valid():
		_editor_set_previewing.call(self, true)

	JuiceLogger.log_info(self, _get_domain_tag(),
			"Entered editor preview | target='%s' | effects=%d" % [
			_target_node.name, _runtime_effects.size()],
			debug_enabled)


## Exit editor preview mode. Called by the Preview Director when this node is
## deselected or the transport is closing.
##
## Stops all effects, restores target to natural state, and cleans up runtime
## clones so no preview artifacts leak into the scene.
func _exit_editor_preview() -> void:
	if not _editor_preview_active:
		return

	if mode == Mode.SEQUENCER:
		# SEQUENCER cleanup: stop the sequence if running, clear runtime state
		if _is_playing:
			stop()
		_editor_preview_active = false
		_runtime_effects.clear()
		_active_effect_indices.clear()
		if _editor_set_previewing.is_valid():
			_editor_set_previewing.call(self, false)
		JuiceLogger.log_info(self, _get_domain_tag(),
				"Exited editor preview (SEQUENCER mode)", debug_enabled)
		return

	# STACK mode: stop all effects and restore natural state
	if _is_playing:
		stop()
	else:
		# Even if not playing (paused, scrubbed), undo any visual contribution
		_temporarily_undo_visual()
		_post_tick_write()

	_editor_preview_active = false
	_target_node = null
	_runtime_effects.clear()
	_active_effect_indices.clear()

	# Unregister from JuiceEditorContext
	if _editor_set_previewing.is_valid():
		_editor_set_previewing.call(self, false)

	JuiceLogger.log_info(self, _get_domain_tag(),
			"Exited editor preview", debug_enabled)


## Whether this node supports editor preview.
## Returns true if the node has a valid recipe with at least one effect.
## SceneAction utilities override this to return false.
func _supports_editor_preview() -> bool:
	if recipe == null:
		return false
	for effect in recipe.effects:
		if effect != null:
			return true
	return false


## Whether any effects are currently playing.
func is_playing() -> bool:
	return _is_playing


## Get the total preview duration for the scrub slider range.
## Accounts for node_start_delay and the longest effect in the recipe.
func get_total_preview_duration() -> float:
	var base_dur := 0.0
	if recipe != null:
		base_dur = recipe.get_total_preview_duration()
	return base_dur + start_delay


## Scrub all effects to a specific wall-clock time.
## Each effect maps the time to its own progress using get_progress_at_time(),
## which accounts for start_delay, duration_in, hold_at_peak, duration_out, and easing.
## Called by the Preview Director when the user drags the scrub slider.
func scrub_to_time(time: float) -> void:
	if _target_node == null or _runtime_effects.is_empty():
		return

	# Subtract node-level start_delay from the wall-clock time
	var effect_time := maxf(time - start_delay, 0.0)

	# Initialize effects on first scrub if not yet started
	if not _external_progress_initialized:
		_external_progress_initialized = true
		_temporarily_undo_visual()
		for effect in _runtime_effects:
			if effect != null:
				effect._ledger_base_snapshot = JuiceLedger.get_base_dict(_target_node)
				effect._on_animate_start(_target_node)
		_temporarily_reapply_visual()

	# Set per-effect progress based on wall-clock time
	for effect in _runtime_effects:
		if effect != null:
			var progress := effect.get_progress_at_time(effect_time)
			effect.set_progress(progress, _target_node)

	# Flush stacked deltas to target
	_pre_tick()
	_post_tick_write()


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
			# If this call came from a polarity signal (hover/focus/press enter or exit),
			# use the polarity direction directly — no flip-flop.
			# If this call came from a momentary trigger (click, ready, etc.),
			# flip-flop the toggle state as before.
			if trigger_info.get("is_polarity", false):
				resolved_play_in = play_in
			else:
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
				JuiceLogger.log_info(self, _get_domain_tag(), "Trigger ignored (playing)", debug_enabled)
				return
			RetriggerPolicy.QUEUE:
				_queued_trigger = trigger_info
				JuiceLogger.log_info(self, _get_domain_tag(), "Trigger queued", debug_enabled)
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
		JuiceLogger.log_info(self, _get_domain_tag(),
				"Node start_delay=%.2f, holding at From state" % start_delay,
				debug_enabled)

	JuiceLogger.log_info(self, _get_domain_tag(),
			"Trigger handled: play_in=%s, behaviour=%s" % [
			play_in, JuiceEffectBase.TriggerBehaviour.keys()[trigger_behaviour]],
			debug_enabled)

# =============================================================================
# CORE LOGIC
# =============================================================================

func _start_effects(play_in: bool) -> void:
	if recipe == null or _runtime_effects.is_empty():
		JuiceLogger.warn(self, _get_domain_tag(), "No recipe or effects to play", debug_enabled)
		return

	if _target_node == null:
		_target_node = _resolve_target()
		if _target_node == null:
			return

	# Cat 6: Domain guardrail — warn if any effect is incompatible with target
	for effect in _runtime_effects:
		if effect == null:
			continue
		if effect is JuiceControlEffectBase and not (_target_node is Control):
			JuiceLogger.warn_domain_mismatch(
				effect.get_script().get_global_name(),
				"Control", _target_node.get_class())
		elif effect is Juice2DEffectBase and not (_target_node is Node2D):
			JuiceLogger.warn_domain_mismatch(
				effect.get_script().get_global_name(),
				"Node2D", _target_node.get_class())
		elif effect is Juice3DEffectBase and not (_target_node is Node3D):
			JuiceLogger.warn_domain_mismatch(
				effect.get_script().get_global_name(),
				"Node3D", _target_node.get_class())

	_is_playing = true
	_active_effect_indices.clear()

	if play_in:
		animate_in_started.emit()
	else:
		animate_out_started.emit()

	# Find root effects (those not chained from another)
	var root_indices := _get_root_effect_indices()

	# JIT sync: Detect external moves (Container layout shifts) that happened while idle
	_pre_tick()

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



	# Safety guard — orch is created eagerly in _ready(), so this never fires in normal
	# operation. Kept as a defensive check for edge cases (node never entered scene tree).
	if _runtime_orchestrator == null or not is_instance_valid(_runtime_orchestrator):
		_runtime_orchestrator = JuiceOrchestratorFactory.create(self, recipe, _target_node, JuiceOrchestrator.Mode.RUNTIME)
		add_child(_runtime_orchestrator)

	# Log started effects with their type names so the orchestration chain is
	# auditable: which specific effects are playing, not just how many.
	var effect_names := PackedStringArray()
	for idx in root_indices:
		var e := _runtime_effects[idx]
		effect_names.append(e.get_script().get_global_name() if e else "null")
	JuiceLogger.log_info(self, _get_domain_tag(),
			"Started %d root effects (play_in=%s): [%s]" % [
			root_indices.size(), play_in, ", ".join(effect_names)],
			debug_enabled)


func _on_effect_completed(idx: int) -> void:
	if idx < 0 or idx >= _runtime_effects.size():
		return

	var effect := _runtime_effects[idx]
	if effect == null:
		return

	# Include type name + final progress so completion is attributable without
	# cross-referencing effect index against the recipe list.
	var effect_type: String = effect.get_script().get_global_name() if effect.get_script() else "unknown"
	JuiceLogger.log_info(self, _get_domain_tag(),
			"Effect %d (%s) completed (progress=%.3f)" % [
			idx, effect_type, effect._animation_progress],
			debug_enabled)

	# Follow chain_to (skip if chained_preroll already started it)
	if not effect.chain_to.is_empty() and not effect._chained_preroll_triggered:
		for chained_effect in effect.chain_to:
			var chain_idx := _runtime_effects.find(chained_effect)
			if chain_idx >= 0 and chain_idx not in _active_effect_indices:
				var chained := _runtime_effects[chain_idx]
				if chained != null:
					var play_in := effect._animation_progress >= 0.5
					chained.start(_target_node, play_in, false, self)
					_active_effect_indices.append(chain_idx)
		var chain_names := PackedStringArray()
		for ce in effect.chain_to:
			chain_names.append(ce.get_script().get_global_name() if ce and ce.get_script() else "null")
		JuiceLogger.log_info(self, _get_domain_tag(),
				"Effect %d (%s) chained to [%s]" % [idx, effect_type, ", ".join(chain_names)],
				debug_enabled)


func _on_all_effects_completed() -> void:
	_is_playing = false
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
		else:
			_start_effects(true)
		return

	# Truly complete
	completed.emit()

	JuiceLogger.log_info(self, _get_domain_tag(),
			"All effects completed (iterations=%d)" % _current_iteration,
			debug_enabled)

	# Execute queued trigger
	if not _queued_trigger.is_empty():
		var queued := _queued_trigger
		_queued_trigger = {}
		_handle_trigger(queued)


# D2: Stop sibling JuiceBase nodes whose effects share an interrupt identity
# with any effect in this node that has interrupt_siblings = true.
# Only called on new triggers (not loop restarts) to ensure consistent event propagation.
# `interrupt_siblings and not is_one_shot_return` guard.
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
					JuiceLogger.log_info(self, _get_domain_tag(),
							"Interrupted sibling '%s'" % sibling.name,
							debug_enabled)
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

# Sequencer retrigger gate — mirrors STACK's retrigger logic but for sequences.
func _seq_request_sequence(is_reverse: bool, is_one_shot_return: bool = false) -> void:
	if _is_playing:
		match retrigger_policy:
			RetriggerPolicy.IGNORE:
				JuiceLogger.log_info(self, _get_domain_tag(), "Seq retrigger IGNORED", debug_enabled)
				return
			RetriggerPolicy.QUEUE:
				_queued_trigger = {"play_in": not is_reverse, "is_one_shot_return": is_one_shot_return}
				JuiceLogger.log_info(self, _get_domain_tag(), "Seq retrigger QUEUED", debug_enabled)
				return
			RetriggerPolicy.RESTART:
				JuiceLogger.log_info(self, _get_domain_tag(), "Seq retrigger RESTART", debug_enabled)
				_seq_stop()

	# Initialize loop/ping-pong state on fresh triggers (not internal restarts)
	if not is_one_shot_return and _seq_current_loop == 0 and _seq_pp_current_cycle == 0:
		_seq_playing_reverse = is_reverse
		_seq_initial_reverse = is_reverse
		_seq_pp_forward = true

	_seq_start_sequence(is_reverse, is_one_shot_return)

# Stop all sequencer animations cleanly.
func _seq_stop() -> void:
	_seq_generation += 1  # Abort any in-flight coroutines
	_is_playing = false
	_queued_trigger = {}
	_seq_active_animations = 0
	_seq_pp_forward = true
	_seq_pp_current_cycle = 0
	_seq_current_loop = 0
	
	# Sequencer memory leak fix: ensure we wipe our active ledgers natively
	# before clearing the target tracking dictionaries.
	if juice_source == JuiceSource.RECIPE:
		for target_variant: Variant in _seq_target_active_indices.keys():
			var target := target_variant as Node
			if is_instance_valid(target):
				_seq_restore_target_natural(target)
				JuiceLedger.flush(target)
		for entry in _seq_held_entries:
			var target := entry.get("target") as Node
			if is_instance_valid(target) and not _seq_target_active_indices.has(target):
				_seq_restore_target_natural(target)
				JuiceLedger.flush(target)

	_seq_target_active_indices.clear()
	_seq_held_entries.clear()

	# Stop all per-target effect clones — call stop() unconditionally so that
	# VFX effects (which complete near-instantly) still get _restore_to_natural()
	# called. Without this, particles from a previous preview persist into replays
	# because is_playing() returns false before stop is attempted.
	for target_variant: Variant in _seq_target_effects.keys():
		var target: Node = target_variant as Node
		var effects: Array = _seq_target_effects.get(target_variant, []) as Array
		for effect_variant: Variant in effects:
			var effect: JuiceEffectBase = effect_variant as JuiceEffectBase
			if effect != null and target != null:
				effect.stop(target)
	_seq_target_effects.clear()

	JuiceLogger.log_info(self, _get_domain_tag(), "Seq stopped", debug_enabled)


# Core sequencing coroutine — staggers animation across targets.
func _seq_start_sequence(is_reverse: bool, is_one_shot_return: bool = false) -> void:
	_is_playing = true
	_seq_playing_reverse = is_reverse

	# Capture generation for stale coroutine detection
	_seq_generation += 1
	var my_gen := _seq_generation

	# Get filtered and ordered targets early — needed for warmup before delay
	var targets := _get_seq_targets()

	if targets.is_empty():
		JuiceLogger.log_info(self, _get_domain_tag(), "Seq: no targets found", debug_enabled)
		_is_playing = false
		completed.emit()
		return

	targets = _apply_seq_stagger_order(targets, is_reverse)
	_seq_active_animations = 0

	# Safety guard — orch is always created in _ready(), so this is a no-op in normal
	# operation. Defensive check only.
	if _runtime_orchestrator == null or not is_instance_valid(_runtime_orchestrator):
		_runtime_orchestrator = JuiceOrchestratorFactory.create(self, recipe, _target_node, JuiceOrchestrator.Mode.RUNTIME)
		add_child(_runtime_orchestrator)
	# else: existing orch already ticking — zero-allocation retrigger

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

	JuiceLogger.log_info(self, _get_domain_tag(),
			"Seq starting with %d targets, delay=%.2f, reverse=%s" % [
			targets.size(), seq_stagger_delay, is_reverse],
			debug_enabled)

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


# Animate a single target based on juice_source mode.
func _seq_animate_target(target: Node, is_reverse: bool) -> void:
	match juice_source:
		JuiceSource.RECIPE:
			_seq_animate_target_recipe(target, is_reverse)
		JuiceSource.TARGETS_STACK:
			_seq_animate_target_stack(target, is_reverse)
		JuiceSource.TARGETS_CHILDREN:
			_seq_animate_target_children(target, is_reverse)


# RECIPE mode: clone recipe effects per target and start them.
# Effects are ticked by _seq_process_tick() in _process().
func _seq_animate_target_recipe(target: Node, is_reverse: bool) -> void:
	if recipe == null:
		return

	var effects := _seq_get_or_create_target_effects(target)
	if effects.is_empty():
		return

	# Find root effect indices (not chained from another in this set)
	var chained_set: Array[JuiceEffectBase] = []
	for eff in effects:
		if eff != null:
			chained_set.append_array(eff.chain_to)
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

	# Write immediately so first-frame state is correct (same as STACK mode).
	# Without this, the target sits at natural state for one frame → visible flash.
	_seq_post_tick_write_target(target, effects)

	JuiceLogger.log_info(self, _get_domain_tag(),
			"Seq RECIPE: started %d roots on '%s'" % [root_indices.size(), target.name],
			debug_enabled)


# TARGETS_STACK mode: find JuiceBase nodes inside a named container on target.
func _seq_animate_target_stack(target: Node, is_reverse: bool) -> void:
	var stack := target.get_node_or_null(seq_stack_name)
	if stack == null:
		JuiceLogger.warn(self, _get_domain_tag(),
				"Seq STACK: target '%s' has no stack '%s'" % [target.name, seq_stack_name],
				debug_enabled)
		return

	var juice_nodes: Array[JuiceBase] = []
	for child in stack.get_children():
		if child is JuiceBase:
			juice_nodes.append(child as JuiceBase)

	if juice_nodes.is_empty():
		JuiceLogger.warn(self, _get_domain_tag(),
				"Seq STACK: stack '%s' on '%s' has no JuiceBase children" % [seq_stack_name, target.name],
				debug_enabled)
		return

	_seq_trigger_juice_nodes(juice_nodes, is_reverse, target.name, "STACK")


# TARGETS_CHILDREN mode: find JuiceBase children directly on target.
func _seq_animate_target_children(target: Node, is_reverse: bool) -> void:
	var juice_nodes: Array[JuiceBase] = []
	for child in target.get_children():
		if child is JuiceBase:
			juice_nodes.append(child as JuiceBase)

	if juice_nodes.is_empty():
		JuiceLogger.warn(self, _get_domain_tag(),
				"Seq CHILDREN: target '%s' has no JuiceBase children" % target.name,
				debug_enabled)
		return

	_seq_trigger_juice_nodes(juice_nodes, is_reverse, target.name, "CHILDREN")


# Shared helper: trigger a list of JuiceBase nodes and track their completion.
func _seq_trigger_juice_nodes(juice_nodes: Array[JuiceBase], is_reverse: bool, target_name: String, mode_label: String) -> void:
	for juice in juice_nodes:
		_seq_active_animations += 1
		if not juice.completed.is_connected(_seq_on_ext_juice_completed):
			juice.completed.connect(_seq_on_ext_juice_completed)
		if is_reverse:
			juice.animate_out()
		else:
			juice.animate_in()

	JuiceLogger.log_info(self, _get_domain_tag(),
			"Seq %s: triggered %d JuiceBase nodes on '%s'" % [mode_label, juice_nodes.size(), target_name],
			debug_enabled)


# Callback when an externally-triggered JuiceBase node completes (STACK/CHILDREN modes).
func _seq_on_ext_juice_completed() -> void:
	_seq_active_animations = maxi(0, _seq_active_animations - 1)


# Get or create per-target runtime effect clones for RECIPE mode.
func _seq_get_or_create_target_effects(target: Node) -> Array[JuiceEffectBase]:
	if _seq_target_effects.has(target):
		return _seq_target_effects[target] as Array[JuiceEffectBase]

	if recipe == null:
		return []

	var clones: Array[JuiceEffectBase] = recipe.create_runtime_effects()
	_seq_target_effects[target] = clones

	JuiceLogger.log_info(self, _get_domain_tag(),
			"Created %d effect clones for target '%s'" % [clones.size(), target.name],
			debug_enabled)

	return clones


# Pre-position all targets at their From state before the stagger loop begins.
# For Control targets inside Containers, registers a hold entry so the From state
# is re-applied every frame (beating Container re-sort). 2D/3D get one-shot only.
func _seq_warmup_recipe_targets(targets: Array[Node], is_reverse: bool) -> void:
	_seq_held_entries.clear()
	var play_in := not is_reverse

	for target in targets:
		# Seed the Ledger with the target's current natural position BEFORE effects
		# read it via JuiceLedger.get_base_dict(). On first preview the Ledger is
		# empty (no STACK node has called _capture_base_values() yet), so SELF
		# snapshots would fall back to Vector2.ZERO without this call.
		_seq_ensure_ledger_for_target(target)

		var effects := _seq_get_or_create_target_effects(target)
		if effects.is_empty():
			continue

		# Start effects at From state (progress 0.0 for in, 1.0 for out)
		# then write deltas to target as a one-shot.
		for eff in effects:
			# Inject ledger base: the warmup path calls _on_animate_start directly (not via
			# effect.start()), so it needs manual injection. TO=SELF snapshots captured here
			# should read the target's natural ledger base position, not its warmup-modified state.
			eff._ledger_base_snapshot = JuiceLedger.get_base_dict(target)
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

	JuiceLogger.log_info(self, _get_domain_tag(),
			"Seq warmup: %d targets, %d held" % [targets.size(), _seq_held_entries.size()],
			debug_enabled)


# Release held entries for a target when its real animation starts.
func _seq_release_held_for_target(target: Node) -> void:
	for i in range(_seq_held_entries.size() - 1, -1, -1):
		if _seq_held_entries[i].get("target") == target:
			_seq_held_entries.remove_at(i)


# Tick all per-target effects in SEQUENCER RECIPE mode.
# Called from _process() when mode == SEQUENCER.
# Handles chaining and per-target completion tracking.
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
			elif result == JuiceEffectBase.TickResult.RESTART_REVERSED:
				# REVERSE_EASED accumulation: direction already flipped — restart easing from 0
				effect.start(target, true, false, self)

		# Chained preroll: start chained effects early for overlap
		for idx_variant2: Variant in active_indices:
			var pidx: int = idx_variant2 as int
			if pidx < 0 or pidx >= effects.size():
				continue
			var peff: JuiceEffectBase = effects[pidx] as JuiceEffectBase
			if peff == null or not peff.is_playing():
				continue
			if peff.chain_to.is_empty() or peff.chained_preroll <= 0.0:
				continue
			if peff._chained_preroll_triggered:
				continue
			if peff._get_time_to_completion() <= peff.chained_preroll:
				for chained_effect in peff.chain_to:
					var chain_idx := effects.find(chained_effect)
					if chain_idx >= 0 and chain_idx not in active_indices:
						var chained: JuiceEffectBase = effects[chain_idx] as JuiceEffectBase
						if chained != null:
							var play_in := peff._animation_progress >= 0.5
							chained.start(target, play_in, false, self)
							active_indices.append(chain_idx)
							any_playing = true
				peff._chained_preroll_triggered = true

		# Write aggregated deltas to target (domain-specific)
		_seq_post_tick_write_target(target, effects)

		# Handle chaining within this target's effects (skip if preroll already started)
		for idx in newly_completed:
			var effect: JuiceEffectBase = effects[idx] as JuiceEffectBase
			if effect != null and not effect.chain_to.is_empty() and not effect._chained_preroll_triggered:
				for chained_effect in effect.chain_to:
					var chain_idx := effects.find(chained_effect)
					if chain_idx >= 0 and chain_idx not in active_indices:
						var chained: JuiceEffectBase = effects[chain_idx] as JuiceEffectBase
						if chained != null:
							var play_in := effect._animation_progress >= 0.5
							chained.start(target, play_in, false, self)
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

	# No set_process(false) here — _seq_on_pass_complete() frees the orchestrator when done.


# Called when a full sequence pass completes (all targets done).
# Handles ping-pong cycling, PLAY_IN_AND_OUT auto-reverse, non-ping-pong
# looping, hide_parent_on_reverse_complete, and final completion.
func _seq_on_pass_complete(is_reverse: bool, is_one_shot_return: bool, my_gen: int) -> void:
	JuiceLogger.log_info(self, _get_domain_tag(),
			"Seq pass complete (reverse=%s, osr=%s)" % [is_reverse, is_one_shot_return],
			debug_enabled)

	# --- Ping-pong cycling ---
	# Forward leg → reverse leg = 1 cycle. Superset of PLAY_IN_AND_OUT auto-reverse.
	if trigger_behaviour == JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT \
			and not is_one_shot_return:
		if _seq_pp_forward:
			# Forward leg just completed → start reverse leg
			_seq_pp_forward = false
			JuiceLogger.log_info(self, _get_domain_tag(),
					"Seq ping-pong: forward → reverse", debug_enabled)
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
				JuiceLogger.log_info(self, _get_domain_tag(),
						"Seq ping-pong: cycle %d/%s → next" % [
						_seq_pp_current_cycle, str(loop_count)],
						debug_enabled)
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
			JuiceLogger.log_info(self, _get_domain_tag(),
					"Seq loop: pass %d/%s → next" % [
					_seq_current_loop, str(loop_count)],
					debug_enabled)
			if loop_delay > 0.0:
				await get_tree().create_timer(loop_delay).timeout
				if _seq_generation != my_gen:
					return
			# Clear the clone cache before each loop restart — same reason as _seq_stop:
			# effect clones carry _has_base=true from the completed iteration. Reusing
			# them causes warmup to compute a stale FROM delta (post-animation position),
			# snapping targets to TO on the first frame of the new iteration.
			_seq_target_effects.clear()
			_seq_start_sequence(_seq_initial_reverse)
			return

	# --- Sequence fully complete ---
	_is_playing = false
	# Orch stays alive — idle no-op ticks until next sequence or node freed.
	# Drop the per-target clone cache so the next play creates fresh effects.
	# The cache is a live-session resource — effect clones accumulate base-capture
	# state (_has_base=true) during a run. Keeping them alive across plays causes
	# subsequent animate_in() calls to snap rather than animate, because
	# _on_animate_start skips re-capture when _has_base is already set.
	# Internal loops are safe: they call _seq_start_sequence() and return before
	# reaching this block, so the cache stays live for the full loop session.
	_seq_target_effects.clear()

	JuiceLogger.log_info(self, _get_domain_tag(), "Seq fully complete", debug_enabled)

	# Handle hide_parent_on_reverse_complete (only after FINAL reverse)
	if is_reverse and seq_hide_parent_on_reverse_complete:
		var parent := get_parent()
		if parent and parent is CanvasItem:
			parent.hide()
			JuiceLogger.log_info(self, _get_domain_tag(),
					"Hiding parent '%s' after reverse complete" % parent.name,
					debug_enabled)

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


# Free the RUNTIME orchestrator explicitly.
# NOT called in normal animation lifecycle (stop, complete, seq_stop) — the orch persists
# for zero-allocation retriggers. Only call this for exceptional teardown (e.g. scene reload,
# explicit destruction of the Juice node while wanting to shed the orch immediately).
func _free_runtime_orchestrator() -> void:
	if _runtime_orchestrator != null and is_instance_valid(_runtime_orchestrator):
		_runtime_orchestrator.queue_free()
	_runtime_orchestrator = null


## Returns the domain tag string for logging ("Control", "2D", "3D").
## Base returns "Base". Domain subclasses override.
func _get_domain_tag() -> String:
	return "Base"


## Pre-tick hook: detect external moves (something else changed the target).
## Called once per frame BEFORE effects are ticked.
func _pre_tick() -> void:
	pass


## Post-tick hook: aggregate all effect deltas and write to target ONCE.
## Called once per frame AFTER all effects have been ticked.
## Also called by stop() to write natural state after contributions are cleared.
func _post_tick_write() -> void:
	pass


# Flush Ledger entries for cross-node PropertyTarget resolved nodes.
# PropertyJuiceEffectBase._apply_effect() registers deltas on the RESOLVED
# node (e.g. OmniLight3D via node_path), but each domain's _post_tick_write()
# only flushes _target_node. This helper iterates Property effects to find
# any resolved nodes that differ from the main target and flushes them.
# Call from each domain's _post_tick_write() AFTER the main flush() call.
func _flush_cross_node_property_targets() -> void:
	if _target_node == null:
		return
	# Collect unique cross-node targets (avoid flushing the same node twice).
	var flushed: Array[Node] = []
	for effect in _runtime_effects:
		if effect == null:
			continue
		var prop_eff := effect as PropertyJuiceEffectBase
		if prop_eff == null:
			continue
		for pt in prop_eff.property_targets:
			if pt == null:
				continue
			var resolved: Node = pt.get_target_node()
			if resolved == null or not is_instance_valid(resolved):
				continue
			if resolved == _target_node:
				continue  # Already flushed by domain's main flush()
			if resolved in flushed:
				continue  # Already flushed this frame
			JuiceLedger.flush(resolved)
			flushed.append(resolved)

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
## IMPORTANT: non-permanent (false) — STACK JuiceControls own the ledger lifecycle.
## The sequencer is a writer, not the owner. Permanently destroying the ledger would
## erase the natural base that other JuiceControls (hover, scene-action, etc.) rely on.
func _seq_restore_target_natural(target: Node) -> void:
	JuiceLedger.cleanup_source(target, self, false)


## Sequencer per-target ledger seeding — called once per target at warmup start.
## Domain subclasses call JuiceLedger.ensure(target, domain_props) here so the
## Ledger base is populated BEFORE effects read it via get_base_dict(). Without
## this seed, the first preview run gets an empty ledger and SELF position
## snapshots fall back to Vector2.ZERO, causing the "jump to 0,0" bug.
## Non-sequencer (STACK) nodes never call this — they have their own
## _capture_base_values() lifecycle.
func _seq_ensure_ledger_for_target(_target: Node) -> void:
	pass


## Sequencer RECIPE mode: aggregate effect deltas and write to target.
## Uses the Centralized Metadata Ledger to sum outputs across cross-stacking nodes
## safely avoiding Container layout suppressions.
func _seq_post_tick_write_target(target: Node, effects: Array) -> void:
	# Aggregate all effect contributions keyed by property name
	var total := {}
	for eff: Variant in effects:
		if eff == null:
			continue
		var contrib: Dictionary = eff._get_seq_contribution()
		for key: String in contrib:
			if key in total:
				if typeof(total[key]) == TYPE_COLOR and typeof(contrib[key]) == TYPE_COLOR:
					var c_tot := total[key] as Color
					var c_con := contrib[key] as Color
					total[key] = Color(c_tot.r * c_con.r, c_tot.g * c_con.g, c_tot.b * c_con.b, c_tot.a * c_con.a)
				else:
					total[key] = total[key] + contrib[key]
			else:
				total[key] = contrib[key]

	var tracked_props: Array[String] = []
	for k in total.keys():
		tracked_props.append(k)

	# The sequencer is a PURE WRITER: ensure ledger exists, clear stale deltas, register
	# new deltas, write. It does NOT call _ledger_update_external_displacement.
	#
	# WHY: External displacement detection belongs to STACK JuiceControls via _pre_tick.
	# They have context about their target (runs every frame while playing, plus JIT at
	# trigger). The sequencer lacks that context and calling displacement detection here
	# causes a critical bug during the warmup → real-animation transition:
	#
	#   _seq_restore_target_natural() zeroes OUR delta in the ledger (permanently=false).
	#   ctrl.position is still at the warmup FROM position (no physical write happened).
	#   → next _seq_post_tick_write_target call: total=0, ctrl=FROM_state, base=Container_Y.
	#   → "idle" path fires: base = ctrl.position = FROM_state. BASE CORRUPTED.
	#   → All subsequent ledger reads (hover, scene-action) use the corrupted base.
	#
	# With deferred _post_ready_init (which fires AFTER Container._sort_children), the
	# ledger base is already the true Container position. The sequencer should trust it.
	JuiceLedger.ensure(target, tracked_props)

	# Zero stale entries from the previous frame. Any property we animated last frame but
	# not this frame (e.g., an effect chain finished one channel) is cleared so it does
	# not accumulate as phantom deltas in the remaining registration step below.
	JuiceLedger.cleanup_source(target, self, false)

	# Write current property offsets into the ledger and resolve absolute value
	for prop in tracked_props:
		var delta: Variant = total[prop]
		JuiceLedger.register_delta(target, self, prop, delta)
		
		var base_val: Variant = JuiceLedger.get_base(target, prop, target.get(prop))
		var total_delta: Variant = JuiceLedger.get_total(target, prop, JuiceLedger.zero_for(base_val))

		if typeof(total_delta) == TYPE_COLOR:
			# Additive Color: base + Σdeltas, clamped to valid range.
			# Appearance effects bypass this path entirely (empty _get_seq_contribution),
			# so only PropertyTarget additive deltas reach here.
			var base_col := base_val as Color
			var tot_col := total_delta as Color
			var result := Color(base_col.r + tot_col.r, base_col.g + tot_col.g, base_col.b + tot_col.b, base_col.a + tot_col.a)
			result = Color(maxf(result.r, 0.0), maxf(result.g, 0.0), maxf(result.b, 0.0), clampf(result.a, 0.0, 1.0))
			target.set(prop, result)
		else:
			target.set(prop, base_val + total_delta)





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

# Called whenever the assigned recipe resource emits changed (editor only).
# Godot's Resource.changed fires on any property edit inside the resource,
# including array mutations and sub-resource property changes.
func _on_recipe_changed() -> void:
	if Engine.is_editor_hint():
		if recipe != null and _editor_register_recipe.is_valid():
			_editor_register_recipe.call(recipe, self)
		update_configuration_warnings()


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

	# Validate chain references point to effects in the same recipe
	if recipe != null and not recipe.effects.is_empty():
		for effect in recipe.effects:
			if effect == null or effect.chain_to.is_empty():
				continue
			for chained in effect.chain_to:
				if chained == null:
					warnings.append("Effect '%s' has a null reference in chain_to array." % effect.get_script().get_global_name())
				elif chained not in recipe.effects:
					warnings.append("Effect '%s' chains to an effect not in the same recipe." % effect.get_script().get_global_name())

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

# Compare every property in the persisted ledger base against the node's

# Resolve the source node for trigger_on hint building in _validate_property.
# Returns null if not in editor, or when the source can't yet be resolved
# (e.g. during initial scene load before get_node is reliable).
# Domain nodes call this from their own _validate_property to get the
# trigger source for TriggerHintBuilder — returns null at runtime (no-op).
func _resolve_hint_source_node() -> Node:
	if not Engine.is_editor_hint():
		return null
	match trigger_source:
		TriggerSource.PARENT:
			return get_parent()
		TriggerSource.NODE:
			if trigger_source_path.is_empty():
				return null
			# Guard: get_tree may be null during early scene load.
			var tree := get_tree()
			if tree == null or tree.edited_scene_root == null:
				return null
			return get_node_or_null(trigger_source_path)
	return null

## Resolve the target node based on mode.
## Subclasses override to validate domain (Control, Node2D, Node3D).
func _resolve_target() -> Node:
	if mode == Mode.STACK:
		return get_parent()
	return null  # SEQUENCER resolves per-target dynamically


# Get filtered list of target nodes for SEQUENCER mode based on target_scope.
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
					JuiceLogger.warn(self, _get_domain_tag(),
							"CUSTOM target not found: %s" % str(path),
							debug_enabled)
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


# Apply sequence ordering to target list, with optional mirror on exit.
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


# Clone recipe effects for independent runtime state.
func _invalidate_runtime_effects() -> void:
	_runtime_effects.clear()
	_active_effect_indices.clear()
	if recipe != null:
		_runtime_effects = recipe.create_runtime_effects()
		# Confirm how many runtime clones were produced. If this is 0 when effects are
		# expected, the recipe is empty or create_runtime_effects() silently failed.
		JuiceLogger.log_info(self, _get_domain_tag(),
				"runtime effects cloned: %d" % _runtime_effects.size(),
				debug_enabled)


# Get indices of root effects (not chained from any other effect).
func _get_root_effect_indices() -> Array[int]:
	var chained_targets: Array[JuiceEffectBase] = []
	for effect in _runtime_effects:
		if effect != null:
			chained_targets.append_array(effect.chain_to)

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
		JuiceTriggerRouter.connect_visibility(_trigger_source_node, _on_visibility_changed)
		return

	# AnimationPlayer: cross-domain, connect animation_finished
	if _trigger_source_node is AnimationPlayer:
		var anim := _trigger_source_node as AnimationPlayer
		if not anim.animation_finished.is_connected(_on_animation_finished):
			anim.animation_finished.connect(_on_animation_finished)
		JuiceLogger.log_info(self, _get_domain_tag(),
				"Auto-connected to AnimationPlayer '%s'" % anim.name,
				debug_enabled)
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


# _connect_visibility_signals  → JuiceTriggerRouter.connect_visibility()
# _connect_manual_signal       → JuiceTriggerRouter.wire_manual()   (inlined in _ready)
# _make_manual_callable        → JuiceTriggerRouter.resolve_manual_callable()

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
			# PLAY_IN_AND_OUT is a one-shot trigger: fires on enter, plays in then
			# auto-reverses to out. The exit edge is intentionally ignored.
			# For paired hover behavior, use Toggle instead.
			if is_on:
				_handle_trigger({"play_in": true})
		JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY:
			if is_on: _handle_trigger({"play_in": true})
		JuiceEffectBase.TriggerBehaviour.PLAY_OUT_ONLY:
			if not is_on: _handle_trigger({"play_in": false})
		JuiceEffectBase.TriggerBehaviour.TOGGLE:
			# Pass is_polarity flag so _handle_trigger uses direction, not flip-flop.
			_handle_trigger({"play_in": is_on, "is_polarity": true})
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


# Callbacks for collision/input events (used by Juice2D, Juice3D subclasses)
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

# Polarity handler for ON_PRESS on non-Button Controls.
# Fires polarity_on on mouse-down, polarity_off on mouse-up.
# This lets Toggle use press=animate_in, release=animate_out rather than flip-flop.
func _on_control_gui_input_press_polarity(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.pressed:
		_on_trigger_polarity_on()
	else:
		_on_trigger_polarity_off()

# Polarity handler for ON_PRESS on CollisionObject2D (input_event signal).
# Fires polarity_on on press, polarity_off on release.
func _on_collision_input_press_polarity_2d(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	if event.pressed:
		_on_trigger_polarity_on()
	else:
		_on_trigger_polarity_off()

# Polarity handler for ON_PRESS on CollisionObject3D (input_event signal).
# Fires polarity_on on press, polarity_off on release.
func _on_collision_input_press_polarity_3d(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	if event.pressed:
		_on_trigger_polarity_on()
	else:
		_on_trigger_polarity_off()

# Filtered mouse button callback for Control gui_input (left/right/middle click).
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

# Ledger helpers live in JuiceLedger.gd (class_name JuiceLedger).
# All callers use JuiceLedger.ensure(), JuiceLedger.register_delta(), etc.
