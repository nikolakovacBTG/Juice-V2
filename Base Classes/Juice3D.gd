## Juice node for [Node3D] targets (MeshInstance3D, CharacterBody3D, etc.).
##
## Attach as a child of any [Node3D]. Assign a [JuiceRecipe] and configure
## triggers to animate position, scale, rotation, appearance, and more.
## Effects stack automatically when multiple Juice nodes share a target.

# ============================================================================
# WHAT: Juice node for Node3D targets (MeshInstance3D, CharacterBody3D, etc.).
# WHY: Validates parent is Node3D, connects Area3D/CollisionObject3D signals.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Implement effects — those are JuiceEffectBase resources in a recipe.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBase3D.svg")
class_name Juice3D
extends JuiceBase

# =============================================================================
# CONDITIONAL EXPORT SYSTEM (Override)
# =============================================================================

# Mutates trigger_on hint_string to show only events valid for the resolved
# trigger source type (Area3D, CollisionObject3D, etc.). Falls back to the
# full 3D event list when no source node is resolvable yet.
# Also narrows recipe to Juice3DRecipe so the inspector only offers the
# correct recipe type for this domain.
# Note: show/hide of properties is handled by JuiceEditorInspectorPlugin.
func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "trigger_on":
		var source: Node = _resolve_hint_source_node()
		property.hint_string = TriggerHintBuilder.build_hint(source, &"3D")
	if property.name == "recipe":
		property.hint_string = "Juice3DRecipe"


# =============================================================================
# INTERNAL STATE (Write Coordination)
# =============================================================================

# Whether base values have been captured at least once.
# Transform state is owned by the Centralized Metadata Ledger (LEDGER_KEY on target).
# Appearance uses Ledger-based factor tracking with domain-owned working material.
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
		if parent != null:
			JuiceLogger.warn(self, _get_domain_tag(),
					"Parent '%s' is not a Node3D node" % parent.name,
					debug_enabled)
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
	JuiceLogger.log_info(self, _get_domain_tag(),
			"Auto-connected to %s '%s' on %s" % [
			col_obj.get_class(), col_obj.name, TriggerEvent.keys()[trigger_on]],
			debug_enabled)

# =============================================================================
# DOMAIN VIRTUAL HOOK OVERRIDES (Write Coordination)
# =============================================================================

## Returns "3D" for structured log output.
func _get_domain_tag() -> String:
	return "3D"


## Capture target's natural position/rotation/scale and appearance base.
## Transform and appearance factor tracking go through the Shared Target Ledger.
## The working material lifecycle remains domain-specific.
func _capture_base_values() -> void:
	if _target_node == null or not _target_node is Node3D:
		return
	var n3d := _target_node as Node3D
	JuiceLedger.ensure(n3d, ["position", "rotation", "scale"])
	# Store natural albedo+alpha packed as Color for Ledger-based factor tracking.
	# The Ledger uses this as the base for multiplicative accumulation.
	# We use a synthetic "_appearance_factor" key since there's no direct node property.
	var ledger := JuiceLedger.ensure(n3d, [])
	if not ledger["base"].has("_appearance_factor"):
		# Lazily capture the natural albedo+alpha once the working mat is set up.
		# For now, seed with WHITE — _ensure_appearance_working_mat() will update.
		ledger["base"]["_appearance_factor"] = Color.WHITE
	_base_captured = true
	JuiceLogger.log_capture(self, "3D", "position", n3d.position, debug_enabled)
	JuiceLogger.log_capture(self, "3D", "rotation", n3d.rotation, debug_enabled)
	JuiceLogger.log_capture(self, "3D", "scale", n3d.scale, debug_enabled)


# Sequencer: seed the Ledger for an arbitrary Node3D target before warmup
# reads it via JuiceLedger.get_base_dict(). Mirrors the JuiceControl override.
func _seq_ensure_ledger_for_target(target: Node) -> void:
	if target == null or not target is Node3D:
		return
	JuiceLedger.ensure(target, ["position", "rotation", "scale"])


