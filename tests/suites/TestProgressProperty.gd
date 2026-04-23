## TestProgressProperty.gd
## ============================================================================
## WHAT: Tests for PropertyProgressJuiceEffectBase and its domain wrappers.
## WHY: Verify arbitrary property accumulation via set_indexed() works for
##      float, Vector2, Vector3, and Color types. Tests use the Control-domain
##      wrapper as it is most testable headlessly.
## SYSTEM: Tests (tests/suites/)
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "progress_property"


func get_test_methods() -> Array[String]:
	return [
		"test_float_accumulates",
		"test_color_alpha_accumulates",
		"test_hold_on_stop_true",
		"test_hold_on_stop_false",
		"test_bound_stop",
		"test_needs_sustain",
		"test_warning_on_empty_path",
	]


# =============================================================================
# HELPERS
# =============================================================================

## Creates a JuiceControl rig targeting an arbitrary property on the Control node.
func _create_property_rig(
	label: String,
	path: String,
	prop_type: int,
	f_rate: float = 0.5,
	duration: float = 0.1
) -> Array:
	var target := Control.new()
	target.name = label
	target.custom_minimum_size = Vector2(80.0, 40.0)
	_runner.add_child(target)

	var effect := PropertyProgressControlJuiceEffect.new()
	effect.property_path = path
	effect.property_type = prop_type
	effect.float_rate = f_rate
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = duration

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
# TESTS: Float accumulation
# =============================================================================

func test_float_accumulates() -> void:
	# modulate.a starts at 1.0, rate -0.5/s -> should decrease over time.
	var target := Control.new()
	target.name = "pprop_float"
	target.custom_minimum_size = Vector2(80.0, 40.0)
	_runner.add_child(target)

	var effect := PropertyProgressControlJuiceEffect.new()
	effect.property_path = "modulate:a"
	effect.property_type = PropertyProgressJuiceEffectBase.PropertyType.FLOAT
	effect.float_rate = -0.5  # decrease alpha
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.1

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.5)

	# After 0.4s sustain at -0.5/s: alpha should have dropped at least 0.1
	assert_true(target.modulate.a < 0.9,
		"ProgressProperty FLOAT: modulate.a should decrease (a=%.2f)" % target.modulate.a)

	await cleanup(target)


# =============================================================================
# TESTS: Color alpha accumulation
# =============================================================================

func test_color_alpha_accumulates() -> void:
	var target := Control.new()
	target.name = "pprop_color"
	target.custom_minimum_size = Vector2(80.0, 40.0)
	_runner.add_child(target)

	var effect := PropertyProgressControlJuiceEffect.new()
	effect.property_path = "modulate"
	effect.property_type = PropertyProgressJuiceEffectBase.PropertyType.COLOR
	effect.color_rate = Color(0.0, 0.0, 0.0, -0.5)  # decrease alpha only
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.1

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.5)

	assert_true(target.modulate.a < 0.9,
		"ProgressProperty COLOR: modulate.a should decrease (a=%.2f)" % target.modulate.a)

	await cleanup(target)


# =============================================================================
# TESTS: hold_on_stop
# =============================================================================

func test_hold_on_stop_true() -> void:
	var target := Control.new()
	target.name = "pprop_hold_true"
	target.custom_minimum_size = Vector2(80.0, 40.0)
	_runner.add_child(target)

	var effect := PropertyProgressControlJuiceEffect.new()
	effect.property_path = "modulate:a"
	effect.property_type = PropertyProgressJuiceEffectBase.PropertyType.FLOAT
	effect.float_rate = -0.5
	effect.hold_on_stop = true
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_in = 0.1
	effect.duration_out = 0.1

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.4)

	var alpha_mid: float = target.modulate.a
	juice.animate_out()
	await wait_seconds(0.3)

	# hold_on_stop=true: alpha should remain below 1.0 after stopping
	assert_true(target.modulate.a < 0.99,
		"ProgressProperty hold_on_stop=true: alpha should remain changed (a=%.2f)" % target.modulate.a)

	await cleanup(target)


func test_hold_on_stop_false() -> void:
	var target := Control.new()
	target.name = "pprop_hold_false"
	target.custom_minimum_size = Vector2(80.0, 40.0)
	_runner.add_child(target)

	var effect := PropertyProgressControlJuiceEffect.new()
	effect.property_path = "modulate:a"
	effect.property_type = PropertyProgressJuiceEffectBase.PropertyType.FLOAT
	effect.float_rate = -0.5
	effect.hold_on_stop = false
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_in = 0.1
	effect.duration_out = 0.1

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.4)

	juice.animate_out()
	await wait_seconds(0.3)

	# hold_on_stop=false: alpha should snap back to 1.0
	assert_approx_float(target.modulate.a, 1.0,
		"ProgressProperty hold_on_stop=false: alpha should return to 1.0 (a=%.2f)" % target.modulate.a,
		0.1)

	await cleanup(target)


# =============================================================================
# TESTS: Bound STOP
# =============================================================================

func test_bound_stop() -> void:
	var target := Control.new()
	target.name = "pprop_bound"
	target.custom_minimum_size = Vector2(80.0, 40.0)
	_runner.add_child(target)

	var effect := PropertyProgressControlJuiceEffect.new()
	effect.property_path = "modulate:a"
	effect.property_type = PropertyProgressJuiceEffectBase.PropertyType.FLOAT
	effect.float_rate = -2.0  # Fast decrease
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.05
	effect.bound_enabled = true
	effect.bound_behaviour = PropertyProgressJuiceEffectBase.BoundBehaviour.STOP
	effect.bound_value = 0.5  # Stop when 0.5 has been accumulated (alpha = 0.5)

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.5)

	# Should stop near 0.5 alpha (base 1.0 - accumulated 0.5)
	assert_approx_float(target.modulate.a, 0.5,
		"ProgressProperty BOUND STOP: should stop at bound (a=%.2f)" % target.modulate.a,
		0.15)

	await cleanup(target)


# =============================================================================
# TESTS: Sustain + warnings
# =============================================================================

func test_needs_sustain() -> void:
	var effect := PropertyProgressControlJuiceEffect.new()
	assert_true(effect._needs_sustain(),
		"PropertyProgressControlJuiceEffect must return true from _needs_sustain()")


func test_warning_on_empty_path() -> void:
	var effect := PropertyProgressControlJuiceEffect.new()
	effect.property_path = ""
	var warnings := effect._get_configuration_warnings()
	assert_true(warnings.size() > 0,
		"ProgressProperty should warn when property_path is empty")
