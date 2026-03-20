## ShakePropertyJuiceComp.gd
## ============================================================================
## WHAT: Domain-agnostic shake effect for any property on any node.
##       Oscillates a property value around its base using sine + randomness,
##       with configurable frequency, strength, and decay.
## WHY: Extends the Shake family beyond transforms — shake a light's energy,
##      a material's roughness, an audio bus volume, a shader parameter, etc.
##      This is the "+1" in the 3+1 architecture (domain-agnostic complement
##      to the 3 domain-specific shake scripts).
##
## WRITE PATTERN: Delta-first. Each frame writes only the CHANGE in this comp's
##   contribution: property += (new_offset - _my_contribution). This enables
##   stacking with other effects and preserves external changes to the property.
## SYSTEM: Juicing System (addons/juice/) - Property Domain
## DOES NOT: Handle transform shaking (use ShakeControl/Shake2D/Shake3D).
## DOES NOT: Handle camera shake (use Camera3DJuiceComp / Camera2DJuiceComp).
##
## PLACEMENT:
## Add as child of (or in the same scene as) the node whose property you want
## to affect — property resolution uses NodePath, which requires scene-tree
## proximity. To trigger the effect from a remote source (e.g., an enemy hit
## triggering camera shake), keep the juice comp near the target and use
## manual_trigger_signal + trigger_source_path pointed at a SignalBus or
## relay node. This is standard Godot signal routing, not a workaround.
## ============================================================================
##
## KEY CONCEPT:
## Shake is TIME-driven during animation, not progress-driven.
## Progress only controls the decay envelope (amplitude reduction).
## The actual oscillation comes from sin(time * frequency) blended with
## per-frame randomness.
##
## PROPERTY ACCESS:
## Uses get_indexed() / set_indexed() to read/write any property by path.
## Supports nested paths like "modulate:a", "material:shader_parameter/dissolve".
## Property type must be specified so the correct shake math is applied.
##
## CONDITIONAL EXPORTS:
## Changing property_type triggers notify_property_list_changed() which
## shows/hides the relevant per-type strength values via _get_property_list().
##
## REFERENCE:
## Property resolution pattern adapted from SpringJuiceComp PROPERTY mode.
## Shake math adapted from the Shake family domain scripts.
## ============================================================================

@tool
@icon("res://addons/Juice_V1/Icons/JuiceBaseProperty.svg")
class_name ShakePropertyJuiceComp
extends JuiceCompBase

# =============================================================================
# PROPERTY TARGET CONFIGURATION
# =============================================================================

@export_group("Effect")

## Path to node containing the property.
## Leave empty to use parent node.
@export_node_path("Node") var target_node_path: NodePath

## Path to the property to shake (e.g., "modulate:a", "light_energy")
## Supports nested paths like "material:shader_parameter/dissolve"
@export var property_path: String = ""

## Type of the property value — determines which shake strength export is shown
## and which math is used for oscillation.
enum PropertyType {
	FLOAT,
	VECTOR2,
	VECTOR3,
	COLOR
}

@export var property_type: PropertyType = PropertyType.FLOAT:
	set(value):
		property_type = value
		notify_property_list_changed()

# =============================================================================
# SHARED SHAKE CONFIGURATION (always visible)
# =============================================================================

@export_group("Shake")

## Oscillations per second (Hz) — higher = more frantic
@export var shake_frequency: float = 20.0

## If true, shake intensity decreases over duration (recommended for impacts)
@export var decay: bool = true

## Blend between predictable sine wave (0) and fully random (1)
## 0 = pure sine oscillation, 1 = fully random direction each frame
@export_range(0.0, 1.0) var randomness: float = 0.5

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — they are shown/hidden via _get_property_list()
# =============================================================================

## Maximum shake offset for float properties
var float_strength: float = 0.5

## Maximum shake offset per axis for Vector2 properties
var vector2_strength: Vector2 = Vector2(0.1, 0.1)

