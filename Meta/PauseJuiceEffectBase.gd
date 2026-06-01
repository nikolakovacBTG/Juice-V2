## Inserts a timed pause into a Juice effect chain without any visual output.
##
## Add to any Juice recipe to delay subsequent chained effects. Set
## [member pause_duration] to the desired pause length in seconds.
## Enable [member use_realtime] if the pause must run at wall-clock speed
## regardless of [member Engine.time_scale].

# ============================================================================
# WHAT: Domain-agnostic meta effect that delays chain progression by a fixed duration.
# WHY:  Provides a chain-scoped delay with a single, unambiguous inspector setting.
#       Unlike start_delay (which fires every trigger), PauseJuiceEffect occupies
#       an explicit slot in the chain — the delay is structural, not per-trigger.
# SYSTEM: Juice System (addons/Juice_V2/Meta/)
# DOES NOT: Write any visual property to the target node.
# DOES NOT: Expose Animate In/Out, Trigger Behaviour, Start Delay, or Loop settings
#           — these are irrelevant for a pure chain-delay effect.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseEvents.svg")
class_name PauseJuiceEffectBase
extends JuiceEffectBase


# =============================================================================
# CONFIGURATION
# =============================================================================

## How long this pause lasts in seconds. The chain will not advance until
## this duration elapses. Backed by [member duration_in] internally.
## Setting this automatically updates duration_in so the tick loop uses it.
var pause_duration: float = 0.5 :
	set(value):
		pause_duration = value
		duration_in = value

## If true, the pause timer runs at wall-clock speed and ignores Engine.time_scale.
## Use when the pause must be a fixed real-time gap (e.g. a UI beat during slow-motion).
## Default (false): the pause stretches and compresses with Engine.time_scale like any
## other effect — a slow-motion effect will also slow the pause.
var use_realtime: bool = false


# =============================================================================
# INTERNAL STATE
# =============================================================================

# Guards the use_realtime log point — only log once per animate_in to avoid
# repeating the same message every frame for the duration of the pause.
var _realtime_logged: bool = false


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

# Lock trigger_behaviour to PLAY_IN_ONLY — a pause effect never has an out phase.
# Set _subclass_owns_effect_group to suppress the base "Effect" group header.
func _init() -> void:
	_subclass_owns_effect_group = true
	trigger_behaviour = TriggerBehaviour.PLAY_IN_ONLY
	duration_in = pause_duration


## Expose a minimal, pause-specific inspector layout.
## Only pause_duration and use_realtime are added here.
## Chaining and Debug are emitted by the base class — we do NOT duplicate them.
## In Godot 4, _get_property_list() results are MERGED across the class hierarchy,
## so adding Chaining/Debug here would produce duplicates.
func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# "Effect" group with the only two user-facing settings.
	props.append({"name": "Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "pause_duration", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,60.0,0.01,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "use_realtime", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})

	# Chaining and Debug are intentionally NOT added here — the base emits them.
	return props


## Hide the base class's "Animate In" group and all its children so they don't
## appear in the inspector or get serialized to the .tscn alongside pause_duration.
## Without this, duration_in would be saved separately and could overwrite the
## value set by the pause_duration setter on scene reload.
func _validate_property(property: Dictionary) -> void:
	const HIDDEN := [
		"Animate In",
		"duration_in", "transition_in", "ease_in", "custom_curve_in",
		"hold_at_peak", "elastic_amplitude_in", "elastic_period_in", "back_overshoot_in",
	]
	if property.name in HIDDEN:
		property.usage = PROPERTY_USAGE_NONE


# Redirect pause_duration and use_realtime through _set() for inspector/resource writes.
# Also intercept duration_in: old scene files (.tscn) may have duration_in = 0.3 baked in
# from before this effect existed. Redirecting it through pause_duration ensures the setter
# always runs and keeps both values in sync, regardless of which property Godot restores first.
func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"pause_duration":
			pause_duration = value  # native setter → also sets duration_in
			return true
		&"duration_in":
			pause_duration = value  # redirect legacy/base writes through our setter
			return true
		&"use_realtime": use_realtime = value; return true
	return super._set(property, value)


# Redirect reads for our custom properties; fall through for all base properties.
func _get(property: StringName) -> Variant:
	match property:
		&"pause_duration": return pause_duration
		&"use_realtime": return use_realtime
	return super._get(property)


# =============================================================================
# TICK OVERRIDE
# =============================================================================

## When use_realtime is true, corrects the engine-scaled delta to wall-clock time
## so the pause duration is always measured in real seconds, matching V0 behavior.
## When use_realtime is false, falls through to super.tick() unchanged —
## Engine.time_scale naturally stretches/compresses the pause like any other effect.
func tick(delta: float, target: Node) -> TickResult:
	if use_realtime:
		var real_delta := delta / maxf(Engine.time_scale, 0.001)
		if not _realtime_logged:
			_realtime_logged = true
			JuiceLogger.log_info(self, _get_domain_tag(),
				"use_realtime correction: time_scale=%.3f delta=%.4f→%.4f target=%s" % [
				Engine.time_scale, delta, real_delta, target.name],
				debug_enabled)
		return super.tick(real_delta, target)
	return super.tick(delta, target)


# Resets the one-shot log guard when the animation restarts.
# Also prints an always-visible diagnostic so we can confirm duration_in is
# in sync with pause_duration at the moment the effect actually starts.
func _on_animate_start(target: Node) -> void:
	_realtime_logged = false
	print("[PauseDiag] start — pause_duration=%.3f  duration_in=%.3f  target=%s" % [
		pause_duration, duration_in, target.name if target else "null"])


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

## No visual output — this effect exists only to occupy time in the chain.
## The inherited tick() loop drives the pause duration via duration_in.
func _apply_effect(_progress: float, _target: Node) -> void:
	pass


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

## Warns in the editor if pause_duration is zero, which would make the pause a no-op.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if pause_duration <= 0.0:
		warnings.append("pause_duration is 0 — the pause will complete instantly. Set pause_duration to the desired delay length.")
	return warnings
