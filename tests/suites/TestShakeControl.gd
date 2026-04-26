## TestShakeControl.gd
## ============================================================================
## WHAT: Tests for ShakeControlJuiceEffect.
## TESTS: Position shake applies, rotation shake applies, scale shake applies,
##        returns to natural after completion.
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "shake_control"


func get_test_methods() -> Array[String]:
	return [
		"test_position_shake_applies",
		"test_rotation_shake_applies",
		"test_scale_shake_applies",
		"test_returns_to_natural_after_completion",
	]


# =============================================================================
# HELPERS
# =============================================================================

func _create_shake_rig(
	label: String,
	target_type: int = ShakeControlJuiceEffect.TransformTarget.POSITION,
	duration: float = 0.3
) -> Array:
	var target := create_control_target(label)

	var effect := ShakeControlJuiceEffect.new()
	effect.transform_target = target_type
	effect.shake_frequency = 20.0
	effect.position_strength = Vector2(20.0, 20.0)
	effect.rotation_amplitude = 15.0
	effect.scale_amplitude = Vector2(0.3, 0.3)
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_in = duration
	effect.duration_out = duration

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

func test_position_shake_applies() -> void:
	var rig := await _create_shake_rig("ShakePosCtrl",
		ShakeControlJuiceEffect.TransformTarget.POSITION)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]
	var natural_pos := target.position

	juice.animate_in()
	await wait_seconds(0.05)

	# Poll max displacement over 10 frames to avoid phase-dependent zero-crossing failures
	var max_dist := 0.0
	for i in range(10):
		await wait_frames(1)
		max_dist = maxf(max_dist, target.position.distance_to(natural_pos))

	assert_true(max_dist >= 0.5, "Position should displace during shake (max=%.3f)" % max_dist)

	await cleanup(target)


func test_rotation_shake_applies() -> void:
	var rig := await _create_shake_rig("ShakeRotCtrl",
		ShakeControlJuiceEffect.TransformTarget.ROTATION)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]
	var natural_rot := target.rotation

	juice.animate_in()
	await wait_seconds(0.05)

	# Poll max displacement over 10 frames
	var max_rot_dist := 0.0
	for i in range(10):
		await wait_frames(1)
		max_rot_dist = maxf(max_rot_dist, absf(target.rotation - natural_rot))

	assert_true(max_rot_dist >= 0.01, "Rotation should displace during shake (max=%.4f)" % max_rot_dist)

	await cleanup(target)


func test_scale_shake_applies() -> void:
	var rig := await _create_shake_rig("ShakeScaleCtrl",
		ShakeControlJuiceEffect.TransformTarget.SCALE)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]
	var natural_scale := target.scale

	juice.animate_in()
	await wait_seconds(0.05)

	# Poll max displacement over 10 frames
	var max_scale_dist := 0.0
	for i in range(10):
		await wait_frames(1)
		max_scale_dist = maxf(max_scale_dist, target.scale.distance_to(natural_scale))

	assert_true(max_scale_dist >= 0.01, "Scale should displace during shake (max=%.4f)" % max_scale_dist)

	await cleanup(target)


func test_returns_to_natural_after_completion() -> void:
	var rig := await _create_shake_rig("ShakeReturnCtrl",
		ShakeControlJuiceEffect.TransformTarget.POSITION, 0.15)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]
	var natural_pos := target.position

	juice.animate_in()
	await wait_seconds(0.5)

	assert_approx_vec2(target.position, natural_pos,
		"Position should return to natural after completion", 1.0)

	await cleanup(target)
