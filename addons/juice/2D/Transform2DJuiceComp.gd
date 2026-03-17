## Animate position, rotation, or scale of a [Node2D] with tween-based easing.
##
## Select a [member transform_target] (Position, Rotation, or Scale) and configure
## a From/To animation using [code]CUSTOM[/code] values, [code]SELF[/code] snapshots,
## or live [code]TARGET_NODE[/code] references. Supports pivot modes for rotation and
## scale. Add as a child of any [Node2D] and trigger via [method animate_in].

# ============================================================================
# WHAT: Consolidated deterministic transform effect for Node2D nodes. Combines
#       position, rotation, and scale animation into a single component with a
#       TransformTarget selector. Uses _get_property_list() to conditionally
#       show only relevant exports in the inspector.
# WHY: Replaces 3 separate scripts (Position2DJuiceComp, Rotation2DJuiceComp,
#      Scale2DJuiceComp) with one unified component, reducing file count and
#      ensuring consistent behavior across transform types.
#
# WRITE PATTERN: Delta-first. Each frame writes only the CHANGE in this comp's
#   contribution: node.property += (desired - _my_contribution). This enables
#   stacking with other effects and preserves external changes to the node.
# SYSTEM: Juicing System (addons/juice/) - 2D Domain
# DOES NOT: Handle Control or Node3D targets (use TransformControl/Transform3D).
# DOES NOT: Handle procedural effects like shake or noise (use Shake/Noise comps).
# DOES NOT: Handle arbitrary property animation (use PropertyShake/PropertyNoise).
# ============================================================================
#
# TRANSFORM TARGETS:
# - POSITION: Animates Node2D.position via From/To model + PositionIn unit system.
#   Supports PIXELS, FRACTION_OWN, FRACTION_PARENT, FRACTION_VIEWPORT units.
#   Uses size inference (Sprite2D, AnimatedSprite2D, CollisionShape2D, Polygon2D,
#   recursive child bounds) for fraction-based offset resolution.
# - ROTATION: Animates Node2D.rotation via From/To model (degrees) + pivot mode.
#   Node2D lacks native pivot_offset, so pivot is achieved by position
#   compensation: fixed_pivot = base_pos + pivot.rotated(base_rot),
#   new_pos = fixed_pivot - pivot.rotated(new_rot).
# - SCALE: Animates Node2D.scale via From/To model + pivot mode.
#   Pivot compensation via: pos += pivot * (ONE - scale_ratio).
#
# PIVOT (ROTATION and SCALE only):
# - AUTO_CENTER: Infers visual center from Sprite2D/CollisionShape2D/etc.
#   Node2D content is typically centered at origin, so center is often (0,0).
# - INHERIT: No position compensation (rotate/scale from node origin).
# - CUSTOM: User-specified local-space pivot point (pixels).
#
# FROM/TO MODEL (Position, Rotation, Scale):
# All transform types use a unified "From [source] To [destination]" model.
# Sources can be CUSTOM (explicit value), SELF (snapshot), or TARGET_NODE (live).
#
# CONDITIONAL EXPORTS:
# Changing transform_target triggers notify_property_list_changed() which
# shows/hides the relevant parameters via _get_property_list(). Properties
# added this way appear AFTER all @export properties in the inspector.
# ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBase2D.svg")
class_name Transform2DJuiceComp
extends JuiceCompBase

# =============================================================================
# TRANSFORM TARGET SELECTION
# =============================================================================

## Which transform property to animate
enum TransformTarget {
	POSITION,  ## Animate Node2D.position with offset + unit
	ROTATION,  ## Animate Node2D.rotation (single-axis Z, degrees)
	SCALE      ## Animate Node2D.scale with offset
}

@export_group("Effect")

@export var transform_target: TransformTarget = TransformTarget.POSITION:
	set(value):
		transform_target = value
		notify_property_list_changed()

# =============================================================================
# PIVOT MODE (shown for ROTATION and SCALE only, via _get_property_list)
# =============================================================================

## Determines how the pivot point is calculated
enum PivotMode {
	AUTO_CENTER,  ## Infer visual center and compensate position (most common)
	INHERIT,      ## Rotate/scale from node origin (no compensation)
	CUSTOM        ## Rotate/scale from custom_pivot (local-space pixels)
}

## Reference type for From/To axes (shared by Position, Rotation, and Scale)
enum TransformReference {
	CUSTOM,       ## Explicit value supplied by the user
	SELF,         ## This object's current value (captured at capture_at moment)
	TARGET_NODE   ## Another object's value (tracked live every frame)
}

## How to interpret custom position values (2D)
enum PositionIn {
	PIXELS,           ## Position in absolute pixels
	FRACTION_OWN,     ## Position in fraction of object's own size
	FRACTION_PARENT,  ## Position in fraction of parent's size
	FRACTION_VIEWPORT ## Position in fraction of viewport size
}

## When to capture Self's transform value
enum CaptureAt {
	TRIGGER,    ## Capture when animation starts (default)
	READY,      ## Capture when scene loads / _ready()
	IN_EDITOR   ## WYSIWYG — bake editor-time value into the scene file
}

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — they are shown/hidden via _get_property_list()
# =============================================================================

# --- POSITION (From/To model) ---
## Custom From position value (shown when from_reference == CUSTOM)
var from_position: Vector2 = Vector2.ZERO
## How to interpret From position values
var from_position_in: int = PositionIn.FRACTION_OWN
## Custom To position value (shown when to_reference == CUSTOM)
var to_position: Vector2 = Vector2.ZERO
## How to interpret To position values
var to_position_in: int = PositionIn.FRACTION_OWN

# --- ROTATION (From/To model) ---
## Custom From rotation offset in degrees (shown when from_reference == CUSTOM)
var from_rotation_degrees: float = 0.0
## Custom To rotation offset in degrees (shown when to_reference == CUSTOM)
var to_rotation_degrees: float = 15.0

