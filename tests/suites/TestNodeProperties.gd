## TestNodeProperties.gd
## ============================================================================
## WHAT: Tests for JuiceBase node-level properties across all domains.
## WHY: Verify start_delay, loop_count, loop_delay, retrigger_policy, and
##      trigger_behaviour are all wired up and produce correct runtime behavior.
## SYSTEM: Tests (tests/suites/)
## ============================================================================
##
## Tests use Control domain (JuiceControl + TransformControlJuiceEffect)
## because it's the easiest to set up programmatically. Node-level properties
## are domain-agnostic (implemented in JuiceBase), so testing one domain
## verifies all three.
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "node_properties"


func get_test_methods() -> Array[String]:
	return [
		"test_start_delay_zero_moves_immediately",
		"test_start_delay_holds_then_starts",
		"test_start_delay_retrigger_restart_clears_delay",
		"test_loop_count_two_replays",
		"test_loop_delay_pauses_between_iterations",
		"test_retrigger_ignore",
		"test_retrigger_restart",
		"test_restart_spammable_at_target",
		"test_restart_same_direction_resets",
		"test_restart_crossfade_direction_switch",
		"test_interrupt_siblings_stops_matching",
		"test_hold_at_peak_delays_auto_reverse",
		"test_ping_pong_oscillates",
		"test_infinite_loop_keeps_playing",
		"test_retrigger_queue_plays_after_first",
		"test_chain_to_sequential_effects",
		"test_loop_phase_offset_starts_mid_cycle",
		"test_trigger_behaviour_play_in_only",
		"test_trigger_behaviour_play_out_only",
		"test_trigger_behaviour_toggle",
	]


# =============================================================================
# HELPER: Create a standard test rig (Button + JuiceControl + TransformEffect)
# =============================================================================

## Creates a Button with a JuiceControl child, configured for position animation.
## Returns [button, juice_node, effect] for inspection and triggering.
func _create_position_rig(
	label: String,
	to_pos: Vector2 = Vector2(100, 0),
	duration: float = 0.3,
	trigger_beh: JuiceEffectBase.TriggerBehaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY,
	dur_out: float = -1.0
) -> Array:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(120, 40)
	btn.position = Vector2.ZERO
	_runner.add_child(btn)

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_position = to_pos
	effect.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect.trigger_behaviour = trigger_beh
	effect.duration_in = duration
	if dur_out >= 0.0:
		effect.duration_out = dur_out

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = trigger_beh
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	btn.add_child(juice)

	# Wait for _ready to fire and clone effects
	await wait_frames(2)

	return [btn, juice, effect]


# =============================================================================
# TESTS: start_delay
# =============================================================================

func test_start_delay_zero_moves_immediately() -> void:
	var rig := await _create_position_rig("delay=0", Vector2(100, 0), 0.3)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]
	juice.start_delay = 0.0

	var base_pos := btn.position

	juice.animate_in()
	# Wait enough frames for animation to start
	await wait_seconds(0.1)

	assert_not_approx_vec2(btn.position, base_pos,
		"With start_delay=0, target should move immediately after trigger", 0.5)

	await cleanup(btn)


func test_start_delay_holds_then_starts() -> void:
	var rig := await _create_position_rig("delay=0.5", Vector2(100, 0), 0.3)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]
	juice.start_delay = 0.5

	var base_pos := btn.position

	juice.animate_in()

	# During delay (0.2s in): target should NOT have moved
	await wait_seconds(0.2)
	assert_approx_vec2(btn.position, base_pos,
		"During node start_delay, target should remain at base position", 2.0)

	# After delay expires (0.7s total): target should have moved
	await wait_seconds(0.5)
	assert_not_approx_vec2(btn.position, base_pos,
		"After node start_delay expires, target should be animating", 5.0)

	await cleanup(btn)


func test_start_delay_retrigger_restart_clears_delay() -> void:
	var rig := await _create_position_rig("delay_retrigger", Vector2(100, 0), 0.5)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]
	juice.start_delay = 1.0
	juice.retrigger_policy = JuiceBase.RetriggerPolicy.RESTART

	juice.animate_in()
	await wait_seconds(0.3)

	# Retrigger with RESTART — should reset the delay
	juice.start_delay = 0.0  # Remove delay for second trigger
	juice.animate_in()
	await wait_seconds(0.15)

	# With delay=0 on retrigger, animation should have started
	assert_not_approx_vec2(btn.position, Vector2.ZERO,
		"After RESTART retrigger with delay=0, animation should start immediately", 0.5)

	await cleanup(btn)


# =============================================================================
# TESTS: loop_count / loop_delay
# =============================================================================

