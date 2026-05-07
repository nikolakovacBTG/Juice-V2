## F2_assign_recipe.gd
## ============================================================================
## Scenario: F2 — Developer assigns a JuiceControlRecipe to a fresh node
## Family: F — Inspector Plugin property visibility
##
## What a developer does:
##   Has a JuiceControl with no recipe (getting a "No recipe assigned" config
##   warning). Drags a JuiceControlRecipe onto the recipe slot.
##   Expects the "No recipe assigned" warning to clear (replaced by a
##   "Recipe has no effects" warning — the next step in setup).
##
## What to assert:
##   - Before assign: config warnings include "No recipe assigned"
##   - After assign: recipe is non-null and correct type (JuiceControlRecipe)
##   - After assign: "No recipe assigned" warning is gone
##     Note: a "Recipe has no effects" warning is expected and correct —
##     the recipe is assigned but empty; that is the NEXT thing to fix.
##
## Plugin visibility note:
##   F1 already confirms the recipe property is always visible in the inspector.
##   F2 focuses on the config warning lifecycle, not plugin visibility.
##
## Pre-conditions:
##   - Any scene is open in the editor (scene root must exist)
## ============================================================================
func run():
	var scene_root = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return {"error": "No scene open in editor — open any scene first"}

	var node := JuiceControl.new()
	node.name = "F2_TestJuiceControl"
	scene_root.add_child(node)
	node.owner = scene_root

	# --- Before assignment ---
	var before = node._get_configuration_warnings()
	var had_no_recipe_warning := false
	for w in before:
		# "No recipe assigned. Add a JuiceRecipe to get started."
		if "no recipe" in w.to_lower():
			had_no_recipe_warning = true

	# --- Assign recipe ---
	var recipe := JuiceControlRecipe.new()
	node.recipe = recipe

	# --- After assignment ---
	var after = node._get_configuration_warnings()
	var no_recipe_cleared := true
	for w in after:
		# "Recipe has no effects" is acceptable — only "No recipe" must be gone
		if "no recipe" in w.to_lower():
			no_recipe_cleared = false

	var correct_type := node.recipe is JuiceControlRecipe

	node.queue_free()

	return {
		"warnings_before": before,
		"had_no_recipe_warning": had_no_recipe_warning,
		"warnings_after": after,
		"no_recipe_warning_cleared": no_recipe_cleared,
		"recipe_correct_type": correct_type,
		"all_correct": had_no_recipe_warning and no_recipe_cleared and correct_type,
	}
