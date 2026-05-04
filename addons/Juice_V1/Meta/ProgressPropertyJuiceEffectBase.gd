## Domain-agnostic continuous-accumulation (Progress) effect targeting any node property.
##
## Uses set_indexed() to write directly to the target property — approved exception
## to the delta system (same pattern as TimeJuiceEffectBase).

# =============================================================================
# WHAT: Accumulates any float/Vector2/Vector3/Color property on any node.
# WHY:  Defines a resource-based progress driver for the Property family.
#       Domain-agnostic: targets any property via string path on any node.
#       Examples: "modulate:a", "material:shader_parameter/dissolve", "speed"
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# DOES NOT: Use the delta system — writes directly via set_indexed() (approved exception).
# DOES NOT: Handle position/rotation/scale — use ProgressTransform2D/Control/3DJuiceEffect.
#
# APPROVED EXCEPTION: ProgressProperty writes via set_indexed() because:
# 1. Domain nodes don't know about arbitrary user properties.
# 2. Stacking multiple ProgressProperty effects on different paths is still valid.
# 3. Same exception pattern as TimeJuiceEffectBase (writes Engine.time_scale directly).
# See CONTRACTS/l3-effects.md "Approved Direct-Write Exceptions".
# =============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseProperty.svg")
class_name PropertyProgressJuiceEffectBase
extends JuiceEffectBase


# =============================================================================
# ENUMS
# =============================================================================

## Target property value type. Determines which rate var is used.
enum PropertyType {
	FLOAT,    ## Float property (e.g., modulate.a, speed)
	VECTOR2,  ## Vector2 property (e.g., position, uv_offset)
	VECTOR3,  ## Vector3 property (e.g., angular_velocity)
	COLOR     ## Color property (e.g., modulate) — accumulated per channel
}

## What to do when accumulated distance reaches the bound.
enum BoundBehaviour {
	EMIT_COMPLETED,  ## Emit completed signal (fires chaining).
	REVERSE,         ## Instant direction flip (ping-pong).
	REVERSE_EASED,   ## Smooth direction change via eased deceleration + restart.
	WRAP,            ## Reset accumulated to 0, continue (looping).
	STOP,            ## Stop accumulation, hold at bound value.
	DESTROY_PARENT   ## queue_free() the parent node.
}


# =============================================================================
# CONFIGURATION
# =============================================================================

func _init() -> void:
	_subclass_owns_effect_group = true


## String path to the target property on the target node.
## Use indexed syntax: "modulate:a", "material:shader_parameter/my_param"
var property_path: String = "":
	set(value):
		property_path = value
		notify_property_list_changed()

## Which value type the target property expects.
var property_type: int = PropertyType.FLOAT:
	set(value):
		property_type = value
		notify_property_list_changed()

## Begin accumulating immediately on _ready instead of waiting for a trigger.
var auto_start: bool = false
## When true, the accumulated value persists after stop. When false, restores to pre-animation value.
var hold_on_stop: bool = true

# --- Rate vars (one visible at a time based on property_type) ---
var float_rate: float = 1.0
var vector2_rate: Vector2 = Vector2(1.0, 0.0)
var vector3_rate: Vector3 = Vector3(0.0, 1.0, 0.0)
var color_rate: Color = Color(0.0, 0.0, 0.0, 0.1)

# --- Bound ---
var bound_enabled: bool = false:
	set(value):
		bound_enabled = value
		notify_property_list_changed()
