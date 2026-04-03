## Test[EffectName][Domain].gd
## ============================================================================
## WHAT: Automated tests for [EffectName][Domain]JuiceEffect.
## TESTS: [List key behaviors being tested]
## ============================================================================
extends JuiceTestSuite


func get_suite_name() -> String:
	return "REPLACE_effect_domain"


func get_test_methods() -> Array[String]:
	return [
		# List ALL test methods here — order matters for readability
		"test_basic_effect_applies",
		"test_returns_to_natural_after_completion",
		# "test_[specific_behavior]",
	]


# =============================================================================
# TESTS
# =============================================================================

## Verify that the effect produces a visible change during animation.
func test_basic_effect_applies() -> void:
	# 1. CREATE target + effect + juice node
	var target := create_control_target("Test")
	# var effect := [EffectName]ControlJuiceEffect.new()
	# [configure effect properties]
	# var juice := create_juice_control(effect, target)

	# 2. WAIT for ready
	await wait_frames(2)

	# 3. RECORD natural state
	# var natural_pos := target.position

	# 4. TRIGGER animation
	# juice.animate_in()

	# 5. WAIT for effect to be visible (mid-animation)
	# await wait_seconds(effect.duration_in * 0.5)

	# 6. ASSERT change happened
	# assert_not_approx_vec2(target.position, natural_pos,
	#     "Position should differ during animation")

	# 7. CLEANUP
	await cleanup(target)


## Verify that the target returns to its natural state after animation completes.
func test_returns_to_natural_after_completion() -> void:
	# 1. CREATE
	var target := create_control_target("Test")
	# var effect := ...
	# var juice := create_juice_control(effect, target)
	await wait_frames(2)

	# 2. RECORD natural
	# var natural_pos := target.position

	# 3. TRIGGER + WAIT for completion
	# juice.animate_in()
	# await wait_seconds(effect.duration_in + 0.1)

	# 4. ASSERT returned to natural
	# assert_approx_vec2(target.position, natural_pos,
	#     "Position should return to natural after completion")

	# 5. CLEANUP
	await cleanup(target)


# =============================================================================
# TEST PATTERN REFERENCE
# =============================================================================
#
# Standard test structure for Juice effects:
#
# 1. CREATE — target node + effect resource + juice node
# 2. WAIT — 2 frames for _ready() propagation
# 3. RECORD — capture natural/base state
# 4. TRIGGER — juice.animate_in() or juice.animate_out()
# 5. WAIT — for mid-animation or completion
# 6. ASSERT — verify expected state
# 7. CLEANUP — await cleanup(target)
#
# Key assertions per effect type:
# - Transform: position/rotation/scale changes during animation
# - SquashStretch: scale changes, volume preservation
# - Noise/Shake: position varies frame-to-frame (non-deterministic)
# - Appearance: modulate/material changes
#
# Cross-domain verification:
# - If this is a Control test, ensure equivalent 2D and 3D tests exist
# - Use the same test names across domains for traceability
