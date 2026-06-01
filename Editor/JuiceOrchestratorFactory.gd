## Creates and returns configured JuiceOrchestrator instances.
##
## Single static entry point for all orchestrator creation. Ensures every
## orchestrator is properly set up before the caller receives it.

# ============================================================================
# WHAT: Factory for JuiceOrchestrator instances.
# WHY:  Centralizes orchestrator creation so the setup() contract is always
#       fulfilled before the caller touches the orchestrator. Callers provide
#       recipe and target explicitly — the factory is a pure assembler with
#       zero knowledge of domain-node internals.
# SYSTEM: Juice V2 Editor (addons/Juice_V2/Editor/)
# DOES NOT: Own the orchestrator after creation — caller owns lifetime.
#           Resolve recipe or target from node internals.
#           Cache or pool orchestrators.
# ============================================================================

@tool
class_name JuiceOrchestratorFactory


# =============================================================================
# PUBLIC API
# =============================================================================

## Create a JuiceOrchestrator for the given node with the given recipe, target, and mode.
##
## recipe and target must be provided by the caller. The factory is a pure
## assembler — it does not reach into node internals. target may be null
## for SEQUENCER mode (targets are resolved per-sequence-entry at runtime).
##
## The returned orchestrator is already setup() and ready for play_in()/play_out().
## The CALLER owns the returned object, MUST add_child() it, and MUST call teardown() when done.
##
## Example (PREVIEW):
##   var orch := JuiceOrchestratorFactory.create(node, node.recipe, node._target_node, JuiceOrchestrator.Mode.PREVIEW)
##   node.add_child(orch)
##   orch.play_in()
##   # later:
##   orch.teardown()
##
## Example (RUNTIME — eager creation in _ready()):
##   var orch := JuiceOrchestratorFactory.create(self, recipe, _target_node, JuiceOrchestrator.Mode.RUNTIME)
##   add_child(orch)
static func create(
		node: JuiceBase,
		recipe: JuiceRecipe,
		target: Node,
		mode: JuiceOrchestrator.Mode) -> JuiceOrchestrator:
	if node == null:
		JuiceLogger.warn(null, "OrchestratorFactory",
				"create() called with null node — returning null.", false)
		return null
	var mode_str := "PREVIEW" if mode == JuiceOrchestrator.Mode.PREVIEW else "RUNTIME"
	JuiceLogger.log_info(node, "OrchestratorFactory",
			"create() | node=%s | target=%s | mode=%s" % [
			node.name,
			target.name if target != null else "null",
			mode_str],
			node.debug_enabled)
	var orch := JuiceOrchestrator.new()
	orch.setup(node, recipe, target, mode)
	return orch
