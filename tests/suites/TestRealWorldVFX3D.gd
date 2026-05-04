## TestRealWorldVFX3D.gd
## ============================================================================
## WHAT: Realistic integration tests for VFX3DJuiceEffect in a live Juice3D
##       pipeline with real Node3D targets and GPUParticles3D.
## WHY:  3D domain has different transform access patterns (Node3D.global_position,
##       global_rotation as Vector3) and particle types (GPUParticles3D/CPUParticles3D).
##       3D particles inherit parent transform naturally — no repositioning needed.
##       These tests guard against the type-access crashes the monolithic effect
##       produced when using global_rotation on mixed-domain targets.
## SYSTEM: Tests (tests/suites/)
## DOES NOT: Test 2D/Control domains — see TestRealWorldVFX2D / TestRealWorldVFXControl.
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "real_world_vfx_3d"


func get_test_methods() -> Array[String]:
	return [
		"test_trigger_existing_fires_particle_on_3d_target",
		"test_trigger_existing_two_independent_targets_both_fire",
		"test_instantiate_new_adds_instance_as_child_of_3d_target",
		"test_instantiate_new_no_crash_null_scene",
		"test_instantiate_new_custom_position_spawns_extra_instance",
		"test_vfx_stacked_with_transform_3d_no_crash",
		"test_vfx_appears_in_3d_recipe_whitelist",
	]


# =============================================================================
# RIG BUILDERS
# =============================================================================

# Build a Node3D at a known 3D position with a GPUParticles3D child.
# Returns [node3d, particles3d].
func _create_3d_target_with_particles(pos: Vector3) -> Array:
	var target := Node3D.new()
	target.position = pos
	_runner.add_child(target)
	await wait_frames(1)

	var particles := GPUParticles3D.new()
	particles.emitting = false
	target.add_child(particles)
	return [target, particles]


# Build a minimal PackedScene containing a Node3D with a GPUParticles3D child.
func _create_vfx_packed_scene_3d() -> PackedScene:
	var root := Node3D.new()
	root.name = "VFXRoot3D"
	var p := GPUParticles3D.new()
	p.name = "Particles3D"
	p.emitting = false
	root.add_child(p)
	p.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.queue_free()
	return scene


# Build a Juice3D node with a VFX3DJuiceEffect in TRIGGER_EXISTING mode.
func _create_juice3d_trigger(target: Node3D) -> Juice3D:
	var effect := VFX3DJuiceEffect.new()
	effect.vfx_mode = VFXJuiceEffectBase.VFXMode.TRIGGER_EXISTING
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.1

	var recipe := Juice3DRecipe.new()
	recipe.effects.append(effect)

	var juice := Juice3D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	target.add_child(juice)
	return juice


# =============================================================================
# TESTS — TRIGGER_EXISTING
# =============================================================================

func test_trigger_existing_fires_particle_on_3d_target() -> void:
	var result := await _create_3d_target_with_particles(Vector3(1.0, 0.0, 0.0))
	var target: Node3D = result[0]
	var particles: GPUParticles3D = result[1]

	var juice := _create_juice3d_trigger(target)
	await wait_frames(2)

	juice.animate_in()
	await wait_frames(3)

	assert_true(particles.emitting,
		"TRIGGER_EXISTING: GPUParticles3D.emitting true after animate_in on Node3D")
	await cleanup(target)


func test_trigger_existing_two_independent_targets_both_fire() -> void:
	var r0 := await _create_3d_target_with_particles(Vector3(0.0, 0.0, 0.0))
	var t0: Node3D = r0[0]
	var p0: GPUParticles3D = r0[1]

	var r1 := await _create_3d_target_with_particles(Vector3(3.0, 0.0, 0.0))
	var t1: Node3D = r1[0]
	var p1: GPUParticles3D = r1[1]

	var j0 := _create_juice3d_trigger(t0)
	var j1 := _create_juice3d_trigger(t1)
	await wait_frames(2)

	j0.animate_in()
	j1.animate_in()
	await wait_frames(3)

	assert_true(p0.emitting, "MULTI-TARGET: t0 particle fires")
	assert_true(p1.emitting, "MULTI-TARGET: t1 particle fires")
	await cleanup(t0)
	await cleanup(t1)


