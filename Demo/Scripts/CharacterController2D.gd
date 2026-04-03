## CharacterController2D.gd
## ============================================================================
## WHAT: 2D platformer character controller with health system.
## WHY: Provides WASD movement, jumping, and damage handling for demo.
## SYSTEM: Juice Demo Character System
## DOES NOT: Handle animations - uses AnimatedSprite2D for direct control.
## ============================================================================

extends CharacterBody2D

# Exported configuration for easy demo tweaking
@export var max_hp: int = 5
@export var move_speed: float = 200.0
@export var jump_velocity: float = -400.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1

@export var damage_amount: int = 1

# Get references to child nodes
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Internal state
var current_hp: int

# Coyote time and jump buffering
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# Get the gravity from the project settings so you can sync with rigid body nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Animation tree parameters
var animation_state: AnimationNodeStateMachinePlayback
var is_jumping: bool = false

func _ready():
	# Initialize health
	current_hp = max_hp

func _physics_process(delta):
	# Handle jump buffering
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	
	# Update timers
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	if coyote_timer > 0:
		coyote_timer -= delta
	
	# Check if we should be able to jump (coyote time or jump buffer)
	var can_jump = is_on_floor() or coyote_timer > 0
	
	# Handle jumping
	if can_jump and jump_buffer_timer > 0:
		# Regular jump
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		is_jumping = true
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# Reset coyote timer when on ground
		coyote_timer = coyote_time
		is_jumping = false
	
	# Handle horizontal movement
	var direction = Input.get_axis("move_left", "move_right")
	velocity.x = direction * move_speed
	
	# Handle ducking when not jumping
	if not is_jumping and Input.is_action_pressed("move_down"):
		velocity.x = 0  # Stop movement when ducking
	
	move_and_slide()
	
	# Handle sprite flipping based on movement direction
	update_sprite_direction()
	
	# Update animations
	update_animations()

# Handle sprite flipping based on movement direction
func update_sprite_direction():
	if animated_sprite:
		# Flip sprite when moving left
		if velocity.x < -10:  # Moving left
			animated_sprite.flip_h = true
		elif velocity.x > 10:  # Moving right
			animated_sprite.flip_h = false

func update_animations():
	if not animated_sprite:
		return
	
	# Determine current state
	var new_animation = ""
	
	if is_jumping:
		new_animation = "jump"
	elif not is_jumping and Input.is_action_pressed("move_down") and is_on_floor():
		new_animation = "duck"
	elif abs(velocity.x) > 10 and is_on_floor():
		new_animation = "walk"
	else:
		new_animation = "idle"
	
	# Only change animation if it's different
	if animated_sprite.animation != new_animation:
		animated_sprite.play(new_animation)


func take_damage(amount: int):
	current_hp -= amount
	current_hp = max(0, current_hp)
	
	# Play hit animation
	if animated_sprite:
		animated_sprite.play("hit")
	
	# Handle death
	if current_hp <= 0:
		# For demo, just respawn - you could add game over logic here
		respawn()

func respawn():
	# Reset health and position
	current_hp = max_hp
	global_position = Vector2.ZERO  # Reset to origin or spawn point
	velocity = Vector2.ZERO

func heal(amount: int):
	current_hp += amount
	current_hp = min(max_hp, current_hp)
