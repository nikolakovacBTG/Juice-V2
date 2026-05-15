## Continuously accumulates an arbitrary named property at a configurable rate,
## scaled by the Juice progress envelope (0–1).
##
## The effect keeps ticking after animate-in completes ([method _needs_sustain]
## returns true). Stop via [method animate_out] to decelerate, or let the bound
## system reverse/wrap/halt automatically.

# =============================================================================
# WHAT: Continuous rate-accumulator for arbitrary named node properties.
#       Each frame: accumulated += rate * delta * progress * direction.
#       Delta is registered in JuiceLedger so stacking with other property
#       effects on the same path is automatic and conflict-free.
# WHY:  This is the property-family equivalent of ProgressTransform2D/3D/Control.
#       Interpolate drives a property FROM → TO over a fixed duration.
#       Progress drives a property CONTINUOUSLY at a rate, indefinitely, with
#       optional bounds (reverse, wrap, stop, etc.) controlling what happens
#       when the accumulated value reaches a designer-set limit.
#       Use cases: shader progress, custom fill bars, continuous rotation of a UI
#       dial, any value that accumulates over time driven by Juice's envelope.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Handle transform (position/rotation/scale) — use ProgressTransform family.
#           Does not support multiple target paths — use one effect per path.
#           Does not write to nodes directly — routes through JuiceLedger.
# =============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseProperty.svg")
class_name ProgressPropertyJuiceEffectBase
extends PropertyJuiceEffectBase


# =============================================================================
# ENUMS
# =============================================================================

## Type of the target property. Determines which rate variable is shown and
## which accumulator is advanced each frame.
enum PropertyType { FLOAT, VECTOR2, VECTOR3, COLOR }

## What to do when the accumulated magnitude reaches [member bound_value].
enum BoundBehaviour {
	EMIT_COMPLETED,  ## Emit the completed signal (triggers chaining).
	REVERSE,         ## Instantly flip accumulation direction (ping-pong).
	REVERSE_EASED,   ## Flip direction and ramp progress back via animate-out/in.
	WRAP,            ## Reset accumulation to zero and continue looping.
	STOP,            ## Halt accumulation at the bound value.
	DESTROY_PARENT   ## Call queue_free() on the Juice node's parent.
}


# =============================================================================
# LIFECYCLE
# =============================================================================

func _init() -> void:
	# Owns the full inspector layout so PropertyJuiceEffectBase does not emit
	# a property_targets array (Progress exposes property_path directly instead).
	_subclass_owns_prop_layout = true


# =============================================================================
# CONFIGURATION
# =============================================================================

## The named property on the target node to accumulate.
## E.g. "rotation_degrees", "modulate:r", "shader_parameter/intensity".
var property_path: String = "":
	set(value):
		property_path = value
		notify_property_list_changed()

## Type of the target property. Controls which rate var is shown in the inspector.
var property_type: int = PropertyType.FLOAT:
	set(value):
		property_type = value
		notify_property_list_changed()

## Begin accumulating immediately when the scene starts, without an explicit
## animate_in() call.
var auto_start: bool = false

## When true (default), stopping holds the accumulated value on the property.
## When false, stop() snaps the property back to its natural base value.
var hold_on_stop: bool = true

# Rate vars — only one is visible in the inspector at a time (matches property_type).
## Accumulation speed in units/second when property type is Float.
var float_rate: float = 1.0
## Accumulation speed per axis in units/second when property type is Vector2.
var vec2_rate: Vector2 = Vector2(1.0, 0.0)
## Accumulation speed per axis in units/second when property type is Vector3.
var vec3_rate: Vector3 = Vector3(1.0, 0.0, 0.0)
## Per-channel additive speed in units/second when property type is Color.
## Values are added to the base color each second. Keep small (0.0–1.0 range).
var color_rate: Color = Color(0.1, 0.0, 0.0, 0.0)

