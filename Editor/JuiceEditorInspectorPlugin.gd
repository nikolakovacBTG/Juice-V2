## Controls which JuiceBase inspector properties are visible based on current node state.
##
## Centralises all Juice property-visibility logic in one editor class, keeping
## domain nodes free of editor-only code. This enables @tool to be stripped from
## domain nodes in a future phase without losing inspector usability.

# ============================================================================
# WHAT: EditorInspectorPlugin that shows/hides JuiceBase properties reactively.
# WHY:  Property visibility logic (which sequencer props to show, when to hide
#       manual_trigger_signal, etc.) belongs in the editor layer — not baked into
#       runtime domain nodes as _validate_property overrides. The plugin fires
#       _parse_property for every inspector rebuild, exactly as _validate_property
#       did, but from a dedicated editor class.
# SYSTEM: Juice System — Editor layer (addons/Juice_V2/Editor/)
# DOES NOT: Handle Resource sub-inspectors (JuiceEffectBase, JuiceRecipe, etc.)
#           Those are embedded sub-resources and EditorInspectorPlugin._parse_property
#           does not fire for their properties. Resource-level _validate_property stays.
# ============================================================================
#
# TOGGLE BEHAVIOUR NOTE:
# The previous _validate_property dynamically modified trigger_behaviour's enum
# hint_string to hide the "Toggle" option on non-toggleable triggers. This is
# not possible from EditorInspectorPlugin._parse_property (which cannot modify
# hint_string — only hide properties or add custom controls).
# V2 decision: always show all trigger_behaviour options including Toggle.
# Selecting Toggle on an incompatible trigger (e.g. ON_RELEASE) is a
# misconfiguration that surfaces as a _get_configuration_warnings() warning.
# This is more consistent: misconfig → warning, not → silent inspector hiding.
# The warning is added to JuiceBase._get_configuration_warnings() in Phase 3.3.
# ============================================================================

@tool
extends EditorInspectorPlugin


# =====================================================================
# ENTRY POINT
# =====================================================================

# Return true to claim this object — we inspect all JuiceBase domain nodes.
func _can_handle(object: Object) -> bool:
	return object is JuiceBase


# =====================================================================
# PROPERTY VISIBILITY
# =====================================================================

# Called by Godot for every property of the inspected JuiceBase node.
# Return true to consume the property (hide it from the default inspector).
# Return false to let the default inspector render it normally.
#
# Mirrors the logic that lived in JuiceBase._validate_property().
# Reading state directly from the live node instance is safe here because
# this method is called synchronously during an inspector rebuild triggered
# by notify_property_list_changed() — the same moment _validate_property fired.
func _parse_property(object: Object, _type: Variant.Type, name: String,
		_hint_type: PropertyHint, _hint_string: String,
		_usage_flags: int, _wide: bool) -> bool:

	if not object is JuiceBase:
		return false

	var node := object as JuiceBase

	# --- Trigger group: inline conditional display ---

	# auto_connect_parent is only relevant when the source is the PARENT node.
	# When using a specific NODE source, auto-connect concept does not apply.
	if name == "auto_connect_parent" \
			and node.trigger_source != JuiceBase.TriggerSource.PARENT:
		return true

	# trigger_source_path is only relevant when the user picks a specific NODE.
	# When using PARENT source, there is nothing to path-reference.
	if name == "trigger_source_path" \
			and node.trigger_source != JuiceBase.TriggerSource.NODE:
		return true

	# manual_trigger_signal is only relevant for MANUAL trigger_on.
	# For every other event the signal is determined automatically.
	if name == "manual_trigger_signal" \
			and node.trigger_on != JuiceBase.TriggerEvent.MANUAL:
		return true

	# --- Loop group ---

	# loop_delay has no effect when loop_count == 1 (no looping).
	if name == "loop_delay" and node.loop_count == 1:
		return true

	# --- Mode group: sequencer properties hidden in STACK mode ---

	# In STACK mode the sequencer sub-system is inactive; expose nothing from it.
	const SEQ_PROPS: Array[String] = [
		"juice_source", "target_scope", "seq_custom_targets", "seq_stack_name",
		"sequence_type", "seq_stagger_delay", "seq_mirror_stagger_on_exit",
		"seq_skip_invisible", "seq_skip_self", "seq_skip_juice_nodes",
		"seq_hide_parent_on_reverse_complete",
	]
	if node.mode == JuiceBase.Mode.STACK and name in SEQ_PROPS:
		return true

	# --- Within SEQUENCER mode: fine-grained conditional visibility ---
	if node.mode == JuiceBase.Mode.SEQUENCER:

		# seq_custom_targets is only needed for a manually authored target list.
		if name == "seq_custom_targets" \
				and node.target_scope != JuiceBase.TargetScope.CUSTOM:
			return true

		# seq_stack_name is only needed when juice is sourced from a named child container.
		if name == "seq_stack_name" \
				and node.juice_source != JuiceBase.JuiceSource.TARGETS_STACK:
			return true

		# seq_stagger_delay has no effect when all targets fire simultaneously.
		if name == "seq_stagger_delay" \
				and node.sequence_type == JuiceBase.SequenceType.ALL_AT_ONCE:
			return true

		# seq_mirror_stagger_on_exit only applies to directional stagger types.
		# Random and ALL_AT_ONCE have no direction to mirror.
		if name == "seq_mirror_stagger_on_exit" \
				and node.sequence_type not in [
					JuiceBase.SequenceType.STAGGER_FORWARD,
					JuiceBase.SequenceType.STAGGER_REVERSE,
				]:
			return true

	return false
