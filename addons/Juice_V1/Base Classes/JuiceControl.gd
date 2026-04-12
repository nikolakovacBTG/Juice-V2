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

# Natural state — captured once at _ready. Read-only reference after capture;
# contribution tracking does not modify these.
var _base_position: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _base_scale: Vector2 = Vector2.ONE

# Sum of all effect deltas currently applied — used by undo/reapply
var _total_pos_contribution: Vector2 = Vector2.ZERO
var _total_rot_contribution: float = 0.0
var _total_scale_contribution: Vector2 = Vector2.ZERO

# Whether base values have been captured at least once
var _base_captured: bool = false

# Expected values after our last write — for external-move detection (pre-tick).
# If the actual value differs from expected next frame, something external moved
# the target (Container re-sort, game logic, tween, etc.) and we update _base_*.
var _expected_position: Vector2 = Vector2.INF
var _expected_rotation: float = INF
var _expected_scale: Vector2 = Vector2.INF

# Modulate base — captured at _capture_base_values for appearance accumulation.
# JuiceControlAppearanceEffect effects contribute _modulate_factor multiplicatively;
# the domain node writes target.modulate = _base_modulate * combined_factor once per frame.
var _base_modulate: Color = Color.WHITE
var _has_modulate_base: bool = false

# Whether the target is inside a Container. In V1's write-every-frame model,
# _post_tick_write() inherently beats Container re-sorts each frame.
# This flag is kept for potential future Container-specific edge cases.
var _in_container: bool = false

# Phase B: Per-node contribution tracking for sibling stacking
var _own_modulate_contribution: Color = Color.WHITE

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
## Base values are a read-only reference; contribution tracking handles writes.
func _capture_base_values() -> void:
	if _target_node == null or not _target_node is Control:
		return
	var ctrl := _target_node as Control
	_base_position = ctrl.position
	_base_rotation = ctrl.rotation
	_base_scale = ctrl.scale
	_base_modulate = ctrl.modulate
	_has_modulate_base = true
	_base_captured = true
	# Reset contribution tracking
	_total_pos_contribution = Vector2.ZERO
	_total_rot_contribution = 0.0
	_total_scale_contribution = Vector2.ZERO
	# Initialise expected values so pre-tick can detect external moves
	_expected_position = ctrl.position
	_expected_rotation = ctrl.rotation
	_expected_scale = ctrl.scale
	if debug_enabled:
		print("[%s] JuiceControl._capture_base_values: ctrl.pos=%s ctrl.rot=%.2f ctrl.scale=%s" % [
			name, ctrl.position, ctrl.rotation, ctrl.scale])


## Detect external displacement of the target (Container re-sort, game logic, tweens).
## Runs once per frame, before effects tick. When displacement is detected,
## updates _base_* so delta computations use the correct natural state.
func _pre_tick() -> void:
	if _target_node == null or not _base_captured:
		return
	var ctrl := _target_node as Control
	var any_displaced := false

	# Position
	if _expected_position != Vector2.INF:
		if not ctrl.position.is_equal_approx(_expected_position):
			var displacement := ctrl.position - _expected_position
			_base_position += displacement
			_expected_position = ctrl.position
			any_displaced = true
			if debug_enabled:
				print("[%s] External displacement (position): %s → new base: %s" % [
					name, displacement, _base_position])

	# Rotation
	if _expected_rotation != INF:
		if not is_equal_approx(ctrl.rotation, _expected_rotation):
			var displacement := ctrl.rotation - _expected_rotation
			_base_rotation += displacement
			_expected_rotation = ctrl.rotation
			any_displaced = true

	# Scale
	if _expected_scale != Vector2.INF:
		if not ctrl.scale.is_equal_approx(_expected_scale):
			var displacement := ctrl.scale - _expected_scale
			_base_scale += displacement
			_expected_scale = ctrl.scale
			any_displaced = true

	# Invalidate effect base caches so they re-capture on next animation start
	if any_displaced:
		for effect in _runtime_effects:
			if effect != null:
				effect._invalidate_base_cache()


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

	if debug_enabled:
		print("[FROMTO_DBG] %s._post_tick_write: ctrl.pos_BEFORE=%s old_contrib=%s new_delta=%s => result=%s" % [
			name, ctrl.position, _total_pos_contribution, new_pos,
			ctrl.position - _total_pos_contribution + new_pos])

	# Contribution tracking: subtract what we added last frame, add what we want now
	ctrl.position = ctrl.position - _total_pos_contribution + new_pos
	ctrl.rotation = ctrl.rotation - _total_rot_contribution + new_rot
	ctrl.scale = ctrl.scale - _total_scale_contribution + new_scale

	# Track expected values (for external-displacement detection next frame)
	_expected_position = ctrl.position
	_expected_rotation = ctrl.rotation
	_expected_scale = ctrl.scale

	# Update tracked contribution (for undo/reapply and next frame's subtraction)
	_total_pos_contribution = new_pos
	_total_rot_contribution = new_rot
	_total_scale_contribution = new_scale

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
	if debug_enabled:
		print("[FROMTO_DBG] %s._temporarily_undo_visual: ctrl.pos_BEFORE=%s _total_pos_contrib=%s => undone_pos=%s" % [
			name, ctrl.position, _total_pos_contribution,
			ctrl.position - _total_pos_contribution])
	ctrl.position -= _total_pos_contribution
	ctrl.rotation -= _total_rot_contribution
	ctrl.scale -= _total_scale_contribution
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
	if debug_enabled:
		print("[FROMTO_DBG] %s._temporarily_reapply_visual: ctrl.pos_BEFORE=%s _total_pos_contrib=%s => reapplied_pos=%s" % [
			name, ctrl.position, _total_pos_contribution,
			ctrl.position + _total_pos_contribution])
	ctrl.position += _total_pos_contribution
	ctrl.rotation += _total_rot_contribution
	ctrl.scale += _total_scale_contribution
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
