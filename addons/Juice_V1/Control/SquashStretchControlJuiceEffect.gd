## SquashStretchControlJuiceEffect.gd
## ============================================================================
## WHAT: Classic squash & stretch scaling for Control nodes with volume preservation.
## WHY: Provides lively UI deformation feedback without AnimationPlayer.
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Support Node2D/Node3D targets — use SquashStretch2D/3DJuiceEffect.
## ============================================================================
##
## ARCHITECTURE:
## - Effects are Resources (not Nodes). The host ControlJuice node ticks them.
## - Uses sin(progress * PI) curve — peaks at progress=0.5.
## - At progress=0.0 and 1.0: natural scale (no deformation).
## - At progress=0.5: maximum squash.
## - If preserve_volume=true, perpendicular axis expands as primary compresses.
##
## TYPICAL USAGE:
## - Button press feedback: squash_axis = VERTICAL, squash_amount = 0.3, duration = 0.15
## - Hover bounce: squash_axis = VERTICAL, squash_amount = 0.2
## ============================================================================

@tool
class_name SquashStretchControlJuiceEffect
extends JuiceEffectBase


# =============================================================================
# ENUMS
# =============================================================================

## Which axis is the primary squash axis.
enum SquashAxis {
	VERTICAL,    ## Squash on Y, stretch on X (landing, pressing down)
	HORIZONTAL   ## Squash on X, stretch on Y (side impact)
}

## Pivot origin for the scale transformation.
## Controls where scaling appears to originate from.
enum PivotMode {
	AUTO_CENTER,  ## Automatically center pivot on the Control's size
	INHERIT,      ## Use the Control's existing pivot_offset (don't change it)
	CUSTOM        ## Use a custom normalized pivot (see custom_pivot)
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

@export_group("Pivot")

## Controls scale origin point. AUTO_CENTER sets pivot to center of the Control.
## INHERIT keeps whatever pivot_offset the Control already has.
## CUSTOM uses normalized coordinates from custom_pivot.
@export var pivot_mode: PivotMode = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()

## Custom pivot in normalized coordinates (0–1).
## (0.5, 0.5) = center, (0.5, 1.0) = bottom center.
## Only visible when pivot_mode is CUSTOM.
@export var custom_pivot: Vector2 = Vector2(0.5, 0.5)


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	# custom_pivot only shown when pivot_mode == CUSTOM
	if property.name == "custom_pivot" and pivot_mode != PivotMode.CUSTOM:
		property.usage = PROPERTY_USAGE_NO_EDITOR


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _base_scale: Vector2 = Vector2.ONE
var _has_base: bool = false
var _pivot_applied: bool = false


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

## Capture base scale and apply pivot on first animation start.
func _on_animate_start(target: Node) -> void:
	_capture_base(target)

	if not _pivot_applied:
		_apply_pivot_mode(target)
		_pivot_applied = true


## Apply squash/stretch deformation at the given progress.
## Uses sin(progress * PI) for a symmetric curve that peaks at 0.5.
func _apply_effect(progress: float, target: Node) -> void:
	var ctrl := target as Control
	if ctrl == null:
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

	ctrl.scale = new_scale


## Snap back to exact base scale to avoid floating point drift.
func _on_animate_out_complete(target: Node) -> void:
	var ctrl := target as Control
	if ctrl == null:
		return
	ctrl.scale = _base_scale


## Restore target to natural (unmodified) state.
func _restore_to_natural(target: Node) -> void:
	var ctrl := target as Control
	if ctrl == null:
		return
	ctrl.scale = _base_scale


## Reset cached base values when target changes.
func _invalidate_base_cache() -> void:
	_has_base = false
	_pivot_applied = false


# TODO: Override _get_interrupt_identity() to share identity with future
# TransformControlJuiceEffect SCALE mode once that effect is ported.
# V0 did: return [load("TransformControlJuiceComp.gd"), TransformTarget.SCALE]


# =============================================================================
# HELPERS
# =============================================================================

## Capture base scale from target (once per animation cycle).
func _capture_base(target: Node) -> void:
	if _has_base:
		return
	var ctrl := target as Control
	if ctrl == null:
		return
	_base_scale = ctrl.scale
	_has_base = true


## Apply pivot offset to the Control based on pivot_mode.
func _apply_pivot_mode(target: Node) -> void:
	var ctrl := target as Control
	if ctrl == null:
		return

	match pivot_mode:
		PivotMode.AUTO_CENTER:
			ctrl.pivot_offset = ctrl.size / 2.0
		PivotMode.INHERIT:
			return
		PivotMode.CUSTOM:
			ctrl.pivot_offset = Vector2(
				ctrl.size.x * custom_pivot.x,
				ctrl.size.y * custom_pivot.y
			)
