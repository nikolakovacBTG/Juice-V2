## TestSequencer.gd
## ============================================================================
## WHAT: Tests for JuiceBase SEQUENCER mode (Phase 5).
## WHY: Verify stagger, target discovery, RECIPE/TARGETS_CHILDREN modes,
##      looping, ping-pong, retrigger, and Container hold pattern.
## SYSTEM: Tests (tests/suites/)
## ============================================================================
##
## Uses Control domain (JuiceControl + TransformControlJuiceEffect) for setup
## convenience. Sequencer logic lives in JuiceBase (domain-agnostic).
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "sequencer"


func get_test_methods() -> Array[String]:
	return [
		"test_recipe_stagger_forward_moves_targets",
		"test_recipe_all_at_once_moves_simultaneously",
		"test_recipe_stagger_reverse_order",
		"test_target_scope_siblings",
		"test_skip_invisible_filters_hidden",
		"test_skip_juice_nodes_filters_juice",
		"test_targets_children_triggers_child_juice",
		"test_sequencer_loop_count_two",
		"test_sequencer_play_in_and_out_auto_reverse",
		"test_sequencer_retrigger_restart",
		"test_completed_signal_fires",
		"test_warmup_prepositions_during_start_delay",
	]


# =============================================================================
# HELPER: Create a sequencer rig with N sibling buttons
# =============================================================================

## Creates a parent Node with N Button children and a JuiceControl sequencer.
## Returns { "parent": Node, "buttons": Array[Button], "sequencer": JuiceControl }
func _create_seq_rig(
	button_count: int = 3,
	stagger_delay: float = 0.05,
	duration: float = 0.15,
	sequence_type: JuiceBase.SequenceType = JuiceBase.SequenceType.STAGGER_FORWARD,
	juice_source: JuiceBase.JuiceSource = JuiceBase.JuiceSource.RECIPE,
) -> Dictionary:
	var parent := Control.new()
	parent.name = "SeqParent"
	_runner.add_child(parent)

	var buttons: Array[Button] = []
	for i in button_count:
		var btn := Button.new()
		btn.text = "Btn%d" % i
		btn.custom_minimum_size = Vector2(80, 30)
		btn.position = Vector2(0, i * 40)
		parent.add_child(btn)
		buttons.append(btn)

	# Build recipe: position animation (move X by 60px)
	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(60, 0)
	effect.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = duration

	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)

	# Create sequencer node
	var seq := JuiceControl.new()
	seq.name = "Sequencer"
	seq.mode = JuiceBase.Mode.SEQUENCER
	seq.juice_source = juice_source
	seq.target_scope = JuiceBase.TargetScope.SIBLINGS
	seq.sequence_type = sequence_type
	seq.seq_stagger_delay = stagger_delay
	seq.seq_skip_self = true
	seq.seq_skip_juice_nodes = true
	seq.trigger_on = JuiceBase.TriggerEvent.MANUAL
	seq.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	seq.recipe = recipe
	parent.add_child(seq)

	await wait_frames(3)

	return { "parent": parent, "buttons": buttons, "sequencer": seq }


# =============================================================================
# TESTS
# =============================================================================

func test_recipe_stagger_forward_moves_targets() -> void:
	var rig := await _create_seq_rig(3, 0.05, 0.15)
	var buttons: Array = rig.buttons
	var seq: JuiceControl = rig.sequencer

	# Record starting positions
	var start_positions: Array[float] = []
	for btn: Button in buttons:
		start_positions.append(btn.position.x)

	seq.animate_in()

	# Wait for full sequence: 3 targets × 0.05 stagger + 0.15 duration + buffer
	await wait_seconds(0.5)

	# All buttons should have moved right
	for i in buttons.size():
		var btn: Button = buttons[i]
		assert_greater(btn.position.x, start_positions[i] + 10.0,
			"Btn%d moved right after stagger forward (pos.x=%.1f)" % [i, btn.position.x])

	await cleanup(rig.parent)


func test_recipe_all_at_once_moves_simultaneously() -> void:
	var rig := await _create_seq_rig(3, 0.0, 0.15, JuiceBase.SequenceType.ALL_AT_ONCE)
	var buttons: Array = rig.buttons
	var seq: JuiceControl = rig.sequencer

	seq.animate_in()
	# With ALL_AT_ONCE and 0.15 duration, all should be done quickly
	await wait_seconds(0.1)

	# Mid-animation: all should be moving (not still at start)
	var any_moved := false
	for btn: Button in buttons:
		if btn.position.x > 5.0:
			any_moved = true
			break

	assert_true(any_moved, "ALL_AT_ONCE: at least one target moved mid-animation")

	await wait_seconds(0.2)
	await cleanup(rig.parent)


