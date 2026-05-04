## TestRealWorldVFX2D.gd
## ============================================================================
## WHAT: Realistic integration tests for VFX2DJuiceEffect in a live Juice2D pipeline.
## WHY:  Headless unit tests don't catch pipeline-specific bugs (null host_node,
##       wrong particle positioning, recipe registration failures). These tests
##       build real Node2D rigs, attach real Juice2D nodes, and drive them through
##       the actual animate_start path.
## SYSTEM: Tests (tests/suites/)
## DOES NOT: Test visual particle output — headless mode has no renderer.
##           Tests verify node lifecycle: particle discovered, emitting flag set,
##           instance added to tree, instance positioned correctly.
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "real_world_vfx_2d"


func get_test_methods() -> Array[String]:
	return [
		"test_trigger_existing_fires_particle_on_2d_target",
		"test_trigger_existing_multiple_targets_all_fire",
		"test_trigger_existing_repositions_particle_to_target_global_pos",
		"test_instantiate_new_adds_instance_as_child_of_target",
		"test_instantiate_new_null_scene_no_crash",
		"test_instantiate_new_custom_position_spawns_extra_instance",
		"test_vfx_stacked_with_transform_no_crash",
		"test_vfx_appears_in_2d_recipe_whitelist",
	]


# =============================================================================
# RIG BUILDERS
# =============================================================================

# Build a Node2D at a known position with a GPUParticles2D child.
# Returns [node2d, particles2d].
func _create_2d_target_with_particles(pos: Vector2) -> Array:
	var target := Node2D.new()
	target.position = pos
	_runner.add_child(target)
	# Force it into the tree so global_position resolves correctly.
	await wait_frames(1)

	var particles := GPUParticles2D.new()
	particles.emitting = false
	target.add_child(particles)
	return [target, particles]


# Build a Juice2D node with a VFX2DJuiceEffect wired to trigger_targets.
func _create_juice2d_trigger_existing(target: Node2D, extra_targets: Array[NodePath] = []) -> Juice2D:
	var effect := VFX2DJuiceEffect.new()
	effect.vfx_mode = VFXJuiceEffectBase.VFXMode.TRIGGER_EXISTING
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.1

	# Empty trigger_targets defaults to the juice's own animated target.
	# Append extra NodePaths for multi-target tests.
	for path in extra_targets:
		effect.trigger_targets.append(path)

	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	target.add_child(juice)
	return juice


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


# =============================================================================
# TESTS — TRIGGER_EXISTING
# =============================================================================

func test_trigger_existing_fires_particle_on_2d_target() -> void:
	var result := await _create_2d_target_with_particles(Vector2(100.0, 200.0))
	var target: Node2D = result[0]
	var particles: GPUParticles2D = result[1]

	var juice := _create_juice2d_trigger_existing(target)
	await wait_frames(2)

	juice.animate_in()
	await wait_frames(3)

	assert_true(particles.emitting,
		"TRIGGER_EXISTING: particle.emitting should be true after animate_in")
	await cleanup(target)


func test_trigger_existing_multiple_targets_all_fire() -> void:
	# Tests that ONE VFX effect with two trigger_targets entries fires both.
	# Node names are set explicitly so we can compute the relative NodePath
	# before add_child triggers the recipe clone at _ready().
	#
	# Scene structure after setup:
	#   _runner/
	#     Target_A/           (target, has p0)
	#       Juice2D            (host_node; path to Target_B = "../../Target_B")
	#     Target_B/           (target2, has p1)
	#
	# NodePath "../../Target_B" resolves correctly from the Juice2D host_node.

	var r0 := await _create_2d_target_with_particles(Vector2(100.0, 100.0))
	var target: Node2D = r0[0]
	var p0: GPUParticles2D = r0[1]
	target.name = "Target_A"

	var r1 := await _create_2d_target_with_particles(Vector2(300.0, 100.0))
	var target2: Node2D = r1[0]
	var p1: GPUParticles2D = r1[1]
	target2.name = "Target_B"

	# Build effect with both trigger entries BEFORE add_child so the
	# recipe clone in _ready() captures the fully-configured array.
	var effect := VFX2DJuiceEffect.new()
	effect.vfx_mode = VFXJuiceEffectBase.VFXMode.TRIGGER_EXISTING
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.1
	# trigger_targets[0]: empty NodePath() = the juice's own target (Target_A).
	# trigger_targets[1]: pre-baked path from juice (child of Target_A) to Target_B.
	effect.trigger_targets.append(NodePath())  # = Target_A (own animated node)
	effect.trigger_targets.append(NodePath("../../Target_B"))

	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	target.add_child(juice)  # recipe cloned here — both entries are captured
	await wait_frames(2)

	juice.animate_in()
	await wait_frames(3)

	assert_true(p0.emitting, "MULTI-TARGET: Target_A particle fires (empty NodePath)")
	assert_true(p1.emitting, "MULTI-TARGET: Target_B particle fires (cross-node NodePath)")
	await cleanup(target)
	await cleanup(target2)


