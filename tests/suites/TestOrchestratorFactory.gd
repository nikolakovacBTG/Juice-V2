## TestOrchestratorFactory.gd
## ============================================================================
## WHAT: Unit tests for JuiceOrchestratorFactory.create() entry point.
## WHY:  Factory is the single creation path for all orchestrators — must verify
##       correct mode assignment, recipe wiring, and target resolution.
## SYSTEM: Tests (tests/)
## DOES NOT: Test orchestrator animation tick or lifecycle state transitions.
## ============================================================================
## Tests written during: Phase 4 (Single Orchestrator & Factory)
extends JuiceTestSuite

func get_suite_name() -> String:
	return "orchestrator_factory"

func get_test_methods() -> Array[String]:
	# Populated in Phase 4. Expected coverage:
	# - create() returns correctly-typed JuiceOrchestrator
	# - PREVIEW mode assigned correctly
	# - RUNTIME mode assigned correctly
	# - Null recipe / null target handled gracefully
	return []