# =============================================================================
# TESTS — INSTANTIATE_NEW
# =============================================================================

func test_instantiate_new_adds_instance_as_child_of_3d_target() -> void:
	var target := Node3D.new()
	target.position = Vector3(2.0, 0.0, 0.0)
	_runner.add_child(target)
	await wait_frames(2)

	var effect := VFX3DJuiceEffect.new()
	effect.vfx_mode = VFXJuiceEffectBase.VFXMode.INSTANTIATE_NEW
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.1

	effect.spawn_scenes.append(_create_vfx_packed_scene_3d())

	var recipe := Juice3DRecipe.new()
	recipe.effects.append(effect)

	var juice := Juice3D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	var children_before := target.get_child_count()
	juice.animate_in()
	await wait_frames(3)

	assert_true(target.get_child_count() > children_before,
		"INSTANTIATE_NEW: Node3D instance added as child of target")
	await cleanup(target)


func test_instantiate_new_no_crash_null_scene() -> void:
	var target := Node3D.new()
	_runner.add_child(target)
	await wait_frames(1)

	var effect := VFX3DJuiceEffect.new()
	effect.vfx_mode = VFXJuiceEffectBase.VFXMode.INSTANTIATE_NEW
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.1
	effect.spawn_scenes.append(null)

	var recipe := Juice3DRecipe.new()
	recipe.effects.append(effect)

	var juice := Juice3D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_frames(3)
	assert_true(true, "NULL_SCENE: animate_in with null scene on Node3D did not crash")
	await cleanup(target)


func test_instantiate_new_custom_position_spawns_extra_instance() -> void:
	var target := Node3D.new()
	target.position = Vector3(0.0, 1.0, 0.0)
	_runner.add_child(target)
	await wait_frames(2)

	var effect := VFX3DJuiceEffect.new()
	effect.vfx_mode = VFXJuiceEffectBase.VFXMode.INSTANTIATE_NEW
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.1

	effect.spawn_scenes.append(_create_vfx_packed_scene_3d())

	effect.use_custom_positions = true
	effect.custom_positions.append(Vector3(5.0, 5.0, 5.0))

	var recipe := Juice3DRecipe.new()
	recipe.effects.append(effect)

	var juice := Juice3D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	var children_before := target.get_child_count()
	juice.animate_in()
	await wait_frames(3)

	var new_children := target.get_child_count() - children_before
	assert_true(new_children >= 2,
		"CUSTOM_POS 3D: 2 instances spawned (location + custom), got %d" % new_children)
	await cleanup(target)


# =============================================================================
# STACKING AND REGISTRATION
# =============================================================================

func test_vfx_stacked_with_transform_3d_no_crash() -> void:
	var result := await _create_3d_target_with_particles(Vector3(0.0, 0.0, 0.0))
	var target: Node3D = result[0]

	var vfx_effect := VFX3DJuiceEffect.new()
	vfx_effect.vfx_mode = VFXJuiceEffectBase.VFXMode.TRIGGER_EXISTING
	vfx_effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	vfx_effect.duration_in = 0.2

	var transform_effect := Transform3DJuiceEffect.new()
	transform_effect.duration_in = 0.2
	transform_effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY

	var recipe := Juice3DRecipe.new()
	recipe.effects.append(vfx_effect)
	recipe.effects.append(transform_effect)

	var juice := Juice3D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_frames(5)
	assert_true(true, "STACKING: VFX3D + Transform3D on same Node3D did not crash")
	await cleanup(target)


func test_vfx_appears_in_3d_recipe_whitelist() -> void:
	var recipe := Juice3DRecipe.new()
	var whitelist: String = recipe._CONCRETE_EFFECTS
	assert_true(whitelist.contains("VFX3DJuiceEffect"),
		"REGISTRY: VFX3DJuiceEffect is in Juice3DRecipe._CONCRETE_EFFECTS")