func test_trigger_existing_repositions_particle_to_target_global_pos() -> void:
	# Target at a non-zero position — particle should move to that global pos.
	var r := await _create_2d_target_with_particles(Vector2(300.0, 150.0))
	var target: Node2D = r[0]
	var particles: GPUParticles2D = r[1]
	particles.position = Vector2.ZERO  # start at local origin

	var juice := _create_juice2d_trigger_existing(target)
	await wait_frames(2)
	juice.animate_in()
	await wait_frames(3)

	assert_approx_vec2(particles.global_position, Vector2(300.0, 150.0),
		"TRIGGER_EXISTING: particle repositioned to target global_position", 1.0)
	await cleanup(target)


# =============================================================================
# TESTS — INSTANTIATE_NEW
# =============================================================================

func test_instantiate_new_adds_instance_as_child_of_target() -> void:
	var target := Node2D.new()
	target.position = Vector2(250.0, 100.0)
	_runner.add_child(target)
	await wait_frames(2)

	var effect := VFX2DJuiceEffect.new()
	effect.vfx_mode = VFXJuiceEffectBase.VFXMode.INSTANTIATE_NEW
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.1

	effect.spawn_scenes.append(_create_vfx_packed_scene())
	# spawn_locations empty → spawns at the juice's own animated target.

	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	var children_before := target.get_child_count()
	juice.animate_in()
	await wait_frames(3)

	assert_true(target.get_child_count() > children_before,
		"INSTANTIATE_NEW: instance added as child of target node")
	await cleanup(target)


func test_instantiate_new_null_scene_no_crash() -> void:
	var target := Node2D.new()
	_runner.add_child(target)
	await wait_frames(1)

	var effect := VFX2DJuiceEffect.new()
	effect.vfx_mode = VFXJuiceEffectBase.VFXMode.INSTANTIATE_NEW
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.1
	# null scene in array — should warn and not crash.
	effect.spawn_scenes.append(null)

	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	# Must not crash.
	juice.animate_in()
	await wait_frames(3)
	assert_true(true, "NULL_SCENE: animate_in with null scene did not crash")
	await cleanup(target)


func test_instantiate_new_custom_position_spawns_extra_instance() -> void:
	var target := Node2D.new()
	target.position = Vector2(100.0, 100.0)
	_runner.add_child(target)
	await wait_frames(2)

	var effect := VFX2DJuiceEffect.new()
	effect.vfx_mode = VFXJuiceEffectBase.VFXMode.INSTANTIATE_NEW
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.1

	effect.spawn_scenes.append(_create_vfx_packed_scene())

	# spawn_locations empty (defaults to target) + one custom position → 2 instances total.
	effect.use_custom_positions = true
	effect.custom_positions.append(Vector2(500.0, 500.0))

	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	var children_before := target.get_child_count()
	juice.animate_in()
	await wait_frames(3)

	# Each trigger spawns: 1 from spawn_locations + 1 from custom_positions = 2 new children.
	# (Both are added as children of the target node.)
	var new_children := target.get_child_count() - children_before
	assert_true(new_children >= 2,
		"CUSTOM_POS: 2 instances spawned (location + custom position), got %d" % new_children)
	await cleanup(target)


# =============================================================================
# TESTS — STACKING AND REGISTRATION
# =============================================================================

func test_vfx_stacked_with_transform_no_crash() -> void:
	var r := await _create_2d_target_with_particles(Vector2(200.0, 200.0))
	var target: Node2D = r[0]

	var vfx_effect := VFX2DJuiceEffect.new()
	vfx_effect.vfx_mode = VFXJuiceEffectBase.VFXMode.TRIGGER_EXISTING
	vfx_effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	vfx_effect.duration_in = 0.2

	var transform_effect := Transform2DJuiceEffect.new()
	transform_effect.duration_in = 0.2
	transform_effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY

	var recipe := Juice2DRecipe.new()
	recipe.effects.append(vfx_effect)
	recipe.effects.append(transform_effect)

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_frames(5)
	assert_true(true, "STACKING: VFX + Transform on same target did not crash")
	await cleanup(target)


func test_vfx_appears_in_2d_recipe_whitelist() -> void:
	var recipe := Juice2DRecipe.new()
	var whitelist: String = recipe._CONCRETE_EFFECTS
	assert_true(whitelist.contains("VFX2DJuiceEffect"),
		"REGISTRY: VFX2DJuiceEffect is in Juice2DRecipe._CONCRETE_EFFECTS")
