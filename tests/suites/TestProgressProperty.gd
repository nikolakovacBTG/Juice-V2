## Phase 6.5 tests for ProgressPropertyJuiceEffectBase and domain leaf nodes.
##
## Validates that the progress envelope correctly drives a property from its
## natural base toward the configured target value via the JuiceLedger, and
## that the property is fully restored to its base when the effect stops.

# ============================================================================
# WHAT: Automated tests for the ProgressProperty effect family.
# WHY:  Confirms that ProgressPropertyJuiceEffectBase lerps base→to_* correctly
#       through JuiceLedger (not direct write), and that _restore_to_natural()
#       returns the property to its captured base — same invariants as all other
#       Property-family effects.
# SYSTEM: Tests (tests/suites/)
# ============================================================================

extends JuiceTestSuite


func get_suite_name() -> String:
	return "progress_property_v2"


func get_test_methods() -> Array[String]:
	return [
		"test_progress_drives_float_property",
		"test_progress_restores_base_after_stop",
		"test_progress_drives_color_property",
	]


# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------

# Builds a ProgressProperty2DJuiceEffect targeting a float property.
# to_val is the absolute target value at progress=1.0.
func _make_float_effect(prop: String, to_val: float) -> ProgressProperty2DJuiceEffect:
	var effect := ProgressProperty2DJuiceEffect.new()
	effect.to_float = to_val
	var slot := PropertyTarget.new()
	slot.property_path = prop
	effect.property_targets.append(slot)
	return effect


# Builds a ProgressPropertyControlJuiceEffect targeting a Color property.
func _make_color_effect(prop: String, to_val: Color) -> ProgressPropertyControlJuiceEffect:
	var effect := ProgressPropertyControlJuiceEffect.new()
	effect.to_color = to_val
	var slot := PropertyTarget.new()
	slot.property_path = prop
	effect.property_targets.append(slot)
	return effect


# Drives the effect through one apply cycle at the given progress.
# ProgressProperty is deterministic — no time state — so a single
# _apply_effect call at a known progress is sufficient to verify output.
func _drive_progress(effect: PropertyJuiceEffectBase, target: Node, progress: float) -> void:
	effect._on_animate_start(target)
	effect._apply_effect(progress, target)
	JuiceLedger.flush(target)


# ---------------------------------------------------------------------------
# TESTS
# ---------------------------------------------------------------------------

## At progress=0.5, float property should be exactly halfway between base and to_float.
## base=0.0, to_float=10.0 → lerp(0.0, 10.0, 0.5) = 5.0.
## Verifies the Ledger path: delta = desired - base = 5.0, flush writes base+delta = 5.0.
func test_progress_drives_float_property() -> void:
	var target := create_2d_target()
	target.rotation = 0.0
	var effect := _make_float_effect("rotation", 10.0)
	_drive_progress(effect, target, 0.5)
	assert_approx_float(target.rotation, 5.0,
		"rotation should be ~5.0 at progress=0.5 (got %.4f)" % target.rotation, 0.01)
	JuiceLedger.cleanup_source(target, effect, true)
	await cleanup(target)


## After _restore_to_natural(), the property must return to its captured base.
## Drives to progress=1.0 first to confirm the effect reaches to_float, then
## stops and verifies the Ledger writes back the original base value.
func test_progress_restores_base_after_stop() -> void:
	var target := create_2d_target()
	target.rotation = 3.0
	var effect := _make_float_effect("rotation", 10.0)
	_drive_progress(effect, target, 1.0)
	assert_approx_float(target.rotation, 10.0,
		"rotation should be ~10.0 at progress=1.0 (got %.4f)" % target.rotation, 0.01)
	# Stop — cleanup_source(false) removes this source's delta, leaving base intact.
	effect._restore_to_natural(target)
	JuiceLedger.flush(target)
	assert_approx_float(target.rotation, 3.0,
		"rotation should restore to 3.0 after stop (got %.4f)" % target.rotation, 0.001)
	JuiceLedger.cleanup_source(target, effect, true)
	await cleanup(target)


## At progress=1.0, Color property should equal to_color exactly.
## base=Color(1,1,1,1), to_color=Color(0.5,0.5,0.5,0.5) → desired=Color(0.5,0.5,0.5,0.5).
## Factor = desired/base = Color(0.5,0.5,0.5,0.5); flush: base*factor = Color(0.5,0.5,0.5,0.5).
func test_progress_drives_color_property() -> void:
	var target := create_control_target("TestBtn")
	target.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var effect := _make_color_effect("modulate", Color(0.5, 0.5, 0.5, 0.5))
	_drive_progress(effect, target, 1.0)
	assert_approx_float(target.modulate.r, 0.5,
		"modulate.r should be ~0.5 at progress=1.0 (got %.4f)" % target.modulate.r, 0.01)
	assert_approx_float(target.modulate.a, 0.5,
		"modulate.a should be ~0.5 at progress=1.0 (got %.4f)" % target.modulate.a, 0.01)
	JuiceLedger.cleanup_source(target, effect, true)
	await cleanup(target)
