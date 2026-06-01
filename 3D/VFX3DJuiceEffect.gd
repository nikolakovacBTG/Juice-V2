## Triggers particle effects or spawns VFX scenes on Node3D targets.
##
## TRIGGER_EXISTING: fires GPU/CPU particle nodes that are children of Node3D targets.
## INSTANTIATE_NEW: spawns PackedScene instances as children of Node3D nodes at their position.
## Custom positions use Vector3 values in world space.

# =============================================================================
# WHAT: 3D-domain VFX effect — fires or spawns particle systems on Node3D targets.
# WHY:  Domain subclasses exist because position math requires type-safe access to
#       domain-specific node properties (Node3D.global_position, global_rotation).
#       3D particles do not need repositioning in TRIGGER_EXISTING mode because
#       Node3D children naturally inherit their parent's global transform.
# SYSTEM: Juice System (addons/Juice_V2/3D/)
# DOES NOT: Handle Control or Node2D target types.
# DOES NOT: Compute transform deltas — side-effect exception (see base class).
# =============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseVFX.svg")
class_name VFX3DJuiceEffect
extends VFXJuiceEffectBase


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

## Append the Vector3 custom_positions array when use_custom_positions is enabled.
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
					"hint_string": "%d:" % TYPE_VECTOR3,
					"usage": PROPERTY_USAGE_DEFAULT
				})
				break
	return props


# =============================================================================
# VIRTUAL METHOD IMPLEMENTATIONS
# =============================================================================

## 3D particles are Node3D children and inherit parent global transform automatically.
## No repositioning is needed — leave as no-op.
func _reposition_particles_to_node(_particles: Array[Node], _source_node: Node) -> void:
	pass


## Position a spawned Node3D instance at the reference node's global position plus offset.
## The instance is already a child of ref_node when this is called.
func _place_instance(instance: Node, ref_node: Node,
		offset: Vector3, inherit_rot: bool) -> void:
	if not instance is Node3D:
		return
	var i3 := instance as Node3D
	var ref3 := ref_node as Node3D
	i3.global_position = ref3.global_position + offset
	if inherit_rot:
		i3.global_rotation = ref3.global_rotation


## Place a spawned instance at a Vector3 world-space custom position.
func _place_instance_at_custom_pos(instance: Node, pos: Variant) -> void:
	if not instance is Node3D:
		return
	(instance as Node3D).global_position = pos as Vector3
