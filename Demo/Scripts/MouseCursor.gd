## MouseCursor.gd
## ============================================================================
## WHAT: Custom mouse cursor with USE/INSPECT actions.
## WHY: Provides visual feedback for mouse interactions with Juice utilities.
## SYSTEM: Juice Demo Interaction System
## DOES NOT: Handle interaction logic - Juice components handle clicks directly.
## ============================================================================

extends Node

## Sprite for the mouse cursor
@onready var cursor_sprite: Sprite2D = $CursorSprite

func _ready():
	# Hide default cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	# Set up cursor sprite
	if cursor_sprite:
		cursor_sprite.texture = create_cursor_texture()

func _input(event):
	if event is InputEventMouseMotion:
		# Update cursor position
		if cursor_sprite:
			cursor_sprite.global_position = event.global_position

func create_cursor_texture() -> ImageTexture:
	# Create a simple arrow cursor texture
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Draw a simple arrow shape (you can replace this with a proper texture)
	for y in range(16):
		for x in range(16):
			if (x == 0 and y == 0) or (x <= y and x < 8):
				image.set_pixel(x, y, Color.WHITE)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func _exit_tree():
	# Restore default cursor when this node is removed
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)