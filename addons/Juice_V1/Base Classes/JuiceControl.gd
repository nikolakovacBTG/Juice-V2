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

# Phase B: Per-node contribution tracking for sibling stacking (Modulate)
# Transform properties use the shared Metadata Ledger.
var _own_modulate_contribution: Color = Color.WHITE

# Whether base values have been captured at least once
var _base_captured: bool = false

# Expected values after our last write — for external-move detection (pre-tick).
# Kept for modulate, as transform uses the ledger.
var _expected_modulate: Color = Color.WHITE

# Modulate base — captured at _capture_base_values for appearance accumulation.
# JuiceControlAppearanceEffect effects contribute _modulate_factor multiplicatively;
# the domain node writes target.modulate = _base_modulate * combined_factor once per frame.
var _base_modulate: Color = Color.WHITE
var _has_modulate_base: bool = false

# Whether the target is inside a Container. In V1's write-every-frame model,
# _post_tick_write() inherently beats Container re-sorts each frame.
# This flag is kept for potential future Container-specific edge cases.
var _in_container: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()
	# Detect Container parent for hold pattern
	if _target_node != null and _target_node is Control:
		var ctrl := _target_node as Control
		_in_container = ctrl.get_parent() is Container


func _exit_tree() -> void:
	super._exit_tree()
	if _target_node != null and is_instance_valid(_target_node):
		_ledger_cleanup_source(_target_node, self)

# =============================================================================
# TARGET RESOLUTION (Override)
# =============================================================================

## Resolve target and validate it's a Control node.
func _resolve_target() -> Node:
	if mode == Mode.STACK:
		var parent := get_parent()
		if parent is Control:
			return parent
		if parent != null and debug_enabled:
			push_warning("[%s] Parent '%s' is not a Control node" % [name, parent.name])
		return null
	return null  # SEQUENCER Phase 5

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
	if debug_enabled:
		print("[%s] Auto-connected to Button '%s' on %s" % [
			name, button.name, TriggerEvent.keys()[trigger_on]])


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
	if debug_enabled:
		print("[%s] Auto-connected to Control '%s' on %s" % [
			name, control.name, TriggerEvent.keys()[trigger_on]])

# =============================================================================
# DOMAIN VIRTUAL HOOK OVERRIDES (Write Coordination)
# =============================================================================

## Capture target's natural position/rotation/scale.
## Transforms use the Shared Target Ledger; Modulate uses the dedicated META_KEY.
func _capture_base_values() -> void:
	if _target_node == null or not _target_node is Control:
		return
	var ctrl := _target_node as Control
	
	_ledger_ensure_initialized(ctrl, ["position", "rotation", "scale"])
	
	_base_modulate = ctrl.modulate
	_has_modulate_base = true
	_base_captured = true

## Detect external displacement of the target (Container re-sort, game logic, tweens).
## Updates the Shared Target Ledger baseline so animation deltas ride cleanly.
func _pre_tick() -> void:
	if _target_node == null or not _base_captured:
		return
	var ctrl := _target_node as Control
	
	_ledger_update_external_displacement(ctrl, ["position", "rotation", "scale"])


