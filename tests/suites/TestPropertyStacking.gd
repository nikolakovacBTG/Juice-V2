## TestPropertyStacking.gd
## ============================================================================
## WHAT: Integration tests for multi-source delta stacking in V2.
## WHY:  Two orchestrators targeting the same node must sum deltas correctly —
##       neither can overwrite the other. This is the core correctness guarantee
##       of the ledger-based write model.
## SYSTEM: Tests (tests/)
## DOES NOT: Test single-source animation or inspector behavior.
## ============================================================================
## Tests written during: Phase 6 (Property Ledger)
extends JuiceTestSuite

func get_suite_name() -> String:
	return "property_stacking_v2"

func get_test_methods() -> Array[String]:
	# Populated in Phase 6. Expected coverage (mirrors B2 family in realistic-test-design):
	# - Full overlap: two orchestrators same target simultaneously
	# - Partial overlap A-first: A starts, B starts mid-A, A completes, B completes
	# - One stops early: stop A, B continues with its delta only
	# - Different channels: position + scale from separate orchestrators
	return []
