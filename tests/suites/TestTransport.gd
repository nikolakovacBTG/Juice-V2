## TestTransport.gd
## ============================================================================
## WHAT: Tests for the Juice Editor Transport system (JuicePreviewDirector +
##       JuiceBase preview API).
## WHY:  Verify that editor preview lifecycle, scrubbing, loop guard, stale-recipe
##       detection, and progress-effect detection work correctly without requiring
##       a live editor session.
## SYSTEM: Tests (tests/suites/)
## DOES NOT: Test UI button layout or editor selection signals (editor-only, manual).
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "transport"


func get_test_methods() -> Array[String]:
	return [
		"test_enter_exit_preview_lifecycle",
		"test_supports_editor_preview_with_recipe",
		"test_supports_editor_preview_without_recipe",
		"test_enter_preview_clones_runtime_effects",
		"test_exit_preview_clears_preview_flag",
		"test_scrub_to_time_moves_target",
		"test_director_select_state",
		"test_director_deselect_clears_state",
		"test_director_loop_off_stops_at_end",
		"test_director_has_sustained_effects_false",
		"test_director_has_sustained_effects_true",
		"test_director_stale_recipe_detection",
		"test_director_scrubbable_stack_mode",
		"test_director_not_scrubbable_sequencer_random",
		"test_get_total_preview_duration",
		"test_sequencer_replay_after_stop",
		"test_sequencer_replay_after_completion",
		"test_sequencer_loop_animates_each_iteration",
	]


# =============================================================================
# HELPERS: Build minimal rigs for transport testing
# =============================================================================

# Build a Juice2D rig with one Transform2DJuiceEffect.
# Returns [target, juice2d, effect, recipe].
func _build_2d_rig(duration: float = 0.3) -> Array:
	var target := Node2D.new()
	target.position = Vector2.ZERO
	_runner.add_child(target)

	var effect := Transform2DJuiceEffect.new()
	effect.transform_target = Transform2DJuiceEffect.TransformTarget.POSITION
	effect.from_reference = Transform2DJuiceEffect.TransformReference.SELF
	effect.to_reference = Transform2DJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(80.0, 0.0)
	effect.to_position_in = Transform2DJuiceEffect.PositionIn.PIXELS
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = duration

	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)
	return [target, juice, effect, recipe]


# Build a JuicePreviewDirector parented to the runner (simulates plugin).
func _build_director() -> JuicePreviewDirector:
	var director := JuicePreviewDirector.new()
	director.debug_enabled = false
	_runner.add_child(director)
	await wait_frames(1)
	return director


# Build a Juice2D rig that has a Noise2DJuiceEffect (a sustained-family effect).
# has_sustained_effects() checks _needs_sustain() — this covers Noise, Shake,
# Progress, and Camera families, not just Progress. Using Noise here proves the
# detection is not Progress-specific.
func _build_sustained_rig() -> Array:
	var target := Node2D.new()
	target.position = Vector2.ZERO
	_runner.add_child(target)

	var effect := Noise2DJuiceEffect.new()
	effect.transform_target = Noise2DJuiceEffect.TransformTarget.POSITION
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_in = 0.3

	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)
	return [target, juice, effect, recipe]


# =============================================================================
# TESTS: JuiceBase Preview API
# =============================================================================

func test_enter_exit_preview_lifecycle() -> void:
	var rig := await _build_2d_rig()
	var juice: Juice2D = rig[1]

	assert_false(juice._editor_preview_active,
		"Transport lifecycle: _editor_preview_active should be false before enter")

	juice._enter_editor_preview()
	assert_true(juice._editor_preview_active,
		"Transport lifecycle: _editor_preview_active should be true after enter")

	juice._exit_editor_preview()
	assert_false(juice._editor_preview_active,
		"Transport lifecycle: _editor_preview_active should be false after exit")

	await cleanup(rig[0])


func test_supports_editor_preview_with_recipe() -> void:
	var rig := await _build_2d_rig()
	var juice: Juice2D = rig[1]

	assert_true(juice._supports_editor_preview(),
		"Supports preview: should be true when recipe has effects")

	await cleanup(rig[0])


