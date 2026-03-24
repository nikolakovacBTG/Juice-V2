## TestMultiWriter.gd
## ============================================================================
## WHAT: Tests for multi-writer contribution tracking across all 3 domains.
## WHY: Verify that multiple Juice nodes on the same target write independently
##      without overwriting each other's contributions (no 1-frame flash).
## SYSTEM: Tests (tests/suites/)
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "multi_writer"


func get_test_methods() -> Array[String]:
	return [
		# Control domain
		"test_control_two_nodes_additive",
		"test_control_no_flash_at_natural",
		"test_control_stop_one_preserves_other",
		"test_control_sequential_start",
		# 2D domain
		"test_2d_two_nodes_additive",
		"test_2d_stop_one_preserves_other",
		# 3D domain
		"test_3d_two_nodes_additive",
		"test_3d_stop_one_preserves_other",
	]


# =============================================================================
# HELPERS
# =============================================================================

func _make_control_transform_effect(
	target_prop: int,  # TransformControlJuiceEffect.TransformTarget
	to_pos: Vector2 = Vector2.ZERO,
	to_rot_deg: float = 0.0,
	to_scale: Vector2 = Vector2.ONE,
	duration: float = 0.15
) -> TransformControlJuiceEffect:
	var eff := TransformControlJuiceEffect.new()
	eff.transform_target = target_prop
	eff.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	eff.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	eff.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	eff.duration_in = duration
	match target_prop:
		TransformControlJuiceEffect.TransformTarget.POSITION:
			eff.to_position = to_pos
			eff.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
		TransformControlJuiceEffect.TransformTarget.ROTATION:
			eff.to_rotation_degrees = to_rot_deg
		TransformControlJuiceEffect.TransformTarget.SCALE:
			eff.to_scale = to_scale
	return eff


func _attach_juice_control(target: Control, effect: JuiceControlEffectBase) -> JuiceControl:
	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = effect.trigger_behaviour
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	return juice


func _make_2d_transform_effect(
	target_prop: int,
	to_pos: Vector2 = Vector2.ZERO,
	to_rot_deg: float = 0.0,
	to_scale: Vector2 = Vector2.ONE,
	duration: float = 0.15
) -> Transform2DJuiceEffect:
	var eff := Transform2DJuiceEffect.new()
	eff.transform_target = target_prop
	eff.from_reference = Transform2DJuiceEffect.TransformReference.SELF
	eff.to_reference = Transform2DJuiceEffect.TransformReference.CUSTOM
	eff.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	eff.duration_in = duration
	match target_prop:
		Transform2DJuiceEffect.TransformTarget.POSITION:
			eff.to_position = to_pos
			eff.to_position_in = Transform2DJuiceEffect.PositionIn.PIXELS
		Transform2DJuiceEffect.TransformTarget.ROTATION:
			eff.to_rotation_degrees = to_rot_deg
		Transform2DJuiceEffect.TransformTarget.SCALE:
			eff.to_scale = to_scale
	return eff


func _attach_juice_2d(target: Node2D, effect: Juice2DTransformEffect) -> Juice2D:
	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = effect.trigger_behaviour
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	return juice


func _make_3d_transform_effect(
	target_prop: int,
	to_pos: Vector3 = Vector3.ZERO,
	to_rot_deg: Vector3 = Vector3.ZERO,
	to_scale: Vector3 = Vector3.ONE,
	duration: float = 0.15
) -> Transform3DJuiceEffect:
	var eff := Transform3DJuiceEffect.new()
	eff.transform_target = target_prop
	eff.from_reference = Transform3DJuiceEffect.TransformReference.SELF
	eff.to_reference = Transform3DJuiceEffect.TransformReference.CUSTOM
	eff.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	eff.duration_in = duration
	match target_prop:
		Transform3DJuiceEffect.TransformTarget.POSITION:
			eff.to_position = to_pos
			eff.to_position_in = Transform3DJuiceEffect.PositionIn3D.WORLD_UNITS
		Transform3DJuiceEffect.TransformTarget.ROTATION:
			eff.to_rotation_degrees = to_rot_deg
		Transform3DJuiceEffect.TransformTarget.SCALE:
			eff.to_scale = to_scale
	return eff


func _attach_juice_3d(target: Node3D, effect: Juice3DTransformEffect) -> Juice3D:
	var juice := Juice3D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = effect.trigger_behaviour
	var recipe := Juice3DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	return juice


# =============================================================================
# CONTROL DOMAIN TESTS
# =============================================================================

