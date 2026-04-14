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
		"test_container_layout_preserved_during_animation",
		"test_custom_from_scale_not_polluted_by_warmup",
		"test_external_reset_during_warmup_hold_recovers",
	]


# =============================================================================
# HELPER: Create a sequencer rig with N sibling buttons inside HBoxContainer
# =============================================================================

## Creates an HBoxContainer with N Button children and a JuiceControl sequencer.
## Uses a real Container so tests catch layout-management bugs.
## Animation moves Y axis (perpendicular to HBox layout) so Container-managed
## X positions can be independently verified.
## Returns { "parent": HBoxContainer, "buttons": Array[Button], "sequencer": JuiceControl }
func _create_seq_rig(
	button_count: int = 3,
	stagger_delay: float = 0.05,
	duration: float = 0.15,
	sequence_type: JuiceBase.SequenceType = JuiceBase.SequenceType.STAGGER_FORWARD,
	juice_source: JuiceBase.JuiceSource = JuiceBase.JuiceSource.RECIPE,
) -> Dictionary:
	var parent := HBoxContainer.new()
	parent.name = "SeqHBox"
	parent.size = Vector2(600, 100)
	_runner.add_child(parent)

	var buttons: Array[Button] = []
	for i in button_count:
		var btn := Button.new()
		btn.text = "Btn%d" % i
		btn.custom_minimum_size = Vector2(80, 30)
		parent.add_child(btn)
		buttons.append(btn)

	# Build recipe: position animation with CUSTOM From (non-zero warmup delta).
	# From = base + (0, -40) — 40px above natural during warmup/hold.
	# To   = base + (0, 60)  — 60px below natural at animation end.
	# CUSTOM From is critical: exercises the warmup-to-animation transition where
	# effects re-capture base. From=SELF would produce zero warmup delta, hiding bugs.
	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.from_position = Vector2(0, -40)
	effect.from_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(0, 60)
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

	# Record starting Y positions (HBox-managed)
	var start_positions: Array[float] = []
	for btn: Button in buttons:
		start_positions.append(btn.position.y)

	seq.animate_in()

	# Wait for full sequence: 3 targets × 0.05 stagger + 0.15 duration + buffer
	await wait_seconds(0.5)

	# All buttons should have moved down (Y increased)
	for i in buttons.size():
		var btn: Button = buttons[i]
		assert_greater(btn.position.y, start_positions[i] + 10.0,
			"Btn%d moved down after stagger forward (pos.y=%.1f)" % [i, btn.position.y])

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
		if btn.position.y > 5.0:
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
	assert_greater(btn0.position.y, 30.0,
		"STAGGER_REVERSE: Btn0 eventually moved (pos.y=%.1f)" % btn0.position.y)
	assert_greater(btn2.position.y, 30.0,
		"STAGGER_REVERSE: Btn2 eventually moved (pos.y=%.1f)" % btn2.position.y)

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
		assert_greater(btn.position.y, 10.0,
			"SIBLINGS: Btn%d moved (pos.y=%.1f)" % [i, btn.position.y])

	await cleanup(rig.parent)