func test_supports_editor_preview_without_recipe() -> void:
	var target := Node2D.new()
	_runner.add_child(target)
	var juice := Juice2D.new()
	juice.recipe = null
	target.add_child(juice)
	await wait_frames(2)

	assert_false(juice._supports_editor_preview(),
		"Supports preview: should be false when recipe is null")

	await cleanup(target)


func test_enter_preview_clones_runtime_effects() -> void:
	var rig := await _build_2d_rig()
	var juice: Juice2D = rig[1]

	# Runtime effects are empty before entering preview (no _ready in editor mode)
	# _enter_editor_preview must call _invalidate_runtime_effects()
	juice._enter_editor_preview()

	assert_true(juice._runtime_effects.size() > 0,
		"Enter preview: runtime effects should be cloned (count=%d)" % juice._runtime_effects.size())

	juice._exit_editor_preview()
	await cleanup(rig[0])


func test_exit_preview_clears_preview_flag() -> void:
	var rig := await _build_2d_rig()
	var juice: Juice2D = rig[1]

	juice._enter_editor_preview()
	juice._exit_editor_preview()

	assert_false(juice._editor_preview_active,
		"Exit preview: flag must be false so _process is blocked again")

	await cleanup(rig[0])


func test_scrub_to_time_moves_target() -> void:
	var rig := await _build_2d_rig(1.0)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice._enter_editor_preview()
	# Scrub halfway through a 1s animation
	juice.scrub_to_time(0.5)
	await wait_frames(2)

	# At t=0.5 with LINEAR easing, position should be ~40px (half of 80)
	assert_greater(target.position.x, 10.0,
		"Scrub to time: node should have a non-zero position at t=0.5 (x=%.2f)" % target.position.x)

	juice._exit_editor_preview()
	await cleanup(target)


func test_get_total_preview_duration() -> void:
	var rig := await _build_2d_rig(0.5)
	var juice: Juice2D = rig[1]

	juice._enter_editor_preview()
	var duration := juice.get_total_preview_duration()

	assert_greater(duration, 0.0,
		"Total preview duration: should be > 0 (got %.2f)" % duration)

	juice._exit_editor_preview()
	await cleanup(rig[0])


# =============================================================================
# TESTS: JuicePreviewDirector state machine
# =============================================================================

func test_director_select_state() -> void:
	var director := await _build_director()
	var rig := await _build_2d_rig()
	var juice: Juice2D = rig[1]

	director.select(juice)

	assert_true(director.can_play(),
		"Director select: can_play should be true after valid selection")
	assert_equal(director.get_primary_node(), juice,
		"Director select: primary node should match the selected juice node")

	director.deselect()
	await cleanup(rig[0])
	await cleanup(director)


func test_director_deselect_clears_state() -> void:
	var director := await _build_director()
	var rig := await _build_2d_rig()
	var juice: Juice2D = rig[1]

	director.select(juice)
	director.deselect()

	assert_false(director.can_play(),
		"Director deselect: can_play should be false after deselect")
	assert_equal(director.get_primary_node(), null,
		"Director deselect: primary node should be null")

	await cleanup(rig[0])
	await cleanup(director)


func test_director_loop_off_stops_at_end() -> void:
	var director := await _build_director()
	var rig := await _build_2d_rig(0.15)
	var juice: Juice2D = rig[1]

	director.select(juice)
	director.set_loop_enabled(false)

	assert_false(director.loop_enabled,
		"Director loop OFF: loop_enabled should be false")

	# Wait one frame: select() schedules _deferred_editor_preview_init() async.
	# Without this, the PREVIEW orch has empty runtime_effects when play() runs
	# and _start_effects() returns early — leaving director.is_playing permanently true.
	await wait_frames(1)

	# Play, let it complete
	director.play()
	await wait_seconds(0.4)

	# After completion, director should have stopped itself
	assert_false(director.is_playing,
		"Director loop OFF: is_playing should be false after animation completes")

	director.deselect()
	await cleanup(rig[0])
	await cleanup(director)


