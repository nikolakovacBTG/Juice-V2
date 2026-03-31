## ManualTest.gd
## ============================================================================
## WHAT: Simple manual test script for multiple chaining debug scene.
## WHY: Allows manual triggering of animations to observe bugs.
## SYSTEM: Juice V1 Testing
## DOES NOT: Auto-configure - you must set up recipe manually in inspector.
## ============================================================================

extends Control

func _ready():
	print("=== Multiple Chaining Manual Test Ready ===")
	print("MANUAL SETUP REQUIRED:")
	print("1. Select JuiceControl node")
	print("2. Create new JuiceControlRecipe resource")
	print("3. Add 4 effects: Transform (punch), Shake, SquashStretch, Appearance")
	print("4. Configure Transform: to_position=(80,0), from_reference=SELF, to_reference=CUSTOM")
	print("5. Configure Transform chain_to array: [Shake, SquashStretch, Appearance]")
	print("6. Configure Shake: position_strength=(0,0) (disabled)")
	print("7. Configure Appearance: effect_type=FADE, fade_target_alpha=0.0")
	print("8. Set all trigger_behaviour=PLAY_IN_ONLY")
	print("===========================================")
	print("SPACE: Trigger animate_in()")
	print("S: Call stop()")
	print("Expected: Position 80px, Alpha returns to 1.0 on stop")
	print("Actual bugs: Position 9600px, Alpha stays 0.0")
	print("===========================================")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var juice_control = $ImpactBtn/JuiceControl
		match event.keycode:
			KEY_SPACE:
				print("Triggering animate_in()...")
				if juice_control.recipe == null:
					print("ERROR: No recipe configured! See setup instructions above.")
					return
				juice_control.animate_in()
			KEY_S:
				print("Calling stop()...")
				juice_control.stop()
				await get_tree().process_frame
				var btn = $ImpactBtn
				print("After stop - Position: ", btn.position, " Alpha: ", btn.modulate.a)
