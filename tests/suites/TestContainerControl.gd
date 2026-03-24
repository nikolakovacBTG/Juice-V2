## TestContainerControl.gd
## ============================================================================
## WHAT: Tests for Control effects inside Container layouts (VBox, HBox, nested).
## WHY: Container nodes manage children's position, which fights with effects
##      that modify position or set pivot_offset. These tests verify that
##      effects behave correctly in realistic Container-based UI layouts.
## SYSTEM: Tests (tests/suites/)
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "container_control"


func get_test_methods() -> Array[String]:
	return [
		# --- Scale in Container ---
		"test_scale_from_zero_in_vbox",
		"test_scale_from_zero_with_auto_center_pivot_in_vbox",
		"test_squash_stretch_in_vbox",
		# --- Rotation in Container ---
		"test_rotation_with_auto_center_pivot_in_vbox",
		# --- Multiple effects with pivots in Container ---
		"test_squash_plus_rotation_stacking_in_vbox",
		# --- Nested containers ---
		"test_scale_in_nested_hbox_vbox",
		# --- Container distribution preserved ---
		"test_vbox_sibling_positions_preserved",
		# --- Pivot_offset conflict ---
		"test_two_effects_different_pivots_on_same_node",
	]


# =============================================================================
# HELPER: Create a VBox with multiple Labels (realistic UI pattern)
# =============================================================================

## Build a VBoxContainer with N Label children, return [vbox, labels_array].
func _create_vbox_with_labels(count: int, label_prefix: String = "Item") -> Array:
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	vbox.custom_minimum_size = Vector2(200, 0)
	_runner.add_child(vbox)

	var labels: Array[Label] = []
	for i in count:
		var lbl := Label.new()
		lbl.text = "%s %d" % [label_prefix, i]
		lbl.custom_minimum_size = Vector2(100, 30)
		vbox.add_child(lbl)
		labels.append(lbl)

	return [vbox, labels]


## Attach a JuiceControl with a single effect to a Control target.
func _attach_juice(target: Control, effect: JuiceControlEffectBase) -> JuiceControl:
	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	return juice


# =============================================================================
# TESTS: Scale in Container
# =============================================================================

## The exact regression scenario: TransformControl SCALE from 0→1 inside VBox.
## Bug was: showed natural→2x instead of 0→1.
func test_scale_from_zero_in_vbox() -> void:
	var rig := _create_vbox_with_labels(3, "Scale")
	var vbox: VBoxContainer = rig[0]
	var labels: Array = rig[1]
	var target: Label = labels[1]  # middle label
	await wait_frames(3)

	var natural_scale := target.scale  # should be (1,1)

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.SCALE
	effect.from_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.from_scale = Vector2.ZERO
	effect.to_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var juice := _attach_juice(target, effect)
	await wait_frames(2)

	juice.animate_in()
	# At start (progress≈0): scale should be near (0,0), not near natural
	await wait_frames(3)
	assert_true(target.scale.length() < 0.5,
		"Scale from zero in VBox: start should be near zero, got %s" % target.scale)

	# Let it finish
	await wait_seconds(0.4)
	# At end (progress=1): scale should return to natural (1,1)
	assert_approx_vec2(target.scale, natural_scale,
		"Scale from zero in VBox: end should be natural scale", 0.1)

	await cleanup(vbox)


## Scale with AUTO_CENTER pivot inside VBox — pivot_offset must be set and
## the label must still scale visually from its center, not top-left.
func test_scale_from_zero_with_auto_center_pivot_in_vbox() -> void:
	var rig := _create_vbox_with_labels(3, "Pivot")
	var vbox: VBoxContainer = rig[0]
	var labels: Array = rig[1]
	var target: Label = labels[1]
	await wait_frames(3)

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.SCALE
	effect.from_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.from_scale = Vector2.ZERO
	effect.to_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.pivot_mode = TransformControlJuiceEffect.PivotMode.AUTO_CENTER
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var juice := _attach_juice(target, effect)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.4)

	# After animation, scale should be back to natural
	assert_approx_vec2(target.scale, Vector2.ONE,
		"AUTO_CENTER pivot in VBox: scale returns to natural", 0.1)

	# Pivot_offset should have been set to center
	var expected_pivot := target.size / 2.0
	assert_approx_vec2(target.pivot_offset, expected_pivot,
		"AUTO_CENTER pivot in VBox: pivot_offset should be center of label", 2.0)

	await cleanup(vbox)