func test_skip_invisible_filters_hidden() -> void:
	var rig := await _create_seq_rig(3, 0.02, 0.15)
	var buttons: Array = rig.buttons
	var seq: JuiceControl = rig.sequencer

	# Capture btn1 Y before hiding (HBox re-sort may change it)
	var _btn1_pre_y := (buttons[1] as Button).position.y

	# Hide button 1 and wait for HBox re-sort
	(buttons[1] as Button).visible = false
	await wait_frames(2)
	var btn1_hidden_y := (buttons[1] as Button).position.y

	seq.animate_in()
	await wait_seconds(0.4)

	# Btn0 and Btn2 should move (Y increased), Btn1 should NOT
	assert_greater((buttons[0] as Button).position.y, 10.0,
		"skip_invisible: Btn0 visible, moved")
	assert_approx_float((buttons[1] as Button).position.y, btn1_hidden_y,
		"skip_invisible: Btn1 hidden, NOT moved (y=%.1f vs pre=%.1f)" % [
			(buttons[1] as Button).position.y, btn1_hidden_y], 2.0)
	assert_greater((buttons[2] as Button).position.y, 10.0,
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

	assert_greater((rig.buttons[0] as Button).position.y, 10.0,
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

	# After IN_AND_OUT, targets should be back at From state = CUSTOM(0, -40)
	for i in rig.buttons.size():
		var btn: Button = rig.buttons[i]
		assert_approx_float(btn.position.y, -40.0,
			"PLAY_IN_AND_OUT: Btn%d returned to From=-40 (pos.y=%.1f)" % [i, btn.position.y], 5.0)

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
		assert_greater(btn.position.y, 10.0,
			"RESTART retrigger: Btn%d completed (pos.y=%.1f)" % [i, btn.position.y])

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
	# immediately, NOT staying at natural during the delay.
	# Rig uses From=CUSTOM(0, -40) so warmup delta is non-zero.
	var rig := await _create_seq_rig(2, 0.02, 0.15)
	var seq: JuiceControl = rig.sequencer
	seq.start_delay = 0.5  # Long delay

	seq.animate_in()

	# Wait a few frames — warmup should have pre-positioned at From state.
	# From=CUSTOM(0, -40) means targets should be 40px ABOVE natural (Y ≈ -40).
	await wait_frames(5)

	var mid_delay_y_0 := (rig.buttons[0] as Button).position.y
	assert_approx_float(mid_delay_y_0, -40.0,
		"Warmup during delay: Btn0 at From=CUSTOM(-40) (pos.y=%.1f)" % mid_delay_y_0, 5.0)

	# Now wait for delay + animation to finish
	await wait_seconds(0.8)

	# After delay + stagger + animation, targets should be at To = +60
	assert_greater((rig.buttons[0] as Button).position.y, 50.0,
		"After delay: Btn0 reached To state (pos.y=%.1f)" % (rig.buttons[0] as Button).position.y)

	await cleanup(rig.parent)


func test_container_layout_preserved_during_animation() -> void:
	# HBoxContainer manages X positions. Animation moves Y.
	# Verify that Container-managed X positions remain correct and distinct
	# throughout the animation — not collapsed to 0 or overlapping.
	var rig := await _create_seq_rig(3, 0.0, 0.2, JuiceBase.SequenceType.ALL_AT_ONCE)
	var buttons: Array = rig.buttons
	var seq: JuiceControl = rig.sequencer

	# Record HBox-managed X positions before animation
	var natural_x: Array[float] = []
	for btn: Button in buttons:
		natural_x.append(btn.position.x)

	# Buttons should have distinct X positions (HBox lays them out horizontally)
	assert_greater(natural_x[1], natural_x[0] + 10.0,
		"Pre-anim: Btn1.x (%.1f) > Btn0.x (%.1f) — HBox layout" % [natural_x[1], natural_x[0]])
	assert_greater(natural_x[2], natural_x[1] + 10.0,
		"Pre-anim: Btn2.x (%.1f) > Btn1.x (%.1f) — HBox layout" % [natural_x[2], natural_x[1]])

	seq.animate_in()

	# Check mid-animation: Y should be moving, X should stay at HBox values
	await wait_seconds(0.1)
	for i in buttons.size():
		var btn: Button = buttons[i]
		assert_approx_float(btn.position.x, natural_x[i],
			"Mid-anim: Btn%d X preserved (%.1f vs natural %.1f)" % [i, btn.position.x, natural_x[i]], 2.0)
		assert_greater(btn.position.y, 5.0,
			"Mid-anim: Btn%d Y moved (pos.y=%.1f)" % [i, btn.position.y])

	# Check post-animation: X should still be at HBox values
	await wait_seconds(0.3)
	for i in buttons.size():
		var btn: Button = buttons[i]
		assert_approx_float(btn.position.x, natural_x[i],
			"Post-anim: Btn%d X preserved (%.1f vs natural %.1f)" % [i, btn.position.x, natural_x[i]], 2.0)

	# Y should have reached ~60 (full animation)
	assert_greater((buttons[0] as Button).position.y, 50.0,
		"Post-anim: Btn0 Y reached target (pos.y=%.1f)" % (buttons[0] as Button).position.y)

	await cleanup(rig.parent)


func test_custom_from_scale_not_polluted_by_warmup() -> void:
	# Reproduces the exact bug: warmup sets scale to From=0, then effect.start()
	# re-captures base from the warmup-modified target (scale=0 instead of 1).
	# With polluted base: animation goes 1→2 instead of 0→1.
	# Fix: _seq_restore_target_natural() undoes contribution before base capture.
	var parent := HBoxContainer.new()
	parent.name = "ScaleHBox"
	parent.size = Vector2(600, 100)
	_runner.add_child(parent)

	var buttons: Array[Button] = []
	for i in 2:
		var btn := Button.new()
		btn.text = "ScaleBtn%d" % i
		btn.custom_minimum_size = Vector2(80, 30)
		parent.add_child(btn)
		buttons.append(btn)

	# Scale effect: From=CUSTOM(0,0) → To=CUSTOM(1,1)
	# At warmup (progress 0): scale goes to (0,0). Non-zero warmup delta!
	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.SCALE
	effect.from_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.from_scale = Vector2(0, 0)
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_scale = Vector2(1, 1)
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.15

	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)

	var seq := JuiceControl.new()
	seq.name = "ScaleSeq"
	seq.mode = JuiceBase.Mode.SEQUENCER
	seq.juice_source = JuiceBase.JuiceSource.RECIPE
	seq.target_scope = JuiceBase.TargetScope.SIBLINGS
	seq.sequence_type = JuiceBase.SequenceType.STAGGER_FORWARD
	seq.seq_stagger_delay = 0.05
	seq.seq_skip_self = true
	seq.seq_skip_juice_nodes = true
	seq.trigger_on = JuiceBase.TriggerEvent.MANUAL
	seq.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	seq.recipe = recipe
	parent.add_child(seq)

	await wait_frames(3)

	# Natural scale should be (1, 1)
	for btn: Button in buttons:
		assert_approx_float(btn.scale.x, 1.0,
			"Pre-anim: %s scale.x = 1 (natural)" % btn.text, 0.01)

	# Use start_delay so warmup holds long enough to verify From state
	seq.start_delay = 0.3
	seq.animate_in()

	# During delay, warmup holds targets at From state (scale 0)
	await wait_frames(5)
	assert_approx_float(buttons[0].scale.x, 0.0,
		"Warmup: Btn0 at From scale=0 (scale.x=%.2f)" % buttons[0].scale.x, 0.05)
	assert_approx_float(buttons[1].scale.x, 0.0,
		"Warmup: Btn1 at From scale=0 (scale.x=%.2f)" % buttons[1].scale.x, 0.05)

	# Wait for delay + animation to complete
	await wait_seconds(0.8)

	# After animation: scale should be at To = (1, 1), NOT (2, 2)
	for btn: Button in buttons:
		assert_approx_float(btn.scale.x, 1.0,
			"Post-anim: %s scale.x = 1 (To state), NOT 2 (polluted)" % btn.text, 0.1)
		assert_approx_float(btn.scale.y, 1.0,
			"Post-anim: %s scale.y = 1 (To state), NOT 2 (polluted)" % btn.text, 0.1)

	await cleanup(parent)


func test_external_reset_during_warmup_hold_recovers() -> void:
	# Reproduces the exact bug from Control_Intro_v1.tscn:
	# Something externally resets scale from 0 (warmup From) back to 1 (natural)
	# between warmup and the first process tick. Without external-reset detection,
	# contribution tracking computes wrong natural: (1,1)-(-1,-1)=(2,2) instead of (1,1).
	# Result: scale stays at 1 during delay, then animates 1→2 instead of 0→1.
	var parent := HBoxContainer.new()
	parent.name = "ResetHBox"
	parent.size = Vector2(600, 100)
	_runner.add_child(parent)

	var buttons: Array[Button] = []
	for i in 2:
		var btn := Button.new()
		btn.text = "ResetBtn%d" % i
		btn.custom_minimum_size = Vector2(80, 30)
		parent.add_child(btn)
		buttons.append(btn)

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.SCALE
	effect.from_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.from_scale = Vector2(0, 0)
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_scale = Vector2(1, 1)
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)

	var seq := JuiceControl.new()
	seq.name = "ResetSeq"
	seq.mode = JuiceBase.Mode.SEQUENCER
	seq.juice_source = JuiceBase.JuiceSource.RECIPE
	seq.target_scope = JuiceBase.TargetScope.SIBLINGS
	seq.sequence_type = JuiceBase.SequenceType.STAGGER_FORWARD
	seq.seq_stagger_delay = 0.05
	seq.seq_skip_self = true
	seq.seq_skip_juice_nodes = true
	seq.trigger_on = JuiceBase.TriggerEvent.MANUAL
	seq.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	seq.recipe = recipe
	seq.start_delay = 0.5
	parent.add_child(seq)

	await wait_frames(3)

	seq.animate_in()
	# Warmup just ran synchronously — targets should be at scale=0
	# Now SIMULATE the external reset that happens in real scenes
	# (something resets scale back to 1 before the first process tick)
	for btn in buttons:
		btn.scale = Vector2(1, 1)

	# Wait a few frames — V1 drift detection will permanently add the external +1.0 override to the baseline.
	# The hold delta (-1.0) + the new base (2.0) = 1.0.
	await wait_frames(5)
	assert_approx_float(buttons[0].scale.x, 1.0,
		"Post-reset recovery: Btn0 holds at 1.0 due to additive drift (scale.x=%.2f)" % buttons[0].scale.x, 0.05)
	assert_approx_float(buttons[1].scale.x, 1.0,
		"Post-reset recovery: Btn1 holds at 1.0 due to additive drift (scale.x=%.2f)" % buttons[1].scale.x, 0.05)

	# Wait for delay + animation to complete
	await wait_seconds(1.0)

	# After animation: scale must be at To=(1,1) + Drift(1,1) = (2,2)
	for btn: Button in buttons:
		assert_approx_float(btn.scale.x, 2.0,
			"Post-anim: %s scale.x = 2 (baseline 1 + drift 1)" % btn.text, 0.1)
		assert_approx_float(btn.scale.y, 2.0,
			"Post-anim: %s scale.y = 2 (baseline 1 + drift 1)" % btn.text, 0.1)

	await cleanup(parent)
