## G1_basic_play.gd
## ============================================================================
## WHAT: MCP Tier 2 — Orchestrator basic play lifecycle (PREVIEW mode).
## SCENARIO: A developer selects a JuiceControl in the editor. PreviewDirector
##           creates an orchestrator via factory. Developer clicks Play IN.
##           Verify: orchestrator created, play_in() delegates without crash,
##           teardown() frees the orchestrator.
## ============================================================================
@tool
extends EditorScript

func _run() -> void:
	var results := {}

	# Setup: JuiceControl with a parent (simulates being in a real scene)
	var parent := Control.new()
	parent.name = "_G1_TestParent"
	EditorInterface.get_edited_scene_root().add_child(parent)

	var juice := JuiceControl.new()
	juice.name = "_G1_TestJuice"
	parent.add_child(juice)

	await Engine.get_main_loop().process_frame

	# Simulate: PreviewDirector._add_preview_node() spawns orchestrator
	var orch := JuiceOrchestratorFactory.create(juice, JuiceOrchestrator.Mode.PREVIEW)

	results["orchestrator_created"] = is_instance_valid(orch)
	results["mode_is_preview"] = (orch._mode == JuiceOrchestrator.Mode.PREVIEW)
	results["node_stored"] = (orch._node == juice)

	# Simulate: Developer clicks Play IN
	orch.play_in()
	results["play_in_no_crash"] = true

	# Simulate: Developer deselects — teardown() called
	orch.teardown()
	results["freed_after_teardown"] = not is_instance_valid(orch)

	results["all_correct"] = (
		results["orchestrator_created"] and
		results["mode_is_preview"] and
		results["node_stored"] and
		results["play_in_no_crash"] and
		results["freed_after_teardown"]
	)

	print("G1 results: ", results)

	# Cleanup
	parent.queue_free()
