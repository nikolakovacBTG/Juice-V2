## SquashStretch2DJuiceComp.gd
## ============================================================================
## WHAT: Classic animation squash & stretch with volume preservation.
## WHY: Provides organic, lively deformation feedback that follows the classic
##      animation principle of squash and stretch.
## SYSTEM: Juicing System (addons/juice/)
## DOES NOT: Handle 3D deformation, bone/skeletal squash, or physics-based
##           soft body simulation.
## ============================================================================
##
## BEHAVIOR:
## - Uses sin(progress * PI) curve - peaks at progress=0.5
## - At progress=0.0 and 1.0: natural scale (no deformation)
## - At progress=0.5: maximum squash
## - If preserve_volume=true, perpendicular axis expands as primary compresses
##
## TYPICAL USAGE:
## - Landing impact: Squash on Y, expand on X momentarily
## - Jump anticipation: Smaller squash on Y, compress on X
## - Button press: Quick squash and return
##
## EXAMPLES:
## - Landing squash: squash_axis = VERTICAL, squash_amount = 0.3, duration = 0.15
## - Bounce: squash_axis = VERTICAL, squash_amount = 0.2
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBase2D.svg")
class_name SquashStretch2DJuiceComp
extends JuiceCompBase

# =============================================================================
# ENUMS
# =============================================================================

## Which axis is the primary squash axis
enum SquashAxis {
	VERTICAL,    ## Squash on Y, stretch on X (landing, pressing down)
	HORIZONTAL   ## Squash on X, stretch on Y (side impact)
}

# =============================================================================
# SQUASH STRETCH CONFIGURATION
# =============================================================================

@export_group("Squash Stretch")

## How much to compress at peak (0.0 = no squash, 0.99 = maximum)
## Values are clamped to prevent scale inversion
@export_range(0.0, 0.99) var squash_amount: float = 0.3

## Primary axis of squash
@export var squash_axis: SquashAxis = SquashAxis.VERTICAL

## If true, expand perpendicular axis to preserve visual volume
## Creates more organic, cartoon-like deformation
@export var preserve_volume: bool = true

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Captured base scale
var _base_scale: Vector2 = Vector2.ONE

## Whether base has been captured
var _has_base_scale: bool = false

# =============================================================================
# LIFECYCLE OVERRIDES
# =============================================================================

func _ready() -> void:
	super._ready()


## Called when animation begins
func _on_animate_start() -> void:
	_capture_base_scale()
	
	if debug_enabled:
		print("[%s] SquashStretch start. Base: %s, Amount: %.2f, Axis: %s, Preserve: %s" % [
			name, _base_scale, squash_amount, SquashAxis.keys()[squash_axis], preserve_volume
		])


## Called each frame to apply squash/stretch
func _apply_effect(progress: float) -> void:
	var target := _get_target_node_2d()
	if target == null:
		return
	
	# Use sin(progress * PI) for symmetric squash curve
	# This gives: 0 at progress=0, 1 at progress=0.5, 0 at progress=1
	var squash_factor := sin(progress * PI)
	
	# Calculate scale modification
	var new_scale := _base_scale
	
	if squash_axis == SquashAxis.VERTICAL:
		# Squash Y axis
		var y_multiplier := 1.0 - (squash_amount * squash_factor)
		new_scale.y = _base_scale.y * y_multiplier
		
		if preserve_volume:
			# Expand X to preserve area (inverse relationship)
			# If Y shrinks to 0.7, X expands to ~1.43 (1/0.7)
			var x_multiplier := 1.0 / y_multiplier
			new_scale.x = _base_scale.x * x_multiplier
	else:
		# Squash X axis
		var x_multiplier := 1.0 - (squash_amount * squash_factor)
		new_scale.x = _base_scale.x * x_multiplier
		
		if preserve_volume:
			var y_multiplier := 1.0 / x_multiplier
			new_scale.y = _base_scale.y * y_multiplier
	
	target.scale = new_scale
	
	if debug_enabled:
		print("[%s] SquashStretch progress=%.2f, factor=%.2f, scale=%s" % [
			name, progress, squash_factor, new_scale
		])


## Called when animate_out completes - return to base scale
func _on_animate_out_complete() -> void:
	var target := _get_target_node_2d()
	if target != null:
		target.scale = _base_scale
	
	if debug_enabled:
		print("[%s] SquashStretch complete, returned to base: %s" % [name, _base_scale])


## Called when target changes
func _invalidate_base_cache() -> void:
	_has_base_scale = false
	if debug_enabled:
		print("[%s] Base scale cache invalidated" % name)


# =============================================================================
# SEQUENCER RECIPE CONTRACT
# =============================================================================

func _recipe_capture_natural(target: Node) -> Variant:
	if target is Node2D:
		return {"scale": (target as Node2D).scale}
	return null


func _recipe_apply_natural(target: Node, natural: Variant) -> void:
	if not (natural is Dictionary) or not (target is Node2D):
		return
	var dict := natural as Dictionary
	(target as Node2D).scale = dict.get("scale", Vector2.ONE) as Vector2


func _recipe_restore_natural(target: Node, natural: Variant) -> void:
	_recipe_apply_natural(target, natural)

# =============================================================================
# INTERNAL HELPERS
# =============================================================================

## Capture base scale from target
func _capture_base_scale() -> void:
	if _has_base_scale:
		return
	
	var target := _get_target_node_2d()
	if target == null:
		if debug_enabled:
			push_warning("[%s] Cannot capture base scale - no valid Node2D target" % name)
		return
	
	_base_scale = target.scale
	
	_has_base_scale = true
	
	if debug_enabled:
		print("[%s] Captured base scale: %s" % [name, _base_scale])


func _get_target_node_2d() -> Node2D:
	if not is_instance_valid(_target_node):
		return null
	if _target_node is Node2D:
		return _target_node as Node2D
	if debug_enabled:
		push_warning("[%s] Target '%s' is not Node2D" % [name, _target_node.name])
	return null

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent := get_parent()
	if parent and not parent is Node2D:
		warnings.append("Parent must be a Node2D node. Use SquashStretchControl/3D for other domains.")
	return warnings