## Maximum shake offset per axis for Vector3 properties
var vector3_strength: Vector3 = Vector3(0.1, 0.1, 0.1)

## Maximum shake offset per channel for Color properties (RGBA)
var color_strength: Color = Color(0.1, 0.1, 0.1, 0.0)

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Resolved property target node
var _property_target_node: Node = null

## Captured base property value (type varies)
var _base_value: Variant = null

## Whether base has been captured
var _has_base: bool = false

## Whether configuration has been validated
var _is_valid: bool = false

## Accumulated shake time (drives the oscillation)
var _shake_time: float = 0.0

## Random seed for consistent-ish randomness per play
var _shake_seed: float = 0.0

## Delta-first contribution tracking.
## Tracks what THIS comp last wrote as an offset so we can compute deltas.
## Type matches the property being shaken (float, Vector2, Vector3, Color).
var _my_contribution: Variant = null

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	match property_type:
		PropertyType.FLOAT:
			props.append({
				"name": "float_strength",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
		PropertyType.VECTOR2:
			props.append({
				"name": "vector2_strength",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
		PropertyType.VECTOR3:
			props.append({
				"name": "vector3_strength",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
		PropertyType.COLOR:
			props.append({
				"name": "color_strength",
				"type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT,
			})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"float_strength": float_strength = value; return true
		&"vector2_strength": vector2_strength = value; return true
		&"vector3_strength": vector3_strength = value; return true
		&"color_strength": color_strength = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"float_strength": return float_strength
		&"vector2_strength": return vector2_strength
		&"vector3_strength": return vector3_strength
		&"color_strength": return color_strength
	return null

# =============================================================================
# LIFECYCLE OVERRIDES
# =============================================================================

func _ready() -> void:
	super._ready()
	_validate_configuration()


func _validate_configuration() -> void:
	_is_valid = true

	# Resolve target node
	if target_node_path.is_empty():
		_property_target_node = get_parent()
	else:
		_property_target_node = get_node_or_null(target_node_path)

	if _property_target_node == null:
		push_warning("[%s] PropertyShake: target node not found" % name)
		_is_valid = false
	elif property_path.is_empty():
		push_warning("[%s] PropertyShake: property_path is empty" % name)
		_is_valid = false

	if debug_enabled and _is_valid:
		var resolved_name: String = "null"
		if _property_target_node != null:
			resolved_name = str(_property_target_node.name)
		print("[%s] PropertyShake validated. Target: %s, Path: %s, Type: %s" % [
			name, resolved_name, property_path, PropertyType.keys()[property_type]
		])


func _on_animate_start() -> void:
	if not _is_valid:
		_validate_configuration()
	if not _is_valid:
		return

	if not _has_base:
		_capture_base()

	_shake_seed = randf() * 1000.0
	_shake_time = 0.0

	if debug_enabled:
		print("[%s] PropertyShake start. Path: %s, Type: %s, Base: %s, Freq: %.1f Hz" % [
			name, property_path, PropertyType.keys()[property_type],
			_base_value, shake_frequency
		])


func _apply_effect(progress: float) -> void:
	if not _is_valid:
		return
	if not is_instance_valid(_property_target_node):
		return

	_shake_time += get_process_delta_time()

	var decay_mult := 1.0
	if decay:
		decay_mult = 1.0 - progress

	match property_type:
		PropertyType.FLOAT:
			_apply_float_shake(decay_mult)
		PropertyType.VECTOR2:
			_apply_vector2_shake(decay_mult)
		PropertyType.VECTOR3:
			_apply_vector3_shake(decay_mult)
		PropertyType.COLOR:
			_apply_color_shake(decay_mult)


func _on_animate_out_complete() -> void:
	# Safety cleanup: remove any remaining contribution.
	# Needed because shake at progress=0 has non-zero offset (decay_mult=1.0).
	_remove_contribution()
	if debug_enabled:
		print("[%s] PropertyShake complete (out), contribution cleared" % name)


func _on_animate_in_complete() -> void:
	# At progress=1 with decay=true, decay_mult=0 so offset=0 and contribution
	# should already be zero. This is a safety net.
	_remove_contribution()
	if debug_enabled:
		print("[%s] PropertyShake complete (in), contribution cleared" % name)


func _restore_to_natural() -> void:
	_remove_contribution()


func _exit_tree() -> void:
	# Clean up our delta contribution if freed mid-animation
	_remove_contribution()


func _invalidate_base_cache() -> void:
	_has_base = false
	_my_contribution = null
	if debug_enabled:
		print("[%s] Base cache invalidated" % name)


## Subtract our current contribution from the property and reset tracking.
## Safe to call even if no contribution was made (_my_contribution == null).
func _remove_contribution() -> void:
	if _my_contribution == null:
		return
	if not is_instance_valid(_property_target_node):
		_my_contribution = null
		return

	var current: Variant = _property_target_node.get_indexed(property_path)
	match property_type:
		PropertyType.FLOAT:
			var prev: float = _my_contribution as float
			_property_target_node.set_indexed(property_path, (current as float) - prev)
		PropertyType.VECTOR2:
			var prev: Vector2 = _my_contribution as Vector2
			_property_target_node.set_indexed(property_path, (current as Vector2) - prev)
		PropertyType.VECTOR3:
			var prev: Vector3 = _my_contribution as Vector3
			_property_target_node.set_indexed(property_path, (current as Vector3) - prev)
		PropertyType.COLOR:
			var prev: Color = _my_contribution as Color
			var cur: Color = current as Color
			_property_target_node.set_indexed(property_path, Color(
				cur.r - prev.r, cur.g - prev.g, cur.b - prev.b, cur.a - prev.a
			))
	_my_contribution = null


# =============================================================================
# PER-TYPE SHAKE APPLICATION
# =============================================================================

func _apply_float_shake(intensity: float) -> void:
	var freq_mult := _shake_time * shake_frequency * TAU
	var sine_val := sin(freq_mult + _shake_seed)
	var random_val := randf_range(-1.0, 1.0)
	var final_val := lerpf(sine_val, random_val, randomness)

	var offset := final_val * float_strength * intensity
	var prev: float = _my_contribution if _my_contribution is float else 0.0
	var current: float = _property_target_node.get_indexed(property_path)
	_property_target_node.set_indexed(property_path, current + offset - prev)
	_my_contribution = offset


func _apply_vector2_shake(intensity: float) -> void:
	var freq_mult := _shake_time * shake_frequency * TAU
	var sine_x := sin(freq_mult + _shake_seed)
	var sine_y := sin(freq_mult * 1.3 + _shake_seed + 100.0)

	var random_x := randf_range(-1.0, 1.0)
	var random_y := randf_range(-1.0, 1.0)

	var final_x := lerpf(sine_x, random_x, randomness)
	var final_y := lerpf(sine_y, random_y, randomness)

	var offset := Vector2(
		final_x * vector2_strength.x * intensity,
		final_y * vector2_strength.y * intensity
	)
	var prev: Vector2 = _my_contribution if _my_contribution is Vector2 else Vector2.ZERO
	var current: Vector2 = _property_target_node.get_indexed(property_path)
	_property_target_node.set_indexed(property_path, current + offset - prev)
	_my_contribution = offset


func _apply_vector3_shake(intensity: float) -> void:
	var freq_mult := _shake_time * shake_frequency * TAU
	var sine_x := sin(freq_mult + _shake_seed)
	var sine_y := sin(freq_mult * 1.3 + _shake_seed + 100.0)
	var sine_z := sin(freq_mult * 0.7 + _shake_seed + 200.0)

	var random_x := randf_range(-1.0, 1.0)
	var random_y := randf_range(-1.0, 1.0)
	var random_z := randf_range(-1.0, 1.0)

	var final_x := lerpf(sine_x, random_x, randomness)
	var final_y := lerpf(sine_y, random_y, randomness)
	var final_z := lerpf(sine_z, random_z, randomness)

	var offset := Vector3(
		final_x * vector3_strength.x * intensity,
		final_y * vector3_strength.y * intensity,
		final_z * vector3_strength.z * intensity
	)
	var prev: Vector3 = _my_contribution if _my_contribution is Vector3 else Vector3.ZERO
	var current: Vector3 = _property_target_node.get_indexed(property_path)
	_property_target_node.set_indexed(property_path, current + offset - prev)
	_my_contribution = offset


func _apply_color_shake(intensity: float) -> void:
	var freq_mult := _shake_time * shake_frequency * TAU

	# Per-channel oscillation with slight frequency offsets
	var sine_r := sin(freq_mult + _shake_seed)
	var sine_g := sin(freq_mult * 1.3 + _shake_seed + 100.0)
	var sine_b := sin(freq_mult * 0.7 + _shake_seed + 200.0)
	var sine_a := sin(freq_mult * 1.1 + _shake_seed + 300.0)

	var random_r := randf_range(-1.0, 1.0)
	var random_g := randf_range(-1.0, 1.0)
	var random_b := randf_range(-1.0, 1.0)
	var random_a := randf_range(-1.0, 1.0)

	var final_r := lerpf(sine_r, random_r, randomness)
	var final_g := lerpf(sine_g, random_g, randomness)
	var final_b := lerpf(sine_b, random_b, randomness)
	var final_a := lerpf(sine_a, random_a, randomness)

	var offset := Color(
		final_r * color_strength.r * intensity,
		final_g * color_strength.g * intensity,
		final_b * color_strength.b * intensity,
		final_a * color_strength.a * intensity
	)
	var prev: Color = _my_contribution if _my_contribution is Color else Color(0, 0, 0, 0)
	var current: Color = _property_target_node.get_indexed(property_path)
	var delta := Color(offset.r - prev.r, offset.g - prev.g, offset.b - prev.b, offset.a - prev.a)
	_property_target_node.set_indexed(property_path, Color(
		current.r + delta.r, current.g + delta.g,
		current.b + delta.b, current.a + delta.a
	))
	_my_contribution = offset

# =============================================================================
# BASE CAPTURE
# =============================================================================

func _capture_base() -> void:
	if _has_base:
		return

	if not is_instance_valid(_property_target_node):
		push_warning("[%s] Cannot capture base — no valid target node" % name)
		return

	_base_value = _property_target_node.get_indexed(property_path)
	_has_base = true

	if debug_enabled:
		print("[%s] Captured property base: %s = %s" % [name, property_path, _base_value])

# =============================================================================
# SEQUENCER RECIPE CONTRACT
# =============================================================================

func _recipe_capture_natural(_target: Node) -> Variant:
	# For property shake, we capture the property value from the resolved target,
	# not from the 'target' parameter (which is the juice component's parent).
	# The recipe system needs to know our property's natural state.
	if is_instance_valid(_property_target_node) and not property_path.is_empty():
		return {"property_value": _property_target_node.get_indexed(property_path)}
	return null


func _recipe_apply_natural(_target: Node, natural: Variant) -> void:
	if not (natural is Dictionary):
		return
	var dict := natural as Dictionary
	_base_value = dict.get("property_value")
	_has_base = true


func _recipe_restore_natural(_target: Node, natural: Variant) -> void:
	if not (natural is Dictionary):
		return
	if not is_instance_valid(_property_target_node):
		return
	var dict := natural as Dictionary
	var value: Variant = dict.get("property_value")
	if value != null:
		_property_target_node.set_indexed(property_path, value)

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if property_path.is_empty():
		warnings.append("property_path must be configured (e.g. 'position:x', 'modulate:r').")
	return warnings
