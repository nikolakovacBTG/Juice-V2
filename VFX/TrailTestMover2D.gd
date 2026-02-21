## TrailTestMover2D.gd
## ============================================================================
## WHAT: Simple oscillating movement for 2D trail test elements.
## WHY: Demonstrates 2D trail effects by moving the parent Control in a pattern.
## SYSTEM: Test utility (addons/juice/VFX/)
## DOES NOT: Affect gameplay - this is purely for VFX testing demonstrations.
## ============================================================================

class_name TrailTestMover2D
extends Node

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Movement")

## Movement speed multiplier
@export var speed: float = 2.0

## Movement amplitude in pixels
@export var amplitude: Vector2 = Vector2(50, 20)

## If true, starts moving immediately
@export var auto_start: bool = true

@export_group("Debug")

## Enable debug logging
@export var debug_enabled: bool = false

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _is_moving: bool = false
var _time: float = 0.0
var _start_position: Vector2 = Vector2.ZERO

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Store starting position
	var parent := get_parent()
	if parent is Control:
		_start_position = (parent as Control).position
	elif parent is Node2D:
		_start_position = (parent as Node2D).position
	
	if auto_start:
		_is_moving = true
	
	if debug_enabled:
		print("[TrailTestMover2D] Ready - auto_start: %s, amplitude: %s" % [auto_start, amplitude])


func _process(delta: float) -> void:
	if not _is_moving:
		return
	
	_time += delta * speed
	
	var parent := get_parent()
	if parent == null:
		return
	
	# Figure-8 pattern
	var new_pos := _start_position + Vector2(
		sin(_time) * amplitude.x,
		sin(_time * 2) * amplitude.y
	)
	
	if parent is Control:
		(parent as Control).position = new_pos
	elif parent is Node2D:
		(parent as Node2D).position = new_pos


func start_moving() -> void:
	_is_moving = true


func stop_moving() -> void:
	_is_moving = false
