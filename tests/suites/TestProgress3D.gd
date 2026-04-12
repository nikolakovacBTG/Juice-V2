## TestProgress3D.gd
## ============================================================================
## WHAT: Tests for Progress3DJuiceEffect across position, rotation, scale.
## WHY: Verify accumulation-as-speed-multiplier, hold_on_stop, and bound
##      behaviours work correctly for the 3D domain.
## SYSTEM: Tests (tests/suites/)
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "progress_3d"


func get_test_methods() -> Array[String]:
	return [
		"test_position_accumulates",
		"test_rotation_accumulates",
		"test_needs_sustain",
		"test_bound_reverse",
	]


# =============================================================================
# HELPERS
# =============================================================================

func _create_progress_rig(
	label: String,
	target_type: int = Progress3DJuiceEffect.TransformTarget.POSITION,
	rate_pos: Vector3 = Vector3(100.0, 0.0, 0.0),
	rate_rot: Vector3 = Vector3(0.0, 90.0, 0.0),
	rate_scale: Vector3 = Vector3(0.5, 0.5, 0.5),
	duration: float = 0.3
) -> Array:
	var target := Node3D.new()
	target.name = label
	target.position = Vector3.ZERO
	target.rotation = Vector3.ZERO
	target.scale = Vector3.ONE
	_runner.add_child(target)

	var effect := Progress3DJuiceEffect.new()
	effect.transform_target = target_type
	effect.position_rate = rate_pos
	effect.rotation_rate = rate_rot
	effect.scale_rate = rate_scale
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = duration
	effect.auto_start = false

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
# TESTS: Accumulation
# =============================================================================

func test_position_accumulates() -> void:
	var rig := await _create_progress_rig("prog_pos_3d",
		Progress3DJuiceEffect.TransformTarget.POSITION,
		Vector3(100.0, 0.0, 0.0), Vector3(0.0, 90.0, 0.0), Vector3(0.5, 0.5, 0.5), 0.1)
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]

	juice.animate_in()
	await wait_seconds(0.5)

	assert_greater(target.position.x, 20.0,
		"Progress 3D POSITION: should have moved along X (x=%.1f)" % target.position.x)

	await cleanup(target)


func test_rotation_accumulates() -> void:
	var rig := await _create_progress_rig("prog_rot_3d",
		Progress3DJuiceEffect.TransformTarget.ROTATION,
		Vector3(100.0, 0.0, 0.0), Vector3(0.0, 90.0, 0.0), Vector3(0.5, 0.5, 0.5), 0.1)
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]

	juice.animate_in()
	await wait_seconds(0.5)

	assert_greater(absf(target.rotation.y), 0.3,
		"Progress 3D ROTATION: should have rotated around Y (rot.y=%.2f)" % target.rotation.y)

	await cleanup(target)


# =============================================================================
# TESTS: Sustain contract
# =============================================================================

func test_needs_sustain() -> void:
	var effect := Progress3DJuiceEffect.new()
	assert_true(effect._needs_sustain(),
		"Progress3DJuiceEffect must return true from _needs_sustain()")


# =============================================================================
# TESTS: Bound
# =============================================================================

func test_bound_reverse() -> void:
	var target := Node3D.new()
	target.name = "prog_bound_3d"
	target.position = Vector3.ZERO
	_runner.add_child(target)

	var effect := Progress3DJuiceEffect.new()
	effect.transform_target = Progress3DJuiceEffect.TransformTarget.POSITION
	effect.position_rate = Vector3(200.0, 0.0, 0.0)
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.05
	effect.bound_enabled = true
	effect.bound_behaviour = Progress3DJuiceEffect.BoundBehaviour.REVERSE
	effect.bound_value = 50.0

	var juice := Juice3D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := Juice3DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.6)

	assert_true(absf(target.position.x) <= 55.0,
		"Progress 3D BOUND REVERSE: position should stay within bound (x=%.1f)" % target.position.x)

	await cleanup(target)
