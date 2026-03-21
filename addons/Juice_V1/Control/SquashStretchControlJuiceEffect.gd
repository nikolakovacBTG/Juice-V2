## SquashStretchControlJuiceEffect.gd
## ============================================================================
## WHAT: Classic squash & stretch scaling for Control nodes with volume preservation.
## WHY: Provides lively UI deformation feedback without AnimationPlayer.
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Support Node2D/Node3D targets — use SquashStretch2D/3DJuiceEffect.
## ============================================================================
##
## ARCHITECTURE:
## - Effects are Resources (not Nodes). The host JuiceControl node ticks them.
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
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name SquashStretchControlJuiceEffect
extends JuiceControlEffectBase


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

## How much to compress at peak (0.0 = no squash, 0.99 = maximum).
## Values are clamped to prevent scale inversion.
var squash_amount: float = 0.3

## Primary axis of squash.
var squash_axis: int = SquashAxis.VERTICAL

## If true, expand perpendicular axis to preserve visual volume.
## Creates more organic, cartoon-like deformation.
var preserve_volume: bool = true

## Controls scale origin point. AUTO_CENTER sets pivot to center of the Control.
## INHERIT keeps whatever pivot_offset the Control already has.
## CUSTOM uses normalized coordinates from custom_pivot.
var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()

## Custom pivot in normalized coordinates (0–1).
## (0.5, 0.5) = center, (0.5, 1.0) = bottom center.
## Only visible when pivot_mode is CUSTOM.
var custom_pivot: Vector2 = Vector2(0.5, 0.5)

func _init() -> void:
	_subclass_owns_effect_group = true


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# --- Effect group: squash config + base effect properties ---
	props.append({"name": "Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "squash_amount", "type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,0.99,0.01",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "squash_axis", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Vertical,Horizontal",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "preserve_volume", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append_array(_get_effect_base_properties())

	# --- Pivot group ---
	props.append({"name": "Pivot", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "pivot_mode", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Auto Center,Inherit,Custom",
		"usage": PROPERTY_USAGE_DEFAULT})
	if pivot_mode == PivotMode.CUSTOM:
		props.append({"name": "custom_pivot", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"squash_amount": squash_amount = value; return true
		&"squash_axis": squash_axis = value; return true
		&"preserve_volume": preserve_volume = value; return true
		&"pivot_mode": pivot_mode = value; return true
		&"custom_pivot": custom_pivot = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"squash_amount": return squash_amount
		&"squash_axis": return squash_axis
		&"preserve_volume": return preserve_volume
		&"pivot_mode": return pivot_mode
		&"custom_pivot": return custom_pivot
	return null


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