# --- SHARED FROM/TO (used by all transform types) ---
## Reference type for the From endpoint (CUSTOM, SELF, or TARGET_NODE)
var from_reference: int = TransformReference.SELF:
	set(value):
		from_reference = value
		notify_property_list_changed()
## Reference type for the To endpoint (CUSTOM, SELF, or TARGET_NODE)
var to_reference: int = TransformReference.CUSTOM:
	set(value):
		to_reference = value
		notify_property_list_changed()
## Target node for From reference (shown when from_reference == TARGET_NODE)
var from_target_node: NodePath
## Target node for To reference (shown when to_reference == TARGET_NODE)
var to_target_node: NodePath
## When to capture Self's transform value (shown when reference == SELF)
var capture_at: int = CaptureAt.TRIGGER:
	set(value):
		capture_at = value
		# Clear editor cache when leaving IN_EDITOR to keep .tscn clean
		if value != CaptureAt.IN_EDITOR:
			_editor_cached_position = Vector2.ZERO
			_editor_cached_rotation = 0.0
			_editor_cached_scale = Vector2.ONE
		# Capture immediately when entering IN_EDITOR in the editor
		elif Engine.is_editor_hint():
			_update_editor_cache()
		notify_property_list_changed()

# --- SCALE (From/To model) ---
## Custom From scale value (shown when from_reference == CUSTOM)
var from_scale: Vector2 = Vector2.ZERO
## Custom To scale value (shown when to_reference == CUSTOM)
var to_scale: Vector2 = Vector2.ONE

# --- PIVOT (ROTATION + SCALE) ---
var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()
## Custom pivot in local-space coordinates (pixels)
var custom_pivot: Vector2 = Vector2.ZERO

# --- EDITOR CACHE (serialized only when capture_at == IN_EDITOR) ---
# These store the parent's transform at editor time so the runtime can use
# pre-baked values without a frame-0 flash.
var _editor_cached_position: Vector2 = Vector2.ZERO
var _editor_cached_rotation: float = 0.0
var _editor_cached_scale: Vector2 = Vector2.ONE

# =============================================================================
# INTERNAL STATE
# =============================================================================

var _base_position: Vector2 = Vector2.ZERO
var _base_rotation_radians: float = 0.0
var _base_scale: Vector2 = Vector2.ONE

## Whether base has been captured
var _has_base: bool = false

## Resolved pivot point in target's local space (for rotation/scale)
var _pivot_point: Vector2 = Vector2.ZERO
var _pivot_resolved: bool = false

## Fixed pivot position in parent space (pre-computed at animation start for rotation)
var _fixed_pivot_parent: Vector2 = Vector2.ZERO

## Delta-first contribution tracking.
## Each tracks what THIS comp has contributed to the node's property.
## On each frame: delta = desired - contribution; node.prop += delta.
## On cleanup: node.prop -= contribution.
var _my_position_contribution: Vector2 = Vector2.ZERO
var _my_rotation_contribution: float = 0.0
var _my_scale_contribution: Vector2 = Vector2.ZERO

## Tracks the position we last wrote to the target. Used to detect external
## repositioning between frames. See TransformControlJuiceComp for full docs.
var _last_written_position: Vector2 = Vector2.INF

