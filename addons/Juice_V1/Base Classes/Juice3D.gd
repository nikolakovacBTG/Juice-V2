## Juice node for [Node3D] targets (MeshInstance3D, CharacterBody3D, etc.).
##
## Attach as a child of any [Node3D]. Assign a [JuiceRecipe] and configure
## triggers to animate position, scale, rotation, appearance, and more.
## Effects stack automatically when multiple Juice nodes share a target.

# ============================================================================
# WHAT: Juice node for Node3D targets (MeshInstance3D, CharacterBody3D, etc.).
# WHY: Validates parent is Node3D, connects Area3D/CollisionObject3D signals.
# SYSTEM: Juicing System (addons/Juice_V1/)
# DOES NOT: Implement effects — those are JuiceEffectBase resources in a recipe.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name Juice3D
extends JuiceBase

# =============================================================================
# CONDITIONAL EXPORT SYSTEM (Override)
# =============================================================================

## Hint string for Juice3D: all triggers EXCEPT focus/unfocus (which are Control-only).
const _3D_TRIGGER_HINT := "On Press:0,On Release:1,On Hover Start:2,On Hover End:3,On Show:6,On Hide:7,On Ready:8,Manual:9,On Left Click:10,On Right Click:11,On Middle Click:12,On Body Entered:13,On Body Exited:14,On Area Entered:15,On Area Exited:16"

func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "trigger_on":
		property.hint_string = _3D_TRIGGER_HINT
	# Narrow recipe type so inspector only offers Juice3DRecipe
	if property.name == "recipe":
		property.hint_string = "Juice3DRecipe"

# =============================================================================
# INTERNAL STATE (Write Coordination)
# =============================================================================

# Natural state — captured once at _ready. Read-only reference after capture;
# contribution tracking does not modify these.
var _base_position: Vector3 = Vector3.ZERO
var _base_rotation: Vector3 = Vector3.ZERO
var _base_scale: Vector3 = Vector3.ONE

# Expected values after our last write — used for external-move detection.
# Difference between current and expected = displacement from other writers
# (sibling Juice nodes, game logic). INF sentinel = no write yet.
var _expected_position: Vector3 = Vector3.INF
var _expected_rotation: Vector3 = Vector3.INF
var _expected_scale: Vector3 = Vector3.INF

# Sum of all effect deltas currently applied — used by undo/reapply
var _total_pos_contribution: Vector3 = Vector3.ZERO
var _total_rot_contribution: Vector3 = Vector3.ZERO
var _total_scale_contribution: Vector3 = Vector3.ZERO

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

## Resolve target and validate it's a Node3D node.
func _resolve_target() -> Node:
	if mode == Mode.STACK:
		var parent := get_parent()
		if parent is Node3D:
			return parent
		if parent != null and debug_enabled:
			push_warning("[%s] Parent '%s' is not a Node3D node" % [name, parent.name])
		return null
	return null  # SEQUENCER Phase 5

# =============================================================================
# AUTO-CONNECT (Override)
# =============================================================================

func _is_recognized_trigger_source(node: Node) -> bool:
	if super._is_recognized_trigger_source(node):
		return true
	return node is CollisionObject3D or node is AnimationPlayer


## Connect Area3D/CollisionObject3D signals based on trigger_on.
## Uses _trigger_source_node (may differ from _target_node when TriggerSource == NODE).
func _auto_connect_domain_signals() -> void:
	if _trigger_source_node == null:
		return

	# CollisionObject3D covers Area3D, StaticBody3D, RigidBody3D, etc.
	if _trigger_source_node is CollisionObject3D:
		_connect_collision_object_3d_signals(_trigger_source_node as CollisionObject3D)
		return

	# Check parent chain for CollisionObject3D (e.g., MeshInstance3D inside Area3D)
	var parent := _trigger_source_node.get_parent()
	if parent is CollisionObject3D:
		_connect_collision_object_3d_signals(parent as CollisionObject3D)


