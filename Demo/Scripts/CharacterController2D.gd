## CharacterController2D.gd
## ============================================================================
## WHAT: 2D platformer character controller with ladder climbing and health system.
## WHY: Provides WASD movement, jumping, climbing, and damage handling for demo.
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
var is_on_ladder: bool = false
var ladder_area: Area2D = null

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
	
	# CharacterBody2D doesn't have area_entered, we'll use the ladder's own signals

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
	var can_jump = is_on_floor() or coyote_timer > 0 or is_on_ladder
	
	# Handle jumping
	if can_jump and jump_buffer_timer > 0:
		if is_on_ladder:
			# Jump off ladder
			is_on_ladder = false
			velocity.y = jump_velocity
		else:
			# Regular jump
			velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		is_jumping = true
	
	# Apply gravity (only when not on ladder)
	if not is_on_ladder:
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			# Reset coyote timer when on ground
			coyote_timer = coyote_time
			is_jumping = false
	
	# Handle ladder climbing
	if is_on_ladder and ladder_area:
		var vertical_input = Input.get_axis("move_up", "move_down")
		velocity.y = vertical_input * move_speed * 0.8  # Slower climbing speed
		velocity.x = 0  # No horizontal movement on ladder
	else:
		# Handle horizontal movement
		var direction = Input.get_axis("move_left", "move_right")
		velocity.x = direction * move_speed
	
	# Handle ducking when not on ladder and not jumping
	if not is_on_ladder and not is_jumping and Input.is_action_pressed("move_down"):
		velocity.x = 0  # Stop movement when ducking
	
	move_and_slide()
	
	# Check for area overlaps (ladders and damage zones)
	check_area_overlaps()
	
	# Handle sprite flipping based on movement direction
	update_sprite_direction()
	
	# Update animations
	update_animations()

func check_area_overlaps():
	# Simple proximity check for ladder (since CharacterBody2D can't detect areas)
	# This is a basic implementation - for production, use an Area2D child
	if ladder_area and global_position.distance_to(ladder_area.global_position) < 50:
		if not is_on_ladder:
			is_on_ladder = true
			velocity.y = 0
	elif is_on_ladder:
		is_on_ladder = false
		ladder_area = null

# Simple ladder detection function to call from ladder script
func set_ladder_area(area: Area2D):
	ladder_area = area

func clear_ladder_area():
	if ladder_area:
		ladder_area = null
		is_on_ladder = false

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
	
	if is_on_ladder:
		if abs(velocity.y) > 10:
			new_animation = "climb"
		else:
			new_animation = "climb"  # Use climb for idle on ladder too
	elif not is_on_floor() and velocity.y < 0:
		new_animation = "jump"  # You may need to add this animation
	elif not is_on_floor() and velocity.y > 0:
		new_animation = "front"  # Use front for falling
	elif abs(velocity.x) > 10:
		new_animation = "walk"  # You may need to add this animation
	elif Input.is_action_pressed("move_down") and is_on_floor():
		new_animation = "duck"
	else:
		new_animation = "front"  # Use front as idle
	
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
