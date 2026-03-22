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
		"test_start_delay_prepositions_at_from",
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
		"test_4phase_ping_pong_in_and_out",
		"test_custom_curve_in_overrides_easing",
		"test_elastic_easing_overshoots",
		"test_back_easing_overshoots",
		"test_custom_curve_out_overrides_easing",
		"test_elastic_easing_out_overshoots",
		"test_back_easing_out_overshoots",
		"test_loop_counter_preserved_during_auto_out",
		"test_play_in_and_out_loop_restart",
		"test_mirror_in_to_out_copies_all_params",
		"test_mirror_in_to_out_reverses_custom_curve",
		"test_autoconnect_button_pressed",
		"test_autoconnect_control_hover",
		"test_autoconnect_control_focus",
		"test_autoconnect_control_gui_input_press",
		"test_autoconnect_visibility_on_show",
		"test_autoconnect_animation_player",
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


func test_start_delay_prepositions_at_from() -> void:
	# Effect: From=CUSTOM(-80,0) pixels, To=SELF. With start_delay, target
	# should sit at From position during delay, NOT at natural position.
	var btn := Button.new()
	btn.text = "delay_prepos"
	btn.custom_minimum_size = Vector2(120, 40)
	btn.position = Vector2.ZERO
	_runner.add_child(btn)

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.from_position = Vector2(-80, 0)
	effect.from_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect.to_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.3

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	juice.start_delay = 0.5
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	btn.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_frames(3)

	# During delay: target should be near From position (-80, 0), NOT at base (0, 0)
	assert_true(btn.position.x < -50.0,
		"During start_delay, target should be at From position (%.1f), not natural" % btn.position.x)

	# After delay expires + animation completes: should be back at base (Self)
	await wait_seconds(1.0)
	assert_approx_vec2(btn.position, Vector2.ZERO,
		"After start_delay + animation, target should return to Self (base)", 5.0)

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


# =============================================================================
# TESTS: 4-phase ping-pong (IN_AND_OUT + ping_pong)
# =============================================================================

func test_4phase_ping_pong_in_and_out() -> void:
	# IN_AND_OUT + ping_pong = 4 phases per cycle:
	# Phase 0: 0->1 (in, normal)
	# Phase 1: 1->0 (out, normal)
	# Phase 2: 1->0 (out, reversed)
	# Phase 3: 0->1 (in, reversed)
	var rig := await _create_position_rig("4phase_pp", Vector2(80, 0), 0.1,
		JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT, 0.1)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]

	# Configure ping_pong on the runtime effect
	for eff in juice._runtime_effects:
		if eff != null:
			eff.ping_pong = true
			eff.loop_count = 1

	juice.animate_in()
	# 4 phases x 0.1s each = 0.4s total. Wait for completion.
	await wait_seconds(0.6)

	# After 4 phases, target should be back near base (0,0)
	# Phase 0: 0->1 (pos goes 0->80)
	# Phase 1: 1->0 (pos goes 80->0)
	# Phase 2: 1->0 reversed (pos goes 0->80, tape rewind)
	# Phase 3: 0->1 reversed (pos goes 80->0, tape rewind)
	assert_approx_vec2(btn.position, Vector2.ZERO,
		"4-phase ping-pong: should end back at base after all 4 phases", 10.0)

	await cleanup(btn)


# =============================================================================
# TESTS: Custom curves
# =============================================================================

func test_custom_curve_in_overrides_easing() -> void:
	# A custom curve that maps all t to 1.0 should snap instantly to target
	var rig := await _create_position_rig("curve_in", Vector2(100, 0), 0.3)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]

	# Create a flat curve at y=1.0 (always returns 1.0)
	var flat_curve := Curve.new()
	flat_curve.add_point(Vector2(0.0, 1.0))
	flat_curve.add_point(Vector2(1.0, 1.0))

	for eff in juice._runtime_effects:
		if eff != null:
			eff.custom_curve_in = flat_curve

	juice.animate_in()
	await wait_frames(3)

	# With a flat curve at 1.0, even at early progress the eased value is 1.0
	# so the position should be at or very near the target immediately
	assert_true(btn.position.x > 80.0,
		"Custom curve (flat@1.0): position (%.1f) should be near 100 almost immediately" % btn.position.x)

	await cleanup(btn)


# =============================================================================
# TESTS: Elastic and Back easing
# =============================================================================

