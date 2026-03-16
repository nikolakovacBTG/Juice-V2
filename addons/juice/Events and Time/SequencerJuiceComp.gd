## SequencerJuiceComp.gd
## ============================================================================
## WHAT: Orchestrates sequenced animations across multiple targets.
## WHY: Lets designers apply one authored set of juice components (including chaining)
##      to many targets with configurable timing and ordering.
## SYSTEM: Juicing System (addons/juice/)
## DOES NOT: Decide what properties a recipe drives; that is defined by the recipe
##      components via the recipe natural baseline contract in JuiceCompBase.
## ============================================================================
##
## THREE JUICE SOURCE MODES:
##
## SEQUENCER'S CHILDREN:
##   - Sequencer has juice children that define the animation "recipe"
##   - Recipe is cloned and applied to each target
##   - Use case: Apply uniform slide-in to all menu buttons without duplicating juice
##
## TARGET'S STACK:
##   - Each target has a named container node (the "stack") holding juice components
##   - Sequencer finds that container by name and triggers all juice inside
##   - Use case: Each button has custom entry animation, sequencer orchestrates timing
##   - Different targets can have different juice under the same stack name
##
## TARGET'S CHILDREN:
##   - Triggers juice components that are direct children of each target
##   - No named container needed — all JuiceCompBase children on each target fire
##   - Use case: Simple setups where targets have their own juice without containers
##
## NESTING:
##   - Because this extends JuiceCompBase, parent sequencers can target child sequencers
##   - Enables cascading: Screen > Panels > Panel Elements
##
## CONNECTIONS:
##   - Targets: Siblings, children, or custom list depending on target_scope
##   - Recipe juice (SEQUENCER'S CHILDREN): Child juice components of this sequencer
##   - Stack juice (TARGET'S STACK): Juice inside target's named container
##   - Direct juice (TARGET'S CHILDREN): Juice as direct children of targets
##
## TRIGGERING:
##   - Inherits full trigger system from JuiceCompBase (trigger_on, bidirectional, trigger_source_path)
##   - Use trigger_source_path to point at a button/container that controls this sequencer
##   - Example: trigger_source_path points to toggle button, trigger_on = ON_PRESS, bidirectional = true
##     -> Button pressed = animate_in(), Button released/untoggled = animate_out()
##   - Optional: hide_parent_on_reverse_complete hides parent after exit animation finishes
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBaseEvents.svg")
class_name SequencerJuiceComp
extends JuiceCompBase

# =============================================================================
# ENUMS
# =============================================================================

## How this sequencer sources its juice animations.
enum JuiceSource {
	SEQUENCERS_CHILDREN,  ## Clone our juice children as "recipe" onto all targets
	TARGETS_STACK,        ## Trigger juice inside a named container on each target
	TARGETS_CHILDREN      ## Trigger juice that are direct children of each target
}

## What nodes to animate
enum TargetScope {
	SIBLINGS,  ## Animate siblings of this sequencer (parent's other children)
	CHILDREN,  ## Animate children of parent (useful when sequencer is child of container)
	CUSTOM     ## Use a manually authored list of targets
}

## How targets are ordered and timed during the sequence.
enum SequenceType {
	STAGGER_FORWARD,  ## First to last with delay between each
	STAGGER_REVERSE,  ## Last to first with delay between each
	RANDOM,           ## Random order with delay between each
	ALL_AT_ONCE       ## All targets fire simultaneously on the same frame
}

# =============================================================================
# INSPECTOR PROPERTIES (managed via _get_property_list for conditional visibility)
# =============================================================================

## --- Sequencer Mode group ---

## Where this sequencer gets its juice from
var juice_source: int = JuiceSource.SEQUENCERS_CHILDREN:
	set(value):
		juice_source = value
		notify_property_list_changed()

## Which nodes to target for animation
var target_scope: int = TargetScope.SIBLINGS:
	set(value):
		target_scope = value
		notify_property_list_changed()

## Manually authored list of target nodes (visible only when target_scope == CUSTOM)
var custom_targets: Array[NodePath] = []

## Name of the container node holding juice on each target
## (visible only when juice_source == TARGETS_STACK)
var stack_name: String = ""

## --- Sequence group ---

## Order and timing strategy for the sequence
var sequence_type: int = SequenceType.STAGGER_FORWARD:
	set(value):
		sequence_type = value
		notify_property_list_changed()

## Time delay between targets. Display name changes based on sequence_type:
## "Stagger Delay" for stagger types, "Delay" for random. Hidden for All At Once.
var _delay: float = 0.1

## Mirror the stagger direction when playing the exit animation.
## Example: Stagger Forward on entry → Stagger Reverse on exit.
## (visible only for STAGGER_FORWARD and STAGGER_REVERSE)
var mirror_stagger_on_exit: bool = true

## --- Filtering group ---

## Skip targets that are not visible
var skip_invisible: bool = true

## Skip self when targeting siblings (almost always true)
var skip_self: bool = true

## Skip targets that are JuiceCompBase (don't animate our own juice children in sibling mode)
var skip_juice_components: bool = true

## --- Completion Actions group ---

## When the exit animation completes, hide the parent node.
## Useful for menu exit animations - sequence plays out, then parent hides.
## Only triggers on reverse completion, not forward completion.
var hide_parent_on_reverse_complete: bool = false

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Tracks active animations for completion detection
var _active_animations: int = 0

## Cached list of recipe juice components (SEQUENCERS_CHILDREN mode)
var _recipe_juice: Array[JuiceCompBase] = []

## True when we're playing in reverse (affects stagger order if mirror_stagger_on_exit is true)
var _playing_reverse: bool = false

