## Manages the animation lifecycle for a single JuiceBase node.
##
## Single class with a mode enum — PREVIEW and RUNTIME differ only in
## what happens on stop() and teardown(). Extends Node so _process runs
## natively in the scene tree and queue_free() handles cleanup automatically.
## The orchestrator is added as a child of its managed domain node.

# ============================================================================
# WHAT: Lifecycle container for one JuiceBase node's animation session.
# WHY:  Decouples lifecycle management from PreviewDirector (which manages lists
#       of nodes) and from JuiceBase (which owns the tick loop and ledger writes).
#       Extends Node (not Object) so _process runs natively and queue_free()
#       provides automatic scene-tree cleanup — no manual deferred freeing needed.
# SYSTEM: Juice V2 Editor (addons/Juice_V2/Editor/)
# DOES NOT: Clone effects (Phase 5C1/5C2). Permanently remove ledger entries on stop —
#           only cleanup_source(permanent=false) fires in _exit_tree. Domain nodes handle
#           permanent cleanup in NOTIFICATION_PREDELETE until Phase 5C-full removes them.
# ============================================================================

@tool
class_name JuiceOrchestrator
extends Node


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
# LIFECYCLE
# =============================================================================

# Drive one PREVIEW tick per frame by calling the managed node's tick().
# RUNTIME mode is excluded — JuiceBase drives its own _process() until Phase 5B2.
# This method runs automatically because the orchestrator is a Node child of the
# domain node; Godot's scene tree enables _process by default.
func _process(delta: float) -> void:
	if not _is_node_valid():
		return
	# Drive tick() for both PREVIEW and RUNTIME modes.
	# JuiceBase.tick() returns immediately when _is_playing is false — safe to call every frame.
	_node.tick(delta)


# Clean up the ledger source when this orchestrator is freed.
# Fires on queue_free() (animation complete, teardown, scene exit) — covers all normal paths.
# Domain nodes retain a PREDELETE fallback for abnormal exits (Phase 5C-full removes it).
func _exit_tree() -> void:
	if _target != null and is_instance_valid(_target) \
			and _node != null and is_instance_valid(_node):
		JuiceLedger.cleanup_source(_target, _node, false)
		JuiceLogger.log_info(self, "Orchestrator",
				"_exit_tree: ledger cleanup for target=%s" % _target.name,
				debug_enabled)


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
	# queue_free() is safe here: as a Node child, Godot handles scene-tree removal
	# cleanly. Callers can check is_instance_valid() in the same frame after teardown.
	queue_free()



# =============================================================================
# HELPERS
# =============================================================================

# Returns true if the managed node is still valid.
# Guards all delegation methods against freed or exited nodes.
func _is_node_valid() -> bool:
	return _node != null and is_instance_valid(_node)
