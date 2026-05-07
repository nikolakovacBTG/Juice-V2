## TestConfigWarnings.gd
## ============================================================================
## WHAT: Unit tests for _get_configuration_warnings() on JuiceControl domain nodes.
## WHY:  Config warnings are the user's primary feedback mechanism in the editor.
##       Missing recipe, empty recipe, null slots, and bad chain references must
##       all surface as clear, specific warning strings before the game runs.
## SYSTEM: Tests (tests/)
## DOES NOT: Test inspector property visibility or runtime animation.
## ============================================================================
## _get_configuration_warnings() is inherited from JuiceBase and executes
## identically across all three domains. Testing on JuiceControl provides full
## coverage of the base logic without headless class conflicts.
extends JuiceTestSuite

func get_suite_name() -> String:
	return "config_warnings"

func get_test_methods() -> Array[String]:
	return [
		"test_no_recipe_warns",
		"test_recipe_assigned_clears_warning",
		"test_empty_recipe_warns",
		"test_null_effect_slot_warns",
		"test_cross_recipe_chain_warns",
	]


# =============================================================================
# TESTS
# =============================================================================

func test_no_recipe_warns() -> void:
	# JuiceControl defaults to recipe = null — the most common user mistake.
	var parent := Control.new()
	_runner.add_child(parent)
	var juice := JuiceControl.new()
	parent.add_child(juice)
	await wait_frames(1)

	var warnings := juice._get_configuration_warnings()
	assert_true(_warning_contains(warnings, "No recipe assigned"),
			"No-recipe warning fires when recipe is null")

	parent.queue_free()


func test_recipe_assigned_clears_warning() -> void:
	# A non-empty recipe must suppress the no-recipe warning entirely.
	var parent := Control.new()
	_runner.add_child(parent)
	var juice := JuiceControl.new()
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(TransformControlJuiceEffect.new())
	juice.recipe = recipe
	parent.add_child(juice)
	await wait_frames(1)

	var warnings := juice._get_configuration_warnings()
	assert_false(_warning_contains(warnings, "No recipe assigned"),
			"No-recipe warning absent when valid recipe is assigned")

	parent.queue_free()


func test_empty_recipe_warns() -> void:
	# A recipe with zero effects is a common copy-paste mistake.
	var parent := Control.new()
	_runner.add_child(parent)
	var juice := JuiceControl.new()
	juice.recipe = JuiceControlRecipe.new()  # valid recipe, but zero effects
	parent.add_child(juice)
	await wait_frames(1)

	var warnings := juice._get_configuration_warnings()
	assert_true(_warning_contains(warnings, "Recipe has no effects"),
			"Empty-recipe warning fires when recipe has zero effects")

	parent.queue_free()


func test_null_effect_slot_warns() -> void:
	# Null slots appear when the user adds an entry but never assigns an effect resource.
	var parent := Control.new()
	_runner.add_child(parent)
	var juice := JuiceControl.new()
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(null)  # one null slot
	juice.recipe = recipe
	parent.add_child(juice)
	await wait_frames(1)

	var warnings := juice._get_configuration_warnings()
	assert_true(_warning_contains(warnings, "empty effect slot"),
			"Null-slot warning fires when recipe contains a null entry")

	parent.queue_free()


func test_cross_recipe_chain_warns() -> void:
	# chain_to pointing outside the recipe is caught at edit time, not runtime.
	var parent := Control.new()
	_runner.add_child(parent)
	var juice := JuiceControl.new()
	var effect_in_recipe := TransformControlJuiceEffect.new()
	var effect_outside := TransformControlJuiceEffect.new()  # never added to recipe
	effect_in_recipe.chain_to.append(effect_outside)
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect_in_recipe)
	juice.recipe = recipe
	parent.add_child(juice)
	await wait_frames(1)

	var warnings := juice._get_configuration_warnings()
	assert_true(_warning_contains(warnings, "chains to an effect not in the same recipe"),
			"Cross-recipe chain warning fires when chain_to references an external effect")

	parent.queue_free()


# =============================================================================
# HELPERS
# =============================================================================

# Returns true if any warning string in the array contains the given substring.
func _warning_contains(warnings: PackedStringArray, substring: String) -> bool:
	for w in warnings:
		if substring in w:
			return true
	return false
