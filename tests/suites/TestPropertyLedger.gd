## TestPropertyLedger.gd
## ============================================================================
## WHAT: Unit tests for JuiceLedger behavior under V2 orchestrator source model.
## WHY:  V2 uses orchestrator as source_id, not domain nodes. These tests verify
##       the ledger correctly handles orchestrator registration and cleanup.
## SYSTEM: Tests (tests/)
## DOES NOT: Duplicate coverage already in TestJuiceLedger.gd (base API tests).
## ============================================================================
## Tests written during: Phase 6 (Property Ledger)
extends JuiceTestSuite

func get_suite_name() -> String:
	return "property_ledger_v2"

func get_test_methods() -> Array[String]:
	# Populated in Phase 6. Expected coverage:
	# - Orchestrator as source_id registers correctly
	# - RUNTIME orchestrator cleanup removes ledger entry
	# - PREVIEW orchestrator cleanup removes ledger entry
	# - Two orchestrators same target: independent source tracking
	return []
