extends Node
class_name JuiceTimeCoordinator
## ============================================================================
## JUICE TIME COORDINATOR — Optional Time Scale Manager
## ============================================================================
## Coordinates Engine.time_scale requests from multiple TimeJuiceComp instances
## (and any other system) to prevent conflicts when several effects manipulate
## gameplay speed simultaneously.
##
## SYSTEM: Juice System (addons/juice/Utility/)
##
## USAGE:
## This script is OPTIONAL. TimeJuiceComp works without it (built-in static
## fallback handles simple cases). Add this when you need:
##   - Priority resolution (slowest slow-mo wins, fastest speed-up wins)
##   - Audio pitch sync with time scale
##   - A central place for other systems to also request time changes
##   - The time_scale_changed signal for UI or gameplay reactions
##
## SETUP:
##   1. Add as an Autoload (Project → Project Settings → Autoload)
##   2. Or add as a child of any persistent node in your scene
##   3. TimeJuiceComp discovers it automatically — no wiring needed
##
## DISCOVERY:
## Uses a static instance pattern. TimeJuiceComp checks
## JuiceTimeCoordinator.instance on _ready(). If found, all time requests
## go through the coordinator. If not found, TimeJuiceComp falls back to
## its built-in static request system.
##
## RESOLUTION LOGIC:
##   - Multiple slow-mo requests: minimum scale wins (slowest dominates)
##   - Multiple speed-up requests: maximum scale wins (fastest dominates)
##   - Mixed: slow-mo takes priority (scale < 1.0 overrides scale > 1.0)
##   - No requests: returns to 1.0
##
## DOES NOT HANDLE:
##   - World/day-night time (game-specific, not juice)
##   - Per-object time scaling (Godot limitation)
##   - Juice timing or triggering (TimeJuiceComp handles that)
## ============================================================================


# =============================================================================
# STATIC INSTANCE (auto-discovery by TimeJuiceComp)
# =============================================================================

## Global reference for TimeJuiceComp to find the coordinator.
## Only one JuiceTimeCoordinator should exist at a time.
static var instance: JuiceTimeCoordinator = null


# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when the effective time scale changes.
## Connect to this for audio sync, UI updates, gameplay reactions, etc.
signal time_scale_changed(new_scale: float, old_scale: float)


# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Audio Integration")

## If set, adjusts pitch on this audio bus proportionally to time scale.
## Leave empty to disable audio pitch adjustment.
@export var affect_audio_bus: StringName = &""

@export_group("Debug")

## Enable debug output to console
@export var debug_enabled: bool = false


# =============================================================================
# RUNTIME STATE
# =============================================================================

## Active time scale requests: Node instance_id → requested scale
var _requests: Dictionary = {}

## Current effective time scale (what Engine.time_scale is set to)
var _effective_scale: float = 1.0

## Cached audio bus index for pitch adjustment (-1 if not found)
var _audio_bus_index: int = -1

## Cached pitch effect index on the audio bus (-1 if not found)
var _pitch_effect_index: int = -1


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	if instance != null and instance != self:
		if debug_enabled:
			push_warning("[JuiceTimeCoordinator] Multiple instances detected — replacing previous.")
	instance = self

	# Cache audio bus index if configured
	if affect_audio_bus != &"":
		_audio_bus_index = AudioServer.get_bus_index(affect_audio_bus)
		if _audio_bus_index == -1:
			push_warning("[JuiceTimeCoordinator] Audio bus '%s' not found" % affect_audio_bus)
		else:
			_find_pitch_effect()

	if debug_enabled:
		print("[JuiceTimeCoordinator] Ready (static instance registered). Audio bus: '%s'" % affect_audio_bus)


func _exit_tree() -> void:
	if instance == self:
		instance = null

	# Restore Engine.time_scale if we were managing it
	if Engine.time_scale != 1.0:
		Engine.time_scale = 1.0
		if debug_enabled:
			print("[JuiceTimeCoordinator] Restored Engine.time_scale to 1.0 on exit")


# =============================================================================
# PUBLIC API
# =============================================================================