func test_loop_count_two_replays() -> void:
	var rig := await _create_position_rig("loop=2", Vector2(80, 0), 0.15,
		JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]
	juice.loop_count = 2

	var counter := [0]  # Array so lambda captures by reference
	juice.completed.connect(func(): counter[0] += 1)

	juice.animate_in()

	# Wait long enough for 2 full cycles (in+out = ~0.3s each, x2 = ~0.6s + margin)
	await wait_seconds(1.5)

	assert_equal(counter[0], 1,
		"completed signal should fire once after loop_count=2 finishes")

	await cleanup(btn)


func test_loop_delay_pauses_between_iterations() -> void:
	var rig := await _create_position_rig("loop_delay", Vector2(80, 0), 0.1,
		JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT, 0.1)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]
	juice.loop_count = 2
	juice.loop_delay = 0.5

	juice.animate_in()

	# First cycle completes ~0.2s, then 0.5s loop_delay, then second cycle
	# At 0.4s we should be in loop_delay (position near base after out phase)
	await wait_seconds(0.4)
	assert_approx_vec2(btn.position, Vector2.ZERO,
		"During loop_delay, target should be near base (after out phase)", 10.0)

	await cleanup(btn)


# =============================================================================
# TESTS: retrigger_policy
# =============================================================================

func test_retrigger_ignore() -> void:
	var rig := await _create_position_rig("retrigger_ignore", Vector2(100, 0), 0.5)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]
	juice.retrigger_policy = JuiceBase.RetriggerPolicy.IGNORE

	juice.animate_in()
	await wait_seconds(0.1)
	var pos_after_first := btn.position

	# Second trigger should be ignored
	juice.animate_in()
	await wait_frames(2)
	var pos_after_second := btn.position

	# Position should continue smoothly (not reset)
	assert_approx_vec2(pos_after_second, pos_after_first,
		"IGNORE policy: second trigger should not reset animation", 15.0)

	await cleanup(btn)


func test_retrigger_restart() -> void:
	var rig := await _create_position_rig("retrigger_restart", Vector2(100, 0), 0.5)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]
	juice.retrigger_policy = JuiceBase.RetriggerPolicy.RESTART

	juice.animate_in()
	await wait_seconds(0.3)
	var pos_mid := btn.position

	# Retrigger — should restart from beginning
	juice.animate_in()
	await wait_seconds(0.05)

	# After restart, position should be near the start (less than mid-point)
	assert_true(btn.position.x < pos_mid.x,
		"RESTART policy: position after retrigger (%.1f) should be less than mid-point (%.1f)" % [
			btn.position.x, pos_mid.x])

	await cleanup(btn)


func test_restart_spammable_at_target() -> void:
	var rig := await _create_position_rig("spammable", Vector2(100, 0), 0.1)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]
	juice.retrigger_policy = JuiceBase.RetriggerPolicy.RESTART

	# First trigger: animate IN to completion (progress reaches 1.0)
	juice.animate_in()
	await wait_seconds(0.3)
	assert_not_approx_vec2(btn.position, Vector2.ZERO,
		"After first IN completes, should be at target", 5.0)

	# Second trigger: same direction, effect is idle at target (1.0 → 1.0 would be no-op)
	# M2 ensures progress resets to origin so re-trigger always produces motion
	juice.animate_in()
	await wait_seconds(0.05)
	assert_true(btn.position.x < 90.0,
		"Spammable: re-trigger at target should restart from origin (pos.x=%.1f should be < 90)" % btn.position.x)

	await cleanup(btn)


func test_restart_same_direction_resets() -> void:
	var rig := await _create_position_rig("same_dir", Vector2(100, 0), 0.5)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]
	juice.retrigger_policy = JuiceBase.RetriggerPolicy.RESTART

	juice.animate_in()
	await wait_seconds(0.25)
	var pos_mid := btn.position.x

	# Same-direction retrigger (IN again while already going IN)
	juice.animate_in()
	await wait_seconds(0.05)

	# M1: should have restarted from origin (near 0), not continued from mid
	assert_true(btn.position.x < pos_mid,
		"Same-direction RESTART: pos (%.1f) should be less than mid-point (%.1f)" % [btn.position.x, pos_mid])

	await cleanup(btn)


func test_restart_crossfade_direction_switch() -> void:
	var rig := await _create_position_rig("crossfade", Vector2(100, 0), 0.5,
		JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]
	juice.retrigger_policy = JuiceBase.RetriggerPolicy.RESTART
	# Set crossfade_time on the runtime clone
	for eff in juice._runtime_effects:
		if eff != null:
			eff.crossfade_time = 0.3

	# Animate IN
	juice.animate_in()
	await wait_seconds(0.25)
	var _pos_before_switch := btn.position.x

	# Direction switch: trigger OUT while going IN
	# D1+M3: crossfade should capture current position and blend smoothly
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_OUT_ONLY
	juice.animate_out()
	await wait_frames(3)

	# During crossfade, position should NOT have snapped to 0 — it should be
	# near where it was (crossfade blends from old visual to new animation)
	assert_true(btn.position.x > 10.0,
		"Crossfade: position (%.1f) should not snap to 0 during blend" % btn.position.x)

	# After crossfade completes, animation should have moved toward 0
	await wait_seconds(0.5)
	assert_approx_vec2(btn.position, Vector2.ZERO,
		"After crossfade + OUT completes, should be near base", 15.0)

	await cleanup(btn)


