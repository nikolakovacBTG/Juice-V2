## SpringPropertyJuiceComp.gd
## ============================================================================
## WHAT: Physics-based spring animation for any property on any node.
##       Springs a property value from its base towards a target using
##       configurable stiffness, damping, and mass.
## WHY: Extends the Spring family beyond transforms — spring a light's energy,
##      a material's roughness, an audio bus volume, a shader parameter, etc.
##      This is the "+1" in the 3+1 architecture (domain-agnostic complement
##      to the 3 domain-specific spring scripts).
## SYSTEM: Juicing System (addons/juice/) - Property Domain
## DOES NOT: Handle transform springing (use SpringControl/Spring2D/Spring3D).
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
## KEY DIFFERENCE FROM OTHER JUICE:
## Spring does NOT use easing curves. It uses physics simulation:
## - Stiffness controls how fast it tries to reach target
## - Damping controls how quickly oscillations die down
## - Mass affects momentum and response time
##
## The component completes when velocity drops below threshold, not after a
## fixed duration. Duration acts as a maximum timeout.
##
## PROPERTY ACCESS:
## Uses get_indexed() / set_indexed() to read/write any property by path.
## Supports nested paths like "modulate:a", "material:shader_parameter/dissolve".
## Property type must be specified so the correct spring math is applied.
##
## CONDITIONAL EXPORTS:
## Changing property_type triggers notify_property_list_changed() which
## shows/hides the relevant per-type target values via _get_property_list().
##
## REFERENCE:
## Property resolution pattern adapted from ShakePropertyJuiceComp.
## Spring math adapted from the Spring family domain scripts.
## ============================================================================

@tool
class_name SpringPropertyJuiceComp
extends JuiceCompBase

# =============================================================================
# PROPERTY TARGET CONFIGURATION
# =============================================================================

@export_group("Property Target")

## Path to node containing the property.
## Leave empty to use parent node.
@export_node_path("Node") var target_node_path: NodePath

## Path to the property to spring (e.g., "modulate:a", "light_energy")
## Supports nested paths like "material:shader_parameter/dissolve"
@export var property_path: String = ""

## Type of the property value — determines which target export is shown
## and which spring math is used.
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
# SPRING PHYSICS CONFIGURATION (always visible)
# =============================================================================

@export_group("Spring Physics")

## Spring stiffness - higher = faster oscillation, snappier response
@export_range(1.0, 1000.0) var stiffness: float = 300.0

## Damping factor - higher = less bounce, faster settling
@export_range(0.0, 50.0) var damping: float = 10.0

## Mass - higher = more momentum, slower initial response
@export_range(0.1, 10.0) var mass: float = 1.0

@export_group("Settlement")

## Velocity threshold for considering spring "settled"
@export var velocity_threshold: float = 0.5

## Position/value threshold for considering spring "at target"
@export var value_threshold: float = 0.1

## Use physics process instead of regular process
@export var use_physics_process: bool = false

@export_group("Re-trigger Prevention")

## Cooldown time after triggering before accepting new triggers
@export var trigger_cooldown: float = 0.0

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — shown/hidden via _get_property_list()
# =============================================================================

## Target value for float properties
var float_target: float = 1.0

## Target value for Vector2 properties
var vector2_target: Vector2 = Vector2.ONE

## Target value for Vector3 properties
var vector3_target: Vector3 = Vector3.ONE

## Target value for Color properties
var color_target: Color = Color.WHITE

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

## Current spring value (what we're animating)
var _current_value: Variant

## Target value we're springing towards
var _spring_target_value: Variant

## Current velocity (same type as value)
var _velocity: Variant

## Whether we're springing towards target (true) or back to base (false)
var _springing_to_target: bool = true

