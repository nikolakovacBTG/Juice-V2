## Triggers particle effects or spawns VFX scenes on Control targets.
##
## TRIGGER_EXISTING: fires GPU/CPU particle nodes that are children of Control targets,
## repositioning them to the Control's visual center (layout center + size/2).
## INSTANTIATE_NEW: spawns PackedScene instances as children of Control nodes at their center.
## Custom positions use Vector2 values in world space.

# =============================================================================
# WHAT: Control-domain VFX effect — fires or spawns particle systems on Control targets.
# WHY:  Control nodes do not propagate layout transforms to Node2D children the way
#       Node2D does. The center must be calculated from global_position + size / 2.0.
#       Additionally, rotation is accessed via CanvasItem.global_rotation — casting
#       explicitly to CanvasItem avoids GDScript's static-type access limitation
#       when the variable is typed as Control.
# SYSTEM: Juice System (addons/Juice_V1/Control/)
# DOES NOT: Handle Node2D or Node3D target types.
# DOES NOT: Compute transform deltas — side-effect exception (see base class).
# =============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseVFX.svg")
class_name VFXControlJuiceEffect
extends VFXJuiceEffectBase


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

## Append the Vector2 custom_positions array when use_custom_positions is enabled.
## Calls _build_vfx_property_list() (not super._get_property_list()) — Godot auto-merges
## _get_property_list() from all classes in the chain, so calling super would double everything.
func _get_property_list() -> Array[Dictionary]:
	var props := _build_vfx_property_list()
	if vfx_mode == VFXMode.INSTANTIATE_NEW and use_custom_positions:
		for i in props.size():
			if props[i].get("name") == "use_custom_positions":
				props.insert(i + 1, {
					"name": "custom_positions",
					"type": TYPE_ARRAY,
					"hint": PROPERTY_HINT_ARRAY_TYPE,
					"hint_string": "%d:" % TYPE_VECTOR2,
					"usage": PROPERTY_USAGE_DEFAULT
				})
				break
	return props


# =============================================================================
# VIRTUAL METHOD IMPLEMENTATIONS
# =============================================================================

## Reposition Node2D particle children to the Control's visual center.
## Controls do not propagate layout position to Node2D children automatically —
## the center must be explicitly computed from global_position + size / 2.0.
func _reposition_particles_to_node(particles: Array[Node], source_node: Node) -> void:
	if not source_node is Control:
		return
	var ctrl := source_node as Control
	var center: Vector2 = ctrl.global_position + ctrl.size / 2.0
	for p in particles:
		if p is Node2D:
			(p as Node2D).global_position = center


## Position a spawned instance at the Control's visual center plus offset.
## The instance is already a child of ref_node (the Control) when this is called.
## Rotation is read via CanvasItem cast — GDScript's static type system requires
## an explicit cast to access CanvasItem properties on a Control-typed variable.
func _place_instance(instance: Node, ref_node: Node,
		offset: Vector3, inherit_rot: bool) -> void:
	if not instance is Node2D:
		return
	var i2 := instance as Node2D
	var ctrl := ref_node as Control
	var off2 := Vector2(offset.x, offset.y)
	i2.global_position = ctrl.global_position + ctrl.size / 2.0 + off2
	if inherit_rot:
		i2.global_rotation = (ctrl as CanvasItem).global_rotation


## Place a spawned instance at a Vector2 world-space custom position.
func _place_instance_at_custom_pos(instance: Node, pos: Variant) -> void:
	if not instance is Node2D:
		return
	(instance as Node2D).global_position = pos as Vector2
