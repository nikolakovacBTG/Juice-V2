## SquashStretchControlJuiceComp.gd
## ============================================================================
## WHAT: Classic squash & stretch scaling for Control nodes with volume preservation.
## WHY: Provides lively UI deformation feedback without AnimationPlayer.
## SYSTEM: Juicing System (addons/juice/)
## DOES NOT: Support Node2D/Node3D targets, true 3D deformation, or skeletal squash.
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBaseControl.svg")
class_name SquashStretchControlJuiceComp
extends JuiceCompBase


# =============================================================================
# PIVOT MODE - Controls scale origin point
# =============================================================================

enum PivotMode {
	AUTO_CENTER,
	INHERIT,
	CUSTOM
}

var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()

## Custom pivot in normalized coordinates (0-1).
var custom_pivot: Vector2 = Vector2(0.5, 0.5)


# =============================================================================
# SQUASH STRETCH CONFIGURATION
# =============================================================================

enum SquashAxis {
	VERTICAL,
	HORIZONTAL
}

@export_group("Squash Stretch")

## How much to compress at peak (0.0 = no squash, 0.99 = maximum)
## Values are clamped to prevent scale inversion.
@export_range(0.0, 0.99) var squash_amount: float = 0.3

@export var squash_axis: SquashAxis = SquashAxis.VERTICAL

@export var preserve_volume: bool = true


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	props.append({
		"name": "pivot_mode",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Auto Center,Inherit,Custom",
	})
	if pivot_mode == PivotMode.CUSTOM:
		props.append({
			"name": "custom_pivot",
			"type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	return props


func _set(prop: StringName, value: Variant) -> bool:
	match prop:
		&"pivot_mode":
			pivot_mode = value
			return true
		&"custom_pivot":
			custom_pivot = value
			return true
	return false


func _get(prop: StringName) -> Variant:
	match prop:
		&"pivot_mode":
			return pivot_mode
		&"custom_pivot":
			return custom_pivot
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _base_scale: Vector2 = Vector2.ONE
var _has_base: bool = false
var _pivot_applied: bool = false


# =============================================================================
# JUICECOMPBASE OVERRIDES
# =============================================================================

func _on_animate_start() -> void:
	_capture_base()

	if not _pivot_applied:
		_apply_pivot_mode()
		_pivot_applied = true


func _apply_effect(progress: float) -> void:
	var ctrl := _get_target_control()
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


func _on_animate_out_complete() -> void:
	var ctrl := _get_target_control()
	if ctrl == null:
		return
	ctrl.scale = _base_scale


func _invalidate_base_cache() -> void:
	_has_base = false
	_pivot_applied = false


## Share interrupt identity with TransformControlJuiceComp SCALE mode.
## Both write to ctrl.scale, so they must interrupt each other to prevent
## "last writer wins" fights when both are siblings on the same parent.
func _get_interrupt_identity() -> Variant:
	# TransformControlJuiceComp uses [get_script(), TransformTarget.SCALE]
	# We load its script to match that identity array format
	var transform_script := load("res://addons/juice/Control/TransformControlJuiceComp.gd")
	return [transform_script, 2]  # 2 = TransformTarget.SCALE


# =============================================================================
# SEQUENCER RECIPE CONTRACT
# =============================================================================

func _recipe_capture_natural(target: Node) -> Variant:
	if target is Control:
		return {"scale": (target as Control).scale}
	return null


func _recipe_apply_natural(target: Node, natural: Variant) -> void:
	if not (natural is Dictionary) or not (target is Control):
		return
	var dict := natural as Dictionary
	(target as Control).scale = dict.get("scale", Vector2.ONE) as Vector2


func _recipe_restore_natural(target: Node, natural: Variant) -> void:
	_recipe_apply_natural(target, natural)


# =============================================================================
# INTERNAL HELPERS
# =============================================================================

func _get_target_control() -> Control:
	if not is_instance_valid(_target_node):
		return null
	if _target_node is Control:
		return _target_node as Control
	if debug_enabled:
		push_warning("[%s] Target '%s' is not Control" % [name, _target_node.name])
	return null


func _capture_base() -> void:
	if _has_base:
		return

	var ctrl := _get_target_control()
	if ctrl == null:
		return

	_base_scale = ctrl.scale
	_has_base = true


func _apply_pivot_mode() -> void:
	var ctrl := _get_target_control()
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

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent := get_parent()
	if parent and not parent is Control:
		warnings.append("Parent must be a Control node. Use SquashStretch2D/3D for other domains. (ignore if comp is a child of a sequencer)")
	return warnings