## Ping-pong state: true = forward leg (animate_in), false = reverse leg (animate_out)
## Only used when inherited ping_pong bool is true.
var _pp_forward: bool = true

## Counts completed full ping-pong cycles (forward + reverse = 1 cycle).
## Compared against loop_count to determine when to stop.
var _pp_current_cycle: int = 0

## Non-ping-pong loop counter. Counts completed sequence passes.
## For PLAY_IN_AND_OUT, one pass = forward + auto-reverse.
var _seq_current_loop: int = 0

## Coroutine generation counter. Incremented on stop() and new sequence starts.
## Each coroutine captures its generation at birth; if the global counter has
## advanced past it after an await, the coroutine aborts silently.
## This prevents stale coroutines from racing with new ones on retrigger.
var _seq_generation: int = 0

## The direction of the initial trigger (false = forward, true = reverse).
## Used to restart loops from the correct direction.
var _seq_initial_reverse: bool = false

## Persistent per-target state for SEQUENCERS_CHILDREN (recipe) mode.
## Keys: target node, Values: Dictionaries with:
## - template_to_clone: Dictionary (template -> clone)
## - natural_by_template: Dictionary (template -> Variant)
## - entrypoints: Array[JuiceCompBase] (root clones)
## - tails: Array[JuiceCompBase] (last internal clone in each root chain)
var _recipe_target_states: Dictionary = {}

# --- EDITOR CACHE for IN_EDITOR capture mode (SEQUENCERS_CHILDREN only) ---
# Stores per-target transforms at editor time, keyed by relative node path.
# The Sequencer injects these into recipe clones so each target gets its own
# pre-baked Self value, preventing the frame-0 flash.
var _editor_target_caches: Dictionary = {}

# Clones being "held" at a fixed progress (From/To state) every _process frame.
# Needed for Control targets inside Containers: the Container layout re-sort
# overrides one-shot position writes, so we must continuously enforce the
# pre-positioned state until the target's real animation starts.
# Each entry: {"target": Node, "clone": JuiceCompBase, "progress": float}
var _held_entries: Array[Dictionary] = []


