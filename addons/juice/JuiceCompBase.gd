## JuiceCompBase.gd
## ============================================================================
## WHAT: Base class for all juice/feedback components in the Juicing System.
## WHY: Provides shared timing, easing, auto-connect, and chaining logic so
##      concrete components only implement their specific effect.
## SYSTEM: Juicing System (addons/juice/)
## DOES NOT: Implement any visual/audio effect - subclasses do that.
## ============================================================================
##
## ARCHITECTURE (Phase 3.5 - Delta-Based):
## - Animation is progress-based: 0.0 = natural state, 1.0 = effect fully applied
## - Subclasses define an OFFSET/DELTA, not from/to values
## - animate_in() tweens progress from current → 1.0
## - animate_out() tweens progress from current → 0.0
## - No caching of "original" values - stateless and safe for shared recipes
##
## USAGE:
## - Add a juice component as a child of any node
## - Configure via inspector (timing, easing, triggers)
## - Component auto-connects to parent signals OR manually trigger via animate_in()
##
## CONNECTIONS:
## - Parent node: Auto-connects signals based on parent type (Button, Control, etc.)
## - Sibling fallback: If parent has no recognized signals, scans siblings for a
##   trigger source (e.g. Interaction utility as sibling). Connects to the first
##   match, or warns if multiple are found (use trigger_source_path to disambiguate).
## - Next component: Chains to another juice component when this one completes
## - No autoload dependencies - fully self-contained
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBase.svg")
class_name JuiceCompBase
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when this component starts playing
signal started

## Emitted when this component finishes (after all loops)
signal completed

# =============================================================================
# TIMING CONFIGURATION
# =============================================================================

@export_group("Timing")

## Delay before effect starts (seconds)
@export var start_delay: float = 0.0

## Number of times to loop (-1 = infinite, 0 = don't play, 1+ = play N times).
## Setter triggers inspector refresh because ping_pong, loop_delay, and
## loop_phase_offset are hidden when loop_count == 1 (single play).
@export var loop_count: int = 1:
	set(value):
		loop_count = value
		notify_property_list_changed()

## When true, loops reverse direction each cycle like a tape rewind.
## OFF: replays the same direction each loop (default behavior).
## ON: reverses direction each cycle:
##   - PLAY_IN_ONLY/OUT_ONLY: 2-phase bounce (forward + reversed, same curve)
##   - PLAY_IN_AND_OUT: 4-phase tape rewind (IN▶ OUT▶ ◀OUT ◀IN)
## Hidden when loop_count == 1 (no looping) via _validate_property.
@export var ping_pong: bool = false

## Delay between loop cycles (seconds). Also applies at the peak transition
## in 4-phase ping-pong mode (PLAY_IN_AND_OUT + ping_pong) where it acts as
## the pause between the forward IN▶/OUT▶ and the reversed ◀OUT/◀IN phases.
## Hidden when loop_count == 1 (no looping) via _validate_property.
@export var loop_delay: float = 0.0

## Starting phase offset for looping animations (0.0 = start, 0.5 = midpoint, 1.0 = end)
## Useful for creating phase-shifted sinusoidal patterns with multiple looping juice components.
## Only affects the first cycle — subsequent loops start from the beginning.
## Hidden when loop_count == 1 (no looping) via _validate_property.
@export_range(0.0, 1.0) var loop_phase_offset: float = 0.0

# =============================================================================
# TRIGGER CONFIGURATION
# =============================================================================

@export_group("Triggers")

## What this component does when its trigger fires.
## Controls which animation directions are available — changing this hides/shows
## the Animate In and Animate Out groups in the inspector.
enum TriggerBehaviour {
	PLAY_IN_AND_OUT,
	PLAY_IN_ONLY,
	PLAY_OUT_ONLY,
	TOGGLE_IN_AND_OUT,
	SET_FROM_SOURCE
}

@export var trigger_behaviour: TriggerBehaviour = TriggerBehaviour.PLAY_IN_ONLY:
	set(value):
		trigger_behaviour = value
		notify_property_list_changed()

## If true, automatically connect to parent's signals based on its type
## (Button -> pressed/hover, Control -> hover/focus, Area -> body_entered, etc.)
@export var auto_connect_parent: bool = true

## Manual signal name to connect to (e.g., "my_custom_signal")
## When set, REPLACES auto-connect — the two are mutually exclusive.
## Uses trigger_source_path node (or parent if empty) as the signal source.
@export var manual_trigger_signal: String = ""

## Path to the node that provides the trigger signal.
## When set WITHOUT manual_trigger_signal: overrides parent for auto-connect
## (e.g., juice on MeshInstance3D can auto-connect to an Area3D ancestor).
## When set WITH manual_trigger_signal: specifies the manual signal source.
## If empty, uses parent node for both modes.
@export_node_path("Node") var trigger_source_path: NodePath

## Which auto-connect event to respond to (for components that care).
## Values 0-9 are legacy and must keep their ordinals for backward compatibility.
## Values 10+ are new granular triggers added in the Interaction v2 redesign.
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

## Which event triggers this component (used by auto-connect)
@export var trigger_on: TriggerEvent = TriggerEvent.ON_READY

## What happens if the trigger fires while the component is already playing.
enum RetriggerPolicy {
	RESTART,
	IGNORE,
	QUEUE_ONE
}

## Setter triggers inspector refresh because crossfade_time is only
## relevant when retrigger_policy == RESTART (mid-animation direction switch).
@export var retrigger_policy: RetriggerPolicy = RetriggerPolicy.RESTART:
	set(value):
		retrigger_policy = value
		notify_property_list_changed()

## Smoothly blend the visual state when switching direction mid-animation.
## Only relevant when retrigger_policy == RESTART, which is the only policy
## that can cause a mid-animation direction switch. Unbounded on purpose.
## Hidden via _validate_property when retrigger_policy != RESTART.
@export var crossfade_time: float = 0.0

# Animate In/Out, Mirror button, Chaining, and Debug are CONDITIONAL BACKING
# VARIABLES below. Their visibility and ordering is controlled by
# _get_property_list() so they appear in the correct inspector order:
#   Animate In -> [Mirror] -> Animate Out -> Chaining -> Debug

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — they are shown/hidden via _get_property_list()
# =============================================================================

# --- ANIMATE IN ---

## Time to hold at peak (progress=1.0) before animate_out or ping-pong
## reversal begins. Creates "flash" or "sustain" feel: quick in → hold → out.
## 0 = no hold (immediate transition). Shown at end of Animate In group.
var hold_at_peak: float = 0.0

## Duration of animate_in (seconds)
var duration_in: float = 0.3

## Transition curve shape for animate_in (e.g., QUAD, SINE, BOUNCE)
## Setter triggers inspector refresh for elastic/back parameter visibility.
var transition_in: Tween.TransitionType = Tween.TRANS_QUAD:
	set(value):
		transition_in = value
		notify_property_list_changed()

## Easing direction for animate_in (how it accelerates/decelerates)
var ease_in: Tween.EaseType = Tween.EASE_OUT

## Custom curve for animate_in (overrides transition_in + ease_in if set)
## Setter triggers inspector refresh to hide transition/ease when curve is set.
var custom_curve_in: Curve:
	set(value):
		custom_curve_in = value
		notify_property_list_changed()

## Amplitude for ELASTIC easing (only used when transition_in == TRANS_ELASTIC)
var elastic_amplitude_in: float = 1.0

## Period for ELASTIC easing (only used when transition_in == TRANS_ELASTIC)
var elastic_period_in: float = 0.3

## Overshoot for BACK easing (only used when transition_in == TRANS_BACK)
var back_overshoot_in: float = 1.70158

# --- ANIMATE OUT ---

## Duration of animate_out (seconds)
var duration_out: float = 0.3

## Transition curve shape for animate_out
## Setter triggers inspector refresh for elastic/back parameter visibility.
var transition_out: Tween.TransitionType = Tween.TRANS_QUAD:
	set(value):
		transition_out = value
		notify_property_list_changed()

## Easing direction for animate_out
var ease_out: Tween.EaseType = Tween.EASE_IN

## Custom curve for animate_out (overrides transition_out + ease_out if set)
## Setter triggers inspector refresh to hide transition/ease when curve is set.
var custom_curve_out: Curve:
	set(value):
		custom_curve_out = value
		notify_property_list_changed()

## Amplitude for ELASTIC easing (only used when transition_out == TRANS_ELASTIC)
var elastic_amplitude_out: float = 1.0

## Period for ELASTIC easing (only used when transition_out == TRANS_ELASTIC)
var elastic_period_out: float = 0.3

## Overshoot for BACK easing (only used when transition_out == TRANS_BACK)
var back_overshoot_out: float = 1.70158

# --- MIRROR BUTTON (tool button shown between Animate In and Out) ---

## Callable backing var for the Mirror In->Out tool button.
## The button is only shown when both In and Out directions are active.
## Uses a getter to always return a fresh Callable (avoids stale references
## after tool script reload or scene deserialization).
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _btn_mirror_in_to_out: Callable:
	get: return _mirror_in_to_out

# --- CHAINING ---

## Path to next juice component to trigger when this completes.
## Leave empty for no chaining.
var next_component: NodePath

## If true, stop sibling juice components of the same type when this starts.
## Use this to prevent race conditions (e.g., hover-in vs hover-out conflicts).
var interrupt_siblings: bool = false

# --- DEBUG ---

## Enable debug output for this component
var debug_enabled: bool = false

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

## Hint strings for Tween enum dropdowns in _get_property_list().
const _TRANSITION_HINT := "Linear,Sine,Quint,Quart,Quad,Expo,Elastic,Cubic,Circ,Bounce,Back,Spring"
const _EASE_HINT := "In,Out,In-Out,Out-In"


