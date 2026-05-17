## Intermediate base for 3D-domain effects that produce transform deltas.
## Extends [Juice3DEffectBase] and adds the complete Transform From/To framework.
## Concrete Transform effects (e.g., Transform3DJuiceEffect, future BounceEffect)
## only need to implement the typed virtual hooks below.

# ============================================================================
# WHAT: Domain base for all 3D transform effects (position/rotation/scale).
# WHY:  Consolidates shared From/To framework — enums, config, property list,
#       lifecycle skeleton, and non-typed state — so concrete effects provide
#       only the typed per-domain code (capture, apply, resolve, pivot).
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Apply any effect behavior — concrete subclasses implement virtuals.
# DOES NOT: Handle Control or Node2D targets.
# NOTES:
#   3D rotation uses Quaternion slerp (Basis). Rotation pivot pre-computed in
#   _do_capture_base(). Scale pivot resolved at first _on_animate_start().
#   Rotation uses from_rotation: Vector3 (Euler degrees), not from_rotation_degrees: float.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBase3D.svg")
class_name Juice3DTransformEffect
extends Juice3DEffectBase


# =============================================================================
# DELTA CONTRIBUTION STORAGE
# =============================================================================
# Effects compute deltas (offsets from natural state) and store them here.
# The domain node (Juice3D) reads these after tick and writes ONCE.
# Effects NEVER write to the target directly.

## Which channels this effect contributes to. Set in _on_animate_start().
var _contributes_position: bool = false
var _contributes_rotation: bool = false
var _contributes_scale: bool = false

## Current delta values. Updated by _apply_effect() each tick.
## Position: offset from natural position (Vector3)
## Rotation: offset from natural rotation (Vector3, radians per axis)
## Scale: offset from natural scale (Vector3) — additive, not multiplicative
var _pos_delta: Vector3 = Vector3.ZERO
var _rot_delta: Vector3 = Vector3.ZERO
var _scale_delta: Vector3 = Vector3.ZERO

# Last desired_absolute values — set by concrete _apply_*_effect() before subtraction.
# Logged as chain intermediate: if delta is wrong but desired is correct → bug is in base capture.
var _last_desired_pos: Vector3 = Vector3.ZERO
var _last_desired_rot: Vector3 = Vector3.ZERO
var _last_desired_scale: Vector3 = Vector3.ZERO


# =============================================================================
# ENUMS — shared by all 3D transform effects
# =============================================================================

## Which transform property to animate
enum TransformTarget {
	POSITION,  ## Animate Node3D.position
	ROTATION,  ## Animate Node3D.rotation (Euler XYZ, degrees or radians)
	SCALE      ## Animate Node3D.scale
}

