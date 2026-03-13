## RandomJuiceComp.gd
## ============================================================================
## WHAT: Randomly triggers one (or more) of its child juice components.
## WHY: Adds variation to juice effects. Useful for random idle animations,
##      varied impact effects, or any situation needing randomized feedback.
## SYSTEM: Juicing System (addons/juice/Events and Time/)
## DOES NOT: Create any visual effect. This is a control/flow component only.
## ============================================================================
##
## LIFECYCLE:
##   Follows the Sequencer pattern — overrides animate_in()/animate_out()/stop()
##   and bypasses the base class animation loop entirely. Picks random children,
##   triggers them, waits for all to complete via signal tracking, then emits
##   completed and chains. The _generation counter aborts stale coroutines on
##   stop() or retrigger.
##
## USAGE:
## - Add multiple JuiceCompBase children (variations to choose from)
## - Configure random_mode (pick one or pick multiple)
## - Optionally set weights for non-uniform distribution
##
## EXAMPLES:
## - Random hit effect: RandomJuice → [FlashRed, FlashWhite, ShakeSmall, ShakeBig]
## - Varied idle: RandomJuice → [WiggleLeft, WiggleRight, BounceSmall]
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBaseEvents.svg")
class_name RandomJuiceComp
extends JuiceCompBase

# =============================================================================
# ENUMS
# =============================================================================

## How to select from children
enum RandomMode {
	PICK_ONE,      ## Trigger exactly one random child
	PICK_MULTIPLE  ## Trigger a random subset of children
}

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Effect")

## How to select children to trigger
@export var random_mode: RandomMode = RandomMode.PICK_ONE:
	set(value):
		random_mode = value
		notify_property_list_changed()

## Number of children to pick when using PICK_MULTIPLE mode.
## Clamped to available children count. Only shown for PICK_MULTIPLE.
var pick_count: int = 1

## Optional weights for each child (by index).
## If empty, uniform distribution is used.
## If provided, must match number of JuiceCompBase children.
@export var weights: Array[float] = []

