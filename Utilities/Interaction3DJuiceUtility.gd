## Convenience upgrade for [Area3D] that adds structural and gating value for interactive 3D game objects.
##
## Auto-creates collision shapes, manages trigger zone gating, and relays custom input actions
## as dynamically named signals.

# ============================================================================
# WHAT: Convenience upgrade for Area3D that adds structural and gating value
#       for interactive 3D game objects.
# WHY: Area3D already provides all needed native signals (mouse_entered,
#       mouse_exited, input_event, body_entered, etc.). This utility adds
#       value ON TOP of that: auto-shape creation, zone-gated interaction,
#       and input action relay.
# SYSTEM: Juice Utility (addons/Juice_V2/Utilities/)
#
# DOES NOT:
# - Wrap or replace native Area3D signals — they flow through unchanged
# - Provide continuous 0-1 progress (see SoftTrigger3DJuiceUtility)
# - Implement game-specific interaction logic (radial menus, dialogue, etc.)
# - Handle visual effects directly (JuiceBase nodes handle effects)
#
# CONNECTIONS:
# - JuiceBase children/siblings: auto-connect to native Area3D signals
#   via their built-in trigger wiring. No wrapper signals needed.
# - Game scripts: connect to dynamic action signals (e.g., "right_click",
#   "interact") in the Node tab's signal list.
# - Child trigger zone (Area3D): auto-created when INTERACTABLE mode needs
#   zone gating. In TRIGGER_ZONE mode, root Area3D handles detection.
#
# USAGE:
# 1. Add as sibling of a visual Node3D (MeshInstance3D, etc.)
# 2. Add JuiceBase children — they auto-connect to native signals
# 3. Pick mode: INTERACTABLE or TRIGGER_ZONE
# 4. Optionally add input action entries for named signal relay
# 5. Optionally enable check_presence_in_trigger_zone for gated interaction
# ================================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceUtilityArea3D.svg")
class_name Interaction3DJuiceUtility
extends Area3D


# =============================================================================
# ENUMS
# =============================================================================

enum Mode {
	TRIGGER_ZONE,   ## Proximity detection only
	INTERACTABLE,   ## Mouse interaction + optional input action relay + zone gating
}

enum InputActionPreset {
	CUSTOM,        ## User-defined InputMap action name
	LEFT_CLICK,    ## Left mouse button → emits "left_click"
	RIGHT_CLICK,   ## Right mouse button → emits "right_click"
	MIDDLE_CLICK,  ## Middle mouse button → emits "middle_click"
}

enum InputPriority {
	WORLD,   ## _unhandled_input() — GUI blocks world interaction
	ALWAYS,  ## _input() — works even when GUI consumes input
}


# =============================================================================
# CONFIGURATION (backing variables — shown via _get_property_list)
# =============================================================================

## Operating mode: Trigger Zone detects bodies/areas entering a region; Interactable responds to clicks and input actions.
var mode: int = Mode.INTERACTABLE:
	set(value):
		mode = value
		notify_property_list_changed()
		if Engine.is_editor_hint() and is_inside_tree():
			update_configuration_warnings()
			_ensure_shapes()

## Number of input action entries. Each entry maps a click preset or custom InputMap action to a dynamic signal.
var action_count: int = 0:
	set(value):
		var old_count := action_count
		action_count = maxi(0, value)
		while _action_presets.size() < action_count:
			_action_presets.append(InputActionPreset.CUSTOM)
			_action_names.append(&"")
		while _action_presets.size() > action_count:
			_action_presets.pop_back()
			_action_names.pop_back()
		notify_property_list_changed()
		if old_count != action_count:
			_sync_user_signals()
		if Engine.is_editor_hint() and is_inside_tree():
			update_configuration_warnings()

var _action_presets: Array[int] = []
var _action_names: Array[StringName] = []
## Whether custom InputMap actions use World priority (GUI blocks input) or Always (fires behind UI).
var input_priority: int = InputPriority.WORLD

## When enabled, clicks and input actions only fire while a body/area is inside the child trigger zone.
var check_presence_in_trigger_zone: bool = false:
	set(value):
		check_presence_in_trigger_zone = value
		notify_property_list_changed()
		if Engine.is_editor_hint() and is_inside_tree():
			update_configuration_warnings()
			_ensure_shapes()

