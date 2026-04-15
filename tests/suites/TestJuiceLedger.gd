## TestJuiceLedger.gd
## ============================================================================
## WHAT: Isolated unit tests for JuiceLedger static API.
## WHY:  Ledger is core Juice infrastructure -- must be testable without any
##       effects, recipes, or domain nodes. Pure Node target + static calls.
## SYSTEM: Tests (tests/)
## DOES NOT: Test domain nodes, effects, or recipes.
## ============================================================================
extends JuiceTestSuite

func get_suite_name() -> String:
	return "juice_ledger"

func get_test_methods() -> Array[String]:
	return [
		"test_ensure_creates_meta",
		"test_ensure_records_base_from_current_value",
		"test_ensure_does_not_overwrite_existing_base",
		"test_register_delta_single_source",
		"test_register_delta_two_sources_sum",
		"test_register_delta_overwrites_same_source",
		"test_get_base_returns_natural_not_delta",
		"test_flush_writes_base_plus_total",
		"test_flush_on_unleddgered_node_is_noop",
		"test_cleanup_source_removes_delta",
		"test_cleanup_source_preserves_other_sources",
		"test_cleanup_permanently_removes_meta_when_empty",
		"test_cleanup_non_permanently_keeps_meta",
		"test_sync_base_detects_external_move",
		"test_zero_for_returns_correct_types",
	]

# =============================================================================
# HELPERS
# =============================================================================

func _make_source() -> Node:
	var n := Node.new()
	_runner.add_child(n)
	return n

# =============================================================================
# TESTS
# =============================================================================

func test_ensure_creates_meta() -> void:
	var target := create_2d_target()
	assert_false(JuiceLedger.has_ledger(target), "Before ensure: no ledger")
	JuiceLedger.ensure(target, ["position"])
	assert_true(JuiceLedger.has_ledger(target), "After ensure: ledger exists")
	await cleanup(target)

func test_ensure_records_base_from_current_value() -> void:
	var target := create_2d_target()
	target.position = Vector2(33.0, 77.0)
	JuiceLedger.ensure(target, ["position"])
	var base: Variant = JuiceLedger.get_base(target, "position", Vector2.ZERO)
	assert_approx_vec2(base as Vector2, Vector2(33.0, 77.0), "Base should snapshot current position")
	await cleanup(target)

func test_ensure_does_not_overwrite_existing_base() -> void:
	var target := create_2d_target()
	target.position = Vector2(10.0, 0.0)
	JuiceLedger.ensure(target, ["position"])
	target.position = Vector2(99.0, 0.0)
	JuiceLedger.ensure(target, ["position"])
	var base: Variant = JuiceLedger.get_base(target, "position", Vector2.ZERO)
	assert_approx_vec2(base as Vector2, Vector2(10.0, 0.0), "Ensure must not overwrite existing base")
	await cleanup(target)

func test_register_delta_single_source() -> void:
	var target := create_2d_target()
	var source := _make_source()
	target.position = Vector2.ZERO
	JuiceLedger.ensure(target, ["position"])
	JuiceLedger.register_delta(target, source, "position", Vector2(20.0, 0.0))
	var total: Variant = JuiceLedger.get_total(target, "position", Vector2.ZERO)
	assert_approx_vec2(total as Vector2, Vector2(20.0, 0.0), "Single source delta should equal registered value")
	await cleanup(target)
	await cleanup(source)

func test_register_delta_two_sources_sum() -> void:
	var target := create_2d_target()
	var src_a := _make_source()
	var src_b := _make_source()
	target.position = Vector2.ZERO
	JuiceLedger.ensure(target, ["position"])
	JuiceLedger.register_delta(target, src_a, "position", Vector2(10.0, 0.0))
	JuiceLedger.register_delta(target, src_b, "position", Vector2(0.0, 5.0))
	var total: Variant = JuiceLedger.get_total(target, "position", Vector2.ZERO)
	assert_approx_vec2(total as Vector2, Vector2(10.0, 5.0), "Two sources should sum their deltas")
	await cleanup(target)
	await cleanup(src_a)
	await cleanup(src_b)

func test_register_delta_overwrites_same_source() -> void:
	var target := create_2d_target()
	var source := _make_source()
	target.position = Vector2.ZERO
	JuiceLedger.ensure(target, ["position"])
	JuiceLedger.register_delta(target, source, "position", Vector2(10.0, 0.0))
	JuiceLedger.register_delta(target, source, "position", Vector2(25.0, 0.0))
	var total: Variant = JuiceLedger.get_total(target, "position", Vector2.ZERO)
	assert_approx_vec2(total as Vector2, Vector2(25.0, 0.0), "Re-registering same source should replace, not add")
	await cleanup(target)
	await cleanup(source)

func test_get_base_returns_natural_not_delta() -> void:
	var target := create_2d_target()
	var source := _make_source()
	target.position = Vector2(5.0, 5.0)
	JuiceLedger.ensure(target, ["position"])
	JuiceLedger.register_delta(target, source, "position", Vector2(100.0, 0.0))
	var base: Variant = JuiceLedger.get_base(target, "position", Vector2.ZERO)
	assert_approx_vec2(base as Vector2, Vector2(5.0, 5.0), "Base must not include delta -- natural only")
	await cleanup(target)
	await cleanup(source)