func test_elastic_easing_overshoots() -> void:
	# Elastic EASE_OUT overshoots past target then settles
	var rig := await _create_position_rig("elastic", Vector2(100, 0), 0.5)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]

	for eff in juice._runtime_effects:
		if eff != null:
			eff.transition_in = Tween.TRANS_ELASTIC
			eff.ease_in = Tween.EASE_OUT
			eff.elastic_amplitude_in = 1.0
			eff.elastic_period_in = 0.3

	var max_x := 0.0
	juice.animate_in()
	# Sample position over the animation to detect overshoot
	for i in 20:
		await wait_frames(2)
		if btn.position.x > max_x:
			max_x = btn.position.x

	await wait_seconds(0.3)

	# Elastic EASE_OUT should overshoot past 100 at some point
	assert_true(max_x > 100.0,
		"Elastic EASE_OUT: max position (%.1f) should overshoot past 100" % max_x)
	# But settle near target
	assert_approx_vec2(btn.position, Vector2(100, 0),
		"Elastic EASE_OUT: should settle near target after animation", 5.0)

	await cleanup(btn)


func test_back_easing_overshoots() -> void:
	# Back EASE_OUT overshoots past target then returns
	var rig := await _create_position_rig("back", Vector2(100, 0), 0.3)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]

	for eff in juice._runtime_effects:
		if eff != null:
			eff.transition_in = Tween.TRANS_BACK
			eff.ease_in = Tween.EASE_OUT
			eff.back_overshoot_in = 1.70158

	var max_x := 0.0
	juice.animate_in()
	for i in 15:
		await wait_frames(2)
		if btn.position.x > max_x:
			max_x = btn.position.x

	await wait_seconds(0.3)

	assert_true(max_x > 100.0,
		"Back EASE_OUT: max position (%.1f) should overshoot past 100" % max_x)
	assert_approx_vec2(btn.position, Vector2(100, 0),
		"Back EASE_OUT: should settle near target after animation", 5.0)

	await cleanup(btn)


# =============================================================================
# TESTS: Animate Out easing params
# =============================================================================

func test_custom_curve_out_overrides_easing() -> void:
	# A custom_curve_out flat at 1.0 should snap to From immediately during OUT.
	# PLAY_OUT_ONLY: effect goes from To(100,0) → From(Self=0,0).
	var rig := await _create_position_rig("curve_out", Vector2(100, 0), 0.3,
		JuiceEffectBase.TriggerBehaviour.PLAY_OUT_ONLY, 0.3)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]

	var flat_curve := Curve.new()
	flat_curve.add_point(Vector2(0.0, 1.0))
	flat_curve.add_point(Vector2(1.0, 1.0))

	for eff in juice._runtime_effects:
		if eff != null:
			eff.custom_curve_out = flat_curve

	juice.animate_out()
	await wait_frames(3)

	# Flat curve@1.0 means eased_time=1.0 always → progress snaps to 0.0 → position at base
	assert_true(btn.position.x < 20.0,
		"Custom curve_out (flat@1.0): position (%.1f) should snap near 0 immediately" % btn.position.x)

	await cleanup(btn)


func test_elastic_easing_out_overshoots() -> void:
	# Elastic EASE_OUT on the OUT direction should overshoot past From (base).
	# PLAY_OUT_ONLY: effect goes from To(100,0) → From(Self=0,0).
	var rig := await _create_position_rig("elastic_out", Vector2(100, 0), 0.3,
		JuiceEffectBase.TriggerBehaviour.PLAY_OUT_ONLY, 0.5)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]

	for eff in juice._runtime_effects:
		if eff != null:
			eff.transition_out = Tween.TRANS_ELASTIC
			eff.ease_out = Tween.EASE_OUT
			eff.elastic_amplitude_out = 1.0
			eff.elastic_period_out = 0.3

	var min_x := 999.0
	juice.animate_out()
	for i in 20:
		await wait_frames(2)
		if btn.position.x < min_x:
			min_x = btn.position.x

	await wait_seconds(0.3)

	# Elastic EASE_OUT overshoots past base (goes negative)
	assert_true(min_x < 0.0,
		"Elastic OUT EASE_OUT: min position (%.1f) should overshoot past 0" % min_x)
	# Should settle near base
	assert_approx_vec2(btn.position, Vector2.ZERO,
		"Elastic OUT EASE_OUT: should settle near base after animation", 5.0)

	await cleanup(btn)


