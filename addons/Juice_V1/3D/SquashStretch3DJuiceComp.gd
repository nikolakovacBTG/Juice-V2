## SquashStretch3DJuiceComp.gd
## ============================================================================
## WHAT: Classic 3D squash and stretch with optional volume preservation.
## WHY: Provides organic deformation feedback for 3D objects (bounces, impacts,
##      breathing motion) while maintaining volume.
## SYSTEM: Juicing System (addons/juice/)
## DOES NOT: Handle 2D deformation (use SquashStretch2DJuiceComp), bone/skeletal
##           animation, or physics soft body simulation.
## ============================================================================
##
## ARCHITECTURE (Phase 4.12.2 - 3D Transform):
## - Uses sin(progress * PI) curve - peaks at progress=0.5
## - At progress=0.0 and 1.0: natural scale (no deformation)
## - At progress=0.5: maximum squash (or stretch if squash_amount < 0)
## - If preserve_volume=true, perpendicular axes expand as primary compresses
##
## VOLUME PRESERVATION (3D):
## - When primary axis shrinks by factor F, the other two axes each grow by sqrt(1/F)
## - This maintains approximate volume: X * Y * Z remains constant
##
## TYPICAL USAGE:
## - Landing impact: Squash on Y, expand on X and Z momentarily
## - Jump anticipation: Stretch on Y, compress on X and Z
## - Impact feedback: Quick squash and return on any axis
##
## EXAMPLES:
## - Landing: squash_axis=Y, squash_amount=0.3, duration=0.15
## - Impact squash: squash_amount=0.2, stretch_amount=0.1
## - Breathing: loop=true, squash_amount=0.05, stretch_amount=0.05
## ============================================================================

@tool
@icon("res://addons/Juice_V1/Icons/JuiceBase3D.svg")
class_name SquashStretch3DJuiceComp
extends JuiceCompBase

# =============================================================================
# ENUMS
# =============================================================================

## Which axis is the primary squash axis
enum SquashAxis3D {
	X,  ## Squash on X, expand Y and Z
	Y,  ## Squash on Y, expand X and Z (most common - landing, jumping)
	Z   ## Squash on Z, expand X and Y
}

# =============================================================================
# SQUASH STRETCH CONFIGURATION
# =============================================================================

@export_group("Effect")

## How much to compress at peak (0.0 = no squash, 0.99 = maximum)
## Values are clamped to prevent scale inversion
@export_range(0.0, 0.99) var squash_amount: float = 0.3

## Primary axis of squash
@export var squash_axis: SquashAxis3D = SquashAxis3D.Y

## If true, expand perpendicular axes to preserve visual volume
## Creates more organic, cartoon-like deformation
@export var preserve_volume: bool = true

@export_group("Pivot")

## Pivot point for squash/stretch in local space
## Squashing will appear to originate from this point
## For characters, often set to feet position
@export var pivot_offset: Vector3 = Vector3.ZERO

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Captured base scale
var _base_scale: Vector3 = Vector3.ONE

## Captured base position (for pivot compensation)
var _base_position: Vector3 = Vector3.ZERO

## Whether base has been captured
var _has_base: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()


# =============================================================================
# VIRTUAL METHOD IMPLEMENTATIONS
# =============================================================================

func _invalidate_base_cache() -> void:
	_has_base = false


func _on_animate_start() -> void:
	if not _has_base:
		_capture_base_state()
	
	if debug_enabled:
		print("[%s] SquashStretch3D: amount=%.2f, axis=%s, preserve=%s, pivot=%s" % [
			name, squash_amount, SquashAxis3D.keys()[squash_axis], preserve_volume, pivot_offset
		])


func _apply_effect(progress: float) -> void:
	if not _target_node is Node3D:
		return
	
	var n3d := _target_node as Node3D
	
	# Use sin(progress * PI) for symmetric squash curve
	# This gives: 0 at progress=0, 1 at progress=0.5, 0 at progress=1
	var squash_factor := sin(progress * PI)
	
	# Calculate scale modification
	var new_scale := _base_scale
	
	# Primary axis compression
	var primary_multiplier := 1.0 - (squash_amount * squash_factor)
	
	# Perpendicular axes expansion (if preserving volume)
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
	
	# Apply scale
	n3d.scale = new_scale
	
	# Apply pivot compensation if needed
	if pivot_offset != Vector3.ZERO:
		var scale_ratio := new_scale / _base_scale
		var pivot_delta := pivot_offset * (Vector3.ONE - scale_ratio)
		n3d.position = _base_position + pivot_delta
	
	if debug_enabled:
		print("[%s] SquashStretch3D: progress=%.2f, factor=%.2f, scale=%s" % [
			name, progress, squash_factor, new_scale
		])


func _on_animate_out_complete() -> void:
	# Ensure we return to exact base scale (avoid floating point drift)
	if _target_node is Node3D:
		var n3d := _target_node as Node3D
		n3d.scale = _base_scale
		if pivot_offset != Vector3.ZERO:
			n3d.position = _base_position
	
	if debug_enabled:
		print("[%s] SquashStretch3D complete, returned to base: %s" % [name, _base_scale])


# =============================================================================
# HELPERS
# =============================================================================

## Capture base state from target
func _capture_base_state() -> void:
	if not _target_node is Node3D:
		if debug_enabled:
			var target_name := str(_target_node.name) if _target_node else "null"
			push_warning("[%s] Target '%s' is not Node3D" % [name, target_name])
		_base_scale = Vector3.ONE
		_base_position = Vector3.ZERO
		_has_base = true
		return
	
	var n3d := _target_node as Node3D
	_base_scale = n3d.scale
	_base_position = n3d.position
	_has_base = true
	
	if debug_enabled:
		print("[%s] Captured base scale: %s, position: %s" % [name, _base_scale, _base_position])


## Configuration warning if target is not Node3D
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	
	var target := get_parent()
	if target and not target is Node3D:
		warnings.append("SquashStretch3DJuiceComp requires a Node3D parent. Current parent is: " + target.get_class())
	
	return warnings
