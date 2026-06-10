## Editor-time node resolver for PropertyTarget and its subclasses.
##
## Bridges the gap between runtime Resources (PropertyTarget, InterpolatePropertyTarget)
## and editor-only APIs (EditorInterface, JuiceEditorContext). Runtime scripts call
## through static Callable hooks injected by juice_plugin.gd at _enter_tree().

# ============================================================================
# WHAT: Centralised editor-time node resolution for the Property family.
# WHY:  Runtime @tool Resources must not import editor-only classes at class
#       scope — EditorInterface doesn't exist in export builds, causing a parse
#       cascade that kills all effects. This helper lives in Editor/ where
#       EditorInterface is safe, and exposes Callables that runtime code binds
#       to without knowing the implementation.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Run at runtime. All methods are editor-only.
# ============================================================================

class_name PropertyTargetEditorHelper


# =============================================================================
# PUBLIC API — called via Callable from runtime scripts
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
