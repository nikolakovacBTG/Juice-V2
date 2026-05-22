## TestNoise3D.gd
## ============================================================================
## WHAT: Tests for Noise3DJuiceEffect.
## TESTS: Position noise applies, rotation noise applies, scale noise applies,
##        returns to natural after completion.
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "noise_3d"


func get_test_methods() -> Array[String]:
	return [
		"test_position_noise_applies",
		"test_rotation_noise_applies",
		"test_scale_noise_applies",
		"test_returns_to_natural_after_completion",
	]


# =============================================================================
# HELPERS
# =============================================================================

func _create_noise_rig(
	label: String,
	target_type: int = Noise3DJuiceEffect.TransformTarget.POSITION,
	duration: float = 0.3
) -> Array:
	var target := Node3D.new()
	target.name = label
	target.position = Vector3.ZERO
	_runner.add_child(target)

	var effect := Noise3DJuiceEffect.new()
	effect.transform_target = target_type
	effect.noise_speed = 5.0
	effect.position_amplitude = Vector3(2.0, 2.0, 2.0)
	effect.rotation_amplitude = Vector3(0.0, 15.0, 0.0)
	effect.scale_amplitude = Vector3(0.3, 0.3, 0.3)
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_in = duration
	effect.duration_out = duration

	var juice := Juice3D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := Juice3DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)
	return [target, juice, effect]


# =============================================================================
# TESTS
# =============================================================================

func test_position_noise_applies() -> void:
	var rig := await _create_noise_rig("NoisePos3D",
		Noise3DJuiceEffect.TransformTarget.POSITION)
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]
	var natural_pos := target.position

	juice.animate_in()
	await wait_seconds(0.05)

	# Poll max displacement over 10 frames to avoid phase-dependent zero-crossing failures.
	var max_dist := 0.0
	for i in range(5):
		await wait_frames(10)
		max_dist = maxf(max_dist, target.position.distance_to(natural_pos))

	assert_true(max_dist >= 0.01, "Position should displace during noise (max=%.4f)" % max_dist)

	await cleanup(target)


func test_rotation_noise_applies() -> void:
	var rig := await _create_noise_rig("NoiseRot3D",
		Noise3DJuiceEffect.TransformTarget.ROTATION)
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]
	var natural_rot := target.rotation

	juice.animate_in()
	await wait_seconds(0.05)

	# Poll max displacement over 10 frames to avoid phase-dependent zero-crossing failures.
	var max_rot_dist := 0.0
	for i in range(5):
		await wait_frames(10)
		max_rot_dist = maxf(max_rot_dist, target.rotation.distance_to(natural_rot))

	assert_true(max_rot_dist >= 0.01, "Rotation should displace during noise (max=%.4f)" % max_rot_dist)

	await cleanup(target)


func test_scale_noise_applies() -> void:
	var rig := await _create_noise_rig("NoiseScale3D",
		Noise3DJuiceEffect.TransformTarget.SCALE)
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]
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
	var rig := await _create_noise_rig("NoiseReturn3D",
		Noise3DJuiceEffect.TransformTarget.POSITION, 0.15)
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]
	var natural_pos := target.position

	juice.animate_in()
	await wait_seconds(0.5)

	assert_approx_vec3(target.position, natural_pos,
		"Position should return to natural after completion", 0.05)

	await cleanup(target)
