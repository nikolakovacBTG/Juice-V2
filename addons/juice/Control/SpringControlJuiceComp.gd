## SpringControlJuiceComp.gd
## ============================================================================
## WHAT: Physics-based spring animation for Control nodes. Combines position,
##       rotation, and scale spring into a single component with a TransformTarget
##       selector. Uses _get_property_list() to conditionally show only relevant
##       exports in the inspector.
## WHY: Replaces the TRANSFORM mode of the unified SpringJuiceComp for Control
##      nodes. Clean inspector — only shows Control-relevant exports (Vector2
##      offsets, float rotation, native pivot_offset).
## SYSTEM: Juicing System (addons/juice/) - Control Domain
## DOES NOT: Handle Node2D or Node3D targets (use Spring2D/Spring3D).
## DOES NOT: Handle arbitrary property springing (use SpringPropertyJuiceComp).
## ============================================================================
##
## KEY DIFFERENCE FROM OTHER JUICE:
## Spring does NOT use easing curves. It uses physics simulation:
## - Stiffness controls how fast it tries to reach target (oscillation speed)
## - Damping controls how quickly oscillations die down
## - Mass affects momentum and response time
##
## The component completes when velocity drops below threshold, not after a
## fixed duration. Duration acts as a maximum timeout.
##
## TRANSFORM TARGETS:
## - POSITION: Springs Control.position with Vector2 offset
## - ROTATION: Springs Control.rotation with float offset (degrees)
## - SCALE: Springs Control.scale with Vector2 offset
##
## PIVOT (ROTATION and SCALE only):
## Uses the native Control.pivot_offset property via PivotMode enum.
## Reactive pivot updates via the Control's resized signal.
##
## CONDITIONAL EXPORTS:
## Changing transform_target triggers notify_property_list_changed() which
## shows/hides the relevant parameters via _get_property_list(). Properties
## added this way appear AFTER all @export properties in the inspector.
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBaseControl.svg")
class_name SpringControlJuiceComp
extends JuiceCompBase

# =============================================================================
# TRANSFORM TARGET SELECTION
# =============================================================================

## Which transform property to spring
enum TransformTarget {
	POSITION,  ## Spring Control.position
	ROTATION,  ## Spring Control.rotation (single-axis Z)
	SCALE      ## Spring Control.scale
}

@export_group("Effect")

@export var transform_target: TransformTarget = TransformTarget.POSITION:
	set(value):
		transform_target = value
		notify_property_list_changed()

# =============================================================================
# SPRING PHYSICS CONFIGURATION (always visible)
# =============================================================================

## Spring stiffness - higher = faster oscillation, snappier response
## Low (100-200): Slow, lazy spring
## Medium (300-400): Balanced, responsive
## High (500+): Snappy, quick response
@export_range(1.0, 1000.0) var stiffness: float = 300.0

## Damping factor - higher = less bounce, faster settling
## Low (1-5): Very bouncy, many oscillations
## Medium (10-15): Some bounce, settles quickly
## High (20+): Overdamped, no overshoot
@export_range(0.0, 50.0) var damping: float = 10.0

## Mass - higher = more momentum, slower initial response
## Typically keep at 1.0 unless you want sluggish or snappy feel
@export_range(0.1, 10.0) var mass: float = 1.0

@export_group("Settlement")

## Velocity threshold for considering spring "settled"
## Lower = more precise but takes longer to complete
@export var velocity_threshold: float = 0.5

## Position/value threshold for considering spring "at target"
@export var value_threshold: float = 0.1

## Use physics process instead of regular process (more stable but less smooth)
@export var use_physics_process: bool = false

@export_group("Re-trigger Prevention")

## Cooldown time after triggering before accepting new triggers.
## Useful for preventing rapid re-triggering when spring motion causes
## the object to move in/out of hover detection zones.
@export var trigger_cooldown: float = 0.0

# =============================================================================
# PIVOT MODE (shown for ROTATION and SCALE only, via _get_property_list)
# =============================================================================

## Determines how the pivot point is calculated
enum PivotMode {
	AUTO_CENTER,  ## Automatically center pivot (most common for UI)
	INHERIT,      ## Use the node's existing pivot_offset
	CUSTOM        ## Use custom_pivot values below
}

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — they are shown/hidden via _get_property_list()
# =============================================================================

# --- POSITION ---
## Offset to spring towards at animate_in
var position_offset: Vector2 = Vector2(0, -20)

# --- ROTATION ---
## Rotation offset in degrees to spring towards
var rotation_offset_degrees: float = 15.0

# --- SCALE ---
## Scale offset to spring towards (added to base scale)
var scale_offset: Vector2 = Vector2(0.2, 0.2)

# --- PIVOT (ROTATION + SCALE) ---
var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()
## Custom pivot in normalized coordinates (0-1). (0.5, 0.5) = center.
var custom_pivot: Vector2 = Vector2(0.5, 0.5)

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Captured base values of target
var _base_position: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _base_scale: Vector2 = Vector2.ONE