func test_back_easing_out_overshoots() -> void:
	# Back EASE_OUT on the OUT direction should overshoot past From (base).
	# PLAY_OUT_ONLY: effect goes from To(100,0) → From(Self=0,0).
	var rig := await _create_position_rig("back_out", Vector2(100, 0), 0.3,
		JuiceEffectBase.TriggerBehaviour.PLAY_OUT_ONLY, 0.3)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]

	for eff in juice._runtime_effects:
		if eff != null:
			eff.transition_out = Tween.TRANS_BACK
			eff.ease_out = Tween.EASE_OUT
			eff.back_overshoot_out = 1.70158

	var min_x := 999.0
	juice.animate_out()
	for i in 15:
		await wait_frames(2)
		if btn.position.x < min_x:
			min_x = btn.position.x

	await wait_seconds(0.3)

	assert_true(min_x < 0.0,
		"Back OUT EASE_OUT: min position (%.1f) should overshoot past 0" % min_x)
	assert_approx_vec2(btn.position, Vector2.ZERO,
		"Back OUT EASE_OUT: should settle near base after animation", 5.0)

	await cleanup(btn)


# =============================================================================
# TESTS: Loop edge cases
# =============================================================================

func test_loop_counter_preserved_during_auto_out() -> void:
	# In PLAY_IN_AND_OUT, the loop counter should NOT increment after the IN phase.
	# It increments only after the full IN+OUT cycle.
	var rig := await _create_position_rig("loop_auto_out", Vector2(100, 0), 0.15,
		JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT, 0.15)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]

	for eff in juice._runtime_effects:
		if eff != null:
			eff.loop_count = 1

	juice.animate_in()

	# Mid-IN phase: effect should be playing, at some positive X
	await wait_seconds(0.08)
	assert_true(juice._is_playing, "Should still be playing during IN phase")

	# After IN completes (~0.15s), auto-reverse starts. Effect still playing.
	await wait_seconds(0.12)  # ~0.2s total
	assert_true(juice._is_playing, "Should still be playing during auto-OUT phase")
	# Position should be heading back toward base
	var pos_during_out := btn.position.x
	assert_true(pos_during_out < 100.0,
		"During auto-OUT, position (%.1f) should be below 100 (heading back)" % pos_during_out)

	# After full IN+OUT cycle (~0.3s): animation should be done
	await wait_seconds(0.25)  # ~0.45s total — generous margin
	assert_false(juice._is_playing, "Should stop after 1 full IN+OUT cycle")
	assert_approx_vec2(btn.position, Vector2.ZERO,
		"After IN+OUT, target should be back at base", 5.0)

	await cleanup(btn)


func test_play_in_and_out_loop_restart() -> void:
	# With loop_count=2 and PLAY_IN_AND_OUT, the effect should play two full
	# IN+OUT cycles, visiting the To position twice.
	var rig := await _create_position_rig("loop_in_out", Vector2(100, 0), 0.15,
		JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT, 0.15)
	var btn: Button = rig[0]
	var juice: JuiceControl = rig[1]

	for eff in juice._runtime_effects:
		if eff != null:
			eff.loop_count = 2

	juice.animate_in()

	# Track how many times the position crosses the 80px threshold (near To)
	var times_near_peak := 0
	var was_near_peak := false
	for i in 40:
		await wait_frames(2)
		var near_peak := btn.position.x > 80.0
		if near_peak and not was_near_peak:
			times_near_peak += 1
		was_near_peak = near_peak

	await wait_seconds(0.3)  # generous margin for completion

	# Should have visited near-peak at least twice (once per cycle)
	assert_true(times_near_peak >= 2,
		"PLAY_IN_AND_OUT loop_count=2: should visit peak %d times (expected >=2)" % times_near_peak)
	# After 2 full cycles, should be back at base
	assert_false(juice._is_playing, "Should stop after 2 full IN+OUT cycles")
	assert_approx_vec2(btn.position, Vector2.ZERO,
		"After 2 IN+OUT cycles, target should be back at base", 5.0)

	await cleanup(btn)


# =============================================================================
# TESTS: Mirror In -> Out
# =============================================================================

