## TestProgressTransformControl.gd
## ============================================================================
## WHAT: Tests for ProgressTransformControlJuiceEffect across position, rotation, scale.
## WHY: Verify accumulation-as-speed-multiplier, hold_on_stop, pivot_offset
##      reactive updates, and bound behaviours for the Control domain.
## SYSTEM: Tests (tests/suites/)
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "progress_transform_control"


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

func _create_progress_rig(
	label: String,
	target_type: int = ProgressTransformControlJuiceEffect.TransformTarget.POSITION,
	rate_pos: Vector2 = Vector2(100.0, 0.0),
	rate_rot: float = 90.0,
	rate_scale: Vector2 = Vector2(0.5, 0.5),
	duration: float = 0.3
) -> Array:
	var target := Control.new()
	target.name = label
	target.position = Vector2.ZERO
	target.rotation = 0.0
	target.scale = Vector2.ONE
	target.custom_minimum_size = Vector2(80.0, 40.0)
	_runner.add_child(target)

	var effect := ProgressTransformControlJuiceEffect.new()
	effect.transform_target = target_type
	effect.position_rate = rate_pos
	effect.rotation_rate = rate_rot
	effect.scale_rate = rate_scale
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = duration
	effect.auto_start = false

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)
	return [target, juice, effect]


# =============================================================================
# TESTS: Accumulation
# =============================================================================

func test_position_accumulates() -> void:
	var rig := await _create_progress_rig("prog_pos_ctrl",
		ProgressTransformControlJuiceEffect.TransformTarget.POSITION,
		Vector2(100.0, 0.0), 90.0, Vector2(0.5, 0.5), 0.1)
	var target: Control = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	await wait_seconds(0.5)

	assert_greater(target.position.x, 20.0,
		"Progress Control POSITION: should have moved right (x=%.1f)" % target.position.x)

	await cleanup(target)


func test_rotation_accumulates() -> void:
	var rig := await _create_progress_rig("prog_rot_ctrl",
		ProgressTransformControlJuiceEffect.TransformTarget.ROTATION,
		Vector2(100.0, 0.0), 90.0, Vector2(0.5, 0.5), 0.1)
	var target: Control = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	await wait_seconds(0.5)

	assert_greater(absf(target.rotation), 0.3,
		"Progress Control ROTATION: should have rotated (rot=%.2f)" % target.rotation)

	await cleanup(target)


func test_scale_accumulates() -> void:
	var rig := await _create_progress_rig("prog_scale_ctrl",
		ProgressTransformControlJuiceEffect.TransformTarget.SCALE,
		Vector2(100.0, 0.0), 90.0, Vector2(0.5, 0.5), 0.1)
	var target: Control = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	await wait_seconds(0.5)

	assert_greater(target.scale.x, 1.1,
		"Progress Control SCALE: scale.x should grow (scale.x=%.2f)" % target.scale.x)

	await cleanup(target)


# =============================================================================
# TESTS: hold_on_stop
# =============================================================================

func test_hold_on_stop_true() -> void:
	var rig := await _create_progress_rig("prog_hold_true_ctrl",
		ProgressTransformControlJuiceEffect.TransformTarget.POSITION,
		Vector2(100.0, 0.0), 90.0, Vector2(0.5, 0.5), 0.1)
	var target: Control = rig[0]
	var juice: JuiceControl = rig[1]
	var effect: ProgressTransformControlJuiceEffect = rig[2]
	effect.hold_on_stop = true
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_out = 0.1
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT

	juice.animate_in()
	await wait_seconds(0.4)

	juice.animate_out()
	await wait_seconds(0.3)

	assert_greater(target.position.x, 1.0,
		"Progress Control hold_on_stop=true: should hold position after stop (x=%.1f)" % target.position.x)

	await cleanup(target)


func test_hold_on_stop_false() -> void:
	var rig := await _create_progress_rig("prog_hold_false_ctrl",
		ProgressTransformControlJuiceEffect.TransformTarget.POSITION,
		Vector2(100.0, 0.0), 90.0, Vector2(0.5, 0.5), 0.1)
	var target: Control = rig[0]
	var juice: JuiceControl = rig[1]
	var effect: ProgressTransformControlJuiceEffect = rig[2]
	effect.hold_on_stop = false

	juice.animate_in()
	await wait_seconds(0.4)

	# stop() triggers _restore_to_natural immediately, without an accumulation ramp.
	juice.stop()
	await wait_frames(3)

	assert_approx_float(target.position.x, 0.0,
		"Progress Control hold_on_stop=false: position should snap back (x=%.2f)" % target.position.x,
		5.0)

	await cleanup(target)


# =============================================================================
# TESTS: Bound
# =============================================================================

func test_bound_reverse() -> void:
	var target := Control.new()
	target.name = "prog_bound_ctrl"
	target.position = Vector2.ZERO
	target.custom_minimum_size = Vector2(80.0, 40.0)
	_runner.add_child(target)

	var effect := ProgressTransformControlJuiceEffect.new()
	effect.transform_target = ProgressTransformControlJuiceEffect.TransformTarget.POSITION
	effect.position_rate = Vector2(200.0, 0.0)
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.05
	effect.bound_enabled = true
	effect.bound_behaviour = ProgressTransformControlJuiceEffect.BoundBehaviour.REVERSE
	effect.bound_value = 50.0

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.6)

	assert_true(absf(target.position.x) <= 55.0,
		"Progress Control BOUND REVERSE: position should stay within bound (x=%.1f)" % target.position.x)

	await cleanup(target)


# =============================================================================
# TESTS: Sustain contract
# =============================================================================

func test_needs_sustain() -> void:
	var effect := ProgressTransformControlJuiceEffect.new()
	assert_true(effect._needs_sustain(),
		"ProgressTransformControlJuiceEffect must return true from _needs_sustain()")
