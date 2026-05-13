## TestPropertyLedger.gd
## ============================================================================
## WHAT: Unit tests for JuiceLedger Phase 6.1 API changes and property routing.
## WHY:  Phase 6.1 widens the Ledger source type from Node to Object, enabling
##       Resource-typed effects (PropertyJuiceEffectBase) to use their own
##       instance ID as a unique ledger slot. These tests verify:
##         - ensure() primes a property path and captures the base value.
##         - register_delta() + flush() produce base + delta on the target.
##         - cleanup_source() removes the source's contribution cleanly.
##         - A Resource (not a Node) is accepted as the source argument.
##         - Base value is fully restored when all sources are cleaned up.
## SYSTEM: Tests (tests/)
## DOES NOT: Duplicate coverage already in TestJuiceLedger.gd (base API tests).
## ============================================================================
## Tests written during: Phase 6.1 (PropertyJuiceEffectBase Infrastructure)
extends JuiceTestSuite

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------

# Creates a minimal Node2D with a known initial position, added to the runner
# scene tree so ensure()'s tree_exiting signal connects correctly.
func _make_target(position: Vector2 = Vector2(10.0, 20.0)) -> Node2D:
	var n := Node2D.new()
	n.position = position
	_runner.add_child(n)
	return n


# Creates a minimal Node to act as a domain node source for ledger entries.
func _make_source_node() -> Node:
	var n := Node.new()
	_runner.add_child(n)
	return n


# Creates a minimal Resource to act as a PropertyJuiceEffectBase-style source.
# Validates the Node → Object widening introduced in Phase 6.1.
func _make_source_resource() -> Resource:
	return Resource.new()

# ---------------------------------------------------------------------------
# REGISTRATION
# ---------------------------------------------------------------------------

func get_suite_name() -> String:
	return "property_ledger_v2"


func get_test_methods() -> Array[String]:
	return [
		"test_ensure_registers_property_path",
		"test_register_delta_additive_float",
		"test_flush_writes_base_plus_delta",
		"test_cleanup_source_removes_delta",
		"test_property_base_restored_after_all_effects_stop",
		"test_resource_accepted_as_source",
	]

# ---------------------------------------------------------------------------
# TESTS
# ---------------------------------------------------------------------------

## ensure() primes the ledger for a property and captures its current value as base.
func test_ensure_registers_property_path() -> void:
	var target := _make_target(Vector2(5.0, 10.0))
	JuiceLedger.ensure(target, ["position"])
	var base: Vector2 = JuiceLedger.get_base(target, "position", Vector2.ZERO)
	assert_equal(base, Vector2(5.0, 10.0), "ensure() should capture current position as base")
	await cleanup(target)


## register_delta() stores a delta that get_total() can then retrieve.
func test_register_delta_additive_float() -> void:
	var target := _make_target()
	var source := _make_source_node()
	JuiceLedger.ensure(target, ["position"])
	JuiceLedger.register_delta(target, source, "position", Vector2(3.0, 4.0))
	var total: Vector2 = JuiceLedger.get_total(target, "position", Vector2.ZERO)
	assert_equal(total, Vector2(3.0, 4.0), "get_total() should return the registered delta")
	JuiceLedger.cleanup_source(target, source)
	await cleanup(target)
	await cleanup(source)


## flush() writes base + sum(deltas) to the node property.
func test_flush_writes_base_plus_delta() -> void:
	var target := _make_target(Vector2(10.0, 20.0))
	var source := _make_source_node()
	JuiceLedger.ensure(target, ["position"])
	JuiceLedger.register_delta(target, source, "position", Vector2(5.0, -5.0))
	JuiceLedger.flush(target)
	assert_equal(target.position, Vector2(15.0, 15.0), "flush() should write base(10,20) + delta(5,-5) = (15,15)")
	JuiceLedger.cleanup_source(target, source)
	await cleanup(target)
	await cleanup(source)


## cleanup_source(permanently=false) removes the source's delta; subsequent flush restores to base.
func test_cleanup_source_removes_delta() -> void:
	var target := _make_target(Vector2(10.0, 0.0))
	var source := _make_source_node()
	JuiceLedger.ensure(target, ["position"])
	JuiceLedger.register_delta(target, source, "position", Vector2(50.0, 0.0))
	JuiceLedger.flush(target)
	assert_equal(target.position, Vector2(60.0, 0.0), "Before cleanup: base(10) + delta(50) = 60")

	# Remove source's contribution without destroying the ledger entry (permanently=false)
	JuiceLedger.cleanup_source(target, source, false)
	JuiceLedger.flush(target)
	assert_equal(target.position, Vector2(10.0, 0.0), "After non-permanent cleanup: only base(10) remains")

	JuiceLedger.cleanup_source(target, source, true)
	await cleanup(target)
	await cleanup(source)


## cleanup_source(permanently=true) with no remaining sources restores base and removes the entry.
func test_property_base_restored_after_all_effects_stop() -> void:
	var target := _make_target(Vector2(7.0, 7.0))
	var source := _make_source_node()
	JuiceLedger.ensure(target, ["position"])
	JuiceLedger.register_delta(target, source, "position", Vector2(100.0, 100.0))
	JuiceLedger.flush(target)
	assert_equal(target.position, Vector2(107.0, 107.0), "Effect applied correctly before cleanup")

	# Permanent cleanup: no other sources → restore base and erase ledger entry
	JuiceLedger.cleanup_source(target, source, true)
	assert_equal(target.position, Vector2(7.0, 7.0), "Permanent cleanup should restore base value")
	# get_base returns fallback when no ledger entry exists for the target
	var after_base: Variant = JuiceLedger.get_base(target, "position", null)
	assert_true(after_base == null, "Ledger entry should be fully removed after permanent cleanup")
	await cleanup(target)
	await cleanup(source)


## Phase 6.1 key change: a Resource (not a Node) can be passed as source.
## Verifies the Node → Object type widening in register_delta, register_hold,
## and cleanup_source allows PropertyJuiceEffectBase (a Resource) to own its
## own unique ledger slot without a wrapper Node.
func test_resource_accepted_as_source() -> void:
	var target := _make_target(Vector2(0.0, 0.0))
	var effect_resource := _make_source_resource()
	JuiceLedger.ensure(target, ["position"])
	# Passing a Resource where Node was previously required — must not crash
	JuiceLedger.register_delta(target, effect_resource, "position", Vector2(42.0, 0.0))
	JuiceLedger.flush(target)
	assert_equal(target.position, Vector2(42.0, 0.0), "Resource source: flush writes base(0)+delta(42)=42")
	JuiceLedger.cleanup_source(target, effect_resource, true)
	assert_equal(target.position, Vector2(0.0, 0.0), "Resource source: permanent cleanup restores base")
	await cleanup(target)
