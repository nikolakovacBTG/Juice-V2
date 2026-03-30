## TestTimeEffect.gd
## ============================================================================
## WHAT: Tests for TimeJuiceEffectBase (Control domain via TimeControlJuiceEffect).
## TESTS: SLOW_MO reduces Engine.time_scale, FREEZE auto-releases via timer,
##        BULLET_TIME exempts nodes, Layer 1 multi-source coordination,
##        stop() restores time, smooth vs instant transition.
## IMPORTANT: Every test MUST restore Engine.time_scale to 1.0 — even on failure.
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "time_effect"


func get_test_methods() -> Array[String]:
	return [
		"test_slow_mo_reduces_time_scale",
		"test_slow_mo_instant_transition",
		"test_slow_mo_restores_on_animate_out",
		"test_freeze_sets_time_scale_zero",
		"test_freeze_auto_releases",
		"test_stop_restores_time_scale",
		"test_layer1_multi_source_slowest_wins",
		"test_bullet_time_exempts_nodes",
		"test_slow_mo_signals_emitted",
	]


# =============================================================================
# HELPERS
# =============================================================================

func _create_time_rig(
	mode: int = TimeJuiceEffectBase.TimeMode.SLOW_MO,
	target_sc: float = 0.3,
	smooth: bool = true
) -> Array:
	var target := create_control_target("TimeTestBtn")

	var effect := TimeControlJuiceEffect.new()
	effect.time_mode = mode
	effect.target_scale = target_sc
	effect.smooth_transition = smooth
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_in = 0.2
	effect.duration_out = 0.2

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)
	return [target, juice, effect]


func _ensure_time_restored() -> void:
	Engine.time_scale = 1.0
	TimeJuiceEffectBase._static_requests.clear()


# =============================================================================
# TESTS
# =============================================================================

func test_slow_mo_reduces_time_scale() -> void:
	var rig := await _create_time_rig(TimeJuiceEffectBase.TimeMode.SLOW_MO, 0.3, true)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	# Wait for most of animate_in — time_scale should be heading toward 0.3
	await wait_seconds(0.15)

	var current_scale := Engine.time_scale
	_ensure_time_restored()
	assert_true(current_scale < 0.9,
		"SLOW_MO should reduce Engine.time_scale below 0.9 during animation (was %.3f)" % current_scale)

	await cleanup(target)
	_ensure_time_restored()


func test_slow_mo_instant_transition() -> void:
	var rig := await _create_time_rig(TimeJuiceEffectBase.TimeMode.SLOW_MO, 0.25, false)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	await wait_frames(2)

	# With smooth=false, time_scale should jump immediately to target
	var current_scale := Engine.time_scale
	_ensure_time_restored()
	assert_approx_float(current_scale, 0.25,
		"SLOW_MO instant should jump to target_scale immediately", 0.05)

	await cleanup(target)
	_ensure_time_restored()


func test_slow_mo_restores_on_animate_out() -> void:
	var rig := await _create_time_rig(TimeJuiceEffectBase.TimeMode.SLOW_MO, 0.3, false)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]
	var effect: TimeControlJuiceEffect = rig[2]

	juice.animate_in()
	await wait_frames(3)

	# Verify time is slowed
	_ensure_time_restored()  # Reset so animate_out starts from clean state
	# Now manually call animate_out
	juice.animate_out()
	# Wait for animate_out to complete
	await wait_seconds(0.3)

	assert_approx_float(Engine.time_scale, 1.0,
		"Engine.time_scale should be restored to 1.0 after animate_out", 0.05)
	assert_false(effect._has_active_request,
		"Effect should have no active request after animate_out")

	await cleanup(target)
	_ensure_time_restored()


func test_freeze_sets_time_scale_zero() -> void:
	var rig := await _create_time_rig(TimeJuiceEffectBase.TimeMode.FREEZE)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]

	# Set 5 frames (80ms at 60fps) so we have time to check
	var effect: TimeControlJuiceEffect = rig[2]
	effect.freeze_frames = 5

	juice.animate_in()
	await wait_frames(1)

	var scale_during_freeze := Engine.time_scale
	_ensure_time_restored()
	assert_approx_float(scale_during_freeze, 0.0,
		"FREEZE should set Engine.time_scale to 0.0", 0.001)

	await cleanup(target)
	_ensure_time_restored()