func test_mirror_in_to_out_copies_all_params() -> void:
	# _mirror_in_to_out should copy all IN params to OUT with reversed ease
	var effect := TransformControlJuiceEffect.new()
	effect.duration_in = 0.42
	effect.transition_in = Tween.TRANS_ELASTIC
	effect.ease_in = Tween.EASE_IN
	effect.elastic_amplitude_in = 2.5
	effect.elastic_period_in = 0.6
	effect.back_overshoot_in = 3.0

	effect._mirror_in_to_out()

	assert_equal(effect.duration_out, 0.42,
		"Mirror: duration_out should equal duration_in")
	assert_equal(effect.transition_out, Tween.TRANS_ELASTIC,
		"Mirror: transition_out should equal transition_in")
	# EASE_IN -> EASE_OUT (reversed)
	assert_equal(effect.ease_out, Tween.EASE_OUT,
		"Mirror: ease_out should be reversed (EASE_IN -> EASE_OUT)")
	assert_equal(effect.elastic_amplitude_out, 2.5,
		"Mirror: elastic_amplitude_out should equal elastic_amplitude_in")
	assert_equal(effect.elastic_period_out, 0.6,
		"Mirror: elastic_period_out should equal elastic_period_in")
	assert_equal(effect.back_overshoot_out, 3.0,
		"Mirror: back_overshoot_out should equal back_overshoot_in")

	# Also test other ease reversals
	effect.ease_in = Tween.EASE_OUT
	effect._mirror_in_to_out()
	assert_equal(effect.ease_out, Tween.EASE_IN,
		"Mirror: EASE_OUT -> EASE_IN")

	effect.ease_in = Tween.EASE_IN_OUT
	effect._mirror_in_to_out()
	assert_equal(effect.ease_out, Tween.EASE_OUT_IN,
		"Mirror: EASE_IN_OUT -> EASE_OUT_IN")

	effect.ease_in = Tween.EASE_OUT_IN
	effect._mirror_in_to_out()
	assert_equal(effect.ease_out, Tween.EASE_IN_OUT,
		"Mirror: EASE_OUT_IN -> EASE_IN_OUT")


func test_mirror_in_to_out_reverses_custom_curve() -> void:
	# _mirror_in_to_out should time-reverse the custom_curve_in into custom_curve_out
	var effect := TransformControlJuiceEffect.new()

	# Create a curve: starts at (0, 0), goes to (1, 1) — basically linear
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.5, 0.8))
	curve.add_point(Vector2(1.0, 1.0))
	effect.custom_curve_in = curve

	effect._mirror_in_to_out()

	assert_true(effect.custom_curve_out != null,
		"Mirror: custom_curve_out should not be null after mirror")
	assert_equal(effect.custom_curve_out.get_point_count(), 3,
		"Mirror: reversed curve should have same point count")

	# Reversed curve: point at t=0 should have value 1.0 (was t=1.0, y=1.0)
	# Point at t=0.5 should have value 0.8 (was t=0.5, y=0.8)
	# Point at t=1.0 should have value 0.0 (was t=0.0, y=0.0)
	var p0 := effect.custom_curve_out.get_point_position(0)
	var p2 := effect.custom_curve_out.get_point_position(2)
	assert_true(absf(p0.x) < 0.01 and absf(p0.y - 1.0) < 0.01,
		"Mirror curve: first point should be near (0, 1), got (%.2f, %.2f)" % [p0.x, p0.y])
	assert_true(absf(p2.x - 1.0) < 0.01 and absf(p2.y) < 0.01,
		"Mirror curve: last point should be near (1, 0), got (%.2f, %.2f)" % [p2.x, p2.y])

	# Null custom_curve_in should result in null custom_curve_out
	effect.custom_curve_in = null
	effect._mirror_in_to_out()
	assert_true(effect.custom_curve_out == null,
		"Mirror: null custom_curve_in should produce null custom_curve_out")


# =============================================================================
# TESTS: Auto-connect integration
# =============================================================================

func test_autoconnect_button_pressed() -> void:
	# JuiceControl with auto_connect + trigger_on=ON_PRESS on a Button
	var btn := Button.new()
	btn.text = "autoconnect_press"
	btn.custom_minimum_size = Vector2(120, 40)
	btn.position = Vector2.ZERO
	_runner.add_child(btn)

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(50, 0)
	effect.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.15

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.ON_PRESS
	juice.auto_connect_parent = true
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	btn.add_child(juice)
	await wait_frames(3)

	# ON_PRESS auto-connects to button_down (not "pressed")
	btn.emit_signal("button_down")
	await wait_seconds(0.3)

	assert_true(btn.position.x > 30.0,
		"Auto-connect ON_PRESS: button emission should trigger animation (pos.x=%.1f)" % btn.position.x)

	await cleanup(btn)


