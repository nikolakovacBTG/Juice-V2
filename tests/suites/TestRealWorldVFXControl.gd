## TestRealWorldVFXControl.gd
## ============================================================================
## WHAT: Realistic integration tests for VFXControlJuiceEffect in a live
##       JuiceControl pipeline with real Button/Control targets.
## WHY:  Control domain has unique requirements: particles must reposition to
##       ctrl.global_position + ctrl.size/2 (not ctrl.global_position alone).
##       Spawned instances use CanvasItem for rotation access. These tests
##       guard against the type-access crashes the monolithic VFXJuiceEffect
##       produced when it tried to call .global_rotation on a Button.
## SYSTEM: Tests (tests/suites/)
## DOES NOT: Test 2D/3D domains — see TestRealWorldVFX2D / TestRealWorldVFX3D.
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "real_world_vfx_control"


func get_test_methods() -> Array[String]:
	return [
		"test_trigger_existing_fires_particle_on_control_target",
		"test_trigger_existing_repositions_particle_to_control_center",
		"test_instantiate_new_adds_instance_as_child_of_control",
		"test_instantiate_new_no_crash_null_scene",
		"test_instantiate_new_custom_position_spawns_extra_instance",
		"test_vfx_stacked_with_transform_control_no_crash",
		"test_vfx_appears_in_control_recipe_whitelist",
	]


# =============================================================================
# RIG BUILDERS
# =============================================================================

# Build a Button at a known size with a GPUParticles2D child.
# The Button is placed in a VBoxContainer so size is assigned by layout.
# Returns [container, button, particles].
func _create_control_target_with_particles() -> Array:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(200.0, 100.0)
	_runner.add_child(vbox)

	var btn := Button.new()
	btn.text = "VFX Target"
	btn.custom_minimum_size = Vector2(160.0, 40.0)
	vbox.add_child(btn)

	# Force layout to run so btn.size is populated before we read it.
	await wait_frames(3)

	var particles := GPUParticles2D.new()
	particles.emitting = false
	btn.add_child(particles)
	return [vbox, btn, particles]


# Build a minimal PackedScene containing a GPUParticles2D for spawn tests.
func _create_vfx_packed_scene() -> PackedScene:
	var root := Node2D.new()
	root.name = "VFXRoot"
	var p := GPUParticles2D.new()
	p.name = "Particles"
	p.emitting = false
	root.add_child(p)
	p.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.queue_free()
	return scene


# Build a JuiceControl node with a VFXControlJuiceEffect in TRIGGER_EXISTING mode.
func _create_juice_control_trigger(btn: Button) -> JuiceControl:
	var effect := VFXControlJuiceEffect.new()
	effect.vfx_mode = VFXJuiceEffectBase.VFXMode.TRIGGER_EXISTING
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.1

	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	btn.add_child(juice)
	return juice


# =============================================================================
# TESTS — TRIGGER_EXISTING
# =============================================================================

func test_trigger_existing_fires_particle_on_control_target() -> void:
	var result := await _create_control_target_with_particles()
	var vbox: VBoxContainer = result[0]
	var btn: Button = result[1]
	var particles: GPUParticles2D = result[2]

	var juice := _create_juice_control_trigger(btn)
	await wait_frames(2)

	juice.animate_in()
	await wait_frames(3)

	assert_true(particles.emitting,
		"TRIGGER_EXISTING: particle.emitting true after animate_in on Button")
	await cleanup(vbox)


func test_trigger_existing_repositions_particle_to_control_center() -> void:
	var result := await _create_control_target_with_particles()
	var vbox: VBoxContainer = result[0]
	var btn: Button = result[1]
	var particles: GPUParticles2D = result[2]
	particles.position = Vector2.ZERO  # ensure it starts at origin

	var juice := _create_juice_control_trigger(btn)
	await wait_frames(2)

	juice.animate_in()
	await wait_frames(3)

	# Particle should have moved to the visual center of the button.
	var expected := btn.global_position + btn.size / 2.0
	assert_approx_vec2(particles.global_position, expected,
		"TRIGGER_EXISTING: particle repositioned to button visual center", 2.0)
	await cleanup(vbox)


# =============================================================================
# TESTS — INSTANTIATE_NEW
# =============================================================================

func test_instantiate_new_adds_instance_as_child_of_control() -> void:
	var result := await _create_control_target_with_particles()
	var vbox: VBoxContainer = result[0]
	var btn: Button = result[1]

	var effect := VFXControlJuiceEffect.new()
	effect.vfx_mode = VFXJuiceEffectBase.VFXMode.INSTANTIATE_NEW
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.1

	effect.spawn_scenes.append(_create_vfx_packed_scene())

	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	btn.add_child(juice)
	await wait_frames(2)

	var children_before := btn.get_child_count()
	juice.animate_in()
	await wait_frames(3)

	assert_true(btn.get_child_count() > children_before,
		"INSTANTIATE_NEW: instance added as child of Button")
	await cleanup(vbox)


func test_instantiate_new_no_crash_null_scene() -> void:
	var result := await _create_control_target_with_particles()
	var vbox: VBoxContainer = result[0]
	var btn: Button = result[1]

	var effect := VFXControlJuiceEffect.new()
	effect.vfx_mode = VFXJuiceEffectBase.VFXMode.INSTANTIATE_NEW
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.1
	effect.spawn_scenes.append(null)

	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	btn.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_frames(3)
	assert_true(true, "NULL_SCENE: animate_in with null scene on Button did not crash")
	await cleanup(vbox)


func test_instantiate_new_custom_position_spawns_extra_instance() -> void:
	var result := await _create_control_target_with_particles()
	var vbox: VBoxContainer = result[0]
	var btn: Button = result[1]

	var effect := VFXControlJuiceEffect.new()
	effect.vfx_mode = VFXJuiceEffectBase.VFXMode.INSTANTIATE_NEW
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.1

	effect.spawn_scenes.append(_create_vfx_packed_scene())

	effect.use_custom_positions = true
	effect.custom_positions.append(Vector2(400.0, 300.0))

	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	btn.add_child(juice)
	await wait_frames(2)

	var children_before := btn.get_child_count()
	juice.animate_in()
	await wait_frames(3)

	var new_children := btn.get_child_count() - children_before
	assert_true(new_children >= 2,
		"CUSTOM_POS: 2 instances spawned on Button (location + custom), got %d" % new_children)
	await cleanup(vbox)


# =============================================================================
# STACKING AND REGISTRATION
# =============================================================================

func test_vfx_stacked_with_transform_control_no_crash() -> void:
	var result := await _create_control_target_with_particles()
	var vbox: VBoxContainer = result[0]
	var btn: Button = result[1]

	var vfx_effect := VFXControlJuiceEffect.new()
	vfx_effect.vfx_mode = VFXJuiceEffectBase.VFXMode.TRIGGER_EXISTING
	vfx_effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	vfx_effect.duration_in = 0.2

	var transform_effect := TransformControlJuiceEffect.new()
	transform_effect.duration_in = 0.2
	transform_effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY

	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(vfx_effect)
	recipe.effects.append(transform_effect)

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	btn.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_frames(5)
	assert_true(true, "STACKING: VFXControl + TransformControl on same Button did not crash")
	await cleanup(vbox)


func test_vfx_appears_in_control_recipe_whitelist() -> void:
	var recipe := JuiceControlRecipe.new()
	var whitelist: String = recipe._CONCRETE_EFFECTS
	assert_true(whitelist.contains("VFXControlJuiceEffect"),
		"REGISTRY: VFXControlJuiceEffect is in JuiceControlRecipe._CONCRETE_EFFECTS")
