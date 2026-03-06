## ProgressPropertyJuiceComp.gd
## ============================================================================
## WHAT: Domain-agnostic continuous accumulation effect for any property on any
##       node. Accumulates a property value at a configurable rate over time.
##       Progress from base class acts as speed multiplier (0=stopped, 1=full).
## WHY: Extends the Progress family beyond transforms — drift a light's energy,
##       grow a material's roughness, scroll a shader parameter, etc.
##       This is the "+1" in the 3+1 architecture (domain-agnostic complement
##       to the 3 domain-specific progress scripts).
## SYSTEM: Juicing System (addons/juice/) - Property Domain
## DOES NOT: Handle transform accumulation (use ProgressControl/2D/3D).
## DOES NOT: Handle one-shot property animation (use PropertyTween or similar).
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
## Unlike PropertyShake/PropertySpring which oscillate around a base, Progress
## accumulates value continuously: value += rate * delta * speed_multiplier.
## animate_in() ramps speed 0→1 (eased), animate_out() ramps 1→0 (eased).
## Accumulated value persists across transitions — no snap-back on animate_out.
##
## BOUND SYSTEM:
## When bound_enabled, accumulated distance is checked each frame. When reached:
## - EMIT_COMPLETED: fires completed signal (for chaining)
## - REVERSE: instant direction flip (ping-pong)
## - REVERSE_EASED: animate_out → flip → animate_in (smooth direction change)
## - WRAP: reset accumulated to 0, continue (looping)
## - STOP: halt at bound value
## - DESTROY_PARENT: queue_free() the parent node
##
## PROPERTY ACCESS:
## Uses get_indexed() / set_indexed() to read/write any property by path.
## Supports nested paths like "modulate:a", "material:shader_parameter/dissolve".
## Property type must be specified so the correct accumulation math is applied.
##
## CONDITIONAL EXPORTS:
## Changing property_type / bound_enabled / bound_mode triggers
## notify_property_list_changed() to show/hide relevant parameters.
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBaseProperty.svg")
class_name ProgressPropertyJuiceComp
extends JuiceCompBase

# =============================================================================
# PROPERTY TARGET CONFIGURATION
# =============================================================================

@export_group("Property Target")

## Path to node containing the property.
## Leave empty to use parent node.
@export_node_path("Node") var target_node_path: NodePath

## Path to the property to accumulate (e.g., "modulate:a", "light_energy")
## Supports nested paths like "material:shader_parameter/dissolve"
@export var property_path: String = ""

## Type of the property value — determines which rate export is shown
## and which accumulation math is used.
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
# ALWAYS-VISIBLE CONFIGURATION
# =============================================================================

@export_group("Progress")

## Start accumulating immediately when the scene starts (no animate_in needed).
## Sets speed multiplier to 1.0 instantly. Use trigger_on = ON_READY for eased start.
@export var auto_start: bool = false

# =============================================================================
# BOUND CONFIGURATION
# =============================================================================

## What to do when accumulated distance reaches the bound
enum BoundBehaviour {
	EMIT_COMPLETED,  ## Emit completed signal (fires chaining)
	REVERSE,         ## Instant direction flip (ping-pong)
	REVERSE_EASED,   ## Eased direction change via animate_out → flip → animate_in
	WRAP,            ## Reset accumulated to 0, continue (looping)
	STOP,            ## Stop accumulation, hold at bound value
	DESTROY_PARENT   ## queue_free() the parent node
}

## How to measure accumulated distance for bound checking
enum BoundMode {
	MAGNITUDE,  ## Single float compared to accumulated magnitude (default)
	PER_AXIS    ## Per-axis comparison — any axis hitting its bound triggers behaviour
}

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — shown/hidden via _get_property_list()
# =============================================================================

# --- PER-TYPE RATE ---
## Rate of change per second for float properties
var float_rate: float = 0.1

## Rate of change per second for Vector2 properties
var vector2_rate: Vector2 = Vector2(0.1, 0.0)

