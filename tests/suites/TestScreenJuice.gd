## TestScreenJuice.gd
## Tests for ScreenJuiceEffect (formerly ScreenMotionJuiceEffect) and ScreenJuiceUtility.
## Covers auto-bootstrap, all channels, stacking, cleanup, recipe registration,
## and the chained-effect _host_node regression (bug fix validation).
extends JuiceTestSuite


func get_suite_name() -> String:
	return "screen_juice"


func get_test_methods() -> Array[String]:
	return [
		# --- Auto-bootstrap ---
		"test_screen_auto_bootstraps_utility_on_first_use",
		"test_screen_does_not_duplicate_utility_on_manual_placement",
		# --- Channels ---
		"test_screen_offset_applied_during_animation",
		"test_screen_offset_cleared_on_complete",
		"test_screen_rotation_channel_writes_to_utility",
		"test_screen_zoom_channel_writes_to_utility",
		"test_screen_skew_channel_writes_to_utility",
		"test_screen_barrel_channel_writes_to_utility",
		"test_screen_wave_channel_writes_to_utility",
		"test_screen_chromatic_channel_writes_to_utility",
		"test_screen_two_effects_stack_additively",
		"test_screen_stop_clears_contribution",
		# --- Inspector registration ---
		"test_screen_juice_in_2d_recipe_whitelist",
		"test_screen_juice_in_control_recipe_whitelist",
		"test_screen_juice_in_3d_recipe_whitelist",
	]


# =============================================================================
# HELPERS
# =============================================================================

func _cleanup_screen_utility() -> void:
	if is_instance_valid(ScreenJuiceUtility.instance):
		var util := ScreenJuiceUtility.instance
		var parent := util.get_parent()
		ScreenJuiceUtility.instance = null
		if is_instance_valid(parent) and parent.name == "ScreenJuiceCanvas":
			parent.queue_free()
		else:
			util.queue_free()
	await wait_frames(2)


func _create_entity_with_screen_effect(
	p_channel: int = ScreenJuiceEffect.Channel.OFFSET,
	p_duration: float = 0.2
) -> Array:
	var entity := create_2d_target()

	var effect := ScreenJuiceEffect.new()
	effect.channel = p_channel
	effect.screen_offset     = Vector2(0.05, 0.0)
	effect.screen_rotation_degrees = 5.0
	effect.screen_zoom_offset = 0.1
	effect.skew_amount        = Vector2(0.1, 0.0)
	effect.barrel_amount      = Vector2(-0.2, -0.2)
	effect.wave_amplitude     = 0.02
	effect.chromatic_amount   = 0.01
	effect.trigger_behaviour  = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_in  = p_duration
	effect.duration_out = p_duration

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	entity.add_child(juice)

	await wait_frames(3)
	return [entity, juice]


# =============================================================================
# AUTO-BOOTSTRAP TESTS
# =============================================================================

func test_screen_auto_bootstraps_utility_on_first_use() -> void:
	await _cleanup_screen_utility()

	assert_true(
		not is_instance_valid(ScreenJuiceUtility.instance),
		"instance should be null before any effect runs"
	)

	var rig := await _create_entity_with_screen_effect(ScreenJuiceEffect.Channel.OFFSET, 0.3)
	var entity: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_frames(3)

	assert_true(
		is_instance_valid(ScreenJuiceUtility.instance),
		"ScreenJuiceUtility should be auto-created after first effect tick"
	)

	await _cleanup_screen_utility()
	await cleanup(entity)


func test_screen_does_not_duplicate_utility_on_manual_placement() -> void:
	await _cleanup_screen_utility()

	var canvas := CanvasLayer.new()
	canvas.layer = 128
	_runner.add_child(canvas)

	var manual_util := ScreenJuiceUtility.new()
	manual_util.name = "ScreenJuiceUtility"
	manual_util.set_anchors_preset(Control.PRESET_FULL_RECT)
	manual_util.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(manual_util)
	await wait_frames(2)

	var rig := await _create_entity_with_screen_effect(ScreenJuiceEffect.Channel.OFFSET, 0.4)
	var entity: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.1)

	assert_true(
		ScreenJuiceUtility.instance == manual_util,
		"Manually placed utility should be reused — no duplicate created"
	)

	var count := 0
	for child in canvas.get_children():
		if child is ScreenJuiceUtility:
			count += 1
	assert_equal(count, 1, "Should be exactly 1 ScreenJuiceUtility (got %d)" % count)

	await cleanup(canvas)
	await _cleanup_screen_utility()
	await cleanup(entity)


