## SquashStretch3DJuiceEffect.gd
## ============================================================================
## WHAT: Classic 3D squash and stretch with optional volume preservation.
## WHY: Provides organic deformation feedback for 3D objects (bounces, impacts,
##      breathing motion) while maintaining volume.
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Handle Control or Node2D targets — use SquashStretchControl/2DJuiceEffect.
## ============================================================================
##
## ARCHITECTURE:
## - Effects are Resources (not Nodes). The host Juice3D node ticks them.
## - Uses sin(progress * PI) curve — peaks at progress=0.5.
## - At progress=0.0 and 1.0: natural scale (no deformation).
## - At progress=0.5: maximum squash.
## - If preserve_volume=true, perpendicular axes expand as primary compresses.
##
## VOLUME PRESERVATION (3D):
## - When primary axis shrinks by factor F, the other two axes each grow by sqrt(1/F).
## - This maintains approximate volume: X * Y * Z remains constant.
##
## TYPICAL USAGE:
## - Landing impact: squash_axis = Y, squash_amount = 0.3, duration = 0.15
## - Breathing: loop = true, squash_amount = 0.05
## ============================================================================

@tool
class_name SquashStretch3DJuiceEffect
extends JuiceEffectBase


# =============================================================================
# ENUMS
# =============================================================================

## Which axis is the primary squash axis.
enum SquashAxis3D {
	X,  ## Squash on X, expand Y and Z
	Y,  ## Squash on Y, expand X and Z (most common — landing, jumping)
	Z   ## Squash on Z, expand X and Y
}


# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Squash Stretch")

## How much to compress at peak (0.0 = no squash, 0.99 = maximum).
## Values are clamped to prevent scale inversion.
@export_range(0.0, 0.99) var squash_amount: float = 0.3

## Primary axis of squash.
@export var squash_axis: SquashAxis3D = SquashAxis3D.Y

## If true, expand perpendicular axes to preserve visual volume.
## Creates more organic, cartoon-like deformation.
@export var preserve_volume: bool = true

@export_group("Pivot")

## Pivot point for squash/stretch in local space.
## Squashing will appear to originate from this point.
## For characters, often set to feet position.
@export var pivot_offset: Vector3 = Vector3.ZERO


# =============================================================================
# INTERNAL STATE
# =============================================================================

## Captured base scale.
var _base_scale: Vector3 = Vector3.ONE

## Captured base position (for pivot compensation).
var _base_position: Vector3 = Vector3.ZERO

## Whether base has been captured.
var _has_base: bool = false


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

## Capture base state when animation begins.
func _on_animate_start(target: Node) -> void:
	_capture_base(target)


## Apply squash/stretch deformation at the given progress.
## Uses sin(progress * PI) for a symmetric curve that peaks at 0.5.
func _apply_effect(progress: float, target: Node) -> void:
	var n3d := target as Node3D
	if n3d == null:
		return

	var squash_factor := sin(progress * PI)
	var new_scale := _base_scale

	# Primary axis compression
	var primary_multiplier := 1.0 - (squash_amount * squash_factor)

	# In 3D, if one axis shrinks by F, other two each grow by sqrt(1/F)
	var perpendicular_multiplier := 1.0
	if preserve_volume and primary_multiplier > 0.001:
		perpendicular_multiplier = sqrt(1.0 / primary_multiplier)

	match squash_axis:
		SquashAxis3D.X:
			new_scale.x = _base_scale.x * primary_multiplier
			if preserve_volume:
				new_scale.y = _base_scale.y * perpendicular_multiplier
				new_scale.z = _base_scale.z * perpendicular_multiplier
		SquashAxis3D.Y:
			new_scale.y = _base_scale.y * primary_multiplier
			if preserve_volume:
				new_scale.x = _base_scale.x * perpendicular_multiplier
				new_scale.z = _base_scale.z * perpendicular_multiplier
		SquashAxis3D.Z:
			new_scale.z = _base_scale.z * primary_multiplier
			if preserve_volume:
				new_scale.x = _base_scale.x * perpendicular_multiplier
				new_scale.y = _base_scale.y * perpendicular_multiplier

	n3d.scale = new_scale

	# Pivot compensation: offset position so scaling appears anchored at pivot
	if pivot_offset != Vector3.ZERO:
		var scale_ratio := new_scale / _base_scale
		var pivot_delta := pivot_offset * (Vector3.ONE - scale_ratio)
		n3d.position = _base_position + pivot_delta


## Snap back to exact base state to avoid floating point drift.
func _on_animate_out_complete(target: Node) -> void:
	var n3d := target as Node3D
	if n3d == null:
		return
	n3d.scale = _base_scale
	if pivot_offset != Vector3.ZERO:
		n3d.position = _base_position


## Restore target to natural (unmodified) state.
func _restore_to_natural(target: Node) -> void:
	var n3d := target as Node3D
	if n3d == null:
		return
	n3d.scale = _base_scale
	if pivot_offset != Vector3.ZERO:
		n3d.position = _base_position


## Reset cached base values when target changes.
func _invalidate_base_cache() -> void:
	_has_base = false


# =============================================================================
# HELPERS
# =============================================================================

## Capture base state from target (once per animation cycle).
func _capture_base(target: Node) -> void:
	if _has_base:
		return
	var n3d := target as Node3D
	if n3d == null:
		return
	_base_scale = n3d.scale
	_base_position = n3d.position
	_has_base = true
