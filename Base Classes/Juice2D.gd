## Juice node for [Node2D] targets (Sprite2D, CharacterBody2D, etc.).
##
## Attach as a child of any [Node2D]. Assign a [JuiceRecipe] and configure
## triggers to animate position, scale, rotation, appearance, and more.
## Effects stack automatically when multiple Juice nodes share a target.

# ============================================================================
# WHAT: Juice node for Node2D targets (Sprite2D, CharacterBody2D, etc.).
# WHY: Validates parent is Node2D, connects Area2D/CollisionObject2D signals,
#      handles pivot compensation for rotation/scale (Node2D has no pivot_offset).
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Implement effects — those are JuiceEffectBase resources in a recipe.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase2D.svg")
class_name Juice2D
extends JuiceBase

# =============================================================================
# CONDITIONAL EXPORT SYSTEM (Override)
# =============================================================================

## Hint string for Juice2D: fallback when no trigger source node is resolvable.
## Body/Area Entered are marked (toggleable) because they wire both enter+exit
## as a polarity pair — entered fires polarity_on, exited fires polarity_off.
const _2D_TRIGGER_HINT := "On Press (toggleable):0,On Release:1,On Mouse Entered (toggleable):2,On Mouse Exited:3,On Show:6,On Hide:7,On Ready:8,Manual:9,On Left Click:10,On Right Click:11,On Middle Click:12,On Body Entered (toggleable):13,On Body Exited:14,On Area Entered (toggleable):15,On Area Exited:16"

func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "trigger_on":
		# Dynamically filter to only valid options for the current trigger source.
		var source: Node = _resolve_hint_source_node()
		property.hint_string = TriggerHintBuilder.build_hint(source, &"2D")
	# Narrow recipe type so inspector only offers Juice2DRecipe
	if property.name == "recipe":
		property.hint_string = "Juice2DRecipe"

# =============================================================================
# INTERNAL STATE (Write Coordination)
# =============================================================================

# Whether base values have been captured at least once.
# All property tracking (transform + modulate) is owned by JuiceLedger.
var _base_captured: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()


func _exit_tree() -> void:
	super._exit_tree()
	if _target_node != null and is_instance_valid(_target_node):
		JuiceLedger.cleanup_source(_target_node, self)

func _process(delta: float) -> void:
	super._process(delta)

# =============================================================================
# TARGET RESOLUTION (Override)
# =============================================================================

## Resolve target and validate it's a Node2D node.
func _resolve_target() -> Node:
	if mode == Mode.STACK:
		var parent := get_parent()
		if parent is Node2D:
			return parent
		if parent != null:
			JuiceLogger.warn(self, _get_domain_tag(),
					"Parent '%s' is not a Node2D node" % parent.name,
					debug_enabled)
		return null
	return null  # SEQUENCER resolves per-target dynamically

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
			# Polarity handler on input_event covers mouse press=in, release=out for Toggle.
			# Body/area entered signals stay momentary — they have no natural release counterpart here.
			if not col_obj.input_event.is_connected(_on_collision_input_press_polarity_2d):
				col_obj.input_event.connect(_on_collision_input_press_polarity_2d)
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
		TriggerEvent.ON_MOUSE_ENTERED:
			if not col_obj.mouse_entered.is_connected(_on_trigger_polarity_on):
				col_obj.mouse_entered.connect(_on_trigger_polarity_on)
			if not col_obj.mouse_exited.is_connected(_on_trigger_polarity_off):
				col_obj.mouse_exited.connect(_on_trigger_polarity_off)
		TriggerEvent.ON_MOUSE_EXITED:
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
	JuiceLogger.log_info(self, _get_domain_tag(),
			"Auto-connected to %s '%s' on %s" % [
			col_obj.get_class(), col_obj.name, TriggerEvent.keys()[trigger_on]],
			debug_enabled)

# =============================================================================
# DOMAIN VIRTUAL HOOK OVERRIDES (Write Coordination)
# =============================================================================

## Returns "2D" for structured log output.
func _get_domain_tag() -> String:
	return "2D"


## Capture target's natural position/rotation/scale/modulate.
## All properties are tracked through the Shared Target Ledger.
func _capture_base_values() -> void:
	if _target_node == null or not _target_node is Node2D:
		return
	var n2d := _target_node as Node2D
	JuiceLedger.ensure(n2d, ["position", "rotation", "scale", "modulate"])
	_base_captured = true
	JuiceLogger.log_capture(self, "2D", "position", n2d.position, debug_enabled)
	JuiceLogger.log_capture(self, "2D", "rotation", n2d.rotation, debug_enabled)
	JuiceLogger.log_capture(self, "2D", "scale", n2d.scale, debug_enabled)
	JuiceLogger.log_capture(self, "2D", "modulate", n2d.modulate, debug_enabled)

## Detect external displacement of the target (game logic, tweens, etc.).
## The Ledger handles external-displacement for all tracked properties.
func _pre_tick() -> void:
	if _target_node == null or not _base_captured:
		return
	var n2d := _target_node as Node2D
	var old_pos: Vector2 = JuiceLedger.get_base(n2d, "position", n2d.position)
	JuiceLedger.sync_base_if_moved(n2d, ["position", "rotation", "scale", "modulate"])
	var new_pos: Vector2 = JuiceLedger.get_base(n2d, "position", n2d.position)
	if old_pos != new_pos:
		JuiceLogger.log_aggregation("2D", n2d.name, "external_move",
				old_pos, new_pos - old_pos, new_pos, debug_enabled)