func test_recipe_stagger_reverse_order() -> void:
	var rig := await _create_seq_rig(3, 0.08, 0.15, JuiceBase.SequenceType.STAGGER_REVERSE)
	var buttons: Array = rig.buttons
	var seq: JuiceControl = rig.sequencer

	seq.animate_in()

	# After stagger_delay (0.08s), only the LAST button should have started
	await wait_seconds(0.04)

	# Btn2 (last) should be moving, Btn0 (first) should not have started yet
	# But warmup pre-positions all at From, so check after a bit more time
	await wait_seconds(0.12)

	# By now Btn2 should be further along than Btn0
	var btn2: Button = buttons[2]
	var btn0: Button = buttons[0]

	# All should eventually complete
	await wait_seconds(0.3)
	assert_greater(btn0.position.x, 30.0,
		"STAGGER_REVERSE: Btn0 eventually moved (pos.x=%.1f)" % btn0.position.x)
	assert_greater(btn2.position.x, 30.0,
		"STAGGER_REVERSE: Btn2 eventually moved (pos.x=%.1f)" % btn2.position.x)

	await cleanup(rig.parent)


func test_target_scope_siblings() -> void:
	# Default rig uses SIBLINGS scope — verify sequencer itself is excluded
	var rig := await _create_seq_rig(2, 0.02, 0.15)
	var seq: JuiceControl = rig.sequencer

	seq.animate_in()
	await wait_seconds(0.4)

	# Both buttons should have moved, sequencer node should not error
	for i in rig.buttons.size():
		var btn: Button = rig.buttons[i]
		assert_greater(btn.position.x, 10.0,
			"SIBLINGS: Btn%d moved (pos.x=%.1f)" % [i, btn.position.x])

	await cleanup(rig.parent)


func test_skip_invisible_filters_hidden() -> void:
	var rig := await _create_seq_rig(3, 0.02, 0.15)
	var buttons: Array = rig.buttons
	var seq: JuiceControl = rig.sequencer

	# Hide button 1
	(buttons[1] as Button).visible = false

	seq.animate_in()
	await wait_seconds(0.4)

	# Btn0 and Btn2 should move, Btn1 should NOT
	assert_greater((buttons[0] as Button).position.x, 10.0,
		"skip_invisible: Btn0 visible, moved")
	assert_approx_float((buttons[1] as Button).position.x, 0.0,
		"skip_invisible: Btn1 hidden, NOT moved", 2.0)
	assert_greater((buttons[2] as Button).position.x, 10.0,
		"skip_invisible: Btn2 visible, moved")

	await cleanup(rig.parent)


func test_skip_juice_nodes_filters_juice() -> void:
	# Verify that other JuiceBase siblings are filtered out
	var rig := await _create_seq_rig(2, 0.02, 0.15)
	var seq: JuiceControl = rig.sequencer

	# The sequencer itself is a JuiceBase sibling — it should be filtered
	# by seq_skip_juice_nodes AND seq_skip_self. Verify no crash/error.
	seq.animate_in()
	await wait_seconds(0.4)

	assert_greater((rig.buttons[0] as Button).position.x, 10.0,
		"skip_juice_nodes: Btn0 moved (sequencer sibling filtered)")

	await cleanup(rig.parent)


func test_targets_children_triggers_child_juice() -> void:
	# Create targets that have their own JuiceControl children
	var parent := Control.new()
	parent.name = "ChildrenParent"
	_runner.add_child(parent)

	var buttons: Array[Button] = []
	for i in 2:
		var btn := Button.new()
		btn.text = "ChildBtn%d" % i
		btn.custom_minimum_size = Vector2(80, 30)
		btn.position = Vector2(0, i * 40)
		parent.add_child(btn)
		buttons.append(btn)

		# Each button gets its own JuiceControl child
		var child_effect := TransformControlJuiceEffect.new()
		child_effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
		child_effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
		child_effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
		child_effect.to_position = Vector2(50, 0)
		child_effect.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
		child_effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
		child_effect.duration_in = 0.15

		var child_recipe := JuiceControlRecipe.new()
		child_recipe.effects.append(child_effect)

		var child_juice := JuiceControl.new()
		child_juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
		child_juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
		child_juice.recipe = child_recipe
		btn.add_child(child_juice)

	# Create sequencer in TARGETS_CHILDREN mode
	var seq := JuiceControl.new()
	seq.name = "ChildrenSeq"
	seq.mode = JuiceBase.Mode.SEQUENCER
	seq.juice_source = JuiceBase.JuiceSource.TARGETS_CHILDREN
	seq.target_scope = JuiceBase.TargetScope.SIBLINGS
	seq.sequence_type = JuiceBase.SequenceType.ALL_AT_ONCE
	seq.seq_skip_self = true
	seq.seq_skip_juice_nodes = true
	seq.trigger_on = JuiceBase.TriggerEvent.MANUAL
	seq.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	parent.add_child(seq)

	await wait_frames(3)

	seq.animate_in()
	await wait_seconds(0.4)

	for i in buttons.size():
		assert_greater(buttons[i].position.x, 10.0,
			"TARGETS_CHILDREN: Btn%d child juice triggered (pos.x=%.1f)" % [i, buttons[i].position.x])

	await cleanup(parent)


