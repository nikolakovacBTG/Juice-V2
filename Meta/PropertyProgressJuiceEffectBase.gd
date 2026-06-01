## Continuously accumulates arbitrary named properties at configurable rates,
## scaled by the Juice progress envelope (0–1).
##
## The effect keeps ticking after animate-in completes ([method _needs_sustain]
## returns true). Stop via [method animate_out] to decelerate, or let the bound
## system reverse/wrap/halt automatically.
##
## Each [ProgressPropertyTarget] carries its own rate and auto-detected type.
## Multiple targets are supported — each accumulates independently.

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
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Handle transform (position/rotation/scale) — use ProgressTransform family.
#           Does not write to nodes directly — routes through JuiceLedger.
# =============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseProperty.svg")
class_name PropertyProgressJuiceEffectBase
extends PropertyJuiceEffectBase


# =============================================================================
# ENUMS
# =============================================================================

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
	# a property_targets array (Progress emits its own with ProgressPropertyTarget type).
	_subclass_owns_prop_layout = true


# =============================================================================
# CONFIGURATION
# =============================================================================

## Begin accumulating immediately when the scene starts, without an explicit
## animate_in() call.
var auto_start: bool = false

## When true (default), stopping holds the accumulated value on the property.
## When false, stop() snaps the property back to its natural base value.
var hold_on_stop: bool = true

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
	props.append({"name": "auto_start", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "hold_on_stop", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})

	# --- Property Targets typed array ---
	props.append({"name": "Property Targets", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({
		"name": "property_targets",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%d/%d:%s" % [
			TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "ProgressPropertyTarget"],
		"usage": PROPERTY_USAGE_DEFAULT
	})

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


## Tells PropertyJuiceEffectBase which resource subclass to use when the
## parent's _get_property_list() is queried (not active here since
## _subclass_owns_prop_layout = true, but kept for API completeness).
func _get_target_resource_type() -> String:
	return "ProgressPropertyTarget"


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"auto_start":      auto_start = value;      return true
		&"hold_on_stop":    hold_on_stop = value;    return true
		&"bound_enabled":   bound_enabled = value;   return true
		&"bound_behaviour": bound_behaviour = value; return true
		&"bound_value":     bound_value = value;     return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"auto_start":      return auto_start
		&"hold_on_stop":    return hold_on_stop
		&"bound_enabled":   return bound_enabled
		&"bound_behaviour": return bound_behaviour
		&"bound_value":     return bound_value
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

# Per-target accumulators keyed by property_path string.
# Values are typed to match the target's _detected_type (float, Vector2, etc.).
var _accumulators: Dictionary = {}

# Direction multiplier: +1.0 forward, -1.0 after a REVERSE bound flip.
var _current_direction: float = 1.0

# Guards against re-capturing the base on every re-trigger when hold_on_stop=true.
var _base_captured: bool = false

# Signal to tick() that RESTART_REVERSED should be returned.
# Set by _check_bounds() when REVERSE_EASED fires.
var _pending_restart_reversed: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

## Progress effects must keep ticking after animate-in so accumulation continues
## at peak speed during the sustain phase.
func _needs_sustain() -> bool:
	return true


## Stashes the RESTART_REVERSED flag set by _check_bounds() during _apply_effect().
## When REVERSE_EASED fires, the host re-triggers animate_out→animate_in with the
## flipped direction, producing a smooth eased ping-pong.
func tick(delta: float, target: Node) -> JuiceEffectBase.TickResult:
	_pending_restart_reversed = false
	var result := super.tick(delta, target)
	if _pending_restart_reversed:
		_pending_restart_reversed = false
		return JuiceEffectBase.TickResult.RESTART_REVERSED
	return result


## Registers all property paths in the Ledger and optionally resets accumulators.
## When hold_on_stop=true and already running, re-triggering continues from the
## current accumulated position rather than snapping back to zero.
func _on_animate_start(target: Node) -> void:
	# Collect property paths from targets for Ledger registration.
	var paths: Array[String] = []
	for pt in property_targets:
		var entry := pt as ProgressPropertyTarget
		if entry != null and not entry.property_path.is_empty():
			paths.append(entry.property_path)
	if paths.is_empty():
		return
	JuiceLedger.ensure(target, paths)
	if not _base_captured or not hold_on_stop:
		_reset_all_accumulators()
	_base_captured = true


## Removes this effect's Ledger contributions.
## hold_on_stop=false also resets accumulators so the next start is clean.
func _restore_to_natural(target: Node) -> void:
	JuiceLedger.cleanup_source(target, self, false)
	if not hold_on_stop:
		_reset_all_accumulators()
		_base_captured = false


## Before scene save: remove this effect's delta from the Ledger.
func _temporarily_undo_visual(target: Node) -> void:
	JuiceLedger.cleanup_source(target, self, false)


## After scene save: re-register the current accumulated deltas.
func _temporarily_reapply_visual(target: Node) -> void:
	_apply_effect(_animation_progress, target)


# =============================================================================
# CORE LOGIC — accumulation per frame
# =============================================================================

## Called every tick by JuiceEffectBase. progress = speed multiplier (0–1).
## Advances accumulators for all targets and registers running totals via Ledger.
func _apply_effect(progress: float, target: Node) -> void:
	var delta := _current_delta
	for pt in property_targets:
		var entry := pt as ProgressPropertyTarget
		if entry == null or entry.property_path.is_empty():
			continue
		var prop := entry.property_path

		# When hold_on_stop=false and fading out, reset and write zero delta.
		if not hold_on_stop and progress <= 0.0:
			_accumulators[prop] = _zero_for_type(entry._detected_type)
			_register_one(target, entry)
			continue

		# Accumulate: rate * frame_delta * progress_envelope * direction
		var acc: Variant = _accumulators.get(prop, _zero_for_type(entry._detected_type))
		acc = _advance_accumulator(entry, acc, delta, progress)
		_accumulators[prop] = acc
		_register_one(target, entry)

	if bound_enabled and progress > 0.0:
		_check_bounds(target)


# Advances one accumulator by one frame step.
func _advance_accumulator(entry: ProgressPropertyTarget, acc: Variant, delta: float, progress: float) -> Variant:
	var step := delta * progress * _current_direction
	match entry._detected_type:
		TYPE_FLOAT:
			return acc + entry.float_rate * step
		TYPE_INT:
			return acc + entry.float_rate * step
		TYPE_VECTOR2:
			return acc + entry.vec2_rate * step
		TYPE_VECTOR2I:
			return acc + entry.vec2_rate * step
		TYPE_VECTOR3:
			return acc + entry.vec3_rate * step
		TYPE_VECTOR3I:
			return acc + entry.vec3_rate * step
		TYPE_VECTOR4:
			return acc + entry.vec4_rate * step
		TYPE_VECTOR4I:
			return acc + entry.vec4_rate * step
		TYPE_QUATERNION:
			# quat_rate is euler degrees/sec → convert to radian offset for this frame.
			var euler_rad := Vector3(
				deg_to_rad(entry.quat_rate.x),
				deg_to_rad(entry.quat_rate.y),
				deg_to_rad(entry.quat_rate.z)) * step
			return acc * Quaternion.from_euler(euler_rad)
		TYPE_RECT2:
			return Rect2(
				acc.position + entry.rect2_rate.position * step,
				acc.size + entry.rect2_rate.size * step)
		TYPE_RECT2I:
			var r := entry.rect2_rate
			return Rect2(
				acc.position.x + r.position.x * step,
				acc.position.y + r.position.y * step,
				acc.size.x + r.size.x * step,
				acc.size.y + r.size.y * step)
		TYPE_AABB:
			return AABB(
				acc.position + entry.aabb_rate.position * step,
				acc.size + entry.aabb_rate.size * step)
		TYPE_COLOR:
			return Color(
				acc.r + entry.color_rate.r * step,
				acc.g + entry.color_rate.g * step,
				acc.b + entry.color_rate.b * step,
				acc.a + entry.color_rate.a * step)
		TYPE_PLANE:
			# Element-wise: Plane has no native + operator.
			var p := acc as Plane
			var r := entry.plane_rate
			return Plane(
				Vector3(p.normal.x + r.normal.x * step,
						p.normal.y + r.normal.y * step,
						p.normal.z + r.normal.z * step),
				p.d + r.d * step)
		TYPE_BASIS:
			# Element-wise: accumulate per-row. Basis has no native + operator.
			var b := acc as Basis
			var r := entry.basis_rate
			return Basis(
				b.x + r.x * step,
				b.y + r.y * step,
				b.z + r.z * step)
		TYPE_PROJECTION:
			# Element-wise: accumulate per-column. Projection has no native + operator.
			var pj := acc as Projection
			var r := entry.projection_rate
			return Projection(
				Vector4(pj.x.x + r.x.x * step, pj.x.y + r.x.y * step,
						pj.x.z + r.x.z * step, pj.x.w + r.x.w * step),
				Vector4(pj.y.x + r.y.x * step, pj.y.y + r.y.y * step,
						pj.y.z + r.y.z * step, pj.y.w + r.y.w * step),
				Vector4(pj.z.x + r.z.x * step, pj.z.y + r.z.y * step,
						pj.z.z + r.z.z * step, pj.z.w + r.z.w * step),
				Vector4(pj.w.x + r.w.x * step, pj.w.y + r.w.y * step,
						pj.w.z + r.w.z * step, pj.w.w + r.w.w * step))
	return acc


# Converts the current accumulator for one target into Ledger form and registers it.
# Float/Vector types: additive delta (accumulated offset from base).
# Color: multiplicative factor (desired / base), matching JuiceLedger's Color path.
func _register_one(target: Node, entry: ProgressPropertyTarget) -> void:
	var prop := entry.property_path
	var acc: Variant = _accumulators.get(prop, _zero_for_type(entry._detected_type))

	if entry._detected_type == TYPE_COLOR:
		# Ledger's Color path is multiplicative: flush writes base * factor.
		# Convert additive accumulated into factor: (base + acc) / base.
		const EPS := 0.0001
		var base_val := JuiceLedger.get_base(target, prop, Color.WHITE)
		var b := base_val as Color
		var desired := Color(b.r + acc.r, b.g + acc.g, b.b + acc.b, b.a + acc.a)
		JuiceLedger.register_delta(target, self, prop,
			Color(desired.r / max(b.r, EPS),
				  desired.g / max(b.g, EPS),
				  desired.b / max(b.b, EPS),
				  desired.a / max(b.a, EPS)))
	elif entry._detected_type == TYPE_QUATERNION:
		# Quaternion Ledger delta is the accumulated rotation itself.
		JuiceLedger.register_delta(target, self, prop, acc)
	else:
		JuiceLedger.register_delta(target, self, prop, acc)


# =============================================================================
# BOUND SYSTEM
# =============================================================================

# Checks whether ANY target's accumulated magnitude has exceeded bound_value
# and fires the configured BoundBehaviour if so.
func _check_bounds(target: Node) -> void:
	if not _any_bound_exceeded():
		return
	_clamp_all_to_bound()
	match bound_behaviour:
		BoundBehaviour.EMIT_COMPLETED:
			_is_playing = false
		BoundBehaviour.REVERSE:
			_current_direction *= -1.0
		BoundBehaviour.REVERSE_EASED:
			_current_direction *= -1.0
			_pending_restart_reversed = true
		BoundBehaviour.WRAP:
			_wrap_all_accumulators()
		BoundBehaviour.STOP:
			_is_playing = false
		BoundBehaviour.DESTROY_PARENT:
			if _host_node != null and is_instance_valid(_host_node):
				var parent := _host_node.get_parent()
				if parent != null:
					parent.queue_free()


# Returns true when any target's accumulated magnitude has reached bound_value.
func _any_bound_exceeded() -> bool:
	for pt in property_targets:
		var entry := pt as ProgressPropertyTarget
		if entry == null or entry.property_path.is_empty():
			continue
		var acc: Variant = _accumulators.get(entry.property_path,
				_zero_for_type(entry._detected_type))
		if _is_magnitude_exceeded(entry._detected_type, acc):
			return true
	return false


# Checks magnitude for one accumulator value.
func _is_magnitude_exceeded(type: int, acc: Variant) -> bool:
	match type:
		TYPE_FLOAT, TYPE_INT:
			return absf(float(acc)) >= bound_value
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return Vector2(acc).length() >= bound_value
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return Vector3(acc).length() >= bound_value
		TYPE_VECTOR4, TYPE_VECTOR4I:
			return Vector4(acc).length() >= bound_value
		TYPE_QUATERNION:
			# Magnitude = angle of accumulated rotation in degrees.
			var q := acc as Quaternion
			if q != null:
				return rad_to_deg(q.get_angle()) >= bound_value
			return false
		TYPE_RECT2, TYPE_RECT2I:
			var r := acc as Rect2
			if r != null:
				return (Vector2(r.position).length() >= bound_value or
						Vector2(r.size).length() >= bound_value)
			return false
		TYPE_AABB:
			var a := acc as AABB
			if a != null:
				return (a.position.length() >= bound_value or
						a.size.length() >= bound_value)
			return false
		TYPE_COLOR:
			var c := acc as Color
			if c != null:
				return (absf(c.r) >= bound_value or absf(c.g) >= bound_value or
						absf(c.b) >= bound_value or absf(c.a) >= bound_value)
			return false
		TYPE_PLANE:
			var p := acc as Plane
			if p != null:
				return (p.normal.length() >= bound_value or absf(p.d) >= bound_value)
			return false
		TYPE_BASIS:
			var b := acc as Basis
			if b != null:
				return (b.x.length() >= bound_value or b.y.length() >= bound_value or
						b.z.length() >= bound_value)
			return false
		TYPE_PROJECTION:
			var pj := acc as Projection
			if pj != null:
				return (pj.x.length() >= bound_value or pj.y.length() >= bound_value or
						pj.z.length() >= bound_value or pj.w.length() >= bound_value)
			return false
	return false


# Clamps all accumulators to bound_value.
func _clamp_all_to_bound() -> void:
	for pt in property_targets:
		var entry := pt as ProgressPropertyTarget
		if entry == null or entry.property_path.is_empty():
			continue
		var prop := entry.property_path
		var acc: Variant = _accumulators.get(prop, _zero_for_type(entry._detected_type))
		_accumulators[prop] = _clamp_value(entry._detected_type, acc)


# Clamps one accumulator value to bound_value.
func _clamp_value(type: int, acc: Variant) -> Variant:
	match type:
		TYPE_FLOAT, TYPE_INT:
			return clampf(float(acc), -bound_value, bound_value)
		TYPE_VECTOR2, TYPE_VECTOR2I:
			var v := Vector2(acc)
			var l := v.length()
			if l > bound_value and l > 0.0:
				return v.normalized() * bound_value
			return acc
		TYPE_VECTOR3, TYPE_VECTOR3I:
			var v := Vector3(acc)
			var l := v.length()
			if l > bound_value and l > 0.0:
				return v.normalized() * bound_value
			return acc
		TYPE_VECTOR4, TYPE_VECTOR4I:
			var v := Vector4(acc)
			var l := v.length()
			if l > bound_value and l > 0.0:
				return (v / l) * bound_value
			return acc
		TYPE_COLOR:
			var c := acc as Color
			if c != null:
				return Color(
					clampf(c.r, -bound_value, bound_value),
					clampf(c.g, -bound_value, bound_value),
					clampf(c.b, -bound_value, bound_value),
					clampf(c.a, -bound_value, bound_value))
			return acc
		# Plane/Basis/Projection: clamping is not trivial for compound types.
		# The magnitude check fires, but we don't clamp individual elements —
		# the bound behaviour (reverse/wrap/stop) handles the action instead.
	return acc


# Wraps all accumulators to zero for WRAP bound behaviour.
func _wrap_all_accumulators() -> void:
	for prop in _accumulators:
		var type := TYPE_NIL
		for pt in property_targets:
			var entry := pt as ProgressPropertyTarget
			if entry != null and entry.property_path == prop:
				type = entry._detected_type
				break
		_accumulators[prop] = _zero_for_type(type)


# =============================================================================
# HELPERS
# =============================================================================

# Resets all accumulators and direction.
func _reset_all_accumulators() -> void:
	_accumulators.clear()
	_current_direction = 1.0


# Returns the zero value for a given type constant.
func _zero_for_type(type: int) -> Variant:
	match type:
		TYPE_FLOAT:       return 0.0
		TYPE_INT:         return 0.0
		TYPE_VECTOR2:     return Vector2.ZERO
		TYPE_VECTOR2I:    return Vector2.ZERO
		TYPE_VECTOR3:     return Vector3.ZERO
		TYPE_VECTOR3I:    return Vector3.ZERO
		TYPE_VECTOR4:     return Vector4.ZERO
		TYPE_VECTOR4I:    return Vector4.ZERO
		TYPE_QUATERNION:  return Quaternion.IDENTITY
		TYPE_RECT2:       return Rect2()
		TYPE_RECT2I:      return Rect2()
		TYPE_AABB:        return AABB()
		TYPE_COLOR:       return Color(0.0, 0.0, 0.0, 0.0)
		TYPE_PLANE:       return Plane(Vector3.ZERO, 0.0)
		TYPE_BASIS:       return Basis()
		TYPE_PROJECTION:  return Projection()
	return 0.0


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if property_targets.is_empty():
		warnings.append("No property targets configured — this effect will not accumulate any property.")
	else:
		for pt in property_targets:
			var entry := pt as ProgressPropertyTarget
			if entry != null and entry.property_path.is_empty():
				warnings.append("A property target has no property_path set.")
	if bound_enabled and bound_value <= 0.0:
		warnings.append("bound_value is 0 or negative — bound will fire immediately on every frame.")
	return warnings
