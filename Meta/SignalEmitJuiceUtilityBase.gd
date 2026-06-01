## Base class for signal emission utilities.
##
## Holds an array of SignalEmitEntry sub-resources. Each entry fires
## juice_signal(payload) independently at its own timing. Multiple entries
## let one utility emit different signals at different animation points.

# ============================================================================
# WHAT: Emits one juice_signal per SignalEmitEntry when an animation
#       starts or completes. Domain-agnostic — no visual output.
# WHY:  Allows designers to wire "when this animation fires → notify system X"
#       purely in the inspector, without writing custom scripts. Integrates natively
#       with the event orchestration system.
#       SignalEmitJuiceUtility (standalone Node) with a chainable Resource that
#       participates in the recipe stack: start_delay, chain_to, loop all work.
#       Upgraded from single-entry to array to match recipe-item paradigm.
# SYSTEM: Juice System (addons/Juice_V2/Meta/)
# DOES NOT: Produce any visual effect — control/flow only.
# DOES NOT: Block animation completion — fires and immediately completes.
#
# CROSSFADE TIME is intentionally hidden — it blends _animation_progress,
# but _apply_effect is a no-op here so crossfade has no observable effect.
#
# USAGE:
#   - Add to a JuiceBase recipe alongside visual effects
#   - Use start_delay to fire signals partway through a sequence
#   - Connect juice_signal to game systems in the inspector or via code
#   - Multiple entries let one utility cover several signal needs
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceUtilitySignals.svg")
class_name SignalEmitJuiceUtilityBase
extends JuiceEffectBase


# =============================================================================
# SIGNALS
# =============================================================================

## Emitted for each entry when its timing matches. payload carries entry data.
## Connect other systems to this signal to react to animation events.
signal juice_signal(payload: Variant)


# =============================================================================
# ENUMS
# =============================================================================

## Timing constants (matches SignalEmitEntry.emit_on int values).
## Kept for external API reference (e.g. other scripts connecting to this).
enum EmitTiming {
	ON_START    = 0,  ## Emit when animate_in() begins (after start_delay).
	ON_COMPLETE = 1,  ## Emit when animation reaches peak (progress=1.0).
	ON_BOTH     = 2,  ## Emit on both start and complete.
}


# =============================================================================
# CONFIGURATION
# =============================================================================

func _init() -> void:
	_subclass_owns_effect_group = true

## List of signal entries to emit. Each fires independently at its own timing.
var entries: Array = []


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# Single "Trigger" group — meta effects have no visual properties.
	props.append({"name": "Trigger", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})

	props.append({"name": "trigger_behaviour", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Play In And Out,Play In Only,Play Out Only,Toggle,Set From Source",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "start_delay", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,100.0,0.01,or_greater",
		"usage": PROPERTY_USAGE_DEFAULT})

	props.append({"name": "loop_count", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT})
	if loop_count != 1:
		props.append({"name": "ping_pong", "type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "loop_delay", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "loop_phase_offset", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
			"usage": PROPERTY_USAGE_DEFAULT})

	# Crossfade Time intentionally omitted — see file header.

	# Signal Entries group — typed array of SignalEmitEntry resources.
	props.append({"name": "Signal Entries", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({
		"name": "entries",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_ARRAY_TYPE,
		"hint_string": "%d/%d:%s" % [
			TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "SignalEmitEntry"],
		"usage": PROPERTY_USAGE_DEFAULT
	})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"entries": entries = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"entries": return entries
	return null


# Hide the auto-generated 'entries' property. _get_property_list() provides
# the properly-hinted version with PROPERTY_HINT_ARRAY_TYPE; the raw var
# would appear as an untyped array and bypass our custom array editor.
func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == &"entries" and property.hint == PROPERTY_HINT_NONE:
		property.usage = PROPERTY_USAGE_NONE


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

# Called when the animation slot triggers. Fires all entries configured for ON_START.
# No target resolution needed — juice_signal emits on this resource, not a node.
func _on_animate_start(_target: Node) -> void:
	_emit_for_timing(EmitTiming.ON_START, "ON_START")


# Called when animate_in reaches progress=1.0. Fires entries configured for ON_COMPLETE.
# Note: this is animate_in complete, not animate_out — the intent is "call when peaked".
func _on_animate_in_complete(_target: Node) -> void:
	_emit_for_timing(EmitTiming.ON_COMPLETE, "ON_COMPLETE")


func _apply_effect(_progress: float, _target: Node) -> void:
	pass  # No visual output — signal emission happens in lifecycle hooks.


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if entries.is_empty():
		warnings.append("No Signal Entries configured. Add at least one entry.")
	return warnings


# =============================================================================
# HELPERS
# =============================================================================

# Fire all entries whose emit_on matches the given timing.
func _emit_for_timing(timing: EmitTiming, timing_label: String) -> void:
	for entry: SignalEmitEntry in entries:
		if entry == null:
			continue
		# 2 = ON_BOTH — fires on both start and complete.
		if entry.emit_on == timing or entry.emit_on == EmitTiming.ON_BOTH:
			juice_signal.emit(entry.payload)
			JuiceLogger.log_info(self, _get_domain_tag(),
					"'%s' emitted at %s, payload=%s" % [
					entry.signal_description, timing_label, entry.payload],
					debug_enabled)