func test_autoconnect_control_hover() -> void:
	# Non-button Control with ON_HOVER_START: mouse_entered triggers animation
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(120, 40)
	panel.position = Vector2.ZERO
	_runner.add_child(panel)

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(50, 0)
	effect.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.15

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.ON_HOVER_START
	juice.auto_connect_parent = true
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	panel.add_child(juice)
	await wait_frames(3)

	# Emit mouse_entered on the Panel (non-button Control)
	panel.emit_signal("mouse_entered")
	await wait_seconds(0.3)

	assert_true(panel.position.x > 30.0,
		"Auto-connect ON_HOVER_START (Control): mouse_entered should trigger animation (pos.x=%.1f)" % panel.position.x)

	await cleanup(panel)


func test_autoconnect_control_focus() -> void:
	# Non-button Control with ON_FOCUS: focus_entered triggers animation
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(120, 40)
	panel.position = Vector2.ZERO
	panel.focus_mode = Control.FOCUS_ALL
	_runner.add_child(panel)

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(50, 0)
	effect.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.15

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.ON_FOCUS
	juice.auto_connect_parent = true
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	panel.add_child(juice)
	await wait_frames(3)

	# Emit focus_entered on the Panel
	panel.emit_signal("focus_entered")
	await wait_seconds(0.3)

	assert_true(panel.position.x > 30.0,
		"Auto-connect ON_FOCUS (Control): focus_entered should trigger animation (pos.x=%.1f)" % panel.position.x)

	await cleanup(panel)


func test_autoconnect_control_gui_input_press() -> void:
	# Non-button Control with ON_PRESS: gui_input with mouse press triggers animation
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(120, 40)
	panel.position = Vector2.ZERO
	_runner.add_child(panel)

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(50, 0)
	effect.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.15

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.ON_PRESS
	juice.auto_connect_parent = true
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	panel.add_child(juice)
	await wait_frames(3)

	# Emit gui_input with a mouse button press event
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	panel.emit_signal("gui_input", event)
	await wait_seconds(0.3)

	assert_true(panel.position.x > 30.0,
		"Auto-connect ON_PRESS (Control): gui_input mouse press should trigger animation (pos.x=%.1f)" % panel.position.x)

	await cleanup(panel)


func test_autoconnect_animation_player() -> void:
	# AnimationPlayer as trigger source: animation_finished triggers Juice animation
	var btn := Button.new()
	btn.text = "anim_trigger"
	btn.custom_minimum_size = Vector2(120, 40)
	btn.position = Vector2.ZERO
	_runner.add_child(btn)

	# Create an AnimationPlayer sibling
	var anim_player := AnimationPlayer.new()
	anim_player.name = "TestAnimPlayer"
	btn.add_child(anim_player)

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(60, 0)
	effect.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.15

	var juice := JuiceControl.new()
	# Use NODE trigger source pointing at the AnimationPlayer
	juice.trigger_source = JuiceBase.TriggerSource.NODE
	juice.trigger_source_path = NodePath("../TestAnimPlayer")
	juice.trigger_on = JuiceBase.TriggerEvent.ON_PRESS  # any non-MANUAL event
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	btn.add_child(juice)
	await wait_frames(3)

	# Emit animation_finished signal (simulating an animation completing)
	anim_player.emit_signal("animation_finished", &"test_anim")
	await wait_seconds(0.3)

	assert_true(btn.position.x > 30.0,
		"Auto-connect AnimationPlayer: animation_finished should trigger Juice (pos.x=%.1f)" % btn.position.x)

	await cleanup(btn)


func test_autoconnect_visibility_on_show() -> void:
	# JuiceControl with trigger_on=ON_SHOW — animation fires when target becomes visible
	var btn := Button.new()
	btn.text = "autoconnect_show"
	btn.custom_minimum_size = Vector2(120, 40)
	btn.position = Vector2.ZERO
	btn.visible = false
	_runner.add_child(btn)

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(60, 0)
	effect.to_position_in = TransformControlJuiceEffect.PositionIn.PIXELS
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.15

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.ON_SHOW
	juice.auto_connect_parent = true
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	btn.add_child(juice)
	await wait_frames(3)

	# Make visible — should trigger ON_SHOW
	btn.visible = true
	await wait_seconds(0.3)

	assert_true(btn.position.x > 40.0,
		"Auto-connect ON_SHOW: making visible should trigger animation (pos.x=%.1f)" % btn.position.x)

	await cleanup(btn)