## Whether base has been captured
var _has_base: bool = false

## Whether pivot has been applied for current target
var _pivot_applied: bool = false

## Reference to connected Control for resized signal cleanup
var _connected_control: Control = null

## Current spring value (what we're animating)
var _current_value: Variant

## Target value we're springing towards
var _spring_target_value: Variant

## Current velocity (same type as value)
var _velocity: Variant

## Whether we're springing towards offset (true) or back to base (false)
var _springing_to_offset: bool = true

## Timestamp of last trigger (for cooldown)
var _last_trigger_time: float = -INF

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	match transform_target:
		TransformTarget.POSITION:
			props.append({
				"name": "position_offset",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})

		TransformTarget.ROTATION:
			props.append({
				"name": "rotation_offset_degrees",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})
			# Pivot exports for rotation
			props.append_array(_get_pivot_properties())

		TransformTarget.SCALE:
			props.append({
				"name": "scale_offset",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})
			# Pivot exports for scale
			props.append_array(_get_pivot_properties())

	return props


## Shared pivot properties used by both ROTATION and SCALE targets
func _get_pivot_properties() -> Array[Dictionary]:
	var pivot_props: Array[Dictionary] = [
		{
			"name": "pivot_mode",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Auto Center,Inherit,Custom",
		},
	]
	# Only show custom_pivot input when pivot_mode is CUSTOM
	if pivot_mode == PivotMode.CUSTOM:
		pivot_props.append({
			"name": "custom_pivot",
			"type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NONE,
		})
	return pivot_props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		# Position
		&"position_offset": position_offset = value; return true
		# Rotation
		&"rotation_offset_degrees": rotation_offset_degrees = value; return true
		# Scale
		&"scale_offset": scale_offset = value; return true
		# Pivot
		&"pivot_mode": pivot_mode = value; return true
		&"custom_pivot": custom_pivot = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		# Position
		&"position_offset": return position_offset
		# Rotation
		&"rotation_offset_degrees": return rotation_offset_degrees
		# Scale
		&"scale_offset": return scale_offset
		# Pivot
		&"pivot_mode": return pivot_mode
		&"custom_pivot": return custom_pivot
	return null

# =============================================================================
# LIFECYCLE OVERRIDES
# =============================================================================

func _ready() -> void:
	super._ready()


func _process(delta: float) -> void:
	if use_physics_process:
		return
	super._process(delta)


func _physics_process(_delta: float) -> void:
	if not use_physics_process:
		return
	# Mirror the base class _process logic for physics process
	if _is_playing:
		_apply_effect(_animation_progress)


func _on_animate_start() -> void:
	# Check cooldown to prevent rapid re-triggering
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

	# Resolve pivot for rotation/scale targets
	if transform_target != TransformTarget.POSITION and not _pivot_applied:
		_resolve_pivot()
		_pivot_applied = true

	_initialize_spring_state()

	if debug_enabled:
		var target_name: String = TransformTarget.keys()[transform_target]
		print("[%s] Spring start (Control, %s). Stiffness: %.0f, Damping: %.0f" % [
			name, target_name, stiffness, damping
		])


## Called each frame - run spring simulation
## NOTE: Progress parameter is unused because spring uses physics, not interpolation
func _apply_effect(_progress_unused: float) -> void:
	if not is_instance_valid(_target_node) or not (_target_node is Control):
		return

	var delta := get_physics_process_delta_time() if use_physics_process else get_process_delta_time()

	# Run spring physics step
	_spring_step(delta)

	# Apply current value to target
	_apply_spring_value()

	# Check if spring has settled
	if _is_spring_settled():
		# Snap to target
		_current_value = _spring_target_value
		_apply_spring_value()

		if debug_enabled:
			print("[%s] Spring settled at target" % name)


func _on_animate_out_complete() -> void:
	if not is_instance_valid(_target_node) or not (_target_node is Control):
		return

	# Ensure we're at exact target
	_current_value = _spring_target_value
	_apply_spring_value()

	if debug_enabled:
		print("[%s] Spring complete" % name)


func _invalidate_base_cache() -> void:
	_has_base = false
	_pivot_applied = false
	_disconnect_resized()
	if debug_enabled:
		print("[%s] Spring base cache invalidated" % name)

# =============================================================================
# SPRING STATE INITIALIZATION
# =============================================================================

func _initialize_spring_state() -> void:
	# Determine direction based on _target_progress from base class
	_springing_to_offset = (_target_progress > 0.5)

	var ctrl := _target_node as Control

	match transform_target:
		TransformTarget.POSITION:
			_current_value = ctrl.position
			_spring_target_value = _base_position + position_offset if _springing_to_offset else _base_position
			_velocity = Vector2.ZERO
		TransformTarget.ROTATION:
			_current_value = ctrl.rotation
			var offset_rad := deg_to_rad(rotation_offset_degrees)
			_spring_target_value = _base_rotation + offset_rad if _springing_to_offset else _base_rotation
			_velocity = 0.0
		TransformTarget.SCALE:
			_current_value = ctrl.scale
			_spring_target_value = _base_scale + scale_offset if _springing_to_offset else _base_scale
			_velocity = Vector2.ZERO

	if debug_enabled:
		print("[%s] Spring initialized. To offset: %s, Current: %s, Target: %s" % [
			name, _springing_to_offset, _current_value, _spring_target_value
		])