# =============================================================================
# INSPECTOR: CONDITIONAL PROPERTY VISIBILITY
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	
	# --- Sequencer Mode group ---
	props.append({"name": "Sequencer Mode", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	
	props.append({
		"name": "juice_source",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Sequencer's Children,Target's Stack,Target's Children",
		"usage": PROPERTY_USAGE_DEFAULT,
	})
	
	props.append({
		"name": "target_scope",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Siblings,Children,Custom",
		"usage": PROPERTY_USAGE_DEFAULT,
	})
	
	if target_scope == TargetScope.CUSTOM:
		props.append({
			"name": "custom_targets",
			"type": TYPE_ARRAY,
			"hint": PROPERTY_HINT_TYPE_STRING,
			"hint_string": "%d:" % TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	
	if juice_source == JuiceSource.TARGETS_STACK:
		props.append({
			"name": "stack_name",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
			"hint_string": "JuiceStack",
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	
	# --- Sequence group ---
	props.append({"name": "Sequence", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	
	props.append({
		"name": "sequence_type",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Stagger Forward,Stagger Reverse,Random,All At Once",
		"usage": PROPERTY_USAGE_DEFAULT,
	})
	
	# Delay: hidden for ALL_AT_ONCE, display name varies by sequence type
	if sequence_type != SequenceType.ALL_AT_ONCE:
		var is_stagger := sequence_type in [SequenceType.STAGGER_FORWARD, SequenceType.STAGGER_REVERSE]
		var delay_name := "stagger_delay" if is_stagger else "delay"
		props.append({
			"name": delay_name,
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,10.0,0.01,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	
	# Mirror stagger: only relevant for directional stagger types
	if sequence_type in [SequenceType.STAGGER_FORWARD, SequenceType.STAGGER_REVERSE]:
		props.append({
			"name": "mirror_stagger_on_exit",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	
	# --- Filtering group ---
	props.append({"name": "Filtering", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	
	props.append({"name": "skip_invisible", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "skip_self", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "skip_juice_components", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})
	
	# --- Completion Actions group ---
	props.append({"name": "Completion Actions", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	
	props.append({"name": "hide_parent_on_reverse_complete", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})
	
	# Editor target caches — serialized (STORAGE only) when non-empty
	if not _editor_target_caches.is_empty():
		props.append({"name": "_editor_target_caches", "type": TYPE_DICTIONARY,
			"usage": PROPERTY_USAGE_STORAGE})
	
	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		# --- Sequencer Mode group ---
		&"juice_source":
			juice_source = int(value) if value != null else JuiceSource.SEQUENCERS_CHILDREN
			return true
		&"target_scope":
			target_scope = int(value) if value != null else TargetScope.SIBLINGS
			return true
		&"custom_targets":
			custom_targets = value if value != null else []
			return true
		&"stack_name":
			stack_name = str(value) if value != null else ""
			return true
		# --- Sequence group ---
		&"sequence_type":
			sequence_type = int(value) if value != null else SequenceType.STAGGER_FORWARD
			return true
		# Both display names ("stagger_delay" and "delay") map to the same backing variable
		&"stagger_delay", &"delay":
			_delay = float(value) if value != null else 0.1
			return true
		&"mirror_stagger_on_exit":
			mirror_stagger_on_exit = bool(value) if value != null else true
			return true
		# --- Filtering group ---
		&"skip_invisible":
			skip_invisible = bool(value) if value != null else true
			return true
		&"skip_self":
			skip_self = bool(value) if value != null else true
			return true
		&"skip_juice_components":
			skip_juice_components = bool(value) if value != null else true
			return true
		# --- Completion Actions group ---
		&"hide_parent_on_reverse_complete":
			hide_parent_on_reverse_complete = bool(value) if value != null else false
			return true
		# Editor target caches (deserialization)
		&"_editor_target_caches":
			_editor_target_caches = value if value is Dictionary else {}
			return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		# --- Sequencer Mode group ---
		&"juice_source":
			return juice_source
		&"target_scope":
			return target_scope
		&"custom_targets":
			return custom_targets
		&"stack_name":
			return stack_name
		# --- Sequence group ---
		&"sequence_type":
			return sequence_type
		&"stagger_delay", &"delay":
			return _delay
		&"mirror_stagger_on_exit":
			return mirror_stagger_on_exit
		# --- Filtering group ---
		&"skip_invisible":
			return skip_invisible
		&"skip_self":
			return skip_self
		&"skip_juice_components":
			return skip_juice_components
		# --- Completion Actions group ---
		&"hide_parent_on_reverse_complete":
			return hide_parent_on_reverse_complete
		&"_editor_target_caches":
			return _editor_target_caches
	return null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _notification(what: int) -> void:
	# Bake per-target transforms into editor cache right before the scene is saved.
	# This ensures IN_EDITOR Self values are fresh for all Sequencer targets.
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_update_editor_target_caches()


func _ready() -> void:
	# In SEQUENCERS_CHILDREN mode, cache recipe and queue warmup BEFORE
	# super._ready(). super queues _handle_trigger as deferred — by queuing
	# warmup first, the deferred call order becomes:
	#   1. _warmup_recipe_targets  (creates clones + pre-positions at From)
	#   2. _handle_trigger          (fires the sequence with start_delay/stagger)
	# This ensures targets appear at their From state from the first frame,
	# independent of trigger timing or start_delay.
	if juice_source == JuiceSource.SEQUENCERS_CHILDREN:
		_cache_recipe_juice()
		call_deferred("_warmup_recipe_targets")
	
	# Call parent _ready() for standard juice setup (queues _handle_trigger)
	super._ready()


func _process(delta: float) -> void:
	# Maintain held Control targets at their From/To state every frame.
	# Container layout re-sorts override one-shot position writes, so we
	# must continuously enforce the pre-positioned state until the target's
	# real animation starts (animate_in/out via stagger).
	for held in _held_entries:
		var clone: JuiceCompBase = held.get("clone") as JuiceCompBase
		if clone != null:
			clone._apply_effect(held.get("progress", 0.0))

	# No held entries left — disable processing to avoid wasted work.
	# The base class _process is not needed (Sequencer's _apply_effect is a no-op).
	if _held_entries.is_empty():
		set_process(false)


## Remove all held entries for a given target. Called when the target's
## real animation starts (animate_in/out), so the hold loop stops enforcing
## the From state and the animation takes over smoothly.
func _release_held_entries_for_target(target: Node) -> void:
	for i in range(_held_entries.size() - 1, -1, -1):
		if _held_entries[i].get("target") == target:
			_held_entries.remove_at(i)


## Cache juice component children to use as animation recipe (SEQUENCERS_CHILDREN mode)
func _cache_recipe_juice() -> void:
	_recipe_juice.clear()
	
	for child in get_children():
		if child is JuiceCompBase:
			# Disable auto-connect on recipe juice - we trigger them manually
			child.auto_connect_parent = false
			_recipe_juice.append(child)
	
	if debug_enabled:
		print("[%s] Cached %d recipe juice components" % [name, _recipe_juice.size()])

# =============================================================================
# PUBLIC API OVERRIDES
# =============================================================================

## Start the sequenced animation IN (entry animation)
func animate_in() -> void:
	_playing_reverse = false
	_pp_forward = true
	_pp_current_cycle = 0
	_seq_current_loop = 0
	_seq_initial_reverse = false
	_request_sequence(false)


## Start the sequenced animation OUT (exit animation)
func animate_out(is_one_shot_return: bool = false) -> void:
	_playing_reverse = true
	if not is_one_shot_return:
		_seq_current_loop = 0
		_seq_initial_reverse = true
	_request_sequence(true, is_one_shot_return)


## Toggle-friendly method for connecting to Button.toggled(bool) signal
## pressed=true animates in, pressed=false animates out
func toggle(pressed: bool) -> void:
	if pressed:
		animate_in()
	else:
		animate_out()


## Stop all active animations
func stop() -> void:
	_seq_generation += 1  # Abort any in-flight coroutines
	_is_playing = false
	_queued_trigger = {}
	_active_animations = 0
	_pp_forward = true
	_pp_current_cycle = 0
	_seq_current_loop = 0
	_held_entries.clear()
	
	if juice_source == JuiceSource.SEQUENCERS_CHILDREN:
		# Stop all active clones across all targets.
		for target in _recipe_target_states.keys():
			var state: Dictionary = _recipe_target_states.get(target, {})
			var template_to_clone: Dictionary = state.get("template_to_clone", {})
			for clone in template_to_clone.values():
				if clone is JuiceCompBase and (clone as JuiceCompBase).is_playing():
					(clone as JuiceCompBase).stop()
	else:
		# TARGETS_STACK / TARGETS_CHILDREN modes stop the targets' juice directly.
		# We do not track them as clones.
		pass
	
	if debug_enabled:
		print("[%s] Stopped all animations" % name)


func reset_to_natural() -> void:
	if juice_source != JuiceSource.SEQUENCERS_CHILDREN:
		return

	for target_variant: Variant in _recipe_target_states.keys():
		var target := target_variant as Node
		if target == null:
			continue
		if not is_instance_valid(target):
			continue
		var state: Dictionary = _recipe_target_states[target] as Dictionary
		if not bool(state.get("naturals_captured", false)):
			continue
		var template_to_clone: Dictionary = state.get("template_to_clone") as Dictionary
		var natural_by_template: Dictionary = state.get("natural_by_template") as Dictionary
		for template_variant: Variant in template_to_clone.keys():
			var clone_variant: Variant = template_to_clone.get(template_variant)
			var clone: JuiceCompBase = clone_variant as JuiceCompBase
			if clone == null:
				continue
			var natural: Variant = natural_by_template.get(template_variant)
			clone._recipe_restore_natural(target, natural)
			clone._animation_progress = 0.0


func _request_sequence(is_reverse: bool, is_one_shot_return: bool = false) -> void:
	var effective_policy: RetriggerPolicy = retrigger_policy
	if _is_playing:
		match effective_policy:
			RetriggerPolicy.IGNORE:
				if debug_enabled:
					print("[%s] Retrigger IGNORED (sequence in progress)" % name)
				return
			RetriggerPolicy.QUEUE_ONE:
				_queued_trigger = {"is_reverse": is_reverse, "is_one_shot_return": is_one_shot_return}
				if debug_enabled:
					print("[%s] Retrigger QUEUED (sequence in progress)" % name)
				return
			RetriggerPolicy.RESTART:
				# Stop the current sequence cleanly before restarting.
				# This increments _seq_generation, causing in-flight coroutines to abort.
				if debug_enabled:
					print("[%s] Retrigger RESTART — stopping current sequence" % name)
				stop()

	_start_sequence(is_reverse, is_one_shot_return)

# =============================================================================
# CORE SEQUENCING LOGIC
# =============================================================================

## Start the staggered animation sequence
func _start_sequence(is_reverse: bool, is_one_shot_return: bool = false) -> void:
	_is_playing = true
	
	# Capture generation for this coroutine. If a newer sequence starts (retrigger/stop),
	# _seq_generation advances and this coroutine aborts at its next await checkpoint.
	_seq_generation += 1
	var my_gen := _seq_generation
	
	# Handle start delay (skip for one_shot return and internal loop/ping-pong restarts)
	if start_delay > 0.0 and not is_one_shot_return and _seq_current_loop == 0 and _pp_current_cycle == 0:
		await get_tree().create_timer(start_delay).timeout
		if _seq_generation != my_gen:
			return  # Aborted by retrigger
	
	# Get filtered and ordered targets
	var targets := _get_targets()
	
	if targets.is_empty():
		if debug_enabled:
			print("[%s] No targets found - completing immediately" % name)
		_is_playing = false
		completed.emit()
		return
	
	# Apply stagger order
	targets = _apply_stagger_order(targets, is_reverse)
	
	# Reset animation counter
	_active_animations = 0
	
	# Emit started signal only on the very first pass (not on loops or ping-pong legs)
	if not is_one_shot_return and _seq_current_loop == 0 and (not ping_pong or _pp_forward):
		started.emit()
	
	if debug_enabled:
		var reverse_str := " (REVERSE)" if is_reverse else ""
		var loop_str := ""
		if ping_pong:
			loop_str = " [pp_cycle=%d pp_fwd=%s]" % [_pp_current_cycle, str(_pp_forward)]
		elif loop_count != 1:
			loop_str = " [loop=%d/%s]" % [_seq_current_loop + 1, str(loop_count)]
		print("[%s] Starting sequence%s%s with %d targets, delay: %.2fs" % [
			name, reverse_str, loop_str, targets.size(), _delay])
	
	# Animate each target with delay (ALL_AT_ONCE skips delay entirely)
	for i in range(targets.size()):
		var target := targets[i]
		
		# Wait for delay between targets (except first target, and not for ALL_AT_ONCE)
		if i > 0 and sequence_type != SequenceType.ALL_AT_ONCE and _delay > 0.0:
			await get_tree().create_timer(_delay).timeout
			if _seq_generation != my_gen:
				return  # Aborted by retrigger
		
		# Animate this target
		await _animate_target(target, is_reverse)
		if _seq_generation != my_gen:
			return  # Aborted by retrigger
	
	# Wait for all animations to complete
	# Note: _active_animations is decremented by completion callbacks
	while _active_animations > 0:
		await get_tree().process_frame
		if _seq_generation != my_gen:
			return  # Aborted by retrigger
	
	# --- Ping-pong cycling ---
	# When ping_pong is true, the sequencer oscillates: forward leg → reverse leg = 1 cycle.
	# This replaces PLAY_IN_AND_OUT auto-reverse (ping-pong is a superset of it).
	if ping_pong and not is_one_shot_return:
		if _pp_forward:
			# Forward leg just completed → start reverse leg
			_pp_forward = false
			if debug_enabled:
				print("[%s] Ping-pong: forward leg complete → starting reverse leg" % name)
			if loop_delay > 0.0:
				await get_tree().create_timer(loop_delay).timeout
				if _seq_generation != my_gen:
					return
			_start_sequence(true)
			return
		else:
			# Reverse leg just completed → one full cycle done
			_pp_current_cycle += 1
			_pp_forward = true
			
			# Check if we should continue cycling
			var should_continue := false
			if loop_count < 0:
				should_continue = true  # Infinite
			elif _pp_current_cycle < loop_count:
				should_continue = true
			
			if should_continue:
				if debug_enabled:
					print("[%s] Ping-pong: cycle %d/%s complete → starting next" % [
						name, _pp_current_cycle, str(loop_count)])
				if loop_delay > 0.0:
					await get_tree().create_timer(loop_delay).timeout
					if _seq_generation != my_gen:
						return
				_start_sequence(false)
				return
			# else: all cycles done, fall through to completion below
			if debug_enabled:
				print("[%s] Ping-pong: all %d/%s cycles complete" % [
					name, _pp_current_cycle, str(loop_count)])
	
	# --- PLAY_IN_AND_OUT auto-reverse (non-ping-pong path) ---
	# Direct call to _start_sequence bypasses retrigger check, which is correct
	# because this is an internal continuation, not an external trigger.
	if not ping_pong and _is_play_in_and_out_active and not is_reverse and not is_one_shot_return:
		if debug_enabled:
			print("[%s] PLAY_IN_AND_OUT: forward done → starting auto-reverse" % name)
		_start_sequence(true, true)
		return
	
	# --- Non-ping-pong loop ---
	# At this point the full sequence pass is done (including auto-reverse if applicable).
	# Check if we should loop and replay the sequence from the initial direction.
	if not ping_pong and loop_count != 1:
		_seq_current_loop += 1
		var should_loop := false
		if loop_count < 0:
			should_loop = true  # Infinite
		elif _seq_current_loop < loop_count:
			should_loop = true
		
		if should_loop:
			if debug_enabled:
				print("[%s] Loop: pass %d/%s complete → starting next" % [
					name, _seq_current_loop, str(loop_count)])
			if loop_delay > 0.0:
				await get_tree().create_timer(loop_delay).timeout
				if _seq_generation != my_gen:
					return
			# Restart from the initial trigger direction.
			# For PLAY_IN_AND_OUT, this starts forward; the auto-reverse handles the rest.
			_start_sequence(_seq_initial_reverse)
			return
		
		if debug_enabled:
			print("[%s] Loop: all %d/%s passes complete" % [
				name, _seq_current_loop, str(loop_count)])
	
	# --- Sequence fully complete ---
	completed.emit()
	_is_playing = false
	_is_play_in_and_out_active = false
	_force_play_in_and_out_once = false
	
	if debug_enabled:
		print("[%s] Sequence fully completed" % name)
	
	# Handle hide_parent_on_reverse_complete
	# Only hide parent after the FINAL reverse leg, not intermediate loop/ping-pong legs
	if is_reverse and hide_parent_on_reverse_complete:
		var parent := get_parent()
		if parent and parent is CanvasItem:
			parent.hide()
			if debug_enabled:
				print("[%s] Hiding parent '%s' after reverse complete" % [name, parent.name])
		elif debug_enabled:
			push_warning("[%s] hide_parent_on_reverse_complete enabled but parent is not CanvasItem" % name)
	
	# Chain to next component
	_trigger_next_component()

	if not _queued_trigger.is_empty():
		var queued := _queued_trigger
		_queued_trigger = {}
		_request_sequence(bool(queued.get("is_reverse", false)), bool(queued.get("is_one_shot_return", false)))


## Get list of target nodes based on target_scope and filters
## Also caches natural positions on first call (recipe mode)
func _get_targets() -> Array[Node]:
	var targets: Array[Node] = []
	var parent := get_parent()
	
	if parent == null:
		return targets
	
	# Get candidate nodes based on scope
	var candidates: Array[Node] = []
	match target_scope:
		TargetScope.SIBLINGS:
			for child in parent.get_children():
				candidates.append(child)
		TargetScope.CHILDREN:
			# In CHILDREN mode, we target children of our parent
			# (same as siblings, but semantically different intent)
			for child in parent.get_children():
				candidates.append(child)
		TargetScope.CUSTOM:
			for path in custom_targets:
				var node := get_node_or_null(path)
				if node == null:
					if debug_enabled:
						print("[%s] CUSTOM target not found: %s" % [name, str(path)])
					continue
				candidates.append(node)
	
	# Apply filters
	for node in candidates:
		# Skip self
		if skip_self and node == self:
			continue
		
		# Skip invisible nodes
		if skip_invisible:
			if node is CanvasItem and not node.visible:
				continue
			if node is Node3D and not node.visible:
				continue
		
		# Skip juice components (don't animate our recipe juice as targets)
		if skip_juice_components and node is JuiceCompBase:
			continue
		
		targets.append(node)
	
	return targets


## Apply sequence ordering to target list
func _apply_stagger_order(targets: Array[Node], is_reverse: bool) -> Array[Node]:
	var ordered := targets.duplicate()
	
	# Determine effective order
	var effective_type: int = sequence_type
	
	# If playing reverse and mirror_stagger_on_exit is enabled, flip stagger direction
	if is_reverse and mirror_stagger_on_exit:
		match sequence_type:
			SequenceType.STAGGER_FORWARD:
				effective_type = SequenceType.STAGGER_REVERSE
			SequenceType.STAGGER_REVERSE:
				effective_type = SequenceType.STAGGER_FORWARD
			# RANDOM and ALL_AT_ONCE are unaffected by mirroring
	
	# Apply ordering
	match effective_type:
		SequenceType.STAGGER_FORWARD, SequenceType.ALL_AT_ONCE:
			pass  # Keep forward order (ALL_AT_ONCE: order doesn't matter but deterministic is better)
		SequenceType.STAGGER_REVERSE:
			ordered.reverse()
		SequenceType.RANDOM:
			ordered.shuffle()
	
	return ordered


## Animate a single target based on juice_source mode
func _animate_target(target: Node, is_reverse: bool) -> void:
	match juice_source:
		JuiceSource.SEQUENCERS_CHILDREN:
			await _animate_target_recipe(target, is_reverse)
		JuiceSource.TARGETS_STACK:
			_animate_target_trigger(target, is_reverse)
		JuiceSource.TARGETS_CHILDREN:
			_animate_target_direct_children(target, is_reverse)


## SEQUENCERS_CHILDREN mode: Clone recipe juice and apply to target
## Each target gets its own cloned juice instances to avoid state conflicts
## when animations run in parallel with stagger timing.
func _animate_target_recipe(target: Node, is_reverse: bool) -> void:
	if _recipe_juice.is_empty():
		if debug_enabled:
			push_warning("[%s] SEQUENCERS_CHILDREN mode but no recipe juice children" % name)
		return

	if not is_instance_valid(target):
		return

	var state: Dictionary = _ensure_recipe_target_state(target)
	await _ensure_recipe_naturals_captured(target, state)
	var entrypoints: Array[JuiceCompBase] = state.get("entrypoints", []) as Array[JuiceCompBase]
	var tails: Array[JuiceCompBase] = state.get("tails", []) as Array[JuiceCompBase]

	# We count completion per chain tail. This supports mixed chained/unchained recipes
	# without triggering every recipe in parallel.
	for tail in tails:
		_active_animations += 1
		if not tail.completed.is_connected(_on_recipe_tail_completed):
			tail.completed.connect(_on_recipe_tail_completed)

	# Release any held entries for this target — the real animation now takes over
	# from the hold loop that was maintaining the From/To state every frame.
	_release_held_entries_for_target(target)

	for entry in entrypoints:
		if is_reverse:
			entry.animate_out()
		else:
			entry.animate_in()


func _on_recipe_tail_completed() -> void:
	_active_animations = maxi(0, _active_animations - 1)


## TARGETS_STACK mode: Find named stack container on target and trigger its juice
func _animate_target_trigger(target: Node, is_reverse: bool) -> void:
	# Look for stack container by name
	var stack := target.get_node_or_null(stack_name)
	
	if stack == null:
		if debug_enabled:
			print("[%s] TARGETS_STACK: Target '%s' has no stack '%s' - skipping" % [name, target.name, stack_name])
		return
	
	# Find all juice components in the stack
	var stack_juice: Array[JuiceCompBase] = []
	for child in stack.get_children():
		if child is JuiceCompBase:
			stack_juice.append(child)
	
	if stack_juice.is_empty():
		if debug_enabled:
			print("[%s] TARGETS_STACK: Stack '%s' on '%s' has no juice - skipping" % [name, stack_name, target.name])
		return
	
	# Trigger each juice in the stack
	for juice in stack_juice:
		_active_animations += 1
		
		# Connect to completion
		if not juice.completed.is_connected(_on_juice_completed):
			juice.completed.connect(_on_juice_completed)
		
		if is_reverse:
			juice.animate_out()
		else:
			juice.animate_in()
		
		if debug_enabled:
			print("[%s] TARGETS_STACK: Triggered '%s' in stack '%s' on '%s'" % [name, juice.name, stack_name, target.name])


## Callback when any triggered juice completes
func _on_juice_completed() -> void:
	_active_animations = maxi(0, _active_animations - 1)


## TARGETS_CHILDREN mode: Trigger juice that are direct children of each target
## No named container needed — all JuiceCompBase children on the target fire.
func _animate_target_direct_children(target: Node, is_reverse: bool) -> void:
	# Find all juice components directly on the target
	var target_juice: Array[JuiceCompBase] = []
	for child in target.get_children():
		if child is JuiceCompBase:
			target_juice.append(child)
	
	if target_juice.is_empty():
		if debug_enabled:
			print("[%s] TARGETS_CHILDREN: Target '%s' has no juice children - skipping" % [name, target.name])
		return
	
	# Trigger each juice on the target
	for juice in target_juice:
		_active_animations += 1
		
		# Connect to completion
		if not juice.completed.is_connected(_on_juice_completed):
			juice.completed.connect(_on_juice_completed)
		
		if is_reverse:
			juice.animate_out()
		else:
			juice.animate_in()
		
		if debug_enabled:
			print("[%s] TARGETS_CHILDREN: Triggered '%s' on '%s'" % [name, juice.name, target.name])


func _warmup_recipe_targets() -> void:
	if juice_source != JuiceSource.SEQUENCERS_CHILDREN:
		return
	var targets := _get_targets()
	for target in targets:
		if not is_instance_valid(target):
			continue
		var state := _ensure_recipe_target_state(target)

		# Pre-position target at From state (progress 0.0) so it starts at the
		# correct position from the very first rendered frame — independent of
		# trigger timing, start_delay, or stagger. This only fires when naturals
		# are already captured (editor cache path), which is the common case.
		if not bool(state.get("naturals_captured", false)):
			continue
		var entrypoints: Array[JuiceCompBase] = state.get("entrypoints", []) as Array[JuiceCompBase]
		for entry in entrypoints:
			if entry._target_node != target:
				entry._target_node = target
				entry._invalidate_base_cache()
			entry._on_animate_start()
			entry._apply_effect(0.0)

			# Control targets inside Containers need continuous hold: the Container
			# layout system re-sorts children every frame, overriding one-shot
			# position writes. We register held entries so _process re-applies
			# the From state each frame until animate_in() takes over.
			# 2D/3D targets have no Container management — one-shot is sufficient.
			if target is Control:
				_held_entries.append({
					"target": target,
					"clone": entry,
					"progress": 0.0
				})

	# Enable _process to maintain held positions (beats Container re-sorts)
	if not _held_entries.is_empty():
		set_process(true)

	if debug_enabled:
		print("[%s] Warmup: %d targets, %d held entries (Control)" % [name, targets.size(), _held_entries.size()])


func _ensure_recipe_target_state(target: Node) -> Dictionary:
	if _recipe_target_states.has(target):
		return _recipe_target_states[target] as Dictionary

	var state: Dictionary = {
		"template_to_clone": {},
		"natural_by_template": {},
		"naturals_captured": false,
		"entrypoints": [],
		"tails": []
	}
	_recipe_target_states[target] = state

	_build_recipe_clones_for_target(target, state)
	_remap_recipe_chaining(target, state)
	_compute_recipe_entrypoints_and_tails(state)

	return state


func _ensure_recipe_naturals_captured(target: Node, state: Dictionary) -> void:
	if bool(state.get("naturals_captured", false)):
		return
	if not is_instance_valid(target):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_capture_and_apply_recipe_natural(target, state)
	state["naturals_captured"] = true


func _build_recipe_clones_for_target(target: Node, state: Dictionary) -> void:
	var template_to_clone: Dictionary = state.get("template_to_clone") as Dictionary
	for template in _recipe_juice:
		if template_to_clone.has(template):
			continue
		var clone := template.duplicate() as JuiceCompBase
		if clone == null:
			if debug_enabled:
				push_warning("[%s] Failed to clone recipe '%s'" % [name, template.name])
			continue

		clone._is_recipe_clone = true
		clone._target_node = target
		clone.auto_connect_parent = false
		clone.interrupt_siblings = false

		# Inject per-target editor cache BEFORE add_child so clone._ready()
		# has cached values available if needed.
		if not _editor_target_caches.is_empty() and clone.has_method("_inject_editor_cache"):
			var key := _editor_cache_key(target)
			var cache: Dictionary = _editor_target_caches.get(key, {})
			if not cache.is_empty():
				clone._inject_editor_cache(cache)
				if debug_enabled:
					print("[%s] Injected editor cache for target '%s' into clone '%s'" % [name, target.name, clone.name])

		add_child(clone)

		template_to_clone[template] = clone

	state["template_to_clone"] = template_to_clone

	# When editor caches exist, pre-populate naturals from the cache so
	# _ensure_recipe_naturals_captured skips its 2-frame await. This is
	# critical: the force-first-frame call in JuiceCompBase._animate_to()
	# positions the target at From on the same deferred flush. If we waited
	# 2 frames for natural capture, the target would be visible at its
	# natural position during those frames — the exact frame-0 flash we
	# want to prevent.
	if not _editor_target_caches.is_empty():
		var key := _editor_cache_key(target)
		var cache: Dictionary = _editor_target_caches.get(key, {})
		if not cache.is_empty():
			var natural_by_template: Dictionary = state.get("natural_by_template") as Dictionary
			for template in _recipe_juice:
				natural_by_template[template] = cache
			state["natural_by_template"] = natural_by_template
			state["naturals_captured"] = true
			if debug_enabled:
				print("[%s] Pre-populated naturals from editor cache for target '%s'" % [name, target.name])


func _capture_and_apply_recipe_natural(target: Node, state: Dictionary) -> void:
	var template_to_clone: Dictionary = state.get("template_to_clone") as Dictionary
	var natural_by_template: Dictionary = state.get("natural_by_template") as Dictionary
	for template_variant: Variant in template_to_clone.keys():
		var clone_variant: Variant = template_to_clone.get(template_variant)
		var clone: JuiceCompBase = clone_variant as JuiceCompBase
		if clone == null:
			continue

		var natural: Variant = clone._recipe_capture_natural(target)
		natural_by_template[template_variant] = natural
		clone._recipe_apply_natural(target, natural)

	state["natural_by_template"] = natural_by_template


func _remap_recipe_chaining(_target: Node, state: Dictionary) -> void:
	var template_to_clone: Dictionary = state.get("template_to_clone") as Dictionary
	for template_variant: Variant in template_to_clone.keys():
		var template: JuiceCompBase = template_variant as JuiceCompBase
		var clone_variant: Variant = template_to_clone.get(template_variant)
		var clone: JuiceCompBase = clone_variant as JuiceCompBase
		if template == null or clone == null:
			continue

		# Preserve authored chaining, but ensure internal chaining stays within clones.
		if template.next_component.is_empty():
			continue

		var template_next: Node = template.get_node_or_null(template.next_component)
		if template_next != null and template_to_clone.has(template_next):
			var next_clone_variant: Variant = template_to_clone.get(template_next)
			var next_clone: Node = next_clone_variant as Node
			if next_clone != null:
				clone.next_component = (clone as Node).get_path_to(next_clone)
		else:
			# External chaining is allowed and preserved as-is for all clones.
			clone.next_component = template.next_component


func _compute_recipe_entrypoints_and_tails(state: Dictionary) -> void:
	var template_to_clone: Dictionary = state.get("template_to_clone") as Dictionary
	var incoming: Dictionary = {}

	for template_variant: Variant in template_to_clone.keys():
		var template: JuiceCompBase = template_variant as JuiceCompBase
		if template == null:
			continue
		var template_next: Node = template.get_node_or_null(template.next_component)
		if template_next != null and template_to_clone.has(template_next):
			incoming[template_next] = true

	var entrypoints: Array[JuiceCompBase] = []
	for template_variant: Variant in template_to_clone.keys():
		var template: JuiceCompBase = template_variant as JuiceCompBase
		if template == null:
			continue
		if not incoming.has(template):
			var clone: JuiceCompBase = template_to_clone[template] as JuiceCompBase
			if clone != null:
				entrypoints.append(clone)

	var tails: Array[JuiceCompBase] = []
	for entry in entrypoints:
		var tail := _follow_recipe_chain_tail(entry, template_to_clone)
		tails.append(tail)

	state["entrypoints"] = entrypoints
	state["tails"] = tails


func _follow_recipe_chain_tail(start: JuiceCompBase, template_to_clone: Dictionary) -> JuiceCompBase:
	var current := start
	var visited: Dictionary = {}
	while true:
		if visited.has(current):
			return current
		visited[current] = true

		if current.next_component.is_empty():
			return current
		var next_node := current.get_node_or_null(current.next_component)
		if next_node == null:
			return current
		# If next is one of our clones, continue; otherwise treat as external and stop.
		if next_node is JuiceCompBase and template_to_clone.values().has(next_node):
			current = next_node as JuiceCompBase
			continue
		return current
	return current

# =============================================================================
# VIRTUAL METHOD OVERRIDES (Not used by sequencer, but required by base)
# =============================================================================

func _apply_effect(_progress: float) -> void:
	pass  # Sequencer doesn't use _process-based animation


# =============================================================================
# EDITOR TARGET CACHE (IN_EDITOR capture support for SEQUENCERS_CHILDREN)
# =============================================================================

## Update the per-target editor cache. Called on NOTIFICATION_EDITOR_PRE_SAVE.
## Only caches when juice_source == SEQUENCERS_CHILDREN and at least one
## recipe child uses IN_EDITOR capture with a SELF reference.
func _update_editor_target_caches() -> void:
	if not Engine.is_editor_hint():
		return
	if juice_source != JuiceSource.SEQUENCERS_CHILDREN:
		_editor_target_caches.clear()
		return
	if not _any_recipe_child_needs_editor_cache():
		_editor_target_caches.clear()
		return

	var targets := _get_targets()
	var new_caches: Dictionary = {}
	for target in targets:
		var key := _editor_cache_key(target)
		var cache := _cache_target_transform(target)
		if not cache.is_empty():
			new_caches[key] = cache
	_editor_target_caches = new_caches

	if debug_enabled:
		print("[%s] Editor target caches updated: %d targets" % [name, new_caches.size()])


## Check if any recipe child (direct JuiceCompBase child) needs IN_EDITOR cache injection.
func _any_recipe_child_needs_editor_cache() -> bool:
	for child in get_children():
		if child is JuiceCompBase and child.has_method("_needs_editor_cache_injection"):
			if child._needs_editor_cache_injection():
				return true
	return false


## Generate a stable key for a target node (relative path from this Sequencer).
func _editor_cache_key(target: Node) -> String:
	return str(get_path_to(target))


## Read a target's transform properties into a Dictionary for caching.
## Works for Control, Node2D, and Node3D targets.
func _cache_target_transform(target: Node) -> Dictionary:
	var pos = target.get("position")
	var rot = target.get("rotation")
	var scl = target.get("scale")
	var cache := {}
	if pos != null:
		cache["position"] = pos
	if rot != null:
		cache["rotation"] = rot
	if scl != null:
		cache["scale"] = scl
	return cache


## Returns true if any recipe child has a CUSTOM from_reference (value 0).
## Used by configuration warnings to detect potential sibling conflicts.
## Duck-typed: reads `from_reference` property if it exists on the child.
func _has_custom_from_recipe() -> bool:
	for child in get_children():
		if child is JuiceCompBase:
			var from_ref = child.get("from_reference")
			# CUSTOM = 0 in all TransformReference enums (Control, 2D, 3D)
			if from_ref != null and from_ref == 0:
				return true
	return false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	
	if ping_pong and (trigger_behaviour == TriggerBehaviour.PLAY_IN_AND_OUT or _force_play_in_and_out_once):
		warnings.append("ping_pong is enabled alongside PLAY_IN_AND_OUT. Ping-pong will handle direction cycling; PLAY_IN_AND_OUT auto-reverse is skipped.")
	
	if juice_source == JuiceSource.SEQUENCERS_CHILDREN and _recipe_juice.is_empty() and get_child_count() > 0:
		# Only warn if there are children but none are juice
		var has_juice := false
		for child in get_children():
			if child is JuiceCompBase:
				has_juice = true
				break
		if not has_juice:
			warnings.append("Sequencer's Children mode but no JuiceCompBase children found as recipe.")
	
	if juice_source == JuiceSource.TARGETS_STACK and stack_name.is_empty():
		warnings.append("Target's Stack mode requires a Stack Name to identify the juice container on each target.")
	
	# Warn if a sibling Sequencer also targets overlapping nodes with CUSTOM From
	# on the same transform property. Both would pre-position at _ready, and the
	# last one to run "wins" — producing unpredictable initial state.
	if juice_source == JuiceSource.SEQUENCERS_CHILDREN and _has_custom_from_recipe():
		var parent := get_parent()
		if parent != null:
			for sibling in parent.get_children():
				if sibling == self or not (sibling is SequencerJuiceComp):
					continue
				var sib_seq := sibling as SequencerJuiceComp
				if sib_seq.juice_source != JuiceSource.SEQUENCERS_CHILDREN:
					continue
				if not sib_seq._has_custom_from_recipe():
					continue
				warnings.append(
					"Sibling Sequencer '%s' also uses SEQUENCERS_CHILDREN with a CUSTOM From recipe. " % sibling.name +
					"If both target overlapping nodes on the same transform property, only one can " +
					"correctly pre-position targets at scene start."
				)
				break  # One warning is enough
	
	return warnings
