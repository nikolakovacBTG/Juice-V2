## TestSquashStretch2D.gd
## ============================================================================
## WHAT: Tests for SquashStretch2DJuiceEffect.
## WHY: Verify squash/stretch produces correct scale deltas for Node2D domain.
## SYSTEM: Tests (tests/suites/)
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "squash_stretch_2d"


func get_test_methods() -> Array[String]:
	return [
		"test_vertical_squash_at_peak",
		"test_returns_to_natural_at_end",
		"test_preserve_volume",
	]


# =============================================================================
# HELPER
# =============================================================================

func _create_squash_2d_rig(
	label: String,
	axis: int = SquashStretch2DJuiceEffect.SquashAxis.VERTICAL,
	amount: float = 0.5,
	preserve: bool = true,
	duration: float = 0.4
) -> Array:
	var target := Node2D.new()
	target.name = label
	target.position = Vector2.ZERO
	_runner.add_child(target)

	var effect := SquashStretch2DJuiceEffect.new()
	effect.squash_amount = amount
	effect.squash_axis = axis
	effect.preserve_volume = preserve
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = duration

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)
	return [target, juice, effect]


# =============================================================================
# TESTS
# =============================================================================

func test_vertical_squash_at_peak() -> void:
	var rig := await _create_squash_2d_rig("v_squash_2d")
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.2)

	assert_true(target.scale.y < 0.85,
		"2D Vertical squash at peak: scale.y (%.3f) should be < 0.85" % target.scale.y)

	await cleanup(target)


func test_returns_to_natural_at_end() -> void:
	var rig := await _create_squash_2d_rig("squash_end_2d",
		SquashStretch2DJuiceEffect.SquashAxis.VERTICAL, 0.5, true, 0.2)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.4)

	assert_approx_vec2(target.scale, Vector2(1.0, 1.0),
		"2D After squash completes, scale should return to (1, 1)", 0.05)

	await cleanup(target)


func test_preserve_volume() -> void:
	var rig := await _create_squash_2d_rig("preserve_2d")
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.2)

	assert_true(target.scale.y < 0.85,
		"2D Volume preserve: scale.y (%.3f) should be squashed" % target.scale.y)
	assert_true(target.scale.x > 1.1,
		"2D Volume preserve: scale.x (%.3f) should be stretched" % target.scale.x)

	await cleanup(target)
