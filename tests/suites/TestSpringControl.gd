## TestSpringControl.gd
## ============================================================================
## WHAT: Tests for SpringControlJuiceEffect (reactive-only design).
## TESTS: Starts at rest, reacts to external displacement (pos/rot/scale),
##        settles back after displacement, rotation torque from CoG offset.
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "spring_control"


func get_test_methods() -> Array[String]:
	return [
		"test_starts_at_rest",
		"test_reacts_to_position_displacement",
		"test_reacts_to_rotation_displacement",
		"test_reacts_to_scale_displacement",
		"test_settles_back_after_displacement",
		"test_rotation_torque_from_cog_offset",
	]


# =============================================================================
# HELPERS
# =============================================================================

func _create_spring_rig(
	label: String,
	target_type: int = SpringControlJuiceEffect.TransformTarget.POSITION,
	duration: float = 2.0
) -> Array:
	var target := create_control_target(label)

	var effect := SpringControlJuiceEffect.new()
	effect.transform_target = target_type
	effect.stiffness = 300.0
	effect.damping = 10.0
	effect.mass = 1.0
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = duration

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

func test_starts_at_rest() -> void:
	var rig := await _create_spring_rig("SpringRestCtrl")
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]
	var natural_pos := target.position

	juice.animate_in()
	await wait_frames(5)

	# Reactive spring with no external displacement should stay at rest
	assert_approx_vec2(target.position, natural_pos,
		"Spring should remain at rest with no external force", 0.5)

	await cleanup(target)


func test_reacts_to_position_displacement() -> void:
	var rig := await _create_spring_rig("SpringPosCtrl",
		SpringControlJuiceEffect.TransformTarget.POSITION)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	await wait_frames(2)

	# Externally displace the target
	target.position += Vector2(50.0, 0.0)
	var displaced_pos := target.position

	# Wait for spring to react (a few frames)
	await wait_frames(5)

	# Spring should be counteracting the displacement (pulling back)
	# Target should NOT be exactly at the displaced position
	assert_not_approx_vec2(target.position, displaced_pos,
		"Position should differ as spring reacts to displacement", 1.0)

	await cleanup(target)


func test_reacts_to_rotation_displacement() -> void:
	var rig := await _create_spring_rig("SpringRotCtrl",
		SpringControlJuiceEffect.TransformTarget.ROTATION)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	await wait_frames(2)

	# Externally rotate the target
	target.rotation += deg_to_rad(30.0)
	var displaced_rot := target.rotation

	await wait_frames(5)

	# Spring should be counteracting the rotation
	assert_not_approx_float(target.rotation, displaced_rot,
		"Rotation should differ as spring reacts to displacement", 0.01)

	await cleanup(target)


func test_reacts_to_scale_displacement() -> void:
	var rig := await _create_spring_rig("SpringScaleCtrl",
		SpringControlJuiceEffect.TransformTarget.SCALE)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	await wait_frames(2)

	# Externally scale the target
	target.scale += Vector2(0.5, 0.5)
	var displaced_scale := target.scale

	await wait_frames(5)

	# Spring should be counteracting the scale change
	assert_not_approx_vec2(target.scale, displaced_scale,
		"Scale should differ as spring reacts to displacement", 0.01)

	await cleanup(target)


func test_settles_back_after_displacement() -> void:
	# Use high damping so it settles quickly
	var target := create_control_target("SpringSettleCtrl")
	var effect := SpringControlJuiceEffect.new()
	effect.transform_target = SpringControlJuiceEffect.TransformTarget.POSITION
	effect.stiffness = 300.0
	effect.damping = 25.0  # High damping for fast settle
	effect.mass = 1.0
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 3.0

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_frames(2)

	# Externally displace
	target.position += Vector2(30.0, 0.0)
	var displaced_pos := target.position

	# Wait for spring to settle — it should return to the displaced position
	# (spring pulls back to rest = zero delta, so final = base + 0 = displaced base)
	await wait_seconds(1.0)

	assert_approx_vec2(target.position, displaced_pos,
		"Spring should settle at displaced position (zero delta)", 2.0)

	await cleanup(target)


func test_rotation_torque_from_cog_offset() -> void:
	var target := create_control_target("SpringTorqueCtrl")
	# Set a known size for deterministic CoG calculation
	target.custom_minimum_size = Vector2(100, 100)
	target.size = Vector2(100, 100)

	var effect := SpringControlJuiceEffect.new()
	effect.transform_target = SpringControlJuiceEffect.TransformTarget.ROTATION
	effect.stiffness = 300.0
	effect.damping = 10.0
	effect.mass = 1.0
	# CoG at bottom-center (0.5, 1.0) — offset from pivot at center (0.5, 0.5)
	effect.center_of_gravity = Vector2(0.5, 1.0)
	effect.pivot_mode = SpringControlJuiceEffect.PivotMode.AUTO_CENTER
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 2.0

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	var natural_rot := target.rotation
	juice.animate_in()
	await wait_frames(2)

	# Displace position horizontally — with CoG below pivot, this should create torque
	target.position += Vector2(40.0, 0.0)
	await wait_frames(5)

	# Rotation should have changed due to torque from position displacement
	assert_not_approx_float(target.rotation, natural_rot,
		"Rotation should change from torque (CoG offset + position displacement)", 0.001)

	await cleanup(target)