func test_control_two_nodes_additive() -> void:
	var btn := Button.new()
	btn.text = "mw_additive"
	btn.position = Vector2.ZERO
	_runner.add_child(btn)

	# Node A: move right 60px
	var eff_a := _make_control_transform_effect(
		TransformControlJuiceEffect.TransformTarget.POSITION,
		Vector2(60, 0))
	var juice_a := _attach_juice_control(btn, eff_a)

	# Node B: move down 40px
	var eff_b := _make_control_transform_effect(
		TransformControlJuiceEffect.TransformTarget.POSITION,
		Vector2(0, 40))
	var juice_b := _attach_juice_control(btn, eff_b)

	await wait_frames(2)

	juice_a.animate_in()
	juice_b.animate_in()
	await wait_seconds(0.3)

	# Both contributions should be additive: (60, 0) + (0, 40) = (60, 40)
	assert_approx_vec2(btn.position, Vector2(60, 40),
		"Control multi-writer: two nodes should sum to (60, 40)", 5.0)

	await cleanup(btn)


func test_control_no_flash_at_natural() -> void:
	var btn := Button.new()
	btn.text = "mw_no_flash"
	btn.position = Vector2(100, 50)
	_runner.add_child(btn)
	var natural_pos := Vector2(100, 50)

	# Node A: teleport off-screen then animate in (From CUSTOM, To SELF)
	var eff_a := TransformControlJuiceEffect.new()
	eff_a.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	eff_a.from_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	eff_a.from_position = Vector2(-500, 0)
	eff_a.from_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	eff_a.to_reference = TransformControlJuiceEffect.TransformReference.SELF
	eff_a.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	eff_a.duration_in = 0.5
	var juice_a := _attach_juice_control(btn, eff_a)

	# Node B: noise-like small offset (constant contribution)
	var eff_b := _make_control_transform_effect(
		TransformControlJuiceEffect.TransformTarget.POSITION,
		Vector2(10, 10), 0.0, Vector2.ONE, 0.5)
	var juice_b := _attach_juice_control(btn, eff_b)

	await wait_frames(2)

	# Start both simultaneously
	juice_a.animate_in()
	juice_b.animate_in()

	# Check position on the VERY FIRST frame after start
	await wait_frames(1)

	# Position should NOT be at natural — Node A's From offset (-500) should be applied
	# If there was a 1-frame flash, position would briefly be at natural (100, 50)
	var first_frame_pos := btn.position
	var dist_from_natural := first_frame_pos.distance_to(natural_pos)
	assert_greater(dist_from_natural, 50.0,
		"No flash: first frame should be far from natural (dist=%.1f, pos=%s)" % [
			dist_from_natural, first_frame_pos])

	await cleanup(btn)


func test_control_stop_one_preserves_other() -> void:
	var btn := Button.new()
	btn.text = "mw_stop_one"
	btn.position = Vector2.ZERO
	_runner.add_child(btn)

	# Node A: move right 80px
	var eff_a := _make_control_transform_effect(
		TransformControlJuiceEffect.TransformTarget.POSITION,
		Vector2(80, 0), 0.0, Vector2.ONE, 0.5)
	var juice_a := _attach_juice_control(btn, eff_a)

	# Node B: move down 50px (shorter duration — will complete first)
	var eff_b := _make_control_transform_effect(
		TransformControlJuiceEffect.TransformTarget.POSITION,
		Vector2(0, 50), 0.0, Vector2.ONE, 0.15)
	var juice_b := _attach_juice_control(btn, eff_b)

	await wait_frames(2)

	juice_a.animate_in()
	juice_b.animate_in()

	# Wait for B to complete but A still running
	await wait_seconds(0.25)

	# B finished (delta = 0 after completion), A still animating
	# Position should reflect A's progress only — no Y offset from B anymore
	# because B's contribution is cleared after completion (stop → _post_tick_write)
	var pos_after_b_done := btn.position

	# A is still running — x should be between 0 and 80
	assert_greater(pos_after_b_done.x, 20.0,
		"Stop one: A still running, x should be >20 (actual=%.1f)" % pos_after_b_done.x)

	# Wait for A to complete
	await wait_seconds(0.5)

	# Both done — PLAY_IN_ONLY holds at progress=1.0, so both deltas persist:
	# A's delta = (80, 0), B's delta = (0, 50). Sum = (80, 50).
	assert_approx_vec2(btn.position, Vector2(80, 50),
		"Stop one: after both complete, pos should be (80, 50)", 5.0)

	await cleanup(btn)


