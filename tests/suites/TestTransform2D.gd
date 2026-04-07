## TestTransform2D.gd
## ============================================================================
## WHAT: Tests for Transform2DJuiceEffect across all property combinations.
## WHY: Verify position (all PositionIn units), rotation, scale, stacking,
##      and external-move detection work correctly for 2D domain.
## SYSTEM: Tests (tests/suites/)
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "transform_2d"


func get_test_methods() -> Array[String]:
	return [
		"test_position_pixels",
		"test_position_own_size",
		"test_rotation_degrees",
		"test_scale_uniform",
		"test_stacking_two_position_effects",
		"test_stacking_cross_node",
		"test_external_move_detection_position",
		"test_autoconnect_area2d_body_entered",
		"test_autoconnect_area2d_hover",
	]


# =============================================================================
# HELPER: Create a Juice2D rig with a Node2D target
# =============================================================================

func _create_2d_rig(
	label: String,
	to_pos: Vector2 = Vector2(100, 0),
	duration: float = 0.2
) -> Array:
	var target := Node2D.new()
	target.name = label
	target.position = Vector2.ZERO
	_runner.add_child(target)

	var effect := Transform2DJuiceEffect.new()
	effect.transform_target = Transform2DJuiceEffect.TransformTarget.POSITION
	effect.from_reference = Transform2DJuiceEffect.TransformReference.SELF
	effect.to_reference = Transform2DJuiceEffect.TransformReference.CUSTOM
	effect.to_position = to_pos
	effect.to_position_in = Transform2DJuiceEffect.PositionIn.PIXELS
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
# TESTS: Position
# =============================================================================

func test_position_pixels() -> void:
	var rig := await _create_2d_rig("pos_px_2d", Vector2(75, 50), 0.2)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.4)

	assert_approx_vec2(target.position, Vector2(75, 50),
		"2D PIXELS: target should be at (75, 50)", 3.0)

	await cleanup(target)


func test_position_own_size() -> void:
	# Node2D doesn't have inherent "size" — OWN_SIZE infers from child Sprite2D etc.
	# Without a visual child, _infer_node2d_size returns fallback. Test with pixels instead.
	var target := Node2D.new()
	target.position = Vector2.ZERO
	_runner.add_child(target)

	# Add a Sprite2D so _infer_node2d_size can detect a size
	var sprite := Sprite2D.new()
	# Create a simple placeholder texture (8x8 white)
	var img := Image.create(80, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(img)
	target.add_child(sprite)

	var effect := Transform2DJuiceEffect.new()
	effect.transform_target = Transform2DJuiceEffect.TransformTarget.POSITION
	effect.from_reference = Transform2DJuiceEffect.TransformReference.SELF
	effect.to_reference = Transform2DJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(1.0, 0.0)  # 1x own width
	effect.to_position_in = Transform2DJuiceEffect.PositionIn.OWN_SIZE
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.4)

	# 1.0 * sprite width (80px) = 80px horizontal move
	assert_approx_float(target.position.x, 80.0,
		"2D OWN_SIZE: 1.0x own width should move ~80px", 10.0)

	await cleanup(target)


# =============================================================================
# TESTS: Rotation and Scale
# =============================================================================

func test_rotation_degrees() -> void:
	var target := Node2D.new()
	target.position = Vector2.ZERO
	_runner.add_child(target)

	var effect := Transform2DJuiceEffect.new()
	effect.transform_target = Transform2DJuiceEffect.TransformTarget.ROTATION
	effect.from_reference = Transform2DJuiceEffect.TransformReference.SELF
	effect.to_reference = Transform2DJuiceEffect.TransformReference.CUSTOM
	effect.to_rotation_degrees = 90.0
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.4)

	var expected_rad := deg_to_rad(90.0)
	assert_approx_float(target.rotation, expected_rad,
		"2D Rotation: should be at 90 degrees", 0.05)

	await cleanup(target)


