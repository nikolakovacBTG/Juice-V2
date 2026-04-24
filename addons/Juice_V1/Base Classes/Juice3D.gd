## Juice node for [Node3D] targets (MeshInstance3D, CharacterBody3D, etc.).
##
## Attach as a child of any [Node3D]. Assign a [JuiceRecipe] and configure
## triggers to animate position, scale, rotation, appearance, and more.
## Effects stack automatically when multiple Juice nodes share a target.

# ============================================================================
# WHAT: Juice node for Node3D targets (MeshInstance3D, CharacterBody3D, etc.).
# WHY: Validates parent is Node3D, connects Area3D/CollisionObject3D signals.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Implement effects — those are JuiceEffectBase resources in a recipe.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name Juice3D
extends JuiceBase

# =============================================================================
# CONDITIONAL EXPORT SYSTEM (Override)
# =============================================================================

## Hint string for Juice3D: fallback when no trigger source node is resolvable.
## Body/Area Entered are marked (toggleable) because they wire both enter+exit
## as a polarity pair — entered fires polarity_on, exited fires polarity_off.
const _3D_TRIGGER_HINT := "On Press (toggleable):0,On Release:1,On Mouse Entered (toggleable):2,On Mouse Exited:3,On Show:6,On Hide:7,On Ready:8,Manual:9,On Left Click:10,On Right Click:11,On Middle Click:12,On Body Entered (toggleable):13,On Body Exited:14,On Area Entered (toggleable):15,On Area Exited:16"

func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "trigger_on":
		# Dynamically filter to only valid options for the current trigger source.
		var source: Node = _resolve_hint_source_node()
		property.hint_string = TriggerHintBuilder.build_hint(source, &"3D")
	# Narrow recipe type so inspector only offers Juice3DRecipe
	if property.name == "recipe":
		property.hint_string = "Juice3DRecipe"

# =============================================================================
# INTERNAL STATE (Write Coordination)
# =============================================================================

# Whether base values have been captured at least once.
# Transform state is owned by the Centralized Metadata Ledger (LEDGER_KEY on target).
# Appearance state below uses 3D-specific per-node tracking.
var _base_captured: bool = false

# 3D Appearance — domain node owns the single working material to prevent multiple
# Juice3DAppearanceEffect instances fighting over the surface_override_material slot.
# Lazily initialised on first appearance effect use; cleared when no effects active.
var _appearance_mesh: MeshInstance3D = null
var _appearance_working_mat: StandardMaterial3D = null
var _appearance_natural_mat: Material = null
var _appearance_natural_albedo: Color = Color.WHITE
var _appearance_natural_alpha: float = 1.0
var _appearance_setup: bool = false

# Captured reference values for From/To animation
var _captured_from_tint_color: Color = Color.WHITE
var _captured_from_tint_blend: float = 0.0
var _captured_from_alpha: float = 1.0
var _captured_from_brightness: float = 1.0

# Only needed for OUTLINE (which installs a ShaderMaterial on target.material).
# Modulate effects (TINT/FADE/OVERBRIGHT) use _modulate_factor from the intermediate.
var _natural_material: Material = null
var _has_natural: bool = false
var _active_material: Material = null
var _tick_delta: float = 0.0
var _flicker_time: float = 0.0
var _flicker_noise: FastNoiseLite = null

# 3D OUTLINE support
var _outline_material: ShaderMaterial = null

# Per-node contribution tracking for sibling stacking
var _own_albedo_contribution: Color = Color.WHITE
var _own_alpha_contribution: float = 1.0

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()


func _exit_tree() -> void:
	super._exit_tree()
	if _target_node != null and is_instance_valid(_target_node):
		JuiceLedger.cleanup_source(_target_node, self)

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
	return null  # SEQUENCER resolves per-target dynamically

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
			# Polarity handler on input_event covers mouse press=in, release=out for Toggle.
			# Body/area entered signals stay momentary — they have no natural release counterpart here.
			if not col_obj.input_event.is_connected(_on_collision_input_press_polarity_3d):
				col_obj.input_event.connect(_on_collision_input_press_polarity_3d)
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
## Transforms use the Shared Target Ledger; appearance uses 3D-specific per-node tracking.
func _capture_base_values() -> void:
	if _target_node == null or not _target_node is Node3D:
		return
	var n3d := _target_node as Node3D
	JuiceLedger.ensure(n3d, ["position", "rotation", "scale"])
	_base_captured = true

