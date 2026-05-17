## Animate position, rotation, or scale of a [Node2D] with tween-based easing and From/To configuration.
##
## Select a transform target (Position, Rotation, or Scale) and configure animations
## using CUSTOM values, SELF snapshots, or live TARGET_NODE references.

# ============================================================================
# WHAT: Animate position, rotation, or scale of a Node2D with tween-based easing.
# WHY: Replaces 3 separate scripts with one unified component.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Handle Control or Node3D targets — use TransformControl/3DJuiceEffect.
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
# Node2D lacks native pivot_offset, so pivot is achieved by position compensation:
#   Rotation: fixed_pivot = base_pos + pivot.rotated(base_rot)
#             new_pos = fixed_pivot - pivot.rotated(new_rot)
#   Scale:    pos += pivot * (ONE - scale_ratio)
# AUTO_CENTER infers visual center from Sprite2D/CollisionShape2D/Polygon2D etc.
#
# SHARED FRAMEWORK:
# All enums, config vars, property list, and lifecycle skeleton live in
# Juice2DTransformEffect (domain base). This class provides only typed behavior.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBase2D.svg")
class_name Transform2DJuiceEffect
extends Juice2DTransformEffect


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
var custom_pivot: Vector2 = Vector2.ZERO

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
		{"name": "_from_editor_cached_rotation", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_STORAGE},
		{"name": "_from_editor_cached_scale", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_STORAGE},
	]

func _get_to_editor_cache_storage_properties() -> Array[Dictionary]:
	return [
		{"name": "_to_editor_cached_position", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_STORAGE},
		{"name": "_to_editor_cached_rotation", "type": TYPE_FLOAT, "usage": PROPERTY_USAGE_STORAGE},
		{"name": "_to_editor_cached_scale", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_STORAGE},
	]


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"from_position":               from_position = value;               return true
		&"to_position":                 to_position = value;                 return true
		&"from_scale":                  from_scale = value;                  return true
		&"to_scale":                    to_scale = value;                    return true
		&"custom_pivot":                custom_pivot = value;                return true
		&"_from_editor_cached_position": _from_editor_cached_position = value; return true
		&"_from_editor_cached_rotation": _from_editor_cached_rotation = value; return true
		&"_from_editor_cached_scale":    _from_editor_cached_scale = value;    return true
		&"_to_editor_cached_position":   _to_editor_cached_position = value;   return true
		&"_to_editor_cached_rotation":   _to_editor_cached_rotation = value;   return true
		&"_to_editor_cached_scale":      _to_editor_cached_scale = value;      return true
	return super._set(property, value)


func _get(property: StringName) -> Variant:
	match property:
		&"from_position":               return from_position
		&"to_position":                 return to_position
		&"from_scale":                  return from_scale
		&"to_scale":                    return to_scale
		&"custom_pivot":                return custom_pivot
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

# Resolved pivot point in target's local space (for rotation/scale)
var _pivot_point: Vector2 = Vector2.ZERO
# Fixed pivot position in parent space (pre-computed at animation start for rotation)
var _fixed_pivot_parent: Vector2 = Vector2.ZERO

# Resolved From/To target node references
var _from_ref: Node2D = null
var _to_ref: Node2D = null

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

# Called by Juice2DTransformEffect._on_animate_start before From/To resolution.
# Reads from the JuiceLedger (not the target) to get the pre-Juice natural state even
# when sibling effects are active. Skip-guarded to prevent mid-animation overwrite.
func _do_capture_base(target: Node) -> void:
	if _has_base:
		JuiceLogger.log_info(self, _get_domain_tag(),
				"capture_base: SKIPPED (already has base_pos=%s)" % [_base_position],
				debug_enabled)
		return
	var n2d := target as Node2D
	if n2d == null:
		return
	# Read from the ledger so we get the natural state even if other Juice nodes are active.
	_base_position = JuiceLedger.get_base(n2d, "position", n2d.position)
	_base_rotation_radians = JuiceLedger.get_base(n2d, "rotation", n2d.rotation)
	_base_scale = JuiceLedger.get_base(n2d, "scale", n2d.scale)
	_has_base = true
	JuiceLogger.log_capture(self, _get_domain_tag(), "base",
			"pos=%s rot=%.1f° scale=%s" % [
			_base_position, rad_to_deg(_base_rotation_radians), _base_scale],
			debug_enabled)


