## mcp_editor/README.md
## ============================================================================
## Tier 2 — MCP Editor Test Scripts
##
## These scripts are executed via mcp_godot-mcp_execute_editor_script against
## a live open scene. They are NOT registered in JuiceTestRunner.gd.
##
## Each file is a self-contained func run(): block that:
##   1. Sets up state in the live editor scene
##   2. Executes a user-behaviour scenario
##   3. Returns a Dictionary of key values for assertion
##
## Naming convention: [Family][TestNumber]_[description].gd
##   e.g. G3_preview_nonzero_target.gd
##        J2_stop_one_preview_other_continues.gd
##        L4_duplication_independent_resources.gd
##
## See: .agents/skills/realistic-test-design/REFERENCES/tier2-scenarios.md
##      for the full scenario library (Families F-L).
##
## Scripts are documented in their file headers with:
##   - Scenario family + test ID
##   - What a developer does (user-behaviour framing)
##   - What to assert
##   - Pre-conditions (what the open scene must contain)
## ============================================================================
