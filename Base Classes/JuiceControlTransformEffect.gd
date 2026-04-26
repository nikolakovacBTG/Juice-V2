## Intermediate base for Control-domain effects that produce transform deltas.
## Extends [JuiceControlEffectBase] and adds the complete Transform From/To framework.
## Concrete Transform effects (e.g., TransformControlJuiceEffect, future BounceEffect)
## only need to implement the typed virtual hooks below.

# ============================================================================
# WHAT: Domain base for all Control transform effects (position/rotation/scale).
# WHY:  Consolidates shared From/To framework — enums, config, property list,
#       lifecycle skeleton, and non-typed state — so concrete effects provide
#       only the typed per-domain code (capture, apply, resolve, pivot).
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Apply any effect behavior — concrete subclasses implement virtuals.
# DOES NOT: Handle Node2D or Node3D targets.
# NOTES:
#   Control has NATIVE pivot_offset — no position compensation needed for rotation.
#   _apply_pivot_mode() writes to ctrl.pivot_offset once per animation start.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name JuiceControlTransformEffect
extends JuiceControlEffectBase


# =============================================================================
# DELTA CONTRIBUTION STORAGE
# =============================================================================
# Effects compute deltas (offsets from natural state) and store them here.
# The domain node (JuiceControl) reads these after tick and writes ONCE.
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


# =============================================================================
# ENUMS — shared by all Control transform effects
# =============================================================================

## Which transform property to animate
enum TransformTarget {
	POSITION,  ## Animate Control.position
	ROTATION,  ## Animate Control.rotation (Z axis, degrees)
	SCALE      ## Animate Control.scale
}

## Pivot strategy for rotation and scale
enum PivotMode {
	AUTO_CENTER,  ## Pivot from visual center (size / 2)
	INHERIT,      ## Pivot from top-left origin (pivot_offset = Vector2.ZERO)
	CUSTOM        ## User-specified custom_pivot in pixels
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

## How to interpret custom position values (Control)
enum PositionIn {
	PIXELS,        ## Absolute pixels
	OWN_SIZE,      ## Multiple of Control's own size
	PARENT_SIZE,   ## Multiple of parent's size
	VIEWPORT_SIZE  ## Multiple of viewport size
}


# =============================================================================
# CONFIGURATION — non-typed, shared by all Control transform effects
# =============================================================================

var transform_target: int = TransformTarget.POSITION:
	set(value):
		transform_target = value
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

# Rotation — float, same in Control and 2D
var from_rotation_degrees: float = 0.0
var to_rotation_degrees: float = 15.0

# Position unit selector (int)
var from_position_in: int = PositionIn.OWN_SIZE
var to_position_in: int = PositionIn.OWN_SIZE

# Pivot mode (int)
var pivot_mode: int = PivotMode.AUTO_CENTER:
	set(value):
		pivot_mode = value
		notify_property_list_changed()


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
			"hint_string": "Control"})

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
			"hint_string": "Control"})
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
			"hint_string": "Control"})

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
			"hint_string": "Control"})
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
			"hint_string": "Control"})

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
			"hint_string": "Control"})
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

# True once _do_capture_base() has run — cleared by _invalidate_base_cache()
var _has_base: bool = false
# True once _apply_pivot_mode() has run — cleared by _invalidate_base_cache()
# Control uses native pivot_offset so we call it once per animation start.
var _pivot_applied: bool = false

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


