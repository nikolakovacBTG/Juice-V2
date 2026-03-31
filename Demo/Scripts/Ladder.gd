## Ladder.gd
## ============================================================================
## WHAT: Climbable ladder prefab for 2D platformer.
## WHY: Provides area detection for character climbing mechanics.
## SYSTEM: Juice Demo Character System
## DOES NOT: Handle visual sprites - just provides collision and detection.
## ============================================================================

extends Area2D

func _ready():
	# Add to ladder group for easy identification
	add_to_group("ladder")
	
	# Set up collision
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body is CharacterBody2D:
		print("Player entered ladder")

func _on_body_exited(body):
	if body is CharacterBody2D:
		print("Player exited ladder")