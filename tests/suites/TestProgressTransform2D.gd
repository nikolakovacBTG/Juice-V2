## TestProgressTransform2D.gd
## ============================================================================
## WHAT: Tests for ProgressTransform2DJuiceEffect across position, rotation, scale.
## WHY: Verify accumulation-as-speed-multiplier, hold_on_stop, and bound
##      behaviours work correctly for the 2D domain.
## SYSTEM: Tests (tests/suites/)
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "progress_transform_2d"


func get_test_methods() -> Array[String]:
	return [
		"test_position_accumulates",
		"test_rotation_accumulates",
		"test_scale_accumulates",
		"test_hold_on_stop_true",
		"test_hold_on_stop_false",
		"test_bound_reverse",
		"test_needs_sustain",
	]


# =============================================================================
# HELPERS
# =============================================================================

## Creates a minimal Juice2D + Node2D rig with a ProgressTransform2DJuiceEffect.
func _create_progress_rig(
	label: String,
	target_type: int = ProgressTransform2DJuiceEffect.TransformTarget.POSITION,
	rate_pos: Vector2 = Vector2(100.0, 0.0),
	rate_rot: float = 90.0,
	rate_scale: Vector2 = Vector2(0.5, 0.5),
	duration: float = 0.3
) -> Array:
	var target := Node2D.new()
	target.name = label
	target.position = Vector2.ZERO
	target.rotation = 0.0
	target.scale = Vector2.ONE
	_runner.add_child(target)

	var effect := ProgressTransform2DJuiceEffect.new()
	effect.transform_target = target_type
	effect.position_rate = rate_pos
	effect.rotation_rate = rate_rot
	effect.scale_rate = rate_scale
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = duration
	effect.auto_start = false

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
# TESTS: Accumulation
# =============================================================================

func test_position_accumulates() -> void:
	# Progress effect at 100px/s should drift rightward during sustain.
	var rig := await _create_progress_rig("prog_pos_2d",
		ProgressTransform2DJuiceEffect.TransformTarget.POSITION,
		Vector2(100.0, 0.0), 90.0, Vector2(0.5, 0.5), 0.1)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.5)  # 0.1s ramp + ~0.4s sustain at full speed

	assert_greater(target.position.x, 20.0,
		"Progress 2D POSITION: should have moved right (x=%.1f)" % target.position.x)

	await cleanup(target)


func test_rotation_accumulates() -> void:
	# 90 deg/s for ~0.4s sustain -> should rotate noticeably.
	var rig := await _create_progress_rig("prog_rot_2d",
		ProgressTransform2DJuiceEffect.TransformTarget.ROTATION,
		Vector2(100.0, 0.0), 90.0, Vector2(0.5, 0.5), 0.1)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.5)

	assert_greater(absf(target.rotation), 0.3,
		"Progress 2D ROTATION: should have rotated >0.3 rad (rot=%.2f)" % target.rotation)

	await cleanup(target)


func test_scale_accumulates() -> void:
	# 0.5 units/s for ~0.4s sustain -> scale should grow beyond 1.0.
	var rig := await _create_progress_rig("prog_scale_2d",
		ProgressTransform2DJuiceEffect.TransformTarget.SCALE,
		Vector2(100.0, 0.0), 90.0, Vector2(0.5, 0.5), 0.1)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.5)

	assert_greater(target.scale.x, 1.1,
		"Progress 2D SCALE: scale.x should grow (scale.x=%.2f)" % target.scale.x)

	await cleanup(target)


# =============================================================================
# TESTS: hold_on_stop
# =============================================================================

func test_hold_on_stop_true() -> void:
	# After animate_out with hold_on_stop=true, position should remain at last value.
	var rig := await _create_progress_rig("prog_hold_true",
		ProgressTransform2DJuiceEffect.TransformTarget.POSITION,
		Vector2(100.0, 0.0), 90.0, Vector2(0.5, 0.5), 0.1)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	var effect: ProgressTransform2DJuiceEffect = rig[2]
	effect.hold_on_stop = true
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_out = 0.1

	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	juice.animate_in()
	await wait_seconds(0.4)

	var pos_before_stop: float = target.position.x
	juice.animate_out()
	await wait_seconds(0.3)

	assert_greater(target.position.x, 1.0,
		"Progress 2D hold_on_stop=true: position should remain after stop (x=%.1f, was %.1f)" % [
			target.position.x, pos_before_stop])

	await cleanup(target)


func test_hold_on_stop_false() -> void:
	# stop() immediately triggers _restore_to_natural; position should snap back.
	var rig := await _create_progress_rig("prog_hold_false",
		ProgressTransform2DJuiceEffect.TransformTarget.POSITION,
		Vector2(100.0, 0.0), 90.0, Vector2(0.5, 0.5), 0.1)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	var effect: ProgressTransform2DJuiceEffect = rig[2]
	effect.hold_on_stop = false

	juice.animate_in()
	await wait_seconds(0.4)

	# stop() triggers _restore_to_natural immediately, without an accumulation ramp.
	juice.stop()
	await wait_frames(3)

	assert_approx_float(target.position.x, 0.0,
		"Progress 2D hold_on_stop=false: position should snap back to natural (x=%.2f)" % target.position.x,
		5.0)

	await cleanup(target)



# =============================================================================
# TESTS: Bound
# =============================================================================

func test_bound_reverse() -> void:
	# With REVERSE bound at 50px, direction should flip and position stay near 50.
	var target := Node2D.new()
	target.name = "prog_bound_2d"
	target.position = Vector2.ZERO
	_runner.add_child(target)

	var effect := ProgressTransform2DJuiceEffect.new()
	effect.transform_target = ProgressTransform2DJuiceEffect.TransformTarget.POSITION
	effect.position_rate = Vector2(200.0, 0.0)  # Fast — hits bound quickly
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.05
	effect.bound_enabled = true
	effect.bound_behaviour = ProgressTransform2DJuiceEffect.BoundBehaviour.REVERSE
	effect.bound_value = 50.0

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.6)

	# After hitting bound and reversing, position should be within bound range.
	assert_true(absf(target.position.x) <= 55.0,
		"Progress 2D BOUND REVERSE: position should stay within bound (x=%.1f)" % target.position.x)

	await cleanup(target)


# =============================================================================
# TESTS: Sustain contract
# =============================================================================

func test_needs_sustain() -> void:
	# Progress effects must sustain (keep ticking at progress=1.0 after animate_in).
	var effect := ProgressTransform2DJuiceEffect.new()
	assert_true(effect._needs_sustain(),
		"ProgressTransform2DJuiceEffect must return true from _needs_sustain()")