## Detect PhysicsBody3D nodes entering and exiting the trigger zone.
var detect_bodies: bool = true
## Detect other Area3D nodes entering and exiting the trigger zone.
var detect_areas: bool = true
## Only detect nodes belonging to this group. Leave empty to detect all.
var filter_group: String = ""
## Emit signals when a body/area enters the trigger zone.
var trigger_on_enter: bool = true
## Emit signals when the last body/area exits the trigger zone.
var trigger_on_exit: bool = true
## When enabled, the interaction fires only once until manually reset via reset().
var one_shot: bool = false
## Enable debug logging for interaction events, zone gating, and signal relay.
var debug_enabled: bool = false


# =============================================================================
# INTERNAL STATE (transient, not saved)
# =============================================================================

var _bodies_inside: int = 0
var _zone_active: bool = false
var _has_fired: bool = false
var _trigger_zone: Area3D = null
var _registered_signals: Array[StringName] = []
const _TRIGGER_ZONE_META := &"_is_interaction_trigger_zone"


# =============================================================================
# INSPECTOR: _get_property_list / _set / _get
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	props.append(_group("Interaction Mode"))
	props.append({"name": "mode", "type": TYPE_INT, "usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM, "hint_string": "Trigger Zone,Interactable"})

	if mode == Mode.INTERACTABLE:
		props.append(_group("Input Actions"))
		props.append({"name": "action_count", "type": TYPE_INT, "usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,10,1"})
		for i in range(action_count):
			props.append({"name": "action_%d_preset" % i, "type": TYPE_INT, "usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM, "hint_string": "Custom,Left Click,Right Click,Middle Click"})
			if i < _action_presets.size() and _action_presets[i] == InputActionPreset.CUSTOM:
				props.append({"name": "action_%d_name" % i, "type": TYPE_STRING_NAME, "usage": PROPERTY_USAGE_DEFAULT})

		var has_custom := false
		for i in range(mini(action_count, _action_presets.size())):
			if _action_presets[i] == InputActionPreset.CUSTOM:
				has_custom = true
				break
		if has_custom:
			props.append({"name": "input_priority", "type": TYPE_INT, "usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM, "hint_string": "World (GUI blocks),Always"})

		props.append({"name": "check_presence_in_trigger_zone", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})

	var show_tz := (mode == Mode.TRIGGER_ZONE) or (mode == Mode.INTERACTABLE and check_presence_in_trigger_zone)
	if show_tz:
		props.append(_group("Trigger Zone"))
		props.append({"name": "detect_bodies", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "detect_areas", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "filter_group", "type": TYPE_STRING, "usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "trigger_on_enter", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "trigger_on_exit", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "one_shot", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})

	props.append(_group("Debug"))
	props.append({"name": "debug_enabled", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})
	return props


func _group(group_name: String) -> Dictionary:
	return {"name": group_name, "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP}


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"mode": mode = value; return true
		&"action_count": action_count = value; return true
		&"input_priority": input_priority = value; return true
		&"check_presence_in_trigger_zone": check_presence_in_trigger_zone = value; return true
		&"detect_bodies": detect_bodies = value; return true
		&"detect_areas": detect_areas = value; return true
		&"filter_group": filter_group = value; return true
		&"trigger_on_enter": trigger_on_enter = value; return true
		&"trigger_on_exit": trigger_on_exit = value; return true
		&"one_shot": one_shot = value; return true
		&"debug_enabled": debug_enabled = value; return true
		&"collision_layer", &"collision_mask":
			set(property, value)
			update_configuration_warnings()
			return true

	var prop_str := String(property)
	if prop_str.begins_with("action_") and prop_str.contains("_preset"):
		var idx := prop_str.get_slice("_", 1).to_int()
		if idx >= 0 and idx < _action_presets.size():
			var old_val := _action_presets[idx]
			_action_presets[idx] = value
			if old_val != value:
				notify_property_list_changed()
				_sync_user_signals()
			return true
	elif prop_str.begins_with("action_") and prop_str.contains("_name"):
		var idx := prop_str.get_slice("_", 1).to_int()
		if idx >= 0 and idx < _action_names.size():
			var old_name := _action_names[idx]
			_action_names[idx] = value
			if old_name != value:
				_sync_user_signals()
			return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"mode": return mode
		&"action_count": return action_count
		&"input_priority": return input_priority
		&"check_presence_in_trigger_zone": return check_presence_in_trigger_zone
		&"detect_bodies": return detect_bodies
		&"detect_areas": return detect_areas
		&"filter_group": return filter_group
		&"trigger_on_enter": return trigger_on_enter
		&"trigger_on_exit": return trigger_on_exit
		&"one_shot": return one_shot
		&"debug_enabled": return debug_enabled

	var prop_str := String(property)
	if prop_str.begins_with("action_") and prop_str.contains("_preset"):
		var idx := prop_str.get_slice("_", 1).to_int()
		if idx >= 0 and idx < _action_presets.size():
			return _action_presets[idx]
	elif prop_str.begins_with("action_") and prop_str.contains("_name"):
		var idx := prop_str.get_slice("_", 1).to_int()
		if idx >= 0 and idx < _action_names.size():
			return _action_names[idx]
	return null


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	var has_root_shape := false
	for child in get_children():
		if child is CollisionShape3D and child.shape != null:
			has_root_shape = true
			break

	if mode == Mode.INTERACTABLE:
		if not has_root_shape:
			warnings.append("No CollisionShape3D with a shape found. Mouse interaction requires a collision shape.")
		for i in range(mini(action_count, _action_presets.size())):
			if _action_presets[i] == InputActionPreset.CUSTOM:
				if i < _action_names.size() and _action_names[i].is_empty():
					warnings.append("Action entry %d: CUSTOM preset requires an InputMap action name." % i)
		if check_presence_in_trigger_zone:
			var tz := _find_trigger_zone()
			if tz == null:
				warnings.append("No trigger zone child found. One will be auto-created, or add an Area3D child manually.")
			else:
				var has_zone_shape := false
				for child in tz.get_children():
					if child is CollisionShape3D and child.shape != null:
						has_zone_shape = true
						break
				if not has_zone_shape:
					warnings.append("Trigger zone has no CollisionShape3D with a shape.")
				if (collision_layer & tz.collision_mask) != 0 or (tz.collision_layer & collision_mask) != 0:
					warnings.append("This Area3D and its trigger zone share collision layers/masks. They may detect each other.")
	elif mode == Mode.TRIGGER_ZONE:
		if not has_root_shape:
			warnings.append("No CollisionShape3D with a shape found. Trigger zone requires a collision shape.")

	var has_juice := false
	for child in get_children():
		if child is JuiceBase:
			has_juice = true
			break
		var child_script := child.get_script()
		if child_script and child_script.get_global_name() and child_script.get_global_name().ends_with("JuiceUtility"):
			has_juice = true
			break
	if not has_juice and get_parent():
		for sibling in get_parent().get_children():
			if sibling != self and sibling is JuiceBase:
				has_juice = true
				break
			var sibling_script := sibling.get_script()
			if sibling_script and sibling_script.get_global_name() and sibling_script.get_global_name().ends_with("JuiceUtility"):
				has_juice = true
				break
	if not has_juice:
		warnings.append("No JuiceBase (JuiceControl/Juice2D/Juice3D) children or siblings found.")

	return warnings


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_sync_user_signals()

	if Engine.is_editor_hint():
		_ensure_shapes()
		return

	if mode == Mode.TRIGGER_ZONE:
		input_ray_pickable = false
		monitoring = true
		_wire_zone_signals(self)
	elif mode == Mode.INTERACTABLE:
		input_ray_pickable = true
		monitoring = false

		if check_presence_in_trigger_zone:
			# Start disabled — zone entry re-enables picking and input
			input_ray_pickable = false
			_trigger_zone = _find_trigger_zone()
			if _trigger_zone:
				_wire_zone_signals(_trigger_zone)
			elif debug_enabled:
				JuiceLogger.warn(self, "Interaction3D",
						"zone gating enabled but no child trigger zone found",
						debug_enabled)

		var has_custom := _has_custom_action_entries()
		if has_custom:
			if check_presence_in_trigger_zone:
				set_process_unhandled_input(false)
				set_process_input(false)
			else:
				_enable_input_processing(true)
		else:
			set_process_unhandled_input(false)
			set_process_input(false)

	JuiceLogger.log_info(self, "Interaction3D",
			"ready: mode=%s actions=%d" % [
			Mode.keys()[mode], action_count],
			debug_enabled)


# =============================================================================
# SHAPE AUTO-CREATION (@tool, runs in editor)
# =============================================================================

func _ensure_shapes() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	var scene_root := get_tree().edited_scene_root if is_inside_tree() else null
	if scene_root == null:
		return

	var has_root_shape := false
	for child in get_children():
		if child is CollisionShape3D:
			has_root_shape = true
			break
	if not has_root_shape:
		var shape_node := CollisionShape3D.new()
		shape_node.name = "Juice_CollisionShape3D"
		var sphere := SphereShape3D.new()
		sphere.radius = 3.0 if mode == Mode.TRIGGER_ZONE else 1.0
		shape_node.shape = sphere
		add_child(shape_node)
		shape_node.owner = scene_root

	var needs_child_zone := (mode == Mode.INTERACTABLE and check_presence_in_trigger_zone)
	if needs_child_zone:
		var tz := _find_trigger_zone()
		if tz == null:
			tz = Area3D.new()
			tz.name = "TriggerZone"
			tz.set_meta(_TRIGGER_ZONE_META, true)
			tz.input_ray_pickable = false
			tz.monitoring = true
			tz.monitorable = false
			add_child(tz)
			tz.owner = scene_root
			var tz_shape := CollisionShape3D.new()
			tz_shape.name = "Juice_TriggerZoneShape3D"
			var sphere := SphereShape3D.new()
			sphere.radius = 3.0
			tz_shape.shape = sphere
			tz.add_child(tz_shape)
			tz_shape.owner = scene_root
	else:
		var tz := _find_trigger_zone()
		if tz != null:
			remove_child(tz)
			tz.queue_free()

	update_configuration_warnings()


func _find_trigger_zone() -> Area3D:
	for child in get_children():
		if child is Area3D and child.has_meta(_TRIGGER_ZONE_META):
			return child
	return null


# =============================================================================
# INPUT HANDLING: CLICK PRESETS (via _input_event on this Area3D)
# =============================================================================

# Godot physics picking callback — fires when the mouse interacts with this
# Area3D's collision shape. Checks configured click presets and emits their
# named signals when matched.
func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if Engine.is_editor_hint():
		return
	if mode != Mode.INTERACTABLE:
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if check_presence_in_trigger_zone and not _zone_active:
		return
	if one_shot and _has_fired:
		return

	for i in range(mini(action_count, _action_presets.size())):
		var preset := _action_presets[i]
		var sig_name := _get_signal_name_for_entry(i)
		if sig_name.is_empty():
			continue
		var matched := false
		match preset:
			InputActionPreset.LEFT_CLICK:
				matched = (mb.button_index == MOUSE_BUTTON_LEFT)
			InputActionPreset.RIGHT_CLICK:
				matched = (mb.button_index == MOUSE_BUTTON_RIGHT)
			InputActionPreset.MIDDLE_CLICK:
				matched = (mb.button_index == MOUSE_BUTTON_MIDDLE)
		if matched:
			if one_shot:
				_has_fired = true
			JuiceLogger.log_info(self, "Interaction3D",
					"click preset → emit '%s'" % sig_name,
					debug_enabled)
			emit_signal(sig_name)


# =============================================================================
# INPUT HANDLING: CUSTOM ACTIONS (keyboard/gamepad via InputMap)
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or mode != Mode.INTERACTABLE:
		return
	if input_priority != InputPriority.WORLD:
		return
	_handle_custom_actions(event)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or mode != Mode.INTERACTABLE:
		return
	if input_priority != InputPriority.ALWAYS:
		return
	_handle_custom_actions(event)


func _handle_custom_actions(event: InputEvent) -> void:
	if check_presence_in_trigger_zone and not _zone_active:
		return
	if one_shot and _has_fired:
		return
	for i in range(mini(action_count, _action_presets.size())):
		if _action_presets[i] != InputActionPreset.CUSTOM:
			continue
		if i >= _action_names.size():
			continue
		var action_name := _action_names[i]
		if action_name.is_empty():
			continue
		if event.is_action_pressed(action_name):
			if one_shot:
				_has_fired = true
			JuiceLogger.log_info(self, "Interaction3D",
					"custom action '%s' triggered" % action_name,
					debug_enabled)
			emit_signal(action_name)


func _enable_input_processing(enabled: bool) -> void:
	if input_priority == InputPriority.WORLD:
		set_process_unhandled_input(enabled)
		set_process_input(false)
	else:
		set_process_input(enabled)
		set_process_unhandled_input(false)


func _has_custom_action_entries() -> bool:
	for i in range(mini(action_count, _action_presets.size())):
		if _action_presets[i] == InputActionPreset.CUSTOM:
			return true
	return false


# =============================================================================
# TRIGGER ZONE HANDLING
# =============================================================================

func _wire_zone_signals(zone_source: Area3D) -> void:
	zone_source.monitoring = true
	if not zone_source.body_entered.is_connected(_on_zone_body_entered):
		zone_source.body_entered.connect(_on_zone_body_entered)
	if not zone_source.body_exited.is_connected(_on_zone_body_exited):
		zone_source.body_exited.connect(_on_zone_body_exited)
	if not zone_source.area_entered.is_connected(_on_zone_area_entered):
		zone_source.area_entered.connect(_on_zone_area_entered)
	if not zone_source.area_exited.is_connected(_on_zone_area_exited):
		zone_source.area_exited.connect(_on_zone_area_exited)


func _on_zone_body_entered(body: Node3D) -> void:
	if not detect_bodies:
		return
	if not _passes_filter(body):
		return
	_on_zone_object_entered(body)


func _on_zone_body_exited(body: Node3D) -> void:
	if not detect_bodies:
		return
	if not _passes_filter(body):
		return
	_on_zone_object_exited(body)


func _on_zone_area_entered(area: Area3D) -> void:
	if not detect_areas:
		return
	if not _passes_filter(area):
		return
	_on_zone_object_entered(area)


func _on_zone_area_exited(area: Area3D) -> void:
	if not detect_areas:
		return
	if not _passes_filter(area):
		return
	_on_zone_object_exited(area)


func _on_zone_object_entered(node: Node) -> void:
	_bodies_inside += 1
	if _bodies_inside == 1:
		_zone_active = true
		if mode == Mode.TRIGGER_ZONE:
			if trigger_on_enter:
				if one_shot and _has_fired:
					return
				if one_shot:
					_has_fired = true
				JuiceLogger.log_info(self, "Interaction3D",
						"zone trigger IN (node=%s)" % node.name,
						debug_enabled)
				# Native body_entered/area_entered already fired on this Area3D
		elif mode == Mode.INTERACTABLE and check_presence_in_trigger_zone:
			# Zone activates: enable mouse picking and input processing
			input_ray_pickable = true
			if _has_custom_action_entries():
				_enable_input_processing(true)
			JuiceLogger.log_info(self, "Interaction3D",
					"zone active — interaction enabled (node=%s)" % node.name,
					debug_enabled)


func _on_zone_object_exited(node: Node) -> void:
	_bodies_inside = maxi(_bodies_inside - 1, 0)
	if _bodies_inside == 0:
		_zone_active = false
		if mode == Mode.TRIGGER_ZONE:
			if trigger_on_exit:
				JuiceLogger.log_info(self, "Interaction3D",
						"zone trigger OUT (node=%s)" % node.name,
						debug_enabled)
		elif mode == Mode.INTERACTABLE and check_presence_in_trigger_zone:
			input_ray_pickable = false
			if _has_custom_action_entries():
				_enable_input_processing(false)
			JuiceLogger.log_info(self, "Interaction3D",
					"zone empty — interaction disabled (node=%s)" % node.name,
					debug_enabled)


func _passes_filter(node: Node) -> bool:
	if filter_group.is_empty():
		return true
	return node.is_in_group(filter_group)


# =============================================================================
# DYNAMIC SIGNAL MANAGEMENT
# =============================================================================

# Register user signals based on current action configuration.
# Called from property setters (editor-time) and _ready() (runtime).
func _sync_user_signals() -> void:
	var needed: Array[StringName] = []
	for i in range(mini(action_count, _action_presets.size())):
		var sig := _get_signal_name_for_entry(i)
		if not sig.is_empty() and sig not in needed:
			needed.append(sig)

	for sig in needed:
		if sig not in _registered_signals:
			if not has_signal(sig):
				add_user_signal(sig)
			_registered_signals.append(sig)
			JuiceLogger.log_info(self, "Interaction3D",
					"registered dynamic signal '%s'" % sig,
					debug_enabled)
	# Note: Godot has no remove_user_signal(). Orphaned signals from removed
	# entries persist on this instance but are harmless. Cleaned on reload.


func _get_signal_name_for_entry(index: int) -> StringName:
	if index < 0 or index >= _action_presets.size():
		return &""
	match _action_presets[index]:
		InputActionPreset.LEFT_CLICK:
			return &"left_click"
		InputActionPreset.RIGHT_CLICK:
			return &"right_click"
		InputActionPreset.MIDDLE_CLICK:
			return &"middle_click"
		InputActionPreset.CUSTOM:
			if index < _action_names.size():
				return _action_names[index]
	return &""


# =============================================================================
# EXTERNAL API
# =============================================================================

## Enables or disables all input processing and ray picking.
## Call to programmatically suppress interaction (e.g., during cutscenes).
## Respects zone-gating: re-enabling does not override a closed zone.
func set_enabled(enabled: bool) -> void:
	if not enabled:
		set_process_unhandled_input(false)
		set_process_input(false)
		input_ray_pickable = false
		_zone_active = false
		_bodies_inside = 0
	else:
		if mode == Mode.INTERACTABLE:
			if not check_presence_in_trigger_zone or _zone_active:
				input_ray_pickable = true
			if _has_custom_action_entries():
				if not check_presence_in_trigger_zone or _zone_active:
					_enable_input_processing(true)
	JuiceLogger.log_info(self, "Interaction3D",
			"set_enabled(%s)" % enabled, debug_enabled)


## Clears the one-shot guard so the interaction can fire again.
## Call after a one-shot trigger completes its effect to re-arm it.
func reset() -> void:
	_has_fired = false
	JuiceLogger.log_info(self, "Interaction3D",
			"reset() — one-shot guard cleared", debug_enabled)


## Fires the signal for the configured click preset that matches button.
## Useful for testing interaction logic without a physical mouse event.
func simulate_click(button: int = MOUSE_BUTTON_LEFT) -> void:
	for i in range(mini(action_count, _action_presets.size())):
		var preset := _action_presets[i]
		var matched := false
		match preset:
			InputActionPreset.LEFT_CLICK: matched = (button == MOUSE_BUTTON_LEFT)
			InputActionPreset.RIGHT_CLICK: matched = (button == MOUSE_BUTTON_RIGHT)
			InputActionPreset.MIDDLE_CLICK: matched = (button == MOUSE_BUTTON_MIDDLE)
		if matched:
			var sig := _get_signal_name_for_entry(i)
			if not sig.is_empty():
				JuiceLogger.log_info(self, "Interaction3D",
						"simulate_click(%d) → '%s'" % [button, sig],
						debug_enabled)
				emit_signal(sig)


## Emits a registered dynamic signal by name without a real InputEvent.
## Logs a warning if the signal is not registered (action_count / config issue).
func simulate_input_action(action_name: StringName) -> void:
	if has_signal(action_name):
		JuiceLogger.log_info(self, "Interaction3D",
				"simulate_input_action('%s')" % action_name, debug_enabled)
		emit_signal(action_name)
	else:
		JuiceLogger.warn(self, "Interaction3D",
				"simulate_input_action: signal '%s' not found" % action_name,
				debug_enabled)


## Simulates a body or area entering the trigger zone, activating zone-gating.
## Drives the same path as a real physics enter event.
func simulate_zone_enter(node: Node) -> void:
	JuiceLogger.log_info(self, "Interaction3D",
			"simulate_zone_enter(%s)" % (str(node.name) if node else "null"),
			debug_enabled)
	_on_zone_object_entered(node)


## Simulates a body or area exiting the trigger zone, deactivating zone-gating.
## Drives the same path as a real physics exit event.
func simulate_zone_exit(node: Node) -> void:
	JuiceLogger.log_info(self, "Interaction3D",
			"simulate_zone_exit(%s)" % (str(node.name) if node else "null"),
			debug_enabled)
	_on_zone_object_exited(node)


## Returns a snapshot of the current configuration as a Dictionary.
## Useful for test assertions and debug output — not intended for runtime logic.
func get_configuration_summary() -> Dictionary:
	var summary := {
		"mode": Mode.keys()[mode],
		"debug_enabled": debug_enabled,
		"one_shot": one_shot,
	}
	if mode == Mode.INTERACTABLE:
		var actions: Array[Dictionary] = []
		for i in range(mini(action_count, _action_presets.size())):
			var entry := {"preset": InputActionPreset.keys()[_action_presets[i]], "signal": _get_signal_name_for_entry(i)}
			if _action_presets[i] == InputActionPreset.CUSTOM and i < _action_names.size():
				entry["action_name"] = str(_action_names[i])
			actions.append(entry)
		summary["actions"] = actions
		summary["input_priority"] = InputPriority.keys()[input_priority]
		summary["check_presence_in_trigger_zone"] = check_presence_in_trigger_zone

	var has_zone := (mode == Mode.TRIGGER_ZONE) or (mode == Mode.INTERACTABLE and check_presence_in_trigger_zone)
	if has_zone:
		summary["detect_bodies"] = detect_bodies
		summary["detect_areas"] = detect_areas
		summary["filter_group"] = filter_group
		summary["trigger_on_enter"] = trigger_on_enter
		summary["trigger_on_exit"] = trigger_on_exit
	return summary
