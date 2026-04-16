## Animate position, rotation, or scale of a [Node3D] with tween-based easing and From/To configuration.
##
## Select a transform target (Position, Rotation, or Scale) and configure animations
## using CUSTOM values, SELF snapshots, or live TARGET_NODE references.

# ============================================================================
# WHAT: Animate position, rotation, or scale of a Node3D with tween-based easing.
# WHY: Replaces 3 separate scripts with one unified component.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Handle Control or Node2D targets — use TransformControl/2DJuiceEffect.
# DOES NOT: Handle procedural effects like shake or noise — use Shake/Noise effects.
#
# WRITE PATTERN: Delta-first. Each frame writes only the CHANGE in this effect's
#   contribution. Enables stacking with other effects and preserves external changes.
#
# FROM/TO MODEL:
# All transform types use a "From [source] To [destination]" model.
# Sources: CUSTOM (explicit value), SELF (snapshot), or TARGET_NODE (live).
#
# PIVOT (ROTATION):
# 3D rotation pivot is achieved by position compensation:
#   fixed_pivot = base_pos + base_basis * rotation_pivot_offset
#   new_pos = fixed_pivot - new_basis * rotation_pivot_offset
# rotation_pivot_offset is defined in local space at rest pose.
#
# PIVOT (SCALE):
# Scale pivot uses a LOCAL AABB center (AUTO_CENTER) or custom point.
# scale_pivot compensation: pos += pivot * (ONE - scale_ratio)
#
# ROTATION INTERPOLATION:
# Uses Quaternion slerp for smooth 3D rotation without gimbal lock.
# from_rotation and to_rotation are Vector3 Euler angles (degrees by default).
#
# SHARED FRAMEWORK:
# Enums, config vars (including rotation_pivot_offset, scale_custom_pivot),
# property list skeleton, and lifecycle live in Juice3DTransformEffect (domain base).
# This class provides only typed behavior.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name Transform3DJuiceEffect
extends Juice3DTransformEffect


# =============================================================================
# CONFIGURATION — typed vars (Vector3 types, only these live in concrete)
# =============================================================================

# Note: rotation_pivot_offset and scale_custom_pivot are in the domain base
# as Vector3 — Juice3DTransformEffect is 3D-only so that's safe.

# --- POSITION ---
var from_position: Vector3 = Vector3.ZERO
var to_position: Vector3 = Vector3.ZERO

# --- ROTATION (From/To: Vector3 Euler angles) ---
var from_rotation: Vector3 = Vector3.ZERO
var to_rotation: Vector3 = Vector3(0, 90, 0)

# --- SCALE ---
var from_scale: Vector3 = Vector3.ZERO
var to_scale: Vector3 = Vector3.ONE

# --- EDITOR CACHE (serialized only when capture_at == IN_EDITOR) ---
var _from_editor_cached_position: Vector3 = Vector3.ZERO
var _from_editor_cached_rotation: Vector3 = Vector3.ZERO
var _from_editor_cached_scale: Vector3 = Vector3.ONE
var _to_editor_cached_position: Vector3 = Vector3.ZERO
var _to_editor_cached_rotation: Vector3 = Vector3.ZERO
var _to_editor_cached_scale: Vector3 = Vector3.ONE


# =============================================================================
# CONDITIONAL EXPORT SYSTEM — typed property descriptors only
# Note: _get_rotation_from_to_properties() and _get_scale_pivot_properties()
# are OVERRIDDEN here to match original 3D inspector layout (rotation_unit
# inline, pivot appended at end of rotation section).
# =============================================================================

func _get_from_position_property() -> Array[Dictionary]:
	return [{"name": "from_position", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_DEFAULT}]

func _get_to_position_property() -> Array[Dictionary]:
	return [{"name": "to_position", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_DEFAULT}]

