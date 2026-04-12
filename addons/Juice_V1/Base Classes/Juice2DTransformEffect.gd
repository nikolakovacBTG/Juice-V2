## Intermediate base for 2D-domain effects that produce transform deltas.

# ============================================================================
# WHAT: Intermediate base for 2D-domain effects that produce transform deltas.
# WHY: Separates transform delta storage from domain filtering. Effects that
#      manipulate position/rotation/scale extend this. Non-transform effects
#      (Appearance, VFX, etc.) extend Juice2DEffectBase directly.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Implement any effect behavior — concrete subclasses do that.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase2D.svg")
class_name Juice2DTransformEffect
extends Juice2DEffectBase

# =============================================================================
# DELTA CONTRIBUTION STORAGE
# =============================================================================
# Effects compute deltas (offsets from natural state) and store them here.
# The domain node (Juice2D) reads these after tick and writes ONCE.
# Effects NEVER write to the target directly.

## Which channels this effect contributes to. Set by concrete effects in _init().
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


## How to interpret custom position values (2D). Available to all 2D transform effects.
enum PositionIn {
	PIXELS,           ## Position in absolute pixels
	OWN_SIZE,     ## Position as multiple of object's own size
	PARENT_SIZE,  ## Position as multiple of parent's size
	VIEWPORT_SIZE ## Position as multiple of viewport size
}


## Reset all deltas to zero. Called by domain node when effect stops.
func _clear_deltas() -> void:
	_pos_delta = Vector2.ZERO
	_rot_delta = 0.0
	_scale_delta = Vector2.ZERO


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
# SIZE INFERENCE HELPERS (Available to all 2D transform effects)
# =============================================================================

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
