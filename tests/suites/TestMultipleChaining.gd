## TestMultipleChaining.gd
## Tests for multiple effects chained from a single source effect.
## Tests both completion chaining and preroll chaining with arrays.
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "multiple_chaining"


func get_test_methods() -> Array[String]:
	return [
		"test_impact_ensemble_multiple_chains",
		"test_transition_cascade_preroll",
		"test_empty_array_no_chaining",
		"test_sequencer_mode_multiple_chains",
	]


# =============================================================================
# TESTS - Realistic Use Cases
# =============================================================================

func test_impact_ensemble_multiple_chains() -> void:
	# REALISTIC: Impact effect where punch triggers shake + squash + screen flash simultaneously
	var target := create_control_target("ImpactBtn")
	
	# Create effects: Punch (primary) -> Shake + Squash + Flash (secondary)
	var punch := TransformControlJuiceEffect.new()
	var shake := ShakeControlJuiceEffect.new()
	var squash := SquashStretchControlJuiceEffect.new()
	var flash := AppearanceControlJuiceEffect.new()
	
	# Configure primary punch effect
	punch.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	punch.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	punch.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	punch.to_position = Vector2(80, 0)
	punch.to_position_in = JuiceControlTransformEffect.PositionIn.PIXELS
	punch.duration_in = 0.15
	punch.duration_out = 0.3
	punch.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	
	# Configure secondary effects
	# shake disabled for position test
	shake.transform_target = ShakeControlJuiceEffect.TransformTarget.POSITION
	shake.position_strength = Vector2(0, 0)  # Disabled
	shake.duration_in = 0.4
	shake.duration_out = 0.5
	shake.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	
	squash.squash_amount = 0.3
	squash.squash_axis = SquashStretchControlJuiceEffect.SquashAxis.HORIZONTAL
	squash.duration_in = 0.2
	squash.duration_out = 0.25
	squash.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	
	flash.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.FADE
	flash.fade_target_alpha = 0.0
	flash.duration_in = 0.1
	flash.duration_out = 0.4
	flash.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	
	# KEY TEST: Multiple chains from punch
	punch.chain_to = [shake, squash, flash]
	
	# Build recipe and juice
	var recipe := JuiceControlRecipe.new()
	recipe.effects = [punch, shake, squash, flash]
	
	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	target.add_child(juice)
	
	await wait_frames(2)
	
	# Start the impact ensemble
	juice.animate_in()
	await wait_frames(2)
	
	# During punch (before completion): position should be moving, alpha should be full
	assert_true(target.position.x > 20.0,
		"During punch: position.x (%.1f) should be moving right" % target.position.x)
	assert_equal(target.modulate.a, 1.0,
		"During punch: alpha should still be full (flash not started)")
	
	# Wait for punch to complete and secondary effects to start
	await wait_seconds(0.2)
	
	# Now secondary effects should be active: shake + squash + fade
	# Shake adds random motion, squash changes size, fade reduces alpha
	assert_true(target.modulate.a < 0.9,
		"After punch: alpha should be reduced (flash active)")
	# Position should be exactly at punch target (80px) with no shake
	assert_equal(target.position.x, 80.0,
		"After punch: position should be at target (no shake)")
	
	# Wait for all to complete
	await wait_seconds(0.6)
	
	# All effects completed: should be in "to" state (not natural)
	# Position should be exactly at punch target (80px) with no shake
	assert_equal(target.position.x, 80.0,
		"After completion: position should be at target (no shake)")
	# Alpha should be at target (0.0 for fade)
	assert_equal(target.modulate.a, 0.0,
		"After completion: alpha should be at target")
	
	# Test stop() returns to natural (PLAY_IN_ONLY effects don't support animate_out)
	juice.stop()
	await wait_frames(2)
	assert_equal(target.position.x, 0.0,
		"After stop: position should return to natural")
	assert_equal(target.modulate.a, 1.0,
		"After stop: alpha should return to natural")
	
	await cleanup(target)


