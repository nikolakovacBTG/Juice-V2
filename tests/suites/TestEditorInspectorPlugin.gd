## TestEditorInspectorPlugin.gd
## ============================================================================
## WHAT: Unit tests for JuiceEditorInspectorPlugin property visibility logic.
## WHY:  Inspector plugin owns _parse_property() for all domain nodes — must be
##       tested independently to verify show/hide rules are correct per recipe type.
## SYSTEM: Tests (tests/)
## DOES NOT: Test transport preview or runtime animation behavior.
## ============================================================================
## Tests written during: Phase 3 (EditorInspectorPlugin Extraction)
extends JuiceTestSuite

func get_suite_name() -> String:
	return "editor_inspector_plugin"

func get_test_methods() -> Array[String]:
	# Populated in Phase 3
	return []
