## Dynamically generates configuration warnings and inspector hints for Juice triggers.
## ============================================================================
## WHAT: Static helper that builds a filtered Godot PROPERTY_HINT_ENUM hint
##       string for the `trigger_on` property on JuiceBase domain nodes.
##
## WHY:  The full TriggerEvent enum contains entries that are nonsensical for
##       many trigger source nodes (e.g. On Body Entered when the source is a
##       Button, or On Focus when the source is an Area2D). This builder reads
##       the source node's capabilities at editor time and returns only the
##       valid subset, formatted as "Label:int,Label:int,...".
##
##       The backing enum values (ints) are NEVER changed — this only affects
##       the hint string shown in the inspector dropdown. Serialized scenes are
##       100% stable; programmers can still set any TriggerEvent value in code.
##
## SYSTEM: Juice System (addons/Juice_V2/) — Editor tooling only
##
## USAGE:
##   In _validate_property on a JuiceBase domain node:
##     if property.name == "trigger_on":
##         var source := _resolve_hint_source_node()
##         property.hint_string = TriggerHintBuilder.build_hint(source, &"2D")
##
## DOES NOT:
## - Run at runtime (all output is inspector hint strings)
## - Change any enum values or stored property values
## - Make any assumptions about project autoloads or game systems
## ============================================================================

@tool
class_name TriggerHintBuilder


# =============================================================================
# DOMAIN FULL-HINT CONSTANTS
# Used as the safe fallback when source is null/unknown — same as current
# hardcoded per-domain constants in Juice2D / Juice3D / JuiceControl.
# =============================================================================

const _FULL_2D := (
	"On Press (toggleable):0,On Release:1,On Mouse Entered (toggleable):2,"
	+ "On Mouse Exited:3,On Show:6,On Hide:7,On Ready:8,Manual:9,"
	+ "On Left Click:10,On Right Click:11,On Middle Click:12,"
	+ "On Body Entered (toggleable):13,On Body Exited:14,"
	+ "On Area Entered (toggleable):15,On Area Exited:16"
)

const _FULL_3D := (
	"On Press (toggleable):0,On Release:1,On Mouse Entered (toggleable):2,"
	+ "On Mouse Exited:3,On Show:6,On Hide:7,On Ready:8,Manual:9,"
	+ "On Left Click:10,On Right Click:11,On Middle Click:12,"
	+ "On Body Entered (toggleable):13,On Body Exited:14,"
	+ "On Area Entered (toggleable):15,On Area Exited:16"
)

const _FULL_CONTROL := (
	"On Press (toggleable):0,On Release:1,On Mouse Entered (toggleable):2,"
	+ "On Mouse Exited:3,On Focus (toggleable):4,On Unfocus:5,"
	+ "On Show:6,On Hide:7,On Ready:8,Manual:9,"
	+ "On Left Click:10,On Right Click:11,On Middle Click:12"
)

# Always-available entries regardless of source node.
const _ALWAYS := "On Ready:8,Manual:9"

# Juice utility hint: driven via set_external_progress, trigger system bypassed.
# Show only the bare minimum so users aren't confused.
const _SOFT_TRIGGER_HINT := "On Ready:8,Manual:9"


# =============================================================================
# PUBLIC API
# =============================================================================

## Build a filtered trigger_on hint string for the given source node.
##
## @param source_node  The resolved trigger source node (may be null).
## @param domain       One of &"2D", &"3D", or &"Control".
## @returns            A "Label:int,..." hint string for PROPERTY_HINT_ENUM.
static func build_hint(source_node: Node, domain: StringName) -> String:
	# No source — return the full domain hint (safe fallback).
	if source_node == null:
		return _full_hint_for_domain(domain)

	# SoftTrigger utilities drive progress directly via set_external_progress().
	# The Trigger On dropdown is vestigial when using them — show minimal set.
	if source_node is SoftTrigger2DJuiceUtility or source_node is SoftTrigger3DJuiceUtility or source_node is SoftTriggerControlJuiceUtility:
		return _SOFT_TRIGGER_HINT

	# AnimationPlayer: hardcoded callback on animation_finished. Manual is the
	# only useful user-facing trigger.
	if source_node is AnimationPlayer:
		return _ALWAYS

	# Capability-based filtering for everything else.
	# Order follows TriggerEvent enum values to match the _FULL_* constants.
	var parts: PackedStringArray = []
	var has_mouse := source_node.has_signal("mouse_entered")

	# -- Press / Release / Mouse (0-3) --
	if has_mouse:
		parts.append("On Press (toggleable):0")
		parts.append("On Release:1")
		parts.append("On Mouse Entered (toggleable):2")
		parts.append("On Mouse Exited:3")

	# -- Focus (4-5, Control-only) --
	if source_node.has_signal("focus_entered"):
		parts.append("On Focus (toggleable):4")
		parts.append("On Unfocus:5")

	# -- Visibility (6-7) --
	if source_node.has_signal("visibility_changed"):
		parts.append("On Show:6")
		parts.append("On Hide:7")

	# -- Ready / Manual (8-9, always available) --
	parts.append("On Ready:8")
	parts.append("Manual:9")

	# -- Clicks (10-12) --
	if has_mouse:
		parts.append("On Left Click:10")
		parts.append("On Right Click:11")
		parts.append("On Middle Click:12")

	# -- Physics bodies (13-14, Area2D / Area3D) --
	if source_node.has_signal("body_entered"):
		parts.append("On Body Entered (toggleable):13")
		parts.append("On Body Exited:14")

	# -- Other areas (15-16, Area2D / Area3D) --
	if source_node.has_signal("area_entered"):
		parts.append("On Area Entered (toggleable):15")
		parts.append("On Area Exited:16")

	if parts.is_empty():
		# Source node has no recognisable signals — show full domain hint.
		return _full_hint_for_domain(domain)

	return ",".join(parts)


# =============================================================================
# HELPERS
# =============================================================================

static func _full_hint_for_domain(domain: StringName) -> String:
	match domain:
		&"3D":
			return _FULL_3D
		&"Control":
			return _FULL_CONTROL
		_:
			return _FULL_2D
