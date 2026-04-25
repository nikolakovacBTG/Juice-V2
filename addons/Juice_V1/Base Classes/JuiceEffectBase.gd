## Base class for all Juice effects. Extend this to create custom effects.
##
## Effects are [Resource]s with timing, easing, and animation state. A host
## node ([JuiceControl], [Juice2D], [Juice3D]) ticks them each frame.
## Subclasses override [method _apply_effect] to implement their visual behavior.

# ============================================================================
# WHAT: Base class for all juice effects in the JuiceStack system.
# WHY: Provides shared timing, easing, animation loop, and virtual methods so
#      concrete effects only implement their specific visual/audio behavior.
#      Effects are Resources (not Nodes) — they hold config + math + state
#      but have no scene tree lifecycle. A host node (JuiceControl etc.) ticks them.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Implement any visual/audio effect — subclasses do that.
# DOES NOT: Auto-connect signals or manage triggers — the host node does that.
# DOES NOT: Store persistent references to Nodes — target is always passed in.
# ============================================================================

@tool
class_name JuiceEffectBase
extends Resource

# =============================================================================
# ENUMS
# =============================================================================

## What this effect does when its trigger fires.
## Controls which animation directions are available — changing this hides/shows
## the Animate In / Animate Out groups in the inspector.
enum TriggerBehaviour {
	PLAY_IN_AND_OUT,  ## Trigger → animate in, then auto-reverse to out
	PLAY_IN_ONLY,     ## Trigger → animate in only (hold at peak)
	PLAY_OUT_ONLY,    ## Trigger → animate out only (start from peak)
	TOGGLE,           ## Trigger alternates between in and out
	SET_FROM_SOURCE,  ## External progress source controls direction
}

## How to interpret offset/delta values for position and scale
enum OffsetUnit { PIXELS, OWN_SIZE, PARENT_SIZE, VIEWPORT_SIZE }

## How to interpret rotation values
enum RotationUnit { DEGREES, RADIANS }

## Result returned by tick() each frame
enum TickResult {
	PLAYING,           ## Effect is still running.
	COMPLETED,         ## Effect finished — host should clean up.
	RESTART_REVERSED,  ## Accumulation effect hit REVERSE_EASED bound — restart from beginning (direction already flipped).
}

# =============================================================================
# CONFIGURATION
# =============================================================================

# --- EFFECT GROUP PROPERTIES (emitted via _get_property_list) ---
# These are NOT @export — subclasses inject them into the "Effect" group
# via _get_effect_base_properties(). If no subclass overrides, the base
# emits them in its own "Effect" group as fallback.

## What this effect does when triggered. Overrides the node's trigger_behaviour.
var trigger_behaviour: TriggerBehaviour = TriggerBehaviour.PLAY_IN_ONLY:
	set(value):
		trigger_behaviour = value
		notify_property_list_changed()

## Delay before this effect starts (seconds). Used for layered stagger in stacks.
var start_delay: float = 0.0

## Number of times to loop (-1 = infinite, 0 = don't play, 1+ = play N times).
var loop_count: int = 1:
	set(value):
		loop_count = value
		notify_property_list_changed()

## Reverse direction each cycle (tape rewind).
var ping_pong: bool = false

## Delay between loop cycles (seconds).
var loop_delay: float = 0.0

## Starting phase offset for looping (0.0–1.0). Only affects first cycle.
var loop_phase_offset: float = 0.0

# Set to true by subclasses that emit the Effect group in their own
# _get_property_list(). When false, the base emits it as a fallback.
var _subclass_owns_effect_group: bool = false

# =============================================================================
# CONDITIONAL BACKING VARIABLES (shown/hidden via _get_property_list)
# =============================================================================

# --- ANIMATE IN ---
## Time to hold at peak before auto-reverse (seconds). Only for PLAY_IN_AND_OUT.
var hold_at_peak: float = 0.0
## Duration of the animate-in phase (seconds).
var duration_in: float = 0.3
## Easing transition type for animate-in. Ignored when Custom Curve In is set.
var transition_in: Tween.TransitionType = Tween.TRANS_QUAD:
	set(value):
		transition_in = value
		notify_property_list_changed()
