## TestSpring2D.gd
## ============================================================================
## WHAT: Tests for Spring2DJuiceEffect (reactive-only design).
## TESTS: Starts at rest, reacts to external displacement (pos/rot/scale),
##        settles back after displacement, rotation torque from CoG offset.
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "spring_2d"


func get_test_methods() -> Array[String]:
	return [
		"test_starts_at_rest",
		"test_reacts_to_position_displacement",
		"test_reacts_to_rotation_displacement",
		"test_reacts_to_scale_displacement",
		"test_settles_back_after_displacement",
		"test_rotation_torque_from_cog_offset",
	]


# =============================================================================
# HELPERS
# =============================================================================

func _create_spring_rig(
	label: String,
	target_type: int = Spring2DJuiceEffect.TransformTarget.POSITION,
	duration: float = 2.0
) -> Array:
	var target := Node2D.new()
	target.name = label
	_runner.add_child(target)

	var effect := Spring2DJuiceEffect.new()
	effect.transform_target = target_type
	effect.stiffness = 300.0
	effect.damping = 10.0
	effect.mass = 1.0
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = duration

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)
	return [target, juice, effect]


# =============================================================================
# TESTS
# =============================================================================

func test_starts_at_rest() -> void:
	var rig := await _create_spring_rig("SpringRest2D")
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	var natural_pos := target.position

	juice.animate_in()
	await wait_frames(5)

	assert_approx_vec2(target.position, natural_pos,
		"Spring should remain at rest with no external force", 0.5)

	await cleanup(target)


func test_reacts_to_position_displacement() -> void:
	var rig := await _create_spring_rig("SpringPos2D",
		Spring2DJuiceEffect.TransformTarget.POSITION)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_frames(2)

	target.position += Vector2(50.0, 0.0)
	var displaced_pos := target.position

	await wait_frames(5)

	assert_not_approx_vec2(target.position, displaced_pos,
		"Position should differ as spring reacts to displacement", 1.0)

	await cleanup(target)


func test_reacts_to_rotation_displacement() -> void:
	var rig := await _create_spring_rig("SpringRot2D",
		Spring2DJuiceEffect.TransformTarget.ROTATION)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_frames(2)

	target.rotation += deg_to_rad(30.0)
	var displaced_rot := target.rotation

	await wait_frames(5)

	assert_not_approx_float(target.rotation, displaced_rot,
		"Rotation should differ as spring reacts to displacement", 0.01)

	await cleanup(target)


func test_reacts_to_scale_displacement() -> void:
	var rig := await _create_spring_rig("SpringScale2D",
		Spring2DJuiceEffect.TransformTarget.SCALE)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_frames(2)

	target.scale += Vector2(0.5, 0.5)
	var displaced_scale := target.scale

	await wait_frames(5)

	assert_not_approx_vec2(target.scale, displaced_scale,
		"Scale should differ as spring reacts to displacement", 0.01)

	await cleanup(target)


func test_settles_back_after_displacement() -> void:
	var target := Node2D.new()
	target.name = "SpringSettle2D"
	_runner.add_child(target)

	var effect := Spring2DJuiceEffect.new()
	effect.transform_target = Spring2DJuiceEffect.TransformTarget.POSITION
	effect.stiffness = 300.0
	effect.damping = 25.0
	effect.mass = 1.0
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 3.0

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_frames(2)

	target.position += Vector2(30.0, 0.0)
	var displaced_pos := target.position

	await wait_seconds(1.0)

	assert_approx_vec2(target.position, displaced_pos,
		"Spring should settle at displaced position (zero delta)", 2.0)

	await cleanup(target)


func test_rotation_torque_from_cog_offset() -> void:
	var target := Node2D.new()
	target.name = "SpringTorque2D"
	_runner.add_child(target)
	# Add a Sprite2D child for bounding box estimation (100x100)
	var spr := Sprite2D.new()
	spr.centered = true
	var img := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	spr.texture = ImageTexture.create_from_image(img)
	target.add_child(spr)

	var effect := Spring2DJuiceEffect.new()
	effect.transform_target = Spring2DJuiceEffect.TransformTarget.ROTATION
	effect.stiffness = 300.0
	effect.damping = 10.0
	effect.mass = 1.0
	# CoG at right-center (1.0, 0.5) — offset from visual center (0.5, 0.5)
	# Arm ratio = (0.5, 0.0). Vertical displacement creates non-zero cross product.
	effect.center_of_gravity = Vector2(1.0, 0.5)
	effect.pivot_mode = Spring2DJuiceEffect.PivotMode.AUTO_CENTER
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 2.0

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	var natural_rot := target.rotation
	juice.animate_in()
	await wait_frames(2)

	# Large vertical displacement to produce significant torque
	target.position += Vector2(0.0, 200.0)
	await wait_frames(3)

	assert_not_approx_float(target.rotation, natural_rot,
		"Rotation should change from torque (CoG offset + position displacement)", 0.001)

	await cleanup(target)
