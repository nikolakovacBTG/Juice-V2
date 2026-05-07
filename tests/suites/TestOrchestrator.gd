## TestOrchestrator.gd
## ============================================================================
## WHAT: Unit tests for JuiceOrchestrator lifecycle — PREVIEW and RUNTIME modes.
## WHY:  Orchestrator is the animation lifecycle container in V2. These tests
##       verify the Mode contract, teardown/free behavior, and zero-alloc reset.
## SYSTEM: Juice V2 Editor (addons/Juice_V2/Editor/)
## DOES NOT: Test the tick loop (owned by JuiceBase). Test PreviewDirector wiring.
## ============================================================================

extends JuiceTestSuite


func get_suite_name() -> String:
	return "orchestrator"


func get_test_methods() -> Array[String]:
	return [
		"test_setup_stores_node_and_mode_preview",
		"test_setup_stores_mode_runtime",
		"test_teardown_frees_orchestrator",
		"test_preview_play_in_does_not_crash",
		"test_runtime_stop_keeps_orchestrator_alive",
		"test_runtime_teardown_frees_orchestrator",
		"test_runtime_reset_does_not_crash",
	]


# =============================================================================
# TESTS — Setup & Mode
# =============================================================================

func test_setup_stores_node_and_mode_preview() -> void:
	var parent := Control.new()
	_runner.add_child(parent)
	var juice := JuiceControl.new()
	parent.add_child(juice)
	await wait_frames(2)

	var orch := JuiceOrchestrator.new()
	orch.setup(juice, null, parent, JuiceOrchestrator.Mode.PREVIEW)

	assert_true(orch._node == juice, "Node reference stored")
	assert_true(orch._mode == JuiceOrchestrator.Mode.PREVIEW, "Mode stored as PREVIEW")

	orch.teardown()
	await wait_frames(1)
	parent.queue_free()


func test_setup_stores_mode_runtime() -> void:
	var parent := Control.new()
	_runner.add_child(parent)
	var juice := JuiceControl.new()
	parent.add_child(juice)
	await wait_frames(2)

	var orch := JuiceOrchestrator.new()
	orch.setup(juice, null, parent, JuiceOrchestrator.Mode.RUNTIME)

	assert_true(orch._mode == JuiceOrchestrator.Mode.RUNTIME, "Mode stored as RUNTIME")

	orch.teardown()
	await wait_frames(1)
	parent.queue_free()


# =============================================================================
# TESTS — PREVIEW Lifecycle
# =============================================================================

func test_teardown_frees_orchestrator() -> void:
	var parent := Control.new()
	_runner.add_child(parent)
	var juice := JuiceControl.new()
	parent.add_child(juice)
	await wait_frames(2)

	var orch := JuiceOrchestratorFactory.create(juice, JuiceOrchestrator.Mode.PREVIEW)

	assert_true(is_instance_valid(orch), "Orchestrator valid before teardown")
	orch.teardown()
	await wait_frames(1)  # free() is deferred — must wait one frame
	assert_false(is_instance_valid(orch), "Orchestrator freed after teardown")

	parent.queue_free()


func test_preview_play_in_does_not_crash() -> void:
	var parent := Control.new()
	_runner.add_child(parent)
	var juice := JuiceControl.new()
	parent.add_child(juice)
	await wait_frames(2)

	var orch := JuiceOrchestratorFactory.create(juice, JuiceOrchestrator.Mode.PREVIEW)
	orch.play_in()  # delegates to animate_in() — must not crash

	assert_true(is_instance_valid(orch), "Orchestrator still valid after play_in()")
	orch.teardown()
	await wait_frames(1)
	parent.queue_free()


# =============================================================================
# TESTS — RUNTIME Lifecycle
# =============================================================================

func test_runtime_stop_keeps_orchestrator_alive() -> void:
	var parent := Control.new()
	_runner.add_child(parent)
	var juice := JuiceControl.new()
	parent.add_child(juice)
	await wait_frames(2)

	var orch := JuiceOrchestratorFactory.create(juice, JuiceOrchestrator.Mode.RUNTIME)
	orch.stop()

	assert_true(is_instance_valid(orch), "RUNTIME orchestrator alive after stop()")

	orch.teardown()
	await wait_frames(1)
	parent.queue_free()


func test_runtime_teardown_frees_orchestrator() -> void:
	var parent := Control.new()
	_runner.add_child(parent)
	var juice := JuiceControl.new()
	parent.add_child(juice)
	await wait_frames(2)

	var orch := JuiceOrchestratorFactory.create(juice, JuiceOrchestrator.Mode.RUNTIME)
	orch.teardown()
	await wait_frames(1)  # free() is deferred — must wait one frame
	assert_false(is_instance_valid(orch), "RUNTIME orchestrator freed after teardown()")

	parent.queue_free()


func test_runtime_reset_does_not_crash() -> void:
	var parent := Control.new()
	_runner.add_child(parent)
	var juice := JuiceControl.new()
	parent.add_child(juice)
	await wait_frames(2)

	var orch := JuiceOrchestratorFactory.create(juice, JuiceOrchestrator.Mode.RUNTIME)
	orch.stop()
	orch.reset()  # zero-alloc retrigger — must not crash

	assert_true(is_instance_valid(orch), "RUNTIME orchestrator still alive after reset()")

	orch.teardown()
	await wait_frames(1)
	parent.queue_free()