## Rate of change per second for Vector3 properties
var vector3_rate: Vector3 = Vector3(0.0, 0.1, 0.0)

## Rate of change per second for Color properties (per channel RGBA)
var color_rate: Color = Color(0.0, 0.0, 0.0, -0.1)

# --- BOUND ---
var bound_enabled: bool = false:
	set(value):
		bound_enabled = value
		notify_property_list_changed()
var bound_mode: int = BoundMode.MAGNITUDE:
	set(value):
		bound_mode = value
		notify_property_list_changed()
var bound_value: float = 1.0
var bound_value_vec2: Vector2 = Vector2(1.0, 1.0)
var bound_value_vec3: Vector3 = Vector3(1.0, 1.0, 1.0)
var bound_value_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var bound_behaviour: int = BoundBehaviour.REVERSE

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Resolved property target node
var _property_target_node: Node = null

## Captured base property value (type varies)
var _base_value: Variant = null

## Accumulated change from base (type matches property_type)
var _accumulated_float: float = 0.0
var _accumulated_vec2: Vector2 = Vector2.ZERO
var _accumulated_vec3: Vector3 = Vector3.ZERO
var _accumulated_color: Color = Color(0, 0, 0, 0)

## Direction multiplier: +1.0 or -1.0 (flipped by REVERSE bound behaviour)
var _current_direction: float = 1.0

## Whether base has been captured
var _has_base: bool = false

## Whether configuration has been validated
var _is_valid: bool = false

## State flag for REVERSE_EASED
var _awaiting_reverse_restart: bool = false

# =============================================================================
# READ-ONLY PUBLIC PROPERTY
# =============================================================================

