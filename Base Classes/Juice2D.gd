## Juice node for [Node2D] targets (Sprite2D, CharacterBody2D, etc.).
##
## Attach as a child of any [Node2D]. Assign a [JuiceRecipe] and configure
## triggers to animate position, scale, rotation, appearance, and more.
## Effects stack automatically when multiple Juice nodes share a target.

# ============================================================================
# WHAT: Juice node for Node2D targets (Sprite2D, CharacterBody2D, etc.).
# WHY: Validates parent is Node2D, connects Area2D/CollisionObject2D signals,
#      handles pivot compensation for rotation/scale (Node2D has no pivot_offset).
# SYSTEM: Juicing System (addons/Juice_V1/)
# DOES NOT: Implement effects — those are JuiceEffectBase resources in a recipe.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase2D.svg")
class_name Juice2D
extends JuiceBase

# =============================================================================
# CONDITIONAL EXPORT SYSTEM (Override)
# =============================================================================

## Hint string for Juice2D: all triggers EXCEPT focus/unfocus (which are Control-only).
const _2D_TRIGGER_HINT := "On Press:0,On Release:1,On Hover Start:2,On Hover End:3,On Show:6,On Hide:7,On Ready:8,Manual:9,On Left Click:10,On Right Click:11,On Middle Click:12,On Body Entered:13,On Body Exited:14,On Area Entered:15,On Area Exited:16"

func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "trigger_on":
		property.hint_string = _2D_TRIGGER_HINT
	# Narrow recipe type so inspector only offers Juice2DRecipe
	if property.name == "recipe":
		property.hint_string = "Juice2DRecipe"

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
# (sibling Juice nodes, game logic). INF sentinel = no write yet.
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

func _is_recognized_trigger_source(node: Node) -> bool:
	if super._is_recognized_trigger_source(node):
		return true
	return node is CollisionObject2D or node is AnimationPlayer


## Connect Area2D/CollisionObject2D signals based on trigger_on.
## Uses _trigger_source_node (may differ from _target_node when TriggerSource == NODE).
func _auto_connect_domain_signals() -> void:
	if _trigger_source_node == null:
		return

	# CollisionObject2D covers Area2D, StaticBody2D, RigidBody2D, etc.
	if _trigger_source_node is CollisionObject2D:
		_connect_collision_object_2d_signals(_trigger_source_node as CollisionObject2D)
		return

	# Check parent chain for CollisionObject2D (e.g., Sprite2D inside Area2D)
	var parent := _trigger_source_node.get_parent()
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
# DOMAIN VIRTUAL HOOK OVERRIDES (Write Coordination)
# =============================================================================

## Capture target's natural position/rotation/scale.
## Base values are a read-only reference; contribution tracking handles writes.
func _capture_base_values() -> void:
	if _target_node == null or not _target_node is Node2D:
		return
	var n2d := _target_node as Node2D
	_base_position = n2d.position
	_base_rotation = n2d.rotation
	_base_scale = n2d.scale
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
## sibling Juice node writes and game logic — anything that isn't our own contribution.
func _pre_tick() -> void:
	if _target_node == null or not _base_captured:
		return
	var n2d := _target_node as Node2D
	var ext_disp := {}

	# Position: compare current to what we expected after our last write
	if _expected_position != Vector2.INF:
		if not n2d.position.is_equal_approx(_expected_position):
			var displacement := n2d.position - _expected_position
			ext_disp["position"] = displacement
			if debug_enabled:
				print("[%s] External displacement (position): %s" % [name, displacement])

	# Rotation
	if _expected_rotation != INF:
		if not is_equal_approx(n2d.rotation, _expected_rotation):
			ext_disp["rotation"] = n2d.rotation - _expected_rotation

	# Scale
	if _expected_scale != Vector2.INF:
		if not n2d.scale.is_equal_approx(_expected_scale):
			ext_disp["scale"] = n2d.scale - _expected_scale

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
		var eff_2d := effect as Juice2DTransformEffect
		if eff_2d == null:
			continue
		if eff_2d._contributes_position:
			nr_pos += eff_2d._pos_delta
		if eff_2d._contributes_rotation:
			nr_rot += eff_2d._rot_delta
		if eff_2d._contributes_scale:
			nr_scale += eff_2d._scale_delta

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
	var n2d := _target_node as Node2D

	# Sum deltas from all runtime effects
	var new_pos := Vector2.ZERO
	var new_rot := 0.0
	var new_scale := Vector2.ZERO

	for effect in _runtime_effects:
		if effect == null:
			continue
		var eff_2d := effect as Juice2DTransformEffect
		if eff_2d == null:
			continue
		if eff_2d._contributes_position:
			new_pos += eff_2d._pos_delta
		if eff_2d._contributes_rotation:
			new_rot += eff_2d._rot_delta
		if eff_2d._contributes_scale:
			new_scale += eff_2d._scale_delta

	# Contribution tracking: subtract what we added last frame, add what we want now
	n2d.position = n2d.position - _total_pos_contribution + new_pos
	n2d.rotation = n2d.rotation - _total_rot_contribution + new_rot
	n2d.scale = n2d.scale - _total_scale_contribution + new_scale

	# Track expected values (for external-displacement detection next frame)
	_expected_position = n2d.position
	_expected_rotation = n2d.rotation
	_expected_scale = n2d.scale

	# Update tracked contribution (for undo/reapply and next frame's subtraction)
	_total_pos_contribution = new_pos
	_total_rot_contribution = new_rot
	_total_scale_contribution = new_scale


## Subtract this node's contributions — other nodes' contributions remain.
func _temporarily_undo_visual() -> void:
	if _target_node == null or not _base_captured:
		return
	var n2d := _target_node as Node2D
	n2d.position -= _total_pos_contribution
	n2d.rotation -= _total_rot_contribution
	n2d.scale -= _total_scale_contribution


## Re-add contributions after temporary undo.
func _temporarily_reapply_visual() -> void:
	if _target_node == null or not _base_captured:
		return
	var n2d := _target_node as Node2D
	n2d.position += _total_pos_contribution
	n2d.rotation += _total_rot_contribution
	n2d.scale += _total_scale_contribution


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
