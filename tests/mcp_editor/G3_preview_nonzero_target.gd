## G3_preview_nonzero_target.gd
## ============================================================================
## Scenario: G3 — Transport preview on non-zero position target
## Family: G — Transport preview
##
## What a developer does:
##   Opens a scene, selects a Juice2D node whose target is at (200, 150).
##   Presses Play in the transport. Observes animation. Presses Stop.
##
## What to assert:
##   - During animation: target.position != natural position (animation is running)
##   - After stop: target.position == (200, 150) exactly (restored to natural)
##   - Ledger base matches (200, 150) — not (0, 0)
##
## Pre-conditions:
##   - Scene must have a node named "Juice2D" with target_node set
##   - Target must be at non-zero position (200, 150) in the scene
##   - Recipe must have at least one Transform effect
## ============================================================================
func run():
	var scene_root = EditorInterface.get_edited_scene_root()
	var juice: Juice2D = null
	for child in scene_root.get_children():
		if child is Juice2D:
			juice = child
			break

	if juice == null:
		return {"error": "No Juice2D found in scene root"}

	var target = juice.target_node
	if target == null:
		return {"error": "Juice2D has no target_node assigned"}

	var natural_pos = target.position

	# Trigger PREVIEW via PreviewDirector
	JuicePreviewDirector.preview(juice)
	var pos_during = target.position

	JuicePreviewDirector.stop_preview(juice)
	var pos_after = target.position

	var ledger_base = JuiceLedger.get_base(target, "position", Vector2.ZERO)

	return {
		"natural_pos": natural_pos,
		"pos_during_animation": pos_during,
		"pos_after_stop": pos_after,
		"ledger_base": ledger_base,
		"restored_correctly": pos_after.is_equal_approx(natural_pos),
		"ledger_base_correct": ledger_base.is_equal_approx(natural_pos),
		"animation_ran": not pos_during.is_equal_approx(natural_pos),
	}
