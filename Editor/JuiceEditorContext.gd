## JuiceEditorContext.gd
## A static utility script that serves as the central brain for all editor-time
## Juice operations. Safely maps sub-resources to their host Nodes at editor time.
##
## This is strictly an editor-only utility. It prevents polluting runtime
## resources with editor-state caching logic.

class_name JuiceEditorContext
extends RefCounted

# ============================================================================
# WHAT: Editor-only context for Juice nodes and resources.
# WHY: Resources (like JuiceEffectBase and PropertyTarget) don't have a 
#      get_owner_node() equivalent. They need to know their host node to
#      resolve NodePaths at editor time (e.g. for the PropertyPicker).
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Do anything at runtime. This script is fully static and passive.
# ============================================================================

## Editor-only mapping: Resource instance ID -> Node (JuiceBase)
static var _resource_to_node: Dictionary = {}

## Registers a recipe and all of its effects to a host node.
## Must be called from JuiceBase._ready() and whenever the recipe changes in editor.
static func register_recipe(recipe: JuiceRecipe, host: Node) -> void:
	if not Engine.is_editor_hint() or recipe == null or host == null:
		return
	
	_resource_to_node[recipe.get_instance_id()] = host
	
	for effect in recipe.effects:
		if effect != null:
			_resource_to_node[effect.get_instance_id()] = host
			# If the effect contains further sub-resources (like PropertyTargets),
			# we could recurse here. For now, effects usually manage their own
			# targets natively, but let's register known meta-resources if they exist.
			
			# Property Targets (PropertyNoise, PropertyShake, PropertyInterpolate)
			if "property_targets" in effect:
				for target in effect.get("property_targets"):
					if target != null and target is Resource:
						_resource_to_node[target.get_instance_id()] = host
			
			# Call Method Entries (CallMethod)
			if "methods" in effect:
				for method in effect.get("methods"):
					if method != null and method is Resource:
						_resource_to_node[method.get_instance_id()] = host


## Retrieves the host node for a given resource instance.
## Returns null if the resource is not registered or not in editor mode.
static func get_host_node(resource: Resource) -> Node:
	if not Engine.is_editor_hint() or resource == null:
		return null
	
	return _resource_to_node.get(resource.get_instance_id(), null)