## Easing direction for animate-in. Ignored when Custom Curve In is set.
var ease_in: Tween.EaseType = Tween.EASE_OUT
## Custom easing curve for animate-in. Overrides Transition In and Ease In.
var custom_curve_in: Curve:
	set(value):
		custom_curve_in = value
		notify_property_list_changed()
## Amplitude multiplier for Elastic transitions (animate-in).
var elastic_amplitude_in: float = 1.0
## Period of the elastic wave for Elastic transitions (animate-in).
var elastic_period_in: float = 0.3
## Overshoot amount for Back transitions (animate-in).
var back_overshoot_in: float = 1.70158

# --- ANIMATE OUT ---
## Duration of the animate-out phase (seconds).
var duration_out: float = 0.3
## Easing transition type for animate-out. Ignored when Custom Curve Out is set.
var transition_out: Tween.TransitionType = Tween.TRANS_QUAD:
	set(value):
		transition_out = value
		notify_property_list_changed()
## Easing direction for animate-out. Ignored when Custom Curve Out is set.
var ease_out: Tween.EaseType = Tween.EASE_IN
## Custom easing curve for animate-out. Overrides Transition Out and Ease Out.
var custom_curve_out: Curve:
	set(value):
		custom_curve_out = value
		notify_property_list_changed()
## Amplitude multiplier for Elastic transitions (animate-out).
var elastic_amplitude_out: float = 1.0
## Period of the elastic wave for Elastic transitions (animate-out).
var elastic_period_out: float = 0.3
## Overshoot amount for Back transitions (animate-out).
var back_overshoot_out: float = 1.70158

# --- MIRROR ---
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _btn_mirror_in_to_out: Callable:
	get: return _mirror_in_to_out

# --- RETRIGGER CROSSFADE ---
## Blend time when switching direction mid-animation (retrigger with RESTART policy).
var crossfade_time: float = 0.0

# --- CHAINING ---
## References to other effects in the same recipe to trigger when this completes.
## Array allows triggering multiple effects simultaneously.
var chain_to: Array[JuiceEffectBase] = []:
	set(value):
		chain_to = value
		notify_property_list_changed()

## Stop sibling effects with same interrupt identity when this starts.
var interrupt_siblings: bool = false

## Start the chained effects this many seconds before this effect completes.
## Creates visual overlap between effects (e.g. squash on impact).
## Auto-clamped to this effect's total duration. Only visible when chain_to is not empty.
var chained_preroll: float = 0.0:
	set(value):
		chained_preroll = clampf(value, 0.0, _get_max_chained_preroll())

# --- DEBUG ---
## Enable debug print statements to console during animation.
var debug_enabled: bool = false

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

const _TRANSITION_HINT := "Linear,Sine,Quint,Quart,Quad,Expo,Elastic,Cubic,Circ,Bounce,Back,Spring"
const _EASE_HINT := "In,Out,In-Out,Out-In"


