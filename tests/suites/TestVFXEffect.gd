## TestVFXEffect.gd
## Tests for VFXJuiceEffect — particle triggering, no delta output, cleanup.
##
## Coverage:
##   - Instantiation and base type
##   - Registered in Juice2D, JuiceControl, Juice3D recipe whitelists
##   - _apply_effect writes nothing to target (pure side-effect)
##   - CHILDREN mode: particles discovered and emitting when _on_animate_start called directly
##   - CHILDREN mode: particles stopped by _on_animate_out_complete
##   - CHILDREN mode: intensity_multiplier scales particle amounts
##   - CHILDREN mode: kill_previous=false skips already-emitting particles
##   - EXTERNAL_SCENE mode: null vfx_scene does not crash
##   - cull_strategy shown/hidden based on max_living_instances
##   - Configuration warnings for EXTERNAL_SCENE without vfx_scene
##   - _restore_to_natural stops particles
##
## NOTE: Effects are Resources cloned by JuiceBase at runtime. Tests that
##   inspect internal state (_particle_children etc.) call effect methods
##   directly rather than going through the Juice node, which avoids the
##   clone-vs-original reference issue.
extends JuiceTestSuite


func get_suite_name() -> String:
	return "vfx_effect"


func get_test_methods() -> Array[String]:
	return [
		"test_vfx_instantiates",
		"test_vfx_registered_in_2d_recipe",
		"test_vfx_registered_in_control_recipe",
		"test_vfx_registered_in_3d_recipe",
		"test_apply_effect_writes_nothing_to_target",
		"test_children_mode_discovers_particles",
		"test_children_mode_triggers_particles_on_animate_start",
		"test_children_mode_stops_particles_on_animate_out",
		"test_intensity_multiplier_scales_amount",
		"test_kill_previous_false_skips_emitting_particle",
		"test_external_scene_missing_vfx_scene_does_not_crash",
		"test_cull_strategy_visible_when_max_set",
		"test_cull_strategy_hidden_when_max_zero",
		"test_config_warning_external_scene_no_scene_assigned",
		"test_config_warning_clear_when_scene_assigned",
		"test_restore_to_natural_stops_particles",
	]


# =============================================================================
# HELPERS
# =============================================================================

# Build a target Node2D with one GPUParticles2D child.
# Returns [target, particle].
func _create_target_with_particle() -> Array:
	var target := create_2d_target()
	var particle := GPUParticles2D.new()
	particle.name = "TestParticle"
	particle.amount = 10
	particle.one_shot = true
	particle.emitting = false
	particle.process_material = ParticleProcessMaterial.new()
	target.add_child(particle)
	await wait_frames(1)
	return [target, particle]


# Build a VFXJuiceEffect in CHILDREN mode with a fake _host_node set.
# The effect is used directly (not through JuiceBase) to avoid clone issues.
func _create_direct_effect(host: Node) -> VFXJuiceEffect:
	var effect := VFXJuiceEffect.new()
	effect.vfx_source = VFXJuiceEffect.SourceMode.CHILDREN
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.05
	# Inject host so JuiceLogger and tree access don't null-crash.
	effect._host_node = host
	return effect


# =============================================================================
# INSTANTIATION + REGISTRATION
# =============================================================================

func test_vfx_instantiates() -> void:
	var effect := VFXJuiceEffect.new()
	assert_true(effect != null, "VFXJuiceEffect should instantiate")
	assert_true(effect is JuiceEffectBase, "should extend JuiceEffectBase")


func test_vfx_registered_in_2d_recipe() -> void:
	var recipe := Juice2DRecipe.new()
	var effect := VFXJuiceEffect.new()
	recipe.effects.append(effect)
	assert_equal(recipe.effects.size(), 1,
		"VFXJuiceEffect accepted in Juice2DRecipe")


func test_vfx_registered_in_control_recipe() -> void:
	var recipe := JuiceControlRecipe.new()
	var effect := VFXJuiceEffect.new()
	recipe.effects.append(effect)
	assert_equal(recipe.effects.size(), 1,
		"VFXJuiceEffect accepted in JuiceControlRecipe")


func test_vfx_registered_in_3d_recipe() -> void:
	var recipe := Juice3DRecipe.new()
	var effect := VFXJuiceEffect.new()
	recipe.effects.append(effect)
	assert_equal(recipe.effects.size(), 1,
		"VFXJuiceEffect accepted in Juice3DRecipe")


# =============================================================================
# DELTA PURITY
# =============================================================================

func test_apply_effect_writes_nothing_to_target() -> void:
	var target := create_2d_target()
	var effect := VFXJuiceEffect.new()
	var before_pos: Vector2 = target.position
	var before_scale: Vector2 = target.scale

	effect._apply_effect(1.0, target)
	effect._apply_effect(0.5, target)
	effect._apply_effect(0.0, target)

	assert_approx_vec2(target.position, before_pos,
		"position must not change after _apply_effect", 0.001)
	assert_approx_vec2(target.scale, before_scale,
		"scale must not change after _apply_effect", 0.001)
	await cleanup(target)