func test_transition_cascade_preroll() -> void:
	# REALISTIC: Menu transition where slide triggers fade + scale 0.1s before completion
	var target := create_control_target("TransitionPanel")
	target.size = Vector2(200, 100)
	
	# Create effects: Slide (primary) -> Fade + Scale (secondary with preroll)
	var slide := TransformControlJuiceEffect.new()
	var fade := AppearanceControlJuiceEffect.new()
	var scale := TransformControlJuiceEffect.new()
	
	# Configure primary slide effect
	slide.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	slide.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	slide.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	slide.to_position = Vector2(-300, 0)
	slide.to_position_in = JuiceControlTransformEffect.PositionIn.PIXELS
	slide.duration_in = 0.5
	slide.duration_out = 0.4
	slide.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	
	# Configure secondary effects
	fade.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.FADE
	fade.fade_target_alpha = 1.0
	fade.duration_in = 0.3
	fade.duration_out = 0.3
	fade.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	
	scale.transform_target = TransformControlJuiceEffect.TransformTarget.SCALE
	scale.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	scale.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	scale.to_scale = Vector2(1.2, 1.2)
	scale.duration_in = 0.25
	scale.duration_out = 0.2
	scale.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	
	# KEY TEST: Multiple chains with preroll
	slide.chain_to = [fade, scale]
	slide.chained_preroll = 0.1  # Start 0.1s before slide completes
	
	# Build recipe and juice
	var recipe := JuiceControlRecipe.new()
	recipe.effects = [slide, fade, scale]
	
	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	target.add_child(juice)
	
	await wait_frames(2)
	
	# Start transition
	juice.animate_in()
	await wait_frames(2)
	
	# Initially only slide should affect position
	assert_true(target.position.x < -100.0,
		"During slide: position should be moving left")
	assert_equal(target.modulate.a, 1.0,
		"During slide: alpha should be 1 (fade not started yet)")
	
	# Wait for preroll time (0.5 - 0.1 = 0.4s)
	await wait_seconds(0.45)
	
	# Fade and scale should start via preroll while slide still playing
	assert_true(target.modulate.a > 0.5,
		"During preroll: alpha should be increasing (fade active)")
	assert_true(target.scale.x > 1.1,
		"During preroll: scale should be increasing (scale active)")
	# Slide should still be moving
	assert_true(target.position.x < -250.0,
		"During preroll: slide should still be moving")
	
	# Wait for all to complete
	await wait_seconds(0.3)
	
	# All effects completed: should be in "to" state
	# Position should be at slide target (-300px)
	assert_true(target.position.x < -250.0,
		"After completion: position should be at target")
	# Alpha should be at target (1.0 for fade in)
	assert_equal(target.modulate.a, 1.0,
		"After completion: alpha should be at target")
	# Scale should be at target (1.2x)
	assert_true(target.scale.x > 1.15,
		"After completion: scale should be at target")
	
	# Test stop() returns to natural (PLAY_IN_ONLY effects don't support animate_out)
	juice.stop()
	await wait_frames(2)
	assert_equal(target.position.x, 0.0,
		"After stop: position should return to natural")
	assert_equal(target.modulate.a, 1.0,
		"After stop: alpha should return to natural")
	assert_equal(target.scale.x, 1.0,
		"After stop: scale should return to natural")
	
	await cleanup(target)


