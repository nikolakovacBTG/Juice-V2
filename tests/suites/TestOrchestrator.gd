## TestOrchestrator.gd
## ============================================================================
## WHAT: Unit tests for JuiceOrchestrator lifecycle — both PREVIEW and RUNTIME modes.
## WHY:  Orchestrator is the animation engine heart of V2. RUNTIME must never
##       allocate on retrigger. PREVIEW must queue_free() and restore on teardown.
## SYSTEM: Tests (tests/)
## DOES NOT: Test inspector property visibility or config warnings.
## ============================================================================
## Tests written during: Phase 4 (Single Orchestrator & Factory)
extends JuiceTestSuite

func get_suite_name() -> String:
	return "orchestrator"

func get_test_methods() -> Array[String]:
	# Populated in Phase 4. Expected coverage:
	# - PREVIEW: spawn -> play -> teardown -> freed
	# - RUNTIME: spawn -> play -> complete -> idle -> reset() -> no new allocation
	# - Ledger cleanup after both modes
	# - Retrigger allocation (child count unchanged after reset)
	return []
