## SquashStretch2DJuiceEffect.gd
## ============================================================================
## WHAT: Classic squash & stretch scaling for Node2D targets with volume preservation.
## WHY: Provides organic, lively deformation feedback that follows the classic
##      animation principle of squash and stretch.
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Handle Control or Node3D targets — use SquashStretchControl/3DJuiceEffect.
## ============================================================================
##
## ARCHITECTURE:
## - Effects are Resources (not Nodes). The host Juice2D node ticks them.
## - Uses sin(progress * PI) curve — peaks at progress=0.5.
## - At progress=0.0 and 1.0: natural scale (no deformation).
## - At progress=0.5: maximum squash.
## - If preserve_volume=true, perpendicular axis expands as primary compresses.
##
## TYPICAL USAGE:
## - Landing impact: squash_axis = VERTICAL, squash_amount = 0.3, duration = 0.15
## - Bounce: squash_axis = VERTICAL, squash_amount = 0.2
## ============================================================================

@tool
class_name SquashStretch2DJuiceEffect
extends JuiceEffectBase


# =============================================================================
# ENUMS
# =============================================================================

## Which axis is the primary squash axis.
enum SquashAxis {
	VERTICAL,    ## Squash on Y, stretch on X (landing, pressing down)
	HORIZONTAL   ## Squash on X, stretch on Y (side impact)
}


# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Squash Stretch")

## How much to compress at peak (0.0 = no squash, 0.99 = maximum).
## Values are clamped to prevent scale inversion.
@export_range(0.0, 0.99) var squash_amount: float = 0.3

## Primary axis of squash.
@export var squash_axis: SquashAxis = SquashAxis.VERTICAL

## If true, expand perpendicular axis to preserve visual volume.
## Creates more organic, cartoon-like deformation.
@export var preserve_volume: bool = true


# =============================================================================
# INTERNAL STATE
# =============================================================================

## Captured base scale.
var _base_scale: Vector2 = Vector2.ONE

## Whether base has been captured.
var _has_base: bool = false


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

## Capture base scale when animation begins.
func _on_animate_start(target: Node) -> void:
	_capture_base(target)


## Apply squash/stretch deformation at the given progress.
## Uses sin(progress * PI) for a symmetric curve that peaks at 0.5.
func _apply_effect(progress: float, target: Node) -> void:
	var n2d := target as Node2D
	if n2d == null:
		return

	var squash_factor := sin(progress * PI)
	var new_scale := _base_scale

	if squash_axis == SquashAxis.VERTICAL:
		var y_multiplier := 1.0 - (squash_amount * squash_factor)
		new_scale.y = _base_scale.y * y_multiplier
		if preserve_volume:
			new_scale.x = _base_scale.x * (1.0 / y_multiplier)
	else:
		var x_multiplier := 1.0 - (squash_amount * squash_factor)
		new_scale.x = _base_scale.x * x_multiplier
		if preserve_volume:
			new_scale.y = _base_scale.y * (1.0 / x_multiplier)

	n2d.scale = new_scale


## Snap back to exact base scale to avoid floating point drift.
func _on_animate_out_complete(target: Node) -> void:
	var n2d := target as Node2D
	if n2d == null:
		return
	n2d.scale = _base_scale


## Restore target to natural (unmodified) state.
func _restore_to_natural(target: Node) -> void:
	var n2d := target as Node2D
	if n2d == null:
		return
	n2d.scale = _base_scale


## Reset cached base values when target changes.
func _invalidate_base_cache() -> void:
	_has_base = false


# =============================================================================
# HELPERS
# =============================================================================

## Capture base scale from target (once per animation cycle).
func _capture_base(target: Node) -> void:
	if _has_base:
		return
	var n2d := target as Node2D
	if n2d == null:
		return
	_base_scale = n2d.scale
	_has_base = true
