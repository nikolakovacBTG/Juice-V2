@tool
## @icon — custom icon will be added in addons/juice/icons/ later
class_name TimeJuiceComp
extends JuiceCompBase
## ============================================================================
## TIME JUICE COMPONENT
## ============================================================================
## Manipulates Engine.time_scale for gameplay time effects.
## Provides three modes: FREEZE (hitstop), SLOW_MO, and BULLET_TIME.
##
## SYSTEM: Juice System (addons/juice/Events and Time/)
##
## TIME MANAGEMENT (3-layer hybrid):
##   Layer 1 (default): Built-in static request system. Multiple TimeJuiceComps
##     coordinate automatically — slowest slow-mo wins, no setup required.
##   Layer 2 (signal): Set use_external_coordinator = true. The component emits
##     time_scale_requested() instead of touching Engine.time_scale. Connect
##     to your own time system.
##   Layer 3 (coordinator): Add a JuiceTimeCoordinator node to your scene tree
##     (or as an autoload). TimeJuiceComp discovers it automatically and routes
##     all requests through it. Gives you audio pitch sync, priority resolution,
##     and a central time_scale_changed signal.
##
## MODES:
## - FREEZE: Instant stop (scale=0) for duration, then release (hitstop)
## - SLOW_MO: Smooth transition to target_scale, smooth return on one_shot
## - BULLET_TIME: Like SLOW_MO but exempts specified nodes from slowdown
##
## DOES NOT HANDLE:
## - World time (day/night) — game-specific
## - Per-object time scaling — Godot limitation
## - Audio pitch — use JuiceTimeCoordinator for that
## ============================================================================

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when FREEZE starts. freeze_frames = how many frames the freeze lasts.
## Useful for driving hitstop SFX or visual effects.
signal freeze_started(freeze_frames: int)

## Emitted when FREEZE ends (timer expired).
signal freeze_ended()

## Emitted when SLOW_MO begins transitioning to target_scale.
## target_scale = the time scale being transitioned to (e.g. 0.1 for 10% speed).
signal slow_mo_started(target_scale: float)

## Emitted when SLOW_MO animate_out completes and time is fully restored.
signal slow_mo_ended()

## Emitted when BULLET_TIME starts. Compensation factor = 1.0 / target_scale.
## Player can multiply movement by this to maintain normal speed during slow-mo.
signal bullet_time_started(compensation_factor: float)

## Emitted when BULLET_TIME ends (either complete or interrupted).
signal bullet_time_ended()

## Layer 2 escape hatch: emitted instead of touching Engine.time_scale when
## use_external_coordinator is true. Connect this to your own time system.
## scale = desired time scale (0.0 = freeze, <1.0 = slow, 1.0 = normal)
signal time_scale_requested(scale: float)

# =============================================================================
# MODE CONFIGURATION
# =============================================================================

## Time manipulation modes
enum TimeMode {
	FREEZE,      ## Instant scale = 0, hold for duration (hitstop)
	SLOW_MO,     ## Smooth transition to target_scale
	BULLET_TIME  ## Slow world, exempt specified nodes
}

@export_group("Time Effect")

## Which time manipulation mode to use
@export var time_mode: TimeMode = TimeMode.SLOW_MO:
	set(value):
		time_mode = value
		notify_property_list_changed()

## Layer 2: If true, this component emits time_scale_requested() instead of
## setting Engine.time_scale directly. Connect the signal to your own time
## management system. Overrides both built-in static system and coordinator.
@export var use_external_coordinator: bool = false

## Target time scale (0.0 = freeze, <1.0 = slow, >1.0 = fast)
## Only shown for SLOW_MO and BULLET_TIME modes (FREEZE always uses 0.0)
var target_scale: float = 0.3

## If true, transition smoothly to target. If false, instant change.
## Only shown for SLOW_MO and BULLET_TIME modes (FREEZE is always instant)
var smooth_transition: bool = true

## Number of frames to freeze (at 60fps). Only shown in FREEZE mode.
## Overrides base duration: freeze_time = freeze_frames / 60.0
var freeze_frames: int = 3

