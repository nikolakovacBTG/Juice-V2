## Animate position, rotation, or scale of a [Control] with tween-based easing and From/To configuration.
##
## Select a transform target (Position, Rotation, or Scale) and configure animations
## using CUSTOM values, SELF snapshots, or live TARGET_NODE references.

# ============================================================================
# WHAT: Animate position, rotation, or scale of a Control with tween-based easing.
# WHY: Replaces 3 separate scripts with one unified component.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Handle Node2D or Node3D targets — use Transform2D/3DJuiceEffect.
# DOES NOT: Handle procedural effects like shake or noise — use Shake/Noise effects.
#
# WRITE PATTERN: Delta-first. Each frame writes only the CHANGE in this effect's
#   contribution. Enables stacking with other effects and preserves external changes.
#
# FROM/TO MODEL:
# All transform types use a "From [source] To [destination]" model.
# Sources: CUSTOM (explicit value), SELF (snapshot), or TARGET_NODE (live).
#
# PIVOT (ROTATION and SCALE):
# Control nodes have a native pivot_offset property. This effect writes
# pivot_offset once at animation start based on pivot_mode (AUTO_CENTER
# uses size/2, CUSTOM uses a size-fraction vector). No position compensation
# is required for Control rotation/scale — the engine handles it natively.
#
# SHARED FRAMEWORK:
# All enums, config vars, property list, and lifecycle skeleton live in
# JuiceControlTransformEffect (domain base). This class provides only typed behavior.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name TransformControlJuiceEffect
extends JuiceControlTransformEffect


# =============================================================================
# CONFIGURATION — typed vars (Vector2 types, only these live in concrete)
# =============================================================================

# --- POSITION ---
var from_position: Vector2 = Vector2.ZERO
var to_position: Vector2 = Vector2.ZERO

# --- SCALE ---
var from_scale: Vector2 = Vector2.ZERO
var to_scale: Vector2 = Vector2.ONE

# --- PIVOT ---
## Custom pivot as fraction of the Control's size (x: 0=left, 1=right; y: 0=top, 1=bottom)
var custom_pivot: Vector2 = Vector2(0.5, 0.5)

# --- EDITOR CACHE (serialized only when capture_at == IN_EDITOR) ---
var _from_editor_cached_position: Vector2 = Vector2.ZERO
var _from_editor_cached_rotation: float = 0.0
var _from_editor_cached_scale: Vector2 = Vector2.ONE
var _to_editor_cached_position: Vector2 = Vector2.ZERO
var _to_editor_cached_rotation: float = 0.0
var _to_editor_cached_scale: Vector2 = Vector2.ONE


# =============================================================================
# CONDITIONAL EXPORT SYSTEM — typed property descriptors only
# =============================================================================

func _get_from_position_property() -> Array[Dictionary]:
	return [{"name": "from_position", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_DEFAULT}]

func _get_to_position_property() -> Array[Dictionary]:
	return [{"name": "to_position", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_DEFAULT}]

func _get_from_scale_property() -> Array[Dictionary]:
	return [{"name": "from_scale", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_DEFAULT}]

func _get_to_scale_property() -> Array[Dictionary]:
	return [{"name": "to_scale", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_DEFAULT}]

func _get_custom_pivot_property() -> Array[Dictionary]:
	return [{"name": "custom_pivot", "type": TYPE_VECTOR2,
		"usage": PROPERTY_USAGE_DEFAULT, "hint": PROPERTY_HINT_NONE}]

