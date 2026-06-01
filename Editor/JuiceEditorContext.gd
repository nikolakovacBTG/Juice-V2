## Manages ephemeral editor state and preview nodes for the Juice plugin.
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
# SYSTEM: Juice System (addons/Juice_V2/)
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


# =============================================================================
# PREVIEW STATE TRACKING
# =============================================================================

## Nodes currently in editor preview mode (managed by the Preview Director).
static var _previewing_nodes: Array = []


## Register or unregister a node as being in editor preview mode.
## Called by JuiceBase._enter/_exit_editor_preview().
static func set_previewing(node: Node, active: bool) -> void:
	if active and node not in _previewing_nodes:
		_previewing_nodes.append(node)
	elif not active:
		_previewing_nodes.erase(node)


## Check if a specific node is currently being previewed.
static func is_previewing(node: Node) -> bool:
	return node in _previewing_nodes


## Get all nodes currently in editor preview mode.
static func get_all_previewing() -> Array:
	return _previewing_nodes.duplicate()


# =============================================================================
# SMART TARGET DISCOVERY
# =============================================================================

## Find all JuiceBase nodes that target the given node.
## Walks registered host mappings to find JuiceBase nodes whose parent (target)
## matches the selected node. Used by the transport plugin to activate preview
## when the user selects a target node (e.g. a Sprite2D) rather than the
## JuiceBase itself — a UX advantage over V0.
static func find_juice_nodes_for_target(target: Node) -> Array:
	if not Engine.is_editor_hint() or target == null:
		return []
	var results: Array = []
	# Check direct children of the target for JuiceBase nodes
	for child in target.get_children():
		if child is JuiceBase and child not in results:
			results.append(child)
	return results