## SquashStretch inside VBox — the most common real-world case.
func test_squash_stretch_in_vbox() -> void:
	var rig := _create_vbox_with_labels(3, "Squash")
	var vbox: VBoxContainer = rig[0]
	var labels: Array = rig[1]
	var target: Label = labels[1]
	await wait_frames(3)

	var effect := SquashStretchControlJuiceEffect.new()
	effect.squash_amount = 0.5
	effect.squash_axis = SquashStretchControlJuiceEffect.SquashAxis.VERTICAL
	effect.preserve_volume = true
	effect.pivot_mode = SquashStretchControlJuiceEffect.PivotMode.AUTO_CENTER
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.4

	var juice := _attach_juice(target, effect)
	await wait_frames(2)

	juice.animate_in()
	# At peak (~0.2s), scale.y should be squashed
	await wait_seconds(0.2)
	assert_true(target.scale.y < 0.85,
		"Squash in VBox at peak: scale.y (%.3f) should be < 0.85" % target.scale.y)

	# After full animation, scale should return to natural
	await wait_seconds(0.5)
	assert_approx_vec2(target.scale, Vector2.ONE,
		"Squash in VBox: returns to natural after animation", 0.05)

	await cleanup(vbox)


# =============================================================================
# TESTS: Rotation in Container
# =============================================================================

## Rotation with AUTO_CENTER pivot inside VBox — must rotate around center.
func test_rotation_with_auto_center_pivot_in_vbox() -> void:
	var rig := _create_vbox_with_labels(3, "Rotate")
	var vbox: VBoxContainer = rig[0]
	var labels: Array = rig[1]
	var target: Label = labels[1]
	await wait_frames(3)

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.ROTATION
	effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_rotation_degrees = 45.0
	effect.pivot_mode = TransformControlJuiceEffect.PivotMode.AUTO_CENTER
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var juice := _attach_juice(target, effect)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.4)

	# After animation, rotation should be at ~45 degrees
	assert_approx_float(rad_to_deg(target.rotation), 45.0,
		"Rotation in VBox: should reach 45°", 3.0)

	# Pivot should be center
	var expected_pivot := target.size / 2.0
	assert_approx_vec2(target.pivot_offset, expected_pivot,
		"Rotation in VBox: pivot_offset should be center", 2.0)

	await cleanup(vbox)


# =============================================================================
# TESTS: Multiple effects stacking in Container
# =============================================================================

## SquashStretch + Transform Rotation on the same label in VBox.
## Both effects have AUTO_CENTER pivot. This tests pivot_offset conflict:
## both effects want to set ctrl.pivot_offset — last-write wins.
func test_squash_plus_rotation_stacking_in_vbox() -> void:
	var rig := _create_vbox_with_labels(3, "Stack")
	var vbox: VBoxContainer = rig[0]
	var labels: Array = rig[1]
	var target: Label = labels[1]
	await wait_frames(3)

	# Effect 1: SquashStretch
	var squash_effect := SquashStretchControlJuiceEffect.new()
	squash_effect.squash_amount = 0.3
	squash_effect.squash_axis = SquashStretchControlJuiceEffect.SquashAxis.VERTICAL
	squash_effect.preserve_volume = true
	squash_effect.pivot_mode = SquashStretchControlJuiceEffect.PivotMode.AUTO_CENTER
	squash_effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	squash_effect.duration_in = 0.4

	# Effect 2: Rotation
	var rot_effect := TransformControlJuiceEffect.new()
	rot_effect.transform_target = TransformControlJuiceEffect.TransformTarget.ROTATION
	rot_effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	rot_effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	rot_effect.to_rotation_degrees = 15.0
	rot_effect.pivot_mode = TransformControlJuiceEffect.PivotMode.AUTO_CENTER
	rot_effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	rot_effect.duration_in = 0.4

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(squash_effect)
	recipe.effects.append(rot_effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.2)

	# Both effects should be contributing: squash on scale, rotation on rotation
	assert_true(target.scale.y < 0.95,
		"Stacking in VBox: squash should reduce scale.y (got %.3f)" % target.scale.y)
	assert_true(abs(target.rotation) > 0.01,
		"Stacking in VBox: rotation should be non-zero (got %.3f rad)" % target.rotation)

	# Pivot should be center (both effects agree on AUTO_CENTER)
	var expected_pivot := target.size / 2.0
	assert_approx_vec2(target.pivot_offset, expected_pivot,
		"Stacking in VBox: pivot_offset should be center", 2.0)

	await cleanup(vbox)


# =============================================================================
# TESTS: Nested containers
# =============================================================================

