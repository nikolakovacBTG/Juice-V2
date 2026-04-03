## [EffectName]ControlJuiceEffect.gd
## ============================================================================
## WHAT: [One-line description of what this effect does].
## WHY: [Why this effect exists / what user need it serves].
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Handle Node2D or Node3D targets — use [EffectName]2D/3DJuiceEffect.
## ============================================================================
##
## WRITE PATTERN: Delta-first. Stores result in _pos_delta / _rot_delta /
##   _scale_delta — the domain node (JuiceControl) writes once per frame.
##
## [Additional architecture notes specific to this effect]
## ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name REPLACE_EffectNameControlJuiceEffect
extends JuiceControlTransformEffect


# =============================================================================
# ENUMS
# =============================================================================

# [Effect-specific enums here]


# =============================================================================
# CONFIGURATION
# =============================================================================

# [Effect-specific vars shown via _get_property_list — NOT @export]
# Example:
# var my_amount: float = 1.0

func _init() -> void:
	_subclass_owns_effect_group = true


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# --- Effect group: effect-specific config + base effect properties ---
	props.append({"name": "Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})

	# [Add effect-specific properties here]
	# Example:
	# props.append({"name": "my_amount", "type": TYPE_FLOAT,
	#     "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
	#     "usage": PROPERTY_USAGE_DEFAULT})

	props.append_array(_get_effect_base_properties())

	return props


func _set(property: StringName, value: Variant) -> bool:
	# match property:
	#     &"my_amount": my_amount = value; return true
	return false


func _get(property: StringName) -> Variant:
	# match property:
	#     &"my_amount": return my_amount
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _base_scale: Vector2 = Vector2.ONE  # [Adjust per effect needs]
var _has_base: bool = false


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

## Capture base values and set contribution flags.
func _on_animate_start(target: Node) -> void:
	_capture_base(target)
	# Set which channels this effect contributes to:
	# _contributes_position = true
	# _contributes_rotation = true
	# _contributes_scale = true


## Compute effect delta at the given progress.
## Store result in _pos_delta / _rot_delta / _scale_delta.
## NEVER write to target directly.
func _apply_effect(progress: float, target: Node) -> void:
	if target == null:
		return
	# [Effect math here]
	# Example:
	# var desired := lerp(_base_scale, _target_scale, progress)
	# _scale_delta = desired - _base_scale
	pass


## Called when animate_out completes. Snap deltas to zero.
func _on_animate_out_complete(_target: Node) -> void:
	# Reset whichever deltas this effect uses:
	# _scale_delta = Vector2.ZERO
	pass


## Clear deltas — domain node writes natural state.
func _restore_to_natural(_target: Node) -> void:
	_clear_deltas()


## Reset cached base values when target changes.
func _invalidate_base_cache() -> void:
	_has_base = false
	_clear_deltas()


# =============================================================================
# HELPERS
# =============================================================================

func _capture_base(target: Node) -> void:
	if _has_base:
		return
	var ctrl := target as Control
	if ctrl == null:
		return
	# Capture whatever base values this effect needs:
	# _base_scale = ctrl.scale
	_has_base = true