func test_flush_writes_base_plus_total() -> void:
	var target := create_2d_target()
	var source := _make_source()
	target.position = Vector2(10.0, 0.0)
	JuiceLedger.ensure(target, ["position"])
	JuiceLedger.register_delta(target, source, "position", Vector2(20.0, 0.0))
	target.position = Vector2.ZERO
	JuiceLedger.flush(target)
	assert_approx_vec2(target.position, Vector2(30.0, 0.0),
		"Flush: target.position should be base(10) + delta(20) = 30")
	await cleanup(target)
	await cleanup(source)

func test_flush_on_unleddgered_node_is_noop() -> void:
	var target := create_2d_target()
	target.position = Vector2(7.0, 3.0)
	JuiceLedger.flush(target)
	assert_approx_vec2(target.position, Vector2(7.0, 3.0),
		"Flush on node with no ledger must not change position")
	await cleanup(target)

func test_cleanup_source_removes_delta() -> void:
	var target := create_2d_target()
	var source := _make_source()
	target.position = Vector2.ZERO
	JuiceLedger.ensure(target, ["position"])
	JuiceLedger.register_delta(target, source, "position", Vector2(15.0, 0.0))
	JuiceLedger.cleanup_source(target, source, false)
	var total: Variant = JuiceLedger.get_total(target, "position", Vector2.ZERO)
	assert_approx_vec2(total as Vector2, Vector2.ZERO, "After cleanup, total delta must be zero")
	await cleanup(target)
	await cleanup(source)

func test_cleanup_source_preserves_other_sources() -> void:
	var target := create_2d_target()
	var src_a := _make_source()
	var src_b := _make_source()
	target.position = Vector2.ZERO
	JuiceLedger.ensure(target, ["position"])
	JuiceLedger.register_delta(target, src_a, "position", Vector2(10.0, 0.0))
	JuiceLedger.register_delta(target, src_b, "position", Vector2(5.0, 0.0))
	JuiceLedger.cleanup_source(target, src_a, false)
	var total: Variant = JuiceLedger.get_total(target, "position", Vector2.ZERO)
	assert_approx_vec2(total as Vector2, Vector2(5.0, 0.0),
		"Source B delta must survive after Source A is cleaned up")
	await cleanup(target)
	await cleanup(src_a)
	await cleanup(src_b)

func test_cleanup_permanently_removes_meta_when_empty() -> void:
	var target := create_2d_target()
	var source := _make_source()
	target.position = Vector2.ZERO
	JuiceLedger.ensure(target, ["position"])
	JuiceLedger.register_delta(target, source, "position", Vector2(10.0, 0.0))
	JuiceLedger.cleanup_source(target, source, true)
	assert_false(JuiceLedger.has_ledger(target),
		"Permanent cleanup with no remaining sources should remove ledger meta")
	await cleanup(target)
	await cleanup(source)

func test_cleanup_non_permanently_keeps_meta() -> void:
	var target := create_2d_target()
	var source := _make_source()
	target.position = Vector2.ZERO
	JuiceLedger.ensure(target, ["position"])
	JuiceLedger.register_delta(target, source, "position", Vector2(10.0, 0.0))
	JuiceLedger.cleanup_source(target, source, false)
	assert_true(JuiceLedger.has_ledger(target),
		"Non-permanent cleanup must keep ledger meta for next frame re-registration")
	await cleanup(target)
	await cleanup(source)

func test_sync_base_detects_external_move() -> void:
	var target := create_2d_target()
	target.position = Vector2.ZERO
	JuiceLedger.ensure(target, ["position"])
	target.position = Vector2(50.0, 0.0)
	JuiceLedger.sync_base_if_moved(target, ["position"])
	var base: Variant = JuiceLedger.get_base(target, "position", Vector2.ZERO)
	assert_approx_vec2(base as Vector2, Vector2(50.0, 0.0),
		"sync_base_if_moved must update base when target moved externally with no active delta")
	await cleanup(target)

func test_zero_for_returns_correct_types() -> void:
	var float_zero: Variant = JuiceLedger.zero_for(1.0)
	assert_true(float_zero is float, "zero_for(float) should return float")
	assert_approx_float(float_zero as float, 0.0, "zero_for(float) = 0.0")

	var v2_zero: Variant = JuiceLedger.zero_for(Vector2(1.0, 1.0))
	assert_true(v2_zero is Vector2, "zero_for(Vector2) should return Vector2")
	assert_approx_vec2(v2_zero as Vector2, Vector2.ZERO, "zero_for(Vector2) = ZERO")

	var v3_zero: Variant = JuiceLedger.zero_for(Vector3(1.0, 1.0, 1.0))
	assert_true(v3_zero is Vector3, "zero_for(Vector3) should return Vector3")

	var col_zero: Variant = JuiceLedger.zero_for(Color.RED)
	assert_true(col_zero is Color, "zero_for(Color) should return Color")