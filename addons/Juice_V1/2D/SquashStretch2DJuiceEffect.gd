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
@icon("res://addons/Juice_V1/icons/JuiceBase2D.svg")
class_name SquashStretch2DJuiceEffect
extends Juice2DEffectBase


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

## How much to compress at peak (0.0 = no squash, 0.99 = maximum).
## Values are clamped to prevent scale inversion.
var squash_amount: float = 0.3

## Primary axis of squash.
var squash_axis: int = SquashAxis.VERTICAL

## If true, expand perpendicular axis to preserve visual volume.
## Creates more organic, cartoon-like deformation.
var preserve_volume: bool = true

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

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"squash_amount": squash_amount = value; return true
		&"squash_axis": squash_axis = value; return true
		&"preserve_volume": preserve_volume = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"squash_amount": return squash_amount
		&"squash_axis": return squash_axis
		&"preserve_volume": return preserve_volume
	return null


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

	# Set contribution flag so the domain node knows to aggregate scale
	_contributes_scale = true


## Compute squash/stretch scale delta at the given progress.
## Uses sin(progress * PI) for a symmetric curve that peaks at 0.5.
## Stores result in _scale_delta — the domain node writes once per frame.
func _apply_effect(progress: float, target: Node) -> void:
	if target == null:
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

	# Store delta from natural scale — node aggregates and writes
	_scale_delta = new_scale - _base_scale


## Snap back to zero delta to avoid floating point drift.
func _on_animate_out_complete(_target: Node) -> void:
	_scale_delta = Vector2.ZERO


## Clear deltas — the domain node will write natural state via _post_tick_write().
func _restore_to_natural(_target: Node) -> void:
	_clear_deltas()


## Reset cached base values when target changes.
func _invalidate_base_cache() -> void:
	_has_base = false
	_clear_deltas()


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