## Timestamp of last trigger (for cooldown)
var _last_trigger_time: float = -INF

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	match property_type:
		PropertyType.FLOAT:
			props.append({
				"name": "float_target",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
		PropertyType.VECTOR2:
			props.append({
				"name": "vector2_target",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
		PropertyType.VECTOR3:
			props.append({
				"name": "vector3_target",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
		PropertyType.COLOR:
			props.append({
				"name": "color_target",
				"type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT,
			})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"float_target": float_target = value; return true
		&"vector2_target": vector2_target = value; return true
		&"vector3_target": vector3_target = value; return true
		&"color_target": color_target = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"float_target": return float_target
		&"vector2_target": return vector2_target
		&"vector3_target": return vector3_target
		&"color_target": return color_target
	return null

# =============================================================================
# LIFECYCLE OVERRIDES
# =============================================================================

func _ready() -> void:
	super._ready()
	_validate_configuration()


func _process(delta: float) -> void:
	if use_physics_process:
		return
	super._process(delta)


func _physics_process(_delta: float) -> void:
	if not use_physics_process:
		return
	if _is_playing:
		_apply_effect(_animation_progress)


func _validate_configuration() -> void:
	_is_valid = true

	# Resolve target node
	if target_node_path.is_empty():
		_property_target_node = get_parent()
	else:
		_property_target_node = get_node_or_null(target_node_path)

	if _property_target_node == null:
		push_warning("[%s] PropertySpring: target node not found" % name)
		_is_valid = false
	elif property_path.is_empty():
		push_warning("[%s] PropertySpring: property_path is empty" % name)
		_is_valid = false

	if debug_enabled and _is_valid:
		var resolved_name: String = "null"
		if _property_target_node != null:
			resolved_name = str(_property_target_node.name)
		print("[%s] PropertySpring validated. Target: %s, Path: %s, Type: %s" % [
			name, resolved_name, property_path, PropertyType.keys()[property_type]
		])


func _on_animate_start() -> void:
	if not _is_valid:
		_validate_configuration()
	if not _is_valid:
		return

	# Check cooldown
	if trigger_cooldown > 0.0:
		var current_time := Time.get_ticks_msec() / 1000.0
		if current_time - _last_trigger_time < trigger_cooldown:
			if debug_enabled:
				print("[%s] Trigger blocked by cooldown (%.2fs remaining)" % [
					name, trigger_cooldown - (current_time - _last_trigger_time)
				])
			return
		_last_trigger_time = current_time

	if not _has_base:
		_capture_base()

	_initialize_spring_state()

	if debug_enabled:
		print("[%s] PropertySpring start. Path: %s, Type: %s, Stiffness: %.0f" % [
			name, property_path, PropertyType.keys()[property_type], stiffness
		])


func _apply_effect(_progress_unused: float) -> void:
	if not _is_valid:
		return
	if not is_instance_valid(_property_target_node):
		return

	var delta := get_physics_process_delta_time() if use_physics_process else get_process_delta_time()

	_spring_step(delta)
	_apply_property_value()

	if _is_spring_settled():
		_current_value = _spring_target_value
		_apply_property_value()

		if debug_enabled:
			print("[%s] PropertySpring settled at target" % name)


func _on_animate_out_complete() -> void:
	if _is_valid and is_instance_valid(_property_target_node) and _base_value != null:
		_current_value = _spring_target_value
		_apply_property_value()

	if debug_enabled:
		print("[%s] PropertySpring complete" % name)


func _invalidate_base_cache() -> void:
	_has_base = false
	if debug_enabled:
		print("[%s] Base cache invalidated" % name)

# =============================================================================
# SPRING STATE INITIALIZATION
# =============================================================================

func _initialize_spring_state() -> void:
	_springing_to_target = (_target_progress > 0.5)

	_current_value = _property_target_node.get_indexed(property_path)

	match property_type:
		PropertyType.FLOAT:
			_spring_target_value = float_target if _springing_to_target else _base_value
			_velocity = 0.0
		PropertyType.VECTOR2:
			_spring_target_value = vector2_target if _springing_to_target else _base_value
			_velocity = Vector2.ZERO
		PropertyType.VECTOR3:
			_spring_target_value = vector3_target if _springing_to_target else _base_value
			_velocity = Vector3.ZERO
		PropertyType.COLOR:
			_spring_target_value = color_target if _springing_to_target else _base_value
			_velocity = Color(0, 0, 0, 0)

	if debug_enabled:
		print("[%s] Spring initialized. To target: %s, Current: %s, Target: %s" % [
			name, _springing_to_target, _current_value, _spring_target_value
		])

# =============================================================================
# SPRING PHYSICS
# =============================================================================

func _spring_step(delta: float) -> void:
	match property_type:
		PropertyType.FLOAT:
			_spring_step_float(delta)
		PropertyType.VECTOR2:
			_spring_step_vector2(delta)
		PropertyType.VECTOR3:
			_spring_step_vector3(delta)
		PropertyType.COLOR:
			_spring_step_color(delta)


func _spring_step_float(delta: float) -> void:
	var current := _current_value as float
	var target := _spring_target_value as float
	var vel := _velocity as float

	var displacement := target - current
	var spring_force := displacement * stiffness
	var damping_force := vel * damping
	var acceleration := (spring_force - damping_force) / mass

	vel += acceleration * delta
	current += vel * delta

	_velocity = vel
	_current_value = current


func _spring_step_vector2(delta: float) -> void:
	var current := _current_value as Vector2
	var target := _spring_target_value as Vector2
	var vel := _velocity as Vector2

	var displacement := target - current
	var spring_force := displacement * stiffness
	var damping_force := vel * damping
	var acceleration := (spring_force - damping_force) / mass

	vel += acceleration * delta
	current += vel * delta

	_velocity = vel
	_current_value = current


func _spring_step_vector3(delta: float) -> void:
	var current := _current_value as Vector3
	var target := _spring_target_value as Vector3
	var vel := _velocity as Vector3

	var displacement := target - current
	var spring_force := displacement * stiffness
	var damping_force := vel * damping
	var acceleration := (spring_force - damping_force) / mass

	vel += acceleration * delta
	current += vel * delta

	_velocity = vel
	_current_value = current


func _spring_step_color(delta: float) -> void:
	var current := _current_value as Color
	var target := _spring_target_value as Color
	var vel := _velocity as Color

	# Spring each channel independently
	var disp := Color(target.r - current.r, target.g - current.g, target.b - current.b, target.a - current.a)
	var spring_force := Color(disp.r * stiffness, disp.g * stiffness, disp.b * stiffness, disp.a * stiffness)
	var damping_force := Color(vel.r * damping, vel.g * damping, vel.b * damping, vel.a * damping)
	var accel := Color(
		(spring_force.r - damping_force.r) / mass,
		(spring_force.g - damping_force.g) / mass,
		(spring_force.b - damping_force.b) / mass,
		(spring_force.a - damping_force.a) / mass
	)

	vel = Color(vel.r + accel.r * delta, vel.g + accel.g * delta, vel.b + accel.b * delta, vel.a + accel.a * delta)
	current = Color(current.r + vel.r * delta, current.g + vel.g * delta, current.b + vel.b * delta, current.a + vel.a * delta)

	_velocity = vel
	_current_value = current

# =============================================================================
# SETTLEMENT CHECK
# =============================================================================

func _is_spring_settled() -> bool:
	match property_type:
		PropertyType.FLOAT:
			return _is_settled_float()
		PropertyType.VECTOR2:
			return _is_settled_vector2()
		PropertyType.VECTOR3:
			return _is_settled_vector3()
		PropertyType.COLOR:
			return _is_settled_color()
	return false


func _is_settled_float() -> bool:
	var vel := _velocity as float
	var current := _current_value as float
	var target := _spring_target_value as float
	return absf(vel) < velocity_threshold and absf(current - target) < value_threshold


func _is_settled_vector2() -> bool:
	var vel := _velocity as Vector2
	var current := _current_value as Vector2
	var target := _spring_target_value as Vector2
	return vel.length() < velocity_threshold and current.distance_to(target) < value_threshold


func _is_settled_vector3() -> bool:
	var vel := _velocity as Vector3
	var current := _current_value as Vector3
	var target := _spring_target_value as Vector3
	return vel.length() < velocity_threshold and current.distance_to(target) < value_threshold


func _is_settled_color() -> bool:
	var vel := _velocity as Color
	var current := _current_value as Color
	var target := _spring_target_value as Color

	var vel_mag := sqrt(vel.r*vel.r + vel.g*vel.g + vel.b*vel.b + vel.a*vel.a)
	var dist := sqrt(
		pow(current.r - target.r, 2) + pow(current.g - target.g, 2) +
		pow(current.b - target.b, 2) + pow(current.a - target.a, 2)
	)

	return vel_mag < velocity_threshold and dist < value_threshold

# =============================================================================
# VALUE APPLICATION
# =============================================================================

func _apply_property_value() -> void:
	if is_instance_valid(_property_target_node):
		_property_target_node.set_indexed(property_path, _current_value)

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

	if target_node_path.is_empty() and get_parent() == null:
		warnings.append("PropertySpring: No target node available.")
	elif not target_node_path.is_empty():
		var target := get_node_or_null(target_node_path)
		if target == null:
			warnings.append("PropertySpring: target_node_path points to invalid node.")

	if property_path.is_empty():
		warnings.append("PropertySpring: property_path is empty.")

	return warnings
