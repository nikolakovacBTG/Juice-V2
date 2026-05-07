## Creates and returns configured JuiceOrchestrator instances.
##
## Single static entry point for all orchestrator creation. Ensures every
## orchestrator is properly set up before the caller receives it.

# ============================================================================
# WHAT: Factory for JuiceOrchestrator instances.
# WHY:  Centralizes orchestrator creation so the setup() contract is always
#       fulfilled before the caller touches the orchestrator. PreviewDirector
#       and (in Phase 5) domain nodes both go through this factory.
# SYSTEM: Juice V2 Editor (addons/Juice_V2/Editor/)
# DOES NOT: Own the orchestrator after creation — caller owns lifetime.
#           Cache or pool orchestrators (Phase 5 concern if needed).
# ============================================================================

@tool
class_name JuiceOrchestratorFactory


# =============================================================================
# PUBLIC API
# =============================================================================

## Create a JuiceOrchestrator for the given node in the given mode.
##
## The returned orchestrator is already setup() and ready for play_in()/play_out().
## The CALLER owns the returned object and MUST call teardown() when done.
##
## Example (PREVIEW):
##   var orch := JuiceOrchestratorFactory.create(juice_node, JuiceOrchestrator.Mode.PREVIEW)
##   orch.play_in()
##   # ... later:
##   orch.teardown()
##
## Example (RUNTIME):
##   var orch := JuiceOrchestratorFactory.create(juice_node, JuiceOrchestrator.Mode.RUNTIME)
##   orch.play_in()
##   # on retrigger (zero allocation):
##   orch.reset()
##   # on node exit:
##   orch.teardown()
static func create(node: JuiceBase, mode: JuiceOrchestrator.Mode) -> JuiceOrchestrator:
	if node == null:
		JuiceLogger.warn(null, "OrchestratorFactory",
				"create() called with null node — returning null.", false)
		return null
	# Target resolution: parent is the default animation target for STACK mode.
	# In Phase 5 this will resolve via JuiceBase._target_node — using parent now
	# to match the Phase 4 delegating pattern without reaching into private state.
	var target: Node = node.get_parent()
	var recipe: JuiceRecipe = node.recipe
	var mode_str := "PREVIEW" if mode == JuiceOrchestrator.Mode.PREVIEW else "RUNTIME"
	JuiceLogger.log_info(node, "OrchestratorFactory",
			"create() | node=%s | mode=%s" % [node.name, mode_str],
			node.debug_enabled)
	var orch := JuiceOrchestrator.new()
	orch.setup(node, recipe, target, mode)
	return orch
