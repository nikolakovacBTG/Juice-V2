## TestNoiseControl.gd
## ============================================================================
## WHAT: Tests for NoiseControlJuiceEffect.
## TESTS: Position noise applies, rotation noise applies, scale noise applies,
##        returns to natural after completion, stacking with transform effect.
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "noise_control"


func get_test_methods() -> Array[String]:
	return [
		"test_position_noise_applies",
		"test_rotation_noise_applies",
		"test_scale_noise_applies",
		"test_returns_to_natural_after_completion",
		"test_stacking_with_transform_effect",
	]


# =============================================================================
# HELPERS
# =============================================================================

func _create_noise_rig(
	label: String,
	target_type: int = NoiseControlJuiceEffect.TransformTarget.POSITION,
	duration: float = 0.3
) -> Array:
	var target := create_control_target(label)

	var effect := NoiseControlJuiceEffect.new()
	effect.transform_target = target_type
	effect.noise_speed = 5.0
	effect.position_amplitude = Vector2(20.0, 20.0)
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

func test_position_noise_applies() -> void:
	var rig := await _create_noise_rig("NoisePosCtrl",
		NoiseControlJuiceEffect.TransformTarget.POSITION)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]
	var natural_pos := target.position

	juice.animate_in()
	await wait_seconds(0.05)

	# Poll max displacement over 10 frames to avoid phase-dependent zero-crossing failures.
	var max_dist := 0.0
	for i in range(5):
		await wait_frames(10)
		max_dist = maxf(max_dist, target.position.distance_to(natural_pos))

	assert_true(max_dist >= 0.5, "Position should displace during noise (max=%.3f)" % max_dist)

	await cleanup(target)


func test_rotation_noise_applies() -> void:
	var rig := await _create_noise_rig("NoiseRotCtrl",
		NoiseControlJuiceEffect.TransformTarget.ROTATION)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]
	var natural_rot := target.rotation

	juice.animate_in()
	await wait_seconds(0.05)

	# Poll max displacement over 10 frames to avoid phase-dependent zero-crossing failures.
	var max_rot_dist := 0.0
	for i in range(5):
		await wait_frames(10)
		max_rot_dist = maxf(max_rot_dist, absf(target.rotation - natural_rot))

	assert_true(max_rot_dist >= 0.01, "Rotation should displace during noise (max=%.4f)" % max_rot_dist)

	await cleanup(target)


func test_scale_noise_applies() -> void:
	var rig := await _create_noise_rig("NoiseScaleCtrl",
		NoiseControlJuiceEffect.TransformTarget.SCALE)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]
	var natural_scale := target.scale

	juice.animate_in()
	await wait_seconds(0.05)

	# Poll max displacement over 10 frames to avoid phase-dependent zero-crossing failures.
	var max_scale_dist := 0.0
	for i in range(5):
		await wait_frames(10)
		max_scale_dist = maxf(max_scale_dist, target.scale.distance_to(natural_scale))

	assert_true(max_scale_dist >= 0.01, "Scale should displace during noise (max=%.4f)" % max_scale_dist)

	await cleanup(target)


func test_returns_to_natural_after_completion() -> void:
	var rig := await _create_noise_rig("NoiseReturnCtrl",
		NoiseControlJuiceEffect.TransformTarget.POSITION, 0.15)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]
	var natural_pos := target.position

	juice.animate_in()
	# Wait for full IN + OUT cycle
	await wait_seconds(0.5)

	assert_approx_vec2(target.position, natural_pos,
		"Position should return to natural after completion", 1.0)

	await cleanup(target)


func test_stacking_with_transform_effect() -> void:
	var target := create_control_target("NoiseStackCtrl")

	# Noise effect on position
	var noise := NoiseControlJuiceEffect.new()
	noise.transform_target = NoiseControlJuiceEffect.TransformTarget.POSITION
	noise.noise_speed = 5.0
	noise.position_amplitude = Vector2(10.0, 10.0)
	noise.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	noise.duration_in = 0.3

	# Transform effect on position
	var transform := TransformControlJuiceEffect.new()
	transform.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	transform.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	transform.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	transform.to_position = Vector2(0.5, 0.0)
	transform.to_position_in = TransformControlJuiceEffect.PositionIn.OWN_SIZE
	transform.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	transform.duration_in = 0.3

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(noise)
	recipe.effects.append(transform)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)
	var natural_pos := target.position

	juice.animate_in()
	await wait_seconds(0.15)
	await wait_frames(5)

	# Both effects should have moved the position away from natural
	assert_not_approx_vec2(target.position, natural_pos,
		"Stacked noise + transform should differ from natural", 1.0)

	await cleanup(target)
