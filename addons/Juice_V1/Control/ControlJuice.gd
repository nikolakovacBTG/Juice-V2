## ControlJuice.gd
## ============================================================================
## WHAT: Juice node for Control targets (Button, Label, Panel, etc.).
## WHY: Validates parent is Control, connects Control/Button-specific signals,
##      handles Container-aware external-move detection.
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Implement effects — those are JuiceEffectBase resources in a recipe.
## ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name ControlJuice
extends JuiceBase

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()


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

## Connect Control/Button-specific signals based on trigger_on.
func _auto_connect_domain_signals() -> void:
	if _target_node == null:
		return

	# Button is a subclass of Control with richer signal set
	if _target_node is BaseButton:
		_connect_button_signals(_target_node as BaseButton)
		return

	# Generic Control signals
	if _target_node is Control:
		_connect_control_signals(_target_node as Control)


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
	if debug_enabled:
		print("[%s] Auto-connected to Control '%s' on %s" % [
			name, control.name, TriggerEvent.keys()[trigger_on]])

# =============================================================================
# CONFIGURATION WARNINGS (Override)
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()
	if mode == Mode.STACK:
		var parent := get_parent()
		if parent != null and not parent is Control:
			warnings.append("ControlJuice requires a Control parent in STACK mode. Current parent is '%s' (%s)." % [
				parent.name, parent.get_class()])
	return warnings
