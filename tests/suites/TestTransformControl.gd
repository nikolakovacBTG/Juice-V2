## TestTransformControl.gd
## ============================================================================
## WHAT: Tests for TransformControlJuiceEffect across all property combinations.
## WHY: Verify position (all PositionIn units), rotation, scale, stacking,
##      and external-move detection work correctly.
## SYSTEM: Tests (tests/suites/)
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "transform_control"


func get_test_methods() -> Array[String]:
	return [
		"test_position_pixels",
		"test_position_own_size",
		"test_position_parent_size",
		"test_position_viewport_size",
		"test_rotation_degrees",
		"test_scale_uniform",
		"test_stacking_two_position_effects",
		"test_external_move_detection_position",
		"test_from_self_to_custom",
		"test_from_custom_to_self",
	]


# =============================================================================
# HELPER: Create a positioned rig inside a sized parent
# =============================================================================

func _create_sized_rig(
	label: String,
	parent_size: Vector2 = Vector2(400, 300),
	btn_size: Vector2 = Vector2(100, 40)
) -> Array:
	# Create a sized container parent so OWN_SIZE / PARENT_SIZE are testable
	var parent_ctrl := Control.new()
	parent_ctrl.size = parent_size
	parent_ctrl.position = Vector2.ZERO
	_runner.add_child(parent_ctrl)

	var btn := Button.new()
	btn.text = label
	btn.size = btn_size
	btn.position = Vector2.ZERO
	parent_ctrl.add_child(btn)

	return [parent_ctrl, btn]


func _add_juice_with_effect(
	btn: Button,
	effect: TransformControlJuiceEffect
) -> JuiceControl:
	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = effect.trigger_behaviour
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	btn.add_child(juice)
	await wait_frames(2)
	return juice


# =============================================================================
# TESTS: Position in different units
# =============================================================================

func test_position_pixels() -> void:
	var rig := _create_sized_rig("pos_pixels")
	var parent_ctrl: Control = rig[0]
	var btn: Button = rig[1]

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(50, 25)
	effect.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var juice := await _add_juice_with_effect(btn, effect)

	juice.animate_in()
	# Wait for animation to complete
	await wait_seconds(0.4)

	# At progress=1.0, position should be at To value (50, 25) in pixels
	assert_approx_vec2(btn.position, Vector2(50, 25),
		"PIXELS: target should be at (50, 25)", 3.0)

	await cleanup(parent_ctrl)


func test_position_own_size() -> void:
	var rig := _create_sized_rig("pos_own_size", Vector2(400, 300), Vector2(100, 40))
	var parent_ctrl: Control = rig[0]
	var btn: Button = rig[1]

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(1.0, 0.0)  # 1x own width
	effect.to_position_in = TransformControlJuiceEffect.PositionIn.OWN_SIZE
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var juice := await _add_juice_with_effect(btn, effect)

	# Read actual size AFTER layout (Button theme adds padding)
	var actual_width := btn.size.x

	juice.animate_in()
	await wait_seconds(0.4)

	# 1.0 * actual own size.x = actual_width px offset
	assert_approx_float(btn.position.x, actual_width,
		"OWN_SIZE: 1.0x own width (%.0f) should move that many px" % actual_width, 5.0)

	await cleanup(parent_ctrl)


func test_position_parent_size() -> void:
	var rig := _create_sized_rig("pos_parent_size", Vector2(400, 300), Vector2(100, 40))
	var parent_ctrl: Control = rig[0]
	var btn: Button = rig[1]

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(0.5, 0.0)  # 0.5 * parent width = 200px
	effect.to_position_in = TransformControlJuiceEffect.PositionIn.PARENT_SIZE
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var juice := await _add_juice_with_effect(btn, effect)

	juice.animate_in()
	await wait_seconds(0.4)

	# 0.5 * parent size (400, 300) = (200, 0) offset
	assert_approx_vec2(btn.position, Vector2(200, 0),
		"PARENT_SIZE: 0.5x parent width should move 200px", 5.0)

	await cleanup(parent_ctrl)


func test_position_viewport_size() -> void:
	var rig := _create_sized_rig("pos_viewport")
	var parent_ctrl: Control = rig[0]
	var btn: Button = rig[1]

	var viewport_size := Vector2(_runner.get_viewport().get_visible_rect().size)

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(0.25, 0.0)  # 0.25 * viewport width
	effect.to_position_in = TransformControlJuiceEffect.PositionIn.VIEWPORT_SIZE
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var juice := await _add_juice_with_effect(btn, effect)

	juice.animate_in()
	await wait_seconds(0.4)

	var expected_x := viewport_size.x * 0.25
	assert_approx_float(btn.position.x, expected_x,
		"VIEWPORT_SIZE: 0.25x viewport width should move %.0fpx" % expected_x, 5.0)

	await cleanup(parent_ctrl)


# =============================================================================
# TESTS: Rotation and Scale
# =============================================================================