func _get_from_editor_cache_storage_properties() -> Array[Dictionary]:
	return [
		{"name": "_from_editor_cached_position", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_STORAGE},
		{"name": "_from_editor_cached_rotation", "type": TYPE_FLOAT,   "usage": PROPERTY_USAGE_STORAGE},
		{"name": "_from_editor_cached_scale",    "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_STORAGE},
	]

func _get_to_editor_cache_storage_properties() -> Array[Dictionary]:
	return [
		{"name": "_to_editor_cached_position", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_STORAGE},
		{"name": "_to_editor_cached_rotation", "type": TYPE_FLOAT,   "usage": PROPERTY_USAGE_STORAGE},
		{"name": "_to_editor_cached_scale",    "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_STORAGE},
	]


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"from_position":                from_position = value;                return true
		&"to_position":                  to_position = value;                  return true
		&"from_scale":                   from_scale = value;                   return true
		&"to_scale":                     to_scale = value;                     return true
		&"custom_pivot":                 custom_pivot = value;                 return true
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
		&"from_scale":                   return from_scale
		&"to_scale":                     return to_scale
		&"custom_pivot":                 return custom_pivot
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
var _base_position: Vector2 = Vector2.ZERO
var _base_rotation_radians: float = 0.0
var _base_scale: Vector2 = Vector2.ONE

# Resolved From/To target node references
var _from_ref: Control = null
var _to_ref: Control = null

# Self snapshots — typed (guard flags live in base)
var _from_self_position_snapshot: Vector2 = Vector2.ZERO
var _from_self_rotation_snapshot: float = 0.0
var _from_self_scale_snapshot: Vector2 = Vector2.ONE
var _to_self_position_snapshot: Vector2 = Vector2.ZERO
var _to_self_rotation_snapshot: float = 0.0
var _to_self_scale_snapshot: Vector2 = Vector2.ONE


# =============================================================================
# VIRTUAL HOOK IMPLEMENTATIONS
# =============================================================================

func _do_capture_base(target: Node) -> void:
	if _has_base:
		if debug_enabled:
			print("[FROMTO_DBG] TransformCtrl._do_capture_base: SKIPPED (already has _base_pos=%s)" % [_base_position])
		return
	var ctrl := target as Control
	if ctrl == null:
		return
	# Read from the ledger so we get the natural state even if other Juice nodes are active.
	_base_position = JuiceLedger.get_base(ctrl, "position", ctrl.position)
	_base_rotation_radians = JuiceLedger.get_base(ctrl, "rotation", ctrl.rotation)
	_base_scale = JuiceLedger.get_base(ctrl, "scale", ctrl.scale)
	_has_base = true
	if debug_enabled:
		print("[FROMTO_DBG] TransformCtrl._do_capture_base: pos=%s, rot=%.1f°, scale=%s" % [
			_base_position, rad_to_deg(_base_rotation_radians), _base_scale])


func _do_update_editor_cache(target: Node) -> void:
	if not Engine.is_editor_hint():
		return
	var ctrl := target as Control
	if ctrl == null:
		return
	if from_reference == TransformReference.SELF and from_capture_at == CaptureAt.IN_EDITOR:
		_from_editor_cached_position = ctrl.position
		_from_editor_cached_rotation = ctrl.rotation
		_from_editor_cached_scale = ctrl.scale
	if to_reference == TransformReference.SELF and to_capture_at == CaptureAt.IN_EDITOR:
		_to_editor_cached_position = ctrl.position
		_to_editor_cached_rotation = ctrl.rotation
		_to_editor_cached_scale = ctrl.scale
	if debug_enabled:
		print("[TransformCtrl] Editor cache updated: pos=%s, rot=%.1f°, scale=%s" % [
			ctrl.position, rad_to_deg(ctrl.rotation), ctrl.scale])


func _clear_from_editor_cache_typed() -> void:
	_from_editor_cached_position = Vector2.ZERO
	_from_editor_cached_rotation = 0.0
	_from_editor_cached_scale = Vector2.ONE


func _clear_to_editor_cache_typed() -> void:
	_to_editor_cached_position = Vector2.ZERO
	_to_editor_cached_rotation = 0.0
	_to_editor_cached_scale = Vector2.ONE


func _capture_from_self_position_snapshot(target: Node) -> void:
	if _has_from_self_position_snapshot:
		if debug_enabled:
			print("[FROMTO_DBG] TransformCtrl._capture_from_self_position: SKIPPED (snap=%s)" % [_from_self_position_snapshot])
		return
	if from_capture_at == CaptureAt.IN_EDITOR:
		_from_self_position_snapshot = _from_editor_cached_position
		if debug_enabled:
			print("[FROMTO_DBG] TransformCtrl._capture_from_self_position: IN_EDITOR → cached=%s" % [_from_editor_cached_position])
	else:
		var ctrl := target as Control
		_from_self_position_snapshot = _ledger_base_snapshot.get("position", ctrl.position if ctrl else Vector2.ZERO)
		if debug_enabled:
			print("[FROMTO_DBG] TransformCtrl._capture_from_self_position: %s → snap=%s (ledger=%s)" % [
				CaptureAt.keys()[from_capture_at], _from_self_position_snapshot, not _ledger_base_snapshot.is_empty()])
	_has_from_self_position_snapshot = true


func _capture_from_self_rotation_snapshot(target: Node) -> void:
	if _has_from_self_rotation_snapshot:
		return
	if from_capture_at == CaptureAt.IN_EDITOR:
		_from_self_rotation_snapshot = _from_editor_cached_rotation
	else:
		var ctrl := target as Control
		_from_self_rotation_snapshot = _ledger_base_snapshot.get("rotation", ctrl.rotation if ctrl else 0.0)
	_has_from_self_rotation_snapshot = true
	if debug_enabled:
		print("[TransformCtrl] From Self rotation snapshot: %s rad (mode=%s)" % [
			_from_self_rotation_snapshot, CaptureAt.keys()[from_capture_at]])


func _capture_from_self_scale_snapshot(target: Node) -> void:
	if _has_from_self_scale_snapshot:
		return
	if from_capture_at == CaptureAt.IN_EDITOR:
		_from_self_scale_snapshot = _from_editor_cached_scale
	else:
		var ctrl := target as Control
		_from_self_scale_snapshot = _ledger_base_snapshot.get("scale", ctrl.scale if ctrl else Vector2.ONE)
	_has_from_self_scale_snapshot = true
	if debug_enabled:
		print("[TransformCtrl] From Self scale snapshot: %s (mode=%s)" % [
			_from_self_scale_snapshot, CaptureAt.keys()[from_capture_at]])


func _capture_to_self_position_snapshot(target: Node) -> void:
	if _has_to_self_position_snapshot:
		if debug_enabled:
			print("[FROMTO_DBG] TransformCtrl._capture_to_self_position: SKIPPED (snap=%s)" % [_to_self_position_snapshot])
		return
	if to_capture_at == CaptureAt.IN_EDITOR:
		_to_self_position_snapshot = _to_editor_cached_position
		if debug_enabled:
			print("[FROMTO_DBG] TransformCtrl._capture_to_self_position: IN_EDITOR → cached=%s" % [_to_editor_cached_position])
	else:
		var ctrl := target as Control
		_to_self_position_snapshot = _ledger_base_snapshot.get("position", ctrl.position if ctrl else Vector2.ZERO)
		if debug_enabled:
			print("[FROMTO_DBG] TransformCtrl._capture_to_self_position: %s → snap=%s (ledger=%s)" % [
				CaptureAt.keys()[to_capture_at], _to_self_position_snapshot, not _ledger_base_snapshot.is_empty()])
	_has_to_self_position_snapshot = true


func _capture_to_self_rotation_snapshot(target: Node) -> void:
	if _has_to_self_rotation_snapshot:
		return
	if to_capture_at == CaptureAt.IN_EDITOR:
		_to_self_rotation_snapshot = _to_editor_cached_rotation
	else:
		var ctrl := target as Control
		_to_self_rotation_snapshot = _ledger_base_snapshot.get("rotation", ctrl.rotation if ctrl else 0.0)
	_has_to_self_rotation_snapshot = true
	if debug_enabled:
		print("[TransformCtrl] To Self rotation snapshot: %s rad (mode=%s)" % [
			_to_self_rotation_snapshot, CaptureAt.keys()[to_capture_at]])


func _capture_to_self_scale_snapshot(target: Node) -> void:
	if _has_to_self_scale_snapshot:
		return
	if to_capture_at == CaptureAt.IN_EDITOR:
		_to_self_scale_snapshot = _to_editor_cached_scale
	else:
		var ctrl := target as Control
		_to_self_scale_snapshot = _ledger_base_snapshot.get("scale", ctrl.scale if ctrl else Vector2.ONE)
	_has_to_self_scale_snapshot = true
	if debug_enabled:
		print("[TransformCtrl] To Self scale snapshot: %s (mode=%s)" % [
			_to_self_scale_snapshot, CaptureAt.keys()[to_capture_at]])


func _do_apply_pivot_mode(target: Node) -> void:
	var ctrl := target as Control
	if ctrl == null:
		return
	match pivot_mode:
		PivotMode.AUTO_CENTER:
			ctrl.pivot_offset = ctrl.size / 2.0
		PivotMode.INHERIT:
			return  # Leave pivot_offset as-is
		PivotMode.CUSTOM:
			ctrl.pivot_offset = Vector2(
				ctrl.size.x * custom_pivot.x,
				ctrl.size.y * custom_pivot.y
			)


func _apply_position_effect(progress: float, target: Node) -> void:
	var ctrl := target as Control
	if ctrl == null:
		return
	var from_value := _resolve_from_position(ctrl)
	var to_value   := _resolve_to_position(ctrl)
	var desired_absolute := from_value.lerp(to_value, progress)
	_pos_delta = desired_absolute - _base_position
	if debug_enabled and (progress < 0.01 or progress > 0.99):
		print("[FROMTO_DBG] TransformCtrl._apply_position_effect: p=%.3f from=%s to=%s desired=%s _base=%s => _pos_delta=%s" % [
			progress, from_value, to_value, desired_absolute, _base_position, _pos_delta])


func _apply_rotation_effect(progress: float, target: Node) -> void:
	var ctrl := target as Control
	if ctrl == null:
		return
	var from_rad := _resolve_from_rotation(ctrl)
	var to_rad   := _resolve_to_rotation(ctrl)
	var desired_absolute := lerp_angle(from_rad, to_rad, progress)
	_rot_delta = desired_absolute - _base_rotation_radians


func _apply_scale_effect(progress: float, target: Node) -> void:
	var ctrl := target as Control
	if ctrl == null:
		return
	var from_value := _resolve_from_scale(ctrl)
	var to_value   := _resolve_to_scale(ctrl)
	var desired_absolute := from_value.lerp(to_value, progress)
	_scale_delta = desired_absolute - _base_scale


func _do_resolve_from_to_refs() -> void:
	_from_ref = null
	_to_ref = null
	if from_reference == TransformReference.TARGET_NODE:
		_from_ref = _resolve_node_path_to_control(from_target_node, "from_target_node")
	if to_reference == TransformReference.TARGET_NODE:
		_to_ref = _resolve_node_path_to_control(to_target_node, "to_target_node")


func _invalidate_typed_refs() -> void:
	_from_ref = null
	_to_ref = null


# =============================================================================
# POSITION EFFECT — internal resolvers
# =============================================================================

func _resolve_from_position(ctrl: Control) -> Vector2:
	match from_reference:
		TransformReference.CUSTOM:
			return _base_position + _convert_to_pixels(from_position, from_position_in, ctrl)
		TransformReference.SELF:
			return _from_self_position_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_position(_from_ref, ctrl)
	return _base_position


func _resolve_to_position(ctrl: Control) -> Vector2:
	match to_reference:
		TransformReference.CUSTOM:
			return _base_position + _convert_to_pixels(to_position, to_position_in, ctrl)
		TransformReference.SELF:
			return _to_self_position_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_position(_to_ref, ctrl)
	return _base_position


func _get_ref_local_position(ref: Control, animated: Control) -> Vector2:
	var parent := animated.get_parent_control()
	if parent:
		return parent.get_global_transform().affine_inverse() * ref.global_position
	return ref.global_position


# =============================================================================
# ROTATION EFFECT — internal resolvers
# =============================================================================

func _resolve_from_rotation(ctrl: Control) -> float:
	match from_reference:
		TransformReference.CUSTOM:
			return _base_rotation_radians + deg_to_rad(from_rotation_degrees)
		TransformReference.SELF:
			return _from_self_rotation_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_rotation(_from_ref, ctrl)
	return _base_rotation_radians


func _resolve_to_rotation(ctrl: Control) -> float:
	match to_reference:
		TransformReference.CUSTOM:
			return _base_rotation_radians + deg_to_rad(to_rotation_degrees)
		TransformReference.SELF:
			return _to_self_rotation_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_rotation(_to_ref, ctrl)
	return _base_rotation_radians


func _get_ref_local_rotation(ref: Control, animated: Control) -> float:
	var ref_rot := ref.get_global_transform().get_rotation()
	var parent := animated.get_parent_control()
	if parent:
		return ref_rot - parent.get_global_transform().get_rotation()
	return ref_rot


# =============================================================================
# SCALE EFFECT — internal resolvers
# =============================================================================

func _resolve_from_scale(ctrl: Control) -> Vector2:
	match from_reference:
		TransformReference.CUSTOM:
			return from_scale
		TransformReference.SELF:
			return _from_self_scale_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_scale(_from_ref, ctrl)
	return _base_scale


func _resolve_to_scale(ctrl: Control) -> Vector2:
	match to_reference:
		TransformReference.CUSTOM:
			return to_scale
		TransformReference.SELF:
			return _to_self_scale_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_scale(_to_ref, ctrl)
	return _base_scale


func _get_ref_local_scale(ref: Control, animated: Control) -> Vector2:
	var ref_global_scale := ref.get_global_transform().get_scale()
	var parent_scale := Vector2.ONE
	var parent := animated.get_parent_control()
	if parent:
		parent_scale = parent.get_global_transform().get_scale()
	return ref_global_scale / parent_scale


# =============================================================================
# HELPERS
# =============================================================================

func _get_viewport_size(ctrl: Control) -> Vector2:
	var vp := ctrl.get_viewport()
	if vp:
		return Vector2(vp.get_visible_rect().size)
	return Vector2.ZERO


func _resolve_node_path_to_control(path: NodePath, path_name: String) -> Control:
	if path.is_empty():
		return null
	if _host_node == null or not is_instance_valid(_host_node):
		if debug_enabled:
			push_warning("[TransformCtrl] Cannot resolve %s — no host node" % path_name)
		return null
	var resolved := _host_node.get_node_or_null(path)
	if resolved == null:
		if debug_enabled:
			push_warning("[TransformCtrl] %s path '%s' could not be resolved" % [path_name, path])
		return null
	if not (resolved is Control):
		if debug_enabled:
			push_warning("[TransformCtrl] %s '%s' is not a Control (is %s)" % [path_name, resolved.name, resolved.get_class()])
		return null
	return resolved as Control
