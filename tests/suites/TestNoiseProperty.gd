## Phase 6.3 tests for NoisePropertyJuiceEffectBase and domain leaf nodes.
##
## Validates that noise displacement is applied via the JuiceLedger (not direct
## write), that the property returns to its natural base after the effect stops,
## and that the Color channel path produces a measurable displacement.

# ============================================================================
# WHAT: Automated tests for the NoiseProperty effect family.
# WHY:  Confirms that NoisePropertyJuiceEffectBase routes noise deltas through
#       JuiceLedger and that _restore_to_natural() returns the property to its
#       captured base — same invariants as all other Property-family effects.
# SYSTEM: Tests (tests/suites/)
# ============================================================================

extends JuiceTestSuite


func get_suite_name() -> String:
	return "noise_property_v2"


func get_test_methods() -> Array[String]:
	return [
		"test_noise_property_displaces_float_at_peak",
		"test_noise_property_restores_base_after_stop",
		"test_noise_color_property_displaces_at_peak",
	]


# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------

# Builds a NoiseProperty2DJuiceEffect targeting a float property.
# Uses POSITIVE_ONLY + fixed seed so the sample at _noise_time=0.1 is deterministic
# and guaranteed > 0 (absf of noise output).
func _make_float_effect(prop: String, amplitude: float) -> NoiseProperty2DJuiceEffect:
	var effect := NoiseProperty2DJuiceEffect.new()
	effect.noise_seed = 42           # Fixed seed — deterministic output
	effect.noise_speed = 10.0        # Fast advance: t = 0.1 * 10 = 1.0 — non-zero region
	effect.noise_direction = NoisePropertyJuiceEffectBase.NoiseDirection.POSITIVE_ONLY
	effect.clamp_min = 0.0
	effect.clamp_max = 1.0

	var slot := NoisePropertyTarget.new()
	slot.property_path = prop
	slot._detected_type = TYPE_FLOAT
	slot.amplitude_float = amplitude
	effect.property_targets.append(slot)
	return effect


# Builds a NoisePropertyControlJuiceEffect targeting a Color property.
func _make_color_effect(prop: String, amplitude: float) -> NoisePropertyControlJuiceEffect:
	var effect := NoisePropertyControlJuiceEffect.new()
	effect.noise_seed = 7
	effect.noise_speed = 10.0
	effect.noise_direction = NoisePropertyJuiceEffectBase.NoiseDirection.POSITIVE_ONLY
	effect.clamp_min = 0.0
	effect.clamp_max = 1.0

	var slot := NoisePropertyTarget.new()
	slot.property_path = prop
	slot._detected_type = TYPE_COLOR
	slot.amplitude_color = amplitude
	effect.property_targets.append(slot)
	return effect


# Drives effect: capture → set noise_time (bypass _advance guard for headless tests)
# → apply at peak → flush.
func _drive_noise(effect: NoisePropertyJuiceEffectBase, target: Node, noise_time: float = 0.1) -> void:
	effect._on_animate_start(target)
	# _advance_noise_time() is guarded by _target_progress > 0.0 — set it manually
	# so the noise generator samples a non-zero point in the noise field.
	effect._noise_time = noise_time
	effect._apply_effect(1.0, target)
	JuiceLedger.flush(target)


# ---------------------------------------------------------------------------
# TESTS
# ---------------------------------------------------------------------------

## A float property is displaced from its base while the effect is playing.
## Uses rotation (base=0.0) with amplitude=5.0 and POSITIVE_ONLY noise —
## the result must be > 0 at _noise_time=0.1 (guaranteed non-zero region).
func test_noise_property_displaces_float_at_peak() -> void:
	var target := create_2d_target()
	target.rotation = 0.0
	var effect := _make_float_effect("rotation", 5.0)
	_drive_noise(effect, target)
	assert_greater(target.rotation, 0.0,
		"rotation should be > 0.0 after POSITIVE_ONLY noise displacement (got %.4f)" % target.rotation)
	JuiceLedger.cleanup_source(target, effect, true)
	await cleanup(target)


## After _restore_to_natural(), the float property returns to its captured base.
func test_noise_property_restores_base_after_stop() -> void:
	var target := create_2d_target()
	target.rotation = 2.5
	var effect := _make_float_effect("rotation", 5.0)
	_drive_noise(effect, target)
	# Confirm displacement happened before testing restore
	assert_greater(target.rotation, 2.5,
		"rotation should be > 2.5 while effect is active (got %.4f)" % target.rotation)
	# Stop: restores base via Ledger
	effect._restore_to_natural(target)
	JuiceLedger.flush(target)
	assert_approx_float(target.rotation, 2.5,
		"rotation should restore to 2.5 after stop", 0.001)
	JuiceLedger.cleanup_source(target, effect, true)
	await cleanup(target)


## A Color property receives additive noise displacement and is brighter than the base.
## Uses Control.modulate (Color.WHITE base) with POSITIVE_ONLY noise — all channels
## gain positive displacement, so at least one channel should exceed 1.0 before clamp
## (or exactly at 1.0 due to clamp). The test verifies that the Ledger write completed
## without error by checking the result is still a valid non-BLACK color.
func test_noise_color_property_displaces_at_peak() -> void:
	var target := create_control_target("TestBtn")
	target.modulate = Color(0.5, 0.5, 0.5, 1.0)  # mid-grey — room to grow in all channels
	var effect := _make_color_effect("modulate", 0.3)
	_drive_noise(effect, target)
	# modulate.r should be > 0.5 since POSITIVE_ONLY noise adds a positive delta
	assert_greater(target.modulate.r, 0.5,
		"modulate.r should be > 0.5 after POSITIVE_ONLY noise (got %.4f)" % target.modulate.r)
	JuiceLedger.cleanup_source(target, effect, true)
	await cleanup(target)
