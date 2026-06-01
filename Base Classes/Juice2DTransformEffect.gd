## Intermediate base for 2D-domain effects that produce transform deltas.
## Extends [Juice2DEffectBase] and adds the complete Transform From/To framework.
## Concrete Transform effects (e.g., Transform2DJuiceEffect, future BounceEffect)
## only need to implement the typed virtual hooks below.

# ============================================================================
# WHAT: Domain base for all 2D transform effects (position/rotation/scale).
# WHY:  Consolidates shared From/To framework — enums, config, property list,
#       lifecycle skeleton, and non-typed state — so concrete effects provide
#       only the typed per-domain code (capture, apply, resolve, pivot).
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Apply any effect behavior — concrete subclasses implement virtuals.
# DOES NOT: Handle Control or Node3D targets.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBase2D.svg")
class_name Juice2DTransformEffect
extends Juice2DEffectBase


# =============================================================================
# DELTA CONTRIBUTION STORAGE
# =============================================================================
# Effects compute deltas (offsets from natural state) and store them here.
# The domain node (Juice2D) reads these after tick and writes ONCE.
# Effects NEVER write to the target directly.

## Which channels this effect contributes to. Set in _on_animate_start().
var _contributes_position: bool = false
var _contributes_rotation: bool = false
var _contributes_scale: bool = false

## Current delta values. Updated by _apply_effect() each tick.
## Position: offset from natural position (Vector2)
## Rotation: offset from natural rotation (float, radians)
## Scale: offset from natural scale (Vector2) — additive, not multiplicative
var _pos_delta: Vector2 = Vector2.ZERO
var _rot_delta: float = 0.0
var _scale_delta: Vector2 = Vector2.ZERO

# Last desired_absolute values — set by concrete _apply_*_effect() before subtraction.
# Logged as chain intermediate: if delta is wrong but desired is correct → bug is in base capture.
var _last_desired_pos: Vector2 = Vector2.ZERO
var _last_desired_rot: float = 0.0
var _last_desired_scale: Vector2 = Vector2.ZERO


# =============================================================================
# ENUMS — shared by all 2D transform effects
# =============================================================================

## Which transform property to animate
enum TransformTarget {
	POSITION,  ## Animate Node2D.position
	ROTATION,  ## Animate Node2D.rotation (Z axis, degrees)
	SCALE      ## Animate Node2D.scale
}

## Pivot strategy for rotation and scale
enum PivotMode {
	AUTO_CENTER,  ## Infer visual center from child nodes
	INHERIT,      ## Rotate/scale from node origin (no compensation)
	CUSTOM        ## User-specified local-space pivot point
}

## Reference source for From/To values
enum TransformReference {
	CUSTOM,       ## Explicit user-supplied value
	SELF,         ## This node's own captured snapshot
	TARGET_NODE   ## Another node's live value
}

## When to capture the Self snapshot
enum CaptureAt {
	TRIGGER,    ## At animation start (default)
	READY,      ## At scene load
	IN_EDITOR   ## Baked WYSIWYG value stored in scene file
}

## How to interpret custom position values (2D)
enum PositionIn {
	PIXELS,        ## Absolute pixels
	OWN_SIZE,      ## Multiple of object's own size
	PARENT_SIZE,   ## Multiple of parent's size
	VIEWPORT_SIZE  ## Multiple of viewport size
}


# =============================================================================
# CONFIGURATION — non-typed, shared by all 2D transform effects
# =============================================================================

## Which transform channel to animate: Position, Rotation, or Scale.
var transform_target: int = TransformTarget.POSITION:
	set(value):
		transform_target = value
		notify_property_list_changed()

func _init() -> void:
	_subclass_owns_effect_group = true

## Set to true in any direct subclass that has its own complete _get_property_list().
## When true, this class skips its own layout entirely to prevent the double
## "Effect" GROUP duplication that Godot causes by auto-combining all
## _get_property_list() overrides in the inheritance chain.
var _leaf_owns_layout: bool = false

## Where the starting value comes from: a Custom value, a Self snapshot, or a Target Node's live transform.
var from_reference: int = TransformReference.SELF:
	set(value):
		from_reference = value
		notify_property_list_changed()

## Where the ending value comes from: a Custom value, a Self snapshot, or a Target Node's live transform.
var to_reference: int = TransformReference.CUSTOM:
	set(value):
		to_reference = value
		notify_property_list_changed()