# =============================================================================
# CHILDREN MODE — direct effect calls to avoid clone issues
# =============================================================================

func test_children_mode_discovers_particles() -> void:
	var rig := await _create_target_with_particle()
	var target: Node = rig[0]
	var effect := _create_direct_effect(target)

	# Call _on_animate_start directly — this is what the runtime clone would do.
	effect._on_animate_start(target)

	assert_equal(effect._particle_children.size(), 1,
		"should discover 1 GPUParticles2D child")
	await cleanup(target)


func test_children_mode_triggers_particles_on_animate_start() -> void:
	var rig := await _create_target_with_particle()
	var target: Node = rig[0]
	var particle: GPUParticles2D = rig[1]
	var effect := _create_direct_effect(target)

	assert_false(particle.emitting, "particle starts not emitting")
	effect._on_animate_start(target)

	assert_true(particle.emitting, "particle emitting after _on_animate_start")
	await cleanup(target)


func test_children_mode_stops_particles_on_animate_out() -> void:
	var rig := await _create_target_with_particle()
	var target: Node = rig[0]
	var particle: GPUParticles2D = rig[1]
	var effect := _create_direct_effect(target)

	effect._on_animate_start(target)
	assert_true(particle.emitting, "particle emitting after start")

	effect._on_animate_out_complete(target)
	assert_false(particle.emitting, "particle stops after _on_animate_out_complete")
	await cleanup(target)


func test_intensity_multiplier_scales_amount() -> void:
	var rig := await _create_target_with_particle()
	var target: Node = rig[0]
	var particle: GPUParticles2D = rig[1]
	var effect := _create_direct_effect(target)
	effect.intensity_multiplier = 2.0

	effect._on_animate_start(target)
	assert_equal(particle.amount, 20,
		"intensity 2.0 doubles amount from 10 to 20")
	await cleanup(target)


func test_kill_previous_false_skips_emitting_particle() -> void:
	var rig := await _create_target_with_particle()
	var target: Node = rig[0]
	var particle: GPUParticles2D = rig[1]
	var effect := _create_direct_effect(target)
	effect.kill_previous_on_trigger = false
	effect.intensity_multiplier = 2.0
	particle.emitting = true  # Already emitting before trigger.

	effect._on_animate_start(target)
	# Already-emitting particle is skipped — amount NOT scaled.
	assert_equal(particle.amount, 10,
		"amount unchanged — particle skipped (already emitting, kill_previous=false)")
	await cleanup(target)


# =============================================================================
# EXTERNAL SCENE MODE
# =============================================================================

func test_external_scene_missing_vfx_scene_does_not_crash() -> void:
	var target := create_2d_target()
	var effect := VFXJuiceEffect.new()
	effect.vfx_source = VFXJuiceEffect.SourceMode.EXTERNAL_SCENE
	effect.vfx_scene = null
	effect._host_node = target

	# Should log a warning and return without crashing.
	effect._on_animate_start(target)
	assert_true(true, "no crash when vfx_scene is null")
	await cleanup(target)


# =============================================================================
# INSPECTOR CONDITIONAL EXPORTS
# =============================================================================

func test_cull_strategy_visible_when_max_set() -> void:
	var effect := VFXJuiceEffect.new()
	effect.max_living_instances = 3
	var props := effect._get_property_list()
	var found := false
	for p in props:
		if p.name == "cull_strategy":
			found = true
			break
	assert_true(found, "cull_strategy visible when max_living_instances > 0")


func test_cull_strategy_hidden_when_max_zero() -> void:
	var effect := VFXJuiceEffect.new()
	effect.max_living_instances = 0
	var props := effect._get_property_list()
	var found := false
	for p in props:
		if p.name == "cull_strategy":
			found = true
			break
	assert_false(found, "cull_strategy hidden when max_living_instances == 0")


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func test_config_warning_external_scene_no_scene_assigned() -> void:
	var effect := VFXJuiceEffect.new()
	effect.vfx_source = VFXJuiceEffect.SourceMode.EXTERNAL_SCENE
	effect.vfx_scene = null
	var warnings := effect._get_configuration_warnings()
	assert_true(warnings.size() > 0,
		"warning expected when EXTERNAL_SCENE has no vfx_scene")


func test_config_warning_clear_when_scene_assigned() -> void:
	var effect := VFXJuiceEffect.new()
	effect.vfx_source = VFXJuiceEffect.SourceMode.EXTERNAL_SCENE
	effect.vfx_scene = PackedScene.new()
	var warnings := effect._get_configuration_warnings()
	assert_equal(warnings.size(), 0,
		"no warning when vfx_scene is assigned")


# =============================================================================
# RESTORE TO NATURAL
# =============================================================================

func test_restore_to_natural_stops_particles() -> void:
	var rig := await _create_target_with_particle()
	var target: Node = rig[0]
	var particle: GPUParticles2D = rig[1]
	var effect := _create_direct_effect(target)

	effect._on_animate_start(target)
	assert_true(particle.emitting, "particle emitting before restore")

	effect._restore_to_natural(target)
	assert_false(particle.emitting, "particle stops after _restore_to_natural")
	await cleanup(target)
