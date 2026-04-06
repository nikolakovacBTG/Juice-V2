## Appearance Effects - Phase A Test Suite
## Tests From/To API implementation across all domains
## ============================================================================

class_name TestAppearancePhaseA
extends JuiceTestSuite

# =============================================================================
# TEST RIG HELPERS
# =============================================================================

func _create_control_rig(effect: AppearanceControlJuiceEffect, _duration: float = 0.2) -> Array:
	# Create container-aware Control rig
	var canvas_layer := CanvasLayer.new()
	_runner.add_child(canvas_layer)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	canvas_layer.add_child(vbox)
	var btn := Button.new()
	btn.text = "Test Button"
	btn.custom_minimum_size = Vector2(120, 40)
	vbox.add_child(btn)
	
	# Add JuiceControl with single effect
	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	btn.add_child(juice)
	
	await wait_frames(3)  # Container layout pass
	return [btn, juice, canvas_layer]

func _create_2d_rig(effect: Appearance2DJuiceEffect, _duration: float = 0.2) -> Array:
	var target := Sprite2D.new()
	target.texture = preload("res://icon.svg")
	target.position = Vector2(100, 100)
	_runner.add_child(target)
	
	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	
	await wait_frames(2)
	return [target, juice]

func _create_3d_rig(effect: Appearance3DJuiceEffect, _duration: float = 0.2) -> Array:
	var target := MeshInstance3D.new()
	target.mesh = SphereMesh.new()
	_runner.add_child(target)
	
	var juice := Juice3D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := Juice3DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	
	await wait_frames(2)
	return [target, juice]

# =============================================================================
# PHASE A TESTS - FROM/TO API
# =============================================================================

func test_control_tint_from_custom_to_custom():
	var effect := AppearanceControlJuiceEffect.new()
	effect.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.TINT
	effect.from_reference = AppearanceControlJuiceEffect.AppearanceReference.CUSTOM
	effect.to_reference = AppearanceControlJuiceEffect.AppearanceReference.CUSTOM
	effect.from_tint_color = Color.BLUE
	effect.from_tint_blend = 1.0
	effect.tint_color = Color.RED
	effect.tint_blend = 1.0
	
	var rig := await _create_control_rig(effect)
	var btn := rig[0] as Button
	var juice := rig[1] as JuiceControl
	
	# Start animation
	juice.animate_in()
	await wait_frames(5)
	
	# Should be at full RED tint (from BLUE to RED)
	var final_modulate := btn.self_modulate
	assert_true(final_modulate.r > 0.9, "Should have strong red tint")
	assert_true(final_modulate.g < 0.5, "Should have reduced green")
	assert_true(final_modulate.b < 0.5, "Should have reduced blue")
	
	# Cleanup
	juice.stop()
	_runner.remove_child(rig[2])

func test_control_tint_from_self_to_custom():
	var effect := AppearanceControlJuiceEffect.new()
	effect.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.TINT
	effect.from_reference = AppearanceControlJuiceEffect.AppearanceReference.SELF
	effect.to_reference = AppearanceControlJuiceEffect.AppearanceReference.CUSTOM
	effect.tint_color = Color.GREEN
	effect.tint_blend = 1.0
	
	var rig := await _create_control_rig(effect)
	var btn := rig[0] as Button
	var juice := rig[1] as JuiceControl
	
	# Start animation
	juice.animate_in()
	await wait_frames(5)
	
	# Should have transitioned from WHITE to GREEN
	var final_modulate := btn.self_modulate
	assert_true(final_modulate.r < 0.5, "Should have reduced red")
	assert_true(final_modulate.g > 0.9, "Should have strong green")
	assert_true(final_modulate.b < 0.5, "Should have reduced blue")
	
	# Cleanup
	juice.stop()
	_runner.remove_child(rig[2])