func test_rotation_degrees() -> void:
	var rig := _create_sized_rig("rotation")
	var parent_ctrl: Control = rig[0]
	var btn: Button = rig[1]

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.ROTATION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_rotation_degrees = 45.0
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var juice := await _add_juice_with_effect(btn, effect)

	juice.animate_in()
	await wait_seconds(0.4)

	var expected_rad := deg_to_rad(45.0)
	assert_approx_float(btn.rotation, expected_rad,
		"Rotation: should be at 45 degrees (%.4f rad)" % expected_rad, 0.05)

	await cleanup(parent_ctrl)


func test_scale_uniform() -> void:
	var rig := _create_sized_rig("scale")
	var parent_ctrl: Control = rig[0]
	var btn: Button = rig[1]

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.SCALE
	effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_scale = Vector2(2.0, 2.0)
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var juice := await _add_juice_with_effect(btn, effect)

	juice.animate_in()
	await wait_seconds(0.4)

	# Scale delta should be (2.0 - 1.0, 2.0 - 1.0) = (1.0, 1.0), final = base + delta = (2.0, 2.0)
	assert_approx_vec2(btn.scale, Vector2(2.0, 2.0),
		"Scale: should be at (2.0, 2.0)", 0.1)

	await cleanup(parent_ctrl)


# =============================================================================
# TESTS: Stacking
# =============================================================================

func test_stacking_two_position_effects() -> void:
	var rig := _create_sized_rig("stacking")
	var parent_ctrl: Control = rig[0]
	var btn: Button = rig[1]

	# First effect: move right 50px
	var effect1 := TransformControlJuiceEffect.new()
	effect1.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect1.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect1.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect1.to_position = Vector2(50, 0)
	effect1.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect1.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect1.duration_in = 0.2

	# Second effect: move down 30px
	var effect2 := TransformControlJuiceEffect.new()
	effect2.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect2.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect2.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect2.to_position = Vector2(0, 30)
	effect2.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect2.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect2.duration_in = 0.2

	# Single recipe with both effects (stacked)
	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect1)
	recipe.effects.append(effect2)
	juice.recipe = recipe
	btn.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.4)

	# Both effects complete: position = base + (50,0) + (0,30) = (50, 30)
	assert_approx_vec2(btn.position, Vector2(50, 30),
		"Stacking: two position effects should sum to (50, 30)", 5.0)

	await cleanup(parent_ctrl)


# =============================================================================
# TESTS: External-move detection
# =============================================================================

func test_external_move_detection_position() -> void:
	var rig := _create_sized_rig("ext_move")
	var parent_ctrl: Control = rig[0]
	var btn: Button = rig[1]

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(100, 0)
	effect.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 1.0  # Longer duration so we can intervene

	var juice := await _add_juice_with_effect(btn, effect)

	juice.animate_in()
	await wait_seconds(0.2)

	# Externally move the button (simulating AnimationPlayer, Container, etc.)
	var _pos_before_move := btn.position
	btn.position += Vector2(0, 50)  # External vertical move

	await wait_seconds(0.3)

	# The vertical offset should be absorbed into base — animation continues horizontally
	# Final y should be ~50 (the external move) not ~0 (if external move was ignored)
	assert_greater(btn.position.y, 30.0,
		"External move: vertical offset should be preserved (y=%.1f should be >30)" % btn.position.y)

	await cleanup(parent_ctrl)


# =============================================================================
# TESTS: From/To reference directions
# =============================================================================

func test_from_self_to_custom() -> void:
	var rig := _create_sized_rig("self_to_custom")
	var parent_ctrl: Control = rig[0]
	var btn: Button = rig[1]
	btn.position = Vector2(20, 10)  # Start at non-zero position

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(80, 0)
	effect.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var juice := await _add_juice_with_effect(btn, effect)

	juice.animate_in()
	await wait_seconds(0.4)

	# CUSTOM position is base + offset. to_value = base(20,10) + (80,0) = (100, 10)
	# from = SELF = base(20,10), to = (100, 10)
	# At progress=1: desired = (100, 10), delta = (80, 0)
	# Final = base(20,10) + delta(80,0) = (100, 10)
	assert_approx_vec2(btn.position, Vector2(100, 10),
		"SELF→CUSTOM: base(20,10) + offset(80,0) = (100, 10)", 5.0)

	await cleanup(parent_ctrl)


func test_from_custom_to_self() -> void:
	var rig := _create_sized_rig("custom_to_self")
	var parent_ctrl: Control = rig[0]
	var btn: Button = rig[1]
	btn.position = Vector2(50, 20)  # Natural position

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.from_position = Vector2(-100, 0)
	effect.from_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect.to_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var juice := await _add_juice_with_effect(btn, effect)

	juice.animate_in()
	await wait_seconds(0.4)

	# From CUSTOM(-100,0) to SELF(50,20) — at progress=1, should be back at natural
	# Delta at progress=1 = to - from = (50,20) - (-100,0) = (150, 20)
	# But at progress=1, desired_absolute = self = (50,20), so delta = 0
	# Target should be at base = (50, 20)
	assert_approx_vec2(btn.position, Vector2(50, 20),
		"CUSTOM→SELF: at completion should return to natural position (50,20)", 5.0)

	await cleanup(parent_ctrl)
