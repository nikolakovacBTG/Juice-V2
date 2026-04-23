## Base class for all Property family effects (Noise, Shake, Interpolate, Shader).
##
## Drives an arbitrary list of node properties using set_indexed(). Each entry
## in property_targets is a PropertyTarget sub-resource defining which node and
## property to affect, plus effect-specific config (amplitude, from/to, etc.).

# =============================================================================
# WHAT: Shared infrastructure for effects that animate arbitrary node properties.
#       Manages the target list lifecycle: capture, apply, restore, undo/reapply.
# WHY:  Avoids duplicating capture/restore/editor-save logic across Noise, Shake,
#       and Interpolate effects. They only implement _apply_effect().
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# DOES NOT: Implement the actual visual algorithm — subclasses do that.
# DOES NOT: Use domain delta aggregation — writes directly via set_indexed().
#            This is an APPROVED EXCEPTION (same as ProgressPropertyJuiceEffectBase).
#            Two Property effects on the same property on the same node will conflict.
# DOES NOT: Use JuiceLedger — arbitrary properties are not registered there.
# =============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseProperty.svg")
class_name PropertyJuiceEffectBase
extends JuiceEffectBase


# =============================================================================
# CONFIGURATION
# =============================================================================

func _init() -> void:
	# We own the Effect group layout — prevent the base from emitting a fallback.
	_subclass_owns_effect_group = true


## Set to true in _init() of any subclass that provides its own complete
## _get_property_list(). Prevents this base from emitting duplicate
## "Effect" and "Property Targets" group headers (same pattern as
## _subclass_owns_effect_group in JuiceEffectBase).
var _subclass_owns_prop_layout: bool = false


## List of property targets driven by this effect.
## Each entry specifies a node + property path + effect-specific config.
## Subclasses expose this with their concrete PropertyTarget subclass type hint
## by overriding _get_property_list() and changing the hint_string.
var property_targets: Array = []


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

## Override in subclasses to change the array element type shown in the inspector.
## Example: NoisePropertyJuiceEffectBase returns "NoisePropertyTarget".
func _get_target_resource_type() -> String:
	return "PropertyTarget"


func _get_property_list() -> Array[Dictionary]:
	# Subclasses that override _get_property_list() fully (Noise, Shake) set
	# _subclass_owns_prop_layout = true in _init() to suppress this layout.
	if _subclass_owns_prop_layout:
		return []

	var props: Array[Dictionary] = []

	# Effect group — trigger, timing, loop settings from base.
	props.append({"name": "Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append_array(_get_effect_base_properties())

	# Property Targets array — type hint drives which sub-resource Godot instantiates
	# when the user clicks "+" in the inspector array editor.
	props.append({"name": "Property Targets", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({
		"name": "property_targets",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_ARRAY_TYPE,
		"hint_string": "%d/%d:%s" % [
			TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE,
			_get_target_resource_type()],
		"usage": PROPERTY_USAGE_DEFAULT
	})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"property_targets": property_targets = value; return true
	return super._set(property, value)


func _get(property: StringName) -> Variant:
	match property:
		&"property_targets": return property_targets
	return super._get(property)


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

## Procedural effects (Noise, Shake) override to return true so they keep
## ticking after animate_in completes (sustain loop). Interpolate returns false.
func _needs_sustain() -> bool:
	return false  # Safe default; Noise/Shake subclasses override to true.


## Capture natural base values for all configured targets.
## Called by JuiceEffectBase.start() → _on_animate_start().
func _on_animate_start(target: Node) -> void:
	# Pass `target` (the animated node — ctrl, Sprite2D, etc.) NOT _host_node.
	# _host_node is the JuiceBase node itself (a plain Node with no domain properties).
	# When node_path is empty, _resolve_node returns its argument — so it must be `target`.
	for entry: PropertyTarget in property_targets:
		if entry != null and entry.is_configured():
			entry.capture_base(target)


## Restore all targets to their natural values. Called by stop().
func _restore_to_natural(_target: Node) -> void:
	for entry: PropertyTarget in property_targets:
		if entry != null:
			entry.restore_natural()


## Called by the domain node during NOTIFICATION_EDITOR_PRE_SAVE.
## Undo our writes before the scene file is saved so dirty values aren't baked in.
func _temporarily_undo_visual(_target: Node) -> void:
	if not _is_playing:
		return
	for entry: PropertyTarget in property_targets:
		if entry != null:
			entry.restore_natural()


## Re-apply effect after the editor save completes.
func _temporarily_reapply_visual(target: Node) -> void:
	if not _is_playing:
		return
	_apply_effect(_animation_progress, target)


## Property effects bypass the domain delta aggregation system — they write
## directly via set_indexed(). Return {} so the sequencer ignores them.
## Same approved exception as Camera, Screen, Time, and ProgressProperty effects.
func _get_seq_contribution() -> Dictionary:
	return {}


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if property_targets.is_empty():
		warnings.append("No Property Targets configured. Add at least one entry.")
	else:
		for i: int in property_targets.size():
			var entry: PropertyTarget = property_targets[i]
			if entry == null:
				warnings.append("Property Targets[%d] is null." % i)
				continue
			for w: String in entry.get_target_warnings():
				warnings.append("[%d] %s" % [i, w])
	return warnings
