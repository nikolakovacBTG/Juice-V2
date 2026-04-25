## Juice node for [Control] targets (Button, Label, Panel, etc.).
##
## Attach as a child of any [Control]. Assign a [JuiceRecipe] and configure
## triggers to animate position, scale, rotation, appearance, and more.
## Effects stack automatically when multiple Juice nodes share a target.

# ============================================================================
# WHAT: Juice node for Control targets (Button, Label, Panel, etc.).
# WHY: Validates parent is Control, connects Control/Button-specific signals,
#      handles Container-aware external-move detection.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Implement effects — those are JuiceEffectBase resources in a recipe.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name JuiceControl
extends JuiceBase

# =============================================================================
# CONDITIONAL EXPORT SYSTEM (Override)
# =============================================================================

## Hint string for JuiceControl: fallback when no trigger source node is resolvable.
const _CONTROL_TRIGGER_HINT := "On Press (toggleable):0,On Release:1,On Mouse Entered (toggleable):2,On Mouse Exited:3,On Focus (toggleable):4,On Unfocus:5,On Show:6,On Hide:7,On Ready:8,Manual:9,On Left Click:10,On Right Click:11,On Middle Click:12"

func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "trigger_on":
		# Dynamically filter to only valid options for the current trigger source.
		var source: Node = _resolve_hint_source_node()
		property.hint_string = TriggerHintBuilder.build_hint(source, &"Control")
	# Narrow recipe type so inspector only offers JuiceControlRecipe
	if property.name == "recipe":
		property.hint_string = "JuiceControlRecipe"

# =============================================================================
# INTERNAL STATE (Write Coordination)
# =============================================================================

# Whether base values have been captured at least once.
# All property tracking (transform + self_modulate) is owned by JuiceLedger.
var _base_captured: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()


func _exit_tree() -> void:
	super._exit_tree()
	if _target_node != null and is_instance_valid(_target_node):
		JuiceLedger.cleanup_source(_target_node, self)

# =============================================================================
# TARGET RESOLUTION (Override)
# =============================================================================

## Resolve target and validate it's a Control node.
func _resolve_target() -> Node:
	if mode == Mode.STACK:
		var parent := get_parent()
		if parent is Control:
			return parent
		if parent != null:
			JuiceLogger.warn(self, _get_domain_tag(),
					"Parent '%s' is not a Control node" % parent.name,
					debug_enabled)
		return null
	return null  # SEQUENCER resolves per-target dynamically

# =============================================================================
# AUTO-CONNECT (Override)
# =============================================================================

func _is_recognized_trigger_source(node: Node) -> bool:
	if super._is_recognized_trigger_source(node):
		return true
	return node is BaseButton or node is Control or node is AnimationPlayer


## Connect Control/Button-specific signals based on trigger_on.
## Uses _trigger_source_node (may differ from _target_node when TriggerSource == NODE).
func _auto_connect_domain_signals() -> void:
	if _trigger_source_node == null:
		return

	# Button is a subclass of Control with richer signal set
	if _trigger_source_node is BaseButton:
		_connect_button_signals(_trigger_source_node as BaseButton)
		return

	# Generic Control signals
	if _trigger_source_node is Control:
		_connect_control_signals(_trigger_source_node as Control)


func _connect_button_signals(button: BaseButton) -> void:
	match trigger_on:
		TriggerEvent.ON_PRESS:
			# Wire both edges as polarity pair so Toggle can use press=in, release=out.
			# PLAY_IN_ONLY/PLAY_IN_AND_OUT only respond to polarity_on (press edge),
			# PLAY_OUT_ONLY responds to polarity_off (release edge) — all handled in _on_trigger_polarity.
			if not button.button_down.is_connected(_on_trigger_polarity_on):
				button.button_down.connect(_on_trigger_polarity_on)
			if not button.button_up.is_connected(_on_trigger_polarity_off):
				button.button_up.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_RELEASE:
			if not button.button_up.is_connected(_on_trigger_momentary):
				button.button_up.connect(_on_trigger_momentary)
		TriggerEvent.ON_MOUSE_ENTERED:
			if not button.mouse_entered.is_connected(_on_trigger_polarity_on):
				button.mouse_entered.connect(_on_trigger_polarity_on)
			if not button.mouse_exited.is_connected(_on_trigger_polarity_off):
				button.mouse_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_MOUSE_EXITED:
			if not button.mouse_entered.is_connected(_on_trigger_polarity_on):
				button.mouse_entered.connect(_on_trigger_polarity_on)
			if not button.mouse_exited.is_connected(_on_trigger_polarity_off):
				button.mouse_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_FOCUS:
			if not button.focus_entered.is_connected(_on_trigger_polarity_on):
				button.focus_entered.connect(_on_trigger_polarity_on)
			if not button.focus_exited.is_connected(_on_trigger_polarity_off):
				button.focus_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_UNFOCUS:
			if not button.focus_entered.is_connected(_on_trigger_polarity_on):
				button.focus_entered.connect(_on_trigger_polarity_on)
			if not button.focus_exited.is_connected(_on_trigger_polarity_off):
				button.focus_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_LEFT_CLICK, TriggerEvent.ON_RIGHT_CLICK, TriggerEvent.ON_MIDDLE_CLICK:
			if not button.gui_input.is_connected(_on_control_gui_input_filtered):
				button.gui_input.connect(_on_control_gui_input_filtered)
	JuiceLogger.log_info(self, _get_domain_tag(),
			"Auto-connected to Button '%s' on %s" % [
			button.name, TriggerEvent.keys()[trigger_on]],
			debug_enabled)