## Contribution-tracking write: register this node's deltas into the shared target ledger,
## then write absolute values. Transform uses additive, modulate uses multiplicative.
## Multiple Juice nodes on the same target write through the ledger independently.
func _post_tick_write() -> void:
	if _target_node == null or not _base_captured:
		return
	var n2d := _target_node as Node2D

	# Sum transform deltas from all runtime effects
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

	# Register transform deltas into the Target's ledger
	JuiceLedger.register_delta(n2d, self, "position", new_pos)
	JuiceLedger.register_delta(n2d, self, "rotation", new_rot)
	JuiceLedger.register_delta(n2d, self, "scale", new_scale)

	var base_pos: Vector2 = JuiceLedger.get_base(n2d, "position", Vector2.ZERO)
	var base_rot: float = JuiceLedger.get_base(n2d, "rotation", 0.0)
	var base_scale: Vector2 = JuiceLedger.get_base(n2d, "scale", Vector2.ONE)
	var total_pos: Vector2 = JuiceLedger.get_total(n2d, "position", Vector2.ZERO)
	var total_rot: float = JuiceLedger.get_total(n2d, "rotation", 0.0)
	var total_scale: Vector2 = JuiceLedger.get_total(n2d, "scale", Vector2.ZERO)

	JuiceLogger.log_aggregation("2D", n2d.name, "position",
			base_pos, new_pos, base_pos + total_pos, debug_enabled)
	JuiceLogger.log_aggregation("2D", n2d.name, "rotation",
			base_rot, new_rot, base_rot + total_rot, debug_enabled)
	JuiceLogger.log_aggregation("2D", n2d.name, "scale",
			base_scale, new_scale, base_scale + total_scale, debug_enabled)

	# Accumulate modulate factors from Juice2DAppearanceEffect effects.
	# Each effect contributes a multiplicative factor; the Ledger handles
	# base × Πfactors for Color properties automatically.
	var combined_modulate := Color.WHITE
	for effect in _runtime_effects:
		if effect == null:
			continue
		var app_eff := effect as Juice2DAppearanceEffect
		if app_eff == null or not app_eff._contributes_modulate:
			continue
		combined_modulate.r *= app_eff._modulate_factor.r
		combined_modulate.g *= app_eff._modulate_factor.g
		combined_modulate.b *= app_eff._modulate_factor.b
		combined_modulate.a *= app_eff._modulate_factor.a

	# Register modulate factor into the Ledger — sibling stacking is handled
	# automatically via per-source delta tracking (one entry per Juice2D node).
	JuiceLedger.register_delta(n2d, self, "modulate", combined_modulate)

	# Flush all properties — transform (additive) + modulate (multiplicative)
	JuiceLedger.flush(n2d, ["position", "rotation", "scale", "modulate"])
	var written_modulate: Color = n2d.modulate
	JuiceLogger.log_info(self, "2D",
			"post_tick: modulate this_node_factor=%s total_written=%s" % [
			combined_modulate, written_modulate],
			debug_enabled)


## Subtract this node's contributions — other nodes' contributions remain.
## Called before effects capture From/To references and before editor save.
func _temporarily_undo_visual() -> void:
	if _target_node == null or not _base_captured:
		return
	var n2d := _target_node as Node2D
	# Sum deltas being stripped so the log shows exactly what is removed.
	var strip_pos := Vector2.ZERO
	var strip_rot := 0.0
	var strip_scale := Vector2.ZERO
	for effect in _runtime_effects:
		var te := effect as Juice2DTransformEffect
		if te == null:
			continue
		if te._contributes_position:
			strip_pos += te._pos_delta
		if te._contributes_rotation:
			strip_rot += te._rot_delta
		if te._contributes_scale:
			strip_scale += te._scale_delta
	JuiceLogger.log_info(self, "2D",
			"undo_visual '%s': stripping pos=%s rot=%.4f scale=%s" % [
			n2d.name, strip_pos, strip_rot, strip_scale],
			debug_enabled)

	# Strip our deltas from the ledger temporarily without destroying it
	JuiceLedger.cleanup_source(n2d, self, false)

	# Flush remaining sibling contributions — Ledger handles both additive
	# (transform) and multiplicative (modulate) correctly.
	JuiceLedger.flush(n2d, ["position", "rotation", "scale", "modulate"])


## Re-add contributions after temporary undo.
func _temporarily_reapply_visual() -> void:
	if _target_node == null or not _base_captured:
		return
	var n2d := _target_node as Node2D
	# Re-apply transform deltas by flushing a fresh post-tick write.
	# This restores our deltas to the ledger and recalculates absolute values.
	_post_tick_write()
	JuiceLogger.log_info(self, "2D",
			"reapply_visual '%s': restored pos=%s rot=%.4f scale=%s modulate=%s" % [
			n2d.name, n2d.position, n2d.rotation, n2d.scale, n2d.modulate],
			debug_enabled)


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
