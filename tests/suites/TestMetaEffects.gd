## TestMetaEffects.gd
## Tests for SignalEmitJuiceUtilityBase and CallMethodJuiceUtilityBase.
##
## API NOTE: These utilities were refactored from single-property (emit_on, payload,
## call_on, method_name) to array-of-entries (entries: Array[SignalEmitEntry / CallMethodEntry]).
## The old direct-assignment tests crashed with "Invalid assignment of property emit_on"
## because those properties no longer exist on the effect — they live on each Entry sub-resource.
extends JuiceTestSuite


func get_suite_name() -> String:
	return "meta_effects"


func get_test_methods() -> Array[String]:
	return [
		"test_signal_emit_on_start_fires_at_animate_start",
		"test_signal_emit_on_complete_fires_at_peak",
		"test_signal_emit_on_both_fires_twice",
		"test_signal_emit_payload_passed_correctly",
		"test_signal_emit_null_payload_passes",
		"test_call_method_on_start_calls_at_animate_start",
		"test_call_method_with_arguments",
		"test_call_method_graceful_on_empty_method_name",
	]


# =============================================================================
# HELPERS
# =============================================================================

# Creates a SignalEmitControlJuiceUtility with ONE SignalEmitEntry.
# timing: use SignalEmitJuiceUtilityBase.EmitTiming constants (0, 1, 2).
func _create_signal_emit_rig(
	timing: int,
	p_payload: Variant = null
) -> Array:
	var target := create_control_target("SigEmitBtn")

	# Build entry sub-resource — emit_on and payload live here now.
	var entry := SignalEmitEntry.new()
	entry.emit_on = timing
	entry.payload = p_payload

	var effect := SignalEmitControlJuiceUtility.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_in = 0.1
	effect.duration_out = 0.1
	effect.entries.append(entry)

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)
	return [target, juice]


# Creates a CallMethodControlJuiceUtility with ONE CallMethodEntry.
func _create_call_method_rig(
	timing: int,
	path: NodePath = NodePath(""),
	m_name: String = "",
	m_args: Array = []
) -> Array:
	var target := create_control_target("CallMethodBtn")

	# Build entry sub-resource — call_on, target_node_path, method_name, arguments live here.
	var entry := CallMethodEntry.new()
	entry.call_on = timing
	entry.target_node_path = path
	entry.method_name = m_name
	entry.arguments = m_args

	var effect := CallMethodControlJuiceUtility.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_in = 0.1
	effect.duration_out = 0.1
	effect.entries.append(entry)

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)
	return [target, juice]


# =============================================================================
# SIGNAL EMIT TESTS
# =============================================================================

func test_signal_emit_on_start_fires_at_animate_start() -> void:
	var rig := await _create_signal_emit_rig(SignalEmitJuiceUtilityBase.EmitTiming.ON_START)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]

	var runtime_effect: SignalEmitJuiceUtilityBase = juice._runtime_effects[0]
	var count := [0]
	runtime_effect.juice_signal.connect(func(_p): count[0] += 1)

	juice.animate_in()
	await wait_frames(2)

	assert_true(count[0] > 0,
		"juice_signal should fire immediately on animate_in (count=%d)" % count[0])

	await cleanup(target)


func test_signal_emit_on_complete_fires_at_peak() -> void:
	var rig := await _create_signal_emit_rig(SignalEmitJuiceUtilityBase.EmitTiming.ON_COMPLETE)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]

	var runtime_effect: SignalEmitJuiceUtilityBase = juice._runtime_effects[0]
	var count := [0]
	runtime_effect.juice_signal.connect(func(_p): count[0] += 1)

	# Check before animation completes — should NOT have fired yet
	juice.animate_in()
	await wait_frames(1)
	assert_equal(count[0], 0,
		"juice_signal should not fire before animation peak (count=%d)" % count[0])

	# Wait for full duration_in (0.1s ≈ 6 frames at 60fps)
	await wait_seconds(0.15)
	assert_true(count[0] > 0,
		"juice_signal should fire when animation reaches peak (count=%d)" % count[0])

	await cleanup(target)