func test_control_sequential_start() -> void:
	var btn := Button.new()
	btn.text = "mw_sequential"
	btn.position = Vector2.ZERO
	_runner.add_child(btn)

	# Node A: move right 50px
	var eff_a := _make_control_transform_effect(
		TransformControlJuiceEffect.TransformTarget.POSITION,
		Vector2(50, 0), 0.0, Vector2.ONE, 0.15)
	var juice_a := _attach_juice_control(btn, eff_a)

	# Node B: move down 30px
	var eff_b := _make_control_transform_effect(
		TransformControlJuiceEffect.TransformTarget.POSITION,
		Vector2(0, 30), 0.0, Vector2.ONE, 0.15)
	var juice_b := _attach_juice_control(btn, eff_b)

	await wait_frames(2)

	# Start A first
	juice_a.animate_in()
	await wait_seconds(0.05)

	# A is mid-animation — check position is moving right
	var mid_pos := btn.position
	assert_greater(mid_pos.x, 5.0,
		"Sequential: A mid-animation, x should be >5 (actual=%.1f)" % mid_pos.x)

	# Now start B while A is still running
	juice_b.animate_in()
	await wait_seconds(0.3)

	# Both should have completed — contributions additive
	assert_approx_vec2(btn.position, Vector2(50, 30),
		"Sequential: after both complete, should be (50, 30)", 5.0)

	await cleanup(btn)


# =============================================================================
# 2D DOMAIN TESTS
# =============================================================================

func test_2d_two_nodes_additive() -> void:
	var target := Node2D.new()
	target.position = Vector2.ZERO
	_runner.add_child(target)

	var eff_a := _make_2d_transform_effect(
		Transform2DJuiceEffect.TransformTarget.POSITION,
		Vector2(70, 0))
	var juice_a := _attach_juice_2d(target, eff_a)

	var eff_b := _make_2d_transform_effect(
		Transform2DJuiceEffect.TransformTarget.POSITION,
		Vector2(0, 45))
	var juice_b := _attach_juice_2d(target, eff_b)

	await wait_frames(2)

	juice_a.animate_in()
	juice_b.animate_in()
	await wait_seconds(0.3)

	assert_approx_vec2(target.position, Vector2(70, 45),
		"2D multi-writer: two nodes should sum to (70, 45)", 5.0)

	await cleanup(target)


func test_2d_stop_one_preserves_other() -> void:
	var target := Node2D.new()
	target.position = Vector2.ZERO
	_runner.add_child(target)

	# A: long animation
	var eff_a := _make_2d_transform_effect(
		Transform2DJuiceEffect.TransformTarget.POSITION,
		Vector2(100, 0), 0.0, Vector2.ONE, 0.5)
	var juice_a := _attach_juice_2d(target, eff_a)

	# B: short animation
	var eff_b := _make_2d_transform_effect(
		Transform2DJuiceEffect.TransformTarget.POSITION,
		Vector2(0, 60), 0.0, Vector2.ONE, 0.15)
	var juice_b := _attach_juice_2d(target, eff_b)

	await wait_frames(2)

	juice_a.animate_in()
	juice_b.animate_in()
	await wait_seconds(0.25)

	# B completed, A still running — x should be progressing
	assert_greater(target.position.x, 20.0,
		"2D stop one: A still running, x should be >20 (actual=%.1f)" % target.position.x)

	await cleanup(target)


# =============================================================================
# 3D DOMAIN TESTS
# =============================================================================

func test_3d_two_nodes_additive() -> void:
	var target := Node3D.new()
	target.position = Vector3.ZERO
	_runner.add_child(target)

	var eff_a := _make_3d_transform_effect(
		Transform3DJuiceEffect.TransformTarget.POSITION,
		Vector3(5, 0, 0))
	var juice_a := _attach_juice_3d(target, eff_a)

	var eff_b := _make_3d_transform_effect(
		Transform3DJuiceEffect.TransformTarget.POSITION,
		Vector3(0, 3, 0))
	var juice_b := _attach_juice_3d(target, eff_b)

	await wait_frames(2)

	juice_a.animate_in()
	juice_b.animate_in()
	await wait_seconds(0.3)

	assert_approx_vec3(target.position, Vector3(5, 3, 0),
		"3D multi-writer: two nodes should sum to (5, 3, 0)", 0.5)

	await cleanup(target)


func test_3d_stop_one_preserves_other() -> void:
	var target := Node3D.new()
	target.position = Vector3.ZERO
	_runner.add_child(target)

	# A: long animation
	var eff_a := _make_3d_transform_effect(
		Transform3DJuiceEffect.TransformTarget.POSITION,
		Vector3(8, 0, 0), Vector3.ZERO, Vector3.ONE, 0.5)
	var juice_a := _attach_juice_3d(target, eff_a)

	# B: short animation
	var eff_b := _make_3d_transform_effect(
		Transform3DJuiceEffect.TransformTarget.POSITION,
		Vector3(0, 4, 0), Vector3.ZERO, Vector3.ONE, 0.15)
	var juice_b := _attach_juice_3d(target, eff_b)

	await wait_frames(2)

	juice_a.animate_in()
	juice_b.animate_in()
	await wait_seconds(0.25)

	# B completed, A still running
	assert_greater(target.position.x, 2.0,
		"3D stop one: A still running, x should be >2 (actual=%.3f)" % target.position.x)

	await cleanup(target)