func _connect_collision_object_3d_signals(col_obj: CollisionObject3D) -> void:
	match trigger_on:
		TriggerEvent.ON_PRESS:
			if not col_obj.input_event.is_connected(_on_collision_input_press_3d):
				col_obj.input_event.connect(_on_collision_input_press_3d)
			if col_obj is Area3D:
				if not col_obj.body_entered.is_connected(_on_area_body_entered):
					col_obj.body_entered.connect(_on_area_body_entered)
				if not col_obj.area_entered.is_connected(_on_area_area_entered):
					col_obj.area_entered.connect(_on_area_area_entered)
		TriggerEvent.ON_RELEASE:
			if not col_obj.input_event.is_connected(_on_collision_input_release_3d):
				col_obj.input_event.connect(_on_collision_input_release_3d)
			if col_obj is Area3D:
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
			if not col_obj.input_event.is_connected(_on_collision_input_filtered_3d):
				col_obj.input_event.connect(_on_collision_input_filtered_3d)
		TriggerEvent.ON_RIGHT_CLICK:
			if not col_obj.input_event.is_connected(_on_collision_input_filtered_3d):
				col_obj.input_event.connect(_on_collision_input_filtered_3d)
		TriggerEvent.ON_MIDDLE_CLICK:
			if not col_obj.input_event.is_connected(_on_collision_input_filtered_3d):
				col_obj.input_event.connect(_on_collision_input_filtered_3d)
		TriggerEvent.ON_BODY_ENTERED:
			if col_obj is Area3D:
				if not col_obj.body_entered.is_connected(_on_area_body_entered):
					col_obj.body_entered.connect(_on_area_body_entered)
		TriggerEvent.ON_BODY_EXITED:
			if col_obj is Area3D:
				if not col_obj.body_exited.is_connected(_on_area_body_exited):
					col_obj.body_exited.connect(_on_area_body_exited)
		TriggerEvent.ON_AREA_ENTERED:
			if col_obj is Area3D:
				if not col_obj.area_entered.is_connected(_on_area_area_entered):
					col_obj.area_entered.connect(_on_area_area_entered)
		TriggerEvent.ON_AREA_EXITED:
			if col_obj is Area3D:
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
	if _target_node == null or not _target_node is Node3D:
		return
	var n3d := _target_node as Node3D
	_base_position = n3d.position
	_base_rotation = n3d.rotation
	_base_scale = n3d.scale
	_base_captured = true
	# Reset tracking — no write has happened yet
	_expected_position = Vector3.INF
	_expected_rotation = Vector3.INF
	_expected_scale = Vector3.INF
	_total_pos_contribution = Vector3.ZERO
	_total_rot_contribution = Vector3.ZERO
	_total_scale_contribution = Vector3.ZERO


## Detect external displacement: did something change the target since our last write?
## With contribution tracking, displacement = current - expected. This captures
## sibling Juice node writes and game logic — anything that isn't our own contribution.
func _pre_tick() -> void:
	if _target_node == null or not _base_captured:
		return
	var n3d := _target_node as Node3D
	var ext_disp := {}

	# Position: compare current to what we expected after our last write
	if _expected_position != Vector3.INF:
		if not n3d.position.is_equal_approx(_expected_position):
			var displacement := n3d.position - _expected_position
			ext_disp["position"] = displacement
			if debug_enabled:
				print("[%s] External displacement (position): %s" % [name, displacement])

	# Rotation
	if _expected_rotation != Vector3.INF:
		if not n3d.rotation.is_equal_approx(_expected_rotation):
			ext_disp["rotation"] = n3d.rotation - _expected_rotation

	# Scale
	if _expected_scale != Vector3.INF:
		if not n3d.scale.is_equal_approx(_expected_scale):
			ext_disp["scale"] = n3d.scale - _expected_scale

	# Notify effects of external displacement (for reactive effects like Spring)
	if not ext_disp.is_empty():
		for effect in _runtime_effects:
			if effect != null and effect.is_playing():
				effect._on_external_displacement(ext_disp)


## Contribution-tracking write: subtract old contribution, add new contribution.
## Multiple Juice nodes on the same target can write independently without
## overwriting each other — each node only touches its own layer of changes.
func _post_tick_write() -> void:
	if _target_node == null or not _base_captured:
		return
	var n3d := _target_node as Node3D

	# Sum deltas from all runtime effects
	var new_pos := Vector3.ZERO
	var new_rot := Vector3.ZERO
	var new_scale := Vector3.ZERO

	for effect in _runtime_effects:
		if effect == null:
			continue
		var eff_3d := effect as Juice3DTransformEffect
		if eff_3d == null:
			continue
		if eff_3d._contributes_position:
			new_pos += eff_3d._pos_delta
		if eff_3d._contributes_rotation:
			new_rot += eff_3d._rot_delta
		if eff_3d._contributes_scale:
			new_scale += eff_3d._scale_delta

	# Contribution tracking: subtract what we added last frame, add what we want now
	n3d.position = n3d.position - _total_pos_contribution + new_pos
	n3d.rotation = n3d.rotation - _total_rot_contribution + new_rot
	n3d.scale = n3d.scale - _total_scale_contribution + new_scale

	# Track expected values (for external-displacement detection next frame)
	_expected_position = n3d.position
	_expected_rotation = n3d.rotation
	_expected_scale = n3d.scale

	# Track total contribution (for undo/reapply and next frame's subtraction)
	_total_pos_contribution = new_pos
	_total_rot_contribution = new_rot
	_total_scale_contribution = new_scale


## Subtract this node's contributions — other nodes' contributions remain.
func _temporarily_undo_visual() -> void:
	if _target_node == null or not _base_captured:
		return
	var n3d := _target_node as Node3D
	n3d.position -= _total_pos_contribution
	n3d.rotation -= _total_rot_contribution
	n3d.scale -= _total_scale_contribution


## Re-add contributions after temporary undo.
func _temporarily_reapply_visual() -> void:
	if _target_node == null or not _base_captured:
		return
	var n3d := _target_node as Node3D
	n3d.position += _total_pos_contribution
	n3d.rotation += _total_rot_contribution
	n3d.scale += _total_scale_contribution


# =============================================================================
# CONFIGURATION WARNINGS (Override)
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super._get_configuration_warnings()
	if mode == Mode.STACK:
		var parent := get_parent()
		if parent != null and not parent is Node3D:
			warnings.append("Juice3D requires a Node3D parent in STACK mode. Current parent is '%s' (%s)." % [
				parent.name, parent.get_class()])
	return warnings
