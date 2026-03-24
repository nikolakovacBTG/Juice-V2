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
		"test_is_reactive_flag",
		"test_scale_reacts_to_sibling_transform",
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
	# CoG at right-center (1.0, 0.5) — offset from pivot at center (0.5, 0.5)
	# Arm ratio = (0.5, 0.0). Vertical displacement creates cross product:
	# 0.5 * disp_y/box_y - 0.0 * disp_x/box_x = non-zero torque
	effect.center_of_gravity = Vector2(1.0, 0.5)
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

	# Get the runtime clone AFTER animate_in (arm is computed in _on_animate_start)
	var runtime_effect := juice._runtime_effects[0] as SpringControlJuiceEffect
	assert_true(runtime_effect._torque_arm != Vector2.ZERO,
		"Torque arm should be non-zero with CoG offset")

	# Displace position vertically — pixel-space torque: arm × disp / (mass * |arm|²)
	target.position += Vector2(0.0, 200.0)
	await wait_frames(3)

	# Rotation should have changed due to torque from position displacement
	assert_not_approx_float(target.rotation, natural_rot,
		"Rotation should change from torque (CoG offset + position displacement)", 0.001)

	await cleanup(target)


func test_is_reactive_flag() -> void:
	var spring := SpringControlJuiceEffect.new()
	assert_true(spring._is_reactive(), "Spring effect should report _is_reactive() = true")

	var transform := TransformControlJuiceEffect.new()
	assert_true(not transform._is_reactive(), "Transform effect should report _is_reactive() = false")


func test_scale_reacts_to_sibling_transform() -> void:
	# Spring (Scale) + Transform (Scale) on the SAME Juice node
	# When Transform animates scale, Spring should react via sibling displacement
	var target := create_control_target("SpringSiblingCtrl")

	var transform_effect := TransformControlJuiceEffect.new()
	transform_effect.transform_target = TransformControlJuiceEffect.TransformTarget.SCALE
	transform_effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	transform_effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	transform_effect.to_scale = Vector2(1.5, 1.5)
	transform_effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	transform_effect.duration_in = 0.3

	var spring_effect := SpringControlJuiceEffect.new()
	spring_effect.transform_target = SpringControlJuiceEffect.TransformTarget.SCALE
	spring_effect.stiffness = 50.0   # Low stiffness = slow return, easier to observe
	spring_effect.damping = 2.0      # Low damping = more oscillation
	spring_effect.mass = 1.0
	spring_effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	spring_effect.duration_in = 2.0

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(transform_effect)
	recipe.effects.append(spring_effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	var natural_scale := target.scale
	juice.animate_in()
	await wait_frames(10)

	# After enough frames, the Transform effect should have produced visible scale delta
	var scale_after := target.scale
	# Scale should have changed from natural (Transform is animating + Spring reacting)
	assert_not_approx_vec2(scale_after, natural_scale,
		"Scale should change from Transform + Spring sibling interaction", 0.001)

	# Access the runtime clones (not the originals we created)
	var rt_spring: SpringControlJuiceEffect = null
	for eff in juice._runtime_effects:
		if eff is SpringControlJuiceEffect:
			rt_spring = eff
			break
	assert_true(rt_spring != null, "Runtime Spring effect should exist")

	# Wait a few more frames while Transform is still animating
	await wait_frames(5)

	# The Spring should have been perturbed by sibling displacement
	if rt_spring != null:
		var has_state := rt_spring._current_scale != Vector2.ZERO or rt_spring._vel_scale != Vector2.ZERO
		assert_true(has_state,
			"Spring should have non-zero state from sibling Transform displacement")

	await cleanup(target)
