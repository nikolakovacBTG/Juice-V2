## TestShake3D.gd
## ============================================================================
## WHAT: Tests for Shake3DJuiceEffect.
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "shake_3d"


func get_test_methods() -> Array[String]:
	return [
		"test_position_shake_applies",
		"test_rotation_shake_applies",
		"test_scale_shake_applies",
		"test_returns_to_natural_after_completion",
	]


func _create_shake_rig(
	label: String,
	target_type: int = Shake3DJuiceEffect.TransformTarget.POSITION,
	duration: float = 0.3
) -> Array:
	var target := Node3D.new()
	target.name = label
	_runner.add_child(target)

	var effect := Shake3DJuiceEffect.new()
	effect.transform_target = target_type
	effect.shake_frequency = 20.0
	effect.position_strength = Vector3(2.0, 2.0, 2.0)
	effect.rotation_amplitude = Vector3(0.0, 15.0, 0.0)
	effect.scale_amplitude = Vector3(0.5, 0.5, 0.5)
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


func test_position_shake_applies() -> void:
	var rig := await _create_shake_rig("ShakePos3D",
		Shake3DJuiceEffect.TransformTarget.POSITION)
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]
	var natural_pos := target.position

	juice.animate_in()
	await wait_seconds(0.1)

	assert_not_approx_vec3(target.position, natural_pos,
		"Position should differ during shake", 0.01)

	await cleanup(target)


func test_rotation_shake_applies() -> void:
	var rig := await _create_shake_rig("ShakeRot3D",
		Shake3DJuiceEffect.TransformTarget.ROTATION)
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]
	var natural_rot := target.rotation

	juice.animate_in()
	await wait_seconds(0.1)

	assert_not_approx_vec3(target.rotation, natural_rot,
		"Rotation should differ during shake", 0.01)

	await cleanup(target)


func test_scale_shake_applies() -> void:
	var rig := await _create_shake_rig("ShakeScale3D",
		Shake3DJuiceEffect.TransformTarget.SCALE)
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]
	var natural_scale := target.scale

	juice.animate_in()
	# Scale amplitude (0.5) is smaller than position (2.0) or rotation (15°),
	# so the shake needs more frames to reliably exceed the 0.01 assertion threshold.
	# 0.25s matches the pattern used for other noise/shake tests with small amplitudes.
	await wait_seconds(0.25)

	assert_not_approx_vec3(target.scale, natural_scale,
		"Scale should differ during shake", 0.01)

	await cleanup(target)



func test_returns_to_natural_after_completion() -> void:
	var rig := await _create_shake_rig("ShakeReturn3D",
		Shake3DJuiceEffect.TransformTarget.POSITION, 0.15)
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]
	var natural_pos := target.position

	juice.animate_in()
	await wait_seconds(0.5)

	assert_approx_vec3(target.position, natural_pos,
		"Position should return to natural after completion", 0.05)

	await cleanup(target)