func test_director_has_sustained_effects_false() -> void:
	var director := await _build_director()
	var rig := await _build_2d_rig()
	var juice: Juice2D = rig[1]

	director.select(juice)

	assert_false(director.has_sustained_effects(),
		"has_sustained_effects: should be false for a standard Transform effect (no _needs_sustain)")

	director.deselect()
	await cleanup(rig[0])
	await cleanup(director)


func test_director_has_sustained_effects_true() -> void:
	var director := await _build_director()
	var rig := await _build_sustained_rig()
	var juice: Juice2D = rig[1]

	director.select(juice)

	assert_true(director.has_sustained_effects(),
		"has_sustained_effects: should be true for Noise2DJuiceEffect (sustained family)")

	director.deselect()
	await cleanup(rig[0])
	await cleanup(director)


func test_director_stale_recipe_detection() -> void:
	var director := await _build_director()
	var rig := await _build_2d_rig()
	var juice: Juice2D = rig[1]
	var recipe: Juice2DRecipe = rig[3]

	director.select(juice)
	assert_equal(director._recipe_effects_count, 1,
		"Stale recipe: initial snapshot should be 1 effect")

	# Remove the effect — simulates user removing it from inspector
	recipe.effects.clear()

	# Director detects this in _process, but we can verify the snapshot directly
	# by checking the current recipe state
	assert_equal(recipe.effects.size(), 0,
		"Stale recipe: recipe now has 0 effects")
	assert_equal(director._recipe_effects_count, 1,
		"Stale recipe: snapshot still shows 1 (will refresh on next _process tick)")

	director.deselect()
	await cleanup(rig[0])
	await cleanup(director)


func test_director_scrubbable_stack_mode() -> void:
	var director := await _build_director()
	var rig := await _build_2d_rig()
	var juice: Juice2D = rig[1]

	# Default mode is STACK
	director.select(juice)

	assert_true(director.is_scrubbable,
		"Scrubbable: STACK mode should always be scrubbable")

	director.deselect()
	await cleanup(rig[0])
	await cleanup(director)


func test_director_not_scrubbable_sequencer_random() -> void:
	var director := await _build_director()

	var target := Node2D.new()
	_runner.add_child(target)

	var effect := Transform2DJuiceEffect.new()
	effect.transform_target = Transform2DJuiceEffect.TransformTarget.POSITION
	effect.from_reference = Transform2DJuiceEffect.TransformReference.SELF
	effect.to_reference = Transform2DJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(50.0, 0.0)
	effect.to_position_in = Transform2DJuiceEffect.PositionIn.PIXELS
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.mode = JuiceBase.Mode.SEQUENCER
	juice.sequence_type = JuiceBase.SequenceType.RANDOM
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	director.select(juice)

	assert_false(director.is_scrubbable,
		"Scrubbable: SEQUENCER RANDOM should NOT be scrubbable")

	director.deselect()
	await cleanup(target)
	await cleanup(director)


# =============================================================================
# TESTS: Sequencer replay — regression for _seq_target_effects stale-cache bug
# =============================================================================

# Builds a Juice2D SEQUENCER with one Node2D sibling as target.
# Returns [parent, juice_sequencer, target_node].
func _build_sequencer_rig(duration: float = 0.25) -> Array:
	var parent := Node2D.new()
	_runner.add_child(parent)

	var target := Node2D.new()
	target.position = Vector2.ZERO
	parent.add_child(target)

	var effect := Transform2DJuiceEffect.new()
	effect.transform_target = Transform2DJuiceEffect.TransformTarget.POSITION
	effect.from_reference = Transform2DJuiceEffect.TransformReference.SELF
	effect.to_reference = Transform2DJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(100.0, 0.0)
	effect.to_position_in = Transform2DJuiceEffect.PositionIn.PIXELS
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = duration

	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.mode = JuiceBase.Mode.SEQUENCER
	juice.juice_source = JuiceBase.JuiceSource.RECIPE
	juice.target_scope = JuiceBase.TargetScope.SIBLINGS
	juice.recipe = recipe
	parent.add_child(juice)

	await wait_frames(2)
	return [parent, juice, target]


