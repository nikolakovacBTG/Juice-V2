## Intermediate base for 3D-domain effects that produce transform deltas.

# ============================================================================
# WHAT: Intermediate base for 3D-domain effects that produce transform deltas.
# WHY: Separates transform delta storage from domain filtering. Effects that
#      manipulate position/rotation/scale extend this. Non-transform effects
#      (Appearance, VFX, etc.) extend Juice3DEffectBase directly.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Implement any effect behavior — concrete subclasses do that.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name Juice3DTransformEffect
extends Juice3DEffectBase

# =============================================================================
# DELTA CONTRIBUTION STORAGE
# =============================================================================
# Effects compute deltas (offsets from natural state) and store them here.
# The domain node (Juice3D) reads these after tick and writes ONCE.
# Effects NEVER write to the target directly.

## Which channels this effect contributes to. Set by concrete effects in _init().
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


## How to interpret custom position values (3D)
enum PositionIn3D {
	WORLD_UNITS,  ## Position in absolute world units
	OWN_SIZE,     ## Position as multiple of object's own AABB
	PARENT_SIZE   ## Position as multiple of parent's AABB
}


## Reset all deltas to zero. Called by domain node when effect stops.
func _clear_deltas() -> void:
	_pos_delta = Vector3.ZERO
	_rot_delta = Vector3.ZERO
	_scale_delta = Vector3.ZERO


## Return current deltas as a Dictionary keyed by Godot property names.
## Used by Sequencer contribution-tracking (generic, no hardcoded channels
## in domain nodes). Future effects override this to add their own channels.
func _get_seq_contribution() -> Dictionary:
	var d := {}
	if _contributes_position:
		d["position"] = _pos_delta
	if _contributes_rotation:
		d["rotation"] = _rot_delta
	if _contributes_scale:
		d["scale"] = _scale_delta
	return d


# =============================================================================
# SIZE INFERENCE HELPERS (Available to all 3D transform effects)
# =============================================================================

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