## Returns property dicts for the base Effect group properties
## (trigger_behaviour, start_delay, loop settings). Subclasses call this
## in their _get_property_list() to inject them after their own selector.
func _get_effect_base_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	props.append({"name": "trigger_behaviour", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Play In And Out,Play In Only,Play Out Only,Toggle,Set From Source",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "start_delay", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,100.0,0.01,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "crossfade_time", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,10.0,0.01,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "loop_count", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT})
	var is_looping := loop_count != 1
	if is_looping:
		props.append({"name": "ping_pong", "type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "loop_delay", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "loop_phase_offset", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
			"usage": PROPERTY_USAGE_DEFAULT})
	return props

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# If no subclass owns the Effect group, emit it here as fallback.
	# This covers effects that don't override _get_property_list (e.g. SquashStretch).
	if not _subclass_owns_effect_group:
		props.append({"name": "Effect", "type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
		props.append_array(_get_effect_base_properties())

	var show_in := trigger_behaviour != TriggerBehaviour.PLAY_OUT_ONLY
	var show_out := trigger_behaviour != TriggerBehaviour.PLAY_IN_ONLY

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
		props.append({"name": "hold_at_peak", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT})

	if show_out:
		props.append({"name": "Animate Out", "type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
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

	# --- Chaining group ---
	props.append({"name": "Chaining", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "chain_to", "type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_ARRAY_TYPE, "hint_string": "JuiceEffectBase",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "interrupt_siblings", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})
	if not chain_to.is_empty():
		props.append({"name": "chained_preroll", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT})

	# --- Debug ---
	props.append({"name": "Debug", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "debug_enabled", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"duration_in": duration_in = value; return true
		&"transition_in": transition_in = value; return true
		&"ease_in": ease_in = value; return true
		&"custom_curve_in": custom_curve_in = value; return true
		&"elastic_amplitude_in": elastic_amplitude_in = value; return true
		&"elastic_period_in": elastic_period_in = value; return true
		&"back_overshoot_in": back_overshoot_in = value; return true
		&"hold_at_peak": hold_at_peak = value; return true
		&"duration_out": duration_out = value; return true
		&"transition_out": transition_out = value; return true
		&"ease_out": ease_out = value; return true
		&"custom_curve_out": custom_curve_out = value; return true
		&"elastic_amplitude_out": elastic_amplitude_out = value; return true
		&"elastic_period_out": elastic_period_out = value; return true
		&"back_overshoot_out": back_overshoot_out = value; return true
		&"chain_to": chain_to = value; return true
		&"interrupt_siblings": interrupt_siblings = value; return true
		&"chained_preroll": chained_preroll = value; return true
		&"crossfade_time": crossfade_time = value; return true
		&"debug_enabled": debug_enabled = value; return true
		# Effect group properties (now dynamic, not @export)
		&"trigger_behaviour": trigger_behaviour = value; return true
		&"start_delay": start_delay = value; return true
		&"loop_count": loop_count = value; return true
		&"ping_pong": ping_pong = value; return true
		&"loop_delay": loop_delay = value; return true
		&"loop_phase_offset": loop_phase_offset = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"duration_in": return duration_in
		&"transition_in": return transition_in
		&"ease_in": return ease_in
		&"custom_curve_in": return custom_curve_in
		&"elastic_amplitude_in": return elastic_amplitude_in
		&"elastic_period_in": return elastic_period_in
		&"back_overshoot_in": return back_overshoot_in
		&"hold_at_peak": return hold_at_peak
		&"duration_out": return duration_out
		&"transition_out": return transition_out
		&"ease_out": return ease_out
		&"custom_curve_out": return custom_curve_out
		&"elastic_amplitude_out": return elastic_amplitude_out
		&"elastic_period_out": return elastic_period_out
		&"back_overshoot_out": return back_overshoot_out
		&"_btn_mirror_in_to_out": return _mirror_in_to_out
		&"chain_to": return chain_to
		&"interrupt_siblings": return interrupt_siblings
		&"chained_preroll": return chained_preroll
		&"crossfade_time": return crossfade_time
		&"debug_enabled": return debug_enabled
		# Effect group properties (now dynamic, not @export)
		&"trigger_behaviour": return trigger_behaviour
		&"start_delay": return start_delay
		&"loop_count": return loop_count
		&"ping_pong": return ping_pong
		&"loop_delay": return loop_delay
		&"loop_phase_offset": return loop_phase_offset
	return null

# =============================================================================
# INTERNAL ANIMATION STATE
# =============================================================================

var _is_playing: bool = false
var _elapsed: float = 0.0
var _animation_progress: float = 0.0
var _target_progress: float = 0.0
var _start_progress: float = 0.0
var _current_loop: int = 0
var _is_one_shot_return: bool = false
var _will_auto_reverse: bool = false

# Tick-based delay states (replaces coroutine-based await in JuiceBase)
var _in_start_delay: bool = false
var _start_delay_duration: float = 0.0
var _delay_elapsed: float = 0.0
var _in_hold_at_peak: bool = false
var _hold_elapsed: float = 0.0
var _in_sustain: bool = false
var _in_loop_delay: bool = false
# Current frame delta — set at the start of every tick() call. Subclasses that need
# delta inside _apply_effect() read this instead of maintaining their own _tick_delta.
# This removes the need for per-effect tick() overrides just to capture delta.
var _current_delta: float = 0.0
var _loop_delay_elapsed: float = 0.0

# Crossfade state
var _crossfade_elapsed: float = 0.0
var _crossfade_start_progress: float = 0.0
var _is_crossfading: bool = false

# Chained preroll state
var _chained_preroll_triggered: bool = false

# Ping-pong state
var _ping_pong_phase: int = 0
var _pp_reversed: bool = false
var _pp_use_out_curve: bool = false

# Host node reference — set at start(), used for NodePath resolution.
# Not stored persistently; cleared on stop/finish.
var _host_node: Node = null

# Ledger base snapshot — injected by the caller before _on_animate_start fires.
# Contains the target's natural property values from the Centralized Metadata Ledger
# (e.g. {"position": Vector2(0, 40), "rotation": 0.0, "scale": Vector2(1, 1)}).
# SELF capture methods (e.g. _capture_from_self_position_snapshot) prefer this
# over target.property so they read the true natural state, not a dirty value
# that includes deltas from other Juice sources (sequencer, stacked nodes, etc.).
# Empty dict = no ledger data available → fall back to target.property (safe default).
var _ledger_base_snapshot: Dictionary = {}

# =============================================================================
# ANIMATION API (called by host node)
# =============================================================================

## Start animating this effect. play_in = true for animate_in, false for animate_out.
## use_start_delay: if false, skip this effect's start_delay (e.g. chained effects).
## Separates initialization from playback to support staggered chaining and external orchestration without relying on a central timeline.
func start(target: Node, play_in: bool, use_start_delay: bool = true, host: Node = null) -> void:
	# Determine direction based on play_in and trigger_behaviour
	if play_in:
		_target_progress = 1.0
		_will_auto_reverse = (trigger_behaviour == TriggerBehaviour.PLAY_IN_AND_OUT)
	else:
		_target_progress = 0.0
		_will_auto_reverse = false

	_start_progress = _animation_progress
	_is_playing = true
	_is_one_shot_return = false
	_in_sustain = false
	_current_loop = 0
	_elapsed = 0.0
	_chained_preroll_triggered = false
	_reset_ping_pong()

	# Initialize ping-pong state
	if ping_pong:
		_ping_pong_phase = 0
		_pp_reversed = false
		_pp_use_out_curve = (_target_progress <= 0.5)

	# Apply loop phase offset (first cycle only)
	if loop_phase_offset > 0.0:
		var phase_duration := _get_current_duration()
		_elapsed = phase_duration * loop_phase_offset

	# Store host node reference for NodePath resolution in subclasses
	if host != null:
		_host_node = host

	# Inject ledger base so SELF capture methods in _on_animate_start read the
	# true natural position (pre-all-Juice) rather than a dirty target.position
	# that may include active deltas from other Juice sources (sequencer, stacked nodes).
	# JuiceBase._ledger_get_base_dict returns {} if the target has no ledger — safe fallback.
	_ledger_base_snapshot = JuiceLedger.get_base_dict(target)

	_on_animate_start(target)

	# Force-first-frame: apply at start progress immediately
	_apply_effect(_start_progress, target)

	# Handle per-effect start delay via tick-based tracking
	var delay := start_delay if use_start_delay else 0.0
	if delay > 0.0:
		_in_start_delay = true
		_start_delay_duration = delay
		_delay_elapsed = 0.0


## Advance animation by one frame. Returns PLAYING or COMPLETED.
## Allows the domain host (e.g. JuiceControl) to drive effects synchronously. This ensures all active effects complete their math before a single combined write occurs per frame.
func tick(delta: float, target: Node) -> TickResult:
	# Keep _current_delta fresh for all _apply_effect calls this frame.
	# Subclasses read _current_delta instead of maintaining their own _tick_delta.
	_current_delta = delta
	if not _is_playing:
		return TickResult.COMPLETED

	# --- Start delay: hold at From state ---
	if _in_start_delay:
		_delay_elapsed += delta
		if _delay_elapsed < _start_delay_duration:
			_apply_effect(_start_progress, target)
			return TickResult.PLAYING
		_in_start_delay = false
		_elapsed = 0.0

	# --- Sustain: hold at peak indefinitely, keep applying effect ---
	if _in_sustain:
		_apply_effect(1.0, target)
		return TickResult.PLAYING

	# --- Hold at peak ---
	if _in_hold_at_peak:
		_hold_elapsed += delta
		# Keep procedural effects (Noise, Shake) alive during the hold window.
		# Without this, oscillators freeze on a single sample for the entire hold duration.
		# Non-procedural effects (_needs_sustain() = false) are unaffected.
		if _needs_sustain():
			_apply_effect(1.0, target)
		if _hold_elapsed < hold_at_peak:
			return TickResult.PLAYING
		_in_hold_at_peak = false
		# After hold, chain to animate_out if auto-reversing
		if _will_auto_reverse and not _is_one_shot_return:
			_start_animate_out_internal(target)
			return TickResult.PLAYING
		# After hold in ping-pong, continue to next phase
		_elapsed = 0.0

	# --- Loop delay ---
	if _in_loop_delay:
		_loop_delay_elapsed += delta
		if _loop_delay_elapsed < loop_delay:
			return TickResult.PLAYING
		_in_loop_delay = false
		_elapsed = 0.0

	# --- Normal animation ---
	_elapsed += delta
	var current_duration := _get_current_duration()
	var time_progress: float = clampf(_elapsed / current_duration, 0.0, 1.0) if current_duration > 0.0 else 1.0
	var eased_time: float = _apply_easing(time_progress)
	_animation_progress = lerpf(_start_progress, _target_progress, eased_time)

	# Crossfade handling
	if _is_crossfading and crossfade_time > 0.0:
		_crossfade_elapsed += delta
		var blend := clampf(_crossfade_elapsed / crossfade_time, 0.0, 1.0)
		var blended := lerpf(_crossfade_start_progress, _animation_progress, blend)
		_apply_effect(blended, target)
		if blend >= 1.0:
			_is_crossfading = false
	else:
		_apply_effect(_animation_progress, target)

	# Check cycle complete
	if _elapsed >= current_duration:
		return _handle_cycle_complete(target)

	return TickResult.PLAYING


## Stop immediately and restore to natural state.
## Provides a hard reset for sequence cancellation or target node cleanup, ensuring no visual residue is left behind.
func stop(target: Node) -> void:
	_is_playing = false
	_in_start_delay = false
	_in_hold_at_peak = false
	_in_sustain = false
	_in_loop_delay = false
	_animation_progress = 0.0
	_reset_ping_pong()
	_restore_to_natural(target)


## Stop but keep current visual state.
## Required for PLAY_IN_ONLY behaviors where the effect must freeze at peak and wait indefinitely for a reverse trigger.
func stop_and_hold() -> void:
	_is_playing = false
	_in_start_delay = false
	_in_hold_at_peak = false
	_in_sustain = false
	_in_loop_delay = false
	_reset_ping_pong()


## Directly set progress (for editor preview scrubbing).
## Exposes the internal math to the editor tools so designers can scrub the timeline without running the scene or triggering lifecycle events.
func set_progress(value: float, target: Node) -> void:
	_animation_progress = clampf(value, 0.0, 1.0)
	_apply_effect(_animation_progress, target)


## Check if currently animating
func is_playing() -> bool:
	return _is_playing


## Get current animation progress
func get_progress() -> float:
	return _animation_progress


# Estimate seconds remaining until this effect returns COMPLETED.
# Used by the host node to trigger chained_preroll at the right time.
# Required to support negative chained_preroll values, allowing subsequent effects in the sequence to overlap before this one finishes.
func _get_time_to_completion() -> float:
	if not _is_playing:
		return 0.0
	# Don't preroll during delays or if looping
	if _in_start_delay or _in_loop_delay or _in_sustain:
		return INF
	if loop_count != 1:
		return INF  # Looping effects: preroll not supported

	var remaining := maxf(0.0, _get_current_duration() - _elapsed)

	if _in_hold_at_peak:
		remaining = maxf(0.0, hold_at_peak - _hold_elapsed)
		if _will_auto_reverse and not _is_one_shot_return:
			remaining += duration_out
		return remaining

	# If will auto-reverse and hasn't started out phase yet, add hold + out
	if _will_auto_reverse and not _is_one_shot_return:
		remaining += hold_at_peak + duration_out

	return remaining

# =============================================================================
# CORE LOGIC
# =============================================================================

# Start the auto-reverse OUT phase (for IN_AND_OUT effects).
func _start_animate_out_internal(target: Node) -> void:
	_start_progress = _animation_progress
	_target_progress = 0.0
	_is_one_shot_return = true
	_elapsed = 0.0
	_on_animate_start(target)


# Handle cycle completion: ping-pong, auto-reverse, loops.
func _handle_cycle_complete(target: Node) -> TickResult:
	# --- Ping-pong phase advancement ---
	if ping_pong:
		var phases := _get_ping_pong_phases_per_cycle()
		var next_phase := (_ping_pong_phase + 1) % phases
		if next_phase != 0:
			var completed_dur := _get_current_duration()
			# Hold at peak after phase 0 if configured
			if _ping_pong_phase == 0 and hold_at_peak > 0.0:
				_in_hold_at_peak = true
				_hold_elapsed = 0.0
				return TickResult.PLAYING
			_ping_pong_phase = next_phase
			_configure_ping_pong_phase()
			_elapsed = _elapsed - completed_dur
			return TickResult.PLAYING

	# --- IN_AND_OUT auto-reverse (non-ping-pong) ---
	if _will_auto_reverse and _target_progress > 0.5 and not ping_pong:
		# IN phase done — snap to peak, then hold or auto-reverse
		_animation_progress = 1.0
		_apply_effect(1.0, target)
		_on_animate_in_complete(target)
		if hold_at_peak > 0.0:
			_in_hold_at_peak = true
			_hold_elapsed = 0.0
			return TickResult.PLAYING
		_start_animate_out_internal(target)
		return TickResult.PLAYING

	# --- Loop counting ---
	_current_loop += 1
	var should_continue := false
	if loop_count < 0:
		should_continue = true
	elif _current_loop < loop_count:
		should_continue = true

	if should_continue:
		_elapsed = _elapsed - _get_current_duration()
		if ping_pong:
			_ping_pong_phase = 0
			_configure_ping_pong_phase()
		if _will_auto_reverse and not ping_pong:
			_start_progress = 0.0
			_target_progress = 1.0
			_is_one_shot_return = false
			_on_animate_start(target)
		if loop_delay > 0.0:
			_in_loop_delay = true
			_loop_delay_elapsed = 0.0
		return TickResult.PLAYING

	# --- All loops done ---
	return _finish(target)


# Finalize the animation.
func _finish(target: Node) -> TickResult:
	# Snap to exact final progress
	if ping_pong and _pp_reversed:
		_animation_progress = _start_progress
	else:
		_animation_progress = _target_progress
	_apply_effect(_animation_progress, target)

	var just_animated_in := _animation_progress >= 0.5

	# Sustain after animate_in for procedural effects that need continuous
	# ticking (Noise, Shake, Spring). Non-procedural effects (Transform,
	# SquashStretch) complete normally — their frozen delta is the desired state.
	if just_animated_in and not _will_auto_reverse and _needs_sustain():
		_in_sustain = true
		_on_animate_in_complete(target)
		return TickResult.COMPLETED

	_is_playing = false

	if just_animated_in:
		_on_animate_in_complete(target)
	else:
		_on_animate_out_complete(target)

	return TickResult.COMPLETED

# =============================================================================
# DURATION & EASING
# =============================================================================

func _get_current_duration() -> float:
	var base_duration: float
	if ping_pong:
		base_duration = duration_out if _pp_use_out_curve else duration_in
	else:
		base_duration = duration_in if _target_progress > 0.5 else duration_out
	var remaining_distance: float = absf(_target_progress - _start_progress)
	return base_duration * remaining_distance


func _apply_easing(progress: float) -> float:
	var t := progress
	if _pp_reversed:
		t = 1.0 - t
	var use_in_curve: bool
	if ping_pong:
		use_in_curve = not _pp_use_out_curve
	else:
		use_in_curve = _target_progress > 0.5
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


## Apply easing for a specific direction (used by editor preview scrubbing).
func apply_easing_for_direction(normalized_time: float, use_in_curve: bool) -> float:
	var t := clampf(normalized_time, 0.0, 1.0)
	if use_in_curve:
		if custom_curve_in != null: return custom_curve_in.sample(t)
		if transition_in == Tween.TRANS_ELASTIC:
			return _ease_elastic(t, ease_in, elastic_amplitude_in, elastic_period_in)
		if transition_in == Tween.TRANS_BACK:
			return _ease_back(t, ease_in, back_overshoot_in)
		return Tween.interpolate_value(0.0, 1.0, t, 1.0, transition_in, ease_in)
	else:
		if custom_curve_out != null: return custom_curve_out.sample(t)
		if transition_out == Tween.TRANS_ELASTIC:
			return _ease_elastic(t, ease_out, elastic_amplitude_out, elastic_period_out)
		if transition_out == Tween.TRANS_BACK:
			return _ease_back(t, ease_out, back_overshoot_out)
		return Tween.interpolate_value(0.0, 1.0, t, 1.0, transition_out, ease_out)


func _ease_elastic(t: float, ease_type: Tween.EaseType, amplitude: float, period: float) -> float:
	if t == 0.0 or t == 1.0: return t
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
		_:
			if t < 0.5:
				return _ease_elastic(t * 2.0, Tween.EASE_OUT, amplitude, period) * 0.5
			else:
				return _ease_elastic(t * 2.0 - 1.0, Tween.EASE_IN, amplitude, period) * 0.5 + 0.5


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
		_:
			if t < 0.5:
				return _ease_back(t * 2.0, Tween.EASE_OUT, overshoot) * 0.5
			else:
				return _ease_back(t * 2.0 - 1.0, Tween.EASE_IN, overshoot) * 0.5 + 0.5

# =============================================================================
# PING-PONG HELPERS
# =============================================================================

func _get_ping_pong_phases_per_cycle() -> int:
	if trigger_behaviour == TriggerBehaviour.PLAY_IN_AND_OUT:
		return 4
	return 2


func _configure_ping_pong_phase() -> void:
	var phases := _get_ping_pong_phases_per_cycle()
	if phases == 4:
		match _ping_pong_phase:
			0: _start_progress = 0.0; _target_progress = 1.0; _pp_use_out_curve = false; _pp_reversed = false
			1: _start_progress = 1.0; _target_progress = 0.0; _pp_use_out_curve = true; _pp_reversed = false
			2: _start_progress = 1.0; _target_progress = 0.0; _pp_use_out_curve = true; _pp_reversed = true
			3: _start_progress = 0.0; _target_progress = 1.0; _pp_use_out_curve = false; _pp_reversed = true
	else:
		match _ping_pong_phase:
			0:
				_pp_reversed = false
				if _pp_use_out_curve:
					_start_progress = 1.0; _target_progress = 0.0
				else:
					_start_progress = 0.0; _target_progress = 1.0
			1:
				_pp_reversed = true
				if _pp_use_out_curve:
					_start_progress = 1.0; _target_progress = 0.0
				else:
					_start_progress = 0.0; _target_progress = 1.0


func _reset_ping_pong() -> void:
	_ping_pong_phase = 0
	_pp_use_out_curve = false
	_pp_reversed = false

# =============================================================================
# MIRROR UTILITY
# =============================================================================

func _mirror_in_to_out() -> void:
	duration_out = duration_in
	transition_out = transition_in
	ease_out = _reverse_ease_type(ease_in)
	custom_curve_out = _reverse_curve_time(custom_curve_in)
	elastic_amplitude_out = elastic_amplitude_in
	elastic_period_out = elastic_period_in
	back_overshoot_out = back_overshoot_in


func _reverse_ease_type(et: Tween.EaseType) -> Tween.EaseType:
	match et:
		Tween.EASE_IN: return Tween.EASE_OUT
		Tween.EASE_OUT: return Tween.EASE_IN
		Tween.EASE_IN_OUT: return Tween.EASE_OUT_IN
		Tween.EASE_OUT_IN: return Tween.EASE_IN_OUT
		_: return et


func _reverse_curve_time(curve: Curve) -> Curve:
	if curve == null: return null
	var reversed := Curve.new()
	for i in range(curve.get_point_count() - 1, -1, -1):
		var pos: Vector2 = curve.get_point_position(i)
		reversed.add_point(
			Vector2(1.0 - pos.x, pos.y),
			curve.get_point_right_tangent(i) * -1.0,
			curve.get_point_left_tangent(i) * -1.0,
			curve.get_point_right_mode(i),
			curve.get_point_left_mode(i))
	return reversed

# =============================================================================
# EDITOR PREVIEW HELPERS
# =============================================================================

## Calculates the visual progress (0.0 to 1.0) at an exact point in time.
## Enables the Editor Transport to scrub the animation timeline deterministically without running physics ticks or scene lifecycle methods.
func get_progress_at_time(time: float) -> float:
	var has_out := trigger_behaviour == TriggerBehaviour.PLAY_IN_AND_OUT
	if time < start_delay: return 0.0
	var t := time - start_delay
	if t < duration_in:
		var normalized := t / duration_in if duration_in > 0.0 else 1.0
		return apply_easing_for_direction(normalized, true)
	if has_out:
		var after_in := t - duration_in
		if after_in < hold_at_peak: return 1.0
		var out_t := after_in - hold_at_peak
		if out_t < duration_out:
			var normalized := out_t / duration_out if duration_out > 0.0 else 1.0
			return 1.0 - apply_easing_for_direction(normalized, false)
		return 0.0
	return 1.0


## Calculates the full timeline length of the effect including delays and holds.
## Allows the editor preview sequencer to know the total duration of the animation for UI scaling.
func get_total_preview_duration() -> float:
	var total := start_delay + duration_in
	if trigger_behaviour == TriggerBehaviour.PLAY_IN_AND_OUT:
		total += hold_at_peak + duration_out
	return total

# Returns the maximum sensible chained_preroll value — the total duration
# from start to completion for this effect's trigger_behaviour.
# Prevents users from setting a preroll that triggers chained effects before this effect even starts.
func _get_max_chained_preroll() -> float:
	match trigger_behaviour:
		TriggerBehaviour.PLAY_IN_AND_OUT:
			return duration_in + hold_at_peak + duration_out
		TriggerBehaviour.PLAY_OUT_ONLY:
			return duration_out
		_:  # PLAY_IN_ONLY, TOGGLE, SET_FROM_SOURCE
			return duration_in + hold_at_peak

# =============================================================================
# HELPERS FOR SUBCLASSES
# =============================================================================

func _get_target_size(target: Node) -> Vector2:
	if target is Control: return (target as Control).size
	return Vector2.ZERO


func _get_parent_size(target: Node) -> Vector2:
	var parent = target.get_parent() if target else null
	if parent is Control: return (parent as Control).size
	return Vector2.ZERO


func _get_viewport_size(target: Node) -> Vector2:
	if target: return target.get_viewport().get_visible_rect().size
	return Vector2.ZERO

# =============================================================================
# VIRTUAL METHODS (Subclasses Override)
# =============================================================================

## Whether this effect needs continuous ticking after animate_in completes.
## Procedural effects (Noise, Shake) override to return true.
## Non-procedural effects (Transform, SquashStretch) return false — their
## frozen delta at progress=1.0 is the desired state, no further ticking needed.
func _needs_sustain() -> bool:
	return false

## Apply the effect at the given progress. THIS IS THE CORE METHOD.
## progress: 0.0 = natural state, 1.0 = fully applied
## target: the node being affected (passed by host, never stored)
func _apply_effect(_progress: float, _target: Node) -> void:
	pass  # Subclass MUST implement

## Called when animation starts (either direction). Capture base values here.
func _on_animate_start(_target: Node) -> void:
	pass

## Called when animate_in reaches peak (progress=1.0).
func _on_animate_in_complete(_target: Node) -> void:
	pass

## Called when animate_out completes (progress=0.0).
func _on_animate_out_complete(_target: Node) -> void:
	pass

## Restore target to natural (unmodified) state. Called by stop().
func _restore_to_natural(_target: Node) -> void:
	_apply_effect(0.0, _target)

## Reset cached base values. Called when target changes.
func _invalidate_base_cache() -> void:
	pass

## Return the property deltas this effect wrote to the target node this tick.
## Used by the Sequencer to aggregate contributions via the JuiceLedger.
## Meta-effects (Camera, Screen) return {} — they write to external utilities,
## not to the host target node. Domain effects override to return their deltas.
func _get_seq_contribution() -> Dictionary:
	return {}

## Identity key for sibling interruption matching.
func _get_interrupt_identity() -> Variant:
	return get_script()

## Temporarily undo visual effect (for editor save pipeline).
func _temporarily_undo_visual(_target: Node) -> void:
	pass

## Re-apply visual effect after temporary undo.
func _temporarily_reapply_visual(_target: Node) -> void:
	pass

## Called by host node during _ready(). Effects that need READY-time capture use this.
func _on_host_ready(_target: Node, _host: Node) -> void:
	pass

## Called by host node on NOTIFICATION_EDITOR_PRE_SAVE. Effects with editor cache use this.
func _on_editor_pre_save(_target: Node) -> void:
	pass

## Whether this effect type supports editor preview.
func _supports_editor_preview() -> bool:
	return true