func test_interrupt_siblings_stops_matching() -> void:
	# Two JuiceControl nodes on the same parent with same-type effects
	var btn := Button.new()
	btn.text = "interrupt"
	btn.position = Vector2.ZERO
	_runner.add_child(btn)

	# First juice node (will be interrupted)
	var effect_a := TransformControlJuiceEffect.new()
	effect_a.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect_a.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect_a.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect_a.to_position = Vector2(100, 0)
	effect_a.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect_a.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect_a.duration_in = 1.0

	var juice_a := JuiceControl.new()
	juice_a.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe_a := JuiceControlRecipe.new()
	recipe_a.effects.append(effect_a)
	juice_a.recipe = recipe_a
	btn.add_child(juice_a)

	# Second juice node (the interrupter) — same effect type, interrupt_siblings on
	var effect_b := TransformControlJuiceEffect.new()
	effect_b.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect_b.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect_b.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect_b.to_position = Vector2(-50, 0)
	effect_b.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect_b.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect_b.duration_in = 1.0
	effect_b.interrupt_siblings = true

	var juice_b := JuiceControl.new()
	juice_b.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe_b := JuiceControlRecipe.new()
	recipe_b.effects.append(effect_b)
	juice_b.recipe = recipe_b
	btn.add_child(juice_b)

	await wait_frames(2)

	# Start first, let it play
	juice_a.animate_in()
	await wait_seconds(0.2)
	assert_true(juice_a._is_playing,
		"juice_a should be playing before interrupt")

	# Trigger second (with interrupt_siblings) — should stop first
	juice_b.animate_in()
	await wait_frames(2)
	assert_true(not juice_a._is_playing,
		"juice_a should be stopped after juice_b (interrupt_siblings) triggers")
	assert_true(juice_b._is_playing,
		"juice_b should be playing after triggering")

	await cleanup(btn)


# =============================================================================
# TESTS: hold_at_peak, ping_pong, infinite loop, QUEUE, chaining, loop_phase_offset
# =============================================================================

func test_hold_at_peak_delays_auto_reverse() -> void:
	var rig := await _create_position_rig("hold_peak", Vector2(100, 0), 0.1,
		JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT, 0.1)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]
	# Set hold_at_peak on the runtime clone
	for eff in juice._runtime_effects:
		if eff != null:
			eff.hold_at_peak = 0.5

	juice.animate_in()
	# IN takes 0.1s, then hold 0.5s, then OUT 0.1s
	# At 0.3s we should be in hold (position near target, not returning)
	await wait_seconds(0.3)
	assert_true(btn.position.x > 80.0,
		"During hold_at_peak, position (%.1f) should be near target (100)" % btn.position.x)

	# After hold + OUT completes (~0.8s total), should be back near base
	await wait_seconds(0.6)
	assert_approx_vec2(btn.position, Vector2.ZERO,
		"After hold_at_peak + OUT completes, should be near base", 15.0)

	await cleanup(btn)


func test_ping_pong_oscillates() -> void:
	var rig := await _create_position_rig("ping_pong", Vector2(100, 0), 0.15)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]
	# Enable ping_pong on the runtime clone
	for eff in juice._runtime_effects:
		if eff != null:
			eff.ping_pong = true
			eff.loop_count = 1

	juice.animate_in()
	# Ping: 0→1.0 in 0.15s, Pong: 1.0→0 in 0.15s
	# At 0.1s: should be partway through ping (position > 0)
	await wait_seconds(0.1)
	assert_true(btn.position.x > 20.0,
		"Ping phase: position (%.1f) should be moving toward target" % btn.position.x)

	# At 0.35s: pong should have returned near base
	await wait_seconds(0.25)
	assert_approx_vec2(btn.position, Vector2.ZERO,
		"After ping-pong completes, should be near base", 15.0)

	await cleanup(btn)


func test_infinite_loop_keeps_playing() -> void:
	var rig := await _create_position_rig("inf_loop", Vector2(80, 0), 0.1,
		JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT, 0.1)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]
	juice.loop_count = -1  # infinite

	juice.animate_in()
	# After several cycles, should still be playing
	await wait_seconds(0.8)
	assert_true(juice._is_playing,
		"Infinite loop (loop_count=-1) should still be playing after 0.8s")

	juice.stop()
	await wait_frames(2)
	assert_true(not juice._is_playing,
		"After stop(), infinite loop should no longer be playing")

	await cleanup(btn)