## Detect external displacement of the target (game logic, tweens, etc.).
## The Metadata Ledger's external-displacement check handles all tracked props.
func _pre_tick() -> void:
	if _target_node == null or not _base_captured:
		return
	var n3d := _target_node as Node3D
	var old_pos: Vector3 = JuiceLedger.get_base(n3d, "position", n3d.position)
	JuiceLedger.sync_base_if_moved(n3d, ["position", "rotation", "scale"])
	var new_pos: Vector3 = JuiceLedger.get_base(n3d, "position", n3d.position)
	if old_pos != new_pos:
		JuiceLogger.log_aggregation("3D", n3d.name, "external_move",
				old_pos, new_pos - old_pos, new_pos, debug_enabled)


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

	# Flush all registered properties — transform (additive) and any property
	# effects registered dynamically via PropertyJuiceEffectBase.
	# Appearance (modulate/material) uses multiplicative accumulation below, handled separately.
	JuiceLedger.flush(n3d)

	var base_pos: Vector3 = JuiceLedger.get_base(n3d, "position", Vector3.ZERO)
	var base_rot: Vector3 = JuiceLedger.get_base(n3d, "rotation", Vector3.ZERO)
	var base_scale: Vector3 = JuiceLedger.get_base(n3d, "scale", Vector3.ONE)
	var total_pos: Vector3 = JuiceLedger.get_total(n3d, "position", Vector3.ZERO)
	var total_rot: Vector3 = JuiceLedger.get_total(n3d, "rotation", Vector3.ZERO)
	var total_scale: Vector3 = JuiceLedger.get_total(n3d, "scale", Vector3.ZERO)

	JuiceLogger.log_aggregation("3D", n3d.name, "position",
			base_pos, new_pos, base_pos + total_pos, debug_enabled)
	JuiceLogger.log_aggregation("3D", n3d.name, "rotation",
			base_rot, new_rot, base_rot + total_rot, debug_enabled)
	JuiceLogger.log_aggregation("3D", n3d.name, "scale",
			base_scale, new_scale, base_scale + total_scale, debug_enabled)

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

	# Appearance: use Ledger-based factor tracking for sibling stacking.
	# 3D albedo is a sub-resource property on the working material, so we
	# can't use Ledger.flush() (which calls target.set()). Instead, we use
	# register_delta for per-source tracking and get_total for the combined
	# factor, then write to the working material manually.
	#
	# Store as Color(albedo.r, albedo.g, albedo.b, alpha) to pack both channels.
	var appearance_factor := Color(combined_albedo.r, combined_albedo.g, combined_albedo.b, combined_alpha)
	JuiceLedger.register_delta(n3d, self, "_appearance_factor", appearance_factor)

	# Read the combined factor from all sibling Juice3D nodes on this target.
	# The Ledger multiplies Color deltas automatically (multiplicative accumulation).
	var total_factor: Color = JuiceLedger.get_total(n3d, "_appearance_factor", Color.WHITE)
	JuiceLogger.log_info(self, "3D",
			"post_tick: appearance this_node=albedo(%.2f,%.2f,%.2f) alpha=%.2f total_factor=albedo(%.2f,%.2f,%.2f) alpha=%.2f" % [
			combined_albedo.r, combined_albedo.g, combined_albedo.b, combined_alpha,
			total_factor.r, total_factor.g, total_factor.b, total_factor.a],
			debug_enabled)

	# Read base albedo/alpha from the Ledger (captured at ensure time).
	var base_app: Color = JuiceLedger.get_base(n3d, "_appearance_factor", Color.WHITE)
	var base_albedo := Color(base_app.r, base_app.g, base_app.b, 1.0)
	var base_alpha := base_app.a

	# Write to working material: base × Πfactors (total from all sources)
	if _ensure_appearance_working_mat():
		_appearance_working_mat.albedo_color = Color(
			base_albedo.r * total_factor.r,
			base_albedo.g * total_factor.g,
			base_albedo.b * total_factor.b,
			base_alpha * total_factor.a)
		# Handle 3D OUTLINE next_pass
		if has_outline and _ensure_outline_material():
			_outline_material.set_shader_parameter("amount", outline_amount)
			_outline_material.set_shader_parameter("outline_color", outline_color)
			_appearance_working_mat.next_pass = _outline_material
		else:
			_appearance_working_mat.next_pass = null

	# If all sources are at identity, clean up working material
	if total_factor == Color.WHITE and not has_outline:
		_clear_appearance_working_mat()


## Subtract this node's contributions — other nodes' contributions remain.
## Called before effects capture From/To references and before editor save.
func _temporarily_undo_visual() -> void:
	if _target_node == null or not _base_captured:
		return
	var n3d := _target_node as Node3D
	# Sum deltas being stripped so the log shows exactly what is removed.
	var strip_pos := Vector3.ZERO
	var strip_rot := Vector3.ZERO
	var strip_scale := Vector3.ZERO
	for effect in _runtime_effects:
		var te := effect as Juice3DTransformEffect
		if te == null:
			continue
		if te._contributes_position:
			strip_pos += te._pos_delta
		if te._contributes_rotation:
			strip_rot += te._rot_delta
		if te._contributes_scale:
			strip_scale += te._scale_delta
	JuiceLogger.log_info(self, "3D",
			"undo_visual '%s': stripping pos=%s rot=%s scale=%s" % [
			n3d.name, strip_pos, strip_rot, strip_scale],
			debug_enabled)

	# Strip our transform deltas from the ledger temporarily without destroying it
	JuiceLedger.cleanup_source(n3d, self, false)

	# Flush all remaining contributions — Ledger handles transform properties
	# and any property effects registered dynamically via PropertyJuiceEffectBase.
	JuiceLedger.flush(n3d)

	# Restore natural material so editor save doesn't serialise working material
	if _appearance_setup and _appearance_mesh != null:
		_appearance_mesh.set_surface_override_material(0, _appearance_natural_mat)


## Re-add contributions after temporary undo.
func _temporarily_reapply_visual() -> void:
	if _target_node == null or not _base_captured:
		return
	var n3d := _target_node as Node3D
	# Re-apply transform deltas by flushing a fresh post-tick write.
	# This restores our deltas to the ledger and recalculates absolute values.
	# Re-install working material and recompute albedo.
	if _appearance_setup and _appearance_mesh != null and _appearance_working_mat != null:
		_appearance_mesh.set_surface_override_material(0, _appearance_working_mat)
	_post_tick_write()
	JuiceLogger.log_info(self, "3D",
			"reapply_visual '%s': restored pos=%s rot=%s scale=%s" % [
			n3d.name, n3d.position, n3d.rotation, n3d.scale],
			debug_enabled)


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
	# Update the Ledger base with real natural albedo+alpha (was seeded with WHITE).
	if _target_node != null and JuiceLedger.has_ledger(_target_node):
		JuiceLedger.force_base(_target_node, "_appearance_factor", Color(
			_appearance_natural_albedo.r, _appearance_natural_albedo.g,
			_appearance_natural_albedo.b, _appearance_natural_alpha))
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
	var shader := load("res://addons/Juice_V2/Shaders/overlay_3d.gdshader") as Shader
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