func test_freeze_auto_releases() -> void:
	var rig := await _create_time_rig(TimeJuiceEffectBase.TimeMode.FREEZE)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]
	var effect: TimeControlJuiceEffect = rig[2]

	effect.freeze_frames = 3  # 3/60 ≈ 50ms

	juice.animate_in()
	# Wait longer than the freeze duration (real-time, not engine-time)
	await wait_seconds(0.2)

	assert_approx_float(Engine.time_scale, 1.0,
		"FREEZE should auto-release Engine.time_scale after freeze_frames", 0.05)
	assert_false(effect._has_active_request,
		"Effect should have no active request after freeze timer expires")

	await cleanup(target)
	_ensure_time_restored()


func test_stop_restores_time_scale() -> void:
	var rig := await _create_time_rig(TimeJuiceEffectBase.TimeMode.SLOW_MO, 0.2, false)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	await wait_frames(3)

	# Time should be slowed
	juice.stop()
	await wait_frames(2)

	assert_approx_float(Engine.time_scale, 1.0,
		"stop() should restore Engine.time_scale to 1.0", 0.05)

	await cleanup(target)
	_ensure_time_restored()


func test_layer1_multi_source_slowest_wins() -> void:
	# Create two SLOW_MO effects simultaneously — slowest wins
	var rig_a := await _create_time_rig(TimeJuiceEffectBase.TimeMode.SLOW_MO, 0.5, false)
	var rig_b := await _create_time_rig(TimeJuiceEffectBase.TimeMode.SLOW_MO, 0.2, false)
	var target_a: Button = rig_a[0]
	var juice_a: JuiceControl = rig_a[1]
	var target_b: Button = rig_b[0]
	var juice_b: JuiceControl = rig_b[1]

	juice_a.animate_in()
	juice_b.animate_in()
	await wait_frames(2)

	# Both running — slowest (0.2) should win
	var effective_scale := Engine.time_scale
	_ensure_time_restored()
	assert_approx_float(effective_scale, 0.2,
		"Layer 1 multi-source: slowest slow-mo (0.2) should win over 0.5", 0.05)

	await cleanup(target_a)
	await cleanup(target_b)
	_ensure_time_restored()


func test_bullet_time_exempts_nodes() -> void:
	var target := create_control_target("BulletTimeBtn")
	var exempt_node := create_control_target("ExemptBtn")

	var effect := TimeControlJuiceEffect.new()
	effect.time_mode = TimeJuiceEffectBase.TimeMode.BULLET_TIME
	effect.target_scale = 0.3
	effect.smooth_transition = false
	effect.emit_compensation_signal = false
	effect.exempt_nodes = [exempt_node.get_path()]
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_in = 0.3
	effect.duration_out = 0.3

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)

	var original_mode := exempt_node.process_mode

	juice.animate_in()
	await wait_frames(3)

	var mode_during_bt := exempt_node.process_mode
	_ensure_time_restored()

	assert_equal(mode_during_bt, Node.PROCESS_MODE_ALWAYS,
		"Exempt node should be PROCESS_MODE_ALWAYS during BULLET_TIME")

	juice.stop()
	await wait_frames(2)
	assert_equal(exempt_node.process_mode, original_mode,
		"Exempt node process_mode should be restored after BULLET_TIME ends")

	await cleanup(exempt_node)
	await cleanup(target)
	_ensure_time_restored()


func test_slow_mo_signals_emitted() -> void:
	var target := create_control_target("SigTestBtn")

	var effect := TimeControlJuiceEffect.new()
	effect.time_mode = TimeJuiceEffectBase.TimeMode.SLOW_MO
	effect.target_scale = 0.3
	effect.smooth_transition = false
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_in = 0.2
	effect.duration_out = 0.2

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)

	# JuiceBase clones recipe effects into _runtime_effects.
	# Connect to the runtime clone — that's the object actually ticked.
	var sig_count := [0]
	var sig_scale := [-1.0]
	var runtime_effect: TimeJuiceEffectBase = juice._runtime_effects[0]
	runtime_effect.slow_mo_started.connect(
		func(sc: float) -> void:
			sig_count[0] += 1
			sig_scale[0] = sc
	)

	juice.animate_in()
	await wait_frames(3)

	_ensure_time_restored()
	assert_true(sig_count[0] > 0, "slow_mo_started signal should be emitted (count=%d)" % sig_count[0])
	assert_approx_float(sig_scale[0], 0.3,
		"slow_mo_started should carry the target_scale payload", 0.001)

	await cleanup(target)
	_ensure_time_restored()