## Current accumulated change from base. External systems can query this.
var accumulated_value: Variant:
	get:
		match property_type:
			PropertyType.FLOAT:
				return _accumulated_float
			PropertyType.VECTOR2:
				return _accumulated_vec2
			PropertyType.VECTOR3:
				return _accumulated_vec3
			PropertyType.COLOR:
				return _accumulated_color
		return null

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# --- Per-type rate ---
	match property_type:
		PropertyType.FLOAT:
			props.append({
				"name": "float_rate",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
		PropertyType.VECTOR2:
			props.append({
				"name": "vector2_rate",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
		PropertyType.VECTOR3:
			props.append({
				"name": "vector3_rate",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
		PropertyType.COLOR:
			props.append({
				"name": "color_rate",
				"type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT,
			})

	# --- Bound system ---
	props.append({
		"name": "bound_enabled",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT,
	})

	if bound_enabled:
		props.append({
			"name": "bound_behaviour",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Emit Completed,Reverse,Reverse Eased,Wrap,Stop,Destroy Parent",
		})

		# Bound mode and value depend on property type
		match property_type:
			PropertyType.FLOAT:
				# Float is always single value, no PER_AXIS option
				props.append({
					"name": "bound_value",
					"type": TYPE_FLOAT,
					"usage": PROPERTY_USAGE_DEFAULT,
				})
			PropertyType.VECTOR2:
				props.append({
					"name": "bound_mode",
					"type": TYPE_INT,
					"usage": PROPERTY_USAGE_DEFAULT,
					"hint": PROPERTY_HINT_ENUM,
					"hint_string": "Magnitude,Per Axis",
				})
				if bound_mode == BoundMode.PER_AXIS:
					props.append({
						"name": "bound_value_vec2",
						"type": TYPE_VECTOR2,
						"usage": PROPERTY_USAGE_DEFAULT,
					})
				else:
					props.append({
						"name": "bound_value",
						"type": TYPE_FLOAT,
						"usage": PROPERTY_USAGE_DEFAULT,
					})
			PropertyType.VECTOR3:
				props.append({
					"name": "bound_mode",
					"type": TYPE_INT,
					"usage": PROPERTY_USAGE_DEFAULT,
					"hint": PROPERTY_HINT_ENUM,
					"hint_string": "Magnitude,Per Axis",
				})
				if bound_mode == BoundMode.PER_AXIS:
					props.append({
						"name": "bound_value_vec3",
						"type": TYPE_VECTOR3,
						"usage": PROPERTY_USAGE_DEFAULT,
					})
				else:
					props.append({
						"name": "bound_value",
						"type": TYPE_FLOAT,
						"usage": PROPERTY_USAGE_DEFAULT,
					})
			PropertyType.COLOR:
				props.append({
					"name": "bound_mode",
					"type": TYPE_INT,
					"usage": PROPERTY_USAGE_DEFAULT,
					"hint": PROPERTY_HINT_ENUM,
					"hint_string": "Magnitude,Per Axis",
				})
				if bound_mode == BoundMode.PER_AXIS:
					props.append({
						"name": "bound_value_color",
						"type": TYPE_COLOR,
						"usage": PROPERTY_USAGE_DEFAULT,
					})
				else:
					props.append({
						"name": "bound_value",
						"type": TYPE_FLOAT,
						"usage": PROPERTY_USAGE_DEFAULT,
					})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		# Rates
		&"float_rate": float_rate = value; return true
		&"vector2_rate": vector2_rate = value; return true
		&"vector3_rate": vector3_rate = value; return true
		&"color_rate": color_rate = value; return true
		# Bound
		&"bound_enabled": bound_enabled = value; return true
		&"bound_mode": bound_mode = value; return true
		&"bound_value": bound_value = value; return true
		&"bound_value_vec2": bound_value_vec2 = value; return true
		&"bound_value_vec3": bound_value_vec3 = value; return true
		&"bound_value_color": bound_value_color = value; return true
		&"bound_behaviour": bound_behaviour = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"float_rate": return float_rate
		&"vector2_rate": return vector2_rate
		&"vector3_rate": return vector3_rate
		&"color_rate": return color_rate
		&"bound_enabled": return bound_enabled
		&"bound_mode": return bound_mode
		&"bound_value": return bound_value
		&"bound_value_vec2": return bound_value_vec2
		&"bound_value_vec3": return bound_value_vec3
		&"bound_value_color": return bound_value_color
		&"bound_behaviour": return bound_behaviour
	return null

# =============================================================================
# LIFECYCLE OVERRIDES
# =============================================================================

func _ready() -> void:
	super._ready()
	_validate_configuration()
	if auto_start and not Engine.is_editor_hint():
		call_deferred("_start_auto_progress")


func _validate_configuration() -> void:
	_is_valid = true

	# Resolve target node
	if target_node_path.is_empty():
		_property_target_node = get_parent()
	else:
		_property_target_node = get_node_or_null(target_node_path)

	if _property_target_node == null:
		push_warning("[%s] ProgressProperty: target node not found" % name)
		_is_valid = false
	elif property_path.is_empty():
		push_warning("[%s] ProgressProperty: property_path is empty" % name)
		_is_valid = false

	if debug_enabled and _is_valid:
		var resolved_name: String = "null"
		if _property_target_node != null:
			resolved_name = str(_property_target_node.name)
		print("[%s] ProgressProperty validated. Target: %s, Path: %s, Type: %s" % [
			name, resolved_name, property_path, PropertyType.keys()[property_type]
		])


func _start_auto_progress() -> void:
	if not _is_valid:
		_validate_configuration()
	if not _is_valid:
		return

	_capture_base()
	_reset_accumulated()
	_current_direction = 1.0
	_awaiting_reverse_restart = false

	_animation_progress = 1.0
	_target_progress = 1.0
	_is_playing = true
	set_process(true)

	if debug_enabled:
		print("[%s] Auto-started progress (Property, %s)" % [
			name, PropertyType.keys()[property_type]])


## When already playing, retrigger acts as a toggle-stop:
## - Sustaining: animate_out for graceful deceleration to stop.
## - Mid ease-out (REVERSE_EASED): clear the flag so the existing ease-out
##   completes as a full stop instead of reversing direction.
## When not playing, falls through to base class to start normally.
func _handle_trigger(trigger: Dictionary) -> void:
	if _is_playing:
		if _awaiting_reverse_restart:
			_awaiting_reverse_restart = false
		else:
			animate_out()
		return
	super._handle_trigger(trigger)


## Progress overrides _process to bypass the base class easing/loop cycle.
## Value accumulates continuously via delta time — progress is just a speed
## multiplier that ramps during transitions and holds steady during sustained
## accumulation.
func _process(delta: float) -> void:
	if not _is_playing:
		return

	if absf(_animation_progress - _target_progress) > 0.0001:
		_elapsed += delta
		var current_duration := _get_current_duration()
		var t: float = clampf(_elapsed / current_duration, 0.0, 1.0) if current_duration > 0.0 else 1.0
		_animation_progress = lerpf(_start_progress, _target_progress, _apply_easing(t))

		if _elapsed >= current_duration:
			_animation_progress = _target_progress
			if _target_progress <= 0.0:
				# REVERSE_EASED: deceleration complete — absorb overshoot into
				# base, flip direction, and ease back in. Don't stop or emit
				# completed — the ping-pong continues seamlessly.
				if _awaiting_reverse_restart:
					if debug_enabled:
						print("[%s] ◆ EASE-OUT DONE (pre-absorb) | dir=%.0f | acc_f=%.3f acc_v2=%s acc_v3=%s | base=%s" % [
							name, _current_direction, _accumulated_float, _accumulated_vec2, _accumulated_vec3, _base_value])
					_awaiting_reverse_restart = false
					_absorb_accumulated_into_base()
					_current_direction *= -1.0
					if debug_enabled:
						print("[%s] ◆ ABSORBED + FLIPPED | new_dir=%.0f | acc_f=%.3f acc_v2=%s acc_v3=%s | base=%s" % [
							name, _current_direction, _accumulated_float, _accumulated_vec2, _accumulated_vec3, _base_value])
					_start_progress = 0.0
					_target_progress = 1.0
					_elapsed = 0.0
					_animation_progress = 0.0
					return
				# Normal animate_out — fully stop accumulation
				_apply_effect(0.0)
				_is_playing = false
				set_process(false)
				_on_animate_out_complete()
				completed.emit()
				return
			else:
				if debug_enabled:
					print("[%s] ◆ EASE-IN DONE → sustaining | dir=%.0f | acc_f=%.3f acc_v2=%s acc_v3=%s | base=%s" % [
						name, _current_direction, _accumulated_float, _accumulated_vec2, _accumulated_vec3, _base_value])
				completed.emit()

	elif _target_progress <= 0.0:
		# Edge case: easing curve brought progress within epsilon of target before
		# _elapsed reached current_duration. The outer absf guard skipped the block,
		# so _elapsed stopped incrementing and the completion code never fired.
		# Force completion now to avoid getting stuck.
		_animation_progress = _target_progress
		if _awaiting_reverse_restart:
			if debug_enabled:
				print("[%s] ◆ EASE-OUT DONE (early) | dir=%.0f | acc_f=%.3f acc_v2=%s acc_v3=%s | base=%s" % [
					name, _current_direction, _accumulated_float, _accumulated_vec2, _accumulated_vec3, _base_value])
			_awaiting_reverse_restart = false
			_absorb_accumulated_into_base()
			_current_direction *= -1.0
			if debug_enabled:
				print("[%s] ◆ ABSORBED + FLIPPED | new_dir=%.0f | acc_f=%.3f acc_v2=%s acc_v3=%s | base=%s" % [
					name, _current_direction, _accumulated_float, _accumulated_vec2, _accumulated_vec3, _base_value])
			_start_progress = 0.0
			_target_progress = 1.0
			_elapsed = 0.0
			_animation_progress = 0.0
			return
		_apply_effect(0.0)
		_is_playing = false
		set_process(false)
		_on_animate_out_complete()
		completed.emit()
		return

	_apply_effect(_animation_progress)

# =============================================================================
# VIRTUAL METHOD IMPLEMENTATIONS
# =============================================================================

func _invalidate_base_cache() -> void:
	_has_base = false
	if debug_enabled:
		print("[%s] Base cache invalidated" % name)


func _on_animate_start() -> void:
	if not _is_valid:
		_validate_configuration()
	if not _is_valid:
		return

	if not _has_base:
		_capture_base()

	if debug_enabled:
		print("[%s] ProgressProperty start. Path: %s, Type: %s, Base: %s, Direction: %.0f" % [
			name, property_path, PropertyType.keys()[property_type],
			_base_value, _current_direction
		])


func _apply_effect(progress: float) -> void:
	if not _is_valid:
		return
	if not is_instance_valid(_property_target_node):
		return

	var delta := get_process_delta_time()

	match property_type:
		PropertyType.FLOAT:
			_accumulated_float += float_rate * delta * progress * _current_direction
			var result := (_base_value as float) + _accumulated_float
			_property_target_node.set_indexed(property_path, result)

		PropertyType.VECTOR2:
			_accumulated_vec2 += vector2_rate * delta * progress * _current_direction
			var result := (_base_value as Vector2) + _accumulated_vec2
			_property_target_node.set_indexed(property_path, result)

		PropertyType.VECTOR3:
			_accumulated_vec3 += vector3_rate * delta * progress * _current_direction
			var result := (_base_value as Vector3) + _accumulated_vec3
			_property_target_node.set_indexed(property_path, result)

		PropertyType.COLOR:
			var rate_scaled := Color(
				color_rate.r * delta * progress * _current_direction,
				color_rate.g * delta * progress * _current_direction,
				color_rate.b * delta * progress * _current_direction,
				color_rate.a * delta * progress * _current_direction
			)
			_accumulated_color = Color(
				_accumulated_color.r + rate_scaled.r,
				_accumulated_color.g + rate_scaled.g,
				_accumulated_color.b + rate_scaled.b,
				_accumulated_color.a + rate_scaled.a
			)
			var base_col := _base_value as Color
			var result := Color(
				base_col.r + _accumulated_color.r,
				base_col.g + _accumulated_color.g,
				base_col.b + _accumulated_color.b,
				base_col.a + _accumulated_color.a
			)
			_property_target_node.set_indexed(property_path, result)

	if bound_enabled and progress > 0.0:
		_check_bounds()


func _on_animate_out_complete() -> void:
	if debug_enabled:
		print("[%s] ProgressProperty stopped (holding accumulated state)" % name)


# =============================================================================
# BOUND CHECKING
# =============================================================================

func _check_bounds() -> void:
	# Guard: skip re-entrant bound check when REVERSE_EASED animate_out is
	# already in progress — prevents infinite recursion via _animate_to → _apply_effect
	if _awaiting_reverse_restart:
		return

	var exceeded := false

	match property_type:
		PropertyType.FLOAT:
			exceeded = absf(_accumulated_float) > bound_value
		PropertyType.VECTOR2:
			exceeded = _check_vec2_bound(_accumulated_vec2)
		PropertyType.VECTOR3:
			exceeded = _check_vec3_bound(_accumulated_vec3)
		PropertyType.COLOR:
			exceeded = _check_color_bound(_accumulated_color)

	if not exceeded:
		return

	_clamp_to_bound()

	if debug_enabled:
		print("[%s] Bound reached. Behaviour: %s" % [
			name, BoundBehaviour.keys()[bound_behaviour]])

	match bound_behaviour:
		BoundBehaviour.EMIT_COMPLETED:
			completed.emit()
		BoundBehaviour.REVERSE:
			_absorb_accumulated_into_base()
			_current_direction *= -1.0
		BoundBehaviour.REVERSE_EASED:
			if debug_enabled:
				print("[%s] ◆ BOUND HIT → REVERSE_EASED | dir=%.0f | type=%s | acc_f=%.3f acc_v2=%s acc_v3=%s | base=%s | anim_prog=%.3f" % [
					name, _current_direction, PropertyType.keys()[property_type],
					_accumulated_float, _accumulated_vec2, _accumulated_vec3, _base_value, _animation_progress])
			_awaiting_reverse_restart = true
			animate_out()
		BoundBehaviour.WRAP:
			_wrap_accumulated()
		BoundBehaviour.STOP:
			_is_playing = false
			set_process(false)
			completed.emit()
		BoundBehaviour.DESTROY_PARENT:
			if is_instance_valid(_property_target_node):
				_property_target_node.queue_free()


func _check_vec2_bound(accumulated: Vector2) -> bool:
	if bound_mode == BoundMode.PER_AXIS:
		return absf(accumulated.x) > absf(bound_value_vec2.x) or \
			   absf(accumulated.y) > absf(bound_value_vec2.y)
	else:
		return accumulated.length() > bound_value


func _check_vec3_bound(accumulated: Vector3) -> bool:
	if bound_mode == BoundMode.PER_AXIS:
		return absf(accumulated.x) > absf(bound_value_vec3.x) or \
			   absf(accumulated.y) > absf(bound_value_vec3.y) or \
			   absf(accumulated.z) > absf(bound_value_vec3.z)
	else:
		return accumulated.length() > bound_value


func _check_color_bound(accumulated: Color) -> bool:
	if bound_mode == BoundMode.PER_AXIS:
		return absf(accumulated.r) > absf(bound_value_color.r) or \
			   absf(accumulated.g) > absf(bound_value_color.g) or \
			   absf(accumulated.b) > absf(bound_value_color.b) or \
			   absf(accumulated.a) > absf(bound_value_color.a)
	else:
		# Magnitude: treat color as 4D vector
		var mag := sqrt(
			accumulated.r * accumulated.r +
			accumulated.g * accumulated.g +
			accumulated.b * accumulated.b +
			accumulated.a * accumulated.a
		)
		return mag > bound_value


func _clamp_to_bound() -> void:
	match property_type:
		PropertyType.FLOAT:
			_accumulated_float = clampf(_accumulated_float, -bound_value, bound_value)
		PropertyType.VECTOR2:
			_accumulated_vec2 = _clamp_vec2(_accumulated_vec2)
		PropertyType.VECTOR3:
			_accumulated_vec3 = _clamp_vec3(_accumulated_vec3)
		PropertyType.COLOR:
			_accumulated_color = _clamp_color(_accumulated_color)


func _clamp_vec2(accumulated: Vector2) -> Vector2:
	if bound_mode == BoundMode.PER_AXIS:
		return Vector2(
			clampf(accumulated.x, -absf(bound_value_vec2.x), absf(bound_value_vec2.x)),
			clampf(accumulated.y, -absf(bound_value_vec2.y), absf(bound_value_vec2.y))
		)
	else:
		var length := accumulated.length()
		if length > bound_value and length > 0.0:
			return accumulated.normalized() * bound_value
		return accumulated


func _clamp_vec3(accumulated: Vector3) -> Vector3:
	if bound_mode == BoundMode.PER_AXIS:
		return Vector3(
			clampf(accumulated.x, -absf(bound_value_vec3.x), absf(bound_value_vec3.x)),
			clampf(accumulated.y, -absf(bound_value_vec3.y), absf(bound_value_vec3.y)),
			clampf(accumulated.z, -absf(bound_value_vec3.z), absf(bound_value_vec3.z))
		)
	else:
		var length := accumulated.length()
		if length > bound_value and length > 0.0:
			return accumulated.normalized() * bound_value
		return accumulated


func _clamp_color(accumulated: Color) -> Color:
	if bound_mode == BoundMode.PER_AXIS:
		return Color(
			clampf(accumulated.r, -absf(bound_value_color.r), absf(bound_value_color.r)),
			clampf(accumulated.g, -absf(bound_value_color.g), absf(bound_value_color.g)),
			clampf(accumulated.b, -absf(bound_value_color.b), absf(bound_value_color.b)),
			clampf(accumulated.a, -absf(bound_value_color.a), absf(bound_value_color.a))
		)
	else:
		var mag := sqrt(
			accumulated.r * accumulated.r +
			accumulated.g * accumulated.g +
			accumulated.b * accumulated.b +
			accumulated.a * accumulated.a
		)
		if mag > bound_value and mag > 0.0:
			var scale_factor := bound_value / mag
			return Color(
				accumulated.r * scale_factor,
				accumulated.g * scale_factor,
				accumulated.b * scale_factor,
				accumulated.a * scale_factor
			)
		return accumulated


func _wrap_accumulated() -> void:
	match property_type:
		PropertyType.FLOAT:
			_accumulated_float = fmod(_accumulated_float, bound_value) if bound_value > 0.0 else 0.0
		PropertyType.VECTOR2:
			if bound_mode == BoundMode.PER_AXIS:
				_accumulated_vec2 = Vector2(
					fmod(_accumulated_vec2.x, absf(bound_value_vec2.x)) if absf(bound_value_vec2.x) > 0.0 else 0.0,
					fmod(_accumulated_vec2.y, absf(bound_value_vec2.y)) if absf(bound_value_vec2.y) > 0.0 else 0.0
				)
			else:
				_accumulated_vec2 = Vector2.ZERO
		PropertyType.VECTOR3:
			if bound_mode == BoundMode.PER_AXIS:
				_accumulated_vec3 = Vector3(
					fmod(_accumulated_vec3.x, absf(bound_value_vec3.x)) if absf(bound_value_vec3.x) > 0.0 else 0.0,
					fmod(_accumulated_vec3.y, absf(bound_value_vec3.y)) if absf(bound_value_vec3.y) > 0.0 else 0.0,
					fmod(_accumulated_vec3.z, absf(bound_value_vec3.z)) if absf(bound_value_vec3.z) > 0.0 else 0.0
				)
			else:
				_accumulated_vec3 = Vector3.ZERO
		PropertyType.COLOR:
			if bound_mode == BoundMode.PER_AXIS:
				_accumulated_color = Color(
					fmod(_accumulated_color.r, absf(bound_value_color.r)) if absf(bound_value_color.r) > 0.0 else 0.0,
					fmod(_accumulated_color.g, absf(bound_value_color.g)) if absf(bound_value_color.g) > 0.0 else 0.0,
					fmod(_accumulated_color.b, absf(bound_value_color.b)) if absf(bound_value_color.b) > 0.0 else 0.0,
					fmod(_accumulated_color.a, absf(bound_value_color.a)) if absf(bound_value_color.a) > 0.0 else 0.0
				)
			else:
				_accumulated_color = Color(0, 0, 0, 0)

# =============================================================================
# HELPERS
# =============================================================================

## Absorb accumulated value into the base, resetting accumulated to zero.
## This makes the current value the new "start" for bound measurement,
## enabling correct ping-pong between [start, start+bound] instead of [-bound, +bound].
func _absorb_accumulated_into_base() -> void:
	match property_type:
		PropertyType.FLOAT:
			_base_value = (_base_value as float) + _accumulated_float
			_accumulated_float = 0.0
		PropertyType.VECTOR2:
			_base_value = (_base_value as Vector2) + _accumulated_vec2
			_accumulated_vec2 = Vector2.ZERO
		PropertyType.VECTOR3:
			_base_value = (_base_value as Vector3) + _accumulated_vec3
			_accumulated_vec3 = Vector3.ZERO
		PropertyType.COLOR:
			var base_col := _base_value as Color
			_base_value = Color(
				base_col.r + _accumulated_color.r,
				base_col.g + _accumulated_color.g,
				base_col.b + _accumulated_color.b,
				base_col.a + _accumulated_color.a
			)
			_accumulated_color = Color(0, 0, 0, 0)


func _reset_accumulated() -> void:
	_accumulated_float = 0.0
	_accumulated_vec2 = Vector2.ZERO
	_accumulated_vec3 = Vector3.ZERO
	_accumulated_color = Color(0, 0, 0, 0)


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
	# Capture the property value from the resolved target node,
	# not from the 'target' parameter (which is the juice component's parent).
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
