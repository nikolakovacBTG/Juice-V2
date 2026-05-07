## TestOrchestratorFactory.gd
## ============================================================================
## WHAT: Unit tests for JuiceOrchestratorFactory — creation contract.
## WHY:  Factory is the single creation entry point. Tests verify it returns a
##       valid, correctly-configured orchestrator for both modes.
## SYSTEM: Juice V2 Editor (addons/Juice_V2/Editor/)
## DOES NOT: Test orchestrator behavior post-creation (see TestOrchestrator).
## ============================================================================

extends JuiceTestSuite


func get_suite_name() -> String:
	return "orchestrator_factory"


func get_test_methods() -> Array[String]:
	return [
		"test_create_returns_orchestrator_instance",
		"test_create_preview_mode_stored",
		"test_create_runtime_mode_stored",
		"test_create_stores_node_reference",
	]


func test_create_returns_orchestrator_instance() -> void:
	var parent := Control.new()
	_runner.add_child(parent)
	var juice := JuiceControl.new()
	parent.add_child(juice)
	await wait_frames(2)

	var orch := JuiceOrchestratorFactory.create(juice, juice.recipe, juice._target_node, JuiceOrchestrator.Mode.PREVIEW)
	juice.add_child(orch)  # factory creates only; caller adds to scene tree

	assert_true(orch is JuiceOrchestrator, "Factory returns JuiceOrchestrator")
	assert_true(is_instance_valid(orch), "Factory result is immediately valid")

	orch.teardown()
	parent.queue_free()


func test_create_preview_mode_stored() -> void:
	var parent := Control.new()
	_runner.add_child(parent)
	var juice := JuiceControl.new()
	parent.add_child(juice)
	await wait_frames(2)

	var orch := JuiceOrchestratorFactory.create(juice, juice.recipe, juice._target_node, JuiceOrchestrator.Mode.PREVIEW)
	juice.add_child(orch)  # factory creates only; caller adds to scene tree

	assert_true(orch._mode == JuiceOrchestrator.Mode.PREVIEW, "PREVIEW mode stored by factory")

	orch.teardown()
	parent.queue_free()


func test_create_runtime_mode_stored() -> void:
	var parent := Control.new()
	_runner.add_child(parent)
	var juice := JuiceControl.new()
	parent.add_child(juice)
	await wait_frames(2)

	var orch := JuiceOrchestratorFactory.create(juice, juice.recipe, juice._target_node, JuiceOrchestrator.Mode.RUNTIME)
	juice.add_child(orch)  # factory creates only; caller adds to scene tree

	assert_true(orch._mode == JuiceOrchestrator.Mode.RUNTIME, "RUNTIME mode stored by factory")

	orch.teardown()
	parent.queue_free()


func test_create_stores_node_reference() -> void:
	var parent := Control.new()
	_runner.add_child(parent)
	var juice := JuiceControl.new()
	parent.add_child(juice)
	await wait_frames(2)

	var orch := JuiceOrchestratorFactory.create(juice, juice.recipe, juice._target_node, JuiceOrchestrator.Mode.PREVIEW)
	juice.add_child(orch)  # factory creates only; caller adds to scene tree

	assert_true(orch._node == juice, "Factory stores node reference in orchestrator")

	orch.teardown()
	parent.queue_free()
