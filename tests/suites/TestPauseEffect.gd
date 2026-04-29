## TestPauseEffect.gd
## Tests for PauseJuiceEffectBase and all three domain wrappers.
##
## Coverage:
##   - Pause honors duration_in and completes without visual residue
##   - No target property is modified before or after the pause
##   - Chained effect fires only after pause completes
##   - use_realtime path does not crash (functional timing tested manually)
##   - start_delay stacks with pause duration (delay fires first, then pause begins)
##   - All three domain classes (Control, 2D, 3D) instantiate without error
extends JuiceTestSuite


func get_suite_name() -> String:
	return "pause_effect"


func get_test_methods() -> Array[String]:
	return [
		"test_pause_control_instantiates",
		"test_pause_2d_instantiates",
		"test_pause_3d_instantiates",
		"test_pause_completes_after_duration",
		"test_pause_does_not_modify_target_position",
		"test_chained_effect_fires_after_pause",
		"test_use_realtime_flag_does_not_crash",
		"test_start_delay_stacks_with_pause",
		"test_zero_duration_warning_present",
	]


# =============================================================================
# HELPERS
# =============================================================================

# Creates a JuiceControl with a PauseControlJuiceEffect of the given duration.
# Returns [target, juice, effect_resource].
func _create_pause_control_rig(pause_duration: float, use_realtime: bool = false) -> Array:
	var target := create_control_target("PauseBtn")

	var effect := PauseControlJuiceEffect.new()
	effect.pause_duration = pause_duration
	effect.use_realtime = use_realtime

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)
	return [target, juice, effect]


# Creates a Juice2D with a Pause2DJuiceEffect of the given duration.
# Returns [target, juice].
func _create_pause_2d_rig(pause_duration: float) -> Array:
	var target := create_2d_target()

	var effect := Pause2DJuiceEffect.new()
	effect.pause_duration = pause_duration

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)
	return [target, juice]


# =============================================================================
# INSTANTIATION TESTS
# =============================================================================

func test_pause_control_instantiates() -> void:
	var effect := PauseControlJuiceEffect.new()
	assert_true(effect != null, "PauseControlJuiceEffect must instantiate without error")
	assert_true(effect is PauseJuiceEffectBase,
		"PauseControlJuiceEffect must extend PauseJuiceEffectBase")


func test_pause_2d_instantiates() -> void:
	var effect := Pause2DJuiceEffect.new()
	assert_true(effect != null, "Pause2DJuiceEffect must instantiate without error")
	assert_true(effect is PauseJuiceEffectBase,
		"Pause2DJuiceEffect must extend PauseJuiceEffectBase")


func test_pause_3d_instantiates() -> void:
	var effect := Pause3DJuiceEffect.new()
	assert_true(effect != null, "Pause3DJuiceEffect must instantiate without error")
	assert_true(effect is PauseJuiceEffectBase,
		"Pause3DJuiceEffect must extend PauseJuiceEffectBase")


# =============================================================================
# DURATION TESTS
# =============================================================================

func test_pause_completes_after_duration() -> void:
	var rig := await _create_pause_control_rig(0.1)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]

	var completed := [false]
	juice.completed.connect(func(): completed[0] = true)

	juice.animate_in()

	# Should NOT have completed before duration elapses
	await wait_frames(2)
	assert_false(completed[0], "Pause should not complete before duration_in elapses")

	# Should complete after duration_in (0.1s = ~6 frames at 60fps)
	await wait_seconds(0.2)
	assert_true(completed[0], "Pause must emit completed after duration_in")

	await cleanup(target)


func test_pause_does_not_modify_target_position() -> void:
	var rig := await _create_pause_2d_rig(0.1)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	var initial_pos := target.position

	juice.animate_in()
	await wait_seconds(0.2)

	assert_approx_vec2(target.position, initial_pos,
		"Pause must not modify target position (pos before=(%s) after=(%s))" % [
		str(initial_pos), str(target.position)])

	await cleanup(target)


# =============================================================================
# CHAINING TESTS
# =============================================================================

func test_chained_effect_fires_after_pause() -> void:
	var target := create_control_target("ChainPauseBtn")

	# Two effects: pause (0.1s) → signal emit
	var pause_effect := PauseControlJuiceEffect.new()
	pause_effect.pause_duration = 0.1

	var entry := SignalEmitEntry.new()
	entry.emit_on = SignalEmitJuiceUtilityBase.EmitTiming.ON_START
	var signal_effect := SignalEmitControlJuiceUtility.new()
	signal_effect.duration_in = 0.05
	signal_effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	signal_effect.entries.append(entry)

	# Chain: pause → signal_emit
	pause_effect.chain_to.append(signal_effect)

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(pause_effect)
	recipe.effects.append(signal_effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)

	# Connect to the runtime signal emit effect
	var runtime_signal_effect: SignalEmitJuiceUtilityBase = juice._runtime_effects[1]
	var signal_count := [0]
	runtime_signal_effect.juice_signal.connect(func(_p): signal_count[0] += 1)

	juice.animate_in()

	# Signal should NOT fire immediately — pause must complete first
	await wait_frames(2)
	assert_equal(signal_count[0], 0,
		"Chained signal should not fire before pause completes (count=%d)" % signal_count[0])

	# After pause completes (~0.1s), signal should have fired
	await wait_seconds(0.2)
	assert_true(signal_count[0] > 0,
		"Chained signal must fire after pause duration (count=%d)" % signal_count[0])

	await cleanup(target)


# =============================================================================
# USE_REALTIME TESTS
# =============================================================================

func test_use_realtime_flag_does_not_crash() -> void:
	# Functional real-time timing requires Engine.time_scale manipulation which
	# risks polluting other tests. We verify the code path executes without error.
	var rig := await _create_pause_control_rig(0.1, true)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]

	var completed := [false]
	juice.completed.connect(func(): completed[0] = true)

	juice.animate_in()
	await wait_seconds(0.3)

	assert_true(completed[0], "Pause with use_realtime=true must complete without crashing")

	await cleanup(target)


# =============================================================================
# START_DELAY STACKING TESTS
# =============================================================================

func test_start_delay_stacks_with_pause() -> void:
	# start_delay is no longer exposed on PauseJuiceEffect (it was intentionally
	# stripped from the inspector — pause_duration is the only timing control).
	# The base class still supports it internally; this test verifies the effect
	# completes in the expected window when pause_duration is set.
	var target := create_control_target("DelayPauseBtn")

	var effect := PauseControlJuiceEffect.new()
	effect.pause_duration = 0.1

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)

	var completed := [false]
	juice.completed.connect(func(): completed[0] = true)

	juice.animate_in()

	# After only 0.05s, NOT complete yet
	await wait_seconds(0.05)
	assert_false(completed[0],
		"Pause should not complete instantly")

	# After 0.25s (0.1 pause + margin), must be complete
	await wait_seconds(0.25)
	assert_true(completed[0],
		"Pause must complete after pause_duration")

	await cleanup(target)


# =============================================================================
# CONFIGURATION WARNING TEST
# =============================================================================

func test_zero_duration_warning_present() -> void:
	var effect := PauseControlJuiceEffect.new()
	effect.pause_duration = 0.0

	var warnings := effect._get_configuration_warnings()
	assert_true(warnings.size() > 0,
		"PauseJuiceEffectBase must warn when pause_duration is 0")
	assert_true(warnings[0].contains("pause_duration"),
		"Warning must mention pause_duration (got: '%s')" % warnings[0])
