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
## RESPONSIBILITIES:
## - Request time scale changes via EngineTimeCoordinator
## - Handle smooth transitions between time scales
## - Manage exempt nodes for BULLET_TIME mode
## - Emit signals for player speed compensation
##
## DOES NOT HANDLE:
## - World time (day/night) - that's WorldTimeManager
## - Per-object time scaling - Godot doesn't support this natively
## - Audio pitch - delegated to EngineTimeCoordinator
##
## CONNECTIONS:
## - EngineTimeCoordinator: Registers/releases time scale requests
## - Access: GameController.time_coordinator
## - Signals: bullet_time_started, bullet_time_ended for player compensation
##
## MODES:
## - FREEZE: Instant stop (scale=0) for duration, then release (hitstop)
## - SLOW_MO: Smooth transition to target_scale, smooth return on one_shot
## - BULLET_TIME: Like SLOW_MO but exempts specified nodes from slowdown
## ============================================================================

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when BULLET_TIME starts. Compensation factor = 1.0 / target_scale
## Player can multiply movement by this to maintain normal speed during slow-mo
signal bullet_time_started(compensation_factor: float)

## Emitted when BULLET_TIME ends (either complete or interrupted)
signal bullet_time_ended()

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

## Cached reference to EngineTimeCoordinator
var _time_coordinator: EngineTimeCoordinator = null

## Whether we currently have an active time scale request
var _has_active_request: bool = false

## Cached original process modes for exempt nodes (to restore later)
var _exempt_original_modes: Dictionary = {}  # Node instance_id -> ProcessMode

## Timer for FREEZE mode (real-time, not affected by time_scale)
var _freeze_timer: SceneTreeTimer = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Must run even when time is stopped
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Call parent _ready after setting process_mode
	super._ready()
	
	# Cache coordinator reference
	_cache_coordinator()


func _cache_coordinator() -> void:
	## Attempts to find EngineTimeCoordinator via GameController.
	## If not found, component will still work but with warnings.
	
	# Try to get GameController autoload — uses typed access for safety
	var game_controller := get_node_or_null("/root/GameController")
	if game_controller == null:
		if debug_enabled:
			push_warning("[%s] GameController not found - time effects disabled" % name)
		return
	
	# Get time_coordinator from GameController via typed property access
	_time_coordinator = game_controller.get("time_coordinator")
	
	if _time_coordinator == null:
		if debug_enabled:
			push_warning("[%s] EngineTimeCoordinator not found on GameController" % name)

# =============================================================================
# JUICE COMP OVERRIDES
# =============================================================================

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
	
	if time_mode == TimeMode.BULLET_TIME:
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
	
	if debug_enabled:
		print("[%s] FREEZE complete" % name)


func _start_slow_mo() -> void:
	## SLOW_MO mode: Smooth transition to target time scale.
	
	if debug_enabled:
		print("[%s] SLOW_MO: transitioning to %.2f" % [name, target_scale])
	
	# Initial request at current interpolated value
	# _apply_effect will update this each frame
	_update_time_request(1.0)


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
	## Updates or creates a time scale request with the coordinator.
	
	if _time_coordinator == null:
		# Fallback: directly set Engine.time_scale (not recommended)
		Engine.time_scale = scale
		_has_active_request = true
		return
	
	_time_coordinator.request_time_scale(self, scale)
	_has_active_request = true


func _release_time_request() -> void:
	## Releases our time scale request from the coordinator.
	
	if not _has_active_request:
		return
	
	if _time_coordinator == null:
		# Fallback: directly restore Engine.time_scale
		Engine.time_scale = 1.0
	else:
		_time_coordinator.release_time_scale(self)
	
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
		# SceneTreeTimer doesn't have a cancel method, but it will be freed
		_freeze_timer = null
	
	# Release any active time request
	_release_time_request()
	
	# Restore exempt nodes
	_restore_exempt_nodes()
	
	if debug_enabled:
		print("[%s] Exiting - time restored" % name)
