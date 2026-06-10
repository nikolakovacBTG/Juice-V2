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
##
## Self-healing: on cache miss, walks the entire scene tree to find all
## JuiceBase nodes and re-registers their recipes. This covers stale maps
## caused by script reloads (tool scripts recreate Resource instances with
## new IDs), sub-resource array mutations (adding a PropertyTarget in the
## inspector), or fresh resource creation. The expensive tree walk only
## happens once per stale event — subsequent lookups hit the refreshed cache.
static func get_host_node(resource: Resource) -> Node:
	if not Engine.is_editor_hint() or resource == null:
		return null

	var result = _resource_to_node.get(resource.get_instance_id(), null)
	if result != null and is_instance_valid(result):
		return result

	# Cache miss — re-register all JuiceBase recipes in the scene, then retry.
	_refresh_all_registrations()
	return _resource_to_node.get(resource.get_instance_id(), null)


## Resolves the animation target node for an effect Resource at editor time.
## Effects are Resources without scene tree access. This helper bridges that
## gap by looking up the effect's JuiceBase host (via [method get_host_node])
## and returning host.get_parent() — which is the animation target in STACK mode.
## Returns [code]null[/code] at runtime or if the host node cannot be found.
static func resolve_editor_target(effect: Resource) -> Node:
	if not Engine.is_editor_hint():
		return null
	var host := get_host_node(effect)
	if host == null or not is_instance_valid(host):
		return null
	return host.get_parent()


# Walks the scene tree to find every JuiceBase node and re-registers its
# recipe. Called lazily on cache miss so the cost is paid once per stale
# event rather than on every lookup.
static func _refresh_all_registrations() -> void:
	var ei = Engine.get_singleton("EditorInterface")
	if ei == null:
		return
	var scene_root: Node = ei.get_edited_scene_root() as Node
	if scene_root == null:
		return
	_refresh_recursive(scene_root)


# Recursive helper: registers any JuiceBase found in the subtree.
static func _refresh_recursive(node: Node) -> void:
	if node is JuiceBase:
		var recipe = node.get("recipe")
		if recipe is JuiceRecipe:
			register_recipe(recipe, node)
	for child in node.get_children():
		_refresh_recursive(child)


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