## Nodes that should continue running at normal speed during BULLET_TIME
## Typically includes player, UI elements that need to stay responsive
var exempt_nodes: Array[NodePath] = []

## If true, emits bullet_time_started/ended signals for player compensation
var emit_compensation_signal: bool = true


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	
	# SLOW_MO and BULLET_TIME share target_scale and smooth_transition
	if time_mode != TimeMode.FREEZE:
		props.append({
			"name": "target_scale",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,2.0,0.01",
		})
		props.append({
			"name": "smooth_transition",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	
	# FREEZE-only properties
	if time_mode == TimeMode.FREEZE:
		props.append({
			"name": "freeze_frames",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	
	# BULLET_TIME-only properties
	if time_mode == TimeMode.BULLET_TIME:
		props.append({
			"name": "exempt_nodes",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_TYPE_STRING,
			"hint_string": "%d:" % TYPE_NODE_PATH,
		})
		props.append({
			"name": "emit_compensation_signal",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	
	return props


func _set(prop: StringName, value: Variant) -> bool:
	match prop:
		&"target_scale":
			target_scale = value
			return true
		&"smooth_transition":
			smooth_transition = value
			return true
		&"freeze_frames":
			freeze_frames = value
			return true
		&"exempt_nodes":
			exempt_nodes = value
			return true
		&"emit_compensation_signal":
			emit_compensation_signal = value
			return true
	return false


func _get(prop: StringName) -> Variant:
	match prop:
		&"target_scale":
			return target_scale
		&"smooth_transition":
			return smooth_transition
		&"freeze_frames":
			return freeze_frames
		&"exempt_nodes":
			return exempt_nodes
		&"emit_compensation_signal":
			return emit_compensation_signal
	return null

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Cached reference to JuiceTimeCoordinator (Layer 3), if one exists in the tree
var _coordinator: JuiceTimeCoordinator = null

## Whether we currently have an active time scale request
var _has_active_request: bool = false

## Cached original process modes for exempt nodes (to restore later)
var _exempt_original_modes: Dictionary = {}  # Node instance_id -> ProcessMode

## Timer for FREEZE mode (real-time, not affected by time_scale)
var _freeze_timer: SceneTreeTimer = null

# --- Layer 1: Built-in static request system (fallback when no coordinator) ---

## Active time scale requests from all TimeJuiceComp instances: instance_id → scale
static var _static_requests: Dictionary = {}

## Computes effective time scale from all static requests.
## Uses same resolution as JuiceTimeCoordinator: slowest slow-mo wins.
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
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Must run even when time is stopped
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Call parent _ready after setting process_mode
	super._ready()
	
	# Discover coordinator (Layer 3) if one exists
	_coordinator = JuiceTimeCoordinator.instance
	
	if debug_enabled:
		if use_external_coordinator:
			print("[%s] Using Layer 2: signal mode (use_external_coordinator)" % name)
		elif _coordinator:
			print("[%s] Using Layer 3: JuiceTimeCoordinator found" % name)
		else:
			print("[%s] Using Layer 1: built-in static request system" % name)

# =============================================================================
# JUICE COMP OVERRIDES
# =============================================================================

func _process(delta: float) -> void:
	# TimeJuiceComp must animate in real (wall-clock) time, not engine-scaled time.
	# Without this, animate_out from slow-mo feels sluggish because delta is reduced
	# by the very time scale we're trying to restore.
	# FREEZE mode uses a process_always timer instead of progress, so it's unaffected.
	if Engine.time_scale > 0.001:
		var real_delta := delta / Engine.time_scale
		super._process(real_delta)
	else:
		# Time is frozen (scale ~0) — delta is also ~0.
		# FREEZE mode handles completion via its own real-time timer, so this is fine.
		super._process(delta)


func _on_animate_start() -> void:
	## Called when animation begins. Sets up time manipulation.
	
	# Skip during auto-reverse (one_shot return) - we're already set up
	if _is_one_shot_return:
		if debug_enabled:
			print("[%s] Auto-reverse starting - keeping current time request" % name)
		return
	
	match time_mode:
		TimeMode.FREEZE:
			_start_freeze()
		TimeMode.SLOW_MO:
			_start_slow_mo()
		TimeMode.BULLET_TIME:
			_start_bullet_time()


func _apply_effect(progress: float) -> void:
	## Called each frame during animation. Updates time scale based on progress.
	
	# FREEZE mode doesn't use progress - it's instant on/off
	if time_mode == TimeMode.FREEZE:
		return
	
	# SLOW_MO and BULLET_TIME: interpolate time scale based on progress
	# progress 0.0 = normal time (1.0), progress 1.0 = target_scale
	var current_scale: float
	if smooth_transition:
		current_scale = lerpf(1.0, target_scale, progress)
	else:
		# Instant: jump to target when progress > 0
		current_scale = target_scale if progress > 0.0 else 1.0
	
	_update_time_request(current_scale)


func _on_animate_in_complete() -> void:
	## Called when animate_in reaches progress 1.0.
	## For FREEZE, this is when the freeze timer expires.
	
	if debug_enabled:
		print("[%s] Animate IN complete at scale %.2f" % [name, target_scale])


func _on_animate_out_complete() -> void:
	## Called when animate_out reaches progress 0.0.
	## Releases time scale request and restores exempt nodes.
	
	_release_time_request()
	
	match time_mode:
		TimeMode.SLOW_MO:
			slow_mo_ended.emit()
			if debug_enabled:
				print("[%s] Emitted slow_mo_ended" % name)
		TimeMode.BULLET_TIME:
			_restore_exempt_nodes()
			if emit_compensation_signal:
				bullet_time_ended.emit()
	
	if debug_enabled:
		print("[%s] Animate OUT complete - time restored" % name)


func _invalidate_base_cache() -> void:
	## Called when target node changes. Not much to do for time effects.
	pass

# =============================================================================
# MODE IMPLEMENTATIONS
# =============================================================================

func _start_freeze() -> void:
	## FREEZE mode: Instant time stop for specified frames.
	
	# Calculate freeze duration in seconds
	var freeze_time: float = freeze_frames / 60.0
	
	# Override base duration for the freeze
	# (This is a special case - FREEZE doesn't use normal progress animation)
	
	if debug_enabled:
		print("[%s] FREEZE: %d frames (%.3fs)" % [name, freeze_frames, freeze_time])
	
	# Request complete time stop
	_update_time_request(0.0)
	
	freeze_started.emit(freeze_frames)
	if debug_enabled:
		print("[%s] Emitted freeze_started(%d)" % [name, freeze_frames])
	
	# Create real-time timer (process_always) that will end the freeze
	# We need to manually handle completion since _process won't run at time_scale=0
	_freeze_timer = get_tree().create_timer(freeze_time, true, false, true)
	_freeze_timer.timeout.connect(_on_freeze_complete)


func _on_freeze_complete() -> void:
	## Called when FREEZE timer expires.
	
	_freeze_timer = null
	
	# Release time scale request
	_release_time_request()
	
	# Stop the juice component (we're done)
	_finish_animation()
	
	freeze_ended.emit()
	if debug_enabled:
		print("[%s] FREEZE complete — emitted freeze_ended" % name)


func _start_slow_mo() -> void:
	## SLOW_MO mode: Smooth transition to target time scale.
	
	if debug_enabled:
		print("[%s] SLOW_MO: transitioning to %.2f" % [name, target_scale])
	
	# Initial request at current interpolated value
	# _apply_effect will update this each frame
	_update_time_request(1.0)
	
	slow_mo_started.emit(target_scale)
	if debug_enabled:
		print("[%s] Emitted slow_mo_started(%.2f)" % [name, target_scale])


func _start_bullet_time() -> void:
	## BULLET_TIME mode: Slow world but keep exempt nodes at normal speed.
	
	if debug_enabled:
		print("[%s] BULLET_TIME: %.2f with %d exempt nodes" % [
			name, target_scale, exempt_nodes.size()
		])
	
	# Set exempt nodes to PROCESS_MODE_ALWAYS
	_setup_exempt_nodes()
	
	# Start time scale (will be updated by _apply_effect)
	_update_time_request(1.0)
	
	# Emit signal for player compensation
	if emit_compensation_signal and target_scale > 0.0:
		var compensation := 1.0 / target_scale
		bullet_time_started.emit(compensation)
		
		if debug_enabled:
			print("[%s] Emitted bullet_time_started(%.2f)" % [name, compensation])

# =============================================================================
# TIME REQUEST MANAGEMENT
# =============================================================================

func _update_time_request(scale: float) -> void:
	## Routes the time scale request through the appropriate layer.
	## Layer 2 (signal) > Layer 3 (coordinator) > Layer 1 (static fallback)
	
	if use_external_coordinator:
		# Layer 2: emit signal, don't touch Engine.time_scale
		time_scale_requested.emit(scale)
		_has_active_request = true
		return
	
	if _coordinator:
		# Layer 3: route through JuiceTimeCoordinator
		_coordinator.request_time_scale(self, scale)
	else:
		# Layer 1: built-in static request system
		_static_requests[get_instance_id()] = scale
		Engine.time_scale = _compute_static_scale()
	
	_has_active_request = true


func _release_time_request() -> void:
	## Releases our time scale request from whichever layer is active.
	
	if not _has_active_request:
		return
	
	if use_external_coordinator:
		# Layer 2: signal normal time
		time_scale_requested.emit(1.0)
	elif _coordinator:
		# Layer 3: release from coordinator
		_coordinator.release_time_scale(self)
	else:
		# Layer 1: remove from static requests
		_static_requests.erase(get_instance_id())
		Engine.time_scale = _compute_static_scale()
	
	_has_active_request = false

# =============================================================================
# EXEMPT NODE MANAGEMENT (BULLET_TIME)
# =============================================================================

func _setup_exempt_nodes() -> void:
	## Sets exempt nodes to PROCESS_MODE_ALWAYS so they run at normal speed.
	## Caches original process modes for restoration.
	
	_exempt_original_modes.clear()
	
	for node_path in exempt_nodes:
		var node := get_node_or_null(node_path)
		if node == null:
			if debug_enabled:
				push_warning("[%s] Exempt node not found: %s" % [name, node_path])
			continue
		
		# Cache original mode
		_exempt_original_modes[node.get_instance_id()] = node.process_mode
		
		# Set to always process
		node.process_mode = Node.PROCESS_MODE_ALWAYS
		
		if debug_enabled:
			print("[%s] Exempt node '%s' set to PROCESS_MODE_ALWAYS" % [name, node.name])


func _restore_exempt_nodes() -> void:
	## Restores exempt nodes to their original process modes.
	
	for node_path in exempt_nodes:
		var node := get_node_or_null(node_path)
		if node == null:
			continue
		
		var node_id := node.get_instance_id()
		if _exempt_original_modes.has(node_id):
			node.process_mode = _exempt_original_modes[node_id]
			
			if debug_enabled:
				print("[%s] Restored '%s' process_mode" % [name, node.name])
	
	_exempt_original_modes.clear()

# =============================================================================
# CLEANUP
# =============================================================================

func _finish_animation() -> void:
	## Properly ends the animation and emits completed signal.
	
	_is_playing = false
	set_process(false)
	
	# Ensure time request is released
	_release_time_request()
	
	# Restore exempt nodes if bullet time
	if time_mode == TimeMode.BULLET_TIME:
		_restore_exempt_nodes()
		if emit_compensation_signal:
			bullet_time_ended.emit()
	
	completed.emit()


func _exit_tree() -> void:
	## Cleanup when node is removed - ensure time is restored.
	
	# Cancel freeze timer if active
	if _freeze_timer != null:
		_freeze_timer = null
	
	# Release any active time request (handles all 3 layers)
	_release_time_request()
	
	# Safety: ensure our instance_id is cleaned from static requests
	_static_requests.erase(get_instance_id())
	
	# Restore exempt nodes
	_restore_exempt_nodes()
	
	if debug_enabled:
		print("[%s] Exiting - time restored" % name)