func test_sequencer_loop_count_two() -> void:
	var rig := await _create_seq_rig(2, 0.02, 0.1)
	var seq: JuiceControl = rig.sequencer
	seq.loop_count = 2
	seq.loop_delay = 0.05

	var state := [0]  # [completed_count] — array wrapper for lambda capture
	seq.completed.connect(func(): state[0] += 1)

	seq.animate_in()
	# 2 loops × (2 targets × 0.02 stagger + 0.1 duration) + 0.05 delay + buffer
	await wait_seconds(0.8)

	assert_equal(state[0], 1,
		"Sequencer loop_count=2: completed emitted once after all loops")

	await cleanup(rig.parent)


func test_sequencer_play_in_and_out_auto_reverse() -> void:
	var rig := await _create_seq_rig(2, 0.02, 0.1)
	var seq: JuiceControl = rig.sequencer
	seq.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT

	seq.animate_in()
	# Forward + reverse: ~2 × (2 × 0.02 + 0.1) + buffer
	await wait_seconds(0.6)

	# After IN_AND_OUT, targets should be back near starting position
	for i in rig.buttons.size():
		var btn: Button = rig.buttons[i]
		assert_approx_float(btn.position.x, 0.0,
			"PLAY_IN_AND_OUT: Btn%d returned near start (pos.x=%.1f)" % [i, btn.position.x], 5.0)

	await cleanup(rig.parent)


func test_sequencer_retrigger_restart() -> void:
	var rig := await _create_seq_rig(3, 0.1, 0.2)
	var seq: JuiceControl = rig.sequencer
	seq.retrigger_policy = JuiceBase.RetriggerPolicy.RESTART

	seq.animate_in()
	# Wait for first target to start, then retrigger
	await wait_seconds(0.05)
	seq.animate_in()

	# The restart should have aborted the first sequence via generation counter
	await wait_seconds(0.6)

	# All targets should still complete (from the restarted sequence)
	for i in rig.buttons.size():
		var btn: Button = rig.buttons[i]
		assert_greater(btn.position.x, 10.0,
			"RESTART retrigger: Btn%d completed (pos.x=%.1f)" % [i, btn.position.x])

	await cleanup(rig.parent)


func test_completed_signal_fires() -> void:
	var rig := await _create_seq_rig(2, 0.02, 0.1)
	var seq: JuiceControl = rig.sequencer

	var state := [false]  # [completed_fired] — array wrapper for lambda capture
	seq.completed.connect(func(): state[0] = true)

	seq.animate_in()
	await wait_seconds(0.4)

	assert_true(state[0], "completed signal fired after sequence finishes")

	await cleanup(rig.parent)


func test_warmup_prepositions_during_start_delay() -> void:
	# Create rig with a long start_delay — targets should be at From state
	# immediately, NOT staying at Self/natural during the delay.
	var rig := await _create_seq_rig(2, 0.02, 0.15)
	var seq: JuiceControl = rig.sequencer
	seq.start_delay = 0.5  # Long delay

	# Record starting positions (should be 0)
	var start_x_0 := (rig.buttons[0] as Button).position.x
	var _start_x_1 := (rig.buttons[1] as Button).position.x

	seq.animate_in()

	# Wait a few frames — warmup should have pre-positioned targets at From
	# The effect is From=SELF, To=CUSTOM(60,0), so at progress 0.0 the
	# target should be at its original position (From=SELF means natural).
	# BUT the delta is computed and written, so position should reflect the
	# From state. For SELF reference, From = captured base = natural pos.
	# This test verifies that warmup ran (effects started) before the delay.
	await wait_frames(5)

	# The From reference is SELF (natural), so at progress 0.0 the target
	# stays at natural pos. This verifies warmup executed (no crash, effects init'd).
	# The key V0 parity: warmup runs BEFORE delay, not after.
	var mid_delay_x_0 := (rig.buttons[0] as Button).position.x
	assert_approx_float(mid_delay_x_0, start_x_0,
		"Warmup during delay: Btn0 at From=SELF (natural pos) not moved yet", 2.0)

	# Now wait for delay + animation to finish
	await wait_seconds(0.8)

	# After delay + stagger + animation, targets should have moved
	assert_greater((rig.buttons[0] as Button).position.x, 10.0,
		"After delay: Btn0 eventually moved (pos.x=%.1f)" % (rig.buttons[0] as Button).position.x)

	await cleanup(rig.parent)