func _get_from_rotation_property() -> Array[Dictionary]:
	var arr: Array[Dictionary] = [{"name": "from_rotation", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_DEFAULT}]
	arr.append({"name": "rotation_unit", "type": TYPE_INT, "usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Degrees,Radians"})
	return arr

func _get_to_rotation_property() -> Array[Dictionary]:
	var arr: Array[Dictionary] = [{"name": "to_rotation", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_DEFAULT}]
	# Only show rotation_unit once — if from is CUSTOM it shows it already
	if from_reference != TransformReference.CUSTOM:
		arr.append({"name": "rotation_unit", "type": TYPE_INT, "usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Degrees,Radians"})
	return arr

func _get_from_scale_property() -> Array[Dictionary]:
	return [{"name": "from_scale", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_DEFAULT}]

func _get_to_scale_property() -> Array[Dictionary]:
	return [{"name": "to_scale", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_DEFAULT}]

func _get_from_editor_cache_storage_properties() -> Array[Dictionary]:
	return [
		{"name": "_from_editor_cached_position", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_STORAGE},
		{"name": "_from_editor_cached_rotation", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_STORAGE},
		{"name": "_from_editor_cached_scale",    "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_STORAGE},
	]

func _get_to_editor_cache_storage_properties() -> Array[Dictionary]:
	return [
		{"name": "_to_editor_cached_position", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_STORAGE},
		{"name": "_to_editor_cached_rotation", "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_STORAGE},
		{"name": "_to_editor_cached_scale",    "type": TYPE_VECTOR3, "usage": PROPERTY_USAGE_STORAGE},
	]


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"from_position":                from_position = value;                return true
		&"to_position":                  to_position = value;                  return true
		&"from_rotation":                from_rotation = value;                return true
		&"to_rotation":                  to_rotation = value;                  return true
		&"from_scale":                   from_scale = value;                   return true
		&"to_scale":                     to_scale = value;                     return true
		&"_from_editor_cached_position": _from_editor_cached_position = value; return true
		&"_from_editor_cached_rotation": _from_editor_cached_rotation = value; return true
		&"_from_editor_cached_scale":    _from_editor_cached_scale = value;    return true
		&"_to_editor_cached_position":   _to_editor_cached_position = value;   return true
		&"_to_editor_cached_rotation":   _to_editor_cached_rotation = value;   return true
		&"_to_editor_cached_scale":      _to_editor_cached_scale = value;      return true
	return super._set(property, value)


func _get(property: StringName) -> Variant:
	match property:
		&"from_position":                return from_position
		&"to_position":                  return to_position
		&"from_rotation":                return from_rotation
		&"to_rotation":                  return to_rotation
		&"from_scale":                   return from_scale
		&"to_scale":                     return to_scale
		&"_from_editor_cached_position": return _from_editor_cached_position
		&"_from_editor_cached_rotation": return _from_editor_cached_rotation
		&"_from_editor_cached_scale":    return _from_editor_cached_scale
		&"_to_editor_cached_position":   return _to_editor_cached_position
		&"_to_editor_cached_rotation":   return _to_editor_cached_rotation
		&"_to_editor_cached_scale":      return _to_editor_cached_scale
	return super._get(property)


# =============================================================================
# INTERNAL STATE — typed runtime vars
# =============================================================================

# Animation reference base — captured at animation start when target is at natural state.
var _base_position: Vector3 = Vector3.ZERO
var _base_transform: Transform3D = Transform3D.IDENTITY
var _base_euler: Vector3 = Vector3.ZERO
var _base_quat: Quaternion = Quaternion.IDENTITY
var _base_scale: Vector3 = Vector3.ONE

# Fixed pivot position in parent space (for rotation, computed once at start)
var _fixed_pivot_parent: Vector3 = Vector3.ZERO

# Resolved pivot point for scale (local space)
var _scale_pivot_point: Vector3 = Vector3.ZERO

# Resolved From/To target node references
var _from_ref: Node3D = null
var _to_ref: Node3D = null

# Self snapshots — typed (guard flags live in base)
var _from_self_position_snapshot: Vector3 = Vector3.ZERO
var _from_self_rotation_snapshot: Vector3 = Vector3.ZERO
var _from_self_scale_snapshot: Vector3 = Vector3.ONE
var _to_self_position_snapshot: Vector3 = Vector3.ZERO
var _to_self_rotation_snapshot: Vector3 = Vector3.ZERO
var _to_self_scale_snapshot: Vector3 = Vector3.ONE


# =============================================================================
# VIRTUAL HOOK IMPLEMENTATIONS
# =============================================================================

func _do_capture_base(target: Node) -> void:
	if _has_base:
		return
	var n3d := target as Node3D
	if n3d == null:
		_base_transform = Transform3D.IDENTITY
		_has_base = true
		return
	# Read from the ledger so we capture the natural state even if other Juice nodes
	# are active on the same target.
	_base_position = JuiceLedger.get_base(n3d, "position", n3d.position)
	var base_rotation: Vector3 = JuiceLedger.get_base(n3d, "rotation", n3d.rotation)
	_base_scale = JuiceLedger.get_base(n3d, "scale", n3d.scale)
	_base_transform = Transform3D(Basis.from_euler(base_rotation).scaled(_base_scale), _base_position)
	var ortho_basis := _base_transform.basis.orthonormalized()
	_base_euler = ortho_basis.get_euler()
	_base_quat = Quaternion(ortho_basis)
	# Pre-compute fixed pivot position in parent space for rotation compensation
	_fixed_pivot_parent = _base_transform.origin + _base_transform.basis * rotation_pivot_offset
	_has_base = true
	if debug_enabled:
		print("[Transform3D] Base captured: pos=%s, scale=%s" % [_base_position, _base_scale])


func _do_update_editor_cache(target: Node) -> void:
	if not Engine.is_editor_hint():
		return
	var n3d := target as Node3D
	if n3d == null:
		return
	if from_reference == TransformReference.SELF and from_capture_at == CaptureAt.IN_EDITOR:
		_from_editor_cached_position = n3d.position
		_from_editor_cached_rotation = n3d.rotation
		_from_editor_cached_scale = n3d.scale
	if to_reference == TransformReference.SELF and to_capture_at == CaptureAt.IN_EDITOR:
		_to_editor_cached_position = n3d.position
		_to_editor_cached_rotation = n3d.rotation
		_to_editor_cached_scale = n3d.scale
	if debug_enabled:
		print("[Transform3D] Editor cache updated: pos=%s, rot=%s, scale=%s" % [
			n3d.position, n3d.rotation, n3d.scale])


func _clear_from_editor_cache_typed() -> void:
	_from_editor_cached_position = Vector3.ZERO
	_from_editor_cached_rotation = Vector3.ZERO
	_from_editor_cached_scale = Vector3.ONE


func _clear_to_editor_cache_typed() -> void:
	_to_editor_cached_position = Vector3.ZERO
	_to_editor_cached_rotation = Vector3.ZERO
	_to_editor_cached_scale = Vector3.ONE


func _capture_from_self_position_snapshot(target: Node) -> void:
	if _has_from_self_position_snapshot:
		return
	# IN_EDITOR: prefer the per-target ledger base when available.
	# The ledger holds the natural position captured at ready-time — identical to the editor
	# state in all normal cases. This fixes the Sequencer multi-target stacking bug, where
	# one recipe effect has only one cache slot but each target needs its own natural position.
	# Fall back to the baked editor cache only when no ledger exists (very rare).
	if from_capture_at == CaptureAt.IN_EDITOR:
		var ledger_pos: Variant = _ledger_base_snapshot.get("position", null)
		_from_self_position_snapshot = ledger_pos if ledger_pos != null else _from_editor_cached_position
	else:
		var n3d := target as Node3D
		_from_self_position_snapshot = _ledger_base_snapshot.get("position", n3d.position if n3d else Vector3.ZERO)
	_has_from_self_position_snapshot = true
	if debug_enabled:
		print("[Transform3D] From Self position snapshot: %s (mode=%s)" % [
			_from_self_position_snapshot, CaptureAt.keys()[from_capture_at]])


func _capture_from_self_rotation_snapshot(target: Node) -> void:
	if _has_from_self_rotation_snapshot:
		return
	if from_capture_at == CaptureAt.IN_EDITOR:
		var ledger_rot: Variant = _ledger_base_snapshot.get("rotation", null)
		_from_self_rotation_snapshot = ledger_rot if ledger_rot != null else _from_editor_cached_rotation
	else:
		var n3d := target as Node3D
		_from_self_rotation_snapshot = _ledger_base_snapshot.get("rotation", n3d.rotation if n3d else Vector3.ZERO)
	_has_from_self_rotation_snapshot = true
	if debug_enabled:
		print("[Transform3D] From Self rotation snapshot: %s (mode=%s)" % [
			_from_self_rotation_snapshot, CaptureAt.keys()[from_capture_at]])


func _capture_from_self_scale_snapshot(target: Node) -> void:
	if _has_from_self_scale_snapshot:
		return
	if from_capture_at == CaptureAt.IN_EDITOR:
		var ledger_sc: Variant = _ledger_base_snapshot.get("scale", null)
		_from_self_scale_snapshot = ledger_sc if ledger_sc != null else _from_editor_cached_scale
	else:
		var n3d := target as Node3D
		_from_self_scale_snapshot = _ledger_base_snapshot.get("scale", n3d.scale if n3d else Vector3.ONE)
	_has_from_self_scale_snapshot = true
	if debug_enabled:
		print("[Transform3D] From Self scale snapshot: %s (mode=%s)" % [
			_from_self_scale_snapshot, CaptureAt.keys()[from_capture_at]])


func _capture_to_self_position_snapshot(target: Node) -> void:
	if _has_to_self_position_snapshot:
		return
	# IN_EDITOR: prefer the per-target ledger base when available (see _capture_from_self_position_snapshot).
	if to_capture_at == CaptureAt.IN_EDITOR:
		var ledger_pos: Variant = _ledger_base_snapshot.get("position", null)
		_to_self_position_snapshot = ledger_pos if ledger_pos != null else _to_editor_cached_position
	else:
		var n3d := target as Node3D
		_to_self_position_snapshot = _ledger_base_snapshot.get("position", n3d.position if n3d else Vector3.ZERO)
	_has_to_self_position_snapshot = true
	if debug_enabled:
		print("[Transform3D] To Self position snapshot: %s (mode=%s)" % [
			_to_self_position_snapshot, CaptureAt.keys()[to_capture_at]])


func _capture_to_self_rotation_snapshot(target: Node) -> void:
	if _has_to_self_rotation_snapshot:
		return
	if to_capture_at == CaptureAt.IN_EDITOR:
		var ledger_rot: Variant = _ledger_base_snapshot.get("rotation", null)
		_to_self_rotation_snapshot = ledger_rot if ledger_rot != null else _to_editor_cached_rotation
	else:
		var n3d := target as Node3D
		_to_self_rotation_snapshot = _ledger_base_snapshot.get("rotation", n3d.rotation if n3d else Vector3.ZERO)
	_has_to_self_rotation_snapshot = true
	if debug_enabled:
		print("[Transform3D] To Self rotation snapshot: %s (mode=%s)" % [
			_to_self_rotation_snapshot, CaptureAt.keys()[to_capture_at]])


func _capture_to_self_scale_snapshot(target: Node) -> void:
	if _has_to_self_scale_snapshot:
		return
	if to_capture_at == CaptureAt.IN_EDITOR:
		var ledger_sc: Variant = _ledger_base_snapshot.get("scale", null)
		_to_self_scale_snapshot = ledger_sc if ledger_sc != null else _to_editor_cached_scale
	else:
		var n3d := target as Node3D
		_to_self_scale_snapshot = _ledger_base_snapshot.get("scale", n3d.scale if n3d else Vector3.ONE)
	_has_to_self_scale_snapshot = true
	if debug_enabled:
		print("[Transform3D] To Self scale snapshot: %s (mode=%s)" % [
			_to_self_scale_snapshot, CaptureAt.keys()[to_capture_at]])


func _scale_pivot_point_is_nonzero() -> bool:
	return _scale_pivot_point != Vector3.ZERO


func _do_resolve_scale_pivot(target: Node) -> void:
	var n3d := target as Node3D
	match scale_pivot_mode:
		PivotMode.AUTO_CENTER:
			if n3d:
				var bounds := _infer_node3d_local_bounds(n3d)
				if bounds.size == Vector3.ZERO:
					bounds = _infer_node3d_bounds_recursive(n3d)
				_scale_pivot_point = bounds.get_center() if bounds.size != Vector3.ZERO else Vector3.ZERO
				if debug_enabled:
					print("[Transform3D] Auto-center scale pivot: bounds=%s, center=%s" % [bounds, _scale_pivot_point])
			else:
				_scale_pivot_point = Vector3.ZERO
		PivotMode.INHERIT:
			_scale_pivot_point = Vector3.ZERO
		PivotMode.CUSTOM:
			_scale_pivot_point = scale_custom_pivot


func _apply_position_effect(progress: float, target: Node) -> void:
	var n3d := target as Node3D
	if n3d == null:
		return
	var from_value := _resolve_from_position(n3d)
	var to_value   := _resolve_to_position(n3d)
	_pos_delta = from_value.lerp(to_value, progress) - _base_position


func _apply_rotation_effect(progress: float, target: Node) -> void:
	var n3d := target as Node3D
	if n3d == null:
		return
	var from_quat := _resolve_from_rotation_quat(n3d)
	var to_quat   := _resolve_to_rotation_quat(n3d)
	var current_quat := from_quat.slerp(to_quat, progress)
	var desired_euler := Basis(current_quat).get_euler()
	_rot_delta = desired_euler - _base_euler
	# Pivot compensation
	if rotation_pivot_offset != Vector3.ZERO:
		var new_basis := Basis(current_quat)
		_pos_delta = (_fixed_pivot_parent - new_basis * rotation_pivot_offset) - _base_position


func _apply_scale_effect(progress: float, target: Node) -> void:
	var n3d := target as Node3D
	if n3d == null:
		return
	var from_value := _resolve_from_scale(n3d)
	var to_value   := _resolve_to_scale(n3d)
	var desired_absolute := from_value.lerp(to_value, progress)
	_scale_delta = desired_absolute - _base_scale
	if _scale_pivot_point != Vector3.ZERO:
		var scale_ratio := desired_absolute / _base_scale
		_pos_delta = _scale_pivot_point * (Vector3.ONE - scale_ratio)


func _do_resolve_from_to_refs() -> void:
	_from_ref = null
	_to_ref = null
	if from_reference == TransformReference.TARGET_NODE:
		_from_ref = _resolve_node_path_to_node3d(from_target_node, "from_target_node")
	if to_reference == TransformReference.TARGET_NODE:
		_to_ref = _resolve_node_path_to_node3d(to_target_node, "to_target_node")


func _invalidate_typed_refs() -> void:
	_from_ref = null
	_to_ref = null


# =============================================================================
# POSITION EFFECT — internal resolvers
# =============================================================================

func _resolve_from_position(n3d: Node3D) -> Vector3:
	match from_reference:
		TransformReference.CUSTOM:
			return _base_position + _convert_to_world_units(from_position, from_position_in, n3d)
		TransformReference.SELF:
			return _from_self_position_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_position(_from_ref, n3d)
	return _base_position


func _resolve_to_position(n3d: Node3D) -> Vector3:
	match to_reference:
		TransformReference.CUSTOM:
			return _base_position + _convert_to_world_units(to_position, to_position_in, n3d)
		TransformReference.SELF:
			return _to_self_position_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_position(_to_ref, n3d)
	return _base_position


func _get_ref_local_position(ref: Node3D, animated: Node3D) -> Vector3:
	var parent := animated.get_parent()
	if parent is Node3D:
		return (parent as Node3D).global_transform.affine_inverse() * ref.global_position
	return ref.global_position


# =============================================================================
# ROTATION EFFECT — internal resolvers (Quaternion slerp)
# =============================================================================

func _resolve_from_rotation_quat(animated: Node3D) -> Quaternion:
	match from_reference:
		TransformReference.CUSTOM:
			var offset_rad := _rotation_to_radians(from_rotation)
			return _base_quat * Quaternion.from_euler(offset_rad)
		TransformReference.SELF:
			return Quaternion.from_euler(_from_self_rotation_snapshot)
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_rotation_quat(_from_ref, animated)
	return _base_quat


func _resolve_to_rotation_quat(animated: Node3D) -> Quaternion:
	match to_reference:
		TransformReference.CUSTOM:
			var offset_rad := _rotation_to_radians(to_rotation)
			return _base_quat * Quaternion.from_euler(offset_rad)
		TransformReference.SELF:
			return Quaternion.from_euler(_to_self_rotation_snapshot)
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_rotation_quat(_to_ref, animated)
	return _base_quat


func _rotation_to_radians(rot: Vector3) -> Vector3:
	if rotation_unit == RotationUnit.DEGREES:
		return Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))
	return rot