func _do_update_editor_cache(target: Node) -> void:
	if not Engine.is_editor_hint():
		return
	var n2d := target as Node2D
	if n2d == null:
		return
	if from_reference == TransformReference.SELF and from_capture_at == CaptureAt.IN_EDITOR:
		_from_editor_cached_position = n2d.position
		_from_editor_cached_rotation = n2d.rotation
		_from_editor_cached_scale = n2d.scale
	if to_reference == TransformReference.SELF and to_capture_at == CaptureAt.IN_EDITOR:
		_to_editor_cached_position = n2d.position
		_to_editor_cached_rotation = n2d.rotation
		_to_editor_cached_scale = n2d.scale
	JuiceLogger.log_capture(self, _get_domain_tag(), "editor_cache",
			"pos=%s rot=%.1f° scale=%s" % [
			n2d.position, rad_to_deg(n2d.rotation), n2d.scale],
			debug_enabled)


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
		var n2d := target as Node2D
		# Prefer the ledger base (true natural position, pre-all-Juice)
		_from_self_position_snapshot = _ledger_base_snapshot.get("position", n2d.position if n2d else Vector2.ZERO)
	_has_from_self_position_snapshot = true
	JuiceLogger.log_capture(self, _get_domain_tag(), "from_self_pos",
			"%s (mode=%s)" % [
			_from_self_position_snapshot, CaptureAt.keys()[from_capture_at]],
			debug_enabled)


func _capture_from_self_rotation_snapshot(target: Node) -> void:
	if _has_from_self_rotation_snapshot:
		return
	if from_capture_at == CaptureAt.IN_EDITOR:
		var ledger_rot: Variant = _ledger_base_snapshot.get("rotation", null)
		_from_self_rotation_snapshot = ledger_rot if ledger_rot != null else _from_editor_cached_rotation
	else:
		var n2d := target as Node2D
		_from_self_rotation_snapshot = _ledger_base_snapshot.get("rotation", n2d.rotation if n2d else 0.0)
	_has_from_self_rotation_snapshot = true
	JuiceLogger.log_capture(self, _get_domain_tag(), "from_self_rot",
			"%s rad (mode=%s)" % [
			_from_self_rotation_snapshot, CaptureAt.keys()[from_capture_at]],
			debug_enabled)


func _capture_from_self_scale_snapshot(target: Node) -> void:
	if _has_from_self_scale_snapshot:
		return
	if from_capture_at == CaptureAt.IN_EDITOR:
		var ledger_sc: Variant = _ledger_base_snapshot.get("scale", null)
		_from_self_scale_snapshot = ledger_sc if ledger_sc != null else _from_editor_cached_scale
	else:
		var n2d := target as Node2D
		_from_self_scale_snapshot = _ledger_base_snapshot.get("scale", n2d.scale if n2d else Vector2.ONE)
	_has_from_self_scale_snapshot = true
	JuiceLogger.log_capture(self, _get_domain_tag(), "from_self_scale",
			"%s (mode=%s)" % [
			_from_self_scale_snapshot, CaptureAt.keys()[from_capture_at]],
			debug_enabled)


func _capture_to_self_position_snapshot(target: Node) -> void:
	if _has_to_self_position_snapshot:
		return
	# IN_EDITOR: prefer the per-target ledger base when available (see _capture_from_self_position_snapshot).
	if to_capture_at == CaptureAt.IN_EDITOR:
		var ledger_pos: Variant = _ledger_base_snapshot.get("position", null)
		_to_self_position_snapshot = ledger_pos if ledger_pos != null else _to_editor_cached_position
	else:
		var n2d := target as Node2D
		_to_self_position_snapshot = _ledger_base_snapshot.get("position", n2d.position if n2d else Vector2.ZERO)
	_has_to_self_position_snapshot = true
	JuiceLogger.log_capture(self, _get_domain_tag(), "to_self_pos",
			"%s (mode=%s)" % [
			_to_self_position_snapshot, CaptureAt.keys()[to_capture_at]],
			debug_enabled)


func _capture_to_self_rotation_snapshot(target: Node) -> void:
	if _has_to_self_rotation_snapshot:
		return
	if to_capture_at == CaptureAt.IN_EDITOR:
		var ledger_rot: Variant = _ledger_base_snapshot.get("rotation", null)
		_to_self_rotation_snapshot = ledger_rot if ledger_rot != null else _to_editor_cached_rotation
	else:
		var n2d := target as Node2D
		_to_self_rotation_snapshot = _ledger_base_snapshot.get("rotation", n2d.rotation if n2d else 0.0)
	_has_to_self_rotation_snapshot = true
	JuiceLogger.log_capture(self, _get_domain_tag(), "to_self_rot",
			"%s rad (mode=%s)" % [
			_to_self_rotation_snapshot, CaptureAt.keys()[to_capture_at]],
			debug_enabled)


