## Manages the animation lifecycle for a single JuiceBase node.
##
## Single class with a mode enum — PREVIEW and RUNTIME differ only in
## what happens on stop() and teardown(). Effect ticking and delta writes
## remain owned by JuiceBase in Phase 4; the orchestrator delegates to
## JuiceBase's public API. Phase 5 will move the tick loop here.

# ============================================================================
# WHAT: Lifecycle container for one JuiceBase node's animation session.
# WHY:  Decouples lifecycle management from PreviewDirector (which manages lists
#       of nodes) and from JuiceBase (which owns the tick loop and ledger writes).
#       PreviewDirector spawns one orchestrator per node; the orchestrator owns
#       one node's play/stop/teardown contract.
# SYSTEM: Juice V2 Editor (addons/Juice_V2/Editor/)
# DOES NOT: Own the tick loop (JuiceBase does). Clone effects (Phase 5).
#           Register or deregister the ledger (Phase 5). Drive _process itself.
# ============================================================================

class_name JuiceOrchestrator
extends Object


# =============================================================================
# ENUMS
# =============================================================================

## Operating mode for this orchestrator instance.
## PREVIEW: editor-only playback — teardown() frees the orchestrator.
## RUNTIME: in-game playback — stop() keeps the orchestrator alive for reset().
enum Mode {
	PREVIEW,
	RUNTIME,
}


# =============================================================================
# INTERNAL STATE
# =============================================================================

# The JuiceBase node this orchestrator manages.
var _node: JuiceBase = null

# Recipe being played. Stored for Phase 5 when orchestrator owns cloning.
var _recipe: JuiceRecipe = null

# Target node (what gets animated). Stored for Phase 5 ledger registration.
var _target: Node = null

# Current mode — determines stop() and teardown() behavior.
var _mode: Mode = Mode.PREVIEW

# Debug flag — mirrors the managed node's debug_enabled by default.
var debug_enabled: bool = false


# =============================================================================
# PUBLIC API
# =============================================================================

## Configure this orchestrator for the given node and mode.
## Must be called before any play/stop/teardown calls.
## In Phase 4, stores references only — no cloning, no ledger registration.
func setup(node: JuiceBase, recipe: JuiceRecipe, target: Node, mode: Mode) -> void:
	_node   = node
	_recipe = recipe
	_target = target
	_mode   = mode
	debug_enabled = node.debug_enabled if node != null else false
	JuiceLogger.log_info(self, "Orchestrator",
			"setup() | node=%s | mode=%s" % [
			node.name if node else "null",
			"PREVIEW" if mode == Mode.PREVIEW else "RUNTIME"],
			debug_enabled)


## Full-fidelity play — routes through the trigger pipeline.
## Respects trigger_behaviour, start_delay, and retrigger policies.
## Use this for transport "Play" button (full recipe). Use play_in() for quick preview.
func play() -> void:
	if not _is_node_valid():
		return
	JuiceLogger.log_info(self, "Orchestrator", "play() → %s._handle_trigger(play_in)" % _node.name, debug_enabled)
	_node._handle_trigger({"play_in": true})


## Start the forward (IN) animation on the managed node.
## Delegates to JuiceBase.animate_in() — respects trigger_behaviour.
func play_in() -> void:
	if not _is_node_valid():
		return
	JuiceLogger.log_info(self, "Orchestrator", "play_in() → %s.animate_in()" % _node.name, debug_enabled)
	_node.animate_in()


## Start the reverse (OUT) animation on the managed node.
## Delegates to JuiceBase.animate_out() — respects trigger_behaviour.
func play_out() -> void:
	if not _is_node_valid():
		return
	JuiceLogger.log_info(self, "Orchestrator", "play_out() → %s.animate_out()" % _node.name, debug_enabled)
	_node.animate_out()


## Retrigger the animation without reallocating this orchestrator.
## RUNTIME only: stops the node and immediately restarts animate_in().
## This is the zero-allocation retrigger path — no new() call needed.
func reset() -> void:
	if not _is_node_valid():
		return
	if _mode != Mode.RUNTIME:
		JuiceLogger.warn(self, "Orchestrator",
				"reset() called on PREVIEW orchestrator — use teardown() instead.", debug_enabled)
		return
	JuiceLogger.log_info(self, "Orchestrator",
			"reset() → %s.stop() + animate_in() [zero-alloc retrigger]" % _node.name, debug_enabled)
	_node.stop()
	_node.animate_in()


## Stop the current animation.
## RUNTIME: stops the node, orchestrator stays alive (can reset() or teardown()).
## PREVIEW: stops the node, orchestrator is ready for teardown().
func stop() -> void:
	if not _is_node_valid():
		return
	JuiceLogger.log_info(self, "Orchestrator",
			"stop() → %s.stop() [mode=%s]" % [
			_node.name, "PREVIEW" if _mode == Mode.PREVIEW else "RUNTIME"],
			debug_enabled)
	_node.stop()


## Finalize this orchestrator: stop the node and free this object.
## Must be called for both PREVIEW and RUNTIME modes when the node is
## deselected, the game ends, or the node leaves the scene tree.
## After teardown(), this object is invalid — do not call any other methods.
func teardown() -> void:
	if _is_node_valid():
		JuiceLogger.log_info(self, "Orchestrator",
				"teardown() → %s.stop() + free()" % _node.name, debug_enabled)
		_node.stop()
	else:
		JuiceLogger.log_info(self, "Orchestrator", "teardown() — node invalid, freeing anyway", debug_enabled)
	_node   = null
	_recipe = null
	_target = null
	# Deferred free: avoids "Object is locked" errors when teardown() is called
	# while node.stop() is mid-signal dispatch (e.g., completed → deferred checks).
	# Callers that check is_instance_valid() after teardown must await at least 1 frame.
	call_deferred("free")



# =============================================================================
# HELPERS
# =============================================================================

# Returns true if the managed node is still valid.
# Guards all delegation methods against freed or exited nodes.
func _is_node_valid() -> bool:
	return _node != null and is_instance_valid(_node)