# =============================================================================
# SPRING PHYSICS
# =============================================================================

func _spring_step(delta: float) -> void:
	match transform_target:
		TransformTarget.POSITION, TransformTarget.SCALE:
			_spring_step_vector2(delta)
		TransformTarget.ROTATION:
			_spring_step_float(delta)


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

# =============================================================================
# SETTLEMENT CHECK
# =============================================================================

func _is_spring_settled() -> bool:
	match transform_target:
		TransformTarget.POSITION, TransformTarget.SCALE:
			return _is_settled_vector2()
		TransformTarget.ROTATION:
			return _is_settled_float()
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

# =============================================================================
# VALUE APPLICATION
# =============================================================================

func _apply_spring_value() -> void:
	var ctrl := _target_node as Control
	match transform_target:
		TransformTarget.POSITION:
			ctrl.position = _current_value as Vector2
		TransformTarget.ROTATION:
			ctrl.rotation = _current_value as float
		TransformTarget.SCALE:
			ctrl.scale = _current_value as Vector2

# =============================================================================
# BASE CAPTURE
# =============================================================================

func _capture_base() -> void:
	if _has_base:
		return

	if not (_target_node is Control):
		if debug_enabled and _target_node != null:
			push_warning("[%s] Target '%s' is not Control" % [name, _target_node.name])
		_has_base = true
		return

	var ctrl := _target_node as Control
	_base_position = ctrl.position
	_base_rotation = ctrl.rotation
	_base_scale = ctrl.scale
	_has_base = true

	if debug_enabled:
		print("[%s] Captured base: pos=%s, rot=%.1f°, scale=%s" % [
			name, _base_position, rad_to_deg(_base_rotation), _base_scale
		])

# =============================================================================
# PIVOT HANDLING — Uses native Control.pivot_offset
# =============================================================================

func _resolve_pivot() -> void:
	if not (_target_node is Control):
		return

	_apply_pivot_mode()
	_pivot_applied = true

	# Connect to resized signal for reactive pivot updates
	var ctrl := _target_node as Control
	if _connected_control != ctrl:
		_disconnect_resized()
		if not ctrl.resized.is_connected(_on_target_resized):
			ctrl.resized.connect(_on_target_resized)
		_connected_control = ctrl


func _apply_pivot_mode() -> void:
	if not (_target_node is Control):
		return

	var ctrl := _target_node as Control

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

	if debug_enabled:
		print("[%s] Pivot set to %s" % [name, ctrl.pivot_offset])


func _on_target_resized() -> void:
	_apply_pivot_mode()


func _disconnect_resized() -> void:
	if _connected_control != null and is_instance_valid(_connected_control):
		if _connected_control.resized.is_connected(_on_target_resized):
			_connected_control.resized.disconnect(_on_target_resized)
	_connected_control = null

# =============================================================================
# SEQUENCER RECIPE CONTRACT
# =============================================================================

func _recipe_capture_natural(target: Node) -> Variant:
	if target is Control:
		var ctrl := target as Control
		match transform_target:
			TransformTarget.POSITION:
				return {"position": ctrl.position}
			TransformTarget.ROTATION:
				return {"rotation": ctrl.rotation}
			TransformTarget.SCALE:
				return {"scale": ctrl.scale}
	return null


func _recipe_apply_natural(_target: Node, natural: Variant) -> void:
	if not (natural is Dictionary):
		return
	var dict := natural as Dictionary

	match transform_target:
		TransformTarget.POSITION:
			_base_position = dict.get("position", Vector2.ZERO) as Vector2
		TransformTarget.ROTATION:
			_base_rotation = dict.get("rotation", 0.0) as float
		TransformTarget.SCALE:
			_base_scale = dict.get("scale", Vector2.ONE) as Vector2

	_has_base = true
	_pivot_applied = false


func _recipe_restore_natural(target: Node, natural: Variant) -> void:
	if not (natural is Dictionary) or not (target is Control):
		return
	var dict := natural as Dictionary
	var ctrl := target as Control

	match transform_target:
		TransformTarget.POSITION:
			ctrl.position = dict.get("position", Vector2.ZERO) as Vector2
		TransformTarget.ROTATION:
			ctrl.rotation = dict.get("rotation", 0.0) as float
		TransformTarget.SCALE:
			ctrl.scale = dict.get("scale", Vector2.ONE) as Vector2

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent := get_parent()
	if not (parent is Control):
		warnings.append("SpringControlJuiceComp requires a Control parent.")
	return warnings
