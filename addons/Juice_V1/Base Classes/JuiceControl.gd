## Juice node for [Control] targets (Button, Label, Panel, etc.).
##
## Attach as a child of any [Control]. Assign a [JuiceRecipe] and configure
## triggers to animate position, scale, rotation, appearance, and more.
## Effects stack automatically when multiple Juice nodes share a target.

# ============================================================================
# WHAT: Juice node for Control targets (Button, Label, Panel, etc.).
# WHY: Validates parent is Control, connects Control/Button-specific signals,
#      handles Container-aware external-move detection.
# SYSTEM: Juicing System (addons/Juice_V1/)
# DOES NOT: Implement effects — those are JuiceEffectBase resources in a recipe.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name JuiceControl
extends JuiceBase

# =============================================================================
# CONDITIONAL EXPORT SYSTEM (Override)
# =============================================================================

## Hint string for JuiceControl: all triggers EXCEPT body/area (which are Area-only).
const _CONTROL_TRIGGER_HINT := "On Press:0,On Release:1,On Hover Start:2,On Hover End:3,On Focus:4,On Unfocus:5,On Show:6,On Hide:7,On Ready:8,Manual:9,On Left Click:10,On Right Click:11,On Middle Click:12"

func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "trigger_on":
		property.hint_string = _CONTROL_TRIGGER_HINT
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

# Expected values after our last write — used for external-move detection.
# Difference between current and expected = displacement from other writers
# (sibling Juice nodes, Containers, game logic). INF sentinel = no write yet.
var _expected_position: Vector2 = Vector2.INF
var _expected_rotation: float = INF
var _expected_scale: Vector2 = Vector2.INF

# Sum of all effect deltas currently applied — used by undo/reapply
var _total_pos_contribution: Vector2 = Vector2.ZERO
var _total_rot_contribution: float = 0.0
var _total_scale_contribution: Vector2 = Vector2.ZERO

# Previous frame's non-reactive sibling contribution — for sibling displacement detection
var _prev_nr_pos: Vector2 = Vector2.ZERO
var _prev_nr_rot: float = 0.0
var _prev_nr_scale: Vector2 = Vector2.ZERO

# Whether base values have been captured at least once
var _base_captured: bool = false

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
			if not button.button_down.is_connected(_on_trigger_momentary):
				button.button_down.connect(_on_trigger_momentary)
		TriggerEvent.ON_RELEASE:
			if not button.button_up.is_connected(_on_trigger_momentary):
				button.button_up.connect(_on_trigger_momentary)
		TriggerEvent.ON_HOVER_START:
			if not button.mouse_entered.is_connected(_on_trigger_polarity_on):
				button.mouse_entered.connect(_on_trigger_polarity_on)
			if not button.mouse_exited.is_connected(_on_trigger_polarity_off):
				button.mouse_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_HOVER_END:
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
	if debug_enabled:
		print("[%s] Auto-connected to Button '%s' on %s" % [
			name, button.name, TriggerEvent.keys()[trigger_on]])


func _connect_control_signals(control: Control) -> void:
	match trigger_on:
		TriggerEvent.ON_PRESS:
			if not control.gui_input.is_connected(_on_control_gui_input_press):
				control.gui_input.connect(_on_control_gui_input_press)
		TriggerEvent.ON_RELEASE:
			if not control.gui_input.is_connected(_on_control_gui_input_release):
				control.gui_input.connect(_on_control_gui_input_release)
		TriggerEvent.ON_HOVER_START:
			if not control.mouse_entered.is_connected(_on_trigger_polarity_on):
				control.mouse_entered.connect(_on_trigger_polarity_on)
			if not control.mouse_exited.is_connected(_on_trigger_polarity_off):
				control.mouse_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_HOVER_END:
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
	_base_captured = true
	# Reset tracking — no write has happened yet
	_expected_position = Vector2.INF
	_expected_rotation = INF
	_expected_scale = Vector2.INF
	_total_pos_contribution = Vector2.ZERO
	_total_rot_contribution = 0.0
	_total_scale_contribution = Vector2.ZERO
	_prev_nr_pos = Vector2.ZERO
	_prev_nr_rot = 0.0
	_prev_nr_scale = Vector2.ZERO