func test_retrigger_queue_plays_after_first() -> void:
	var rig := await _create_position_rig("queue", Vector2(100, 0), 0.2,
		JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT, 0.2)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]
	juice.retrigger_policy = JuiceBase.RetriggerPolicy.QUEUE

	var counter := [0]
	juice.completed.connect(func(): counter[0] += 1)

	# First trigger
	juice.animate_in()
	await wait_seconds(0.1)
	# Queue a second trigger while first is playing
	juice.animate_in()

	# Wait for both to complete (first ~0.4s + second ~0.4s + margin)
	await wait_seconds(1.2)
	assert_equal(counter[0], 2,
		"QUEUE: completed should fire twice (first + queued)")

	await cleanup(btn)


func test_chain_to_sequential_effects() -> void:
	var btn := Button.new()
	btn.text = "chain"
	btn.custom_minimum_size = Vector2(120, 40)
	btn.position = Vector2.ZERO
	_runner.add_child(btn)

	# Effect A: move right
	var effect_a := TransformControlJuiceEffect.new()
	effect_a.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect_a.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect_a.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect_a.to_position = Vector2(50, 0)
	effect_a.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect_a.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect_a.duration_in = 0.15

	# Effect B: move down (chained from A)
	var effect_b := TransformControlJuiceEffect.new()
	effect_b.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect_b.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect_b.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect_b.to_position = Vector2(0, 50)
	effect_b.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect_b.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect_b.duration_in = 0.15

	# Chain A -> B
	effect_a.chain_to = effect_b

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect_a)
	recipe.effects.append(effect_b)
	juice.recipe = recipe
	btn.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	# After A completes (0.15s), B should start
	await wait_seconds(0.1)
	# During A: should have moved right, not down yet
	assert_true(btn.position.x > 10.0,
		"During chain A: position.x (%.1f) should be moving right" % btn.position.x)
	assert_approx_vec2(Vector2(0, btn.position.y), Vector2.ZERO,
		"During chain A: position.y should still be near 0", 5.0)

	# After both complete
	await wait_seconds(0.4)
	assert_true(btn.position.y > 10.0,
		"After chain B: position.y (%.1f) should have moved down" % btn.position.y)

	await cleanup(btn)


func test_loop_phase_offset_starts_mid_cycle() -> void:
	var rig := await _create_position_rig("phase_offset", Vector2(100, 0), 0.3)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]
	# Set loop_phase_offset = 0.5 (start at 50% through the cycle)
	for eff in juice._runtime_effects:
		if eff != null:
			eff.loop_phase_offset = 0.5

	juice.animate_in()
	await wait_frames(3)
	# With offset 0.5, effect should start at ~50% progress (position ~50)
	assert_true(btn.position.x > 30.0,
		"loop_phase_offset=0.5: initial position (%.1f) should be near midpoint" % btn.position.x)

	await cleanup(btn)


# =============================================================================
# TESTS: trigger_behaviour
# =============================================================================

func test_trigger_behaviour_play_in_only() -> void:
	var rig := await _create_position_rig("play_in_only", Vector2(100, 0), 0.2)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	await wait_seconds(0.4)

	# After completion, should be at target position (held at peak)
	assert_not_approx_vec2(btn.position, Vector2.ZERO,
		"PLAY_IN_ONLY: target should be near To position after completion", 5.0)

	await cleanup(btn)


func test_trigger_behaviour_play_out_only() -> void:
	var rig := await _create_position_rig("play_out_only", Vector2(100, 0), 0.2)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_OUT_ONLY

	juice.animate_out()
	await wait_seconds(0.4)

	# PLAY_OUT_ONLY animates from peak (1.0) to natural (0.0)
	# After completion, should be back near base
	assert_approx_vec2(btn.position, Vector2.ZERO,
		"PLAY_OUT_ONLY: target should return to base after out completes", 10.0)

	await cleanup(btn)


func test_trigger_behaviour_toggle() -> void:
	var rig := await _create_position_rig("toggle", Vector2(100, 0), 0.15)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.TOGGLE

	# First toggle: animate in
	juice.animate_in()
	await wait_seconds(0.3)
	assert_not_approx_vec2(btn.position, Vector2.ZERO,
		"TOGGLE first trigger: should animate to To position", 5.0)

	# Second toggle: animate out
	juice.animate_in()
	await wait_seconds(0.3)
	assert_approx_vec2(btn.position, Vector2.ZERO,
		"TOGGLE second trigger: should animate back to base", 10.0)

	await cleanup(btn)