func test_empty_array_no_chaining() -> void:
	# REALISTIC: Effects with empty chain_to should behave like no chaining
	var target := create_control_target("NoChainBtn")
	
	var effect1 := TransformControlJuiceEffect.new()
	var effect2 := TransformControlJuiceEffect.new()
	
	effect1.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect1.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect1.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect1.to_position = Vector2(50, 0)
	effect1.to_position_in = JuiceControlTransformEffect.PositionIn.PIXELS
	effect1.duration_in = 0.2
	effect1.chain_to = []  # Empty array
	effect1.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	
	effect2.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	effect2.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect2.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect2.to_position = Vector2(0, 50)
	effect2.to_position_in = JuiceControlTransformEffect.PositionIn.PIXELS
	effect2.duration_in = 0.2
	effect2.chain_to = []  # Empty array
	effect2.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	
	# Build recipe
	var recipe := JuiceControlRecipe.new()
	recipe.effects = [effect1, effect2]
	
	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	target.add_child(juice)
	
	await wait_frames(2)
	
	# Both should play simultaneously (no chaining)
	juice.animate_in()
	await wait_frames(2)
	
	# Both effects should be active simultaneously
	assert_true(target.position.x > 20.0,
		"Effect1 should be moving right")
	assert_true(target.position.y > 20.0,
		"Effect2 should be moving down")
	
	await wait_seconds(0.25)
	
	# Both should have completed and be in "to" state
	assert_true(target.position.x > 40.0,
		"After completion: position.x should be at target")
	assert_true(target.position.y > 40.0,
		"After completion: position.y should be at target")
	
	# Test stop() returns to natural (PLAY_IN_ONLY effects don't support animate_out)
	juice.stop()
	await wait_frames(2)
	assert_equal(target.position.x, 0.0,
		"After stop: position.x should return to natural")
	assert_equal(target.position.y, 0.0,
		"After stop: position.y should return to natural")
	
	await cleanup(target)


func test_sequencer_mode_multiple_chains() -> void:
	# REALISTIC: UI menu items where selecting one triggers effects on others
	var parent := create_control_target("MenuContainer")
	
	# Create multiple buttons
	var btn1 := Button.new()
	btn1.text = "Option 1"
	btn1.position = Vector2(0, 0)
	var btn2 := Button.new()
	btn2.text = "Option 2"
	btn2.position = Vector2(0, 40)
	var btn3 := Button.new()
	btn3.text = "Option 3"
	btn3.position = Vector2(0, 80)
	
	parent.add_child(btn1)
	parent.add_child(btn2)
	parent.add_child(btn3)
	
	# Create effects for btn1 (primary) that chains to effects on btn2 and btn3
	var primary := TransformControlJuiceEffect.new()
	var secondary1 := AppearanceControlJuiceEffect.new()
	var secondary2 := AppearanceControlJuiceEffect.new()
	
	primary.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	primary.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	primary.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	primary.to_position = Vector2(20, 0)
	primary.to_position_in = JuiceControlTransformEffect.PositionIn.PIXELS
	primary.duration_in = 0.2
	primary.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	
	secondary1.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.TINT
	secondary1.tint_color = Color.YELLOW
	secondary1.duration_in = 0.3
	secondary1.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	
	secondary2.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.TINT
	secondary2.tint_color = Color.CYAN
	secondary2.duration_in = 0.3
	secondary2.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	
	# KEY TEST: Multiple chains in SEQUENCER mode
	primary.chain_to = [secondary1, secondary2]
	
	# Build recipe
	var recipe := JuiceControlRecipe.new()
	recipe.effects = [primary, secondary1, secondary2]
	
	# Configure sequencer
	var juice := JuiceControl.new()
	juice.mode = JuiceBase.Mode.SEQUENCER
	juice.target_scope = JuiceBase.TargetScope.CHILDREN
	juice.sequence_type = JuiceBase.SequenceType.ALL_AT_ONCE
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.recipe = recipe
	parent.add_child(juice)
	
	await wait_frames(2)
	
	# Start sequence
	juice.animate_in()
	
	# Wait for completion
	await wait_seconds(0.5)
	
	# All should have completed successfully
	assert_true(btn1.position.x > 15.0,
		"Btn1 should have moved to target position")
	# Tint effect multiplies color, so check if it's tinted (not exact match)
	assert_true(btn2.modulate.r > 0.5 and btn2.modulate.g > 0.5,
		"Btn2 should be tinted yellow")
	assert_true(btn3.modulate.g > 0.5 and btn3.modulate.b > 0.5,
		"Btn3 should be tinted cyan")
	
	# Test stop() returns to natural (PLAY_IN_ONLY effects don't support animate_out)
	juice.stop()
	await wait_frames(2)
	assert_equal(btn1.position.x, 0.0,
		"After stop: Btn1 should return to natural")
	assert_equal(btn2.modulate, Color.WHITE,
		"After stop: Btn2 should return to natural")
	assert_equal(btn3.modulate, Color.WHITE,
		"After stop: Btn3 should return to natural")
	
	await cleanup(parent)