## Detect external displacement of the target (game logic, tweens, etc.).
## The Metadata Ledger's external-displacement check handles all tracked props.
func _pre_tick() -> void:
	if _target_node == null or not _base_captured:
		return
	var n3d := _target_node as Node3D
	JuiceLedger.sync_base_if_moved(n3d, ["position", "rotation", "scale"])


## Contribution-tracking write: register this node's deltas into the shared target ledger,
## then write absolute: target = ledger_base + sum(all_source_deltas).
## Multiple Juice nodes on the same target write through the ledger independently.
func _post_tick_write() -> void:
	if _target_node == null or not _base_captured:
		return
	var n3d := _target_node as Node3D

	# Sum transform deltas from all runtime effects
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

	# Register our deltas into the Target's ledger
	JuiceLedger.register_delta(n3d, self, "position", new_pos)
	JuiceLedger.register_delta(n3d, self, "rotation", new_rot)
	JuiceLedger.register_delta(n3d, self, "scale", new_scale)

	# Write: base + Σ(all source deltas) — single authoritative write via ledger.
	# Only flushes transform properties; appearance uses multiplicative accumulation below.
	JuiceLedger.flush(n3d, ["position", "rotation", "scale"])

	# Appearance: accumulate albedo/alpha factors from Juice3DAppearanceEffect effects.
	# Domain node owns one working material; effects only contribute factors.
	var combined_albedo := Color.WHITE
	var combined_alpha := 1.0
	var has_appearance := false
	for effect in _runtime_effects:
		if effect == null:
			continue
		var app_eff := effect as Juice3DAppearanceEffect
		if app_eff == null or not app_eff._contributes_appearance:
			continue
		combined_albedo.r *= app_eff._albedo_factor.r
		combined_albedo.g *= app_eff._albedo_factor.g
		combined_albedo.b *= app_eff._albedo_factor.b
		combined_alpha *= app_eff._alpha_factor
		has_appearance = true

	# Handle 3D OUTLINE via next_pass — read pre-computed values from effect
	var outline_amount := 0.0
	var outline_color := Color.WHITE
	var has_outline := false
	for effect in _runtime_effects:
		if effect == null:
			continue
		var app_eff := effect as Appearance3DJuiceEffect
		if app_eff == null:
			continue
		if app_eff.effect_type == Appearance3DJuiceEffect.AppearanceEffect.OUTLINE:
			# Effect computes amount + color (with flicker applied)
			outline_amount = app_eff._computed_outline_amount
			outline_color = app_eff._computed_outline_color
			has_outline = true

	# Sibling stacking with metadata-based natural base capture
	# Get shared natural base from target metadata (captured by first Juice3D)
	const META_KEY := &"juice_albedo_natural"
	var base_albedo: Color = _appearance_natural_albedo
	var base_alpha: float = _appearance_natural_alpha
	var mesh_inst := _find_mesh_on(_target_node)
	if mesh_inst != null and not mesh_inst.has_meta(META_KEY):
		# First Juice3D node - capture natural base and store in metadata
		mesh_inst.set_meta(META_KEY, {
			"albedo": _appearance_natural_albedo,
			"alpha": _appearance_natural_alpha
		})
	elif mesh_inst != null:
		# Subsequent Juice3D nodes - read natural base from metadata
		var meta = mesh_inst.get_meta(META_KEY)
		base_albedo = meta.get("albedo", Color.WHITE)
		base_alpha = meta.get("alpha", 1.0)

	# Scan all sibling Juice3D nodes on the same target, multiply contributions.
	# In STACK mode, Juice nodes are children of the target — scan target's children.
	var final_albedo := Color.WHITE
	var final_alpha := 1.0
	for child in _target_node.get_children():
		var j := child as Juice3D
		if j == null or j == self:
			continue
		if j._own_albedo_contribution != Color.WHITE or j._own_alpha_contribution != 1.0:
			final_albedo.r *= j._own_albedo_contribution.r
			final_albedo.g *= j._own_albedo_contribution.g
			final_albedo.b *= j._own_albedo_contribution.b
			final_alpha *= j._own_alpha_contribution

	# Write once: base * own_contribution * product of all sibling contributions
	if _ensure_appearance_working_mat():
		_appearance_working_mat.albedo_color = Color(
			base_albedo.r * combined_albedo.r * final_albedo.r,
			base_albedo.g * combined_albedo.g * final_albedo.g,
			base_albedo.b * combined_albedo.b * final_albedo.b,
			base_alpha * combined_alpha * final_alpha)
		# Handle 3D OUTLINE next_pass
		if has_outline and _ensure_outline_material():
			_outline_material.set_shader_parameter("amount", outline_amount)
			_outline_material.set_shader_parameter("outline_color", outline_color)
			_appearance_working_mat.next_pass = _outline_material
		else:
			_appearance_working_mat.next_pass = null

	# Update own contribution tracking
	if has_appearance:
		_own_albedo_contribution = combined_albedo
		_own_alpha_contribution = combined_alpha
	else:
		_own_albedo_contribution = Color.WHITE
		_own_alpha_contribution = 1.0

	# Check if all siblings are at identity (no active effects)
	var all_siblings_idle := true
	for child in _target_node.get_children():
		var j := child as Juice3D
		if j == null or j == self:
			continue
		if j._own_albedo_contribution != Color.WHITE or j._own_alpha_contribution != 1.0:
			all_siblings_idle = false
			break

	# If all siblings idle and we're idle, remove metadata and restore natural state
	if all_siblings_idle and not has_appearance and mesh_inst != null and mesh_inst.has_meta(META_KEY):
		mesh_inst.remove_meta(META_KEY)
		_clear_appearance_working_mat()


