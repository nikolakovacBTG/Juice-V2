## TestRealWorldProgressTransform.gd
## ============================================================================
## WHAT: Realistic integration tests for ProgressTransform effects across all
##       3 domains (2D, Control, 3D).
## WHY:  The unit-style tests (TestProgressTransform2D/3D/Control) use targets
##       at Vector2.ZERO and test effects in isolation. Real scenes have nodes
##       at non-zero positions, multiple effects stacked on the same target, and
##       mixed recipes. This suite covers those real-world scenarios.
## SYSTEM: Tests (tests/suites/)
## DOES NOT: Test editor transport lifecycle (that requires MCP editor scripts
##           running in the live editor process, not headless).
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "realworld_progress_transform"


func get_test_methods() -> Array[String]:
	return [
		# --- Registration ---
		"test_2d_registration",
		"test_control_registration",
		"test_3d_registration",
		# --- 2D Position (Phase A-2) ---
		# "test_2d_position_non_zero_origin",          # Phase A-2
		# "test_2d_position_bound_reverse_non_zero",   # Phase A-2
		# "test_2d_position_bound_reverse_eased_non_zero", # Phase A-2
		# --- 2D Rotation + Scale + Stacking (Phase A-3) ---
		# "test_2d_rotation_non_zero_origin",          # Phase A-3
		# "test_2d_scale_non_zero_origin",             # Phase A-3
		# "test_2d_stacked_deterministic",             # Phase A-3
		# --- 2D Mixed + Retrigger (Phase A-4) ---
		# "test_2d_mixed_shake_no_interference",       # Phase A-4
		# "test_2d_mixed_noise_no_interference",       # Phase A-4
		# "test_2d_retrigger_during_sustain",          # Phase A-4
		# --- Control domain (Phase A-5) ---
		# "test_control_position_non_zero_origin",     # Phase A-5
		# "test_control_bound_reverse_non_zero",       # Phase A-5
		# "test_control_stacked_deterministic",        # Phase A-5
		# "test_control_mixed_noise_no_interference",  # Phase A-5
		# --- 3D domain (Phase A-6) ---
		# "test_3d_position_non_zero_origin",          # Phase A-6
		# "test_3d_rotation_non_zero_origin",          # Phase A-6
		# "test_3d_bound_reverse_non_zero",            # Phase A-6
		# "test_3d_mixed_noise_no_interference",       # Phase A-6
	]


# =============================================================================
# HELPERS (scaffold - implementations added in later phases)
# =============================================================================

# Creates a Juice2D + Node2D target rig at the given position and transform target.
# Returns [Juice2D, Node2D].
func _create_2d_rig_at(
		pos: Vector2,
		target_type: int = ProgressTransform2DJuiceEffect.TransformTarget.POSITION,
		rate_pos: Vector2 = Vector2(100.0, 0.0),
		duration_in: float = 0.3
) -> Array:
	var target := Node2D.new()
	target.name = "RW2DTarget"
	target.position = pos
	_runner.add_child(target)

	var effect := ProgressTransform2DJuiceEffect.new()
	effect.transform_target = target_type
	effect.position_rate = rate_pos
	effect.duration_in = duration_in

	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)

	var juice := Juice2D.new()
	juice.name = "RW_Juice2D"
	juice.recipe = recipe
	target.add_child(juice)

	return [juice, target]


# Creates a JuiceControl + Button rig at the given position.
# Returns [JuiceControl, Button].
func _create_control_rig_at(
		pos: Vector2,
		target_type: int = ProgressTransformControlJuiceEffect.TransformTarget.POSITION,
		rate_pos: Vector2 = Vector2(100.0, 0.0),
		duration_in: float = 0.3
) -> Array:
	var target := Button.new()
	target.name = "RWControlTarget"
	target.position = pos
	target.size = Vector2(80.0, 30.0)
	_runner.add_child(target)

	var effect := ProgressTransformControlJuiceEffect.new()
	effect.transform_target = target_type
	effect.position_rate = rate_pos
	effect.duration_in = duration_in

	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)

	var juice := JuiceControl.new()
	juice.name = "RW_JuiceControl"
	juice.recipe = recipe
	target.add_child(juice)

	return [juice, target]


# Creates a Juice3D + Node3D rig at the given position.
# Returns [Juice3D, Node3D].
func _create_3d_rig_at(
		pos: Vector3,
		target_type: int = ProgressTransform3DJuiceEffect.TransformTarget.POSITION,
		rate_pos: Vector3 = Vector3(100.0, 0.0, 0.0),
		duration_in: float = 0.3
) -> Array:
	var target := Node3D.new()
	target.name = "RW3DTarget"
	target.position = pos
	_runner.add_child(target)

	var effect := ProgressTransform3DJuiceEffect.new()
	effect.transform_target = target_type
	effect.position_rate = rate_pos
	effect.duration_in = duration_in

	var recipe := Juice3DRecipe.new()
	recipe.effects.append(effect)

	var juice := Juice3D.new()
	juice.name = "RW_Juice3D"
	juice.recipe = recipe
	target.add_child(juice)

	return [juice, target]


# =============================================================================
# PHASE A-1: REGISTRATION TESTS
# =============================================================================

## Verify ProgressTransform2DJuiceEffect is listed in Juice2DRecipe's
## inspector whitelist. Missing registration = invisible in the inspector.
func test_2d_registration() -> void:
	var recipe := Juice2DRecipe.new()
	var whitelist: String = recipe._CONCRETE_EFFECTS
	assert_true(
		whitelist.contains("ProgressTransform2DJuiceEffect"),
		"Juice2DRecipe._CONCRETE_EFFECTS must contain 'ProgressTransform2DJuiceEffect'. Got: " + whitelist
	)


## Verify ProgressTransformControlJuiceEffect is listed in JuiceControlRecipe's
## inspector whitelist.
func test_control_registration() -> void:
	var recipe := JuiceControlRecipe.new()
	var whitelist: String = recipe._CONCRETE_EFFECTS
	assert_true(
		whitelist.contains("ProgressTransformControlJuiceEffect"),
		"JuiceControlRecipe._CONCRETE_EFFECTS must contain 'ProgressTransformControlJuiceEffect'. Got: " + whitelist
	)


## Verify ProgressTransform3DJuiceEffect is listed in Juice3DRecipe's
## inspector whitelist.
func test_3d_registration() -> void:
	var recipe := Juice3DRecipe.new()
	var whitelist: String = recipe._CONCRETE_EFFECTS
	assert_true(
		whitelist.contains("ProgressTransform3DJuiceEffect"),
		"Juice3DRecipe._CONCRETE_EFFECTS must contain 'ProgressTransform3DJuiceEffect'. Got: " + whitelist
	)