func _connect_control_signals(control: Control) -> void:
	match trigger_on:
		TriggerEvent.ON_PRESS:
			# Polarity handler fires polarity_on on mouse-down, polarity_off on mouse-up.
			if not control.gui_input.is_connected(_on_control_gui_input_press_polarity):
				control.gui_input.connect(_on_control_gui_input_press_polarity)
		TriggerEvent.ON_RELEASE:
			if not control.gui_input.is_connected(_on_control_gui_input_release):
				control.gui_input.connect(_on_control_gui_input_release)
		TriggerEvent.ON_MOUSE_ENTERED:
			if not control.mouse_entered.is_connected(_on_trigger_polarity_on):
				control.mouse_entered.connect(_on_trigger_polarity_on)
			if not control.mouse_exited.is_connected(_on_trigger_polarity_off):
				control.mouse_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_MOUSE_EXITED:
			if not control.mouse_entered.is_connected(_on_trigger_polarity_on):
				control.mouse_entered.connect(_on_trigger_polarity_on)
			if not control.mouse_exited.is_connected(_on_trigger_polarity_off):
				control.mouse_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_FOCUS:
			if not control.focus_entered.is_connected(_on_trigger_polarity_on):
				control.focus_entered.connect(_on_trigger_polarity_on)
			if not control.focus_exited.is_connected(_on_trigger_polarity_off):
				control.focus_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_UNFOCUS:
			if not control.focus_entered.is_connected(_on_trigger_polarity_on):
				control.focus_entered.connect(_on_trigger_polarity_on)
			if not control.focus_exited.is_connected(_on_trigger_polarity_off):
				control.focus_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_LEFT_CLICK, TriggerEvent.ON_RIGHT_CLICK, TriggerEvent.ON_MIDDLE_CLICK:
			if not control.gui_input.is_connected(_on_control_gui_input_filtered):
				control.gui_input.connect(_on_control_gui_input_filtered)
	JuiceLogger.log_info(self, _get_domain_tag(),
			"Auto-connected to Control '%s' on %s" % [
			control.name, TriggerEvent.keys()[trigger_on]],
			debug_enabled)

# =============================================================================
# DOMAIN VIRTUAL HOOK OVERRIDES (Write Coordination)
# =============================================================================

## Returns "Control" for structured log output.
func _get_domain_tag() -> String:
	return "Control"


## Capture target's natural position/rotation/scale/self_modulate.
## All properties are tracked through the Shared Target Ledger.
func _capture_base_values() -> void:
	if _target_node == null or not _target_node is Control:
		return
	var ctrl := _target_node as Control
	JuiceLedger.ensure(ctrl, ["position", "rotation", "scale", "self_modulate"])
	_base_captured = true

## Detect external displacement of the target (Container re-sort, game logic, tweens).
## Updates the Shared Target Ledger baseline so animation deltas ride cleanly.
func _pre_tick() -> void:
	if _target_node == null or not _base_captured:
		return
	var ctrl := _target_node as Control
	JuiceLedger.sync_base_if_moved(ctrl, ["position", "rotation", "scale", "self_modulate"])


