## TestSquashStretch3D.gd
## ============================================================================
## WHAT: Tests for SquashStretch3DJuiceEffect.
## WHY: Verify squash/stretch produces correct scale deltas for Node3D domain.
## SYSTEM: Tests (tests/suites/)
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "squash_stretch_3d"


func get_test_methods() -> Array[String]:
	return [
		"test_y_squash_at_peak",
		"test_returns_to_natural_at_end",
		"test_preserve_volume",
	]


# =============================================================================
# HELPER
# =============================================================================

func _create_squash_3d_rig(
	label: String,
	axis: int = SquashStretch3DJuiceEffect.SquashAxis3D.Y,
	amount: float = 0.5,
	preserve: bool = true,
	duration: float = 0.4
) -> Array:
	var target := Node3D.new()
	target.name = label
	target.position = Vector3.ZERO
	_runner.add_child(target)

	var effect := SquashStretch3DJuiceEffect.new()
	effect.squash_amount = amount
	effect.squash_axis = axis
	effect.preserve_volume = preserve
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = duration

	var juice := Juice3D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := Juice3DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)
	return [target, juice, effect]


# =============================================================================
# TESTS
# =============================================================================

func test_y_squash_at_peak() -> void:
	var rig := await _create_squash_3d_rig("y_squash_3d")
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]

	juice.animate_in()
	await wait_seconds(0.2)

	assert_true(target.scale.y < 0.85,
		"3D Y squash at peak: scale.y (%.3f) should be < 0.85" % target.scale.y)

	await cleanup(target)


func test_returns_to_natural_at_end() -> void:
	var rig := await _create_squash_3d_rig("squash_end_3d",
		SquashStretch3DJuiceEffect.SquashAxis3D.Y, 0.5, true, 0.2)
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]

	juice.animate_in()
	await wait_seconds(0.4)

	assert_approx_vec3(target.scale, Vector3(1.0, 1.0, 1.0),
		"3D After squash completes, scale should return to (1, 1, 1)", 0.05)

	await cleanup(target)


func test_preserve_volume() -> void:
	var rig := await _create_squash_3d_rig("preserve_3d")
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]

	juice.animate_in()
	await wait_seconds(0.2)

	# Y squashed, X and Z should expand (sqrt(1/F) each for volume preservation)
	assert_true(target.scale.y < 0.85,
		"3D Volume preserve: scale.y (%.3f) should be squashed" % target.scale.y)
	assert_true(target.scale.x > 1.05,
		"3D Volume preserve: scale.x (%.3f) should be stretched" % target.scale.x)
	assert_true(target.scale.z > 1.05,
		"3D Volume preserve: scale.z (%.3f) should be stretched" % target.scale.z)

	await cleanup(target)
