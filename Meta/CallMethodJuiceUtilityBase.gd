## Base class for method-call utilities.
##
## Holds an array of CallMethodEntry sub-resources. Each entry calls its own
## method on its own target node at its own timing. Multiple entries let one
## utility drive several method calls from a single recipe resource.

# ============================================================================
# WHAT: Calls one method per CallMethodEntry when an animation starts or completes.
#       Domain-agnostic — no visual output.
# WHY:  Allows designers to wire "when this animation fires → call method X"
#       purely in the inspector, without writing custom scripts. Integrates natively
#       with the event orchestration system.
#       CallMethodJuiceUtility (standalone Node) with a chainable Resource that
#       participates in the recipe stack: start_delay, chain_to, loop all work.
#       Upgraded from single-entry to array to match recipe-item paradigm.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# DOES NOT: Produce any visual effect — control/flow only.
# DOES NOT: Handle return values from called methods.
# DOES NOT: Block animation completion — calls and immediately completes.
#
# CROSSFADE TIME is intentionally hidden — it blends _animation_progress,
# but _apply_effect is a no-op here so crossfade has no observable effect.
#
# TARGET RESOLUTION per entry:
#   target_node_path resolves relative to _host_node (the JuiceBase node).
#   Leave empty to call on the juiced target node itself.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceUtilityMethods.svg")
class_name CallMethodJuiceUtilityBase
extends JuiceEffectBase


# =============================================================================
# ENUMS
# =============================================================================

## Timing constants (matches CallMethodEntry.call_on int values).
enum CallTiming {
	ON_START    = 0,  ## Call when animate_in() begins (after start_delay).
	ON_COMPLETE = 1,  ## Call when animation reaches peak (progress=1.0).
	ON_BOTH     = 2,  ## Call on both start and complete.
}


# =============================================================================
# CONFIGURATION
# =============================================================================

func _init() -> void:
	_subclass_owns_effect_group = true

## List of method call entries. Each fires independently at its own timing.
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

	# Method Calls group — typed array of CallMethodEntry resources.
	props.append({"name": "Method Calls", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({
		"name": "entries",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_ARRAY_TYPE,
		"hint_string": "%d/%d:%s" % [
			TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "CallMethodEntry"],
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


# =============================================================================
# INTERNAL STATE
# =============================================================================

## Cache of per-entry resolved target nodes. Populated in _on_animate_start,
## cleared in _restore_to_natural. Index matches entries array.
var _resolved_targets: Array[Node] = []


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

func _on_animate_start(target: Node) -> void:
	_resolve_all_targets(target)
	_call_entries_for_timing(CallTiming.ON_START, "ON_START")


func _on_animate_in_complete(_target: Node) -> void:
	_call_entries_for_timing(CallTiming.ON_COMPLETE, "ON_COMPLETE")


func _apply_effect(_progress: float, _target: Node) -> void:
	pass  # No visual output — method calls happen in lifecycle hooks.


func _restore_to_natural(_target: Node) -> void:
	_resolved_targets.clear()


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if entries.is_empty():
		warnings.append("No Method Call entries configured. Add at least one entry.")
	else:
		for i: int in entries.size():
			var entry: CallMethodEntry = entries[i]
			if entry == null:
				warnings.append("entries[%d] is null." % i)
			elif entry.method_name.is_empty():
				warnings.append("entries[%d]: method_name is empty." % i)
	return warnings


# =============================================================================
# HELPERS
# =============================================================================

# Resolve all entry target nodes relative to the host / fallback target.
func _resolve_all_targets(fallback_target: Node) -> void:
	_resolved_targets.clear()
	for entry: CallMethodEntry in entries:
		if entry == null:
			_resolved_targets.append(null)
			continue
		if not entry.target_node_path.is_empty():
			var resolved: Node = null
			if _host_node != null:
				resolved = _host_node.get_node_or_null(entry.target_node_path)
			if resolved == null:
				JuiceLogger.warn(self, _get_domain_tag(),
						"entry target_node_path '%s' not found from host" % entry.target_node_path,
						debug_enabled)
			_resolved_targets.append(resolved)
		else:
			_resolved_targets.append(fallback_target)


# Call all entries whose call_on matches the given timing.
func _call_entries_for_timing(timing: CallTiming, timing_label: String) -> void:
	for i: int in entries.size():
		var entry: CallMethodEntry = entries[i]
		if entry == null:
			continue
		if entry.call_on != timing and entry.call_on != CallTiming.ON_BOTH:
			continue

		var method_target: Node = null
		if i < _resolved_targets.size():
			method_target = _resolved_targets[i]

		_do_call(entry, method_target, timing_label)


# Validates the target node and method exist, then dispatches the call with or without arguments.
func _do_call(entry: CallMethodEntry, method_target: Node, timing_label: String) -> void:
	if not is_instance_valid(method_target):
		JuiceLogger.warn(self, _get_domain_tag(),
				"no valid target node to call '%s'" % entry.method_name,
				debug_enabled)
		return

	if entry.method_name.is_empty():
		JuiceLogger.warn(self, _get_domain_tag(),
				"method_name is empty for entry", debug_enabled)
		return

	if not method_target.has_method(entry.method_name):
		JuiceLogger.warn(self, _get_domain_tag(),
				"'%s' doesn't have method '%s'" % [
				method_target.name, entry.method_name],
				debug_enabled)
		return

	if entry.arguments.is_empty():
		method_target.call(entry.method_name)
	else:
		method_target.callv(entry.method_name, entry.arguments)

	var args_str := str(entry.arguments) if not entry.arguments.is_empty() else "()"
	JuiceLogger.log_info(self, _get_domain_tag(),
			"[%s] called %s.%s%s" % [
			timing_label, method_target.name, entry.method_name, args_str],
			debug_enabled)