## Resolved references for From/To target nodes (cached at animation start)
## Shared by Position, Rotation, and Scale From/To models
var _from_ref: Node2D = null
var _to_ref: Node2D = null
## Self position snapshot — captured once at the moment chosen by capture_at
var _self_position_snapshot: Vector2 = Vector2.ZERO
var _has_self_position_snapshot: bool = false
## Self rotation snapshot — captured once at the moment chosen by capture_at (radians)
var _self_rotation_snapshot: float = 0.0
var _has_self_rotation_snapshot: bool = false
## Self scale snapshot — captured once at the moment chosen by capture_at
var _self_scale_snapshot: Vector2 = Vector2.ONE
var _has_self_scale_snapshot: bool = false


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	match transform_target:
		TransformTarget.POSITION:
			props.append_array(_get_position_from_to_properties())

		TransformTarget.ROTATION:
			props.append_array(_get_rotation_from_to_properties())
			props.append_array(_get_pivot_properties())

		TransformTarget.SCALE:
			props.append_array(_get_scale_from_to_properties())
			props.append_array(_get_pivot_properties())

	# Editor cache — serialized (STORAGE only) when IN_EDITOR is active so the
	# baked value survives save/load. Hidden from inspector.
	var uses_self := (from_reference == TransformReference.SELF or to_reference == TransformReference.SELF)
	if uses_self and capture_at == CaptureAt.IN_EDITOR:
		props.append({"name": "_editor_cached_position", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_STORAGE})
		props.append({"name": "_editor_cached_rotation", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_STORAGE})
		props.append({"name": "_editor_cached_scale", "type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_STORAGE})

	return props


## Position From/To inspector properties (new model)
func _get_position_from_to_properties() -> Array[Dictionary]:
	var pos_props: Array[Dictionary] = []

	# --- From group ---
	pos_props.append({"name": "From", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	pos_props.append({
		"name": "from_reference",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node",
	})

	if from_reference == TransformReference.CUSTOM:
		pos_props.append({
			"name": "from_position_in",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Pixels,Fraction Own,Fraction Parent,Fraction Viewport",
		})
		pos_props.append({
			"name": "from_position",
			"type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif from_reference == TransformReference.SELF:
		pos_props.append({
			"name": "capture_at",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor",
		})
	elif from_reference == TransformReference.TARGET_NODE:
		pos_props.append({
			"name": "from_target_node",
			"type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D",
		})

	# --- To group ---
	pos_props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	pos_props.append({
		"name": "to_reference",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node",
	})

	if to_reference == TransformReference.CUSTOM:
		pos_props.append({
			"name": "to_position_in",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Pixels,Fraction Own,Fraction Parent,Fraction Viewport",
		})
		pos_props.append({
			"name": "to_position",
			"type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif to_reference == TransformReference.SELF:
		pos_props.append({
			"name": "capture_at",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor",
		})
	elif to_reference == TransformReference.TARGET_NODE:
		pos_props.append({
			"name": "to_target_node",
			"type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D",
		})

	return pos_props


## Rotation From/To inspector properties (new model)
func _get_rotation_from_to_properties() -> Array[Dictionary]:
	var rot_props: Array[Dictionary] = []

	# --- From group ---
	rot_props.append({"name": "From", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	rot_props.append({
		"name": "from_reference",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node",
	})

	if from_reference == TransformReference.CUSTOM:
		rot_props.append({
			"name": "from_rotation_degrees",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif from_reference == TransformReference.SELF:
		rot_props.append({
			"name": "capture_at",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor",
		})
	elif from_reference == TransformReference.TARGET_NODE:
		rot_props.append({
			"name": "from_target_node",
			"type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D",
		})

	# --- To group ---
	rot_props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	rot_props.append({
		"name": "to_reference",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node",
	})

	if to_reference == TransformReference.CUSTOM:
		rot_props.append({
			"name": "to_rotation_degrees",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif to_reference == TransformReference.SELF:
		rot_props.append({
			"name": "capture_at",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor",
		})
	elif to_reference == TransformReference.TARGET_NODE:
		rot_props.append({
			"name": "to_target_node",
			"type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D",
		})

	return rot_props


## Scale From/To inspector properties (new model)
func _get_scale_from_to_properties() -> Array[Dictionary]:
	var scale_props: Array[Dictionary] = []

	# --- From group ---
	scale_props.append({"name": "From", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	scale_props.append({
		"name": "from_reference",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node",
	})

	if from_reference == TransformReference.CUSTOM:
		scale_props.append({
			"name": "from_scale",
			"type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif from_reference == TransformReference.SELF:
		scale_props.append({
			"name": "capture_at",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor",
		})
	elif from_reference == TransformReference.TARGET_NODE:
		scale_props.append({
			"name": "from_target_node",
			"type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D",
		})

	# --- To group ---
	scale_props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	scale_props.append({
		"name": "to_reference",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node",
	})

	if to_reference == TransformReference.CUSTOM:
		scale_props.append({
			"name": "to_scale",
			"type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	elif to_reference == TransformReference.SELF:
		scale_props.append({
			"name": "capture_at",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor",
		})
	elif to_reference == TransformReference.TARGET_NODE:
		scale_props.append({
			"name": "to_target_node",
			"type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D",
		})

	return scale_props


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
		# Position (From/To model)
		&"from_position": from_position = value; return true
		&"from_position_in": from_position_in = value; return true
		&"to_position": to_position = value; return true
		&"to_position_in": to_position_in = value; return true
		# Rotation (From/To model)
		&"from_rotation_degrees": from_rotation_degrees = value; return true
		&"to_rotation_degrees": to_rotation_degrees = value; return true
		# Shared From/To
		&"from_reference": from_reference = value; return true
		&"to_reference": to_reference = value; return true
		&"from_target_node": from_target_node = value; return true
		&"to_target_node": to_target_node = value; return true
		&"capture_at": capture_at = value; return true
		# Scale (From/To model)
		&"from_scale": from_scale = value; return true
		&"to_scale": to_scale = value; return true
		# Pivot
		&"pivot_mode": pivot_mode = value; return true
		&"custom_pivot": custom_pivot = value; return true
		# Editor cache (always handle for deserialization even when not in property list)
		&"_editor_cached_position": _editor_cached_position = value; return true
		&"_editor_cached_rotation": _editor_cached_rotation = value; return true
		&"_editor_cached_scale": _editor_cached_scale = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		# Position (From/To model)
		&"from_position": return from_position
		&"from_position_in": return from_position_in
		&"to_position": return to_position
		&"to_position_in": return to_position_in
		# Rotation (From/To model)
		&"from_rotation_degrees": return from_rotation_degrees
		&"to_rotation_degrees": return to_rotation_degrees
		# Shared From/To
		&"from_reference": return from_reference
		&"to_reference": return to_reference
		&"from_target_node": return from_target_node
		&"to_target_node": return to_target_node
		&"capture_at": return capture_at
		# Scale (From/To model)
		&"from_scale": return from_scale
		&"to_scale": return to_scale
		# Pivot
		&"pivot_mode": return pivot_mode
		&"custom_pivot": return custom_pivot
		# Editor cache
		&"_editor_cached_position": return _editor_cached_position
		&"_editor_cached_rotation": return _editor_cached_rotation
		&"_editor_cached_scale": return _editor_cached_scale
	return null


# =============================================================================
# LIFECYCLE OVERRIDES
# =============================================================================

func _notification(what: int) -> void:
	# Bake parent's transform into editor cache right before the scene is saved.
	# This ensures IN_EDITOR Self values are always fresh when the .tscn is written.
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_update_editor_cache()


func _ready() -> void:
	super._ready()
	# All transform types now use From/To model — capture base early
	call_deferred("_capture_base")
	# If Self reference uses CaptureAt.READY, snapshot now (only if SELF is actually used)
	var uses_self := (from_reference == TransformReference.SELF or to_reference == TransformReference.SELF)
	if not uses_self:
		return

	# IN_EDITOR: value is already baked in the scene file — nothing to capture at runtime.
	# In editor: refresh cache so it's current if the user moves the parent.
	if capture_at == CaptureAt.IN_EDITOR:
		if Engine.is_editor_hint():
			call_deferred("_update_editor_cache")
		return

	if capture_at == CaptureAt.READY:
		match transform_target:
			TransformTarget.POSITION:
				call_deferred("_capture_self_position_snapshot")
			TransformTarget.ROTATION:
				call_deferred("_capture_self_rotation_snapshot")
			TransformTarget.SCALE:
				call_deferred("_capture_self_scale_snapshot")


func _invalidate_base_cache() -> void:
	_has_base = false
	_pivot_resolved = false
	_from_ref = null
	_to_ref = null
	_has_self_position_snapshot = false
	_has_self_rotation_snapshot = false
	_has_self_scale_snapshot = false
	_my_position_contribution = Vector2.ZERO
	_my_rotation_contribution = 0.0
	_my_scale_contribution = Vector2.ZERO
	_last_written_position = Vector2.INF


func _get_interrupt_identity() -> Variant:
	return [get_script(), transform_target]


func _exit_tree() -> void:
	# Clean up our delta contribution if freed mid-animation
	var target := _get_target_node2d()
	if target == null:
		return
	match transform_target:
		TransformTarget.POSITION:
			target.position -= _my_position_contribution
		TransformTarget.ROTATION:
			target.rotation -= _my_rotation_contribution
			if _pivot_point != Vector2.ZERO:
				target.position -= _my_position_contribution
		TransformTarget.SCALE:
			target.scale -= _my_scale_contribution
			if _pivot_point != Vector2.ZERO:
				target.position -= _my_position_contribution
	_my_position_contribution = Vector2.ZERO
	_my_rotation_contribution = 0.0
	_my_scale_contribution = Vector2.ZERO


func _temporarily_undo_visual() -> void:
	var target := _get_target_node2d()
	if target == null:
		return
	match transform_target:
		TransformTarget.POSITION:
			target.position -= _my_position_contribution
			_last_written_position = target.position
		TransformTarget.ROTATION:
			target.rotation -= _my_rotation_contribution
			if _pivot_point != Vector2.ZERO:
				target.position -= _my_position_contribution
				_last_written_position = target.position
		TransformTarget.SCALE:
			target.scale -= _my_scale_contribution
			if _pivot_point != Vector2.ZERO:
				target.position -= _my_position_contribution
				_last_written_position = target.position


func _temporarily_reapply_visual() -> void:
	var target := _get_target_node2d()
	if target == null:
		return
	match transform_target:
		TransformTarget.POSITION:
			target.position += _my_position_contribution
			_last_written_position = target.position
		TransformTarget.ROTATION:
			target.rotation += _my_rotation_contribution
			if _pivot_point != Vector2.ZERO:
				target.position += _my_position_contribution
				_last_written_position = target.position
		TransformTarget.SCALE:
			target.scale += _my_scale_contribution
			if _pivot_point != Vector2.ZERO:
				target.position += _my_position_contribution
				_last_written_position = target.position


func _on_animate_start() -> void:
	if not _has_base:
		_capture_base()

	# All transform types now use From/To model
	_resolve_from_to_refs()
	# Capture Self snapshot (only if SELF is actually used)
	# IN_EDITOR snapshots are pre-baked — _capture_self_*_snapshot reads the cache.
	var uses_self := (from_reference == TransformReference.SELF or to_reference == TransformReference.SELF)
	if uses_self and (capture_at == CaptureAt.TRIGGER or capture_at == CaptureAt.IN_EDITOR):
		match transform_target:
			TransformTarget.POSITION:
				_capture_self_position_snapshot()
			TransformTarget.ROTATION:
				_capture_self_rotation_snapshot()
			TransformTarget.SCALE:
				_capture_self_scale_snapshot()

	# Resolve pivot for rotation/scale targets
	if transform_target != TransformTarget.POSITION and not _pivot_resolved:
		_resolve_pivot()
		_pivot_resolved = true

	# Pre-compute fixed pivot in parent space for rotation
	if transform_target == TransformTarget.ROTATION:
		_fixed_pivot_parent = _base_position + _pivot_point.rotated(_base_rotation_radians)

	if debug_enabled:
		var target_name: String = TransformTarget.keys()[transform_target]
		print("[%s] Transform start (2D, %s)" % [name, target_name])


func _apply_effect(progress: float) -> void:
	var target := _get_target_node2d()
	if target == null:
		return

	match transform_target:
		TransformTarget.POSITION:
			_apply_position_effect(progress, target)
		TransformTarget.ROTATION:
			_apply_rotation_effect(progress, target)
		TransformTarget.SCALE:
			_apply_scale_effect(progress, target)


# =============================================================================
# POSITION EFFECT
# =============================================================================

## Apply position using From/To lerp model.
## Both From and To are resolved to world pixels, then interpolated.
func _apply_position_effect(progress: float, target: Node2D) -> void:
	# Detect external repositioning between frames (see TransformControlJuiceComp).
	if _last_written_position != Vector2.INF:
		if not target.position.is_equal_approx(_last_written_position):
			_base_position = target.position
			_my_position_contribution = Vector2.ZERO

	var from_value := _resolve_from_position(target)
	var to_value := _resolve_to_position(target)
	var desired_absolute := from_value.lerp(to_value, progress)

	# Convert absolute position to delta from base (for delta-first write pattern)
	var desired_offset := desired_absolute - _base_position
	var delta := desired_offset - _my_position_contribution
	target.position += delta
	_my_position_contribution = desired_offset
	_last_written_position = target.position


## Resolve the From position to an absolute Vector2 in local space
func _resolve_from_position(animated: Node2D) -> Vector2:
	match from_reference:
		TransformReference.CUSTOM:
			return _base_position + _convert_to_world_pixels(from_position, from_position_in)
		TransformReference.SELF:
			return _self_position_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_position(_from_ref, animated)
			return _base_position
	return _base_position


## Resolve the To position to an absolute Vector2 in local space
func _resolve_to_position(animated: Node2D) -> Vector2:
	match to_reference:
		TransformReference.CUSTOM:
			return _base_position + _convert_to_world_pixels(to_position, to_position_in)
		TransformReference.SELF:
			return _self_position_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_position(_to_ref, animated)
			return _base_position
	return _base_position


## Convert a position value from its PositionIn unit to world pixels (offset)
func _convert_to_world_pixels(position: Vector2, position_in: int) -> Vector2:
	match position_in:
		PositionIn.PIXELS:
			return position
		PositionIn.FRACTION_OWN:
			var size := _infer_node2d_size(_target_node as Node2D)
			return Vector2(position.x * size.x, position.y * size.y)
		PositionIn.FRACTION_PARENT:
			var size := _infer_parent_size()
			return Vector2(position.x * size.x, position.y * size.y)
		PositionIn.FRACTION_VIEWPORT:
			var size := _get_viewport_size()
			return Vector2(position.x * size.x, position.y * size.y)
	return position


## Convert a reference node's global position to the animated node's parent-local position
func _get_ref_local_position(ref: Node2D, animated: Node2D) -> Vector2:
	var parent := animated.get_parent()
	if parent is Node2D:
		return (parent as Node2D).global_transform.affine_inverse() * ref.global_position
	elif parent is Control:
		return (parent as Control).get_global_transform().affine_inverse() * ref.global_position
	return ref.global_position


# =============================================================================
# ROTATION EFFECT
# =============================================================================

## Apply rotation using From/To lerp model with pivot compensation.
## Node2D lacks native pivot_offset, so we adjust position to keep
## the pivot point stationary during rotation:
##   fixed_pivot = base_pos + pivot.rotated(base_rot)
##   new_pos = fixed_pivot - pivot.rotated(new_rot)
func _apply_rotation_effect(progress: float, target: Node2D) -> void:
	var from_rad := _resolve_from_rotation(target)
	var to_rad := _resolve_to_rotation(target)
	var desired_absolute := lerp_angle(from_rad, to_rad, progress)

	# Convert absolute rotation to delta from base (for delta-first write pattern)
	var desired_offset := desired_absolute - _base_rotation_radians
	var rot_delta := desired_offset - _my_rotation_contribution
	target.rotation += rot_delta
	_my_rotation_contribution = desired_offset

	# Pivot compensation: position depends on the full rotation.
	if _pivot_point != Vector2.ZERO:
		var desired_pos := _fixed_pivot_parent - _pivot_point.rotated(desired_absolute)
		var desired_pos_offset := desired_pos - _base_position
		var pos_delta := desired_pos_offset - _my_position_contribution
		target.position += pos_delta
		_my_position_contribution = desired_pos_offset


## Resolve the From rotation to an absolute value in radians (local space)
func _resolve_from_rotation(animated: Node2D) -> float:
	match from_reference:
		TransformReference.CUSTOM:
			return _base_rotation_radians + deg_to_rad(from_rotation_degrees)
		TransformReference.SELF:
			return _self_rotation_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_rotation(_from_ref, animated)
			return _base_rotation_radians
	return _base_rotation_radians


## Resolve the To rotation to an absolute value in radians (local space)
func _resolve_to_rotation(animated: Node2D) -> float:
	match to_reference:
		TransformReference.CUSTOM:
			return _base_rotation_radians + deg_to_rad(to_rotation_degrees)
		TransformReference.SELF:
			return _self_rotation_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_rotation(_to_ref, animated)
			return _base_rotation_radians
	return _base_rotation_radians


## Convert a reference node's global rotation to the animated node's parent-local rotation
func _get_ref_local_rotation(ref: Node2D, animated: Node2D) -> float:
	var parent := animated.get_parent()
	if parent is Node2D:
		return ref.global_rotation - (parent as Node2D).global_rotation
	return ref.global_rotation


# =============================================================================
# SCALE EFFECT
# =============================================================================

## Apply scale using From/To lerp model with pivot compensation.
## Node2D lacks native pivot_offset, so we adjust position to keep
## the pivot point stationary during scaling:
##   pos += pivot * (ONE - scale_ratio)
func _apply_scale_effect(progress: float, target: Node2D) -> void:
	# Resolve absolute From and To values, then lerp between them
	var from_value := _resolve_from_scale(target)
	var to_value := _resolve_to_scale(target)
	var desired_absolute := from_value.lerp(to_value, progress)

	# Convert absolute scale to delta from base (for delta-first write pattern)
	var desired_offset := desired_absolute - _base_scale
	var scale_delta := desired_offset - _my_scale_contribution

	# Pivot compensation: adjust position so the pivot point stays stationary
	if _pivot_point != Vector2.ZERO:
		var scale_ratio := desired_absolute / _base_scale
		var desired_pos_offset := _pivot_point * (Vector2.ONE - scale_ratio)
		var pos_delta := desired_pos_offset - _my_position_contribution
		target.position += pos_delta
		_my_position_contribution = desired_pos_offset

	target.scale += scale_delta
	_my_scale_contribution = desired_offset


## Resolve the From scale value to an absolute Vector2 based on from_reference
func _resolve_from_scale(animated: Node2D) -> Vector2:
	match from_reference:
		TransformReference.CUSTOM:
			return from_scale
		TransformReference.SELF:
			return _self_scale_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_scale(_from_ref, animated)
			return _base_scale
	return _base_scale


## Resolve the To scale value to an absolute Vector2 based on to_reference
func _resolve_to_scale(animated: Node2D) -> Vector2:
	match to_reference:
		TransformReference.CUSTOM:
			return to_scale
		TransformReference.SELF:
			return _self_scale_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_scale(_to_ref, animated)
			return _base_scale
	return _base_scale


## Convert a reference node's global scale to the animated node's parent-local scale
func _get_ref_local_scale(ref: Node2D, animated: Node2D) -> Vector2:
	var ref_global_scale := ref.global_scale
	var parent_scale := Vector2.ONE
	var parent := animated.get_parent()
	if parent is Node2D:
		parent_scale = (parent as Node2D).global_scale
	return ref_global_scale / parent_scale


# =============================================================================
# FROM/TO REFERENCE RESOLUTION (shared by Position, Rotation, and Scale)
# =============================================================================

## Resolve from_target_node and to_target_node NodePaths to cached references.
## Called once per animation start for all From/To models.
func _resolve_from_to_refs() -> void:
	_from_ref = null
	_to_ref = null
	if from_reference == TransformReference.TARGET_NODE:
		_from_ref = _resolve_node_path_to_node2d(from_target_node, "from_target_node")
	if to_reference == TransformReference.TARGET_NODE:
		_to_ref = _resolve_node_path_to_node2d(to_target_node, "to_target_node")


## Capture Self's current rotation as a stable snapshot for use during animation.
## Called at the moment chosen by capture_at (READY, TRIGGER, or IN_EDITOR).
func _capture_self_rotation_snapshot() -> void:
	if _has_self_rotation_snapshot:
		return
	if capture_at == CaptureAt.IN_EDITOR:
		_self_rotation_snapshot = _editor_cached_rotation
	else:
		var target := _get_target_node2d()
		if target == null:
			_self_rotation_snapshot = 0.0
		else:
			_self_rotation_snapshot = target.rotation
	_has_self_rotation_snapshot = true
	if debug_enabled:
		print("[%s] Captured self rotation snapshot: %s rad (mode=%s)" % [
			name, _self_rotation_snapshot, CaptureAt.keys()[capture_at]])


## Capture Self's current position as a stable snapshot for use during animation.
## Called at the moment chosen by capture_at (READY, TRIGGER, or IN_EDITOR).
## IN_EDITOR uses the pre-baked editor cache instead of reading from the live node.
func _capture_self_position_snapshot() -> void:
	if _has_self_position_snapshot:
		return
	if capture_at == CaptureAt.IN_EDITOR:
		_self_position_snapshot = _editor_cached_position
	else:
		var target := _get_target_node2d()
		if target == null:
			_self_position_snapshot = Vector2.ZERO
		else:
			_self_position_snapshot = target.position
	_has_self_position_snapshot = true
	if debug_enabled:
		print("[%s] Captured self position snapshot: %s (mode=%s)" % [
			name, _self_position_snapshot, CaptureAt.keys()[capture_at]])


## Capture Self's current scale as a stable snapshot for use during animation.
## Called at the moment chosen by capture_at (READY, TRIGGER, or IN_EDITOR).
func _capture_self_scale_snapshot() -> void:
	if _has_self_scale_snapshot:
		return
	if capture_at == CaptureAt.IN_EDITOR:
		_self_scale_snapshot = _editor_cached_scale
	else:
		var target := _get_target_node2d()
		if target == null:
			_self_scale_snapshot = Vector2.ONE
		else:
			_self_scale_snapshot = target.scale
	_has_self_scale_snapshot = true
	if debug_enabled:
		print("[%s] Captured self scale snapshot: %s (mode=%s)" % [
			name, _self_scale_snapshot, CaptureAt.keys()[capture_at]])


## Helper: resolve a NodePath to a Node2D, with debug warnings on failure.
## Returns null if the path is empty, unresolvable, or not a Node2D.
func _resolve_node_path_to_node2d(path: NodePath, path_name: String) -> Node2D:
	if path.is_empty():
		return null
	var resolved := get_node_or_null(path)
	if resolved == null:
		if debug_enabled:
			push_warning("[%s] %s path '%s' could not be resolved" % [name, path_name, path])
		return null
	if not (resolved is Node2D):
		if debug_enabled:
			push_warning("[%s] %s '%s' is not a Node2D (is %s)" % [name, path_name, resolved.name, resolved.get_class()])
		return null
	if debug_enabled:
		print("[%s] Resolved %s: '%s'" % [name, path_name, resolved.name])
	return resolved as Node2D


# =============================================================================
# EDITOR CACHE (IN_EDITOR capture mode)
# =============================================================================

## Refresh the editor cache from the parent's current transform.
## Called on NOTIFICATION_EDITOR_PRE_SAVE and when capture_at switches to IN_EDITOR.
## Only writes when IN_EDITOR is active and a SELF reference is used.
func _update_editor_cache() -> void:
	if not Engine.is_editor_hint():
		return
	if capture_at != CaptureAt.IN_EDITOR:
		return
	var uses_self := (from_reference == TransformReference.SELF or to_reference == TransformReference.SELF)
	if not uses_self:
		return

	var parent := get_parent()
	if not parent is Node2D:
		return

	var n2d := parent as Node2D
	_editor_cached_position = n2d.position
	_editor_cached_rotation = n2d.rotation
	_editor_cached_scale = n2d.scale

	if debug_enabled:
		print("[%s] Editor cache updated: pos=%s, rot=%.1f°, scale=%s" % [
			name, _editor_cached_position, rad_to_deg(_editor_cached_rotation), _editor_cached_scale])


## Returns true if this component uses IN_EDITOR capture with a SELF reference.
## Used by SequencerJuiceComp to decide whether to cache per-target transforms.
func _needs_editor_cache_injection() -> bool:
	var uses_self := (from_reference == TransformReference.SELF or to_reference == TransformReference.SELF)
	return uses_self and capture_at == CaptureAt.IN_EDITOR


## Inject per-target editor-cached transform values from the Sequencer.
## Called by SequencerJuiceComp when it clones this recipe onto a target.
func _inject_editor_cache(cache: Dictionary) -> void:
	if cache.has("position"):
		_editor_cached_position = cache["position"]
	if cache.has("rotation"):
		_editor_cached_rotation = cache["rotation"]
	if cache.has("scale"):
		_editor_cached_scale = cache["scale"]
	if debug_enabled:
		print("[%s] Editor cache injected by Sequencer: pos=%s, rot=%.1f°, scale=%s" % [
			name, _editor_cached_position, rad_to_deg(_editor_cached_rotation), _editor_cached_scale])


# =============================================================================
# BASE CAPTURE
# =============================================================================

func _capture_base() -> void:
	if _has_base:
		return

	var target := _get_target_node2d()
	if target == null:
		if debug_enabled and _target_node != null:
			push_warning("[%s] Target '%s' is not Node2D" % [name, _target_node.name])
		_has_base = true
		return

	_base_position = target.position
	_base_rotation_radians = target.rotation
	_base_scale = target.scale
	_has_base = true

	if debug_enabled:
		print("[%s] Captured base: pos=%s, rot=%.1f°, scale=%s" % [
			name, _base_position, rad_to_deg(_base_rotation_radians), _base_scale
		])


# =============================================================================
# PIVOT RESOLUTION (ROTATION and SCALE)
# =============================================================================

## Resolve the pivot point based on pivot_mode. Node2D has no native
## pivot_offset, so AUTO_CENTER infers visual bounds from child nodes.
func _resolve_pivot() -> void:
	match pivot_mode:
		PivotMode.AUTO_CENTER:
			# Compute the visual center of the target in local space.
			# Node2D content (Sprite2D, shapes, etc.) is typically centered at origin,
			# so the center is often (0,0) — meaning no position compensation is needed.
			if _target_node is Node2D:
				var n2d := _target_node as Node2D
				var bounds := _infer_node2d_local_bounds(n2d)
				if bounds.size == Vector2.ZERO:
					# Container fallback: compute merged bounds from children
					bounds = _infer_node2d_bounds_recursive(n2d)
				if bounds.size != Vector2.ZERO:
					_pivot_point = bounds.get_center()
				else:
					_pivot_point = Vector2.ZERO
				if debug_enabled:
					print("[%s] Auto-center pivot: bounds=%s, center=%s" % [name, bounds, _pivot_point])
			else:
				_pivot_point = Vector2.ZERO
		PivotMode.INHERIT:
			_pivot_point = Vector2.ZERO
		PivotMode.CUSTOM:
			_pivot_point = custom_pivot


# =============================================================================
# SIZE INFERENCE (shared between position offset units and pivot resolution)
# =============================================================================

func _infer_parent_size() -> Vector2:
	if _target_node == null:
		return Vector2.ZERO
	var parent := _target_node.get_parent()
	if parent is Control:
		return (parent as Control).size
	if parent is Node2D:
		return _infer_node2d_size(parent as Node2D)
	return Vector2.ZERO


func _infer_node2d_size(node: Node2D) -> Vector2:
	if node == null:
		return Vector2.ZERO

	if node is Sprite2D:
		var spr := node as Sprite2D
		var tex := spr.texture
		if tex != null:
			var size := tex.get_size()
			if spr.region_enabled:
				size = spr.region_rect.size
			var sc := spr.scale
			return Vector2(absf(sc.x) * size.x, absf(sc.y) * size.y)

	if node is AnimatedSprite2D:
		var anim := node as AnimatedSprite2D
		if anim.sprite_frames != null:
			var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
			if tex != null:
				var size := tex.get_size()
				var sc := anim.scale
				return Vector2(absf(sc.x) * size.x, absf(sc.y) * size.y)

	if node is CollisionShape2D:
		var col := node as CollisionShape2D
		if col.shape != null:
			var shape := col.shape
			if shape is RectangleShape2D:
				return (shape as RectangleShape2D).size
			if shape is CircleShape2D:
				var r := (shape as CircleShape2D).radius
				return Vector2(r * 2.0, r * 2.0)
			if shape is CapsuleShape2D:
				var cap := shape as CapsuleShape2D
				return Vector2(cap.radius * 2.0, cap.height + cap.radius * 2.0)

	if node is Polygon2D:
		var poly := node as Polygon2D
		if poly.polygon.size() > 0:
			var min_x := poly.polygon[0].x
			var max_x := poly.polygon[0].x
			var min_y := poly.polygon[0].y
			var max_y := poly.polygon[0].y
			for p in poly.polygon:
				min_x = minf(min_x, p.x)
				max_x = maxf(max_x, p.x)
				min_y = minf(min_y, p.y)
				max_y = maxf(max_y, p.y)
			return Vector2(max_x - min_x, max_y - min_y)

	# Container fallback: infer a bounding box from all descendant Node2D children
	var bounds := _infer_node2d_bounds_recursive(node)
	if bounds.size != Vector2.ZERO:
		return bounds.size

	if debug_enabled:
		push_warning("[%s] Cannot infer Node2D size on '%s' (%s)" % [name, node.name, node.get_class()])
	return Vector2.ZERO


func _infer_node2d_bounds_recursive(root: Node2D) -> Rect2:
	var has_any: bool = false
	var combined := Rect2(Vector2.ZERO, Vector2.ZERO)

	for child in root.get_children():
		if not (child is Node2D):
			continue
		var child_n2d := child as Node2D
		var child_local_bounds := _infer_node2d_local_bounds(child_n2d)
		if child_local_bounds.size != Vector2.ZERO:
			child_local_bounds.position += child_n2d.position
			if not has_any:
				has_any = true
				combined = child_local_bounds
			else:
				combined = combined.merge(child_local_bounds)

		var grandchild_bounds := _infer_node2d_bounds_recursive(child_n2d)
		if grandchild_bounds.size != Vector2.ZERO:
			grandchild_bounds.position += child_n2d.position
			if not has_any:
				has_any = true
				combined = grandchild_bounds
			else:
				combined = combined.merge(grandchild_bounds)

	if not has_any:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return combined


func _infer_node2d_local_bounds(node: Node2D) -> Rect2:
	var size := Vector2.ZERO

	if node is Sprite2D:
		var spr := node as Sprite2D
		var tex := spr.texture
		if tex != null:
			size = tex.get_size()
			if spr.region_enabled:
				size = spr.region_rect.size
			var sc := spr.scale
			size = Vector2(absf(sc.x) * size.x, absf(sc.y) * size.y)

	elif node is AnimatedSprite2D:
		var anim := node as AnimatedSprite2D
		if anim.sprite_frames != null:
			var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
			if tex != null:
				size = tex.get_size()
				var sc := anim.scale
				size = Vector2(absf(sc.x) * size.x, absf(sc.y) * size.y)

	elif node is CollisionShape2D:
		var col := node as CollisionShape2D
		if col.shape != null:
			var shape := col.shape
			if shape is RectangleShape2D:
				size = (shape as RectangleShape2D).size
			elif shape is CircleShape2D:
				var r := (shape as CircleShape2D).radius
				size = Vector2(r * 2.0, r * 2.0)
			elif shape is CapsuleShape2D:
				var cap := shape as CapsuleShape2D
				size = Vector2(cap.radius * 2.0, cap.height + cap.radius * 2.0)

	elif node is Polygon2D:
		var poly := node as Polygon2D
		if poly.polygon.size() > 0:
			var min_x := poly.polygon[0].x
			var max_x := poly.polygon[0].x
			var min_y := poly.polygon[0].y
			var max_y := poly.polygon[0].y
			for p in poly.polygon:
				min_x = minf(min_x, p.x)
				max_x = maxf(max_x, p.x)
				min_y = minf(min_y, p.y)
				max_y = maxf(max_y, p.y)
			size = Vector2(max_x - min_x, max_y - min_y)

	if size == Vector2.ZERO:
		return Rect2(Vector2.ZERO, Vector2.ZERO)

	# Local bounds centered on the node's origin
	return Rect2(-size * 0.5, size)


# =============================================================================
# HELPERS
# =============================================================================

func _get_target_node2d() -> Node2D:
	if not is_instance_valid(_target_node):
		return null
	if _target_node is Node2D:
		return _target_node as Node2D
	if debug_enabled:
		push_warning("[%s] Target '%s' is not Node2D" % [name, _target_node.name])
	return null


# =============================================================================
# SEQUENCER RECIPE CONTRACT
# =============================================================================

func _recipe_capture_natural(target: Node) -> Variant:
	if target is Node2D:
		var n2d := target as Node2D
		match transform_target:
			TransformTarget.POSITION:
				return {"position": n2d.position}
			TransformTarget.ROTATION:
				# Rotation with pivot needs position too for compensation
				return {"rotation": n2d.rotation, "position": n2d.position}
			TransformTarget.SCALE:
				# Scale with pivot needs position too for compensation
				return {"scale": n2d.scale, "position": n2d.position}
	return null


func _recipe_apply_natural(_target: Node, natural: Variant) -> void:
	if not (natural is Dictionary):
		return
	var dict := natural as Dictionary

	match transform_target:
		TransformTarget.POSITION:
			_base_position = dict.get("position", Vector2.ZERO) as Vector2
			# Reset self snapshot so it gets re-captured for this target
			_has_self_position_snapshot = false
		TransformTarget.ROTATION:
			_base_rotation_radians = dict.get("rotation", 0.0) as float
			_base_position = dict.get("position", Vector2.ZERO) as Vector2
			# Reset self snapshot so it gets re-captured for this target
			_has_self_rotation_snapshot = false
		TransformTarget.SCALE:
			_base_scale = dict.get("scale", Vector2.ONE) as Vector2
			_base_position = dict.get("position", Vector2.ZERO) as Vector2
			# Reset self snapshot so it gets re-captured for this target
			_has_self_scale_snapshot = false

	_has_base = true
	_pivot_resolved = false


func _recipe_restore_natural(target: Node, natural: Variant) -> void:
	if not (natural is Dictionary) or not (target is Node2D):
		return
	var dict := natural as Dictionary
	var n2d := target as Node2D

	match transform_target:
		TransformTarget.POSITION:
			n2d.position = dict.get("position", Vector2.ZERO) as Vector2
		TransformTarget.ROTATION:
			n2d.rotation = dict.get("rotation", 0.0) as float
			n2d.position = dict.get("position", Vector2.ZERO) as Vector2
		TransformTarget.SCALE:
			n2d.scale = dict.get("scale", Vector2.ONE) as Vector2
			n2d.position = dict.get("position", Vector2.ZERO) as Vector2

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent := get_parent()
	if parent and not parent is Node2D and not parent is SequencerJuiceComp:
		warnings.append("Parent must be a Node2D node (or a SequencerJuiceComp). Use TransformControl/Transform3D for other domains.")
	# From/To: warn if both reference Self (no visible effect)
	if from_reference == TransformReference.SELF and to_reference == TransformReference.SELF:
		warnings.append("Both From and To reference Self — animation will have no visible effect.")
	# IN_EDITOR cache warning: parent must be Node2D or Sequencer
	if _needs_editor_cache_injection():
		if parent and not parent is Node2D and not parent is SequencerJuiceComp:
			warnings.append("IN_EDITOR capture: parent is not a Node2D or Sequencer. Editor cache will be empty — Self values will default to zero.")
	return warnings
