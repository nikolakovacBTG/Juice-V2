## Juice2D.gd
## ============================================================================
## WHAT: Juice node for Node2D targets (Sprite2D, CharacterBody2D, etc.).
## WHY: Validates parent is Node2D, connects Area2D/CollisionObject2D signals,
##      handles pivot compensation for rotation/scale (Node2D has no pivot_offset).
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Implement effects — those are JuiceEffectBase resources in a recipe.
## ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase2D.svg")
class_name Juice2D
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

## Resolve target and validate it's a Node2D node.
func _resolve_target() -> Node:
	if mode == Mode.STACK:
		var parent := get_parent()
		if parent is Node2D:
			return parent
		if parent != null and debug_enabled:
			push_warning("[%s] Parent '%s' is not a Node2D node" % [name, parent.name])
		return null
	return null  # SEQUENCER Phase 5

# =============================================================================
# AUTO-CONNECT (Override)
# =============================================================================

## Connect Area2D/CollisionObject2D signals based on trigger_on.
func _auto_connect_domain_signals() -> void:
	if _target_node == null:
		return

	# CollisionObject2D covers Area2D, StaticBody2D, RigidBody2D, etc.
	if _target_node is CollisionObject2D:
		_connect_collision_object_2d_signals(_target_node as CollisionObject2D)
		return

	# Check parent chain for CollisionObject2D (e.g., Sprite2D inside Area2D)
	var parent := _target_node.get_parent()
	if parent is CollisionObject2D:
		_connect_collision_object_2d_signals(parent as CollisionObject2D)


func _connect_collision_object_2d_signals(col_obj: CollisionObject2D) -> void:
	match trigger_on:
		TriggerEvent.ON_PRESS:
			if not col_obj.input_event.is_connected(_on_collision_input_press_2d):
				col_obj.input_event.connect(_on_collision_input_press_2d)
			if col_obj is Area2D:
				if not col_obj.body_entered.is_connected(_on_area_body_entered):
					col_obj.body_entered.connect(_on_area_body_entered)
				if not col_obj.area_entered.is_connected(_on_area_area_entered):
					col_obj.area_entered.connect(_on_area_area_entered)
		TriggerEvent.ON_RELEASE:
			if not col_obj.input_event.is_connected(_on_collision_input_release_2d):
				col_obj.input_event.connect(_on_collision_input_release_2d)
			if col_obj is Area2D:
				if not col_obj.body_exited.is_connected(_on_area_body_exited):
					col_obj.body_exited.connect(_on_area_body_exited)
				if not col_obj.area_exited.is_connected(_on_area_area_exited):
					col_obj.area_exited.connect(_on_area_area_exited)
		TriggerEvent.ON_HOVER_START:
			if not col_obj.mouse_entered.is_connected(_on_trigger_polarity_on):
				col_obj.mouse_entered.connect(_on_trigger_polarity_on)
			if not col_obj.mouse_exited.is_connected(_on_trigger_polarity_off):
				col_obj.mouse_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_HOVER_END:
			if not col_obj.mouse_entered.is_connected(_on_trigger_polarity_on):
				col_obj.mouse_entered.connect(_on_trigger_polarity_on)
			if not col_obj.mouse_exited.is_connected(_on_trigger_polarity_off):
				col_obj.mouse_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_LEFT_CLICK:
			if not col_obj.input_event.is_connected(_on_collision_input_filtered_2d):
				col_obj.input_event.connect(_on_collision_input_filtered_2d)
		TriggerEvent.ON_RIGHT_CLICK:
			if not col_obj.input_event.is_connected(_on_collision_input_filtered_2d):
				col_obj.input_event.connect(_on_collision_input_filtered_2d)
		TriggerEvent.ON_MIDDLE_CLICK:
			if not col_obj.input_event.is_connected(_on_collision_input_filtered_2d):
				col_obj.input_event.connect(_on_collision_input_filtered_2d)
		TriggerEvent.ON_BODY_ENTERED:
			if col_obj is Area2D:
				if not col_obj.body_entered.is_connected(_on_area_body_entered):
					col_obj.body_entered.connect(_on_area_body_entered)
		TriggerEvent.ON_BODY_EXITED:
			if col_obj is Area2D:
				if not col_obj.body_exited.is_connected(_on_area_body_exited):
					col_obj.body_exited.connect(_on_area_body_exited)
		TriggerEvent.ON_AREA_ENTERED:
			if col_obj is Area2D:
				if not col_obj.area_entered.is_connected(_on_area_area_entered):
					col_obj.area_entered.connect(_on_area_area_entered)
		TriggerEvent.ON_AREA_EXITED:
			if col_obj is Area2D:
				if not col_obj.area_exited.is_connected(_on_area_area_exited):
					col_obj.area_exited.connect(_on_area_area_exited)
	if debug_enabled:
		print("[%s] Auto-connected to %s '%s' on %s" % [
			name, col_obj.get_class(), col_obj.name, TriggerEvent.keys()[trigger_on]])

# =============================================================================
# CONFIGURATION WARNINGS (Override)
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()
	if mode == Mode.STACK:
		var parent := get_parent()
		if parent != null and not parent is Node2D:
			warnings.append("Juice2D requires a Node2D parent in STACK mode. Current parent is '%s' (%s)." % [
				parent.name, parent.get_class()])
	return warnings
