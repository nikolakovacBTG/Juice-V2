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
# Transform state is owned by the Centralized Metadata Ledger (LEDGER_KEY on target).
# Appearance stacking uses per-node _own_modulate_contribution as before.
var _base_captured: bool = false

# Per-node modulate contribution for sibling stacking (Appearance effects only).
# Transform properties use the shared Metadata Ledger.
var _own_modulate_contribution: Color = Color.WHITE

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()
	if debug_enabled:
		print("[DEBUG] Phase B: Juice2D _ready() called")
		print("[DEBUG] Phase B: Mode: ", mode)
		print("[DEBUG] Phase B: Target node: ", _target_node)


func _exit_tree() -> void:
	super._exit_tree()
	if _target_node != null and is_instance_valid(_target_node):
		JuiceLedger.cleanup_source(_target_node, self)

func _process(delta: float) -> void:
	super._process(delta)
	if debug_enabled:
		print("[DEBUG] Phase B: Juice2D _process() called with delta: ", delta)

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
	if debug_enabled:
		print("[%s] Auto-connected to %s '%s' on %s" % [
			name, col_obj.get_class(), col_obj.name, TriggerEvent.keys()[trigger_on]])

# =============================================================================
# DOMAIN VIRTUAL HOOK OVERRIDES (Write Coordination)
# =============================================================================

## Capture target's natural position/rotation/scale.
## Transforms use the Shared Target Ledger; Modulate uses the dedicated META_KEY.
func _capture_base_values() -> void:
	if _target_node == null or not _target_node is Node2D:
		return
	var n2d := _target_node as Node2D
	
	JuiceLedger.ensure(n2d, ["position", "rotation", "scale"])
	
	_base_captured = true

## Detect external displacement of the target (game logic, tweens, etc.).
## The Metadata Ledger's external-displacement check handles all tracked props.
func _pre_tick() -> void:
	if _target_node == null or not _base_captured:
		return
	var n2d := _target_node as Node2D
	
	JuiceLedger.sync_base_if_moved(n2d, ["position", "rotation", "scale"])


## Contribution-tracking write: register this node's deltas into the shared target ledger,
## then write absolute: target = ledger_base + sum(all_source_deltas).
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

	# Register our deltas into the Target's ledger
	JuiceLedger.register_delta(n2d, self, "position", new_pos)
	JuiceLedger.register_delta(n2d, self, "rotation", new_rot)
	JuiceLedger.register_delta(n2d, self, "scale", new_scale)

	# Write: base + Σ(all source deltas) — single authoritative write via ledger.
	# Only flushes transform properties; modulate uses multiplicative accumulation below.
	JuiceLedger.flush(n2d, ["position", "rotation", "scale"])

	# Appearance: accumulate modulate factors from Juice2DAppearanceEffect effects.
	# Only write modulate when at least one appearance effect has a non-identity factor.
	var combined_modulate := Color.WHITE
	var has_appearance := false
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
		has_appearance = true

	# Phase B: Sibling stacking with metadata-based natural base capture
	# Get shared natural base from target metadata (captured by first Juice2D)
	const META_KEY := &"juice_modulate_natural"
	var base_color: Color = n2d.modulate
	if not n2d.has_meta(META_KEY):
		# First Juice2D node — capture natural base and store in metadata
		n2d.set_meta(META_KEY, n2d.modulate)
	else:
		# Subsequent Juice2D nodes — read natural base from metadata
		base_color = n2d.get_meta(META_KEY)

	# Scan all sibling Juice2D nodes on the same target, multiply contributions.
	# In STACK mode, Juice nodes are children of the target — scan target's children.
	var final_factor := Color.WHITE
	for child in n2d.get_children():
		var j := child as Juice2D
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
	n2d.modulate = Color(
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
	for child in n2d.get_children():
		var j := child as Juice2D
		if j == null or j == self:
			continue
		if j._own_modulate_contribution != Color.WHITE:
			all_siblings_idle = false
			break

	# If all siblings idle and we're idle, remove metadata and restore natural state
	if all_siblings_idle and not has_appearance and n2d.has_meta(META_KEY):
		n2d.remove_meta(META_KEY)
		n2d.modulate = base_color


## Subtract this node's contributions — other nodes' contributions remain.
## Called before effects capture From/To references and before editor save.
func _temporarily_undo_visual() -> void:
	if _target_node == null or not _base_captured:
		return
	var n2d := _target_node as Node2D
	
	# Strip our deltas from the ledger temporarily without destroying it
	JuiceLedger.cleanup_source(n2d, self, false)
	
	# Apply absolute baseline position + sibling remaining deltas
	n2d.position = JuiceLedger.get_base(n2d, "position", n2d.position) + JuiceLedger.get_total(n2d, "position", Vector2.ZERO)
	n2d.rotation = JuiceLedger.get_base(n2d, "rotation", n2d.rotation) + JuiceLedger.get_total(n2d, "rotation", 0.0)
	n2d.scale = JuiceLedger.get_base(n2d, "scale", n2d.scale) + JuiceLedger.get_total(n2d, "scale", Vector2.ZERO)

	# Restore modulate to natural so Appearance effects see the true From state
	# when _on_animate_start captures references (e.g. during animate_out after a fade-in).
	const META_KEY := &"juice_modulate_natural"
	if n2d.has_meta(META_KEY):
		n2d.modulate = n2d.get_meta(META_KEY)
	# Set own contribution to identity so sibling rescan excludes us
	_own_modulate_contribution = Color.WHITE


## Re-add contributions after temporary undo.
func _temporarily_reapply_visual() -> void:
	if _target_node == null or not _base_captured:
		return
	# Re-apply transform deltas by flushing a fresh post-tick write.
	# This restores our deltas to the ledger and recalculates absolute values.
	_post_tick_write()


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