## Regression: stop-then-replay must animate, not teleport.
## Root cause: _seq_stop() did not clear _seq_target_effects.
## Stale clones had _has_base=true → _on_animate_start skipped re-capture
## → FROM reference pointed at post-animation position → instant snap.
func test_sequencer_replay_after_stop() -> void:
	var rig := await _build_sequencer_rig(0.2)
	var parent: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	var target: Node2D = rig[2]

	juice._enter_editor_preview()

	# First play: let it run partway then stop mid-animation
	juice.animate_in()
	await wait_seconds(0.1)
	juice.stop()
	await wait_frames(2)

	# Reset target to natural
	target.position = Vector2.ZERO
	await wait_frames(2)

	# Second play: must animate (not teleport to ~100 in first frame)
	juice.animate_in()
	await wait_frames(3)
	var early_pos := target.position.x

	assert_greater(early_pos, 0.0,
		"Replay after stop: target must have started moving (early_pos=%.2f)" % early_pos)

	await wait_seconds(0.3)
	assert_greater(target.position.x, 50.0,
		"Replay after stop: animation must complete (pos=%.2f, expect ~100)" % target.position.x)

	juice._exit_editor_preview()
	await cleanup(parent)


## Regression: natural-completion-then-replay must animate, not teleport.
## Root cause: _seq_on_pass_complete did not clear _seq_target_effects.
func test_sequencer_replay_after_completion() -> void:
	var rig := await _build_sequencer_rig(0.15)
	var parent: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	var target: Node2D = rig[2]

	juice._enter_editor_preview()

	# First play: let it complete naturally
	juice.animate_in()
	await wait_seconds(0.4)

	# Reset target to natural
	target.position = Vector2.ZERO
	await wait_frames(2)

	# Second play: must animate
	juice.animate_in()
	await wait_frames(3)
	var early_pos := target.position.x

	assert_greater(early_pos, 0.0,
		"Replay after completion: target must have started moving (early_pos=%.2f)" % early_pos)

	await wait_seconds(0.3)
	assert_greater(target.position.x, 50.0,
		"Replay after completion: animation must complete (pos=%.2f, expect ~100)" % target.position.x)

	juice._exit_editor_preview()
	await cleanup(parent)


## Regression: sequencer with loop_count=-1 must animate on each iteration, not teleport.
## Loop path: _seq_on_pass_complete loops back via _seq_start_sequence() and never
## reaches the "Sequence fully complete" block — so _seq_target_effects is never cleared
## mid-session (by design). The cached effects must still produce correct animation
## because _seq_restore_target_natural() restores the target to natural before each
## start() call, so the cached FROM (captured at natural position) remains valid.
func test_sequencer_loop_animates_each_iteration() -> void:
	var duration := 0.2
	var rig := await _build_sequencer_rig(duration)
	var parent: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	var target: Node2D = rig[2]

	juice._enter_editor_preview()
	juice.loop_count = -1  # Simulate Transport loop_enabled = true

	juice.animate_in()

	# Iter1 runs from t=0 to t≈duration. Sample at t = 1.5*duration (midpoint of iter2).
	# Teleporting would put target at 100 before we sample; correct animation puts it ~50.
	await wait_seconds(duration * 1.5)
	var iter2_mid_pos := target.position.x

	assert_greater(iter2_mid_pos, 1.0,
		"Loop iter2: target must have left natural pos (pos=%.2f)" % iter2_mid_pos)
	assert_true(iter2_mid_pos < 95.0,
		"Loop iter2: target must be MID-ANIMATION, not teleported (pos=%.2f, must be < 95)" % iter2_mid_pos)

	# Sample at t = 2.5*duration (midpoint of iter3).
	await wait_seconds(duration)
	var iter3_mid_pos := target.position.x

	assert_greater(iter3_mid_pos, 1.0,
		"Loop iter3: target must have left natural pos (pos=%.2f)" % iter3_mid_pos)
	assert_true(iter3_mid_pos < 95.0,
		"Loop iter3: target must be MID-ANIMATION, not teleported (pos=%.2f, must be < 95)" % iter3_mid_pos)

	juice.loop_count = 1
	juice.stop()
	await wait_frames(2)

	juice._exit_editor_preview()
	await cleanup(parent)