## Node whose transform is used as the animation start value when From Reference is Target Node.
var from_target_node: NodePath
## Node whose transform is used as the animation end value when To Reference is Target Node.
var to_target_node: NodePath

## When to snapshot this node's From value: at animation Trigger, at scene Ready, or baked In Editor.
var from_capture_at: int = CaptureAt.TRIGGER:
	set(value):
		from_capture_at = value
		if value != CaptureAt.IN_EDITOR:
			_clear_from_editor_cache_typed()
		elif Engine.is_editor_hint():
			_do_update_editor_cache(null)
		notify_property_list_changed()

## When to snapshot this node's To value: at animation Trigger, at scene Ready, or baked In Editor.
var to_capture_at: int = CaptureAt.TRIGGER:
	set(value):
		to_capture_at = value
		if value != CaptureAt.IN_EDITOR:
			_clear_to_editor_cache_typed()
		elif Engine.is_editor_hint():
			_do_update_editor_cache(null)
		notify_property_list_changed()

## Custom starting rotation offset in degrees, added to the node's natural rotation.
var from_rotation_degrees: float = 0.0
## Custom ending rotation offset in degrees, added to the node's natural rotation.
var to_rotation_degrees: float = 15.0

## Unit for the custom From position: absolute Pixels, or relative to Own Size, Parent Size, or Viewport Size.
var from_position_in: int = PositionIn.OWN_SIZE
## Unit for the custom To position: absolute Pixels, or relative to Own Size, Parent Size, or Viewport Size.
var to_position_in: int = PositionIn.OWN_SIZE