## Detect external displacement: did something change the target since our last write?
## With contribution tracking, displacement = current - expected. This captures
## sibling Juice node writes, Container re-sorts, and game logic — anything that
## isn't our own contribution. Spring effects react to this displacement.
func _pre_tick() -> void:
	if _target_node == null or not _base_captured:
		return
	var ctrl := _target_node as Control
	var ext_disp := {}

	# Position: compare current to what we expected after our last write
	if _expected_position != Vector2.INF:
		if not ctrl.position.is_equal_approx(_expected_position):
			var displacement := ctrl.position - _expected_position
			ext_disp["position"] = displacement
			if debug_enabled:
				print("[%s] External displacement (position): %s" % [name, displacement])

	# Rotation
	if _expected_rotation != INF:
		if not is_equal_approx(ctrl.rotation, _expected_rotation):
			ext_disp["rotation"] = ctrl.rotation - _expected_rotation

	# Scale
	if _expected_scale != Vector2.INF:
		if not ctrl.scale.is_equal_approx(_expected_scale):
			ext_disp["scale"] = ctrl.scale - _expected_scale

	# Notify effects of external displacement (for reactive effects like Spring)
	if not ext_disp.is_empty():
		for effect in _runtime_effects:
			if effect != null and effect.is_playing():
				effect._on_external_displacement(ext_disp)


## Compute sibling displacement: compare non-reactive effects' current deltas
## to their previous-frame deltas and notify reactive effects of the change.
func _compute_sibling_displacement() -> void:
	if _runtime_effects.is_empty():
		return

	var nr_pos := Vector2.ZERO
	var nr_rot := 0.0
	var nr_scale := Vector2.ZERO

	for effect in _runtime_effects:
		if effect == null or effect._is_reactive():
			continue
		var ctrl_effect := effect as JuiceControlTransformEffect
		if ctrl_effect == null:
			continue
		if ctrl_effect._contributes_position:
			nr_pos += ctrl_effect._pos_delta
		if ctrl_effect._contributes_rotation:
			nr_rot += ctrl_effect._rot_delta
		if ctrl_effect._contributes_scale:
			nr_scale += ctrl_effect._scale_delta

	var sib_disp := {}
	if not nr_pos.is_equal_approx(_prev_nr_pos):
		sib_disp["position"] = nr_pos - _prev_nr_pos
	if not is_equal_approx(nr_rot, _prev_nr_rot):
		sib_disp["rotation"] = nr_rot - _prev_nr_rot
	if not nr_scale.is_equal_approx(_prev_nr_scale):
		sib_disp["scale"] = nr_scale - _prev_nr_scale

	_prev_nr_pos = nr_pos
	_prev_nr_rot = nr_rot
	_prev_nr_scale = nr_scale

	if not sib_disp.is_empty():
		for effect in _runtime_effects:
			if effect != null and effect._is_reactive() and effect.is_playing():
				effect._on_sibling_displacement(sib_disp)


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


## Subtract this node's contributions — other nodes' contributions remain.
## Called before effects capture From/To references and before editor save.
func _temporarily_undo_visual() -> void:
	if _target_node == null or not _base_captured:
		return
	var ctrl := _target_node as Control
	ctrl.position -= _total_pos_contribution
	ctrl.rotation -= _total_rot_contribution
	ctrl.scale -= _total_scale_contribution


## Re-add contributions after temporary undo.
func _temporarily_reapply_visual() -> void:
	if _target_node == null or not _base_captured:
		return
	var ctrl := _target_node as Control
	ctrl.position += _total_pos_contribution
	ctrl.rotation += _total_rot_contribution
	ctrl.scale += _total_scale_contribution


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
	return warnings