var bound_behaviour: int = BoundBehaviour.REVERSE
var bound_value: float = 1.0


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	props.append({"name": "Effect", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "property_path", "type": TYPE_STRING,
		"hint": PROPERTY_HINT_NONE, "usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "property_type", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Float,Vector2,Vector3,Color",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append_array(_get_effect_base_properties())
	props.append({"name": "auto_start", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "hold_on_stop", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})

	# Rate — only the field matching property_type is shown.
	match property_type:
		PropertyType.FLOAT:
			props.append({"name": "float_rate", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_DEFAULT})
		PropertyType.VECTOR2:
			props.append({"name": "vector2_rate", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_DEFAULT})
		PropertyType.VECTOR3:
			props.append({"name": "vector3_rate", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_DEFAULT})
		PropertyType.COLOR:
			props.append({"name": "color_rate", "type": TYPE_COLOR, "usage": PROPERTY_USAGE_DEFAULT})

	# Bound — conditional expansion.
	props.append({"name": "bound_enabled", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_DEFAULT})
	if bound_enabled:
		props.append({"name": "bound_behaviour", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Emit Completed,Reverse,Reverse Eased,Wrap,Stop,Destroy Parent",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "bound_value", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_DEFAULT})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"property_path": property_path = value; return true
		&"property_type": property_type = value; return true
		&"auto_start": auto_start = value; return true
		&"hold_on_stop": hold_on_stop = value; return true
		&"float_rate": float_rate = value; return true
		&"vector2_rate": vector2_rate = value; return true
		&"vector3_rate": vector3_rate = value; return true
		&"color_rate": color_rate = value; return true
		&"bound_enabled": bound_enabled = value; return true
		&"bound_behaviour": bound_behaviour = value; return true
		&"bound_value": bound_value = value; return true
	return super._set(property, value)


func _get(property: StringName) -> Variant:
	match property:
		&"property_path": return property_path
		&"property_type": return property_type
		&"auto_start": return auto_start
		&"hold_on_stop": return hold_on_stop
		&"float_rate": return float_rate
		&"vector2_rate": return vector2_rate
		&"vector3_rate": return vector3_rate
		&"color_rate": return color_rate
		&"bound_enabled": return bound_enabled
		&"bound_behaviour": return bound_behaviour
		&"bound_value": return bound_value
	return super._get(property)


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _accumulated_float: float = 0.0
var _accumulated_vec2: Vector2 = Vector2.ZERO
var _accumulated_vec3: Vector3 = Vector3.ZERO
var _accumulated_color: Color = Color(0.0, 0.0, 0.0, 0.0)

var _base_float: float = 0.0
var _base_vec2: Vector2 = Vector2.ZERO
var _base_vec3: Vector3 = Vector3.ZERO
var _base_color: Color = Color.WHITE
var _has_base: bool = false

var _current_direction: float = 1.0
var _awaiting_reverse_eased: bool = false
var _pending_restart_reversed: bool = false
## Stores delta from tick() for use in _apply_effect() — Resources have no process()
var _last_delta: float = 0.0


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

## Progress accumulates every frame based on delta, requiring continuous ticking.
func _needs_sustain() -> bool:
	return true


## Captures base values on first play to establish the starting accumulation point.
func _on_animate_start(target: Node) -> void:
	if not _has_base:
		_capture_base(target)
	JuiceLogger.log_info(self, _get_domain_tag(),
			"animate_start: property='%s' type=%s dir=%.0f hold=%s bound=%s" % [
			property_path, PropertyType.keys()[property_type], _current_direction,
			hold_on_stop, bound_enabled],
			debug_enabled)
	# Type-conditional rate — a wrong rate here fully explains any wrong accumulation speed.
	match property_type:
		PropertyType.FLOAT:
			JuiceLogger.log_capture(self, _get_domain_tag(), "rate",
					{"float_rate": float_rate}, debug_enabled)
		PropertyType.VECTOR2:
			JuiceLogger.log_capture(self, _get_domain_tag(), "rate",
					{"vector2_rate": vector2_rate}, debug_enabled)
		PropertyType.VECTOR3:
			JuiceLogger.log_capture(self, _get_domain_tag(), "rate",
					{"vector3_rate": vector3_rate}, debug_enabled)
		PropertyType.COLOR:
			JuiceLogger.log_capture(self, _get_domain_tag(), "rate",
					{"color_rate": color_rate}, debug_enabled)
	if bound_enabled:
		JuiceLogger.log_capture(self, _get_domain_tag(), "bound",
				{"behaviour": BoundBehaviour.keys()[bound_behaviour],
				"value": bound_value}, debug_enabled)


## Restores the target to its pre-accumulation state if hold_on_stop is false.
func _restore_to_natural(target: Node) -> void:
	# Log the accumulated state before clearing — silent clears are the #1 undiagnosable bug.
	var acc_log: Variant
	match property_type:
		PropertyType.FLOAT:   acc_log = _accumulated_float
		PropertyType.VECTOR2: acc_log = _accumulated_vec2
		PropertyType.VECTOR3: acc_log = _accumulated_vec3
		PropertyType.COLOR:   acc_log = _accumulated_color
	JuiceLogger.log_info(self, _get_domain_tag(),
			"restore_to_natural: hold=%s accumulated=%s path='%s'" % [
			hold_on_stop, acc_log, property_path], debug_enabled)
	if not hold_on_stop:
		_reset_accumulated()
		_has_base = false
		_write_natural(target)


## Intercepts the tick to cache the delta time for _apply_effect, since Resources don't have _process.
func tick(delta: float, target: Node) -> JuiceEffectBase.TickResult:
	_last_delta = delta
	_pending_restart_reversed = false
	var result := super.tick(delta, target)
	if _pending_restart_reversed:
		_pending_restart_reversed = false
		return JuiceEffectBase.TickResult.RESTART_REVERSED
	return result


# =============================================================================
# APPLY EFFECT — direct write via set_indexed()
# =============================================================================

## Accumulates the typed rate * delta * progress and writes it directly to the target via set_indexed.
func _apply_effect(progress: float, target: Node) -> void:
	if property_path.is_empty():
		JuiceLogger.warn(self, _get_domain_tag(),
				"property_path is empty — accumulation skipped", debug_enabled)
		return

	# When hold_on_stop=false and progress reaches 0 (animate_out at rest),
	# write natural values back immediately so target visually resets.
	if not hold_on_stop and progress <= 0.0:
		JuiceLogger.log_info(self, _get_domain_tag(),
				"apply_effect: progress<=0 + hold=false — resetting to natural", debug_enabled)
		_reset_accumulated()
		_write_natural(target)
		return

	var delta := _last_delta

	match property_type:
		PropertyType.FLOAT:
			_accumulated_float += float_rate * delta * progress * _current_direction
			target.set_indexed(property_path, _base_float + _accumulated_float)

		PropertyType.VECTOR2:
			_accumulated_vec2 += vector2_rate * delta * progress * _current_direction
			var new_val: Vector2 = _base_vec2 + _accumulated_vec2
			target.set_indexed(property_path, new_val)

		PropertyType.VECTOR3:
			_accumulated_vec3 += vector3_rate * delta * progress * _current_direction
			var new_val3: Vector3 = _base_vec3 + _accumulated_vec3
			target.set_indexed(property_path, new_val3)

		PropertyType.COLOR:
			_accumulated_color.r += color_rate.r * delta * progress * _current_direction
			_accumulated_color.g += color_rate.g * delta * progress * _current_direction
			_accumulated_color.b += color_rate.b * delta * progress * _current_direction
			_accumulated_color.a += color_rate.a * delta * progress * _current_direction
			var new_color := Color(
				_base_color.r + _accumulated_color.r,
				_base_color.g + _accumulated_color.g,
				_base_color.b + _accumulated_color.b,
				clampf(_base_color.a + _accumulated_color.a, 0.0, 1.0)
			)
			target.set_indexed(property_path, new_color)

	if bound_enabled and progress > 0.0:
		_check_bounds(target)
	# Log accumulated value (type-conditional) + delta_t + dir —
	# separates "wrong rate", "wrong delta_t", "wrong direction", and "bound fired" causes.
	var acc_log: Variant
	match property_type:
		PropertyType.FLOAT:   acc_log = _accumulated_float
		PropertyType.VECTOR2: acc_log = _accumulated_vec2
		PropertyType.VECTOR3: acc_log = _accumulated_vec3
		PropertyType.COLOR:   acc_log = _accumulated_color
	JuiceLogger.log_delta(self, _get_domain_tag(), progress,
			{"delta_t": delta, "accumulated": acc_log, "dir": _current_direction,
			"path": property_path},
			target.name, debug_enabled)


# =============================================================================
# BOUND CHECKING
# =============================================================================

# Applies boundary logic (wrap, reverse, stop) when the accumulated value exceeds the configured bound.
func _check_bounds(target: Node) -> void:
	if _awaiting_reverse_eased:
		return
	if not _is_bound_exceeded():
		return

	_clamp_to_bound(target)

	var accumulated_at_bound: Variant
	match property_type:
		PropertyType.FLOAT:   accumulated_at_bound = _accumulated_float
		PropertyType.VECTOR2: accumulated_at_bound = _accumulated_vec2
		PropertyType.VECTOR3: accumulated_at_bound = _accumulated_vec3
		PropertyType.COLOR:   accumulated_at_bound = _accumulated_color
	JuiceLogger.log_info(self, _get_domain_tag(),
			"bound reached: behaviour=%s accumulated=%s" % [
			BoundBehaviour.keys()[bound_behaviour], accumulated_at_bound],
			debug_enabled)

	match bound_behaviour:
		BoundBehaviour.EMIT_COMPLETED:
			# Notify host — effects signal completion via lifecycle; host emits its own signal
			_is_playing = false
		BoundBehaviour.REVERSE:
			_absorb_accumulated_into_base()
			_current_direction *= -1.0
			JuiceLogger.log_info(self, _get_domain_tag(),
					"direction flipped: new_dir=%.0f" % _current_direction, debug_enabled)
		BoundBehaviour.REVERSE_EASED:
			_absorb_accumulated_into_base()
			_current_direction *= -1.0
			JuiceLogger.log_info(self, _get_domain_tag(),
					"direction flipped (eased): new_dir=%.0f" % _current_direction, debug_enabled)
			_pending_restart_reversed = true
		BoundBehaviour.WRAP:
			_wrap_accumulated()
		BoundBehaviour.STOP:
			_is_playing = false
		BoundBehaviour.DESTROY_PARENT:
			if _host_node != null and is_instance_valid(_host_node):
				var parent := _host_node.get_parent()
				if parent != null:
					parent.queue_free()


# Evaluates whether the accumulated distance has breached the bound limit across the configured data type.
func _is_bound_exceeded() -> bool:
	match property_type:
		PropertyType.FLOAT:
			return absf(_accumulated_float) > bound_value
		PropertyType.VECTOR2:
			return _accumulated_vec2.length() > bound_value
		PropertyType.VECTOR3:
			return _accumulated_vec3.length() > bound_value
		PropertyType.COLOR:
			return (absf(_accumulated_color.a) > bound_value or
					absf(_accumulated_color.r) > bound_value or
					absf(_accumulated_color.g) > bound_value or
					absf(_accumulated_color.b) > bound_value)
	return false


# Snaps the accumulated value exactly to the boundary limit to prevent overshoot drifting on reversal or stop.
func _clamp_to_bound(target: Node) -> void:
	if property_path.is_empty():
		return
	match property_type:
		PropertyType.FLOAT:
			_accumulated_float = clampf(_accumulated_float, -bound_value, bound_value)
			target.set_indexed(property_path, _base_float + _accumulated_float)
		PropertyType.VECTOR2:
			var len := _accumulated_vec2.length()
			if len > bound_value and len > 0.0:
				_accumulated_vec2 = _accumulated_vec2.normalized() * bound_value
			target.set_indexed(property_path, _base_vec2 + _accumulated_vec2)
		PropertyType.VECTOR3:
			var len3 := _accumulated_vec3.length()
			if len3 > bound_value and len3 > 0.0:
				_accumulated_vec3 = _accumulated_vec3.normalized() * bound_value
			target.set_indexed(property_path, _base_vec3 + _accumulated_vec3)
		PropertyType.COLOR:
			_accumulated_color.r = clampf(_accumulated_color.r, -bound_value, bound_value)
			_accumulated_color.g = clampf(_accumulated_color.g, -bound_value, bound_value)
			_accumulated_color.b = clampf(_accumulated_color.b, -bound_value, bound_value)
			_accumulated_color.a = clampf(_accumulated_color.a, -1.0, 1.0)
			target.set_indexed(property_path, Color(
				_base_color.r + _accumulated_color.r,
				_base_color.g + _accumulated_color.g,
				_base_color.b + _accumulated_color.b,
				clampf(_base_color.a + _accumulated_color.a, 0.0, 1.0)
			))


# Resets the accumulation value to zero (or wraps via modulo) for continuous looping effects.
func _wrap_accumulated() -> void:
	match property_type:
		PropertyType.FLOAT:
			_accumulated_float = fmod(_accumulated_float, bound_value) if bound_value > 0.0 else 0.0
		PropertyType.VECTOR2:
			_accumulated_vec2 = Vector2.ZERO
		PropertyType.VECTOR3:
			_accumulated_vec3 = Vector3.ZERO
		PropertyType.COLOR:
			_accumulated_color = Color(0.0, 0.0, 0.0, 0.0)


# =============================================================================
# HELPERS
# =============================================================================

# Bakes the current accumulation into the base value before reversing direction to prevent snap-back on ping-pong effects.
func _absorb_accumulated_into_base() -> void:
	match property_type:
		PropertyType.FLOAT:
			_base_float += _accumulated_float
			_accumulated_float = 0.0
		PropertyType.VECTOR2:
			_base_vec2 += _accumulated_vec2
			_accumulated_vec2 = Vector2.ZERO
		PropertyType.VECTOR3:
			_base_vec3 += _accumulated_vec3
			_accumulated_vec3 = Vector3.ZERO
		PropertyType.COLOR:
			_base_color.r += _accumulated_color.r
			_base_color.g += _accumulated_color.g
			_base_color.b += _accumulated_color.b
			_base_color.a = clampf(_base_color.a + _accumulated_color.a, 0.0, 1.0)
			_accumulated_color = Color(0.0, 0.0, 0.0, 0.0)


# Clears all active accumulators back to zero.
func _reset_accumulated() -> void:
	_accumulated_float = 0.0
	_accumulated_vec2 = Vector2.ZERO
	_accumulated_vec3 = Vector3.ZERO
	_accumulated_color = Color(0.0, 0.0, 0.0, 0.0)


# Reads the true natural property value directly from the engine before any Juice accumulation starts.
func _capture_base(target: Node) -> void:
	if _has_base or property_path.is_empty():
		return
	var value := target.get_indexed(property_path)
	match property_type:
		PropertyType.FLOAT:
			_base_float = float(value) if value != null else 0.0
		PropertyType.VECTOR2:
			_base_vec2 = value as Vector2 if value is Vector2 else Vector2.ZERO
		PropertyType.VECTOR3:
			_base_vec3 = value as Vector3 if value is Vector3 else Vector3.ZERO
		PropertyType.COLOR:
			_base_color = value as Color if value is Color else Color.WHITE
	_has_base = true
	JuiceLogger.log_capture(self, _get_domain_tag(), "base",
			"property='%s' value=%s" % [property_path, value],
			debug_enabled)


# Writes the unmodified base value back to the engine property on stop.
func _write_natural(target: Node) -> void:
	if property_path.is_empty():
		return
	match property_type:
		PropertyType.FLOAT:
			target.set_indexed(property_path, _base_float)
		PropertyType.VECTOR2:
			target.set_indexed(property_path, _base_vec2)
		PropertyType.VECTOR3:
			target.set_indexed(property_path, _base_vec3)
		PropertyType.COLOR:
			target.set_indexed(property_path, _base_color)


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

# Warns users if the dynamic property path is empty, which would cause silent failure.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if property_path.is_empty():
		warnings.append("Property Path is empty. Set a valid property path (e.g., 'modulate:a').")
	return warnings