## If true, same child won't be picked twice in PICK_MULTIPLE mode.
@export var no_repeats: bool = true

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	if random_mode == RandomMode.PICK_MULTIPLE:
		props.append({
			"name": "pick_count",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	return props


func _set(prop: StringName, value: Variant) -> bool:
	match prop:
		&"pick_count":
			pick_count = value
			return true
	return false


func _get(prop: StringName) -> Variant:
	match prop:
		&"pick_count":
			return pick_count
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _juice_children: Array[JuiceCompBase] = []
var _pending_completions: int = 0

## Coroutine generation counter — incremented on stop() and new triggers.
## Used to abort stale coroutines when children are still running.
var _generation: int = 0

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()
	_cache_juice_children()


func _cache_juice_children() -> void:
	_juice_children.clear()
	for child in get_children():
		if child is JuiceCompBase:
			_juice_children.append(child)


# =============================================================================
# PUBLIC API — Sequencer pattern: bypass base class animation loop
# =============================================================================

## Trigger random child selection. Overrides base class to bypass animation loop.
func animate_in() -> void:
	_do_animate(false)


## Also works on animate_out — triggers animate_out on selected children.
func animate_out(_is_one_shot: bool = false) -> void:
	_do_animate(true)


func _do_animate(is_reverse: bool) -> void:
	# Handle retrigger if already playing
	if _is_playing:
		match retrigger_policy:
			RetriggerPolicy.IGNORE:
				return
			RetriggerPolicy.QUEUE_ONE:
				_queued_trigger = {"is_reverse": is_reverse}
				return
			RetriggerPolicy.RESTART:
				stop()
	
	_generation += 1
	var my_gen := _generation
	
	# Respect start_delay from base class
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
		if _generation != my_gen:
			return
	
	_is_playing = true
	started.emit()
	
	# Ensure children are cached
	if _juice_children.is_empty():
		_cache_juice_children()
	
	if _juice_children.is_empty():
		push_warning("[%s] No JuiceCompBase children to randomize" % name)
		_is_playing = false
		completed.emit()
		_trigger_next_component()
		return
	
	# Pick and trigger children
	var selected: Array[JuiceCompBase] = []
	match random_mode:
		RandomMode.PICK_ONE:
			var child := _select_random_child()
			if child != null:
				selected.append(child)
		RandomMode.PICK_MULTIPLE:
			selected = _select_multiple_children()
	
	if selected.is_empty():
		_is_playing = false
		completed.emit()
		_trigger_next_component()
		return
	
	# Connect to completion signals and trigger
	_pending_completions = selected.size()
	
	if debug_enabled:
		var names: Array[String] = []
		for s in selected:
			names.append(s.name)
		print("[%s] Randomly selected %d: %s" % [name, selected.size(), names])
	
	for child in selected:
		if not child.completed.is_connected(_on_selected_complete):
			child.completed.connect(_on_selected_complete, CONNECT_ONE_SHOT)
		if is_reverse:
			child.animate_out()
		else:
			child.animate_in()
		# Guard: if child failed to start, disconnect one-shot and decrement now.
		# Prevents infinite stall when child can't animate (e.g. no _target_node).
		if not child.is_playing():
			if child.completed.is_connected(_on_selected_complete):
				child.completed.disconnect(_on_selected_complete)
			_pending_completions = maxi(0, _pending_completions - 1)
			if debug_enabled:
				push_warning("[%s] Child '%s' did not start — skipping" % [name, child.name])
	
	# Wait for all selected children to complete (Sequencer pattern)
	while _pending_completions > 0:
		await get_tree().process_frame
		if _generation != my_gen:
			return  # Aborted by stop() or retrigger
	
	_is_playing = false
	
	if debug_enabled:
		print("[%s] All selected children complete" % name)
	
	completed.emit()
	_trigger_next_component()
	
	# Process queued trigger
	if not _queued_trigger.is_empty():
		var queued := _queued_trigger
		_queued_trigger = {}
		_handle_trigger(queued)


## Stop immediately. Stops all running children and aborts pending coroutine.
func stop() -> void:
	_generation += 1
	_is_playing = false
	_pending_completions = 0
	for child in _juice_children:
		if child.is_playing():
			child.stop()


## No visual effect — control flow component.
func _apply_effect(_progress: float) -> void:
	pass

# =============================================================================
# CHILD COMPLETION TRACKING
# =============================================================================

func _on_selected_complete() -> void:
	_pending_completions = maxi(0, _pending_completions - 1)

# =============================================================================
# RANDOM SELECTION
# =============================================================================

func _select_random_child() -> JuiceCompBase:
	var idx := _select_random_index([])
	if idx >= 0:
		return _juice_children[idx]
	return null


func _select_multiple_children() -> Array[JuiceCompBase]:
	var result: Array[JuiceCompBase] = []
	var count := mini(pick_count, _juice_children.size())
	if count <= 0:
		return result
	
	var selected_indices: Array[int] = []
	for i in range(count):
		var idx := _select_random_index(selected_indices if no_repeats else [])
		if idx >= 0:
			selected_indices.append(idx)
	
	for idx in selected_indices:
		result.append(_juice_children[idx])
	return result


func _select_random_index(exclude_indices: Array[int]) -> int:
	if _juice_children.is_empty():
		return -1
	
	# Build list of valid indices
	var valid_indices: Array[int] = []
	var valid_weights: Array[float] = []
	
	for i in range(_juice_children.size()):
		if i not in exclude_indices:
			valid_indices.append(i)
			if weights.size() > i:
				valid_weights.append(weights[i])
			else:
				valid_weights.append(1.0)
	
	if valid_indices.is_empty():
		return -1
	
	# Weighted random selection
	var total_weight := 0.0
	for w in valid_weights:
		total_weight += maxf(w, 0.0)
	
	if total_weight <= 0.0:
		return valid_indices[randi() % valid_indices.size()]
	
	var random_value := randf() * total_weight
	var cumulative := 0.0
	
	for i in range(valid_indices.size()):
		cumulative += maxf(valid_weights[i], 0.0)
		if random_value <= cumulative:
			return valid_indices[i]
	
	return valid_indices[valid_indices.size() - 1]

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	
	var juice_count := 0
	for child in get_children():
		if child is JuiceCompBase:
			juice_count += 1
	
	if juice_count == 0:
		warnings.append("No JuiceCompBase children to randomize. Add juice components as children.")
	
	if not weights.is_empty() and weights.size() != juice_count:
		warnings.append("Weights array size (%d) doesn't match JuiceCompBase children count (%d)" % [weights.size(), juice_count])
	
	if random_mode == RandomMode.PICK_MULTIPLE and pick_count <= 0:
		warnings.append("pick_count is 0 or negative in PICK_MULTIPLE mode.")
	
	return warnings
