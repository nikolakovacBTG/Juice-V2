## JuiceControl.gd
## ============================================================================
## WHAT: Juice node for Control targets (Button, Label, Panel, etc.).
## WHY: Validates parent is Control, connects Control/Button-specific signals,
##      handles Container-aware external-move detection.
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Implement effects — those are JuiceEffectBase resources in a recipe.
## ============================================================================

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

# Natural state — captured at _ready, updated on external-move detection
var _base_position: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _base_scale: Vector2 = Vector2.ONE

# Last values written by this node — used for external-move detection.
# INF sentinel means "no write yet" so the first frame doesn't false-detect.
var _last_written_position: Vector2 = Vector2.INF
var _last_written_rotation: float = INF
var _last_written_scale: Vector2 = Vector2.INF

# Sum of all effect deltas currently applied — used by undo/reapply
var _total_pos_contribution: Vector2 = Vector2.ZERO
var _total_rot_contribution: float = 0.0
var _total_scale_contribution: Vector2 = Vector2.ZERO

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
func _capture_base_values() -> void:
	if _target_node == null or not _target_node is Control:
		return
	var ctrl := _target_node as Control
	_base_position = ctrl.position
	_base_rotation = ctrl.rotation
	_base_scale = ctrl.scale
	_base_captured = true
	# Reset tracking — no write has happened yet
	_last_written_position = Vector2.INF
	_last_written_rotation = INF
	_last_written_scale = Vector2.INF
	_total_pos_contribution = Vector2.ZERO
	_total_rot_contribution = 0.0
	_total_scale_contribution = Vector2.ZERO


## Detect external moves: did something else change the target since our last write?
## If so, update base values to absorb the external change.
func _pre_tick() -> void:
	if _target_node == null or not _base_captured:
		return
	var ctrl := _target_node as Control

	# Position: compare current to what we last wrote
	if _last_written_position != Vector2.INF:
		if not ctrl.position.is_equal_approx(_last_written_position):
			# External move detected — absorb into base
			var external_delta := ctrl.position - _last_written_position
			_base_position += external_delta
			if debug_enabled:
				print("[%s] External position move detected: %s" % [name, external_delta])

	# Rotation
	if _last_written_rotation != INF:
		if not is_equal_approx(ctrl.rotation, _last_written_rotation):
			var external_delta := ctrl.rotation - _last_written_rotation
			_base_rotation += external_delta

	# Scale
	if _last_written_scale != Vector2.INF:
		if not ctrl.scale.is_equal_approx(_last_written_scale):
			var external_delta := ctrl.scale - _last_written_scale
			_base_scale += external_delta


## Aggregate all effect deltas and write to target ONCE per frame.
func _post_tick_write() -> void:
	if _target_node == null or not _base_captured:
		return
	var ctrl := _target_node as Control

	# Sum deltas from all runtime effects
	var total_pos := Vector2.ZERO
	var total_rot := 0.0
	var total_scale := Vector2.ZERO

	for effect in _runtime_effects:
		if effect == null:
			continue
		# Effects must be JuiceControlEffectBase to have typed deltas
		var ctrl_effect := effect as JuiceControlEffectBase
		if ctrl_effect == null:
			continue
		if ctrl_effect._contributes_position:
			total_pos += ctrl_effect._pos_delta
		if ctrl_effect._contributes_rotation:
			total_rot += ctrl_effect._rot_delta
		if ctrl_effect._contributes_scale:
			total_scale += ctrl_effect._scale_delta

	# Write once: base + sum(deltas)
	ctrl.position = _base_position + total_pos
	ctrl.rotation = _base_rotation + total_rot
	ctrl.scale = _base_scale + total_scale

	# Track what we wrote (for external-move detection next frame)
	_last_written_position = ctrl.position
	_last_written_rotation = ctrl.rotation
	_last_written_scale = ctrl.scale

	# Track total contribution (for undo/reapply)
	_total_pos_contribution = total_pos
	_total_rot_contribution = total_rot
	_total_scale_contribution = total_scale


## Subtract all contributions — target returns to natural state.
## Called before effects capture From/To and before editor save.
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