func request_time_scale(requester: Node, scale: float) -> void:
	## Register a time scale request.
	## The effective scale is computed from all active requests.
	##
	## @param requester: The node making the request (used as identifier)
	## @param scale: Desired time scale (0.0 = freeze, <1.0 = slow, >1.0 = fast)

	if not is_instance_valid(requester):
		push_warning("[JuiceTimeCoordinator] Invalid requester node")
		return

	var requester_id := requester.get_instance_id()
	_requests[requester_id] = scale

	if debug_enabled:
		print("[JuiceTimeCoordinator] Request from '%s': scale=%.2f (total: %d)" % [
			requester.name, scale, _requests.size()
		])

	_update_effective_scale()


func release_time_scale(requester: Node) -> void:
	## Release a time scale request.
	## Called when the requesting system no longer needs time manipulation.
	##
	## @param requester: The node that made the original request

	if not is_instance_valid(requester):
		return

	var requester_id := requester.get_instance_id()

	if _requests.has(requester_id):
		_requests.erase(requester_id)

		if debug_enabled:
			print("[JuiceTimeCoordinator] Released by '%s' (remaining: %d)" % [
				requester.name, _requests.size()
			])

		_update_effective_scale()


func get_effective_scale() -> float:
	## Returns the current effective time scale.
	return _effective_scale


func has_active_requests() -> bool:
	## Returns true if any system is currently requesting time manipulation.
	return not _requests.is_empty()


func clear_all_requests() -> void:
	## Emergency clear of all requests. Use for scene transitions or recovery.
	_requests.clear()
	_update_effective_scale()

	if debug_enabled:
		print("[JuiceTimeCoordinator] All requests cleared")


# =============================================================================
# INTERNAL LOGIC
# =============================================================================

func _update_effective_scale() -> void:
	## Computes the effective time scale from all active requests and applies it.

	var old_scale := _effective_scale

	if _requests.is_empty():
		_effective_scale = 1.0
	else:
		var slow_mo_scales: Array[float] = []
		var speed_up_scales: Array[float] = []

		for scale in _requests.values():
			if scale <= 1.0:
				slow_mo_scales.append(scale)
			else:
				speed_up_scales.append(scale)

		# Resolution: slow-mo takes priority, then speed-up
		if not slow_mo_scales.is_empty():
			_effective_scale = slow_mo_scales.min()
		elif not speed_up_scales.is_empty():
			_effective_scale = speed_up_scales.max()
		else:
			_effective_scale = 1.0

	if _effective_scale != old_scale:
		Engine.time_scale = _effective_scale
		_apply_audio_pitch()

		if debug_enabled:
			print("[JuiceTimeCoordinator] Scale changed: %.2f → %.2f" % [old_scale, _effective_scale])

		time_scale_changed.emit(_effective_scale, old_scale)


func _find_pitch_effect() -> void:
	## Searches for a PitchShift effect on the configured audio bus.
	if _audio_bus_index < 0:
		return

	var effect_count := AudioServer.get_bus_effect_count(_audio_bus_index)
	for i in range(effect_count):
		var effect := AudioServer.get_bus_effect(_audio_bus_index, i)
		if effect is AudioEffectPitchShift:
			_pitch_effect_index = i
			if debug_enabled:
				print("[JuiceTimeCoordinator] Found PitchShift effect at index %d" % i)
			return

	if debug_enabled:
		push_warning("[JuiceTimeCoordinator] No PitchShift effect on bus '%s'" % affect_audio_bus)


func _apply_audio_pitch() -> void:
	## Adjusts the pitch effect on the configured audio bus to match time scale.
	if _audio_bus_index < 0 or _pitch_effect_index < 0:
		return

	var effect := AudioServer.get_bus_effect(_audio_bus_index, _pitch_effect_index)
	if effect is AudioEffectPitchShift:
		var pitch := clampf(_effective_scale, 0.5, 2.0)
		effect.pitch_scale = pitch

		if debug_enabled:
			print("[JuiceTimeCoordinator] Audio pitch set to %.2f" % pitch)