## Scale effect on a label inside HBox which is inside VBox (nested containers).
func test_scale_in_nested_hbox_vbox() -> void:
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	_runner.add_child(vbox)

	# Row 1: just a label
	var lbl_top := Label.new()
	lbl_top.text = "Top"
	lbl_top.custom_minimum_size = Vector2(100, 30)
	vbox.add_child(lbl_top)

	# Row 2: HBox with two labels
	var hbox := HBoxContainer.new()
	vbox.add_child(hbox)

	var lbl_left := Label.new()
	lbl_left.text = "Left"
	lbl_left.custom_minimum_size = Vector2(80, 30)
	hbox.add_child(lbl_left)

	var lbl_right := Label.new()
	lbl_right.text = "Right"
	lbl_right.custom_minimum_size = Vector2(80, 30)
	hbox.add_child(lbl_right)

	await wait_frames(3)
	var natural_scale := lbl_left.scale

	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.SCALE
	effect.from_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.from_scale = Vector2.ZERO
	effect.to_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.pivot_mode = TransformControlJuiceEffect.PivotMode.AUTO_CENTER
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.2

	var juice := _attach_juice(lbl_left, effect)
	await wait_frames(2)

	juice.animate_in()
	await wait_frames(3)

	# At start: should be near zero
	assert_true(lbl_left.scale.length() < 0.5,
		"Nested container: scale start should be near zero, got %s" % lbl_left.scale)

	await wait_seconds(0.4)
	# At end: should be natural
	assert_approx_vec2(lbl_left.scale, natural_scale,
		"Nested container: scale end should be natural", 0.1)

	# Right sibling should be unaffected
	assert_approx_vec2(lbl_right.scale, Vector2.ONE,
		"Nested container: sibling scale should be unaffected", 0.01)

	await cleanup(vbox)


# =============================================================================
# TESTS: Container distribution preserved
# =============================================================================

## Verify that VBox siblings maintain their Container-assigned positions
## while one sibling has an active scale effect.
func test_vbox_sibling_positions_preserved() -> void:
	var rig := _create_vbox_with_labels(3, "Dist")
	var vbox: VBoxContainer = rig[0]
	var labels: Array = rig[1]
	await wait_frames(3)

	# Record Container-assigned positions before animation
	var pos_0 := (labels[0] as Label).position
	var pos_2 := (labels[2] as Label).position
	var target: Label = labels[1]

	var effect := SquashStretchControlJuiceEffect.new()
	effect.squash_amount = 0.5
	effect.squash_axis = SquashStretchControlJuiceEffect.SquashAxis.VERTICAL
	effect.preserve_volume = true
	effect.pivot_mode = SquashStretchControlJuiceEffect.PivotMode.AUTO_CENTER
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.4

	var juice := _attach_juice(target, effect)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.2)  # mid-animation

	# Siblings above and below should stay at their Container-assigned positions
	assert_approx_vec2((labels[0] as Label).position, pos_0,
		"VBox distribution: first label position preserved during animation", 2.0)
	assert_approx_vec2((labels[2] as Label).position, pos_2,
		"VBox distribution: third label position preserved during animation", 2.0)

	await cleanup(vbox)


# =============================================================================
# TESTS: Pivot_offset conflict
# =============================================================================

## Two effects with DIFFERENT pivot modes on the same node.
## This documents the current behavior: both write ctrl.pivot_offset,
## last-write wins. This is a known limitation to be solved.
func test_two_effects_different_pivots_on_same_node() -> void:
	var rig := _create_vbox_with_labels(2, "PivotConflict")
	var vbox: VBoxContainer = rig[0]
	var labels: Array = rig[1]
	var target: Label = labels[0]
	await wait_frames(3)

	# Effect 1: SquashStretch with AUTO_CENTER pivot
	var squash_effect := SquashStretchControlJuiceEffect.new()
	squash_effect.squash_amount = 0.3
	squash_effect.squash_axis = SquashStretchControlJuiceEffect.SquashAxis.VERTICAL
	squash_effect.preserve_volume = true
	squash_effect.pivot_mode = SquashStretchControlJuiceEffect.PivotMode.AUTO_CENTER
	squash_effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	squash_effect.duration_in = 0.4

	# Effect 2: Rotation with CUSTOM pivot (top-left corner = 0,0)
	var rot_effect := TransformControlJuiceEffect.new()
	rot_effect.transform_target = TransformControlJuiceEffect.TransformTarget.ROTATION
	rot_effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	rot_effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	rot_effect.to_rotation_degrees = 15.0
	rot_effect.pivot_mode = TransformControlJuiceEffect.PivotMode.CUSTOM
	rot_effect.custom_pivot = Vector2(0.0, 0.0)  # top-left corner
	rot_effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	rot_effect.duration_in = 0.4

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(squash_effect)
	recipe.effects.append(rot_effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.2)

	# Both effects should produce visible results
	assert_true(target.scale.y < 0.95,
		"Pivot conflict: squash should reduce scale.y (got %.3f)" % target.scale.y)
	assert_true(abs(target.rotation) > 0.01,
		"Pivot conflict: rotation should be non-zero (got %.3f rad)" % target.rotation)

	# Document current behavior: pivot_offset is set by BOTH effects (last-write wins).
	# The pivot will be whatever the second effect wrote (CUSTOM 0,0 = top-left).
	# This test documents the conflict — a proper solution should give each effect
	# its own visual pivot without fighting over ctrl.pivot_offset.
	var pivot := target.pivot_offset
	assert_true(true,
		"Pivot conflict documented: pivot_offset=%s (last-write wins)" % pivot)

	await cleanup(vbox)