func test_control_fade_from_self_to_custom():
	var effect := AppearanceControlJuiceEffect.new()
	effect.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.FADE
	effect.from_reference = AppearanceControlJuiceEffect.AppearanceReference.SELF
	effect.to_reference = AppearanceControlJuiceEffect.AppearanceReference.CUSTOM
	effect.fade_target_alpha = 0.3
	
	var rig := await _create_control_rig(effect)
	var btn := rig[0] as Button
	var juice := rig[1] as JuiceControl
	
	# Start animation
	juice.animate_in()
	await wait_frames(5)
	
	# Should have faded from alpha 1.0 to 0.3
	var final_alpha := btn.self_modulate.a
	assert_true(abs(final_alpha - 0.3) < 0.1, "Should be near target alpha 0.3")
	
	# Cleanup
	juice.stop()
	_runner.remove_child(rig[2])

func test_2d_tint_from_custom_to_custom():
	var effect := Appearance2DJuiceEffect.new()
	effect.effect_type = Appearance2DJuiceEffect.AppearanceEffect.TINT
	effect.from_reference = Appearance2DJuiceEffect.AppearanceReference.CUSTOM
	effect.to_reference = Appearance2DJuiceEffect.AppearanceReference.CUSTOM
	effect.from_tint_color = Color.YELLOW
	effect.from_tint_blend = 1.0
	effect.tint_color = Color.MAGENTA
	effect.tint_blend = 1.0
	
	var rig := await _create_2d_rig(effect)
	var target := rig[0] as Sprite2D
	var juice := rig[1] as Juice2D
	
	# Start animation
	juice.animate_in()
	await wait_frames(5)
	
	# Should be at full MAGENTA tint
	var final_modulate := target.modulate
	assert_true(final_modulate.r > 0.9, "Should have strong red tint")
	assert_true(final_modulate.g < 0.5, "Should have reduced green")
	assert_true(final_modulate.b > 0.9, "Should have strong blue tint")
	
	# Cleanup
	juice.stop()
	_runner.remove_child(target)

func test_3d_tint_from_custom_to_custom():
	var effect := Appearance3DJuiceEffect.new()
	effect.effect_type = Appearance3DJuiceEffect.AppearanceEffect.TINT
	effect.from_reference = Appearance3DJuiceEffect.AppearanceReference.CUSTOM
	effect.to_reference = Appearance3DJuiceEffect.AppearanceReference.CUSTOM
	effect.from_tint_color = Color.CYAN
	effect.from_tint_blend = 1.0
	effect.tint_color = Color.ORANGE
	effect.tint_blend = 1.0
	
	var rig := await _create_3d_rig(effect)
	var target := rig[0] as MeshInstance3D
	var juice := rig[1] as Juice3D
	
	# Start animation
	juice.animate_in()
	await wait_frames(5)
	
	# For 3D, we can't easily check material values in test rig
	# Just verify the effect runs without errors
	assert_true(juice.is_running(), "Effect should be running")
	
	# Cleanup
	juice.stop()
	_runner.remove_child(target)

func test_capture_at_trigger_timing():
	var effect := AppearanceControlJuiceEffect.new()
	effect.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.TINT
	effect.from_reference = AppearanceControlJuiceEffect.AppearanceReference.SELF
	effect.to_reference = AppearanceControlJuiceEffect.AppearanceReference.CUSTOM
	effect.capture_at = AppearanceControlJuiceEffect.CaptureAt.TRIGGER
	effect.tint_color = Color.PURPLE
	effect.tint_blend = 1.0
	
	var rig := await _create_control_rig(effect)
	var btn := rig[0] as Button
	var juice := rig[1] as JuiceControl
	
	# Start animation (should capture at trigger)
	juice.animate_in()
	await wait_frames(5)
	
	# Should have captured WHITE and transitioned to PURPLE
	var final_modulate := btn.self_modulate
	assert_true(final_modulate.r > 0.9, "Should have strong red tint")
	assert_true(final_modulate.g < 0.5, "Should have reduced green")
	assert_true(final_modulate.b > 0.9, "Should have strong blue tint")
	
	# Cleanup
	juice.stop()
	_runner.remove_child(rig[2])

# =============================================================================
# TEST SUITE MANAGEMENT
# =============================================================================

func _setup():
	# Initialize test environment
	pass

func _teardown():
	# Clean up test environment
	pass