func test_scale_uniform() -> void:
	var target := Node2D.new()
	target.position = Vector2.ZERO
	_runner.add_child(target)

	var effect := Transform2DJuiceEffect.new()
	effect.transform_target = Transform2DJuiceEffect.TransformTarget.SCALE
	effect.from_reference = Transform2DJuiceEffect.TransformReference.SELF
	effect.to_reference = Transform2DJuiceEffect.TransformReference.CUSTOM
	effect.to_scale = Vector2(3.0, 3.0)
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.4)

	assert_approx_vec2(target.scale, Vector2(3.0, 3.0),
		"2D Scale: should be at (3.0, 3.0)", 0.1)

	await cleanup(target)


# =============================================================================
# TESTS: Stacking and External-move
# =============================================================================

func test_stacking_two_position_effects() -> void:
	var target := Node2D.new()
	target.position = Vector2.ZERO
	_runner.add_child(target)

	var effect1 := Transform2DJuiceEffect.new()
	effect1.transform_target = Transform2DJuiceEffect.TransformTarget.POSITION
	effect1.from_reference = Transform2DJuiceEffect.TransformReference.SELF
	effect1.to_reference = Transform2DJuiceEffect.TransformReference.CUSTOM
	effect1.to_position = Vector2(60, 0)
	effect1.to_position_in = Transform2DJuiceEffect.PositionIn.PIXELS
	effect1.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect1.duration_in = 0.2

	var effect2 := Transform2DJuiceEffect.new()
	effect2.transform_target = Transform2DJuiceEffect.TransformTarget.POSITION
	effect2.from_reference = Transform2DJuiceEffect.TransformReference.SELF
	effect2.to_reference = Transform2DJuiceEffect.TransformReference.CUSTOM
	effect2.to_position = Vector2(0, 40)
	effect2.to_position_in = Transform2DJuiceEffect.PositionIn.PIXELS
	effect2.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect2.duration_in = 0.2

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect1)
	recipe.effects.append(effect2)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.4)

	assert_approx_vec2(target.position, Vector2(60, 40),
		"2D Stacking: two position effects should sum to (60, 40)", 5.0)

	await cleanup(target)


func test_stacking_cross_node() -> void:
	var target := Node2D.new()
	target.position = Vector2.ZERO
	_runner.add_child(target)

	# Node A: move right 40
	var eff_a := Transform2DJuiceEffect.new()
	eff_a.transform_target = Transform2DJuiceEffect.TransformTarget.POSITION
	eff_a.from_reference = Transform2DJuiceEffect.TransformReference.SELF
	eff_a.to_reference = Transform2DJuiceEffect.TransformReference.CUSTOM
	eff_a.to_position = Vector2(40, 0)
	eff_a.to_position_in = Transform2DJuiceEffect.PositionIn.PIXELS
	eff_a.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	eff_a.duration_in = 0.15

	var juice_a := Juice2D.new()
	juice_a.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice_a.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe_a := Juice2DRecipe.new()
	recipe_a.effects.append(eff_a)
	juice_a.recipe = recipe_a
	target.add_child(juice_a)

	# Node B: move up 25
	var eff_b := Transform2DJuiceEffect.new()
	eff_b.transform_target = Transform2DJuiceEffect.TransformTarget.POSITION
	eff_b.from_reference = Transform2DJuiceEffect.TransformReference.SELF
	eff_b.to_reference = Transform2DJuiceEffect.TransformReference.CUSTOM
	eff_b.to_position = Vector2(0, 25)
	eff_b.to_position_in = Transform2DJuiceEffect.PositionIn.PIXELS
	eff_b.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	eff_b.duration_in = 0.15

	var juice_b := Juice2D.new()
	juice_b.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice_b.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe_b := Juice2DRecipe.new()
	recipe_b.effects.append(eff_b)
	juice_b.recipe = recipe_b
	target.add_child(juice_b)

	await wait_frames(2)
	juice_a.animate_in()
	juice_b.animate_in()
	await wait_seconds(0.3)

	assert_approx_vec2(target.position, Vector2(40, 25),
		"2D Cross-node stacking: two nodes should sum to (40, 25)", 5.0)

	await cleanup(target)


