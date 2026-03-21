## TestTransform3D.gd
## ============================================================================
## WHAT: Tests for Transform3DJuiceEffect across all property combinations.
## WHY: Verify position (all PositionIn3D units), rotation, scale, stacking,
##      and external-move detection work correctly for 3D domain.
## SYSTEM: Tests (tests/suites/)
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "transform_3d"


func get_test_methods() -> Array[String]:
	return [
		"test_position_world_units",
		"test_rotation_degrees",
		"test_scale_uniform",
		"test_stacking_two_position_effects",
		"test_external_move_detection_position",
	]


# =============================================================================
# HELPER
# =============================================================================

func _create_3d_rig(
	label: String,
	to_pos: Vector3 = Vector3(5, 0, 0),
	duration: float = 0.2
) -> Array:
	var target := Node3D.new()
	target.name = label
	target.position = Vector3.ZERO
	_runner.add_child(target)

	var effect := Transform3DJuiceEffect.new()
	effect.transform_target = Transform3DJuiceEffect.TransformTarget.POSITION
	effect.from_reference = Transform3DJuiceEffect.TransformReference.SELF
	effect.to_reference = Transform3DJuiceEffect.TransformReference.CUSTOM
	effect.to_position = to_pos
	effect.to_position_in = Transform3DJuiceEffect.PositionIn3D.WORLD_UNITS
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
# TESTS: Position
# =============================================================================

func test_position_world_units() -> void:
	var rig := await _create_3d_rig("pos_wu_3d", Vector3(3, 2, 1), 0.2)
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]

	juice.animate_in()
	await wait_seconds(0.4)

	assert_approx_vec3(target.position, Vector3(3, 2, 1),
		"3D WORLD_UNITS: target should be at (3, 2, 1)", 0.1)

	await cleanup(target)


# =============================================================================
# TESTS: Rotation and Scale
# =============================================================================

func test_rotation_degrees() -> void:
	var target := Node3D.new()
	target.position = Vector3.ZERO
	_runner.add_child(target)

	var effect := Transform3DJuiceEffect.new()
	effect.transform_target = Transform3DJuiceEffect.TransformTarget.ROTATION
	effect.from_reference = Transform3DJuiceEffect.TransformReference.SELF
	effect.to_reference = Transform3DJuiceEffect.TransformReference.CUSTOM
	effect.to_rotation = Vector3(0, 90, 0)
	effect.rotation_unit = JuiceEffectBase.RotationUnit.DEGREES
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var juice := Juice3D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := Juice3DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.4)

	var expected_y := deg_to_rad(90.0)
	assert_approx_float(target.rotation.y, expected_y,
		"3D Rotation: Y should be 90 degrees (%.4f rad)" % expected_y, 0.05)

	await cleanup(target)


func test_scale_uniform() -> void:
	var target := Node3D.new()
	target.position = Vector3.ZERO
	_runner.add_child(target)

	var effect := Transform3DJuiceEffect.new()
	effect.transform_target = Transform3DJuiceEffect.TransformTarget.SCALE
	effect.from_reference = Transform3DJuiceEffect.TransformReference.SELF
	effect.to_reference = Transform3DJuiceEffect.TransformReference.CUSTOM
	effect.to_scale = Vector3(2.0, 2.0, 2.0)
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var juice := Juice3D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := Juice3DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.4)

	assert_approx_vec3(target.scale, Vector3(2.0, 2.0, 2.0),
		"3D Scale: should be at (2, 2, 2)", 0.1)

	await cleanup(target)


# =============================================================================
# TESTS: Stacking and External-move
# =============================================================================

func test_stacking_two_position_effects() -> void:
	var target := Node3D.new()
	target.position = Vector3.ZERO
	_runner.add_child(target)

	var effect1 := Transform3DJuiceEffect.new()
	effect1.transform_target = Transform3DJuiceEffect.TransformTarget.POSITION
	effect1.from_reference = Transform3DJuiceEffect.TransformReference.SELF
	effect1.to_reference = Transform3DJuiceEffect.TransformReference.CUSTOM
	effect1.to_position = Vector3(3, 0, 0)
	effect1.to_position_in = Transform3DJuiceEffect.PositionIn3D.WORLD_UNITS
	effect1.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect1.duration_in = 0.2

	var effect2 := Transform3DJuiceEffect.new()
	effect2.transform_target = Transform3DJuiceEffect.TransformTarget.POSITION
	effect2.from_reference = Transform3DJuiceEffect.TransformReference.SELF
	effect2.to_reference = Transform3DJuiceEffect.TransformReference.CUSTOM
	effect2.to_position = Vector3(0, 2, 0)
	effect2.to_position_in = Transform3DJuiceEffect.PositionIn3D.WORLD_UNITS
	effect2.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect2.duration_in = 0.2

	var juice := Juice3D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := Juice3DRecipe.new()
	recipe.effects.append(effect1)
	recipe.effects.append(effect2)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.4)

	assert_approx_vec3(target.position, Vector3(3, 2, 0),
		"3D Stacking: two position effects should sum to (3, 2, 0)", 0.1)

	await cleanup(target)


func test_external_move_detection_position() -> void:
	var target := Node3D.new()
	target.position = Vector3.ZERO
	_runner.add_child(target)

	var effect := Transform3DJuiceEffect.new()
	effect.transform_target = Transform3DJuiceEffect.TransformTarget.POSITION
	effect.from_reference = Transform3DJuiceEffect.TransformReference.SELF
	effect.to_reference = Transform3DJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector3(5, 0, 0)
	effect.to_position_in = Transform3DJuiceEffect.PositionIn3D.WORLD_UNITS
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 1.0

	var juice := Juice3D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := Juice3DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.2)

	# External move
	target.position += Vector3(0, 3, 0)
	await wait_seconds(0.3)

	assert_greater(target.position.y, 2.0,
		"3D External move: y offset should be preserved (y=%.2f)" % target.position.y)

	await cleanup(target)