## Contribution-tracking write: subtract old contribution, add new contribution.
## Multiple Juice nodes on the same target can write independently without
## overwriting each other — each node only touches its own layer of changes.
func _post_tick_write() -> void:
	if _target_node == null or not _base_captured:
		return
	var ctrl := _target_node as Control

	# Sum deltas from all runtime effects
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

	# Register our deltas into the Target's ledger
	_ledger_set_delta(ctrl, self, "position", new_pos)
	_ledger_set_delta(ctrl, self, "rotation", new_rot)
	_ledger_set_delta(ctrl, self, "scale", new_scale)

	# Fetch the unified natural base and the total sums of all Juice nodes modifying this target
	var base_pos: Vector2 = _ledger_get_base_value(ctrl, "position", ctrl.position)
	var base_rot: float = _ledger_get_base_value(ctrl, "rotation", ctrl.rotation)
	var base_scale: Vector2 = _ledger_get_base_value(ctrl, "scale", ctrl.scale)

	var total_pos: Vector2 = _ledger_get_total(ctrl, "position", Vector2.ZERO)
	var total_rot: float = _ledger_get_total(ctrl, "rotation", 0.0)
	var total_scale: Vector2 = _ledger_get_total(ctrl, "scale", Vector2.ZERO)

	# Absolute write — natively beats container eager snapping without drifting
	ctrl.position = base_pos + total_pos
	ctrl.rotation = base_rot + total_rot
	ctrl.scale = base_scale + total_scale
	
	if debug_enabled:
		print("[%s] POST_TICK base_pos=%s, new_pos_delta=%s, total_pos_ledger=%s, ctrl_now=%s" % [name, base_pos, new_pos, total_pos, ctrl.position])

	# Appearance: accumulate modulate factors from JuiceControlAppearanceEffect effects.
	# Only write modulate when at least one appearance effect has a non-identity factor.
	var combined_modulate := Color.WHITE
	var has_appearance := false
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
		has_appearance = true

	# Phase B: Sibling stacking with metadata-based natural base capture
	# JuiceControl writes to self_modulate, so base capture uses self_modulate.
	const META_KEY := &"juice_modulate_natural"
	var base_color: Color = ctrl.self_modulate
	if not ctrl.has_meta(META_KEY):
		# First JuiceControl node — capture natural self_modulate and store in metadata
		ctrl.set_meta(META_KEY, ctrl.self_modulate)
	else:
		# Subsequent JuiceControl nodes — read natural base from metadata
		base_color = ctrl.get_meta(META_KEY)

	# Scan all sibling JuiceControl nodes on the same target, multiply contributions.
	# In STACK mode, Juice nodes are children of the target — scan target's children.
	var final_factor := Color.WHITE
	for child in ctrl.get_children():
		var j := child as JuiceControl
		if j == null or j == self:
			continue
		var sibling_contrib: Color = Color.WHITE
		if j._own_modulate_contribution != Color.WHITE:
			sibling_contrib = j._own_modulate_contribution
		final_factor.r *= sibling_contrib.r
		final_factor.g *= sibling_contrib.g
		final_factor.b *= sibling_contrib.b
		final_factor.a *= sibling_contrib.a

	# Write once: base * own_contribution * product of all sibling contributions
	ctrl.self_modulate = Color(
		base_color.r * combined_modulate.r * final_factor.r,
		base_color.g * combined_modulate.g * final_factor.g,
		base_color.b * combined_modulate.b * final_factor.b,
		base_color.a * combined_modulate.a * final_factor.a)

	# Update own contribution tracking
	if has_appearance:
		_own_modulate_contribution = combined_modulate
	else:
		_own_modulate_contribution = Color.WHITE

	# Check if all siblings are at identity (no active effects)
	var all_siblings_idle := true
	for child in ctrl.get_children():
		var j := child as JuiceControl
		if j == null or j == self:
			continue
		if j._own_modulate_contribution != Color.WHITE:
			all_siblings_idle = false
			break

	# If all siblings idle and we're idle, remove metadata and restore natural state
	if all_siblings_idle and not has_appearance and ctrl.has_meta(META_KEY):
		ctrl.remove_meta(META_KEY)
		ctrl.self_modulate = base_color


## Subtract this node's contributions — other nodes' contributions remain.
## Called before effects capture From/To references and before editor save.
func _temporarily_undo_visual() -> void:
	if _target_node == null or not _base_captured:
		return
	var ctrl := _target_node as Control
	
	# Strip our deltas from the ledger temporarily without destroying it
	_ledger_cleanup_source(ctrl, self, false)
	
	# Apply absolute baseline position + sibling remaining deltas
	ctrl.position = _ledger_get_base_value(ctrl, "position", ctrl.position) + _ledger_get_total(ctrl, "position", Vector2.ZERO)
	ctrl.rotation = _ledger_get_base_value(ctrl, "rotation", ctrl.rotation) + _ledger_get_total(ctrl, "rotation", 0.0)
	ctrl.scale = _ledger_get_base_value(ctrl, "scale", ctrl.scale) + _ledger_get_total(ctrl, "scale", Vector2.ZERO)

	# Restore self_modulate to natural so Appearance effects see the true From state
	# when _on_animate_start captures references (e.g. during animate_out after a fade-in).
	const META_KEY := &"juice_modulate_natural"
	if ctrl.has_meta(META_KEY):
		ctrl.self_modulate = ctrl.get_meta(META_KEY)
	# Phase B: Set own contribution to identity so sibling rescan excludes us
	_own_modulate_contribution = Color.WHITE


## Re-add contributions after temporary undo.
func _temporarily_reapply_visual() -> void:
	if _target_node == null or not _base_captured:
		return
	var ctrl := _target_node as Control
	# Re-apply transform deltas by flushing a fresh post-tick write
	# This restores our deltas to the ledger and recalculates absolute bounds.
	# Re-apply modulate by flushing a fresh post-tick write
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
