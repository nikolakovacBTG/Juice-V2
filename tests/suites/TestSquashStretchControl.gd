## TestSquashStretchControl.gd
## ============================================================================
## WHAT: Tests for SquashStretchControlJuiceEffect.
## WHY: Verify squash/stretch produces correct scale deltas, volume preservation,
##      and both axis modes work.
## SYSTEM: Tests (tests/suites/)
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "squash_stretch_control"


func get_test_methods() -> Array[String]:
	return [
		"test_vertical_squash_at_peak",
		"test_horizontal_squash_at_peak",
		"test_returns_to_natural_at_end",
		"test_preserve_volume_vertical",
		"test_no_preserve_volume",
	]


# =============================================================================
# HELPER
# =============================================================================

func _create_squash_rig(
	label: String,
	axis: int = SquashStretchControlJuiceEffect.SquashAxis.VERTICAL,
	amount: float = 0.3,
	preserve: bool = true,
	duration: float = 0.2
) -> Array:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(100, 40)
	btn.position = Vector2.ZERO
	_runner.add_child(btn)

	var effect := SquashStretchControlJuiceEffect.new()
	effect.squash_amount = amount
	effect.squash_axis = axis
	effect.preserve_volume = preserve
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = duration

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	btn.add_child(juice)

	await wait_frames(2)
	return [btn, juice, effect]


# =============================================================================
# TESTS
# =============================================================================

func test_vertical_squash_at_peak() -> void:
	# Squash uses sin(progress * PI) — peaks at progress=0.5
	# At peak with amount=0.5: y_multiplier = 1 - 0.5*1.0 = 0.5, scale.y = 0.5
	var rig := await _create_squash_rig("v_squash", 
		SquashStretchControlJuiceEffect.SquashAxis.VERTICAL, 0.5, true, 0.4)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	# Wait roughly to mid-point (peak squash)
	await wait_seconds(0.2)

	# At peak: scale.y should be < 1.0 (squashed)
	assert_true(btn.scale.y < 0.85,
		"Vertical squash at peak: scale.y (%.3f) should be < 0.85" % btn.scale.y)

	await cleanup(btn)


func test_horizontal_squash_at_peak() -> void:
	var rig := await _create_squash_rig("h_squash",
		SquashStretchControlJuiceEffect.SquashAxis.HORIZONTAL, 0.5, true, 0.4)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	await wait_seconds(0.2)

	# At peak: scale.x should be < 1.0 (squashed)
	assert_true(btn.scale.x < 0.85,
		"Horizontal squash at peak: scale.x (%.3f) should be < 0.85" % btn.scale.x)

	await cleanup(btn)


func test_returns_to_natural_at_end() -> void:
	# sin(1.0 * PI) = 0, so at progress=1.0 squash_factor=0, scale returns to base
	var rig := await _create_squash_rig("squash_end",
		SquashStretchControlJuiceEffect.SquashAxis.VERTICAL, 0.5, true, 0.2)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	await wait_seconds(0.4)

	assert_approx_vec2(btn.scale, Vector2(1.0, 1.0),
		"After squash completes, scale should return to (1, 1)", 0.05)

	await cleanup(btn)


func test_preserve_volume_vertical() -> void:
	# With preserve_volume, when Y shrinks, X should grow
	var rig := await _create_squash_rig("preserve_vol",
		SquashStretchControlJuiceEffect.SquashAxis.VERTICAL, 0.5, true, 0.4)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	await wait_seconds(0.2)

	# At peak: scale.y < 1.0 AND scale.x > 1.0
	assert_true(btn.scale.y < 0.85,
		"Volume preserve: scale.y (%.3f) should be squashed" % btn.scale.y)
	assert_true(btn.scale.x > 1.1,
		"Volume preserve: scale.x (%.3f) should be stretched" % btn.scale.x)

	await cleanup(btn)


func test_no_preserve_volume() -> void:
	# Without preserve_volume, only the squash axis changes
	var rig := await _create_squash_rig("no_preserve",
		SquashStretchControlJuiceEffect.SquashAxis.VERTICAL, 0.5, false, 0.4)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	await wait_seconds(0.2)

	# At peak: scale.y < 1.0 BUT scale.x should stay ~1.0
	assert_true(btn.scale.y < 0.85,
		"No preserve: scale.y (%.3f) should be squashed" % btn.scale.y)
	assert_approx_float(btn.scale.x, 1.0,
		"No preserve: scale.x should remain ~1.0", 0.05)

	await cleanup(btn)
