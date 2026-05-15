## Phase 6.5 tests for ProgressPropertyJuiceEffectBase.
##
## Validates that the effect accumulates a property at a configured rate
## (value += rate * delta * progress * direction), routes through JuiceLedger,
## and that hold_on_stop controls whether accumulated state is preserved or
## reset when the effect stops.

# ============================================================================
# WHAT: Automated tests for the ProgressProperty effect family.
# WHY:  Confirms that ProgressPropertyJuiceEffectBase is a rate accumulator
#       (not a lerp), routes deltas through JuiceLedger, and that the bound
#       system and hold_on_stop behave correctly.
# SYSTEM: Tests (tests/suites/)
# ============================================================================

extends JuiceTestSuite


func get_suite_name() -> String:
	return "progress_property_v2"


func get_test_methods() -> Array[String]:
	return [
		"test_float_property_accumulates_at_rate",
		"test_hold_on_stop_true_preserves_accumulated",
		"test_hold_on_stop_false_resets_on_stop",
		"test_reverse_bound_flips_direction",
	]


# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------

# Builds a ProgressProperty2DJuiceEffect for a float property.
# Sets _current_delta manually so accumulation is deterministic in headless tests.
func _make_float_effect(prop: String, rate: float) -> ProgressProperty2DJuiceEffect:
	var effect := ProgressProperty2DJuiceEffect.new()
	effect.property_path = prop
	effect.property_type = ProgressPropertyJuiceEffectBase.PropertyType.FLOAT
	effect.float_rate = rate
	effect.hold_on_stop = true
	return effect


# Drives one accumulation step with a fixed delta and progress.
# _current_delta is set directly because there is no process() loop in tests.
func _drive_one_step(effect: ProgressPropertyJuiceEffectBase, target: Node,
		delta: float, progress: float) -> void:
	effect._on_animate_start(target)
	effect._current_delta = delta
	effect._apply_effect(progress, target)
	JuiceLedger.flush(target)


# ---------------------------------------------------------------------------
# TESTS
# ---------------------------------------------------------------------------

## float_rate=10, delta=0.5, progress=1.0 → accumulated = 10 * 0.5 * 1.0 = 5.0.
## Base rotation=0.0, so node.rotation should equal 5.0 after flush.
func test_float_property_accumulates_at_rate() -> void:
	var target := create_2d_target()
	target.rotation = 0.0
	var effect := _make_float_effect("rotation", 10.0)
	_drive_one_step(effect, target, 0.5, 1.0)
	assert_approx_float(target.rotation, 5.0,
		"rotation should be ~5.0 after rate=10, delta=0.5, progress=1.0 (got %.4f)" % target.rotation,
		0.001)
	JuiceLedger.cleanup_source(target, effect, true)
	await cleanup(target)


## With hold_on_stop=true, stopping does not reset accumulated.
## Drive to 5.0, call _restore_to_natural, then re-drive without resetting.
## Re-drive should add on top of the preserved 5.0, reaching ~10.0.
func test_hold_on_stop_true_preserves_accumulated() -> void:
	var target := create_2d_target()
	target.rotation = 0.0
	var effect := _make_float_effect("rotation", 10.0)
	effect.hold_on_stop = true
	# First drive: accumulated = 5.0
	_drive_one_step(effect, target, 0.5, 1.0)
	assert_approx_float(target.rotation, 5.0,
		"rotation should be 5.0 after first drive (got %.4f)" % target.rotation, 0.001)
	# Stop — hold_on_stop=true keeps _accumulated_float=5.0
	effect._restore_to_natural(target)
	JuiceLedger.flush(target)
	# Second drive: accumulated grows from 5.0 → 10.0
	_drive_one_step(effect, target, 0.5, 1.0)
	assert_approx_float(target.rotation, 10.0,
		"rotation should be 10.0 after second drive (hold preserved, got %.4f)" % target.rotation,
		0.001)
	JuiceLedger.cleanup_source(target, effect, true)
	await cleanup(target)


## With hold_on_stop=false, stopping resets accumulated to 0.
## Drive to 5.0, stop, verify property returns to base (0.0).
## Then re-drive from zero; should reach 5.0 again.
func test_hold_on_stop_false_resets_on_stop() -> void:
	var target := create_2d_target()
	target.rotation = 0.0
	var effect := _make_float_effect("rotation", 10.0)
	effect.hold_on_stop = false
	# Drive to 5.0
	_drive_one_step(effect, target, 0.5, 1.0)
	assert_approx_float(target.rotation, 5.0,
		"rotation should be 5.0 after drive (got %.4f)" % target.rotation, 0.001)
	# Stop — hold_on_stop=false resets accumulated and removes Ledger delta
	effect._restore_to_natural(target)
	JuiceLedger.flush(target)
	assert_approx_float(target.rotation, 0.0,
		"rotation should return to 0.0 after stop with hold_on_stop=false (got %.4f)" % target.rotation,
		0.001)
	JuiceLedger.cleanup_source(target, effect, true)
	await cleanup(target)


## REVERSE bound: after accumulated >= bound_value, direction flips.
## float_rate=10, delta=0.1, progress=1.0 → accumulated = 1.0 = bound_value.
## Bound fires, direction flips to -1.0. Next step: accumulated -= 10*0.1 = 0.0.
func test_reverse_bound_flips_direction() -> void:
	var target := create_2d_target()
	target.rotation = 0.0
	var effect := _make_float_effect("rotation", 10.0)
	effect.bound_enabled = true
	effect.bound_value = 1.0
	effect.bound_behaviour = ProgressPropertyJuiceEffectBase.BoundBehaviour.REVERSE

	# Step 1: accumulate to bound (10 * 0.1 * 1.0 = 1.0 → bound fires → direction=-1)
	effect._on_animate_start(target)
	effect._current_delta = 0.1
	effect._apply_effect(1.0, target)
	JuiceLedger.flush(target)
	assert_approx_float(target.rotation, 1.0,
		"rotation should be clamped to bound 1.0 (got %.4f)" % target.rotation, 0.001)
	assert_approx_float(effect._current_direction, -1.0,
		"direction should flip to -1.0 after REVERSE bound (got %.4f)" % effect._current_direction,
		0.001)

	# Step 2: accumulate in reverse (1.0 + 10*0.1*(-1) = 0.0)
	effect._current_delta = 0.1
	effect._apply_effect(1.0, target)
	JuiceLedger.flush(target)
	assert_approx_float(target.rotation, 0.0,
		"rotation should be ~0.0 after one reverse step (got %.4f)" % target.rotation, 0.01)

	JuiceLedger.cleanup_source(target, effect, true)
	await cleanup(target)
