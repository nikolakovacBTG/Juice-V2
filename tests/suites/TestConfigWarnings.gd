## TestConfigWarnings.gd
## ============================================================================
## WHAT: Unit tests for _get_configuration_warnings() on all domain nodes.
## WHY:  Config warnings are the user's primary feedback mechanism in the editor.
##       Missing recipe, missing target, or invalid effect configuration must all
##       surface as clear, specific warning strings.
## SYSTEM: Tests (tests/)
## DOES NOT: Test inspector property visibility or runtime animation.
## ============================================================================
## Tests written during: Phase 5 (Gut Domain Nodes + Config Warnings)
extends JuiceTestSuite

func get_suite_name() -> String:
	return "config_warnings"

func get_test_methods() -> Array[String]:
	# Populated in Phase 5. Expected coverage:
	# - No recipe: warning present on all 3 domain types
	# - Recipe assigned: warning clears
	# - No target: warning present
	# - Target assigned: warning clears
	# - Empty recipe (no effects): optional warning
	return []
