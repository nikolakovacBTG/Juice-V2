## Base class for time manipulation effects.
##
## Provides FREEZE (hitstop), SLOW_MO, and BULLET_TIME modes. Domain-agnostic
## — does not animate the target node, only Engine.time_scale.

# ============================================================================
# WHAT: Base class for time manipulation effects in the JuiceStack system.
# WHY:  Provides time manipulation capabilities (slomo, stop, hitstop) encapsulated as
#       a JuiceBase recipe — enabling standard triggering and chainability.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# DOES NOT: Animate target node properties — this is a meta effect.
# DOES NOT: Manage audio pitch — use TimeCoordinatorJuiceUtility for that.
# DOES NOT: Support per-object time scaling — Godot limitation.
#
# TIME MANAGEMENT (3-layer hybrid):
#   Layer 1 (default): Built-in static request dict. Multiple TimeJuiceEffects
#     coordinate automatically — slowest slow-mo wins, no setup required.
#   Layer 2 (signal): Set use_external_coordinator=true. Emits time_scale_requested
#     instead of touching Engine.time_scale. Connect to your own time system.
#   Layer 3 (coordinator): TimeCoordinatorJuiceUtility auto-discovered via singleton.
#     Routes all requests for priority resolution, audio pitch sync, etc.
#
# FREEZE MODE NOTES:
#   FREEZE uses a real-time SceneTreeTimer, not the animation progress loop.
#   duration_in / trigger_behaviour are ignored — freeze_frames determines timing.
#   tick() detects timer completion via flag; host node must use PROCESS_MODE_ALWAYS.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceUtilityTimeCoord.svg")
class_name TimeJuiceEffectBase
extends JuiceEffectBase


# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when FREEZE starts. freeze_frames = configured frame count.
signal freeze_started(freeze_frames: int)

## Emitted when FREEZE timer expires and time is released.
signal freeze_ended()

## Emitted when SLOW_MO begins transitioning. target_scale = configured scale.
signal slow_mo_started(target_scale: float)

## Emitted when SLOW_MO animate_out completes and time is fully restored.
signal slow_mo_ended()

## Emitted when BULLET_TIME starts. compensation_factor = 1.0 / target_scale.
## Game code can multiply player velocity by this to maintain apparent normal speed.
signal bullet_time_started(compensation_factor: float)

## Emitted when BULLET_TIME ends (animate_out complete or stop()).
signal bullet_time_ended()

## Layer 2 escape hatch — emitted instead of touching Engine.time_scale when
## use_external_coordinator is true. Connect to your own time system.
## scale = desired time scale (0.0=freeze, <1.0=slow, 1.0=normal).
signal time_scale_requested(scale: float)


# =============================================================================
# ENUMS
# =============================================================================

## Time manipulation modes. Defines the scale strategy applied to the engine.
enum TimeMode {
	FREEZE,      ## Instant scale=0 for N frames (hitstop / impact freeze).
	SLOW_MO,     ## Smooth or instant transition to target_scale.
	BULLET_TIME, ## Like SLOW_MO but specified nodes run at full speed.
}


# =============================================================================
# CONFIGURATION
# =============================================================================

## Which time manipulation mode to use.
var time_mode: int = TimeMode.SLOW_MO:
	set(value):
		time_mode = value
		notify_property_list_changed()

## Target time scale. 0.0=fully frozen, 0.3=30% speed, 1.0=normal.
## Used by SLOW_MO and BULLET_TIME only.
var target_scale: float = 0.3

## Smoothly interpolate to target_scale over duration_in (true)
## or jump instantly (false). Used by SLOW_MO and BULLET_TIME only.
var smooth_transition: bool = true

## Number of frames to hold the freeze (at 60fps). Used by FREEZE only.
## E.g. freeze_frames=3 → 50ms hitstop at 60fps.
var freeze_frames: int = 3

## Nodes that should continue running at normal speed during BULLET_TIME.
## Each node is set to PROCESS_MODE_ALWAYS for the duration.
var exempt_nodes: Array[NodePath] = []

## If true, emit bullet_time_started(compensation_factor) signal.
## compensation_factor = 1.0 / target_scale. Game code can use this to
## preserve apparent normal speed for player-controlled objects.
var emit_compensation_signal: bool = true