func _get_ref_local_rotation_quat(ref: Node3D, animated: Node3D) -> Quaternion:
	var ref_global_basis := ref.global_transform.basis.orthonormalized()
	var parent_basis := Basis.IDENTITY
	if animated.get_parent() is Node3D:
		parent_basis = (animated.get_parent() as Node3D).global_transform.basis.orthonormalized()
	var local_basis := parent_basis.inverse() * ref_global_basis
	return Quaternion(local_basis)


# =============================================================================
# SCALE EFFECT — internal resolvers
# =============================================================================

func _resolve_from_scale(n3d: Node3D) -> Vector3:
	match from_reference:
		TransformReference.CUSTOM:
			return from_scale
		TransformReference.SELF:
			return _from_self_scale_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_scale(_from_ref, n3d)
	return _base_scale


func _resolve_to_scale(n3d: Node3D) -> Vector3:
	match to_reference:
		TransformReference.CUSTOM:
			return to_scale
		TransformReference.SELF:
			return _to_self_scale_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_scale(_to_ref, n3d)
	return _base_scale


func _get_ref_local_scale(ref: Node3D, animated: Node3D) -> Vector3:
	var ref_global_scale := ref.global_transform.basis.get_scale()
	var parent_scale := Vector3.ONE
	var parent := animated.get_parent()
	if parent is Node3D:
		parent_scale = (parent as Node3D).global_transform.basis.get_scale()
	return ref_global_scale / parent_scale


# =============================================================================
# HELPERS
# =============================================================================

func _resolve_node_path_to_node3d(path: NodePath, path_name: String) -> Node3D:
	if path.is_empty():
		return null
	if _host_node == null or not is_instance_valid(_host_node):
		if debug_enabled:
			push_warning("[Transform3D] Cannot resolve %s — no host node" % path_name)
		return null
	var resolved := _host_node.get_node_or_null(path)
	if resolved == null:
		if debug_enabled:
			push_warning("[Transform3D] %s path '%s' could not be resolved" % [path_name, path])
		return null
	if not (resolved is Node3D):
		if debug_enabled:
			push_warning("[Transform3D] %s '%s' is not a Node3D (is %s)" % [path_name, resolved.name, resolved.get_class()])
		return null
	return resolved as Node3D