func test_signal_emit_on_both_fires_twice() -> void:
	var rig := await _create_signal_emit_rig(SignalEmitJuiceUtilityBase.EmitTiming.ON_BOTH)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]

	var runtime_effect: SignalEmitJuiceUtilityBase = juice._runtime_effects[0]
	var count := [0]
	runtime_effect.juice_signal.connect(func(_p): count[0] += 1)

	juice.animate_in()
	await wait_seconds(0.3)

	assert_true(count[0] >= 2,
		"ON_BOTH should emit at least 2 times (count=%d)" % count[0])

	await cleanup(target)


func test_signal_emit_payload_passed_correctly() -> void:
	var rig := await _create_signal_emit_rig(
		SignalEmitJuiceUtilityBase.EmitTiming.ON_START, "test_payload_42")
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]

	var runtime_effect: SignalEmitJuiceUtilityBase = juice._runtime_effects[0]
	var received_payload := ["NONE"]
	runtime_effect.juice_signal.connect(
		func(p: Variant) -> void:
			received_payload[0] = p
	)

	juice.animate_in()
	await wait_frames(2)

	assert_equal(received_payload[0], "test_payload_42",
		"juice_signal should carry the configured payload")

	await cleanup(target)


func test_signal_emit_null_payload_passes() -> void:
	var rig := await _create_signal_emit_rig(
		SignalEmitJuiceUtilityBase.EmitTiming.ON_START, null)
	var target: Button = rig[0]
	var juice: JuiceControl = rig[1]

	var runtime_effect: SignalEmitJuiceUtilityBase = juice._runtime_effects[0]
	var received := [false]
	runtime_effect.juice_signal.connect(
		func(_p: Variant) -> void:
			received[0] = true
	)

	juice.animate_in()
	await wait_frames(2)

	assert_true(received[0], "juice_signal should fire even with null payload")

	await cleanup(target)


# =============================================================================
# CALL METHOD TESTS
# =============================================================================

func test_call_method_on_start_calls_at_animate_start() -> void:
	var target := create_control_target("CallMethodBtn")
	target.set_meta("call_count", 0)

	var rig := await _create_call_method_rig(
		CallMethodJuiceUtilityBase.CallTiming.ON_START,
		NodePath(""),  # empty = call on juiced target node itself
		"set_meta",
		["call_count", 1]
	)
	# _create_call_method_rig creates its own target — use the rig's juice
	# and verify the rig target was called (not our outer target).
	# Re-build rig targeting our outer target for proper assertion.
	await cleanup(rig[0])

	# Inline rig so we can verify on our outer 'target' directly.
	var entry := CallMethodEntry.new()
	entry.call_on = CallMethodJuiceUtilityBase.CallTiming.ON_START
	entry.target_node_path = NodePath("")
	entry.method_name = "set_meta"
	entry.arguments = ["call_count", 1]

	var effect := CallMethodControlJuiceUtility.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.1
	effect.entries.append(entry)

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)
	juice.animate_in()
	await wait_frames(2)

	assert_true(target.get_meta("call_count") > 0,
		"set_meta should have been called on target (meta=%d)" % target.get_meta("call_count"))

	await cleanup(target)


func test_call_method_with_arguments() -> void:
	var target := create_control_target("CallArgsBtn")

	var entry := CallMethodEntry.new()
	entry.call_on = CallMethodJuiceUtilityBase.CallTiming.ON_START
	entry.target_node_path = NodePath("")
	entry.method_name = "set_meta"
	entry.arguments = ["injected_value", 99]

	var effect := CallMethodControlJuiceUtility.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.1
	effect.entries.append(entry)

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)
	juice.animate_in()
	await wait_frames(2)

	assert_equal(target.get_meta("injected_value", -1), 99,
		"Method arguments should be forwarded correctly")

	await cleanup(target)


func test_call_method_graceful_on_empty_method_name() -> void:
	var target := create_control_target("CallEmptyBtn")

	var entry := CallMethodEntry.new()
	entry.call_on = CallMethodJuiceUtilityBase.CallTiming.ON_START
	entry.target_node_path = NodePath("")
	entry.method_name = ""  # Intentionally empty

	var effect := CallMethodControlJuiceUtility.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.1
	effect.entries.append(entry)

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)

	# Should not crash — just log a warning and continue
	juice.animate_in()
	await wait_frames(2)

	# If we get here, it didn't crash
	assert_true(true, "Empty method_name should not crash — effect completes normally")

	await cleanup(target)
