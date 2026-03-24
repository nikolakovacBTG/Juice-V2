## TestSpring2D.gd
## ============================================================================
## WHAT: Tests for Spring2DJuiceEffect.
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "spring_2d"


func get_test_methods() -> Array[String]:
	return [
		"test_position_spring_applies",
		"test_rotation_spring_applies",
		"test_scale_spring_applies",
		"test_position_spring_settles_near_offset",
	]


func _create_spring_rig(
	label: String,
	target_type: int = Spring2DJuiceEffect.TransformTarget.POSITION,
	duration: float = 0.5,
	one_shot: bool = false
) -> Array:
	var target := Node2D.new()
	target.name = label
	_runner.add_child(target)

	var effect := Spring2DJuiceEffect.new()
	effect.transform_target = target_type
	effect.stiffness = 300.0
	effect.damping = 10.0
	effect.mass = 1.0
	effect.position_offset = Vector2(50.0, 0.0)
	effect.rotation_offset_degrees = 20.0
	effect.scale_offset = Vector2(0.3, 0.3)
	effect.one_shot_mode = one_shot
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


func test_position_spring_applies() -> void:
	var rig := await _create_spring_rig("SpringPos2D",
		Spring2DJuiceEffect.TransformTarget.POSITION)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	var natural_pos := target.position

	juice.animate_in()
	await wait_seconds(0.15)

	assert_not_approx_vec2(target.position, natural_pos,
		"Position should differ during spring", 1.0)

	await cleanup(target)


func test_rotation_spring_applies() -> void:
	var rig := await _create_spring_rig("SpringRot2D",
		Spring2DJuiceEffect.TransformTarget.ROTATION)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	var natural_rot := target.rotation

	juice.animate_in()
	await wait_seconds(0.15)

	assert_not_approx_float(target.rotation, natural_rot,
		"Rotation should differ during spring", 0.01)

	await cleanup(target)


func test_scale_spring_applies() -> void:
	var rig := await _create_spring_rig("SpringScale2D",
		Spring2DJuiceEffect.TransformTarget.SCALE)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	var natural_scale := target.scale

	juice.animate_in()
	await wait_seconds(0.15)

	assert_not_approx_vec2(target.scale, natural_scale,
		"Scale should differ during spring", 0.01)

	await cleanup(target)


func test_position_spring_settles_near_offset() -> void:
	var rig := await _create_spring_rig("SpringSettle2D",
		Spring2DJuiceEffect.TransformTarget.POSITION, 1.0, true)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	var effect: Spring2DJuiceEffect = rig[2]
	var natural_pos := target.position

	juice.animate_in()
	await wait_seconds(0.8)

	var expected_pos := natural_pos + effect.position_offset
	assert_approx_vec2(target.position, expected_pos,
		"Position should settle near offset", 5.0)

	await cleanup(target)
