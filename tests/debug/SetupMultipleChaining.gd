## SetupMultipleChaining.gd
## ============================================================================
## WHAT: Debug script to set up multiple chaining test configuration.
## WHY: Creates the failing test case manually for editor testing.
## SYSTEM: Juice V1 Testing
## DOES NOT: Replace automated tests - just for manual debugging.
## =============================================================================

extends Node

func _ready():
	# Find the JuiceControl node
	var juice_control = $Root/ImpactBtn/JuiceControl
	if not juice_control:
		print("ERROR: JuiceControl node not found")
		return
	
	# Create the failing configuration from the test
	var recipe := JuiceControlRecipe.new()
	
	# Create effects: Punch (primary) -> Shake + Squash + Flash (secondary)
	var punch := TransformControlJuiceEffect.new()
	var shake := ShakeControlJuiceEffect.new()
	var squash := SquashStretchControlJuiceEffect.new()
	var flash := AppearanceControlJuiceEffect.new()
	
	# Configure primary punch effect (same as test)
	punch.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	punch.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	punch.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	punch.to_position = Vector2(80, 0)
	punch.duration_in = 0.15
	punch.duration_out = 0.3
	punch.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	
	# Configure secondary effects
	shake.transform_target = ShakeControlJuiceEffect.TransformTarget.POSITION
	shake.position_strength = Vector2(0, 0)  # Disabled to isolate position bug
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
	
	# Build recipe
	recipe.effects = [punch, shake, squash, flash]
	
	# Assign to juice
	juice_control.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice_control.recipe = recipe
	
	print("=== Multiple Chaining Debug Setup Complete ===")
	print("Position should be 80px after punch, but test shows 9600px")
	print("Flash alpha should return to 1.0 on stop(), but stays 0.0")
	print("Press SPACE to trigger animate_in(), press S to stop()")
	print("===========================================")

func _input(event: InputEvent) -> void:
	var juice_control = $Root/ImpactBtn/JuiceControl
	if not juice_control:
		return
		
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				print("Triggering animate_in()...")
				juice_control.animate_in()
			KEY_S:
				print("Calling stop()...")
				juice_control.stop()
				# Print actual values after stop
				await get_tree().process_frame
				var btn = $Root/ImpactBtn
				print("After stop - Position: ", btn.position, " Alpha: ", btn.modulate.a)
