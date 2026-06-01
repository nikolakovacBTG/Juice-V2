## Triggers particle effects or spawns VFX scenes on Node2D targets.
##
## TRIGGER_EXISTING: fires GPU/CPU particle nodes that are children of target nodes.
## INSTANTIATE_NEW: spawns PackedScene instances as children of target nodes at their positions.
## Custom positions use Vector2 values in world space.

# =============================================================================
# WHAT: 2D-domain VFX effect — fires or spawns particle systems on Node2D targets.
# WHY:  Domain subclasses exist because position math requires type-safe access to
#       domain-specific node properties (Node2D.global_position, global_rotation).
#       A unified class with runtime `is` dispatch caused type-access crashes that
#       are impossible here: the target is guaranteed to be Node2D at this level.
# SYSTEM: Juice System (addons/Juice_V2/2D/)
# DOES NOT: Handle Control or 3D target types.
# DOES NOT: Compute transform deltas — side-effect exception (see base class).
# =============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseVFX.svg")
class_name VFX2DJuiceEffect
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
		# Insert custom_positions after the use_custom_positions bool.
		# Find its index and insert right after.
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

## Reposition Node2D particle children to the source node's global position.
## Required because Node2D children don't inherit a parent Node2D's global transform
## automatically when they are manually positioned or when the scene graph updates lazily.
func _reposition_particles_to_node(particles: Array[Node], source_node: Node) -> void:
	if not source_node is Node2D:
		return
	var pos: Vector2 = (source_node as Node2D).global_position
	for p in particles:
		if p is Node2D:
			(p as Node2D).global_position = pos


## Position a spawned instance at the reference Node2D's global position plus offset.
## The instance is already a child of ref_node when this is called.
func _place_instance(instance: Node, ref_node: Node,
		offset: Vector3, inherit_rot: bool) -> void:
	if not instance is Node2D:
		return
	var i2 := instance as Node2D
	var ref2 := ref_node as Node2D
	var off2 := Vector2(offset.x, offset.y)
	# global_position must be set AFTER add_child so the instance is in the tree.
	i2.global_position = ref2.global_position + off2
	if inherit_rot:
		i2.global_rotation = ref2.global_rotation


## Place a spawned instance at a Vector2 world-space custom position.
func _place_instance_at_custom_pos(instance: Node, pos: Variant) -> void:
	if not instance is Node2D:
		return
	(instance as Node2D).global_position = pos as Vector2
