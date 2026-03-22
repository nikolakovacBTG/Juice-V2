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
func _capture_base_values() -> void:
	if _target_node == null or not _target_node is Node2D:
		return
	var n2d := _target_node as Node2D
	_base_position = n2d.position
	_base_rotation = n2d.rotation
	_base_scale = n2d.scale
	_base_captured = true
	# Reset tracking — no write has happened yet
	_last_written_position = Vector2.INF
	_last_written_rotation = INF
	_last_written_scale = Vector2.INF
	_total_pos_contribution = Vector2.ZERO
	_total_rot_contribution = 0.0
	_total_scale_contribution = Vector2.ZERO


## Detect external moves: did something else change the target since our last write?
func _pre_tick() -> void:
	if _target_node == null or not _base_captured:
		return
	var n2d := _target_node as Node2D

	# Position
	if _last_written_position != Vector2.INF:
		if not n2d.position.is_equal_approx(_last_written_position):
			var external_delta := n2d.position - _last_written_position
			_base_position += external_delta
			if debug_enabled:
				print("[%s] External position move detected: %s" % [name, external_delta])

	# Rotation
	if _last_written_rotation != INF:
		if not is_equal_approx(n2d.rotation, _last_written_rotation):
			var external_delta := n2d.rotation - _last_written_rotation
			_base_rotation += external_delta

	# Scale
	if _last_written_scale != Vector2.INF:
		if not n2d.scale.is_equal_approx(_last_written_scale):
			var external_delta := n2d.scale - _last_written_scale
			_base_scale += external_delta


## Aggregate all effect deltas and write to target ONCE per frame.
func _post_tick_write() -> void:
	if _target_node == null or not _base_captured:
		return
	var n2d := _target_node as Node2D

	# Sum deltas from all runtime effects
	var total_pos := Vector2.ZERO
	var total_rot := 0.0
	var total_scale := Vector2.ZERO

	for effect in _runtime_effects:
		if effect == null:
			continue
		var eff_2d := effect as Juice2DEffectBase
		if eff_2d == null:
			continue
		if eff_2d._contributes_position:
			total_pos += eff_2d._pos_delta
		if eff_2d._contributes_rotation:
			total_rot += eff_2d._rot_delta
		if eff_2d._contributes_scale:
			total_scale += eff_2d._scale_delta

	# Write once: base + sum(deltas)
	n2d.position = _base_position + total_pos
	n2d.rotation = _base_rotation + total_rot
	n2d.scale = _base_scale + total_scale

	# Track what we wrote (for external-move detection next frame)
	_last_written_position = n2d.position
	_last_written_rotation = n2d.rotation
	_last_written_scale = n2d.scale

	# Track total contribution (for undo/reapply)
	_total_pos_contribution = total_pos
	_total_rot_contribution = total_rot
	_total_scale_contribution = total_scale


## Subtract all contributions — target returns to natural state.
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


## Sequencer RECIPE mode: aggregate deltas from per-target effects and write once.
func _seq_post_tick_write_target(target: Node, effects: Array) -> void:
	var n2d := target as Node2D
	if n2d == null:
		return

	var total_pos := Vector2.ZERO
	var total_rot := 0.0
	var total_scale := Vector2.ZERO

	for eff_variant: Variant in effects:
		var eff_2d := eff_variant as Juice2DEffectBase
		if eff_2d == null:
			continue
		if eff_2d._contributes_position:
			total_pos += eff_2d._pos_delta
		if eff_2d._contributes_rotation:
			total_rot += eff_2d._rot_delta
		if eff_2d._contributes_scale:
			total_scale += eff_2d._scale_delta

	# Use first Transform effect's base as reference
	var base_pos := Vector2.ZERO
	var base_rot := 0.0
	var base_scale := Vector2.ONE
	for eff_variant2: Variant in effects:
		if eff_variant2 is Transform2DJuiceEffect:
			var t2d := eff_variant2 as Transform2DJuiceEffect
			if t2d._has_base:
				base_pos = t2d._base_position
				base_rot = t2d._base_rotation_radians
				base_scale = t2d._base_scale
				break

	n2d.position = base_pos + total_pos
	n2d.rotation = base_rot + total_rot
	n2d.scale = base_scale + total_scale

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