func _on_animate_start(target: Node) -> void:
	JuiceLogger.log_info(self, _get_domain_tag(),
			"animate_start: has_base=%s target=%s" % [
			_has_base, TransformTarget.keys()[transform_target]],
			debug_enabled)

	if not _has_base:
		_do_capture_base(target)

	# Set contribution flags (Control rotation uses native pivot_offset — no pos compensation)
	_contributes_position = (transform_target == TransformTarget.POSITION)
	_contributes_rotation = (transform_target == TransformTarget.ROTATION)
	_contributes_scale    = (transform_target == TransformTarget.SCALE)

	_do_resolve_from_to_refs()

	var uses_from_self := from_reference == TransformReference.SELF
	var uses_to_self   := to_reference   == TransformReference.SELF

	if uses_from_self and (from_capture_at == CaptureAt.TRIGGER or from_capture_at == CaptureAt.IN_EDITOR):
		JuiceLogger.log_info(self, _get_domain_tag(),
				"capturing from_self snapshot", debug_enabled)
		match transform_target:
			TransformTarget.POSITION: _capture_from_self_position_snapshot(target)
			TransformTarget.ROTATION: _capture_from_self_rotation_snapshot(target)
			TransformTarget.SCALE:    _capture_from_self_scale_snapshot(target)

	if uses_to_self and (to_capture_at == CaptureAt.TRIGGER or to_capture_at == CaptureAt.IN_EDITOR):
		JuiceLogger.log_info(self, _get_domain_tag(),
				"capturing to_self snapshot", debug_enabled)
		match transform_target:
			TransformTarget.POSITION: _capture_to_self_position_snapshot(target)
			TransformTarget.ROTATION: _capture_to_self_rotation_snapshot(target)
			TransformTarget.SCALE:    _capture_to_self_scale_snapshot(target)

	# Apply Control pivot_offset (writes to ctrl.pivot_offset, only done once)
	if transform_target != TransformTarget.POSITION and not _pivot_applied:
		_do_apply_pivot_mode(target)
		_pivot_applied = true

	JuiceLogger.log_info(self, _get_domain_tag(),
			"animate_start complete: channels=pos:%s rot:%s scale:%s" % [
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
			{"pos": _pos_delta, "rot": _rot_delta, "scale": _scale_delta},
			target.name if target else "", debug_enabled)


func _restore_to_natural(_target: Node) -> void:
	_clear_deltas()


func _invalidate_base_cache() -> void:
	_has_base = false
	_pivot_applied = false
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

## Capture the base transform (position/rotation/scale) from the typed Control node.
func _do_capture_base(target: Node) -> void: pass

## Update editor cache from the target's current state.
func _do_update_editor_cache(target: Node) -> void: pass

## Clear typed from-editor cache vars (Vector2 for Control).
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

## Apply pivot mode — writes ctrl.pivot_offset. Called once at animation start.
func _do_apply_pivot_mode(target: Node) -> void: pass

## Apply position / rotation / scale effect at progress 0..1.
func _apply_position_effect(progress: float, target: Node) -> void: pass
func _apply_rotation_effect(progress: float, target: Node) -> void: pass
func _apply_scale_effect(progress: float, target: Node) -> void: pass

## Resolve and cache typed FROM/TO node references (Control).
func _do_resolve_from_to_refs() -> void: pass

## Clear typed ref caches.
func _invalidate_typed_refs() -> void: pass


# =============================================================================
# HELPERS — delta storage + size inference (all Control transform effects)
# =============================================================================

## Reset all deltas to zero. Called by domain node when effect stops.
func _clear_deltas() -> void:
	_pos_delta = Vector2.ZERO
	_rot_delta = 0.0
	_scale_delta = Vector2.ZERO


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


func _convert_to_pixels(position: Vector2, position_in: int, ctrl: Control) -> Vector2:
	match position_in:
		PositionIn.PIXELS:
			return position
		PositionIn.OWN_SIZE:
			var size := ctrl.size
			return Vector2(position.x * size.x, position.y * size.y)
		PositionIn.PARENT_SIZE:
			var size := _get_parent_control_size(ctrl)
			return Vector2(position.x * size.x, position.y * size.y)
		PositionIn.VIEWPORT_SIZE:
			var size := _get_viewport_size(ctrl)
			return Vector2(position.x * size.x, position.y * size.y)
	return position


func _get_parent_control_size(ctrl: Control) -> Vector2:
	var parent := ctrl.get_parent_control()
	if parent:
		return parent.size
	return _get_viewport_size(ctrl)
