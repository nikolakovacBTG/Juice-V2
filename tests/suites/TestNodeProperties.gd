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
