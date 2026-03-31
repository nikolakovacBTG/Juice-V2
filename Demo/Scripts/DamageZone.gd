## DamageZone.gd
## ============================================================================
## WHAT: Hazard area that damages the player on contact.
## WHY: Provides damage system for spikes, pits, and environmental hazards.
## SYSTEM: Juice Demo Character System
## DOES NOT: Handle visual effects - just deals damage on contact.
## ============================================================================

extends Area2D

## Damage amount dealt to player per contact
@export var damage: int = 1
## Time between damage applications to prevent instant death
@export var damage_cooldown: float = 1.0

var can_damage: bool = true

func _ready():
	# Add to hazard group
	add_to_group("hazard")
	
	# Connect signals
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body is CharacterBody2D and body.has_method("take_damage") and can_damage:
		body.take_damage(damage)
		start_damage_cooldown()

func start_damage_cooldown():
	can_damage = false
	await get_tree().create_timer(damage_cooldown).timeout
	can_damage = true