## When enabled, the accumulated value is compared to [member bound_value] each frame.
var bound_enabled: bool = false:
	set(value):
		bound_enabled = value
		notify_property_list_changed()

## Action to take when the accumulated magnitude exceeds [member bound_value].
var bound_behaviour: int = BoundBehaviour.REVERSE

## Magnitude threshold for the bound check.
## For Float: absolute value. For Vector: length(). For Color: any channel.
var bound_value: float = 1.0


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# --- Progress group ---
	props.append({"name": "Progress", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "property_path", "type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "property_type", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Float,Vector2,Vector3,Color",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "auto_start", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "hold_on_stop", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})

	# Only show the rate var matching the selected property_type.
	match property_type:
		PropertyType.FLOAT:
			props.append({"name": "float_rate", "type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT})
		PropertyType.VECTOR2:
			props.append({"name": "vec2_rate", "type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT})
		PropertyType.VECTOR3:
			props.append({"name": "vec3_rate", "type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT})
		PropertyType.COLOR:
			props.append({"name": "color_rate", "type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT})

	# Store all rate vars even when hidden so values survive type switches.
	props.append({"name": "float_rate", "type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_STORAGE if property_type != PropertyType.FLOAT else 0})
	props.append({"name": "vec2_rate", "type": TYPE_VECTOR2,
		"usage": PROPERTY_USAGE_STORAGE if property_type != PropertyType.VECTOR2 else 0})
	props.append({"name": "vec3_rate", "type": TYPE_VECTOR3,
		"usage": PROPERTY_USAGE_STORAGE if property_type != PropertyType.VECTOR3 else 0})
	props.append({"name": "color_rate", "type": TYPE_COLOR,
		"usage": PROPERTY_USAGE_STORAGE if property_type != PropertyType.COLOR else 0})

	# --- Bound group ---
	props.append({"name": "Bound", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "bound_enabled", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})
	if bound_enabled:
		props.append({"name": "bound_behaviour", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Emit Completed,Reverse,Reverse Eased,Wrap,Stop,Destroy Parent",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "bound_value", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,9999.0,0.001,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"property_path":   property_path = value;   return true
		&"property_type":   property_type = value;   return true
		&"auto_start":      auto_start = value;      return true
		&"hold_on_stop":    hold_on_stop = value;    return true
		&"float_rate":      float_rate = value;      return true
		&"vec2_rate":       vec2_rate = value;       return true
		&"vec3_rate":       vec3_rate = value;       return true
		&"color_rate":      color_rate = value;      return true
		&"bound_enabled":   bound_enabled = value;   return true
		&"bound_behaviour": bound_behaviour = value; return true
		&"bound_value":     bound_value = value;     return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"property_path":   return property_path
		&"property_type":   return property_type
		&"auto_start":      return auto_start
		&"hold_on_stop":    return hold_on_stop
		&"float_rate":      return float_rate
		&"vec2_rate":       return vec2_rate
		&"vec3_rate":       return vec3_rate
		&"color_rate":      return color_rate
		&"bound_enabled":   return bound_enabled
		&"bound_behaviour": return bound_behaviour
		&"bound_value":     return bound_value
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

# Per-type accumulators. Only the one matching property_type advances each frame.
var _accumulated_float: float = 0.0
var _accumulated_vec2: Vector2 = Vector2.ZERO
var _accumulated_vec3: Vector3 = Vector3.ZERO
# Color accumulator is an additive offset; _register_accumulated() converts it
# to the Ledger's multiplicative factor form before registering.
var _accumulated_color: Color = Color(0.0, 0.0, 0.0, 0.0)

# Direction multiplier: +1.0 forward, -1.0 after a REVERSE bound flip.
var _current_direction: float = 1.0

# Guards against re-capturing the base on every re-trigger when hold_on_stop=true.
var _base_captured: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

## Progress effects must keep ticking after animate-in so accumulation continues
## at peak speed during the sustain phase.
func _needs_sustain() -> bool:
	return true


## Registers the property path in the Ledger and optionally resets the accumulator.
## When hold_on_stop=true and already running, re-triggering continues from the
## current accumulated position rather than snapping back to zero.
func _on_animate_start(target: Node) -> void:
	if property_path.is_empty():
		return
	# Ledger.ensure() captures the base value before any delta lands.
	JuiceLedger.ensure(target, [property_path])
	if not _base_captured or not hold_on_stop:
		_reset_accumulated()
	_base_captured = true


## Removes this effect's Ledger contributions.
## hold_on_stop=false also resets the accumulator so the next start is clean.
func _restore_to_natural(target: Node) -> void:
	JuiceLedger.cleanup_source(target, self, false)
	if not hold_on_stop:
		_reset_accumulated()
		_base_captured = false


## Before scene save: remove this effect's delta from the Ledger so the offset
## is not baked into the saved transform.
func _temporarily_undo_visual(target: Node) -> void:
	JuiceLedger.cleanup_source(target, self, false)


## After scene save: re-register the current accumulated delta so the live
## visual is restored before the next domain flush.
func _temporarily_reapply_visual(target: Node) -> void:
	_apply_effect(_animation_progress, target)


# =============================================================================
# CORE LOGIC — accumulation per frame
# =============================================================================

## Called every tick by JuiceEffectBase. progress = speed multiplier (0–1).
## Advances the accumulator for this frame and registers the running total
## as a Ledger delta so domain nodes write the correct stacked value.
func _apply_effect(progress: float, target: Node) -> void:
	if property_path.is_empty():
		return
	# When hold_on_stop=false and the effect is fading out (progress→0),
	# reset accumulated and write a zero delta so the property returns to base.
	if not hold_on_stop and progress <= 0.0:
		_reset_accumulated()
		_register_accumulated(target)
		return
	var delta := _current_delta
	match property_type:
		PropertyType.FLOAT:
			_accumulated_float += float_rate * delta * progress * _current_direction
		PropertyType.VECTOR2:
			_accumulated_vec2 += vec2_rate * delta * progress * _current_direction
		PropertyType.VECTOR3:
			_accumulated_vec3 += vec3_rate * delta * progress * _current_direction
		PropertyType.COLOR:
			_accumulated_color.r += color_rate.r * delta * progress * _current_direction
			_accumulated_color.g += color_rate.g * delta * progress * _current_direction
			_accumulated_color.b += color_rate.b * delta * progress * _current_direction
			_accumulated_color.a += color_rate.a * delta * progress * _current_direction
	_register_accumulated(target)
	if bound_enabled and progress > 0.0:
		_check_bounds(target)


# Converts the current accumulator into Ledger form and registers it.
# Float/Vector types: additive delta (accumulated offset from base).
# Color: multiplicative factor (desired / base), matching JuiceLedger's Color path.
func _register_accumulated(target: Node) -> void:
	match property_type:
		PropertyType.FLOAT:
			JuiceLedger.register_delta(target, self, property_path, _accumulated_float)
		PropertyType.VECTOR2:
			JuiceLedger.register_delta(target, self, property_path, _accumulated_vec2)
		PropertyType.VECTOR3:
			JuiceLedger.register_delta(target, self, property_path, _accumulated_vec3)
		PropertyType.COLOR:
			# Ledger's Color path is multiplicative: flush writes base * factor.
			# Convert additive _accumulated_color into a factor: (base + acc) / base.
			# EPS prevents division by zero on zero-channel bases.
			const EPS := 0.0001
			var base_val := JuiceLedger.get_base(target, property_path, Color.WHITE)
			var b := base_val as Color
			var desired := Color(
				b.r + _accumulated_color.r,
				b.g + _accumulated_color.g,
				b.b + _accumulated_color.b,
				b.a + _accumulated_color.a)
			JuiceLedger.register_delta(target, self, property_path,
				Color(desired.r / max(b.r, EPS),
					  desired.g / max(b.g, EPS),
					  desired.b / max(b.b, EPS),
					  desired.a / max(b.a, EPS)))


# Checks whether the accumulated magnitude has exceeded bound_value and fires
# the configured BoundBehaviour if so.
func _check_bounds(target: Node) -> void:
	if not _is_bound_exceeded():
		return
	_clamp_to_bound()
	match bound_behaviour:
		BoundBehaviour.EMIT_COMPLETED:
			_is_playing = false
		BoundBehaviour.REVERSE, BoundBehaviour.REVERSE_EASED:
			# REVERSE_EASED: full TickResult ping-pong requires host cooperation.
			# ProgressProperty fires the direction flip here; the deceleration
			# ramp uses the existing animate_out envelope on the next tick.
			_current_direction *= -1.0
		BoundBehaviour.WRAP:
			_wrap_accumulated()
		BoundBehaviour.STOP:
			_is_playing = false
		BoundBehaviour.DESTROY_PARENT:
			if _host_node != null and is_instance_valid(_host_node):
				var parent := _host_node.get_parent()
				if parent != null:
					parent.queue_free()


# Returns true when the accumulated magnitude has reached or exceeded bound_value.
func _is_bound_exceeded() -> bool:
	match property_type:
		PropertyType.FLOAT:
			return absf(_accumulated_float) >= bound_value
		PropertyType.VECTOR2:
			return _accumulated_vec2.length() >= bound_value
		PropertyType.VECTOR3:
			return _accumulated_vec3.length() >= bound_value
		PropertyType.COLOR:
			return (absf(_accumulated_color.r) >= bound_value or
					absf(_accumulated_color.g) >= bound_value or
					absf(_accumulated_color.b) >= bound_value or
					absf(_accumulated_color.a) >= bound_value)
	return false


# Clamps the accumulator to the bound so the visual does not overshoot.
func _clamp_to_bound() -> void:
	match property_type:
		PropertyType.FLOAT:
			_accumulated_float = clampf(_accumulated_float, -bound_value, bound_value)
		PropertyType.VECTOR2:
			var l := _accumulated_vec2.length()
			if l > bound_value and l > 0.0:
				_accumulated_vec2 = _accumulated_vec2.normalized() * bound_value
		PropertyType.VECTOR3:
			var l := _accumulated_vec3.length()
			if l > bound_value and l > 0.0:
				_accumulated_vec3 = _accumulated_vec3.normalized() * bound_value
		PropertyType.COLOR:
			_accumulated_color.r = clampf(_accumulated_color.r, -bound_value, bound_value)
			_accumulated_color.g = clampf(_accumulated_color.g, -bound_value, bound_value)
			_accumulated_color.b = clampf(_accumulated_color.b, -bound_value, bound_value)
			_accumulated_color.a = clampf(_accumulated_color.a, -bound_value, bound_value)


# Resets the accumulator to zero. Called on fresh start or when hold_on_stop=false.
func _reset_accumulated() -> void:
	_accumulated_float = 0.0
	_accumulated_vec2 = Vector2.ZERO
	_accumulated_vec3 = Vector3.ZERO
	_accumulated_color = Color(0.0, 0.0, 0.0, 0.0)
	_current_direction = 1.0


# Wraps accumulated to zero so the property loops back to base and continues.
# Used by the WRAP BoundBehaviour.
func _wrap_accumulated() -> void:
	match property_type:
		PropertyType.FLOAT:   _accumulated_float = 0.0
		PropertyType.VECTOR2: _accumulated_vec2 = Vector2.ZERO
		PropertyType.VECTOR3: _accumulated_vec3 = Vector3.ZERO
		PropertyType.COLOR:   _accumulated_color = Color(0.0, 0.0, 0.0, 0.0)


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if property_path.is_empty():
		warnings.append("No property_path set — this effect will not accumulate any property.")
	if bound_enabled and bound_value <= 0.0:
		warnings.append("bound_value is 0 or negative — bound will fire immediately on every frame.")
	return warnings