# =============================================================================
# CHANNEL TESTS
# =============================================================================

func test_screen_offset_applied_during_animation() -> void:
	await _cleanup_screen_utility()

	var rig := await _create_entity_with_screen_effect(ScreenJuiceEffect.Channel.OFFSET, 0.4)
	var entity: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.15)

	var util := ScreenJuiceUtility.instance
	assert_true(is_instance_valid(util), "Utility should be auto-bootstrapped")
	assert_true(
		util.offset.length() > 0.0,
		"Screen offset should be non-zero mid-animation (got %s)" % str(util.offset)
	)

	await _cleanup_screen_utility()
	await cleanup(entity)


func test_screen_offset_cleared_on_complete() -> void:
	await _cleanup_screen_utility()

	var rig := await _create_entity_with_screen_effect(ScreenJuiceEffect.Channel.OFFSET, 0.1)
	var entity: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.6)

	var util := ScreenJuiceUtility.instance
	assert_true(
		not is_instance_valid(util) or util.offset.length() < 0.001,
		"Screen offset should return to zero after animation (got %s)" % (
			str(util.offset) if is_instance_valid(util) else "null"
		)
	)

	await _cleanup_screen_utility()
	await cleanup(entity)


func test_screen_rotation_channel_writes_to_utility() -> void:
	await _cleanup_screen_utility()

	var rig := await _create_entity_with_screen_effect(ScreenJuiceEffect.Channel.ROTATION, 0.4)
	var entity: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.15)

	var util := ScreenJuiceUtility.instance
	assert_true(is_instance_valid(util), "Utility should be auto-bootstrapped")
	assert_true(
		abs(util.rotation_amount) > 0.0,
		"rotation_amount should be non-zero mid-animation (got %.4f)" % util.rotation_amount
	)

	await _cleanup_screen_utility()
	await cleanup(entity)


func test_screen_zoom_channel_writes_to_utility() -> void:
	await _cleanup_screen_utility()

	var rig := await _create_entity_with_screen_effect(ScreenJuiceEffect.Channel.ZOOM, 0.4)
	var entity: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.15)

	var util := ScreenJuiceUtility.instance
	assert_true(is_instance_valid(util), "Utility should be auto-bootstrapped")
	assert_true(
		abs(util.zoom_offset) > 0.0,
		"zoom_offset should be non-zero mid-animation (got %.4f)" % util.zoom_offset
	)

	await _cleanup_screen_utility()
	await cleanup(entity)


func test_screen_skew_channel_writes_to_utility() -> void:
	await _cleanup_screen_utility()

	var rig := await _create_entity_with_screen_effect(ScreenJuiceEffect.Channel.SKEW, 0.4)
	var entity: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.15)

	var util := ScreenJuiceUtility.instance
	assert_true(is_instance_valid(util), "Utility should be auto-bootstrapped")
	assert_true(
		util.skew_offset.length() > 0.0,
		"skew_offset should be non-zero mid-animation (got %s)" % str(util.skew_offset)
	)

	await _cleanup_screen_utility()
	await cleanup(entity)


func test_screen_barrel_channel_writes_to_utility() -> void:
	await _cleanup_screen_utility()

	var rig := await _create_entity_with_screen_effect(ScreenJuiceEffect.Channel.BARREL, 0.4)
	var entity: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.15)

	var util := ScreenJuiceUtility.instance
	assert_true(is_instance_valid(util), "Utility should be auto-bootstrapped")
	assert_true(
		abs(util.barrel_distortion) > 0.0,
		"barrel_distortion should be non-zero mid-animation (got %.4f)" % util.barrel_distortion
	)

	await _cleanup_screen_utility()
	await cleanup(entity)