## Conditionally hide @export properties based on other settings.
## - ping_pong, loop_delay, loop_phase_offset: hidden when loop_count == 1 (no looping)
## - crossfade_time: hidden when retrigger_policy != RESTART (no mid-animation switch)
func _validate_property(property: Dictionary) -> void:
	var is_looping := loop_count != 1
	
	# Hide loop-only settings when not looping
	if property.name in ["ping_pong", "loop_delay", "loop_phase_offset"] and not is_looping:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	
	# Crossfade only matters when retrigger can switch direction mid-animation
	if property.name == "crossfade_time" and retrigger_policy != RetriggerPolicy.RESTART:
		property.usage = PROPERTY_USAGE_NO_EDITOR


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	var show_in := trigger_behaviour != TriggerBehaviour.PLAY_OUT_ONLY
	var show_out := trigger_behaviour != TriggerBehaviour.PLAY_IN_ONLY
	# --- Animate In group ---
	if show_in:
		props.append({"name": "Animate In", "type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
		props.append({"name": "duration_in", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT})
		if custom_curve_in == null:
			props.append({"name": "transition_in", "type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM, "hint_string": _TRANSITION_HINT,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "ease_in", "type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM, "hint_string": _EASE_HINT,
				"usage": PROPERTY_USAGE_DEFAULT})
			if transition_in == Tween.TRANS_ELASTIC:
				props.append({"name": "elastic_amplitude_in", "type": TYPE_FLOAT,
					"hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,5.0,0.1",
					"usage": PROPERTY_USAGE_DEFAULT})
				props.append({"name": "elastic_period_in", "type": TYPE_FLOAT,
					"hint": PROPERTY_HINT_RANGE, "hint_string": "0.05,2.0,0.05",
					"usage": PROPERTY_USAGE_DEFAULT})
			elif transition_in == Tween.TRANS_BACK:
				props.append({"name": "back_overshoot_in", "type": TYPE_FLOAT,
					"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,5.0,0.1",
					"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "custom_curve_in", "type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string": "Curve",
			"usage": PROPERTY_USAGE_DEFAULT})
		# hold_at_peak at end of Animate In — holds at progress=1.0 before
		# animate_out or ping-pong reversal begins
		props.append({"name": "hold_at_peak", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT})

	# --- Animate Out group ---
	if show_out:
		props.append({"name": "Animate Out", "type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
		# Mirror button at top of Animate Out (only when both directions active)
		if show_in:
			props.append({"name": "_btn_mirror_in_to_out", "type": TYPE_CALLABLE,
				"hint": PROPERTY_HINT_TOOL_BUTTON,
				"hint_string": "Mirror In -> Out",
				"usage": PROPERTY_USAGE_EDITOR})
		props.append({"name": "duration_out", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT})
		if custom_curve_out == null:
			props.append({"name": "transition_out", "type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM, "hint_string": _TRANSITION_HINT,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "ease_out", "type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM, "hint_string": _EASE_HINT,
				"usage": PROPERTY_USAGE_DEFAULT})
			if transition_out == Tween.TRANS_ELASTIC:
				props.append({"name": "elastic_amplitude_out", "type": TYPE_FLOAT,
					"hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,5.0,0.1",
					"usage": PROPERTY_USAGE_DEFAULT})
				props.append({"name": "elastic_period_out", "type": TYPE_FLOAT,
					"hint": PROPERTY_HINT_RANGE, "hint_string": "0.05,2.0,0.05",
					"usage": PROPERTY_USAGE_DEFAULT})
			elif transition_out == Tween.TRANS_BACK:
				props.append({"name": "back_overshoot_out", "type": TYPE_FLOAT,
					"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,5.0,0.1",
					"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "custom_curve_out", "type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string": "Curve",
			"usage": PROPERTY_USAGE_DEFAULT})

	# --- Chaining group (always visible) ---
	props.append({"name": "Chaining", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "next_component", "type": TYPE_NODE_PATH,
		"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES, "hint_string": "Node",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "interrupt_siblings", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})

	# --- Debug (own group at bottom, rarely used) ---
	props.append({"name": "Debug", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "debug_enabled", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		# Animate In
		&"duration_in": duration_in = value; return true
		&"transition_in": transition_in = value; return true
		&"ease_in": ease_in = value; return true
		&"custom_curve_in": custom_curve_in = value; return true
		&"elastic_amplitude_in": elastic_amplitude_in = value; return true
		&"elastic_period_in": elastic_period_in = value; return true
		&"back_overshoot_in": back_overshoot_in = value; return true
		&"hold_at_peak": hold_at_peak = value; return true
		# Animate Out
		&"duration_out": duration_out = value; return true
		&"transition_out": transition_out = value; return true
		&"ease_out": ease_out = value; return true
		&"custom_curve_out": custom_curve_out = value; return true
		&"elastic_amplitude_out": elastic_amplitude_out = value; return true
		&"elastic_period_out": elastic_period_out = value; return true
		&"back_overshoot_out": back_overshoot_out = value; return true
		# Chaining
		&"next_component": next_component = value; return true
		&"interrupt_siblings": interrupt_siblings = value; return true
		# Debug
		&"debug_enabled": debug_enabled = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		# Animate In
		&"duration_in": return duration_in
		&"transition_in": return transition_in
		&"ease_in": return ease_in
		&"custom_curve_in": return custom_curve_in
		&"elastic_amplitude_in": return elastic_amplitude_in
		&"elastic_period_in": return elastic_period_in
		&"back_overshoot_in": return back_overshoot_in
		&"hold_at_peak": return hold_at_peak
		# Animate Out
		&"duration_out": return duration_out
		&"transition_out": return transition_out
		&"ease_out": return ease_out
		&"custom_curve_out": return custom_curve_out
		&"elastic_amplitude_out": return elastic_amplitude_out
		&"elastic_period_out": return elastic_period_out
		&"back_overshoot_out": return back_overshoot_out
		# Mirror button
		&"_btn_mirror_in_to_out": return _mirror_in_to_out
		# Chaining
		&"next_component": return next_component
		&"interrupt_siblings": return interrupt_siblings
		# Debug
		&"debug_enabled": return debug_enabled
	return null

# =============================================================================
# OFFSET UNITS (Shared enum for scalable measurements)
# =============================================================================

## How to interpret offset/delta values for position and scale
enum OffsetUnit {
	PIXELS,           ## Raw pixel values (ideal for pixel art and fixed-resolution games)
	FRACTION_OWN,      ## Percentage of target's own size (0.5 = 50%)
	FRACTION_PARENT,   ## Percentage of parent's size
	FRACTION_VIEWPORT  ## Percentage of viewport size
}

## How to interpret rotation values
enum RotationUnit {
	DEGREES,  ## Rotation in degrees (human-friendly)
	RADIANS   ## Rotation in radians (Godot native)
}

# =============================================================================
# INTERNAL STATE
# =============================================================================

## The node this component affects (usually parent)
var _target_node: Node

## Currently playing flag
var _is_playing: bool = false

## True when animation is paused at peak (progress=1.0) during hold_at_peak.
## Used by stop()/stop_and_hold() to cancel the hold timer cleanly.
var _in_hold_at_peak: bool = false

## Current loop iteration
var _current_loop: int = 0

## Elapsed time in current cycle
var _elapsed: float = 0.0

## Animation progress: 0.0 = natural state, 1.0 = effect fully applied
## This is the core state - subclasses apply their offset based on this value
var _animation_progress: float = 0.0

## Target progress we're animating towards (0.0 for animate_out, 1.0 for animate_in)
var _target_progress: float = 0.0

## Starting progress when animation began (for smooth interruptions)
var _start_progress: float = 0.0

## True when this is the auto-reverse phase of a one_shot animation
var _is_one_shot_return: bool = false

## True when this juice is a recipe clone (created by sequencer for SEQUENCERS_CHILDREN mode)
## Clones skip auto-setup in _ready() because they're manually configured
var _is_recipe_clone: bool = false

## Toggle state for click-based bidirectional triggers.
## Tracks whether we're currently "in" or "out" so each click alternates.
var _click_toggle_state: bool = false

var _queued_trigger: Dictionary = {}

var _crossfade_elapsed: float = 0.0
var _crossfade_start_progress: float = 0.0
var _is_crossfading: bool = false

var _is_play_in_and_out_active: bool = false

var _force_play_in_and_out_once: bool = false

## Ping-pong phase tracking (0-3 for 4-phase, 0-1 for 2-phase)
var _ping_pong_phase: int = 0

## When true, easing evaluates curve(1.0 - t) instead of curve(t) (time reversal)
var _pp_reversed: bool = false

## When true, use OUT curve parameters regardless of _target_progress direction.
## When false, use IN curve parameters.
var _pp_use_out_curve: bool = false

## When true, an external system (e.g., SoftTriggerJuiceComp) is driving this
## component's progress directly. The internal animation loop is paused.
var _externally_driven: bool = false

## When true, this comp is being driven by the editor Transport Controls plugin.
## Set by _enter_editor_preview(), cleared by _exit_editor_preview().
## Only true inside the editor — never set at runtime.
var _editor_preview_active: bool = false

## True while the comp is in its start_delay period, before the animation clock
## starts ticking. During this phase, _process re-applies _apply_effect at the
## From state every frame to hold the target against Container layout resets
## (Godot's fit_child_in_rect resets position, rotation, and scale each sort).
var _in_start_delay: bool = false

## Generation counter for start_delay coroutine safety. Incremented on each new
## _animate_to call and on stop(), causing stale await coroutines to detect they
## were superseded and abort cleanly.
var _animate_generation: int = 0

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	
	# Managed clones skip auto-setup - they're configured by the sequencer
	if _is_recipe_clone:
		set_process(false)
		if debug_enabled:
			var target_name: String = "(not set)"
			if _target_node != null:
				target_name = _target_node.name
			print("[%s] Ready as managed clone. Target: %s" % [name, target_name])
		return
	
	# Sleep until triggered - zero overhead when idle
	set_process(false)
	
	# Determine target node (what we affect)
	_target_node = get_parent()
	if _target_node == null:
		if debug_enabled:
			push_warning("[%s] No parent node - component will not function" % name)
		return
	
	# Setup trigger connections — manual signal and auto-connect are mutually exclusive.
	# Manual takes priority: if you specify a signal name, that's the only connection made.
	if manual_trigger_signal != "":
		_connect_manual_signal()
	elif auto_connect_parent:
		_try_auto_connect()
	
	# Handle ON_READY trigger - route through _handle_trigger so trigger_behaviour
	# (PLAY_IN_AND_OUT, TOGGLE, SET_FROM_SOURCE, etc.) is respected.
	if trigger_on == TriggerEvent.ON_READY:
		call_deferred("_handle_trigger", {"kind": "momentary"})
		if debug_enabled:
			print("[%s] ON_READY trigger - will fire after scene ready" % name)
	
	if debug_enabled:
		print("[%s] Ready. Target: %s, Auto-connect: %s" % [name, _target_node.name, auto_connect_parent])


func _process(delta: float) -> void:
	if not _is_playing:
		return
	
	# During start_delay, hold the target at its From state every frame.
	# Container layout resets (fit_child_in_rect) override position/rotation/scale
	# each frame, so we must continuously re-apply. This "self-hold" covers the
	# comp's own start_delay. The Sequencer hold (_held_entries) covers a different
	# window: Sequencer-level delay + stagger gaps BEFORE animate_in() is called.
	# Both are needed — they cover adjacent, non-overlapping time windows.
	if _in_start_delay:
		_apply_effect(_start_progress)
		return  # TEMP DEBUG: self-hold re-applies From state every frame during delay
	
	_elapsed += delta
	
	# Use direction-aware duration (in vs out)
	var current_duration := _get_current_duration()
	
	# Calculate normalized time progress (0.0 to 1.0 over duration)
	var time_progress: float = clampf(_elapsed / current_duration, 0.0, 1.0) if current_duration > 0.0 else 1.0
	
	# Apply direction-aware easing to time
	var eased_time: float = _apply_easing(time_progress)
	
	# Interpolate animation progress from start to target
	# This allows smooth interruptions - if we're at 0.3 and animating to 1.0,
	# we lerp from 0.3 to 1.0 over the duration
	_animation_progress = lerpf(_start_progress, _target_progress, eased_time)
	
	# Let subclass apply effect based on current animation progress.
	# If we're switching directions and the IN/OUT curves differ, crossfade prevents visible jumps.
	if _is_crossfading and crossfade_time > 0.0:
		_crossfade_elapsed += delta
		var blend := clampf(_crossfade_elapsed / crossfade_time, 0.0, 1.0)
		var blended_progress := lerpf(_crossfade_start_progress, _animation_progress, blend)
		_apply_effect(blended_progress)
		if blend >= 1.0:
			_is_crossfading = false
	else:
		_apply_effect(_animation_progress)
	
	# Check if cycle complete
	if _elapsed >= current_duration:
		_on_cycle_complete()

# =============================================================================
# PUBLIC API
# =============================================================================

## Animate the effect IN (apply the offset/delta)
## Progress goes from current value towards 1.0
func animate_in() -> void:
	_animate_to(1.0, false)


## Animate the effect OUT (remove the offset/delta)
## Progress goes from current value towards 0.0
func animate_out(is_one_shot_return: bool = false) -> void:
	_animate_to(0.0, is_one_shot_return)


## Animate IN on a specific target node (used by sequencers in recipe mode)
## When target changes, we must invalidate cached base values so they get
## re-captured for the new target node.
func animate_in_on(target: Node) -> void:
	if target == null:
		if debug_enabled:
			push_warning("[%s] Cannot animate_in_on - null target" % name)
		return
	
	# Invalidate base cache when target changes
	if _target_node != target:
		_target_node = target
		_invalidate_base_cache()
	
	animate_in()


## Animate OUT on a specific target node (used by sequencers in recipe mode)
func animate_out_on(target: Node) -> void:
	if target == null:
		if debug_enabled:
			push_warning("[%s] Cannot animate_out_on - null target" % name)
		return
	
	# Invalidate base cache when target changes
	if _target_node != target:
		_target_node = target
		_invalidate_base_cache()
	
	animate_out()


## Allow external systems (e.g., SoftTriggerJuiceComp) to directly drive
## animation progress, bypassing the internal timing/easing loop.
## The spatial falloff of the external system IS the easing curve.
## Pass value in range 0.0–1.0 to set progress.
## Pass -1.0 to release external control and allow normal animation to resume.
func set_external_progress(value: float) -> void:
	if value < 0.0:
		_externally_driven = false
		return
	
	# Ensure subclass has captured its base state before we drive progress
	if not _externally_driven:
		_externally_driven = true
		_is_playing = false
		set_process(false)
		_on_animate_start()
	
	_animation_progress = clampf(value, 0.0, 1.0)
	_apply_effect(_animation_progress)


## Toggle animation based on boolean state (useful for button.toggled signal)
func toggle(pressed: bool) -> void:
	if pressed:
		animate_in()
	else:
		animate_out()


## Toggle animation on each call - used for click-based bidirectional triggers.
## Each click alternates between animate_in and animate_out.
func click_toggle(_interactor: Variant = null) -> void:
	_click_toggle_state = not _click_toggle_state
	if _click_toggle_state:
		animate_in()
	else:
		animate_out()
	
	if debug_enabled:
		print("[%s] Click toggle -> %s" % [name, "IN" if _click_toggle_state else "OUT"])


func _on_trigger_momentary(_interactor: Node = null) -> void:
	_handle_trigger({"kind": "momentary"})


func _on_trigger_polarity(is_on: bool) -> void:
	_handle_trigger({"kind": "polarity", "is_on": is_on})


func _on_trigger_polarity_on() -> void:
	_on_trigger_polarity(true)


func _on_trigger_polarity_off() -> void:
	_on_trigger_polarity(false)


func _on_trigger_source_state(state: bool) -> void:
	_handle_trigger({"kind": "state", "state": state})


func _mirror_in_to_out() -> void:
	duration_out = duration_in
	transition_out = transition_in
	ease_out = _reverse_ease_type(ease_in)
	custom_curve_out = _reverse_curve_time(custom_curve_in)
	elastic_amplitude_out = elastic_amplitude_in
	elastic_period_out = elastic_period_in
	back_overshoot_out = back_overshoot_in


func _reverse_ease_type(ease_type: Tween.EaseType) -> Tween.EaseType:
	match ease_type:
		Tween.EASE_IN:
			return Tween.EASE_OUT
		Tween.EASE_OUT:
			return Tween.EASE_IN
		Tween.EASE_IN_OUT:
			return Tween.EASE_OUT_IN
		Tween.EASE_OUT_IN:
			return Tween.EASE_IN_OUT
		_:
			return ease_type


func _reverse_curve_time(curve: Curve) -> Curve:
	if curve == null:
		return null
	
	var reversed := Curve.new()
	var count: int = curve.get_point_count()
	for i in range(count - 1, -1, -1):
		var pos: Vector2 = curve.get_point_position(i)
		var x := 1.0 - pos.x
		var y := pos.y
		var left_tangent: float = curve.get_point_right_tangent(i) * -1.0
		var right_tangent: float = curve.get_point_left_tangent(i) * -1.0
		var left_mode: int = curve.get_point_right_mode(i)
		var right_mode: int = curve.get_point_left_mode(i)
		reversed.add_point(Vector2(x, y), left_tangent, right_tangent, left_mode, right_mode)
	
	return reversed


func _handle_trigger(trigger: Dictionary) -> void:
	var effective_policy: RetriggerPolicy = retrigger_policy
	if _is_playing:
		match effective_policy:
			RetriggerPolicy.IGNORE:
				return
			RetriggerPolicy.QUEUE_ONE:
				_queued_trigger = trigger
				return
			_:
				pass
	
	var effective_behaviour: TriggerBehaviour = trigger_behaviour
	var has_polarity: bool = trigger.has("kind") and trigger["kind"] == "polarity" and trigger.has("is_on")
	var is_on: bool = bool(trigger.get("is_on", false))
	var has_state: bool = trigger.has("kind") and trigger["kind"] == "state" and trigger.has("state")
	var state: bool = bool(trigger.get("state", false))
	
	_force_play_in_and_out_once = false

	match effective_behaviour:
		TriggerBehaviour.PLAY_IN_AND_OUT:
			_is_play_in_and_out_active = true
			animate_in()
		TriggerBehaviour.PLAY_IN_ONLY:
			animate_in()
		TriggerBehaviour.PLAY_OUT_ONLY:
			animate_out()
		TriggerBehaviour.TOGGLE_IN_AND_OUT:
			if has_polarity:
				if is_on:
					animate_in()
				else:
					animate_out()
			else:
				click_toggle()
		TriggerBehaviour.SET_FROM_SOURCE:
			if has_state:
				toggle(state)
			elif has_polarity:
				toggle(is_on)
			else:
				_force_play_in_and_out_once = true
				_is_play_in_and_out_active = true
				if debug_enabled:
					push_warning("[%s] SET_FROM_SOURCE trigger had no state/polarity; falling back to PLAY_IN_AND_OUT" % name)
				animate_in()


## Core animation method - animates progress towards target value
func _animate_to(target_progress: float, is_one_shot_return: bool = false) -> void:
	# Lazy-init _target_node in editor preview for comps reached via chains,
	# loop_target, or programmatic triggers that weren't in the Transport's
	# initial selection. _ready() skips init in editor (Engine.is_editor_hint guard).
	if _target_node == null and Engine.is_editor_hint() and get_parent() != null:
		_target_node = get_parent()
		_on_animate_start()
		if debug_enabled:
			print("[%s] Lazy-initialized _target_node to '%s' (editor chain)" % [name, _target_node.name])
	if _target_node == null:
		if debug_enabled:
			push_warning("[%s] Cannot animate - no target node" % name)
		return
	
	if debug_enabled:
		var _at_target := absf(_animation_progress - target_progress) <= 0.0001
		print("[%s] ◆ _animate_to(%.2f) | playing=%s | anim=%.3f start=%.3f target=%.3f | at_target=%s | policy=%s" % [
			name, target_progress, _is_playing, _animation_progress, _start_progress, _target_progress, _at_target, RetriggerPolicy.keys()[retrigger_policy]])
	
	# If we are switching direction mid-animation, crossfade from the current visual state
	# to the new direction to avoid discontinuities when IN/OUT curves differ.
	var switching_direction := _is_playing and not is_one_shot_return and target_progress != _target_progress
	if switching_direction and crossfade_time > 0.0:
		_is_crossfading = true
		_crossfade_elapsed = 0.0
		_crossfade_start_progress = _animation_progress
	
	# Stop sibling juice components of same type to prevent race conditions
	# But NOT if this is the one_shot return phase (we're continuing our own animation)
	if interrupt_siblings and not is_one_shot_return:
		_stop_sibling_juice_components()
	
	# Initialize animation state
	# Restart logic:
	# Important: Some effects are intentionally "spammable" (e.g. camera shake, squash/stretch punch)
	# and often use PLAY_IN_ONLY. Once such an effect reaches progress 1.0, it can become a no-op on
	# subsequent animate_in() calls (1.0 -> 1.0). For RESTART, we explicitly reset progress to the
	# direction's origin endpoint even if we're currently idle, so a retrigger always produces motion.
	var effective_policy := retrigger_policy
	var should_restart_same_direction: bool = false
	if effective_policy == RetriggerPolicy.RESTART:
		var restart_is_allowed := true
		var epsilon := 0.0001
		var already_at_target := absf(_animation_progress - target_progress) <= epsilon
		# If we're already at the target endpoint, we cannot infer "direction" from progress.
		# Restart from the origin endpoint every time so punch-style effects remain spammable.
		if restart_is_allowed and already_at_target:
			if target_progress > 0.5:  # Animating IN
				_animation_progress = 0.0
				_apply_effect(0.0)
			else:  # Animating OUT
				_animation_progress = 1.0
				_apply_effect(1.0)
			# Continue into normal setup below (start_progress will be set from the reset value).
		else:
			var current_dir_in := _target_progress > _start_progress
			var new_dir_in := target_progress > _animation_progress
			var same_direction := current_dir_in == new_dir_in and not switching_direction
			if same_direction:
				# RESTART always restarts on same-direction retriggers.
				should_restart_same_direction = restart_is_allowed
			
			if same_direction and should_restart_same_direction:
				if _is_playing:
					if target_progress > 0.5:  # Animating IN
						_animation_progress = 0.0
						_apply_effect(0.0)  # Reset visual state immediately
					else:  # Animating OUT
						_animation_progress = 1.0
						_apply_effect(1.0)
	
	# Start from current progress for smooth interruptions (default behavior)
	_start_progress = _animation_progress
	_target_progress = target_progress
	_is_playing = true
	_is_one_shot_return = is_one_shot_return
	# Preserve loop counter during one_shot_return (PLAY_IN_AND_OUT's auto OUT chain).
	# The full IN+OUT pair is one cycle — resetting here would lose the count.
	if not is_one_shot_return:
		_current_loop = 0
	_elapsed = 0.0
	
	# Initialize ping-pong state for new animation
	if ping_pong and not is_one_shot_return:
		_ping_pong_phase = 0
		_pp_reversed = false
		# Phase 0 curve matches the triggered direction
		_pp_use_out_curve = (target_progress <= 0.5)
	else:
		_reset_ping_pong()
	
	# Apply loop phase offset — starts the first cycle partway through its duration
	# This enables phase-shifted sinusoidal patterns when stacking looping juice components
	if loop_phase_offset > 0.0 and not is_one_shot_return:
		var phase_duration := _get_current_duration()
		_elapsed = phase_duration * loop_phase_offset
	
	# Let subclass prepare
	_on_animate_start()
	
	# Enable processing
	set_process(true)
	
	# Force-first-frame: apply the effect at start progress immediately so
	# the target is positioned at its From state before the first render.
	# Without this, there is a one-frame gap between set_process(true) and
	# the first _process() call where the target is visible at its natural
	# position — causing a frame-0 flash for any animation where From ≠ natural.
	_apply_effect(_start_progress)
	
	# Handle start delay AFTER FFR (skip for one_shot return - immediate transition).
	# The target is now visually at its From state. During the delay, _process
	# re-applies _apply_effect(_start_progress) every frame ("self-hold") to beat
	# Container layout resets (fit_child_in_rect resets position, rotation, scale).
	# This moves the hold responsibility INTO the comp — works for standalone comps,
	# Sequencer clones, and any trigger type. Generation tracking ensures stale
	# coroutines (from retrigger or stop during delay) abort cleanly.
	if start_delay > 0.0 and not is_one_shot_return:
		_in_start_delay = true
		_animate_generation += 1
		var my_gen := _animate_generation
		await get_tree().create_timer(start_delay).timeout
		if _animate_generation != my_gen:
			return  # Aborted by retrigger or stop during delay
		_in_start_delay = false
		_elapsed = 0.0  # Animation clock starts NOW, after the delay
	
	# Only emit started if this is not the one_shot auto-return
	if not is_one_shot_return:
		started.emit()
	
	if debug_enabled:
		var dir_str := "IN" if target_progress > _start_progress else "OUT"
		var return_str := " (one_shot return)" if is_one_shot_return else ""
		var current_dur := duration_in if target_progress > 0.5 else duration_out
		print("[%s] Animate %s%s: %.2f -> %.2f (duration: %.2f)" % [name, dir_str, return_str, _start_progress, target_progress, current_dur])


## Stop the effect immediately and reset to natural state (progress = 0)
func stop() -> void:
	_is_playing = false
	_in_start_delay = false
	_in_hold_at_peak = false
	_animate_generation += 1  # Abort any in-flight start_delay await
	set_process(false)
	_animation_progress = 0.0
	_reset_ping_pong()
	_restore_to_natural()
	
	if debug_enabled:
		print("[%s] Stopped and reset" % name)


## Stop effect but keep current state (don't reset)
func stop_and_hold() -> void:
	_is_playing = false
	_in_start_delay = false
	_in_hold_at_peak = false
	_animate_generation += 1  # Abort any in-flight start_delay await
	set_process(false)
	_reset_ping_pong()
	
	if debug_enabled:
		print("[%s] Stopped and holding at progress %.2f" % [name, _animation_progress])


## Check if currently animating
func is_playing() -> bool:
	return _is_playing


## Get current animation progress (0.0 = natural, 1.0 = fully applied)
func get_progress() -> float:
	return _animation_progress


# =============================================================================
# EDITOR PREVIEW API (Transport Controls)
# Used by the JuiceTransportControls plugin to preview effects in the editor.
# These methods are only meaningful when Engine.is_editor_hint() is true.
# =============================================================================

## Prepare this comp for editor preview playback.
## Sets up _target_node and flags that _ready() normally handles but skips in editor.
## Called by JuicePreviewDirector when a juice comp is selected in the editor.
func _enter_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	_target_node = get_parent()
	_editor_preview_active = true
	# Capture base state now so scrubbing works even without pressing Play first.
	# Subclasses (e.g., TransformControlJuiceComp) cache the target's current
	# position/rotation/scale in _on_animate_start() and need it before _apply_effect().
	if _target_node:
		_on_animate_start()
	if debug_enabled:
		var target_name: String = str(_target_node.name) if _target_node else "(null)"
		print("[%s] Entered editor preview. Target: %s" % [name, target_name])


## Clean up after editor preview.
## Stops playback, restores target to natural state, clears preview state.
## Called by JuicePreviewDirector when selection changes or preview ends.
func _exit_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	stop()
	# Invalidate cached base values so the next preview captures fresh state.
	# Without this, if the user moves the target node between previews, the
	# stale cache would cause incorrect offsets.
	_invalidate_base_cache()
	_target_node = null
	_editor_preview_active = false
	if debug_enabled:
		print("[%s] Exited editor preview" % name)


## Compute what animation progress this comp should display at a given wall-clock time.
## Used by the scrub slider to map a time position (in seconds) to the correct
## visual state, accounting for start_delay, duration_in, hold_at_peak, duration_out.
## Does NOT modify any internal state — pure computation.
func get_progress_at_time(time: float) -> float:
	# Determine if this comp has an OUT phase based on trigger_behaviour
	var has_out := trigger_behaviour == TriggerBehaviour.PLAY_IN_AND_OUT \
		or trigger_behaviour == TriggerBehaviour.TOGGLE_IN_AND_OUT
	
	# Phase 1: start_delay — effect hasn't started yet
	if time < start_delay:
		return 0.0
	
	var t := time - start_delay
	
	# Phase 2: IN animation
	if t < duration_in:
		var normalized := t / duration_in if duration_in > 0.0 else 1.0
		return apply_easing_for_direction(normalized, true)
	
	# Phase 3: Hold at peak (if configured and has OUT phase)
	if has_out:
		var after_in := t - duration_in
		if after_in < hold_at_peak:
			return 1.0  # Sustained at peak during hold
		
		# Phase 4: OUT animation
		var out_t := after_in - hold_at_peak
		if out_t < duration_out:
			var normalized := out_t / duration_out if duration_out > 0.0 else 1.0
			return 1.0 - apply_easing_for_direction(normalized, false)
		else:
			return 0.0  # OUT complete — back to natural
	
	# No OUT phase — hold at peak
	return 1.0


## Get the total wall-clock duration for one full preview cycle.
## Includes start_delay + duration_in + hold_at_peak + duration_out.
## Used by the director to set the scrub slider range.
func get_total_preview_duration() -> float:
	var total := start_delay + duration_in
	var has_out := trigger_behaviour == TriggerBehaviour.PLAY_IN_AND_OUT \
		or trigger_behaviour == TriggerBehaviour.TOGGLE_IN_AND_OUT
	if has_out:
		total += hold_at_peak + duration_out
	return total


## Directly set animation progress and apply the visual effect.
## Used by the editor Transport Controls scrub slider.
## Does NOT start the internal animation loop — just sets the visual state.
## Requires _on_animate_start() to have been called first (done by _enter_editor_preview).
func set_progress(value: float) -> void:
	if _target_node == null:
		return
	_animation_progress = clampf(value, 0.0, 1.0)
	_apply_effect(_animation_progress)


## Apply easing for a specific direction without depending on internal animation state.
## This is the public equivalent of _apply_easing() — used by the preview scrub system
## to compute eased progress without starting a real animation.
## use_in_curve: true = use IN easing parameters, false = use OUT easing parameters.
func apply_easing_for_direction(normalized_time: float, use_in_curve: bool) -> float:
	var t := clampf(normalized_time, 0.0, 1.0)
	if use_in_curve:
		if custom_curve_in != null:
			return custom_curve_in.sample(t)
		if transition_in == Tween.TRANS_ELASTIC:
			return _ease_elastic(t, ease_in, elastic_amplitude_in, elastic_period_in)
		if transition_in == Tween.TRANS_BACK:
			return _ease_back(t, ease_in, back_overshoot_in)
		return Tween.interpolate_value(0.0, 1.0, t, 1.0, transition_in, ease_in)
	else:
		if custom_curve_out != null:
			return custom_curve_out.sample(t)
		if transition_out == Tween.TRANS_ELASTIC:
			return _ease_elastic(t, ease_out, elastic_amplitude_out, elastic_period_out)
		if transition_out == Tween.TRANS_BACK:
			return _ease_back(t, ease_out, back_overshoot_out)
		return Tween.interpolate_value(0.0, 1.0, t, 1.0, transition_out, ease_out)


## Stop sibling juice components that share the same interrupt identity.
## This prevents race conditions when multiple juice components affect the same property
## (e.g., hover-in scale vs hover-out scale fighting each other).
## Matching uses _get_interrupt_identity() so subclasses can refine granularity
## (e.g., transform comps only interrupt siblings with the same transform_target).
func _stop_sibling_juice_components() -> void:
	var parent = get_parent()
	if parent == null:
		return
	
	var my_identity: Variant = _get_interrupt_identity()
	
	for sibling in parent.get_children():
		if sibling == self:
			continue
		
		if sibling is JuiceCompBase:
			var juice_sibling := sibling as JuiceCompBase
			var sibling_identity: Variant = juice_sibling._get_interrupt_identity()
			# Type check first — different identity types (e.g. Object vs Array)
			# can't be equal and would crash Godot's == operator
			if typeof(sibling_identity) == typeof(my_identity) and sibling_identity == my_identity and juice_sibling.is_playing():
				juice_sibling.stop_and_hold()
				if debug_enabled:
					print("[%s] Interrupted sibling '%s'" % [name, sibling.name])

# =============================================================================
# CONFIGURATION WARNINGS (yellow triangle in scene tree)
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	
	# Warn about ambiguous sibling trigger sources.
	# Only relevant when: auto_connect is on, no explicit trigger_source_path,
	# trigger_on requires signal connection, and parent isn't a trigger source itself.
	if auto_connect_parent and trigger_source_path.is_empty() \
			and trigger_on != TriggerEvent.MANUAL and trigger_on != TriggerEvent.ON_READY:
		var parent := get_parent()
		if parent and not _is_recognized_trigger_source(parent):
			var sibling_sources: Array[Node] = []
			for sibling in parent.get_children():
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
					+ "Set trigger_source_path to specify the intended source.")
	
	return warnings

# =============================================================================
# AUTO-CONNECT LOGIC
# =============================================================================

## Attempt to auto-connect signals based on the trigger source node's type.
## By default the trigger source is the parent node. If trigger_source_path is set,
## that node is used instead — allowing juice comps to be parented to the node they
## affect (e.g. MeshInstance3D) while auto-connecting to a trigger source elsewhere
## (e.g. an Area3D ancestor).
##
## SIBLING FALLBACK: If the parent is not a recognized trigger source (no input
## signals to connect to), scans siblings for exactly one recognized source.
## If multiple sibling sources exist, NO connection is made — a config warning
## tells the user to set trigger_source_path for disambiguation.
func _try_auto_connect() -> void:
	var source: Node
	if not trigger_source_path.is_empty():
		source = get_node_or_null(trigger_source_path)
		if source == null:
			if debug_enabled:
				push_warning("[%s] trigger_source_path '%s' not found — auto-connect skipped" % [name, trigger_source_path])
			return
	else:
		source = get_parent()
		# Sibling fallback: if parent isn't a recognized trigger source, scan siblings.
		# Only when trigger_source_path is NOT set (explicit path takes priority).
		if source and not _is_recognized_trigger_source(source):
			var sibling_sources: Array[Node] = []
			for sibling in source.get_children():
				if sibling == self:
					continue
				if _is_recognized_trigger_source(sibling):
					sibling_sources.append(sibling)
			if sibling_sources.size() == 1:
				source = sibling_sources[0]
				if debug_enabled:
					print("[%s] Sibling auto-connect: using '%s' (%s)" % [name, source.name, source.get_class()])
			elif sibling_sources.size() > 1:
				# Ambiguous — multiple possible sources. Don't guess, warn instead.
				if debug_enabled:
					var names := PackedStringArray()
					for s in sibling_sources:
						names.append(s.name)
					push_warning("[%s] Multiple sibling trigger sources found (%s). Set trigger_source_path to specify which one." % [name, ", ".join(names)])
				return
	if source == null:
		return
	
	# MANUAL and ON_READY don't need auto-connect (handled elsewhere)
	if trigger_on == TriggerEvent.MANUAL or trigger_on == TriggerEvent.ON_READY:
		if debug_enabled:
			print("[%s] Trigger %s - no auto-connect needed" % [name, TriggerEvent.keys()[trigger_on]])
		return
	
	# ON_SHOW / ON_HIDE work on any CanvasItem (Control, Node2D)
	if trigger_on == TriggerEvent.ON_SHOW or trigger_on == TriggerEvent.ON_HIDE:
		if source is CanvasItem:
			_connect_visibility_signals(source)
		else:
			if debug_enabled:
				push_warning("[%s] ON_SHOW/ON_HIDE requires CanvasItem source, got %s" % [name, source.get_class()])
		return
	
	# BaseButton (Button, TextureButton, etc.)
	if source is BaseButton:
		_connect_button_signals(source)
	# Control (any UI element)
	elif source is Control:
		_connect_control_signals(source)
	# CollisionObject3D (Area3D, StaticBody3D, RigidBody3D, CharacterBody3D, etc.)
	elif source is CollisionObject3D:
		_connect_collision_object_3d_signals(source)
	# CollisionObject2D (Area2D, StaticBody2D, RigidBody2D, CharacterBody2D, etc.)
	elif source is CollisionObject2D:
		_connect_collision_object_2d_signals(source)
	# AnimationPlayer
	elif source is AnimationPlayer:
		_connect_animation_signals(source)
	else:
		if debug_enabled:
			print("[%s] Source type %s has no auto-connect rules" % [name, source.get_class()])


## Whether a node is a type that _try_auto_connect knows how to wire signals from.
## Used by the sibling fallback scan to identify candidate trigger sources.
func _is_recognized_trigger_source(node: Node) -> bool:
	return node is BaseButton or node is Control or node is CollisionObject3D \
		or node is CollisionObject2D or node is AnimationPlayer


func _connect_button_signals(button: BaseButton) -> void:
	match trigger_on:
		TriggerEvent.ON_PRESS:
			if trigger_behaviour == TriggerBehaviour.SET_FROM_SOURCE:
				if not button.toggled.is_connected(_on_trigger_source_state):
					button.toggled.connect(_on_trigger_source_state)
				# For non-toggle buttons, also connect button_down so they still trigger a
				# sensible fallback. For toggle_mode buttons, connecting both button_down and
				# toggled causes double-triggers (momentary + state), which breaks true ON/OFF.
				if not button.toggle_mode:
					if not button.button_down.is_connected(_on_trigger_momentary):
						button.button_down.connect(_on_trigger_momentary)
			else:
				# button_down fires instantly on press-down for responsive juice feedback.
				# NOTE: If you need juice to fire when the button ACTION completes (after
				# mouse release), use manual_trigger_signal = "pressed" instead.
				if not button.button_down.is_connected(_on_trigger_momentary):
					button.button_down.connect(_on_trigger_momentary)
		TriggerEvent.ON_RELEASE:
			if not button.button_up.is_connected(_on_trigger_momentary):
				button.button_up.connect(_on_trigger_momentary)
		TriggerEvent.ON_HOVER_START:
			if not button.mouse_entered.is_connected(_on_trigger_polarity_on):
				button.mouse_entered.connect(_on_trigger_polarity_on)
			if not button.mouse_exited.is_connected(_on_trigger_polarity_off):
				button.mouse_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_HOVER_END:
			if not button.mouse_entered.is_connected(_on_trigger_polarity_on):
				button.mouse_entered.connect(_on_trigger_polarity_on)
			if not button.mouse_exited.is_connected(_on_trigger_polarity_off):
				button.mouse_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_FOCUS:
			if not button.focus_entered.is_connected(_on_trigger_polarity_on):
				button.focus_entered.connect(_on_trigger_polarity_on)
			if not button.focus_exited.is_connected(_on_trigger_polarity_off):
				button.focus_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_UNFOCUS:
			if not button.focus_entered.is_connected(_on_trigger_polarity_on):
				button.focus_entered.connect(_on_trigger_polarity_on)
			if not button.focus_exited.is_connected(_on_trigger_polarity_off):
				button.focus_exited.connect(_on_trigger_polarity_off)
	
	if debug_enabled:
		print("[%s] Auto-connected to Button '%s' on %s" % [name, button.name, TriggerEvent.keys()[trigger_on]])


func _connect_control_signals(control: Control) -> void:
	match trigger_on:
		TriggerEvent.ON_PRESS:
			# gui_input receives all input events — filter for mouse click in handler
			if not control.gui_input.is_connected(_on_control_gui_input_press):
				control.gui_input.connect(_on_control_gui_input_press)
		TriggerEvent.ON_RELEASE:
			if not control.gui_input.is_connected(_on_control_gui_input_release):
				control.gui_input.connect(_on_control_gui_input_release)
		TriggerEvent.ON_HOVER_START:
			if not control.mouse_entered.is_connected(_on_trigger_polarity_on):
				control.mouse_entered.connect(_on_trigger_polarity_on)
			if not control.mouse_exited.is_connected(_on_trigger_polarity_off):
				control.mouse_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_HOVER_END:
			if not control.mouse_entered.is_connected(_on_trigger_polarity_on):
				control.mouse_entered.connect(_on_trigger_polarity_on)
			if not control.mouse_exited.is_connected(_on_trigger_polarity_off):
				control.mouse_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_FOCUS:
			if not control.focus_entered.is_connected(_on_trigger_polarity_on):
				control.focus_entered.connect(_on_trigger_polarity_on)
			if not control.focus_exited.is_connected(_on_trigger_polarity_off):
				control.focus_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_UNFOCUS:
			if not control.focus_entered.is_connected(_on_trigger_polarity_on):
				control.focus_entered.connect(_on_trigger_polarity_on)
			if not control.focus_exited.is_connected(_on_trigger_polarity_off):
				control.focus_exited.connect(_on_trigger_polarity_off)
	
	if debug_enabled:
		print("[%s] Auto-connected to Control '%s' on %s" % [name, control.name, TriggerEvent.keys()[trigger_on]])


## Auto-connect to CollisionObject3D signals (Area3D, StaticBody3D, RigidBody3D, etc.).
## Connects directly to native Godot signals — no wrapper signal checks needed.
func _connect_collision_object_3d_signals(col_obj: CollisionObject3D) -> void:
	match trigger_on:
		TriggerEvent.ON_PRESS:
			# Any mouse button press on collision shape
			if not col_obj.input_event.is_connected(_on_collision_input_press_3d):
				col_obj.input_event.connect(_on_collision_input_press_3d)
			# Area-specific: physics body and area overlap
			if col_obj is Area3D:
				if not col_obj.body_entered.is_connected(_on_area_body_entered):
					col_obj.body_entered.connect(_on_area_body_entered)
				if not col_obj.area_entered.is_connected(_on_area_area_entered):
					col_obj.area_entered.connect(_on_area_area_entered)
		TriggerEvent.ON_RELEASE:
			# Any mouse button release on collision shape
			if not col_obj.input_event.is_connected(_on_collision_input_release_3d):
				col_obj.input_event.connect(_on_collision_input_release_3d)
			# Area-specific: physics body and area overlap exit
			if col_obj is Area3D:
				if not col_obj.body_exited.is_connected(_on_area_body_exited):
					col_obj.body_exited.connect(_on_area_body_exited)
				if not col_obj.area_exited.is_connected(_on_area_area_exited):
					col_obj.area_exited.connect(_on_area_area_exited)
		TriggerEvent.ON_HOVER_START:
			# Native mouse_entered/exited — polarity pair (in on enter, out on exit)
			if not col_obj.mouse_entered.is_connected(_on_trigger_polarity_on):
				col_obj.mouse_entered.connect(_on_trigger_polarity_on)
			if not col_obj.mouse_exited.is_connected(_on_trigger_polarity_off):
				col_obj.mouse_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_HOVER_END:
			# Native mouse_entered/exited — reversed polarity (in on exit, out on enter)
			if not col_obj.mouse_entered.is_connected(_on_trigger_polarity_on):
				col_obj.mouse_entered.connect(_on_trigger_polarity_on)
			if not col_obj.mouse_exited.is_connected(_on_trigger_polarity_off):
				col_obj.mouse_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_LEFT_CLICK:
			# Left mouse button only — filtered in the callback handler
			if not col_obj.input_event.is_connected(_on_collision_input_filtered_3d):
				col_obj.input_event.connect(_on_collision_input_filtered_3d)
		TriggerEvent.ON_RIGHT_CLICK:
			# Right mouse button only — filtered in the callback handler
			if not col_obj.input_event.is_connected(_on_collision_input_filtered_3d):
				col_obj.input_event.connect(_on_collision_input_filtered_3d)
		TriggerEvent.ON_MIDDLE_CLICK:
			# Middle mouse button only — filtered in the callback handler
			if not col_obj.input_event.is_connected(_on_collision_input_filtered_3d):
				col_obj.input_event.connect(_on_collision_input_filtered_3d)
		TriggerEvent.ON_BODY_ENTERED:
			# Area-only: physics body entered
			if col_obj is Area3D:
				if not col_obj.body_entered.is_connected(_on_area_body_entered):
					col_obj.body_entered.connect(_on_area_body_entered)
		TriggerEvent.ON_BODY_EXITED:
			# Area-only: physics body exited
			if col_obj is Area3D:
				if not col_obj.body_exited.is_connected(_on_area_body_exited):
					col_obj.body_exited.connect(_on_area_body_exited)
		TriggerEvent.ON_AREA_ENTERED:
			# Area-only: another area entered
			if col_obj is Area3D:
				if not col_obj.area_entered.is_connected(_on_area_area_entered):
					col_obj.area_entered.connect(_on_area_area_entered)
		TriggerEvent.ON_AREA_EXITED:
			# Area-only: another area exited
			if col_obj is Area3D:
				if not col_obj.area_exited.is_connected(_on_area_area_exited):
					col_obj.area_exited.connect(_on_area_area_exited)
	
	if debug_enabled:
		print("[%s] Auto-connected to %s '%s' on %s" % [name, col_obj.get_class(), col_obj.name, TriggerEvent.keys()[trigger_on]])


## Auto-connect to CollisionObject2D signals (Area2D, StaticBody2D, RigidBody2D, etc.).
## Connects directly to native Godot signals — no wrapper signal checks needed.
func _connect_collision_object_2d_signals(col_obj: CollisionObject2D) -> void:
	match trigger_on:
		TriggerEvent.ON_PRESS:
			# Any mouse button press on collision shape
			if not col_obj.input_event.is_connected(_on_collision_input_press_2d):
				col_obj.input_event.connect(_on_collision_input_press_2d)
			# Area-specific: physics body and area overlap
			if col_obj is Area2D:
				if not col_obj.body_entered.is_connected(_on_area_body_entered):
					col_obj.body_entered.connect(_on_area_body_entered)
				if not col_obj.area_entered.is_connected(_on_area_area_entered):
					col_obj.area_entered.connect(_on_area_area_entered)
		TriggerEvent.ON_RELEASE:
			# Any mouse button release on collision shape
			if not col_obj.input_event.is_connected(_on_collision_input_release_2d):
				col_obj.input_event.connect(_on_collision_input_release_2d)
			# Area-specific: physics body and area overlap exit
			if col_obj is Area2D:
				if not col_obj.body_exited.is_connected(_on_area_body_exited):
					col_obj.body_exited.connect(_on_area_body_exited)
				if not col_obj.area_exited.is_connected(_on_area_area_exited):
					col_obj.area_exited.connect(_on_area_area_exited)
		TriggerEvent.ON_HOVER_START:
			# Native mouse_entered/exited — polarity pair (in on enter, out on exit)
			if not col_obj.mouse_entered.is_connected(_on_trigger_polarity_on):
				col_obj.mouse_entered.connect(_on_trigger_polarity_on)
			if not col_obj.mouse_exited.is_connected(_on_trigger_polarity_off):
				col_obj.mouse_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_HOVER_END:
			# Native mouse_entered/exited — reversed polarity (in on exit, out on enter)
			if not col_obj.mouse_entered.is_connected(_on_trigger_polarity_on):
				col_obj.mouse_entered.connect(_on_trigger_polarity_on)
			if not col_obj.mouse_exited.is_connected(_on_trigger_polarity_off):
				col_obj.mouse_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_LEFT_CLICK:
			# Left mouse button only — filtered in the callback handler
			if not col_obj.input_event.is_connected(_on_collision_input_filtered_2d):
				col_obj.input_event.connect(_on_collision_input_filtered_2d)
		TriggerEvent.ON_RIGHT_CLICK:
			# Right mouse button only — filtered in the callback handler
			if not col_obj.input_event.is_connected(_on_collision_input_filtered_2d):
				col_obj.input_event.connect(_on_collision_input_filtered_2d)
		TriggerEvent.ON_MIDDLE_CLICK:
			# Middle mouse button only — filtered in the callback handler
			if not col_obj.input_event.is_connected(_on_collision_input_filtered_2d):
				col_obj.input_event.connect(_on_collision_input_filtered_2d)
		TriggerEvent.ON_BODY_ENTERED:
			# Area-only: physics body entered
			if col_obj is Area2D:
				if not col_obj.body_entered.is_connected(_on_area_body_entered):
					col_obj.body_entered.connect(_on_area_body_entered)
		TriggerEvent.ON_BODY_EXITED:
			# Area-only: physics body exited
			if col_obj is Area2D:
				if not col_obj.body_exited.is_connected(_on_area_body_exited):
					col_obj.body_exited.connect(_on_area_body_exited)
		TriggerEvent.ON_AREA_ENTERED:
			# Area-only: another area entered
			if col_obj is Area2D:
				if not col_obj.area_entered.is_connected(_on_area_area_entered):
					col_obj.area_entered.connect(_on_area_area_entered)
		TriggerEvent.ON_AREA_EXITED:
			# Area-only: another area exited
			if col_obj is Area2D:
				if not col_obj.area_exited.is_connected(_on_area_area_exited):
					col_obj.area_exited.connect(_on_area_area_exited)
	
	if debug_enabled:
		print("[%s] Auto-connected to %s '%s' on %s" % [name, col_obj.get_class(), col_obj.name, TriggerEvent.keys()[trigger_on]])


func _connect_animation_signals(anim: AnimationPlayer) -> void:
	if not anim.animation_finished.is_connected(_on_animation_finished):
		anim.animation_finished.connect(_on_animation_finished)
	
	if debug_enabled:
		print("[%s] Auto-connected to AnimationPlayer '%s'" % [name, anim.name])


## Connect to visibility_changed signal for ON_SHOW / ON_HIDE triggers
## Works on any CanvasItem (Control, Node2D, etc.)
func _connect_visibility_signals(canvas_item: CanvasItem) -> void:
	if not canvas_item.visibility_changed.is_connected(_on_visibility_changed):
		canvas_item.visibility_changed.connect(_on_visibility_changed)
	
	if debug_enabled:
		print("[%s] Auto-connected to CanvasItem '%s' visibility" % [name, canvas_item.name])


## Connect to a manually specified signal
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
			if debug_enabled:
				print("[%s] Connected to manual signal '%s' on '%s'" % [name, manual_trigger_signal, source.name])
	else:
		if debug_enabled:
			push_warning("[%s] Signal '%s' not found on '%s'" % [name, manual_trigger_signal, source.name])

# =============================================================================
# SIGNAL CALLBACKS
# =============================================================================

func _on_area_body_entered(_body: Node) -> void:
	_on_trigger_momentary()


func _on_area_body_exited(_body: Node) -> void:
	_on_trigger_momentary()


## CollisionObject3D input_event — filters for mouse button press (click on collision shape)
func _on_collision_input_press_3d(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_trigger_momentary()


## CollisionObject3D input_event — filters for mouse button release
func _on_collision_input_release_3d(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and not event.pressed:
		_on_trigger_momentary()


## CollisionObject2D input_event — filters for mouse button press (click on collision shape)
func _on_collision_input_press_2d(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_trigger_momentary()


## CollisionObject2D input_event — filters for mouse button release
func _on_collision_input_release_2d(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and not event.pressed:
		_on_trigger_momentary()


## CollisionObject3D input_event — filters by specific mouse button based on trigger_on.
## Used by ON_LEFT_CLICK, ON_RIGHT_CLICK, ON_MIDDLE_CLICK trigger events.
func _on_collision_input_filtered_3d(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed:
		return
	var mb := event as InputEventMouseButton
	match trigger_on:
		TriggerEvent.ON_LEFT_CLICK:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_on_trigger_momentary()
		TriggerEvent.ON_RIGHT_CLICK:
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				_on_trigger_momentary()
		TriggerEvent.ON_MIDDLE_CLICK:
			if mb.button_index == MOUSE_BUTTON_MIDDLE:
				_on_trigger_momentary()


## CollisionObject2D input_event — filters by specific mouse button based on trigger_on.
## Used by ON_LEFT_CLICK, ON_RIGHT_CLICK, ON_MIDDLE_CLICK trigger events.
func _on_collision_input_filtered_2d(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed:
		return
	var mb := event as InputEventMouseButton
	match trigger_on:
		TriggerEvent.ON_LEFT_CLICK:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_on_trigger_momentary()
		TriggerEvent.ON_RIGHT_CLICK:
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				_on_trigger_momentary()
		TriggerEvent.ON_MIDDLE_CLICK:
			if mb.button_index == MOUSE_BUTTON_MIDDLE:
				_on_trigger_momentary()


## Area3D/2D area_entered — another area entered this area's space
func _on_area_area_entered(_area: Node) -> void:
	_on_trigger_momentary()


## Area3D/2D area_exited — another area exited this area's space
func _on_area_area_exited(_area: Node) -> void:
	_on_trigger_momentary()


## Control gui_input — filters for mouse button press on non-button Controls
func _on_control_gui_input_press(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_trigger_momentary()


## Control gui_input — filters for mouse button release on non-button Controls
func _on_control_gui_input_release(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		_on_trigger_momentary()


func _on_animation_finished(_anim_name: StringName) -> void:
	_on_trigger_momentary()


## Callback for visibility_changed signal (ON_SHOW / ON_HIDE triggers)
## visibility_changed doesn't pass the new state, so we check is_visible()
func _on_visibility_changed() -> void:
	var is_now_visible: bool = _target_node.is_visible() if _target_node else false
	
	match trigger_on:
		TriggerEvent.ON_SHOW:
			_on_trigger_polarity(is_now_visible)
		TriggerEvent.ON_HIDE:
			_on_trigger_polarity(not is_now_visible)

# =============================================================================
# DURATION & EASING (Direction-Aware)
# =============================================================================

## Get the duration for the current animation direction.
## In ping-pong mode, duration follows the curve being used (not just target direction),
## because reversed phases reuse the original curve's duration.
func _get_current_duration() -> float:
	var base_duration: float
	if ping_pong:
		base_duration = duration_out if _pp_use_out_curve else duration_in
	else:
		base_duration = duration_in if _target_progress > 0.5 else duration_out
	
	# Believable interruption:
	# If we interrupt at progress 0.75 and start animating OUT to 0.0, the OUT phase should
	# take 0.75 * duration_out seconds. This keeps the total time proportional to the actual
	# distance traveled in progress space.
	var remaining_distance: float = absf(_target_progress - _start_progress)
	return base_duration * remaining_distance


## Apply direction-aware easing to normalized progress (0.0 to 1.0).
## Uses Godot's built-in Tween interpolation for standard curves,
## or custom implementations for ELASTIC/BACK with configurable parameters.
## In ping-pong reversed phases, time is inverted (1.0 - t) to play the curve backward.
func _apply_easing(progress: float) -> float:
	# Reverse time for ping-pong reversed phases (tape rewind effect).
	# This plays the same curve shape backward without needing a separate reversed resource.
	var t := progress
	if _pp_reversed:
		t = 1.0 - t
	
	# Determine which curve to use: IN or OUT.
	# In ping-pong mode, the phase config overrides the normal direction check
	# because reversed phases swap which curve is active.
	var use_in_curve: bool
	if ping_pong:
		use_in_curve = not _pp_use_out_curve
	else:
		use_in_curve = _target_progress > 0.5
	
	if use_in_curve:
		# Custom curve overrides everything
		if custom_curve_in != null:
			return custom_curve_in.sample(t)
		# ELASTIC and BACK need custom implementation for configurable params
		if transition_in == Tween.TRANS_ELASTIC:
			return _ease_elastic(t, ease_in, elastic_amplitude_in, elastic_period_in)
		if transition_in == Tween.TRANS_BACK:
			return _ease_back(t, ease_in, back_overshoot_in)
		# Use Godot's Tween interpolation for all other transitions
		return Tween.interpolate_value(0.0, 1.0, t, 1.0, transition_in, ease_in)
	else:
		# Custom curve overrides everything
		if custom_curve_out != null:
			return custom_curve_out.sample(t)
		# ELASTIC and BACK need custom implementation for configurable params
		if transition_out == Tween.TRANS_ELASTIC:
			return _ease_elastic(t, ease_out, elastic_amplitude_out, elastic_period_out)
		if transition_out == Tween.TRANS_BACK:
			return _ease_back(t, ease_out, back_overshoot_out)
		# Use Godot's Tween interpolation for all other transitions
		return Tween.interpolate_value(0.0, 1.0, t, 1.0, transition_out, ease_out)


## Custom ELASTIC easing with configurable amplitude and period.
## Based on Robert Penner's easing equations.
func _ease_elastic(t: float, ease_type: Tween.EaseType, amplitude: float, period: float) -> float:
	if t == 0.0 or t == 1.0:
		return t
	
	var s: float = period / TAU * asin(1.0 / amplitude)
	
	match ease_type:
		Tween.EASE_IN:
			t -= 1.0
			return -(amplitude * pow(2.0, 10.0 * t) * sin((t - s) * TAU / period))
		Tween.EASE_OUT:
			return amplitude * pow(2.0, -10.0 * t) * sin((t - s) * TAU / period) + 1.0
		Tween.EASE_IN_OUT:
			t *= 2.0
			if t < 1.0:
				t -= 1.0
				return -0.5 * amplitude * pow(2.0, 10.0 * t) * sin((t - s) * TAU / period)
			else:
				t -= 1.0
				return amplitude * pow(2.0, -10.0 * t) * sin((t - s) * TAU / period) * 0.5 + 1.0
		_:  # EASE_OUT_IN
			if t < 0.5:
				return _ease_elastic(t * 2.0, Tween.EASE_OUT, amplitude, period) * 0.5
			else:
				return _ease_elastic(t * 2.0 - 1.0, Tween.EASE_IN, amplitude, period) * 0.5 + 0.5


## Custom BACK easing with configurable overshoot.
## Based on Robert Penner's easing equations.
func _ease_back(t: float, ease_type: Tween.EaseType, overshoot: float) -> float:
	match ease_type:
		Tween.EASE_IN:
			return t * t * ((overshoot + 1.0) * t - overshoot)
		Tween.EASE_OUT:
			t -= 1.0
			return t * t * ((overshoot + 1.0) * t + overshoot) + 1.0
		Tween.EASE_IN_OUT:
			var s := overshoot * 1.525
			t *= 2.0
			if t < 1.0:
				return 0.5 * (t * t * ((s + 1.0) * t - s))
			else:
				t -= 2.0
				return 0.5 * (t * t * ((s + 1.0) * t + s) + 2.0)
		_:  # EASE_OUT_IN
			if t < 0.5:
				return _ease_back(t * 2.0, Tween.EASE_OUT, overshoot) * 0.5
			else:
				return _ease_back(t * 2.0 - 1.0, Tween.EASE_IN, overshoot) * 0.5 + 0.5

# =============================================================================
# LOOP HANDLING
# =============================================================================

func _on_cycle_complete() -> void:
	# --- Ping-pong phase advancement ---
	# In PING_PONG mode, each "cycle" in _process is actually one phase of a multi-phase
	# ping-pong cycle. We advance the phase first, and only count a full loop when the
	# phase wraps back to 0.
	if ping_pong:
		var phases_per_cycle := _get_ping_pong_phases_per_cycle()
		var next_phase := (_ping_pong_phase + 1) % phases_per_cycle
		
		if next_phase != 0:
			# Mid-cycle: advance phase
			# Capture completed phase's duration BEFORE configuring the new phase
			var completed_duration := _get_current_duration()
			
			# Hold at peak if this phase ended at peak (phase 0 always goes toward 1.0).
			# Pause processing during hold, then resume for the next phase.
			if _ping_pong_phase == 0 and hold_at_peak > 0.0:
				_in_hold_at_peak = true
				set_process(false)
				if debug_enabled:
					print("[%s] Ping-pong: holding at peak for %.2fs" % [name, hold_at_peak])
				await get_tree().create_timer(hold_at_peak).timeout
				_in_hold_at_peak = false
				if not _is_playing:
					return  # Stopped during hold
			
			_ping_pong_phase = next_phase
			_configure_ping_pong_phase()
			# Carry over excess time so phases don't accumulate ~1 frame of drift each
			_elapsed = _elapsed - completed_duration
			if debug_enabled:
				var curve_str := "OUT" if _pp_use_out_curve else "IN"
				var rev_str := " REVERSED" if _pp_reversed else ""
				print("[%s] Ping-pong phase %d: %.1f → %.1f (%s%s)" % [
					name, _ping_pong_phase, _start_progress, _target_progress, curve_str, rev_str])
			# Resume processing for the next phase (may have been paused by hold)
			set_process(true)
			return
		
		# Full cycle complete — fall through to loop counting below
	
	# --- PLAY_IN_AND_OUT (non-ping-pong): IN phase always chains to OUT via _finish(). ---
	# The full IN+OUT pair is one "loop iteration" — loop counting happens after OUT.
	if _is_play_in_and_out_active and _target_progress > 0.5 and not ping_pong:
		if debug_enabled:
			print("[%s] Cycle complete: IN done (progress=%.2f), chaining to OUT via _finish()" % [name, _animation_progress])
		_finish()
		return
	
	if debug_enabled:
		print("[%s] Cycle complete: target=%.2f | loop=%d/%d | play_in_out=%s" % [
			name, _target_progress, _current_loop, loop_count, _is_play_in_and_out_active])
	_current_loop += 1
	
	# Check if we should continue looping
	var should_continue := false
	if loop_count < 0:  # Infinite
		if ping_pong:
			# Ping-pong always continues in infinite mode — a full cycle returns
			# to the starting state, so it's naturally safe to keep going
			should_continue = true
		elif _is_play_in_and_out_active:
			# OUT phase of PLAY_IN_AND_OUT just completed — restart full IN+OUT cycle
			should_continue = true
		else:
			# Only continue infinite loop when animating IN (sustaining the effect)
			# When animating OUT (releasing), always complete in one cycle
			should_continue = (_target_progress > 0.0)
	elif _current_loop < loop_count:
		should_continue = true
	
	if should_continue:
		# Carry over excess time so loops don't accumulate timing drift
		_elapsed = _elapsed - _get_current_duration()
		
		# For ping-pong, reset to phase 0 for the next cycle
		if ping_pong:
			_ping_pong_phase = 0
			_configure_ping_pong_phase()
			if debug_enabled:
				print("[%s] Ping-pong cycle %d starting" % [name, _current_loop + 1])
		
		# PLAY_IN_AND_OUT: restart full IN+OUT cycle from the IN phase
		if _is_play_in_and_out_active and not ping_pong:
			_start_progress = 0.0
			_target_progress = 1.0
			_is_one_shot_return = false
			_on_animate_start()
			if debug_enabled:
				print("[%s] PLAY_IN_AND_OUT cycle %d restarting" % [name, _current_loop + 1])
			if loop_delay > 0.0:
				set_process(false)
				await get_tree().create_timer(loop_delay).timeout
				if _is_playing:
					set_process(true)
			return
		
		# Apply loop delay if any (between full cycles, not between phases)
		if loop_delay > 0.0:
			set_process(false)
			await get_tree().create_timer(loop_delay).timeout
			if _is_playing:  # Could have been stopped during delay
				set_process(true)
	else:
		# All loops complete
		_finish()


## Returns the number of phases in one full ping-pong cycle.
## PLAY_IN_AND_OUT uses 4 phases (IN▶ OUT▶ ◀OUT ◀IN).
## All other trigger behaviours use 2 phases (forward + reversed of one curve).
func _get_ping_pong_phases_per_cycle() -> int:
	if trigger_behaviour == TriggerBehaviour.PLAY_IN_AND_OUT or _force_play_in_and_out_once:
		return 4
	return 2


## Configure start/target progress, curve source, and reversal flag for the current
## ping-pong phase. Called when advancing to a new phase within a cycle.
func _configure_ping_pong_phase() -> void:
	var phases := _get_ping_pong_phases_per_cycle()
	
	if phases == 4:
		# 4-phase tape rewind: IN▶ OUT▶ ◀OUT ◀IN
		# Reversed phases keep the SAME start/target as their forward counterpart.
		# The easing reversal (t = 1-t) alone flips the visual direction, so swapping
		# start/target too would double-reverse and cancel out (the original bug).
		match _ping_pong_phase:
			0:
				_start_progress = 0.0; _target_progress = 1.0
				_pp_use_out_curve = false; _pp_reversed = false
			1:
				_start_progress = 1.0; _target_progress = 0.0
				_pp_use_out_curve = true; _pp_reversed = false
			2:  # Reverse of phase 1 — same start/target, easing plays backward
				_start_progress = 1.0; _target_progress = 0.0
				_pp_use_out_curve = true; _pp_reversed = true
			3:  # Reverse of phase 0 — same start/target, easing plays backward
				_start_progress = 0.0; _target_progress = 1.0
				_pp_use_out_curve = false; _pp_reversed = true
	else:
		# 2-phase bounce: same curve forward then reversed.
		# _pp_use_out_curve is preserved from phase 0 setup (set in _animate_to).
		# Phase 1 keeps the SAME start/target as phase 0 — the easing reversal
		# alone flips the visual direction (swapping both would cancel out).
		match _ping_pong_phase:
			0:
				_pp_reversed = false
				if _pp_use_out_curve:
					_start_progress = 1.0; _target_progress = 0.0
				else:
					_start_progress = 0.0; _target_progress = 1.0
			1:  # Reverse of phase 0 — same start/target, easing plays backward
				_pp_reversed = true
				if _pp_use_out_curve:
					_start_progress = 1.0; _target_progress = 0.0
				else:
					_start_progress = 0.0; _target_progress = 1.0


## Reset ping-pong state to defaults. Called when stopping or starting non-ping-pong animations.
func _reset_ping_pong() -> void:
	_ping_pong_phase = 0
	_pp_use_out_curve = false
	_pp_reversed = false


func _finish() -> void:
	# Snap to exact final progress.
	# For ping-pong reversed phases, the easing reversal (t = 1-t) flips the
	# interpolation direction, so the visual end state is _start_progress,
	# not _target_progress. Using _target_progress here would cause a visible
	# snap (e.g., animation smoothly reaches 0.0, then jumps to 1.0).
	if ping_pong and _pp_reversed:
		_animation_progress = _start_progress
	else:
		_animation_progress = _target_progress
	_apply_effect(_animation_progress)
	
	var just_animated_in := _animation_progress >= 0.5
	
	# Check if we need to chain into animate_out (PLAY_IN_AND_OUT pattern).
	# In PING_PONG mode, the OUT phase is part of the ping-pong cycle,
	# so _finish() should never chain to animate_out — the cycle already handled it.
	var will_chain_out := just_animated_in and not _is_one_shot_return and (
		trigger_behaviour == TriggerBehaviour.PLAY_IN_AND_OUT or _force_play_in_and_out_once
	) and not ping_pong
	
	if will_chain_out:
		# Notify subclass that IN phase reached peak (before hold/out chain)
		_on_animate_in_complete()
		
		# Hold at peak if configured — pause processing while we wait,
		# then chain to animate_out after the hold expires.
		if hold_at_peak > 0.0:
			_in_hold_at_peak = true
			set_process(false)
			if debug_enabled:
				print("[%s] _finish(): holding at peak for %.2fs" % [name, hold_at_peak])
			await get_tree().create_timer(hold_at_peak).timeout
			_in_hold_at_peak = false
			# Could have been stopped during hold (e.g., stop() called externally)
			if not _is_playing:
				return
		
		if debug_enabled:
			print("[%s] _finish(): chaining OUT (one_shot_return)" % name)
		_is_play_in_and_out_active = true
		animate_out(true)
		return
	
	if debug_enabled:
		print("[%s] _finish(): DONE | progress=%.2f | emitting completed" % [name, _animation_progress])
	_is_playing = false
	set_process(false)
	
	# Let subclass finalize based on direction
	# animate_in complete (progress=1) → hold effect, don't restore
	# animate_out complete (progress=0) → restore to base state
	if just_animated_in:
		_on_animate_in_complete()
	else:
		_on_animate_out_complete()
	
	if _is_play_in_and_out_active and not just_animated_in:
		_is_play_in_and_out_active = false
		_force_play_in_and_out_once = false
	
	completed.emit()
	
	if debug_enabled:
		print("[%s] Completed at progress %.2f" % [name, _animation_progress])
	
	# Chain to next component
	_trigger_next_component()
	
	# If a trigger was queued while playing, execute it now.
	if not _queued_trigger.is_empty():
		var queued := _queued_trigger
		_queued_trigger = {}
		_handle_trigger(queued)


func _trigger_next_component() -> void:
	if next_component.is_empty():
		return
	
	var next_juice = get_node_or_null(next_component)
	if next_juice == null:
		if debug_enabled:
			push_warning("[%s] Next component not found: %s" % [name, next_component])
		return
	
	if next_juice.has_method("animate_in"):
		next_juice.animate_in()
		if debug_enabled:
			print("[%s] Chained to '%s'" % [name, next_juice.name])


func _recipe_capture_natural(_target: Node) -> Variant:
	return null


func _recipe_apply_natural(_target: Node, _natural: Variant) -> void:
	pass


func _recipe_restore_natural(_target: Node, _natural: Variant) -> void:
	pass

# =============================================================================
# VIRTUAL METHODS (Subclasses Override)
# =============================================================================

## Called when animation starts (animate_in or animate_out)
## Subclass can prepare per-animation state here
func _on_animate_start() -> void:
	pass  # Subclass implements


## Called when target node changes (in recipe mode via animate_in_on/animate_out_on)
## Subclass should reset its base value cache flag so it re-captures for the new target node
func _invalidate_base_cache() -> void:
	pass  # Subclass implements


## Returns an identity key for sibling interruption matching.
## Siblings with the same identity interrupt each other when interrupt_siblings is true.
## Default: script class (all instances of the same component type interrupt each other).
## Override in subclasses that use a single script for multiple distinct targets
## (e.g., transform comps with different transform_target enums).
func _get_interrupt_identity() -> Variant:
	return get_script()


## Called when animate_in completes (progress reached 1.0)
## Default: do nothing (hold the animated state)
## Override if you need special behavior when effect reaches full strength
func _on_animate_in_complete() -> void:
	pass  # Most effects just hold at full strength

## Called when animate_out completes (progress reached 0.0)
## Default: do nothing (effect already at base via _apply_effect(0))
## Override to restore exact base values if needed
func _on_animate_out_complete() -> void:
	pass  # Subclass can restore exact base values here


## Whether this comp type supports editor preview via Transport Controls.
## Default: true. Override to return false for comps that genuinely crash in editor
## (no known cases yet — camera/screen comps degrade gracefully if receiver is missing).
func _supports_editor_preview() -> bool:
	return true


## Temporarily undo this comp's visual effect on the target.
## Used by the save pipeline (JuicePreviewDirector.temporarily_restore_natural)
## to prevent mid-animation or From-state values from being baked into scenes.
## The default implementation is a no-op — subclasses that modify serializable
## target properties (position, rotation, scale, modulate, etc.) MUST override.
func _temporarily_undo_visual() -> void:
	pass


## Re-apply this comp's visual effect after a temporary undo.
## Called via deferred after the save pipeline completes, restoring the preview
## to its pre-save visual state without touching contribution tracking.
func _temporarily_reapply_visual() -> void:
	pass


## Restore the target to its natural (unmodified) state when stop() is called.
## Default: calls _apply_effect(0.0) — correct for comps where progress 0 = no effect.
## Override in comps where progress 0 ≠ natural state (e.g., From/To Transform model,
## Shake/Noise/Spring that use absolute writes with a captured base).
func _restore_to_natural() -> void:
	_apply_effect(0.0)


## Apply the effect at the given progress (0.0 = natural state, 1.0 = fully applied)
## This is the core animation logic - subclass MUST implement
## Progress interpolates smoothly, so subclass just applies the offset scaled by progress
func _apply_effect(_progress: float) -> void:
	push_error("[%s] _apply_effect not implemented in subclass!" % name)


# =============================================================================
# HELPER METHODS FOR SUBCLASSES
# =============================================================================

## Get the size of the target node (for percentage-based calculations)
func _get_target_size() -> Vector2:
	if _target_node is Control:
		return (_target_node as Control).size
	elif _target_node is Node2D:
		# Node2D doesn't have intrinsic size, return zero
		return Vector2.ZERO
	return Vector2.ZERO


## Get the size of the target's parent (for percentage-based calculations)
func _get_parent_size() -> Vector2:
	var parent = _target_node.get_parent() if _target_node else null
	if parent is Control:
		return (parent as Control).size
	return Vector2.ZERO


## Get viewport size (for percentage-based calculations)
func _get_viewport_size() -> Vector2:
	if _target_node:
		return _target_node.get_viewport().get_visible_rect().size
	return Vector2.ZERO
