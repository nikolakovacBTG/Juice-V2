## JuiceTestSuite.gd
## ============================================================================
## WHAT: Base class for Juice V1 automated test suites.
## WHY: Provides assertion helpers, frame waiting, result tracking, and
##      a consistent interface for the test runner to orchestrate.
## SYSTEM: Tests (tests/)
## ============================================================================
class_name JuiceTestSuite
extends RefCounted

# --- Result tracking ---
var _test_name: String = ""
var _results: Array[Dictionary] = []
var _runner: Node = null
var _pass_count: int = 0
var _fail_count: int = 0

# =============================================================================
# PUBLIC API (called by runner)
# =============================================================================

## Override in subclass — unique name for this suite (used in filenames).
func get_suite_name() -> String:
	return "base"


## Override in subclass — return ordered list of test method names.
func get_test_methods() -> Array[String]:
	return []


## Run all tests in this suite. Returns array of result dicts.
func run(runner: Node) -> Array[Dictionary]:
	_runner = runner
	_results.clear()
	_pass_count = 0
	_fail_count = 0

	for method_name in get_test_methods():
		_test_name = method_name
		# Call the test method (may be async)
		await call(method_name)

	_runner = null
	return _results


## Get pass count after run.
func get_pass_count() -> int:
	return _pass_count


## Get fail count after run.
func get_fail_count() -> int:
	return _fail_count

# =============================================================================
# ASSERTION HELPERS
# =============================================================================

func assert_true(condition: bool, message: String) -> void:
	if condition:
		_pass(message)
	else:
		_fail(message)


func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)


func assert_equal(actual, expected, message: String) -> void:
	if actual == expected:
		_pass("%s (actual=%s)" % [message, actual])
	else:
		_fail("%s (actual=%s, expected=%s)" % [message, actual, expected])


func assert_approx_vec2(actual: Vector2, expected: Vector2, message: String, epsilon: float = 1.0) -> void:
	var dist := actual.distance_to(expected)
	if dist <= epsilon:
		_pass("%s (actual=%s, expected=%s)" % [message, actual, expected])
	else:
		_fail("%s (actual=%s, expected=%s, dist=%.4f > eps=%.4f)" % [message, actual, expected, dist, epsilon])


func assert_not_approx_vec2(actual: Vector2, expected: Vector2, message: String, min_dist: float = 1.0) -> void:
	var dist := actual.distance_to(expected)
	if dist > min_dist:
		_pass("%s (actual=%s, differs from %s by %.4f)" % [message, actual, expected, dist])
	else:
		_fail("%s (actual=%s too close to %s, dist=%.4f <= min=%.4f)" % [message, actual, expected, dist, min_dist])


func assert_approx_vec3(actual: Vector3, expected: Vector3, message: String, epsilon: float = 0.01) -> void:
	var dist := actual.distance_to(expected)
	if dist <= epsilon:
		_pass("%s (actual=%s, expected=%s)" % [message, actual, expected])
	else:
		_fail("%s (actual=%s, expected=%s, dist=%.4f > eps=%.4f)" % [message, actual, expected, dist, epsilon])


func assert_not_approx_vec3(actual: Vector3, expected: Vector3, message: String, min_dist: float = 0.01) -> void:
	var dist := actual.distance_to(expected)
	if dist > min_dist:
		_pass("%s (actual=%s, differs from %s by %.4f)" % [message, actual, expected, dist])
	else:
		_fail("%s (actual=%s too close to %s, dist=%.4f <= min=%.4f)" % [message, actual, expected, dist, min_dist])


func assert_approx_float(actual: float, expected: float, message: String, epsilon: float = 0.01) -> void:
	var diff := absf(actual - expected)
	if diff <= epsilon:
		_pass("%s (actual=%.4f, expected=%.4f)" % [message, actual, expected])
	else:
		_fail("%s (actual=%.4f, expected=%.4f, diff=%.4f > eps=%.4f)" % [message, actual, expected, diff, epsilon])


func assert_not_approx_float(actual: float, expected: float, message: String, min_diff: float = 0.01) -> void:
	var diff := absf(actual - expected)
	if diff > min_diff:
		_pass("%s (actual=%.4f, differs from %.4f by %.4f)" % [message, actual, expected, diff])
	else:
		_fail("%s (actual=%.4f too close to %.4f, diff=%.4f)" % [message, actual, expected, diff])


func assert_greater(actual: float, threshold: float, message: String) -> void:
	if actual > threshold:
		_pass("%s (actual=%.4f > %.4f)" % [message, actual, threshold])
	else:
		_fail("%s (actual=%.4f <= %.4f)" % [message, actual, threshold])

# =============================================================================
# FRAME / TIME HELPERS
# =============================================================================

## Wait for N process frames.
func wait_frames(count: int) -> void:
	for i in count:
		await _runner.get_tree().process_frame


## Wait for a duration in seconds.
func wait_seconds(seconds: float) -> void:
	await _runner.get_tree().create_timer(seconds).timeout

# =============================================================================
# NODE CREATION HELPERS
# =============================================================================

## Create a Button target for Control domain tests.
func create_control_target(label_text: String, parent: Node = null) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(120, 40)
	if parent:
		parent.add_child(btn)
	else:
		_runner.add_child(btn)
	return btn


## Create a JuiceControl node with a recipe containing a single effect.
func create_juice_control(effect: JuiceControlEffectBase, target: Control) -> JuiceControl:
	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	return juice


## Create a TransformControlJuiceEffect with common defaults.
func create_transform_control_effect() -> TransformControlJuiceEffect:
	var effect := TransformControlJuiceEffect.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.3
	return effect


## Create a Node2D target for 2D domain tests.
func create_2d_target(parent: Node = null) -> Node2D:
	var n2d := Node2D.new()
	if parent:
		parent.add_child(n2d)
	else:
		_runner.add_child(n2d)
	return n2d


## Create a Node3D target for 3D domain tests.
func create_3d_target(parent: Node = null) -> Node3D:
	var n3d := Node3D.new()
	if parent:
		parent.add_child(n3d)
	else:
		_runner.add_child(n3d)
	return n3d

# =============================================================================
# CLEANUP HELPERS
# =============================================================================

## Free a node and wait a frame for cleanup.
func cleanup(node: Node) -> void:
	node.queue_free()
	await wait_frames(2)

# =============================================================================
# INTERNAL
# =============================================================================

func _pass(message: String) -> void:
	_pass_count += 1
	_results.append({"test": _test_name, "status": "PASS", "message": message})


func _fail(message: String) -> void:
	_fail_count += 1
	_results.append({"test": _test_name, "status": "FAIL", "message": message})
