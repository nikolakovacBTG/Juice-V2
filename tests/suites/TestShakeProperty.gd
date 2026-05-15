## Phase 6.4 tests for PropertyShakeJuiceEffectBase and domain leaf nodes.
##
## Validates that sine-blend shake displacement is applied via the JuiceLedger
## (not direct write), that the property returns to its natural base after the
## effect stops, and that the Color channel path produces a measurable delta.

# ============================================================================
# WHAT: Automated tests for the ShakeProperty effect family.
# WHY:  Confirms that PropertyShakeJuiceEffectBase routes shake deltas through
#       JuiceLedger and that _restore_to_natural() returns the property to its
#       captured base — same invariants as all other Property-family effects.
# SYSTEM: Tests (tests/suites/)
# ============================================================================

extends JuiceTestSuite


func get_suite_name() -> String:
	return "shake_property_v2"


func get_test_methods() -> Array[String]:
	return [
		"test_shake_property_displaces_float_at_peak",
		"test_shake_property_restores_base_after_stop",
		"test_shake_color_property_displaces_at_peak",
	]


# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------

# Builds a PropertyShake2DJuiceEffect targeting a float property.
# randomness=0.0 → pure sine, no per-frame random jitter.
# _shake_seed is overridden to 0.0 after _on_animate_start so the sine value
# at _shake_time=0.25, freq=1.0 is sin(π/2) = 1.0 — exactly predictable.
func _make_float_effect(prop: String, amplitude: float) -> PropertyShake2DJuiceEffect:
	var effect := PropertyShake2DJuiceEffect.new()
	effect.shake_frequency = 1.0   # 1 cycle/sec — at time=0.25: sin(π/2)=1.0
	effect.randomness = 0.0        # Pure sine, no random component

	var slot := ShakePropertyTarget.new()
	slot.property_path = prop
	slot._detected_type = TYPE_FLOAT
	slot.amplitude_float = amplitude
	effect.property_targets.append(slot)
	return effect


# Builds a PropertyShakeControlJuiceEffect targeting a Color property.
# Same deterministic config as float — randomness=0.0, freq=1.0.
func _make_color_effect(prop: String, amplitude: float) -> PropertyShakeControlJuiceEffect:
	var effect := PropertyShakeControlJuiceEffect.new()
	effect.shake_frequency = 1.0
	effect.randomness = 0.0

	var slot := ShakePropertyTarget.new()
	slot.property_path = prop
	slot._detected_type = TYPE_COLOR
	slot.amplitude_color = amplitude
	effect.property_targets.append(slot)
	return effect


# Drives effect through one apply cycle with deterministic shake time.
# Sets _shake_seed=0.0 and _shake_time=0.25 after _on_animate_start so
# _sample_shake(0.0) = sin(0.25 * 1.0 * TAU + 0.0 + 0.0) = sin(π/2) = 1.0.
# _apply_effect advances time by _current_delta (0.0 in tests) — time stays put.
func _drive_shake(effect: PropertyShakeJuiceEffectBase, target: Node) -> void:
	effect._on_animate_start(target)
	# Override seed AFTER _on_animate_start (which randomises it)
	effect._shake_seed = 0.0
	effect._shake_time = 0.25
	effect._apply_effect(1.0, target)
	JuiceLedger.flush(target)


# ---------------------------------------------------------------------------
# TESTS
# ---------------------------------------------------------------------------

## A float property is displaced from its base while the effect is playing.
## At _shake_time=0.25, freq=1.0, seed=0.0, randomness=0.0:
##   sin(0.25 * 2π + 0) = sin(π/2) = 1.0 → delta = amplitude * 1.0 * progress = 5.0.
## With base rotation = 0.0, result should be ~5.0 (allowing minor float precision error).
func test_shake_property_displaces_float_at_peak() -> void:
	var target := create_2d_target()
	target.rotation = 0.0
	var effect := _make_float_effect("rotation", 5.0)
	_drive_shake(effect, target)
	assert_approx_float(target.rotation, 5.0,
		"rotation should be ~5.0 at sine peak (got %.4f)" % target.rotation, 0.01)
	JuiceLedger.cleanup_source(target, effect, true)
	await cleanup(target)


## After _restore_to_natural(), the float property returns to its captured base.
func test_shake_property_restores_base_after_stop() -> void:
	var target := create_2d_target()
	target.rotation = 2.5
	var effect := _make_float_effect("rotation", 5.0)
	_drive_shake(effect, target)
	# Confirm displacement happened first
	assert_greater(target.rotation, 2.5,
		"rotation should be > 2.5 while effect is active (got %.4f)" % target.rotation)
	# Stop: restores base via Ledger
	effect._restore_to_natural(target)
	JuiceLedger.flush(target)
	assert_approx_float(target.rotation, 2.5,
		"rotation should restore to 2.5 after stop", 0.001)
	JuiceLedger.cleanup_source(target, effect, true)
	await cleanup(target)


## A Color property receives an additive shake delta.
## At the sine peak (time=0.25, freq=1.0, seed=0.0, randomness=0.0):
##   shake_delta per channel = amplitude_color * 1.0 * progress = 0.3 * 1.0 * 1.0 = 0.3.
## With base modulate = Color(0.5, 0.5, 0.5, 1.0), result.r should be ~0.8.
func test_shake_color_property_displaces_at_peak() -> void:
	var target := create_control_target("TestBtn")
	target.modulate = Color(0.5, 0.5, 0.5, 1.0)
	var effect := _make_color_effect("modulate", 0.3)
	_drive_shake(effect, target)
	assert_greater(target.modulate.r, 0.5,
		"modulate.r should be > 0.5 after shake displacement (got %.4f)" % target.modulate.r)
	JuiceLedger.cleanup_source(target, effect, true)
	await cleanup(target)