## Pivot strategy for rotation and scale: Auto Center infers the visual center, Inherit uses the node origin, Custom uses a specified offset.
var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	# If a direct subclass owns the full layout, skip to avoid double "Effect" GROUP.
	# See _leaf_owns_layout for details.
	if _leaf_owns_layout:
		return []
	var props: Array[Dictionary] = []

	props.append({"name": "Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "transform_target", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Position,Rotation,Scale",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append_array(_get_effect_base_properties())

	match transform_target:
		TransformTarget.POSITION:
			props.append_array(_get_position_from_to_properties())
		TransformTarget.ROTATION:
			props.append_array(_get_rotation_from_to_properties())
			props.append_array(_get_pivot_properties())
		TransformTarget.SCALE:
			props.append_array(_get_scale_from_to_properties())
			props.append_array(_get_pivot_properties())

	if from_reference == TransformReference.SELF and from_capture_at == CaptureAt.IN_EDITOR:
		props.append_array(_get_from_editor_cache_storage_properties())

	if to_reference == TransformReference.SELF and to_capture_at == CaptureAt.IN_EDITOR:
		props.append_array(_get_to_editor_cache_storage_properties())

	return props


func _get_position_from_to_properties() -> Array[Dictionary]:
	var pos_props: Array[Dictionary] = []

	pos_props.append({"name": "From", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	pos_props.append({"name": "from_reference", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node"})
	if from_reference == TransformReference.CUSTOM:
		pos_props.append({"name": "from_position_in", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
			"hint_string": "Pixels,Own Size,Parent Size,Viewport Size"})
		pos_props.append_array(_get_from_position_property())
	elif from_reference == TransformReference.SELF:
		pos_props.append({"name": "from_capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor"})
	elif from_reference == TransformReference.TARGET_NODE:
		pos_props.append({"name": "from_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D"})

	pos_props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	pos_props.append({"name": "to_reference", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node"})
	if to_reference == TransformReference.CUSTOM:
		pos_props.append({"name": "to_position_in", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
			"hint_string": "Pixels,Own Size,Parent Size,Viewport Size"})
		pos_props.append_array(_get_to_position_property())
	elif to_reference == TransformReference.SELF:
		pos_props.append({"name": "to_capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor"})
	elif to_reference == TransformReference.TARGET_NODE:
		pos_props.append({"name": "to_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D"})
	return pos_props


func _get_rotation_from_to_properties() -> Array[Dictionary]:
	var rot_props: Array[Dictionary] = []

	rot_props.append({"name": "From", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	rot_props.append({"name": "from_reference", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node"})
	if from_reference == TransformReference.CUSTOM:
		rot_props.append({"name": "from_rotation_degrees", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT})
	elif from_reference == TransformReference.SELF:
		rot_props.append({"name": "from_capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor"})
	elif from_reference == TransformReference.TARGET_NODE:
		rot_props.append({"name": "from_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D"})

	rot_props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	rot_props.append({"name": "to_reference", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node"})
	if to_reference == TransformReference.CUSTOM:
		rot_props.append({"name": "to_rotation_degrees", "type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT})
	elif to_reference == TransformReference.SELF:
		rot_props.append({"name": "to_capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor"})
	elif to_reference == TransformReference.TARGET_NODE:
		rot_props.append({"name": "to_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D"})
	return rot_props


func _get_scale_from_to_properties() -> Array[Dictionary]:
	var scale_props: Array[Dictionary] = []

	scale_props.append({"name": "From", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	scale_props.append({"name": "from_reference", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node"})
	if from_reference == TransformReference.CUSTOM:
		scale_props.append_array(_get_from_scale_property())
	elif from_reference == TransformReference.SELF:
		scale_props.append({"name": "from_capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor"})
	elif from_reference == TransformReference.TARGET_NODE:
		scale_props.append({"name": "from_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D"})

	scale_props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	scale_props.append({"name": "to_reference", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node"})
	if to_reference == TransformReference.CUSTOM:
		scale_props.append_array(_get_to_scale_property())
	elif to_reference == TransformReference.SELF:
		scale_props.append({"name": "to_capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor"})
	elif to_reference == TransformReference.TARGET_NODE:
		scale_props.append({"name": "to_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node2D"})
	return scale_props


func _get_pivot_properties() -> Array[Dictionary]:
	var pivot_props: Array[Dictionary] = [
		{"name": "pivot_mode", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
		"hint_string": "Auto Center,Inherit,Custom"},
	]
	if pivot_mode == PivotMode.CUSTOM:
		pivot_props.append_array(_get_custom_pivot_property())
	return pivot_props


# Virtual: return [{"name": "from_position", "type": TYPE_VECTOR2, ...}]
func _get_from_position_property() -> Array[Dictionary]: return []
func _get_to_position_property() -> Array[Dictionary]: return []
func _get_from_scale_property() -> Array[Dictionary]: return []
func _get_to_scale_property() -> Array[Dictionary]: return []
func _get_custom_pivot_property() -> Array[Dictionary]: return []
func _get_from_editor_cache_storage_properties() -> Array[Dictionary]: return []
func _get_to_editor_cache_storage_properties() -> Array[Dictionary]: return []


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"transform_target":        transform_target = value;        return true
		&"from_reference":          from_reference = value;          return true
		&"to_reference":            to_reference = value;            return true
		&"from_target_node":        from_target_node = value;        return true
		&"to_target_node":          to_target_node = value;          return true
		&"from_capture_at":         from_capture_at = value;         return true
		&"to_capture_at":           to_capture_at = value;           return true
		&"from_position_in":        from_position_in = value;        return true
		&"to_position_in":          to_position_in = value;          return true
		&"from_rotation_degrees":   from_rotation_degrees = value;   return true
		&"to_rotation_degrees":     to_rotation_degrees = value;     return true
		&"pivot_mode":              pivot_mode = value;              return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"transform_target":        return transform_target
		&"from_reference":          return from_reference
		&"to_reference":            return to_reference
		&"from_target_node":        return from_target_node
		&"to_target_node":          return to_target_node
		&"from_capture_at":         return from_capture_at
		&"to_capture_at":           return to_capture_at
		&"from_position_in":        return from_position_in
		&"to_position_in":          return to_position_in
		&"from_rotation_degrees":   return from_rotation_degrees
		&"to_rotation_degrees":     return to_rotation_degrees
		&"pivot_mode":              return pivot_mode
	return null


# =============================================================================
# INTERNAL STATE — non-typed flags (safe to store in base)
# =============================================================================

# True once _do_capture_base() has run for this target — cleared by _invalidate_base_cache()
var _has_base: bool = false
# True once _resolve_pivot() has run — cleared by _invalidate_base_cache()
var _pivot_resolved: bool = false

# Self-snapshot guard flags — cleared by _invalidate_base_cache()
var _has_from_self_position_snapshot: bool = false
var _has_from_self_rotation_snapshot: bool = false
var _has_from_self_scale_snapshot: bool = false
var _has_to_self_position_snapshot: bool = false
var _has_to_self_rotation_snapshot: bool = false
var _has_to_self_scale_snapshot: bool = false


# =============================================================================
# LIFECYCLE — shared skeleton, calls virtual typed hooks
# =============================================================================

func _on_host_ready(target: Node, host: Node) -> void:
	_host_node = host
	_do_capture_base(target)

	var uses_from_self := from_reference == TransformReference.SELF
	var uses_to_self   := to_reference   == TransformReference.SELF

	if uses_from_self and from_capture_at == CaptureAt.READY:
		match transform_target:
			TransformTarget.POSITION: _capture_from_self_position_snapshot(target)
			TransformTarget.ROTATION: _capture_from_self_rotation_snapshot(target)
			TransformTarget.SCALE:    _capture_from_self_scale_snapshot(target)

	if uses_to_self and to_capture_at == CaptureAt.READY:
		match transform_target:
			TransformTarget.POSITION: _capture_to_self_position_snapshot(target)
			TransformTarget.ROTATION: _capture_to_self_rotation_snapshot(target)
			TransformTarget.SCALE:    _capture_to_self_scale_snapshot(target)


func _on_editor_pre_save(target: Node) -> void:
	_do_update_editor_cache(target)


# Unlike Control (which has native pivot_offset), 2D must resolve pivot
# position and pre-compute compensation coords for rotation/scale.
func _on_animate_start(target: Node) -> void:
	if not _has_base:
		_do_capture_base(target)

	# Set contribution flags
	_contributes_position = (transform_target == TransformTarget.POSITION)
	_contributes_rotation = (transform_target == TransformTarget.ROTATION)
	_contributes_scale    = (transform_target == TransformTarget.SCALE)

	_do_resolve_from_to_refs()

	var uses_from_self := from_reference == TransformReference.SELF
	var uses_to_self   := to_reference   == TransformReference.SELF

	if uses_from_self and (from_capture_at == CaptureAt.TRIGGER or from_capture_at == CaptureAt.IN_EDITOR):
		match transform_target:
			TransformTarget.POSITION: _capture_from_self_position_snapshot(target)
			TransformTarget.ROTATION: _capture_from_self_rotation_snapshot(target)
			TransformTarget.SCALE:    _capture_from_self_scale_snapshot(target)

	if uses_to_self and (to_capture_at == CaptureAt.TRIGGER or to_capture_at == CaptureAt.IN_EDITOR):
		match transform_target:
			TransformTarget.POSITION: _capture_to_self_position_snapshot(target)
			TransformTarget.ROTATION: _capture_to_self_rotation_snapshot(target)
			TransformTarget.SCALE:    _capture_to_self_scale_snapshot(target)

	# Resolve pivot for rotation/scale (2D: position-compensation approach)
	if transform_target != TransformTarget.POSITION and not _pivot_resolved:
		_do_resolve_pivot(target)
		_pivot_resolved = true

	# Pre-compute fixed-pivot parent-space coords for rotation pivot compensation
	if transform_target == TransformTarget.ROTATION:
		_pre_compute_pivot_for_rotation()

	# Update position contribution if pivot is active
	if transform_target != TransformTarget.POSITION and _pivot_contributes_position():
		_contributes_position = true

	JuiceLogger.log_info(self, _get_domain_tag(),
			"animate_start: target=%s channels=pos:%s rot:%s scale:%s" % [
			TransformTarget.keys()[transform_target],
			_contributes_position, _contributes_rotation, _contributes_scale],
			debug_enabled)


# =============================================================================
# CORE LOGIC
# =============================================================================

func _apply_effect(progress: float, target: Node) -> void:
	match transform_target:
		TransformTarget.POSITION: _apply_position_effect(progress, target)
		TransformTarget.ROTATION: _apply_rotation_effect(progress, target)
		TransformTarget.SCALE:    _apply_scale_effect(progress, target)
	JuiceLogger.log_delta(self, _get_domain_tag(), progress,
			{"desired": _last_desired_pos if transform_target == TransformTarget.POSITION
				else (_last_desired_rot if transform_target == TransformTarget.ROTATION
				else _last_desired_scale),
			"pos": _pos_delta, "rot": _rot_delta, "scale": _scale_delta},
			target.name if target else "", debug_enabled)


func _restore_to_natural(_target: Node) -> void:
	JuiceLogger.log_info(self, _get_domain_tag(),
			"restore_to_natural: clearing pos=%s rot=%.4f scale=%s" % [
			_pos_delta, _rot_delta, _scale_delta], debug_enabled)
	_clear_deltas()


func _invalidate_base_cache() -> void:
	_has_base = false
	_pivot_resolved = false
	_has_from_self_position_snapshot = false
	_has_from_self_rotation_snapshot = false
	_has_from_self_scale_snapshot    = false
	_has_to_self_position_snapshot   = false
	_has_to_self_rotation_snapshot   = false
	_has_to_self_scale_snapshot      = false
	_invalidate_typed_refs()
	_clear_deltas()


func _get_interrupt_identity() -> Variant:
	return [get_script(), transform_target]


# =============================================================================
# VIRTUAL METHODS — implemented by concrete subclass
# =============================================================================

## Capture the base transform (position/rotation/scale) from the typed target node.
## Must populate _base_position, _base_rotation_radians, _base_scale (typed vars in concrete).
func _do_capture_base(target: Node) -> void: pass

## Update the editor cache vars from the target's current typed properties.
func _do_update_editor_cache(target: Node) -> void: pass

## Clear the from-editor cache typed vars (Vector2 for 2D/Control, Vector3 for 3D).
func _clear_from_editor_cache_typed() -> void: pass

## Clear the to-editor cache typed vars.
func _clear_to_editor_cache_typed() -> void: pass

## Capture self snapshot for position/rotation/scale at the appropriate moment.
func _capture_from_self_position_snapshot(target: Node) -> void: pass
func _capture_from_self_rotation_snapshot(target: Node) -> void: pass
func _capture_from_self_scale_snapshot(target: Node) -> void: pass
func _capture_to_self_position_snapshot(target: Node) -> void: pass
func _capture_to_self_rotation_snapshot(target: Node) -> void: pass
func _capture_to_self_scale_snapshot(target: Node) -> void: pass

## Infer and store the pivot point from the target's visual bounds.
func _do_resolve_pivot(target: Node) -> void: pass

## Pre-compute world-space fixed-pivot data for rotation compensation.
## Node2D: _fixed_pivot_parent = _base_position + _pivot_point.rotated(_base_rotation_radians)
func _pre_compute_pivot_for_rotation() -> void: pass

## Return true if the resolved pivot is non-zero (meaning position delta is needed).
func _pivot_contributes_position() -> bool: return false

## Apply position / rotation / scale effect at progress 0..1.
func _apply_position_effect(progress: float, target: Node) -> void: pass
func _apply_rotation_effect(progress: float, target: Node) -> void: pass
func _apply_scale_effect(progress: float, target: Node) -> void: pass

## Resolve and cache typed FROM/TO node references (e.g., to Node2D).
func _do_resolve_from_to_refs() -> void: pass

## Clear typed _from_ref / _to_ref caches.
func _invalidate_typed_refs() -> void: pass


# =============================================================================
# HELPERS — delta storage + size inference (all 2D transform effects)
# =============================================================================

## Reset all deltas to zero. Called by domain node when effect stops.
func _clear_deltas() -> void:
	_pos_delta = Vector2.ZERO
	_rot_delta = 0.0
	_scale_delta = Vector2.ZERO


## Return current deltas as a Dictionary keyed by Godot property names.
## Used by Sequencer contribution-tracking.
func _get_seq_contribution() -> Dictionary:
	var d := {}
	if _contributes_position:
		d["position"] = _pos_delta
	if _contributes_rotation:
		d["rotation"] = _rot_delta
	if _contributes_scale:
		d["scale"] = _scale_delta
	return d


func _convert_to_world_pixels(position: Vector2, position_in: int, target: Node2D) -> Vector2:
	match position_in:
		PositionIn.PIXELS:
			return position
		PositionIn.OWN_SIZE:
			var size := _infer_node2d_size(target)
			return Vector2(position.x * size.x, position.y * size.y)
		PositionIn.PARENT_SIZE:
			var size := _infer_parent_size(target)
			return Vector2(position.x * size.x, position.y * size.y)
		PositionIn.VIEWPORT_SIZE:
			var size := _get_viewport_size(target)
			return Vector2(position.x * size.x, position.y * size.y)
	return position


func _infer_parent_size(target: Node) -> Vector2:
	if target == null:
		return Vector2.ZERO
	var parent := target.get_parent()
	if parent is Control:
		return (parent as Control).size
	if parent is Node2D:
		return _infer_node2d_size(parent as Node2D)
	return Vector2.ZERO


# Node2D has no .size property, so we walk known subtypes (Sprite2D,
# AnimatedSprite2D, CollisionShape2D, Polygon2D) to estimate visual bounds.
# Falls back to recursive child-bounds merge for container-like nodes.
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

	# Container fallback
	var bounds := _infer_node2d_bounds_recursive(node)
	if bounds.size != Vector2.ZERO:
		return bounds.size

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

	return Rect2(-size * 0.5, size)