func _capture_to_self_scale_snapshot(target: Node) -> void:
	if _has_to_self_scale_snapshot:
		return
	if to_capture_at == CaptureAt.IN_EDITOR:
		var ledger_sc: Variant = _ledger_base_snapshot.get("scale", null)
		_to_self_scale_snapshot = ledger_sc if ledger_sc != null else _to_editor_cached_scale
	else:
		var n2d := target as Node2D
		_to_self_scale_snapshot = _ledger_base_snapshot.get("scale", n2d.scale if n2d else Vector2.ONE)
	_has_to_self_scale_snapshot = true
	JuiceLogger.log_capture(self, _get_domain_tag(), "to_self_scale",
			"%s (mode=%s)" % [
			_to_self_scale_snapshot, CaptureAt.keys()[to_capture_at]],
			debug_enabled)


# Node2D has no native pivot_offset. AUTO_CENTER estimates the visual center
# from child bounds (Sprite2D, CollisionShape2D, etc.) with a recursive fallback
# if the direct node has zero-size bounds. CUSTOM uses a raw pixel offset.
func _do_resolve_pivot(target: Node) -> void:
	var n2d := target as Node2D
	match pivot_mode:
		PivotMode.AUTO_CENTER:
			if n2d:
				var bounds := _infer_node2d_local_bounds(n2d)
				if bounds.size == Vector2.ZERO:
					bounds = _infer_node2d_bounds_recursive(n2d)
				_pivot_point = bounds.get_center() if bounds.size != Vector2.ZERO else Vector2.ZERO
				JuiceLogger.log_capture(self, _get_domain_tag(), "pivot_auto",
						"bounds=%s center=%s" % [bounds, _pivot_point],
						debug_enabled)
			else:
				_pivot_point = Vector2.ZERO
		PivotMode.INHERIT:
			_pivot_point = Vector2.ZERO
		PivotMode.CUSTOM:
			_pivot_point = custom_pivot


func _pre_compute_pivot_for_rotation() -> void:
	_fixed_pivot_parent = _base_position + _pivot_point.rotated(_base_rotation_radians)


func _pivot_contributes_position() -> bool:
	return _pivot_point != Vector2.ZERO


func _apply_position_effect(progress: float, target: Node) -> void:
	var n2d := target as Node2D
	if n2d == null:
		return
	var from_value := _resolve_from_position(n2d)
	var to_value   := _resolve_to_position(n2d)
	var desired_absolute := from_value.lerp(to_value, progress)
	_last_desired_pos = desired_absolute
	_pos_delta = desired_absolute - _base_position


func _apply_rotation_effect(progress: float, target: Node) -> void:
	var n2d := target as Node2D
	if n2d == null:
		return
	var from_rad := _resolve_from_rotation(n2d)
	var to_rad   := _resolve_to_rotation(n2d)
	var desired_absolute := lerp_angle(from_rad, to_rad, progress)
	_last_desired_rot = desired_absolute
	_rot_delta = desired_absolute - _base_rotation_radians
	# Pivot compensation: store position delta
	if _pivot_point != Vector2.ZERO:
		var desired_pos := _fixed_pivot_parent - _pivot_point.rotated(desired_absolute)
		_pos_delta = desired_pos - _base_position


func _apply_scale_effect(progress: float, target: Node) -> void:
	var n2d := target as Node2D
	if n2d == null:
		return
	var from_value := _resolve_from_scale(n2d)
	var to_value   := _resolve_to_scale(n2d)
	var desired_absolute := from_value.lerp(to_value, progress)
	_last_desired_scale = desired_absolute
	_scale_delta = desired_absolute - _base_scale
	# Pivot compensation: store position delta
	if _pivot_point != Vector2.ZERO:
		var scale_ratio := desired_absolute / _base_scale
		_pos_delta = _pivot_point * (Vector2.ONE - scale_ratio)


