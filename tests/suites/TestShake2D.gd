## TestShake2D.gd
## ============================================================================
## WHAT: Tests for Shake2DJuiceEffect.
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "shake_2d"


func get_test_methods() -> Array[String]:
	return [
		"test_position_shake_applies",
		"test_rotation_shake_applies",
		"test_scale_shake_applies",
		"test_returns_to_natural_after_completion",
	]


func _create_shake_rig(
	label: String,
	target_type: int = Shake2DJuiceEffect.TransformTarget.POSITION,
	duration: float = 0.3
) -> Array:
	var target := Node2D.new()
	target.name = label
	_runner.add_child(target)

	var effect := Shake2DJuiceEffect.new()
	effect.transform_target = target_type
	effect.shake_frequency = 20.0
	effect.decay = true
	effect.position_strength = Vector2(20.0, 20.0)
	effect.rotation_amplitude = 15.0
	effect.scale_amplitude = Vector2(0.3, 0.3)
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_in = duration
	effect.duration_out = duration

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)
	return [target, juice, effect]


func test_position_shake_applies() -> void:
	var rig := await _create_shake_rig("ShakePos2D",
		Shake2DJuiceEffect.TransformTarget.POSITION)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	var natural_pos := target.position

	juice.animate_in()
	await wait_seconds(0.1)

	assert_not_approx_vec2(target.position, natural_pos,
		"Position should differ during shake", 0.5)

	await cleanup(target)


func test_rotation_shake_applies() -> void:
	var rig := await _create_shake_rig("ShakeRot2D",
		Shake2DJuiceEffect.TransformTarget.ROTATION)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	var natural_rot := target.rotation

	juice.animate_in()
	await wait_seconds(0.1)

	assert_not_approx_float(target.rotation, natural_rot,
		"Rotation should differ during shake", 0.01)

	await cleanup(target)


func test_scale_shake_applies() -> void:
	var rig := await _create_shake_rig("ShakeScale2D",
		Shake2DJuiceEffect.TransformTarget.SCALE)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	var natural_scale := target.scale

	juice.animate_in()
	await wait_seconds(0.1)

	assert_not_approx_vec2(target.scale, natural_scale,
		"Scale should differ during shake", 0.01)

	await cleanup(target)


func test_returns_to_natural_after_completion() -> void:
	var rig := await _create_shake_rig("ShakeReturn2D",
		Shake2DJuiceEffect.TransformTarget.POSITION, 0.15)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	var natural_pos := target.position

	juice.animate_in()
	await wait_seconds(0.5)

	assert_approx_vec2(target.position, natural_pos,
		"Position should return to natural after completion", 1.0)

	await cleanup(target)