func test_autoconnect_area2d_body_entered() -> void:
	# Area2D with ON_PRESS: body_entered triggers animation
	var area := Area2D.new()
	area.position = Vector2.ZERO
	_runner.add_child(area)

	var effect := Transform2DJuiceEffect.new()
	effect.transform_target = Transform2DJuiceEffect.TransformTarget.POSITION
	effect.from_reference = Transform2DJuiceEffect.TransformReference.SELF
	effect.to_reference = Transform2DJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(80, 0)
	effect.to_position_in = Transform2DJuiceEffect.PositionIn.PIXELS
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.15

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.ON_PRESS
	juice.auto_connect_parent = true
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	area.add_child(juice)
	await wait_frames(3)

	# Emit body_entered (connected for ON_PRESS on Area2D)
	var dummy_body := Node2D.new()
	_runner.add_child(dummy_body)
	area.emit_signal("body_entered", dummy_body)
	await wait_seconds(0.3)

	assert_true(area.position.x > 50.0,
		"Auto-connect Area2D ON_PRESS: body_entered should trigger animation (pos.x=%.1f)" % area.position.x)

	await cleanup(dummy_body)
	await cleanup(area)


func test_autoconnect_area2d_hover() -> void:
	# Area2D with ON_MOUSE_ENTERED: mouse_entered triggers animation
	var area := Area2D.new()
	area.position = Vector2.ZERO
	_runner.add_child(area)

	var effect := Transform2DJuiceEffect.new()
	effect.transform_target = Transform2DJuiceEffect.TransformTarget.POSITION
	effect.from_reference = Transform2DJuiceEffect.TransformReference.SELF
	effect.to_reference = Transform2DJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(80, 0)
	effect.to_position_in = Transform2DJuiceEffect.PositionIn.PIXELS
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.15

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.ON_MOUSE_ENTERED
	juice.auto_connect_parent = true
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	area.add_child(juice)
	await wait_frames(3)

	# Emit mouse_entered on Area2D
	area.emit_signal("mouse_entered")
	await wait_seconds(0.3)

	assert_true(area.position.x > 50.0,
		"Auto-connect Area2D ON_MOUSE_ENTERED: mouse_entered should trigger animation (pos.x=%.1f)" % area.position.x)

	await cleanup(area)


func test_toggle_polarity_hover_2d() -> void:
	# ON_MOUSE_ENTERED + Toggle on Area2D: hover enter fires animate_in, hover exit fires animate_out.
	var area := Area2D.new()
	area.position = Vector2.ZERO
	_runner.add_child(area)

	var effect := Transform2DJuiceEffect.new()
	effect.transform_target = Transform2DJuiceEffect.TransformTarget.POSITION
	effect.from_reference = Transform2DJuiceEffect.TransformReference.SELF
	effect.to_reference = Transform2DJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(80, 0)
	effect.to_position_in = Transform2DJuiceEffect.PositionIn.PIXELS
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.15
	effect.duration_out = 0.15

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.ON_MOUSE_ENTERED
	juice.auto_connect_parent = true
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.TOGGLE
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	area.add_child(juice)
	await wait_frames(3)

	area.emit_signal("mouse_entered")
	await wait_seconds(0.3)

	assert_true(area.position.x > 50.0,
		"Toggle polarity hover 2D: mouse_entered should animate_in (pos.x=%.1f)" % area.position.x)

	area.emit_signal("mouse_exited")
	await wait_seconds(0.3)

	assert_true(area.position.x < 20.0,
		"Toggle polarity hover 2D: mouse_exited should animate_out back toward origin (pos.x=%.1f)" % area.position.x)

	await cleanup(area)


func test_external_move_detection_position() -> void:
	var target := Node2D.new()
	target.position = Vector2.ZERO
	_runner.add_child(target)

	var effect := Transform2DJuiceEffect.new()
	effect.transform_target = Transform2DJuiceEffect.TransformTarget.POSITION
	effect.from_reference = Transform2DJuiceEffect.TransformReference.SELF
	effect.to_reference = Transform2DJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(100, 0)
	effect.to_position_in = Transform2DJuiceEffect.PositionIn.PIXELS
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 1.0

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.2)

	# External move
	target.position += Vector2(0, 80)
	await wait_seconds(0.3)

	assert_greater(target.position.y, 50.0,
		"2D External move: y offset should be preserved (y=%.1f)" % target.position.y)

	await cleanup(target)