func _do_resolve_from_to_refs() -> void:
	_from_ref = null
	_to_ref = null
	if from_reference == TransformReference.TARGET_NODE:
		_from_ref = _resolve_node_path_to_node2d(from_target_node, "from_target_node")
	if to_reference == TransformReference.TARGET_NODE:
		_to_ref = _resolve_node_path_to_node2d(to_target_node, "to_target_node")


func _invalidate_typed_refs() -> void:
	_from_ref = null
	_to_ref = null


# =============================================================================
# POSITION EFFECT — internal resolvers
# =============================================================================

func _resolve_from_position(animated: Node2D) -> Vector2:
	match from_reference:
		TransformReference.CUSTOM:
			return _base_position + _convert_to_world_pixels(from_position, from_position_in, animated)
		TransformReference.SELF:
			return _from_self_position_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_position(_from_ref, animated)
	return _base_position


func _resolve_to_position(animated: Node2D) -> Vector2:
	match to_reference:
		TransformReference.CUSTOM:
			return _base_position + _convert_to_world_pixels(to_position, to_position_in, animated)
		TransformReference.SELF:
			return _to_self_position_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_position(_to_ref, animated)
	return _base_position


func _get_ref_local_position(ref: Node2D, animated: Node2D) -> Vector2:
	var parent := animated.get_parent()
	if parent is Node2D:
		return (parent as Node2D).global_transform.affine_inverse() * ref.global_position
	elif parent is Control:
		return (parent as Control).get_global_transform().affine_inverse() * ref.global_position
	return ref.global_position


# =============================================================================
# ROTATION EFFECT — internal resolvers
# =============================================================================

func _resolve_from_rotation(animated: Node2D) -> float:
	match from_reference:
		TransformReference.CUSTOM:
			return _base_rotation_radians + deg_to_rad(from_rotation_degrees)
		TransformReference.SELF:
			return _from_self_rotation_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_rotation(_from_ref, animated)
	return _base_rotation_radians


func _resolve_to_rotation(animated: Node2D) -> float:
	match to_reference:
		TransformReference.CUSTOM:
			return _base_rotation_radians + deg_to_rad(to_rotation_degrees)
		TransformReference.SELF:
			return _to_self_rotation_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_rotation(_to_ref, animated)
	return _base_rotation_radians


func _get_ref_local_rotation(ref: Node2D, animated: Node2D) -> float:
	var parent := animated.get_parent()
	if parent is Node2D:
		return ref.global_rotation - (parent as Node2D).global_rotation
	return ref.global_rotation


# =============================================================================
# SCALE EFFECT — internal resolvers
# =============================================================================

func _resolve_from_scale(animated: Node2D) -> Vector2:
	match from_reference:
		TransformReference.CUSTOM:
			return from_scale
		TransformReference.SELF:
			return _from_self_scale_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_from_ref):
				return _get_ref_local_scale(_from_ref, animated)
	return _base_scale


func _resolve_to_scale(animated: Node2D) -> Vector2:
	match to_reference:
		TransformReference.CUSTOM:
			return to_scale
		TransformReference.SELF:
			return _to_self_scale_snapshot
		TransformReference.TARGET_NODE:
			if is_instance_valid(_to_ref):
				return _get_ref_local_scale(_to_ref, animated)
	return _base_scale


func _get_ref_local_scale(ref: Node2D, animated: Node2D) -> Vector2:
	var ref_global_scale := ref.global_scale
	var parent_scale := Vector2.ONE
	var parent := animated.get_parent()
	if parent is Node2D:
		parent_scale = (parent as Node2D).global_scale
	return ref_global_scale / parent_scale


# =============================================================================
# HELPERS
# =============================================================================

func _resolve_node_path_to_node2d(path: NodePath, path_name: String) -> Node2D:
	if path.is_empty():
		return null
	if _host_node == null or not is_instance_valid(_host_node):
		if debug_enabled:
			JuiceLogger.warn(self, _get_domain_tag(),
					"cannot resolve %s — no host node" % path_name, debug_enabled)
		return null
	var resolved := _host_node.get_node_or_null(path)
	if resolved == null:
		if debug_enabled:
			JuiceLogger.warn(self, _get_domain_tag(),
					"%s path '%s' could not be resolved" % [path_name, path], debug_enabled)
		return null
	if not (resolved is Node2D):
		if debug_enabled:
			JuiceLogger.warn(self, _get_domain_tag(),
					"%s '%s' is not a Node2D (is %s)" % [path_name, resolved.name, resolved.get_class()], debug_enabled)
		return null
	return resolved as Node2D