## Layer 2: emit time_scale_requested signal instead of setting Engine.time_scale.
## Overrides Layer 1 (static dict) and Layer 3 (TimeCoordinatorJuiceUtility).
## Connect time_scale_requested to your own time management system.
var use_external_coordinator: bool = false


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _init() -> void:
	_subclass_owns_effect_group = true


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	props.append({"name": "Time Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "time_mode", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Freeze,Slow Mo,Bullet Time",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "use_external_coordinator", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})

	if time_mode != TimeMode.FREEZE:
		props.append({"name": "target_scale", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,2.0,0.01",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "smooth_transition", "type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT})

	if time_mode == TimeMode.FREEZE:
		props.append({"name": "freeze_frames", "type": TYPE_INT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "1,600,1,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT})

	if time_mode == TimeMode.BULLET_TIME:
		props.append({"name": "exempt_nodes", "type": TYPE_ARRAY,
			"hint": PROPERTY_HINT_TYPE_STRING, "hint_string": "%d:" % TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "emit_compensation_signal", "type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT})

	props.append_array(_get_effect_base_properties())

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"time_mode": time_mode = value; return true
		&"target_scale": target_scale = value; return true
		&"smooth_transition": smooth_transition = value; return true
		&"freeze_frames": freeze_frames = value; return true
		&"exempt_nodes": exempt_nodes = value; return true
		&"emit_compensation_signal": emit_compensation_signal = value; return true
		&"use_external_coordinator": use_external_coordinator = value; return true
	return super._set(property, value)


func _get(property: StringName) -> Variant:
	match property:
		&"time_mode": return time_mode
		&"target_scale": return target_scale
		&"smooth_transition": return smooth_transition
		&"freeze_frames": return freeze_frames
		&"exempt_nodes": return exempt_nodes
		&"emit_compensation_signal": return emit_compensation_signal
		&"use_external_coordinator": return use_external_coordinator
	return super._get(property)


# =============================================================================
# INTERNAL STATE
# =============================================================================

## Layer 1 fallback: active time scale requests keyed by resource instance_id.
static var _static_requests: Dictionary = {}

## Cached Layer 3 coordinator reference (refreshed each animate_start).
var _coordinator: TimeCoordinatorJuiceUtility = null

## True while we hold an active time scale request (any layer).
var _has_active_request: bool = false

## Cached original process modes for exempt nodes (instance_id → ProcessMode).
var _exempt_original_modes: Dictionary = {}

## Real-time timer for FREEZE mode. Null when not active.
var _freeze_timer: SceneTreeTimer = null

## Set by _on_freeze_complete(); tick() picks it up to return COMPLETED.
var _freeze_complete: bool = false


# =============================================================================
# TICK OVERRIDE
# =============================================================================

## FREEZE: timer-based completion, not progress-based. Returns PLAYING until
## the timer fires, then cleans up and returns COMPLETED.
## SLOW_MO / BULLET_TIME: corrects engine-scaled delta to real (wall-clock) time
## so animate_out restores time at the configured real-time duration.
func tick(delta: float, target: Node) -> TickResult:
	if time_mode == TimeMode.FREEZE:
		if _freeze_complete:
			_freeze_complete = false
			_is_playing = false
			_release_time_request()
			_on_animate_in_complete(target)
			freeze_ended.emit()
			return TickResult.COMPLETED
		return TickResult.PLAYING

	# Real-time correction: delta is time-scaled, but time animations should run
	# at wall-clock speed (otherwise animate_out of slow-mo takes 3x longer).
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	return super.tick(real_delta, target)


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

## Initializes exempt nodes and begins the specific time manipulation phase (freeze, slow-mo, or bullet time).
func _on_animate_start(target: Node) -> void:
	# Refresh coordinator reference (may have been added to scene since last play).
	_coordinator = TimeCoordinatorJuiceUtility.instance

	# Restore direction: auto-reverse (one_shot) or explicit start(false).
	# _apply_effect() already lerps back to 1.0 as progress falls to 0 — no restart needed.
	if _is_one_shot_return or _target_progress == 0.0:
		return

	match time_mode:
		TimeMode.FREEZE:    _start_freeze()
		TimeMode.SLOW_MO:   _start_slow_mo()
		TimeMode.BULLET_TIME: _start_bullet_time()


## Adjusts the time scale based on the easing progress envelope during bullet-time and slow-mo.
func _apply_effect(progress: float, _target: Node) -> void:
	if time_mode == TimeMode.FREEZE:
		return  # FREEZE is timer-based; progress is not used.

	var current_scale: float
	if smooth_transition:
		current_scale = lerpf(1.0, target_scale, progress)
	else:
		current_scale = target_scale if progress > 0.0 else 1.0

	_update_time_request(current_scale)


## Cleans up engine state immediately when the effect naturally finishes easing out.
func _on_animate_out_complete(_target: Node) -> void:
	_release_time_request()
	match time_mode:
		TimeMode.SLOW_MO:
			slow_mo_ended.emit()
		TimeMode.BULLET_TIME:
			_restore_exempt_nodes()
			if emit_compensation_signal:
				bullet_time_ended.emit()


## Forces an immediate cleanup of time scale and exempt nodes if the effect is abruptly stopped or interrupted.
func _restore_to_natural(_target: Node) -> void:
	# Called by stop(). _is_playing is already false when this runs, so
	# _on_freeze_complete() will self-cancel via the _is_playing guard.
	_freeze_timer = null
	_freeze_complete = false
	_release_time_request()
	_restore_exempt_nodes()


# =============================================================================
# MODE IMPLEMENTATIONS
# =============================================================================

# Initiates a zero time scale state for a fixed duration (hitstop) before transitioning to ease-out or normal time.
func _start_freeze() -> void:
	var freeze_time := freeze_frames / 60.0
	_update_time_request(0.0)
	freeze_started.emit(freeze_frames)
	# Real-time timer (process_always=true) so it fires even at time_scale=0.
	_freeze_timer = _host_node.get_tree().create_timer(freeze_time, true, false, true)
	_freeze_timer.timeout.connect(_on_freeze_complete)

	JuiceLogger.log_info(self, _get_domain_tag(),
			"FREEZE: %d frames (%.3fs)" % [freeze_frames, freeze_time],
			debug_enabled)


# Triggered by the unscaled internal timer when hitstop ends, advancing the animation lifecycle.
func _on_freeze_complete() -> void:
	_freeze_timer = null
	if not _is_playing:
		return  # Effect was stopped before timer fired — ignore.
	_freeze_complete = true  # tick() will detect this on the next frame.


# Jumps directly to the target slowed time scale without easing.
func _start_slow_mo() -> void:
	_update_time_request(1.0)  # tick() will interpolate from here.
	slow_mo_started.emit(target_scale)

	JuiceLogger.log_info(self, _get_domain_tag(),
			"SLOW_MO: target_scale=%.2f smooth=%s" % [target_scale, smooth_transition],
			debug_enabled)


# Begins the smooth easing transition into the target time scale.
func _start_bullet_time() -> void:
	_setup_exempt_nodes()
	_update_time_request(1.0)  # tick() will interpolate from here.
	if emit_compensation_signal and target_scale > 0.0:
		bullet_time_started.emit(1.0 / target_scale)

	JuiceLogger.log_info(self, _get_domain_tag(),
			"BULLET_TIME: target_scale=%.2f, %d exempt nodes" % [
			target_scale, exempt_nodes.size()],
			debug_enabled)


# =============================================================================
# TIME REQUEST MANAGEMENT
# =============================================================================

# Registers this specific effect's time scale request in the global ledger and updates the engine.
func _update_time_request(scale: float) -> void:
	if use_external_coordinator:
		time_scale_requested.emit(scale)
		_has_active_request = true
		return
	if _coordinator != null:
		_coordinator.request_time_scale(self, scale)
	else:
		_static_requests[get_instance_id()] = scale
		Engine.time_scale = _compute_static_scale()
	_has_active_request = true


# Removes this effect's influence from the global time ledger, allowing other effects or base time to take over.
func _release_time_request() -> void:
	if not _has_active_request:
		return
	if use_external_coordinator:
		time_scale_requested.emit(1.0)
	elif _coordinator != null:
		_coordinator.release_time_scale(self)
	else:
		_static_requests.erase(get_instance_id())
		Engine.time_scale = _compute_static_scale()
	_has_active_request = false


# Computes effective Engine.time_scale from all active static requests.
# Slowest slow-mo wins (same resolution as TimeCoordinatorJuiceUtility).
static func _compute_static_scale() -> float:
	if _static_requests.is_empty():
		return 1.0
	var slow_scales: Array[float] = []
	var fast_scales: Array[float] = []
	for scale: float in _static_requests.values():
		if scale <= 1.0:
			slow_scales.append(scale)
		else:
			fast_scales.append(scale)
	if not slow_scales.is_empty():
		return slow_scales.min()
	if not fast_scales.is_empty():
		return fast_scales.max()
	return 1.0


# =============================================================================
# EXEMPT NODE MANAGEMENT (BULLET_TIME)
# =============================================================================

# Temporarily sets specific nodes to process in ALWAYS mode so they ignore the engine time scale (e.g. the player during hitstop).
func _setup_exempt_nodes() -> void:
	_exempt_original_modes.clear()
	for node_path in exempt_nodes:
		var node := _host_node.get_node_or_null(node_path)
		if node == null:
			JuiceLogger.warn(self, _get_domain_tag(),
					"exempt node not found: %s" % node_path,
					debug_enabled)
			continue
		_exempt_original_modes[node.get_instance_id()] = node.process_mode
		node.process_mode = Node.PROCESS_MODE_ALWAYS
		JuiceLogger.log_info(self, _get_domain_tag(),
				"exempt '%s' → PROCESS_MODE_ALWAYS" % node.name,
				debug_enabled)


# Reverts exempt nodes back to their original process modes once the effect finishes.
func _restore_exempt_nodes() -> void:
	for node_path in exempt_nodes:
		var node := _host_node.get_node_or_null(node_path) if _host_node != null else null
		if node == null:
			continue
		var nid := node.get_instance_id()
		if _exempt_original_modes.has(nid):
			node.process_mode = _exempt_original_modes[nid]
			JuiceLogger.log_info(self, _get_domain_tag(),
					"restored '%s' process_mode" % node.name,
					debug_enabled)
	_exempt_original_modes.clear()
