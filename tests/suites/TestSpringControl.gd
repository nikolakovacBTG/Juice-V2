## TestSpringControl.gd
## ============================================================================
## WHAT: Tests for SpringControlJuiceEffect.
## TESTS: Position spring applies, rotation spring applies, scale spring applies,
##        spring settles near target offset.
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "spring_control"


func get_test_methods() -> Array[String]:
	return [
		"test_position_spring_applies",
		"test_rotation_spring_applies",
		"test_scale_spring_applies",
		"test_position_spring_settles_near_offset",
	]


# =============================================================================
# HELPERS
# =============================================================================

func _create_spring_rig(
	label: String,
	target_type: int = SpringControlJuiceEffect.TransformTarget.POSITION,
	duration: float = 0.5,
	one_shot: bool = false
) -> Array:
	var target := create_control_target(label)

	var effect := SpringControlJuiceEffect.new()
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

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)
	return [target, juice, effect]


# =============================================================================
# TESTS
# =============================================================================

func test_position_spring_applies() -> void:
	var rig := await _create_spring_rig("SpringPosCtrl",
		SpringControlJuiceEffect.TransformTarget.POSITION)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]
	var natural_pos := target.position

	juice.animate_in()
	await wait_seconds(0.15)

	assert_not_approx_vec2(target.position, natural_pos,
		"Position should differ during spring animation", 1.0)

	await cleanup(target)


func test_rotation_spring_applies() -> void:
	var rig := await _create_spring_rig("SpringRotCtrl",
		SpringControlJuiceEffect.TransformTarget.ROTATION)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]
	var natural_rot := target.rotation

	juice.animate_in()
	await wait_seconds(0.15)

	assert_not_approx_float(target.rotation, natural_rot,
		"Rotation should differ during spring animation", 0.01)

	await cleanup(target)


func test_scale_spring_applies() -> void:
	var rig := await _create_spring_rig("SpringScaleCtrl",
		SpringControlJuiceEffect.TransformTarget.SCALE)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]
	var natural_scale := target.scale

	juice.animate_in()
	await wait_seconds(0.15)

	assert_not_approx_vec2(target.scale, natural_scale,
		"Scale should differ during spring animation", 0.01)

	await cleanup(target)


func test_position_spring_settles_near_offset() -> void:
	var rig := await _create_spring_rig("SpringSettleCtrl",
		SpringControlJuiceEffect.TransformTarget.POSITION, 1.0, true)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]
	var effect: SpringControlJuiceEffect = rig[2]
	var natural_pos := target.position

	juice.animate_in()
	# Give spring time to settle (high stiffness, moderate damping)
	await wait_seconds(0.8)

	var expected_pos := natural_pos + effect.position_offset
	assert_approx_vec2(target.position, expected_pos,
		"Position should settle near offset", 5.0)

	await cleanup(target)
