## G2_deselect_teardown.gd
## ============================================================================
## WHAT: MCP Tier 2 — Deselect tears down all orchestrators (PREVIEW mode).
## SCENARIO: Two JuiceControl nodes are previewed simultaneously (sibling mode).
##           Developer deselects. Verify all orchestrators are freed, no leaks.
## ============================================================================
@tool
extends EditorScript

func _run() -> void:
	var results := {}

	var parent := Control.new()
	parent.name = "_G2_TestParent"
	EditorInterface.get_edited_scene_root().add_child(parent)

	var juice_a := JuiceControl.new()
	juice_a.name = "_G2_JuiceA"
	parent.add_child(juice_a)

	var juice_b := JuiceControl.new()
	juice_b.name = "_G2_JuiceB"
	parent.add_child(juice_b)

	await Engine.get_main_loop().process_frame

	# Simulate: PreviewDirector spawns two orchestrators (primary + sibling)
	var orch_a := JuiceOrchestratorFactory.create(juice_a, JuiceOrchestrator.Mode.PREVIEW)
	var orch_b := JuiceOrchestratorFactory.create(juice_b, JuiceOrchestrator.Mode.PREVIEW)

	results["both_created"] = is_instance_valid(orch_a) and is_instance_valid(orch_b)

	# Simulate: play_in on both (as PreviewDirector.play_in() would)
	orch_a.play_in()
	orch_b.play_in()
	results["both_play_in_no_crash"] = true

	# Simulate: Developer deselects — PreviewDirector.deselect() calls teardown on each
	orch_a.teardown()
	orch_b.teardown()

	results["orch_a_freed"] = not is_instance_valid(orch_a)
	results["orch_b_freed"] = not is_instance_valid(orch_b)

	results["all_correct"] = (
		results["both_created"] and
		results["both_play_in_no_crash"] and
		results["orch_a_freed"] and
		results["orch_b_freed"]
	)

	print("G2 results: ", results)

	parent.queue_free()
