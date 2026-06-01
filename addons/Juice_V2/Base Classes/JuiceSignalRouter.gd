## JuiceSignalRouter — static utility for dynamic signal registration and emission.
##
## Registers user-defined signals on host Nodes (and optionally their owners)
## so they appear in the Inspector's Connect Signal dialog. Handles emission
## with optional bubbling to the scene/sub-scene root for prefab encapsulation.

# =============================================================================
# WHAT: Static helper that registers and emits dynamic user-defined signals
#       on Nodes, bridging the gap between Resource-based Juice effects and
#       Node-based Godot signal infrastructure.
# WHY:  Godot 4 Inspector can only connect signals from Nodes, not Resources.
#       Juice effects are Resources inside arrays — their signals are invisible
#       to the Inspector. This router registers the effect's signal_name on the
#       host Node so designers can connect it without code.
#       Bubbling to owner enables the prefab-as-black-box pattern: a main scene
#       connects to the prefab root's signal without digging into internal nodes.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Own any state — pure static utility. Does not manage signal lifetime
#           (signals persist on the Node until it is freed).
# =============================================================================

class_name JuiceSignalRouter


# =============================================================================
# PUBLIC API
# =============================================================================

## Register a user-defined signal on [param node] if it doesn't already exist.
## The signal is created with a single optional [code]payload[/code] argument
## so connected methods receive the entry's data.
## Safe to call multiple times — skips if the signal is already registered.
static func register_signal(node: Node, signal_name: String) -> void:
	if signal_name.is_empty():
		return
	if not node.has_user_signal(signal_name):
		# Single argument: payload (Variant). Connected methods receive it.
		node.add_user_signal(signal_name, [
			{"name": "payload", "type": TYPE_NIL}
		])


## Register a user-defined signal on both [param node] and its [member Node.owner].
## The owner is the scene/sub-scene root — registering there enables the
## prefab-as-black-box pattern (parent scene connects to prefab root).
## Skips owner registration if owner is null, same as node, or not valid.
static func register_signal_with_owner(node: Node, signal_name: String) -> void:
	register_signal(node, signal_name)
	var owner_node: Node = node.owner
	if _is_valid_owner(node, owner_node):
		register_signal(owner_node, signal_name)


## Emit [param signal_name] on [param node] with [param payload].
## No-op if signal_name is empty or the signal is not registered.
static func emit(node: Node, signal_name: String, payload: Variant) -> void:
	if signal_name.is_empty():
		return
	if node.has_user_signal(signal_name):
		node.emit_signal(signal_name, payload)


## Emit [param signal_name] on [param node] and also on its [member Node.owner]
## if [param bubble_to_owner] is true. This is the primary emission method —
## effects call this with their emit_to_owner configuration.
static func emit_with_bubbling(node: Node, signal_name: String, payload: Variant, bubble_to_owner: bool) -> void:
	emit(node, signal_name, payload)
	if bubble_to_owner:
		var owner_node: Node = node.owner
		if _is_valid_owner(node, owner_node):
			emit(owner_node, signal_name, payload)


# =============================================================================
# HELPERS
# =============================================================================

# Validate that owner is a distinct, valid node worth bubbling to.
# Returns false when owner is null, freed, or the same node (scene roots
# own themselves — emitting twice on the same node is wasteful).
static func _is_valid_owner(node: Node, owner_node: Node) -> bool:
	if owner_node == null or not is_instance_valid(owner_node):
		return false
	if owner_node == node:
		return false  # Scene roots own themselves — no double-emission.
	return true
