## Bridges runtime @tool scripts to editor-only APIs.
##
## Runtime scripts (JuiceBase, JuiceEffectBase, PropertyTarget, etc.) must not
## import editor-only classes at class scope — EditorInterface doesn't exist in
## export builds, causing a parse cascade that kills all effects. This bridge
## lives in Editor/ where EditorInterface is safe, and exposes static methods
## that runtime code calls through Callable hooks injected by juice_plugin.gd.

# ============================================================================
# WHAT: Centralised editor bridge for all runtime→editor dependencies.
# WHY:  Runtime @tool scripts reference this class ONLY through Callables
#       bound by juice_plugin.gd at _enter_tree(). This severs the parse chain:
#       runtime scripts never mention JuiceEditorBridge or JuiceEditorContext
#       in their source, so the parser never follows the dependency into
#       Editor/ code that references EditorInterface.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Run at runtime. All methods are editor-only.
# ============================================================================

class_name JuiceEditorBridge


# =============================================================================
# PROPERTY TARGET HOOKS — called via Callable from PropertyTarget/subclasses
# =============================================================================

## Resolves the target node for a PropertyTarget at editor time.
## Uses a 3-strategy waterfall: JuiceEditorContext → editor selection → scene root.
## Returns null if no resolution is possible.
static func resolve_node_for_target(pt: PropertyTarget) -> Node:
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return null

	# Strategy 1: JuiceEditorContext robust discovery.
	var context_host: Node = JuiceEditorContext.get_host_node(pt)
	if context_host != null:
		if pt.node_path == NodePath():
			return context_host
		var resolved: Node = context_host.get_node_or_null(pt.node_path)
		if resolved != null:
			return resolved

	# Strategy 2: Editor selection fallback (less reliable — user may have
	# selected a different node since last click).
	var juice_node: Node = _find_juice_base_from_selection()
	if juice_node != null:
		if pt.node_path == NodePath():
			return juice_node
		var resolved: Node = juice_node.get_node_or_null(pt.node_path)
		if resolved != null:
			return resolved

	# Strategy 3: Absolute NodePath resolved from scene root.
	if pt.node_path != NodePath():
		var resolved: Node = scene_root.get_node_or_null(pt.node_path)
		if resolved != null:
			return resolved

	return scene_root


## Resolves the editor target for an InterpolatePropertyTarget.
## Returns the animation target node (JuiceBase's parent) or null.
static func resolve_editor_target_for_interpolate(pt: Resource) -> Node:
	return JuiceEditorContext.resolve_editor_target(pt)


## Returns the JuiceBase host node for the given resource, or null.
static func get_host_node_for_resource(res: Resource) -> Node:
	return JuiceEditorContext.get_host_node(res)


# =============================================================================
# JUICE BASE HOOKS — called via Callable from JuiceBase
# =============================================================================

## Registers a recipe and its effects in JuiceEditorContext for sub-resource→host mapping.
static func register_recipe_for_host(recipe: Resource, host: Node) -> void:
	JuiceEditorContext.register_recipe(recipe, host)


## Flags a JuiceBase node as actively previewing (or not).
static func set_previewing_for_node(node: Node, active: bool) -> void:
	JuiceEditorContext.set_previewing(node, active)


# =============================================================================
# EFFECT BASE HOOKS — called via Callable from transform/appearance effects
# =============================================================================

## Resolves the editor target node for an effect (JuiceBase's parent).
## Used by transform effects' CaptureAt.IN_EDITOR setters.
static func resolve_editor_target_for_effect(effect: Resource) -> Node:
	return JuiceEditorContext.resolve_editor_target(effect)


## Returns the JuiceBase host node for an effect resource.
## Used by Appearance3DJuiceEffect for editor-time mesh resolution.
static func get_host_node_for_effect(effect: Resource) -> Node:
	return JuiceEditorContext.get_host_node(effect)


# =============================================================================
# HELPERS
# =============================================================================

# Walk the editor selection to find a JuiceBase node.
static func _find_juice_base_from_selection() -> Node:
	var selection := EditorInterface.get_selection()
	for selected in selection.get_selected_nodes():
		if selected is JuiceBase:
			return selected
		for child in selected.get_children():
			if child is JuiceBase:
				return child
	return null