## Subtract this node's contributions — other nodes' contributions remain.
## Called before effects capture From/To references and before editor save.
func _temporarily_undo_visual() -> void:
	if _target_node == null or not _base_captured:
		return
	var n3d := _target_node as Node3D
	
	# Strip our transform deltas from the ledger temporarily without destroying it
	JuiceLedger.cleanup_source(n3d, self, false)
	
	# Apply absolute baseline position + sibling remaining deltas
	n3d.position = JuiceLedger.get_base(n3d, "position", n3d.position) + JuiceLedger.get_total(n3d, "position", Vector3.ZERO)
	n3d.rotation = JuiceLedger.get_base(n3d, "rotation", n3d.rotation) + JuiceLedger.get_total(n3d, "rotation", Vector3.ZERO)
	n3d.scale = JuiceLedger.get_base(n3d, "scale", n3d.scale) + JuiceLedger.get_total(n3d, "scale", Vector3.ZERO)

	# Restore natural material so editor save doesn't serialise working material
	if _appearance_setup and _appearance_mesh != null:
		_appearance_mesh.set_surface_override_material(0, _appearance_natural_mat)


## Re-add contributions after temporary undo.
func _temporarily_reapply_visual() -> void:
	if _target_node == null or not _base_captured:
		return
	# Re-apply transform deltas by flushing a fresh post-tick write.
	# This restores our deltas to the ledger and recalculates absolute values.
	# Re-install working material and recompute albedo.
	if _appearance_setup and _appearance_mesh != null and _appearance_working_mat != null:
		_appearance_mesh.set_surface_override_material(0, _appearance_working_mat)
	_post_tick_write()


# =============================================================================
# 3D APPEARANCE HELPERS
# =============================================================================

# Find the first MeshInstance3D on target or among its direct children.
func _find_mesh_on(target: Node) -> MeshInstance3D:
	if target is MeshInstance3D:
		return target as MeshInstance3D
	for child in target.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null


# Lazily set up the shared working material for albedo accumulation.
# Returns true if a valid StandardMaterial3D working copy was established.
func _ensure_appearance_working_mat() -> bool:
	if _appearance_working_mat != null:
		return true
	if _target_node == null:
		return false
	_appearance_mesh = _find_mesh_on(_target_node)
	if _appearance_mesh == null:
		return false
	_appearance_natural_mat = _appearance_mesh.get_active_material(0)
	var std_mat := _appearance_natural_mat as StandardMaterial3D
	if std_mat == null:
		return false
	_appearance_working_mat = std_mat.duplicate() as StandardMaterial3D
	_appearance_mesh.set_surface_override_material(0, _appearance_working_mat)
	_appearance_natural_albedo = std_mat.albedo_color
	_appearance_natural_alpha = std_mat.albedo_color.a
	_appearance_setup = true
	return true


# Restore natural material and clear working material reference.
func _clear_appearance_working_mat() -> void:
	if _appearance_mesh != null:
		_appearance_mesh.set_surface_override_material(0, _appearance_natural_mat)
	_appearance_working_mat = null
	_appearance_setup = false
	# Clear outline material
	if _outline_material != null:
		_outline_material = null


# Create and manage 3D outline material via next_pass
func _ensure_outline_material() -> bool:
	if _outline_material != null:
		return true
	if _appearance_mesh == null:
		return false
	# Create outline shader material
	var shader := load("res://addons/Juice_V1/Shaders/overlay_3d.gdshader") as Shader
	if shader == null:
		return false
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = shader
	return true


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