## Pivot strategy for rotation and scale (3D)
enum PivotMode {
	AUTO_CENTER,  ## Infer visual center from AABB
	INHERIT,      ## Pivot from node origin (no compensation)
	CUSTOM        ## rotation_pivot_offset or scale_custom_pivot (Vector3)
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

## How to interpret custom position values (3D)
enum PositionIn3D {
	WORLD_UNITS,  ## Absolute world units
	OWN_SIZE,     ## Multiple of object's own AABB
	PARENT_SIZE   ## Multiple of parent's AABB
}

# Note: RotationUnit (DEGREES/RADIANS) is inherited from JuiceEffectBase.

# =============================================================================
# CONFIGURATION — non-typed, shared by all 3D transform effects
# Note: rotation_pivot_offset and scale_custom_pivot are Vector3 — kept here
# since Juice3DTransformEffect is 3D-only. No cross-domain vector ambiguity.
# =============================================================================

var transform_target: int = TransformTarget.POSITION:
	set(value):
		transform_target = value
		notify_property_list_changed()

# Shared pivot mode for effects using simple pivot selection (Noise/Shake/Progress).
# Transform3D effects use scale_pivot_mode + rotation_pivot_offset instead.
var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()

func _init() -> void:
	_subclass_owns_effect_group = true

## Set to true in any direct subclass that has its own complete _get_property_list().
## Prevents double "Effect" GROUP duplication from Godot auto-combining the chain.
var _leaf_owns_layout: bool = false

var from_reference: int = TransformReference.SELF:
	set(value):
		from_reference = value
		notify_property_list_changed()

var to_reference: int = TransformReference.CUSTOM:
	set(value):
		to_reference = value
		notify_property_list_changed()

var from_target_node: NodePath
var to_target_node: NodePath

var from_capture_at: int = CaptureAt.TRIGGER:
	set(value):
		from_capture_at = value
		if value != CaptureAt.IN_EDITOR:
			_clear_from_editor_cache_typed()
		elif Engine.is_editor_hint():
			_do_update_editor_cache(null)
		notify_property_list_changed()

var to_capture_at: int = CaptureAt.TRIGGER:
	set(value):
		to_capture_at = value
		if value != CaptureAt.IN_EDITOR:
			_clear_to_editor_cache_typed()
		elif Engine.is_editor_hint():
			_do_update_editor_cache(null)
		notify_property_list_changed()

# Position unit selector (int)
var from_position_in: int = PositionIn3D.WORLD_UNITS
var to_position_in: int = PositionIn3D.WORLD_UNITS

# Rotation unit selector (3D only)
var rotation_unit: int = RotationUnit.DEGREES:
	set(value):
		rotation_unit = value
		notify_property_list_changed()

# Scale pivot mode — uses PivotMode enum (same AUTO_CENTER/INHERIT/CUSTOM values)
var scale_pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		scale_pivot_mode = value
		notify_property_list_changed()

# Rotation pivot: offset from node origin in local space (Vector3, always 3D)
var rotation_pivot_offset: Vector3 = Vector3.ZERO

# Scale custom pivot in local space (Vector3, always 3D)
var scale_custom_pivot: Vector3 = Vector3.ZERO


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
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
			# rotation_pivot_offset is appended inside _get_rotation_from_to_properties()
			props.append_array(_get_rotation_from_to_properties())
		TransformTarget.SCALE:
			props.append_array(_get_scale_from_to_properties())
			props.append_array(_get_scale_pivot_properties())

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
			"hint_string": "World Units,Own Size,Parent Size"})
		pos_props.append_array(_get_from_position_property())
	elif from_reference == TransformReference.SELF:
		pos_props.append({"name": "from_capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor"})
	elif from_reference == TransformReference.TARGET_NODE:
		pos_props.append({"name": "from_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node3D"})

	pos_props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	pos_props.append({"name": "to_reference", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node"})
	if to_reference == TransformReference.CUSTOM:
		pos_props.append({"name": "to_position_in", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
			"hint_string": "World Units,Own Size,Parent Size"})
		pos_props.append_array(_get_to_position_property())
	elif to_reference == TransformReference.SELF:
		pos_props.append({"name": "to_capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor"})
	elif to_reference == TransformReference.TARGET_NODE:
		pos_props.append({"name": "to_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node3D"})
	return pos_props


func _get_rotation_from_to_properties() -> Array[Dictionary]:
	var rot_props: Array[Dictionary] = []

	rot_props.append({"name": "From", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	rot_props.append({"name": "from_reference", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node"})
	if from_reference == TransformReference.CUSTOM:
		rot_props.append_array(_get_from_rotation_property())
	elif from_reference == TransformReference.SELF:
		rot_props.append({"name": "from_capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor"})
	elif from_reference == TransformReference.TARGET_NODE:
		rot_props.append({"name": "from_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node3D"})

	rot_props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	rot_props.append({"name": "to_reference", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
		"hint_string": "Custom,Self,Target Node"})
	if to_reference == TransformReference.CUSTOM:
		rot_props.append_array(_get_to_rotation_property())
	elif to_reference == TransformReference.SELF:
		rot_props.append({"name": "to_capture_at", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
			"hint_string": "Trigger,Ready,In Editor"})
	elif to_reference == TransformReference.TARGET_NODE:
		rot_props.append({"name": "to_target_node", "type": TYPE_NODE_PATH,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			"hint_string": "Node3D"})
	# Rotation pivot offset (always shown for rotation, Vector3 in 3D)
	rot_props.append({"name": "Pivot", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
	rot_props.append({"name": "rotation_pivot_offset", "type": TYPE_VECTOR3,
		"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_NONE})
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
			"hint_string": "Node3D"})

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
			"hint_string": "Node3D"})
	return scale_props


func _get_rotation_pivot_properties() -> Array[Dictionary]:
	# 3D rotation pivot uses an explicit offset vector (always shown)
	return [{
		"name": "rotation_pivot_offset", "type": TYPE_VECTOR3,
		"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_NONE
	}]


func _get_scale_pivot_properties() -> Array[Dictionary]:
	var pivot_props: Array[Dictionary] = [
		{"name": "scale_pivot_mode", "type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_ENUM,
		"hint_string": "Auto Center,Inherit,Custom"},
	]
	if scale_pivot_mode == PivotMode.CUSTOM:
		pivot_props.append({"name": "scale_custom_pivot", "type": TYPE_VECTOR3,
			"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_NONE})
	return pivot_props


# Virtual: return single-element array with typed property dict
func _get_from_position_property() -> Array[Dictionary]: return []
func _get_to_position_property() -> Array[Dictionary]: return []
func _get_from_rotation_property() -> Array[Dictionary]: return []
func _get_to_rotation_property() -> Array[Dictionary]: return []
func _get_from_scale_property() -> Array[Dictionary]: return []
func _get_to_scale_property() -> Array[Dictionary]: return []
func _get_from_editor_cache_storage_properties() -> Array[Dictionary]: return []
func _get_to_editor_cache_storage_properties() -> Array[Dictionary]: return []


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"transform_target":       transform_target = value;       return true
		&"from_reference":         from_reference = value;         return true
		&"to_reference":           to_reference = value;           return true
		&"from_target_node":       from_target_node = value;       return true
		&"to_target_node":         to_target_node = value;         return true
		&"from_capture_at":        from_capture_at = value;        return true
		&"to_capture_at":          to_capture_at = value;          return true
		&"from_position_in":       from_position_in = value;       return true
		&"to_position_in":         to_position_in = value;         return true
		&"rotation_unit":          rotation_unit = value;          return true
		&"scale_pivot_mode":       scale_pivot_mode = value;       return true
		&"rotation_pivot_offset":  rotation_pivot_offset = value;  return true
		&"scale_custom_pivot":     scale_custom_pivot = value;     return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"transform_target":      return transform_target
		&"from_reference":        return from_reference
		&"to_reference":          return to_reference
		&"from_target_node":      return from_target_node
		&"to_target_node":        return to_target_node
		&"from_capture_at":       return from_capture_at
		&"to_capture_at":         return to_capture_at
		&"from_position_in":      return from_position_in
		&"to_position_in":        return to_position_in
		&"rotation_unit":         return rotation_unit
		&"scale_pivot_mode":      return scale_pivot_mode
		&"rotation_pivot_offset": return rotation_pivot_offset
		&"scale_custom_pivot":    return scale_custom_pivot
	return null


# =============================================================================
# INTERNAL STATE — non-typed flags (safe to store in base)
# =============================================================================

# True once _do_capture_base() has run — cleared by _invalidate_base_cache()
var _has_base: bool = false
# True once _resolve_scale_pivot() has run — cleared by _invalidate_base_cache()
# Rotation pivot is pre-computed in _do_capture_base() for 3D.
var _scale_pivot_resolved: bool = false

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


# 3D splits pivot handling: rotation pivot is pre-computed during
# _do_capture_base(), scale pivot is resolved lazily here on first start.
func _on_animate_start(target: Node) -> void:
	if not _has_base:
		_do_capture_base(target)

	# Set contribution flags
	_contributes_position = (transform_target == TransformTarget.POSITION)
	_contributes_rotation = (transform_target == TransformTarget.ROTATION)
	_contributes_scale    = (transform_target == TransformTarget.SCALE)

	# Check if rotation/scale pivots contribute position
	if transform_target == TransformTarget.ROTATION and rotation_pivot_offset != Vector3.ZERO:
		_contributes_position = true
	if transform_target == TransformTarget.SCALE and _scale_pivot_point_is_nonzero():
		_contributes_position = true

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

	# Resolve scale pivot if needed (rotation pivot pre-computed in _do_capture_base)
	if transform_target == TransformTarget.SCALE and not _scale_pivot_resolved:
		_do_resolve_scale_pivot(target)
		_scale_pivot_resolved = true

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
			"restore_to_natural: clearing pos=%s rot=%s scale=%s" % [
			_pos_delta, _rot_delta, _scale_delta], debug_enabled)
	_clear_deltas()


func _invalidate_base_cache() -> void:
	_has_base = false
	_scale_pivot_resolved = false
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

## Capture the base transform from the typed Node3D target.
## Also pre-computes rotation pivot (_fixed_pivot_parent = origin + basis * rotation_pivot_offset).
func _do_capture_base(target: Node) -> void: pass

## Update editor cache from the target's current state.
func _do_update_editor_cache(target: Node) -> void: pass

## Clear typed from-editor cache vars (Vector3 for 3D).
func _clear_from_editor_cache_typed() -> void: pass

## Clear typed to-editor cache vars.
func _clear_to_editor_cache_typed() -> void: pass

## Capture self snapshot for position/rotation/scale.
func _capture_from_self_position_snapshot(target: Node) -> void: pass
func _capture_from_self_rotation_snapshot(target: Node) -> void: pass
func _capture_from_self_scale_snapshot(target: Node) -> void: pass
func _capture_to_self_position_snapshot(target: Node) -> void: pass
func _capture_to_self_rotation_snapshot(target: Node) -> void: pass
func _capture_to_self_scale_snapshot(target: Node) -> void: pass

## True if _scale_pivot_point != Vector3.ZERO (after previous resolution).
func _scale_pivot_point_is_nonzero() -> bool: return false

## Infer and store scale pivot from the target's AABB.
func _do_resolve_scale_pivot(target: Node) -> void: pass

## Apply position / rotation / scale effect at progress 0..1.
func _apply_position_effect(progress: float, target: Node) -> void: pass
func _apply_rotation_effect(progress: float, target: Node) -> void: pass
func _apply_scale_effect(progress: float, target: Node) -> void: pass

## Resolve and cache typed FROM/TO node references (Node3D).
func _do_resolve_from_to_refs() -> void: pass

## Clear typed ref caches.
func _invalidate_typed_refs() -> void: pass


# =============================================================================
# HELPERS — delta storage + size inference (all 3D transform effects)
# =============================================================================

## Reset all deltas to zero. Called by domain node when effect stops.
func _clear_deltas() -> void:
	_pos_delta = Vector3.ZERO
	_rot_delta = Vector3.ZERO
	_scale_delta = Vector3.ZERO


## Return current deltas as a Dictionary keyed by Godot property names.
func _get_seq_contribution() -> Dictionary:
	var d := {}
	if _contributes_position:
		d["position"] = _pos_delta
	if _contributes_rotation:
		d["rotation"] = _rot_delta
	if _contributes_scale:
		d["scale"] = _scale_delta
	return d


func _convert_to_world_units(pos: Vector3, position_in: int, target: Node3D) -> Vector3:
	match position_in:
		PositionIn3D.WORLD_UNITS:
			return pos
		PositionIn3D.OWN_SIZE:
			var size := _infer_node3d_size(target)
			return Vector3(pos.x * size.x, pos.y * size.y, pos.z * size.z)
		PositionIn3D.PARENT_SIZE:
			var size := _infer_parent_size(target)
			return Vector3(pos.x * size.x, pos.y * size.y, pos.z * size.z)
	return pos


func _infer_parent_size(target: Node) -> Vector3:
	if target == null:
		return Vector3.ZERO
	var parent := target.get_parent()
	if parent is Node3D:
		return _infer_node3d_size(parent as Node3D)
	return Vector3.ZERO


# Estimates visual size from MeshInstance3D AABB, CollisionShape3D geometry,
# or any node exposing get_aabb(). Falls back to recursive child-bounds merge.
func _infer_node3d_size(node: Node3D) -> Vector3:
	if node == null:
		return Vector3.ZERO

	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var aabb := mi.mesh.get_aabb()
			var sc := mi.global_transform.basis.get_scale()
			return Vector3(absf(sc.x) * aabb.size.x, absf(sc.y) * aabb.size.y, absf(sc.z) * aabb.size.z)

	if node is CollisionShape3D:
		var col := node as CollisionShape3D
		if col.shape != null:
			var shape := col.shape
			if shape is BoxShape3D:
				return (shape as BoxShape3D).size
			if shape is SphereShape3D:
				var r := (shape as SphereShape3D).radius
				return Vector3(r * 2.0, r * 2.0, r * 2.0)
			if shape is CapsuleShape3D:
				var cap := shape as CapsuleShape3D
				return Vector3(cap.radius * 2.0, cap.height + cap.radius * 2.0, cap.radius * 2.0)

	if node.has_method("get_aabb"):
		var aabb_var: Variant = node.call("get_aabb")
		if aabb_var is AABB:
			var aabb := aabb_var as AABB
			var sc := node.global_transform.basis.get_scale()
			return Vector3(absf(sc.x) * aabb.size.x, absf(sc.y) * aabb.size.y, absf(sc.z) * aabb.size.z)

	# Container fallback
	var bounds := _infer_node3d_bounds_recursive(node)
	if bounds.size != Vector3.ZERO:
		return bounds.size

	return Vector3.ZERO


func _infer_node3d_bounds_recursive(root: Node3D) -> AABB:
	var has_any: bool = false
	var combined := AABB(Vector3.ZERO, Vector3.ZERO)

	for child in root.get_children():
		if not (child is Node3D):
			continue
		var child_n3d := child as Node3D
		var child_local := _infer_node3d_local_bounds(child_n3d)
		if child_local.size != Vector3.ZERO:
			child_local.position += child_n3d.position
			if not has_any:
				has_any = true
				combined = child_local
			else:
				combined = combined.merge(child_local)

		var grandchild_bounds := _infer_node3d_bounds_recursive(child_n3d)
		if grandchild_bounds.size != Vector3.ZERO:
			grandchild_bounds.position += child_n3d.position
			if not has_any:
				has_any = true
				combined = grandchild_bounds
			else:
				combined = combined.merge(grandchild_bounds)

	if not has_any:
		return AABB(Vector3.ZERO, Vector3.ZERO)
	return combined


func _infer_node3d_local_bounds(node: Node3D) -> AABB:
	var size := Vector3.ZERO

	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var aabb := mi.mesh.get_aabb()
			var sc := mi.transform.basis.get_scale()
			size = Vector3(absf(sc.x) * aabb.size.x, absf(sc.y) * aabb.size.y, absf(sc.z) * aabb.size.z)

	elif node is CollisionShape3D:
		var col := node as CollisionShape3D
		if col.shape != null:
			var shape := col.shape
			if shape is BoxShape3D:
				size = (shape as BoxShape3D).size
			elif shape is SphereShape3D:
				var r := (shape as SphereShape3D).radius
				size = Vector3(r * 2.0, r * 2.0, r * 2.0)
			elif shape is CapsuleShape3D:
				var cap := shape as CapsuleShape3D
				size = Vector3(cap.radius * 2.0, cap.height + cap.radius * 2.0, cap.radius * 2.0)

	elif node.has_method("get_aabb"):
		var aabb_var: Variant = node.call("get_aabb")
		if aabb_var is AABB:
			var aabb := aabb_var as AABB
			var sc := node.transform.basis.get_scale()
			size = Vector3(absf(sc.x) * aabb.size.x, absf(sc.y) * aabb.size.y, absf(sc.z) * aabb.size.z)

	if size == Vector3.ZERO:
		return AABB(Vector3.ZERO, Vector3.ZERO)

	return AABB(-size * 0.5, size)


# Returns the local-space AABB center of node, with recursive child fallback.
# Used by all 3D effects to resolve AUTO_CENTER pivot.
func _infer_node3d_center(node: Node3D) -> Vector3:
	var bounds := _infer_node3d_local_bounds(node)
	if bounds.size == Vector3.ZERO:
		bounds = _infer_node3d_bounds_recursive(node)
	return bounds.get_center() if bounds.size != Vector3.ZERO else Vector3.ZERO