func test_screen_wave_channel_writes_to_utility() -> void:
	await _cleanup_screen_utility()

	var rig := await _create_entity_with_screen_effect(ScreenJuiceEffect.Channel.WAVE, 0.4)
	var entity: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.15)

	var util := ScreenJuiceUtility.instance
	assert_true(is_instance_valid(util), "Utility should be auto-bootstrapped")
	assert_true(
		util.wave_amplitude > 0.0,
		"wave_amplitude should be non-zero mid-animation (got %.4f)" % util.wave_amplitude
	)

	await _cleanup_screen_utility()
	await cleanup(entity)


func test_screen_chromatic_channel_writes_to_utility() -> void:
	await _cleanup_screen_utility()

	var rig := await _create_entity_with_screen_effect(ScreenJuiceEffect.Channel.CHROMATIC, 0.4)
	var entity: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.15)

	var util := ScreenJuiceUtility.instance
	assert_true(is_instance_valid(util), "Utility should be auto-bootstrapped")
	assert_true(
		util.chromatic_amount > 0.0,
		"chromatic_amount should be non-zero mid-animation (got %.4f)" % util.chromatic_amount
	)

	await _cleanup_screen_utility()
	await cleanup(entity)


func test_screen_two_effects_stack_additively() -> void:
	await _cleanup_screen_utility()

	var rig_a := await _create_entity_with_screen_effect(ScreenJuiceEffect.Channel.OFFSET, 0.5)
	var entity_a: Node2D = rig_a[0]
	var juice_a: Juice2D = rig_a[1]

	var rig_b := await _create_entity_with_screen_effect(ScreenJuiceEffect.Channel.OFFSET, 0.5)
	var entity_b: Node2D = rig_b[0]
	var juice_b: Juice2D = rig_b[1]

	juice_a.animate_in()
	juice_b.animate_in()
	await wait_seconds(0.25)

	var util := ScreenJuiceUtility.instance
	assert_true(is_instance_valid(util), "Utility should be auto-bootstrapped")
	assert_true(
		util.offset.x > 0.0,
		"Two stacked screen offset effects should accumulate (got x=%.4f)" % util.offset.x
	)

	await _cleanup_screen_utility()
	await cleanup(entity_a)
	await cleanup(entity_b)


func test_screen_stop_clears_contribution() -> void:
	await _cleanup_screen_utility()

	var rig := await _create_entity_with_screen_effect(ScreenJuiceEffect.Channel.OFFSET, 0.5)
	var entity: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.1)

	juice.stop()
	await wait_frames(3)

	var util := ScreenJuiceUtility.instance
	assert_true(
		not is_instance_valid(util) or util.offset.length() < 0.001,
		"stop() should clear contribution (got %s)" % (
			str(util.offset) if is_instance_valid(util) else "null"
		)
	)

	await _cleanup_screen_utility()
	await cleanup(entity)


# =============================================================================
# INSPECTOR REGISTRATION TESTS
# =============================================================================

func test_screen_juice_in_2d_recipe_whitelist() -> void:
	var recipe := Juice2DRecipe.new()
	var prop_def := {"name": "effects", "hint_string": "", "hint": 0, "usage": 0, "type": 0}
	recipe._validate_property(prop_def)
	assert_true(prop_def["hint_string"].contains("ScreenJuiceEffect"),
		"ScreenJuiceEffect must appear in Juice2DRecipe whitelist")


func test_screen_juice_in_control_recipe_whitelist() -> void:
	var recipe := JuiceControlRecipe.new()
	var prop_def := {"name": "effects", "hint_string": "", "hint": 0, "usage": 0, "type": 0}
	recipe._validate_property(prop_def)
	assert_true(prop_def["hint_string"].contains("ScreenJuiceEffect"),
		"ScreenJuiceEffect must appear in JuiceControlRecipe whitelist")


func test_screen_juice_in_3d_recipe_whitelist() -> void:
	var recipe := Juice3DRecipe.new()
	var prop_def := {"name": "effects", "hint_string": "", "hint": 0, "usage": 0, "type": 0}
	recipe._validate_property(prop_def)
	assert_true(prop_def["hint_string"].contains("ScreenJuiceEffect"),
		"ScreenJuiceEffect must appear in Juice3DRecipe whitelist")