## Contribution-tracking write: subtract old contribution, add new contribution.
## Multiple Juice nodes on the same target can write independently without
## overwriting each other — each node only touches its own layer of changes.
## Both transform (additive) and self_modulate (multiplicative) go through the Ledger.
func _post_tick_write() -> void:
	if _target_node == null or not _base_captured:
		return
	var ctrl := _target_node as Control

	# Sum transform deltas from all runtime effects
	var new_pos := Vector2.ZERO
	var new_rot := 0.0
	var new_scale := Vector2.ZERO

	for effect in _runtime_effects:
		if effect == null:
			continue
		var ctrl_effect := effect as JuiceControlTransformEffect
		if ctrl_effect == null:
			continue
		if ctrl_effect._contributes_position:
			new_pos += ctrl_effect._pos_delta
		if ctrl_effect._contributes_rotation:
			new_rot += ctrl_effect._rot_delta
		if ctrl_effect._contributes_scale:
			new_scale += ctrl_effect._scale_delta

	# Register transform deltas into the Target's ledger
	JuiceLedger.register_delta(ctrl, self, "position", new_pos)
	JuiceLedger.register_delta(ctrl, self, "rotation", new_rot)
	JuiceLedger.register_delta(ctrl, self, "scale", new_scale)

	JuiceLogger.log_aggregation("Control", ctrl.name, "scale",
			JuiceLedger.get_base(ctrl, "scale", Vector2.ONE),
			new_scale,
			JuiceLedger.get_total(ctrl, "scale", Vector2.ZERO),
			debug_enabled)

	# Accumulate modulate factors from JuiceControlAppearanceEffect effects.
	# Each effect contributes a multiplicative factor; the Ledger handles
	# base × Πfactors for Color properties automatically.
	var combined_modulate := Color.WHITE
	for effect in _runtime_effects:
		if effect == null:
			continue
		var app_effect := effect as JuiceControlAppearanceEffect
		if app_effect == null or not app_effect._contributes_modulate:
			continue
		combined_modulate.r *= app_effect._modulate_factor.r
		combined_modulate.g *= app_effect._modulate_factor.g
		combined_modulate.b *= app_effect._modulate_factor.b
		combined_modulate.a *= app_effect._modulate_factor.a

	# Register modulate factor into the Ledger — sibling stacking is handled
	# automatically via per-source delta tracking (one entry per JuiceControl node).
	JuiceLedger.register_delta(ctrl, self, "self_modulate", combined_modulate)

	# Flush all properties — transform (additive) + self_modulate (multiplicative)
	JuiceLedger.flush(ctrl, ["position", "rotation", "scale", "self_modulate"])


## Subtract this node's contributions — other nodes' contributions remain.
## Called before effects capture From/To references and before editor save.
func _temporarily_undo_visual() -> void:
	if _target_node == null or not _base_captured:
		return
	var ctrl := _target_node as Control

	# Strip our deltas from the ledger temporarily without destroying it
	JuiceLedger.cleanup_source(ctrl, self, false)

	# Flush remaining sibling contributions — Ledger handles both additive
	# (transform) and multiplicative (self_modulate) correctly.
	JuiceLedger.flush(ctrl, ["position", "rotation", "scale", "self_modulate"])


## Re-add contributions after temporary undo.
func _temporarily_reapply_visual() -> void:
	if _target_node == null or not _base_captured:
		return
	var ctrl := _target_node as Control
	# Re-register and flush all deltas (transform + modulate) through the Ledger
	_post_tick_write()


# =============================================================================
# CONFIGURATION WARNINGS (Override)
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()
	if mode == Mode.STACK:
		var parent := get_parent()
		if parent != null and not parent is Control:
			warnings.append("JuiceControl requires a Control parent in STACK mode. Current parent is '%s' (%s)." % [
				parent.name, parent.get_class()])

	# Check for pivot_offset conflicts between effects
	if recipe != null:
		var pivot_warning := _check_pivot_conflicts()
		if not pivot_warning.is_empty():
			warnings.append(pivot_warning)

	return warnings


# Detect pivot_offset conflicts: Control nodes have a single pivot_offset property,
# so multiple effects with different pivot modes will overwrite each other (last-write wins).
# Returns a warning string if a conflict is found, or empty string if no conflict.
func _check_pivot_conflicts() -> String:
	if recipe == null or recipe.effects.size() < 2:
		return ""

	# Collect pivot configurations from effects that use pivot
	# (effects that only affect position don't touch pivot_offset)
	var pivot_configs: Array[Dictionary] = []
	for effect in recipe.effects:
		if effect == null:
			continue
		if not ("pivot_mode" in effect):
			continue
		var pm: int = effect.pivot_mode
		# INHERIT doesn't write pivot_offset, so it never conflicts
		if pm == 1:  # INHERIT
			continue
		var config := {"mode": pm, "effect": effect.get_class()}
		if pm == 2 and "custom_pivot" in effect:  # CUSTOM
			config["custom_pivot"] = effect.custom_pivot
		pivot_configs.append(config)

	if pivot_configs.size() < 2:
		return ""

	# Check for conflicts: AUTO_CENTER vs CUSTOM, or two CUSTOMs with different values
	var has_auto := false
	var has_custom := false
	var custom_pivots: Array[Vector2] = []
	for cfg in pivot_configs:
		if cfg.mode == 0:  # AUTO_CENTER
			has_auto = true
		elif cfg.mode == 2:  # CUSTOM
			has_custom = true
			if cfg.has("custom_pivot"):
				custom_pivots.append(cfg.custom_pivot)

	var conflict := false
	if has_auto and has_custom:
		conflict = true
	elif custom_pivots.size() >= 2:
		for i in range(1, custom_pivots.size()):
			if not custom_pivots[i].is_equal_approx(custom_pivots[0]):
				conflict = true
				break

	if conflict:
		return "Multiple effects on this node use different pivot modes. " \
			+ "Control nodes have a single pivot_offset — the last effect to start wins. " \
			+ "For independent pivots, use separate JuiceControl nodes on wrapper Controls."

	return ""
