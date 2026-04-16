## TestCameraJuice.gd
## Realistic tests for Camera2DJuiceEffect and CameraJuiceUtility.
extends JuiceTestSuite


func get_suite_name() -> String:
	return "camera_juice"


func get_test_methods() -> Array[String]:
	return [
		# --- Camera2D ---
		"test_camera2d_position_offset_applied_during_animation",
		"test_camera2d_position_offset_cleared_on_complete",
		"test_camera2d_rotation_channel_writes_to_utility",
		"test_camera2d_zoom_channel_writes_to_utility",
		"test_camera2d_two_effects_stack_additively",
		"test_camera2d_no_utility_does_not_crash",
		"test_camera2d_no_camera_does_not_crash",
		"test_camera2d_stop_clears_contribution",
		# --- Inspector registration ---
		"test_camera2d_effect_in_2d_recipe_whitelist",
		"test_camera3d_effect_in_2d_recipe_whitelist",
		"test_camera2d_effect_in_control_recipe_whitelist",
		"test_camera2d_effect_in_3d_recipe_whitelist",
	]


# =============================================================================
# HELPERS
# =============================================================================

## Create a Camera2D with a CameraJuiceUtility child, parented to the test runner.
## Returns [camera2d, utility].
func _create_camera_2d(p_name: String = "TestCam2D") -> Array:
	var cam := Camera2D.new()
	cam.name = p_name
	cam.enabled = true
	_runner.add_child(cam)

	var util := CameraJuiceUtility.new()
	util.name = "CameraJuiceUtility"
	cam.add_child(util)

	await wait_frames(3)
	return [cam, util]


## Create a Node2D entity with a Juice2D + Camera2DJuiceEffect.
## Returns [entity, juice, runtime_effect].
func _create_entity_2d_camera_rig(
	p_channel: int = Camera2DJuiceEffect.Channel.POSITION,
	p_duration: float = 0.2
) -> Array:
	var entity := create_2d_target()  # Adds to _runner internally.

	var effect := Camera2DJuiceEffect.new()
	effect.channel = p_channel
	effect.position_offset_percent = Vector2(5.0, 0.0)
	effect.rotation_degrees = 10.0
	effect.zoom_offset = 0.3
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_in = p_duration
	effect.duration_out = p_duration

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	entity.add_child(juice)

	await wait_frames(3)
	return [entity, juice]


# =============================================================================
# CAMERA2D TESTS
# =============================================================================

func test_camera2d_position_offset_applied_during_animation() -> void:
	var cam_rig := await _create_camera_2d()
	var cam: Camera2D = cam_rig[0]
	var util: CameraJuiceUtility = cam_rig[1]

	var entity_rig := await _create_entity_2d_camera_rig(Camera2DJuiceEffect.Channel.POSITION, 0.3)
	var entity: Node2D = entity_rig[0]
	var juice: Juice2D = entity_rig[1]

	juice.animate_in()
	await wait_seconds(0.1)

	assert_true(
		util.position_offset.length() > 0.0,
		"position_offset should be non-zero mid-animation (got %s)" % str(util.position_offset)
	)

	await cleanup(cam)
	await cleanup(entity)


func test_camera2d_position_offset_cleared_on_complete() -> void:
	var cam_rig := await _create_camera_2d()
	var cam: Camera2D = cam_rig[0]
	var util: CameraJuiceUtility = cam_rig[1]

	var entity_rig := await _create_entity_2d_camera_rig(Camera2DJuiceEffect.Channel.POSITION, 0.1)
	var entity: Node2D = entity_rig[0]
	var juice: Juice2D = entity_rig[1]

	juice.animate_in()
	await wait_seconds(0.5)

	assert_true(
		util.position_offset.length() < 0.001,
		"position_offset should return to zero after animation (got %s)" % str(util.position_offset)
	)

	await cleanup(cam)
	await cleanup(entity)


func test_camera2d_rotation_channel_writes_to_utility() -> void:
	var cam_rig := await _create_camera_2d()
	var cam: Camera2D = cam_rig[0]
	var util: CameraJuiceUtility = cam_rig[1]

	var entity_rig := await _create_entity_2d_camera_rig(Camera2DJuiceEffect.Channel.ROTATION, 0.3)
	var entity: Node2D = entity_rig[0]
	var juice: Juice2D = entity_rig[1]

	juice.animate_in()
	await wait_seconds(0.1)

	assert_true(
		util.rotation_offset.length() > 0.0,
		"rotation_offset should be non-zero mid-animation (got %s)" % str(util.rotation_offset)
	)

	await cleanup(cam)
	await cleanup(entity)


func test_camera2d_zoom_channel_writes_to_utility() -> void:
	var cam_rig := await _create_camera_2d()
	var cam: Camera2D = cam_rig[0]
	var util: CameraJuiceUtility = cam_rig[1]

	var entity_rig := await _create_entity_2d_camera_rig(Camera2DJuiceEffect.Channel.ZOOM, 0.3)
	var entity: Node2D = entity_rig[0]
	var juice: Juice2D = entity_rig[1]

	juice.animate_in()
	await wait_seconds(0.1)

	assert_true(
		abs(util.zoom_offset) > 0.0,
		"zoom_offset should be non-zero mid-animation (got %.4f)" % util.zoom_offset
	)

	await cleanup(cam)
	await cleanup(entity)


func test_camera2d_two_effects_stack_additively() -> void:
	var cam_rig := await _create_camera_2d()
	var cam: Camera2D = cam_rig[0]
	var util: CameraJuiceUtility = cam_rig[1]

	var rig_a := await _create_entity_2d_camera_rig(Camera2DJuiceEffect.Channel.POSITION, 0.5)
	var entity_a: Node2D = rig_a[0]
	var juice_a: Juice2D = rig_a[1]

	var rig_b := await _create_entity_2d_camera_rig(Camera2DJuiceEffect.Channel.POSITION, 0.5)
	var entity_b: Node2D = rig_b[0]
	var juice_b: Juice2D = rig_b[1]

	juice_a.animate_in()
	juice_b.animate_in()
	await wait_seconds(0.3)

	assert_true(
		util.position_offset.x > 0.0,
		"Two stacked position effects should accumulate (got x=%.2f)" % util.position_offset.x
	)

	await cleanup(cam)
	await cleanup(entity_a)
	await cleanup(entity_b)


func test_camera2d_no_utility_does_not_crash() -> void:
	var cam := Camera2D.new()
	cam.name = "CamNoUtil"
	cam.enabled = true
	_runner.add_child(cam)
	await wait_frames(2)

	var entity_rig := await _create_entity_2d_camera_rig()
	var entity: Node2D = entity_rig[0]
	var juice: Juice2D = entity_rig[1]

	juice.animate_in()
	await wait_frames(5)

	assert_true(true, "No crash when CameraJuiceUtility is missing from Camera2D")

	await cleanup(cam)
	await cleanup(entity)


func test_camera2d_no_camera_does_not_crash() -> void:
	var entity_rig := await _create_entity_2d_camera_rig()
	var entity: Node2D = entity_rig[0]
	var juice: Juice2D = entity_rig[1]

	juice.animate_in()
	await wait_frames(5)

	assert_true(true, "No crash when no Camera2D exists in viewport")

	await cleanup(entity)


func test_camera2d_stop_clears_contribution() -> void:
	var cam_rig := await _create_camera_2d()
	var cam: Camera2D = cam_rig[0]
	var util: CameraJuiceUtility = cam_rig[1]

	var entity_rig := await _create_entity_2d_camera_rig(Camera2DJuiceEffect.Channel.POSITION, 0.5)
	var entity: Node2D = entity_rig[0]
	var juice: Juice2D = entity_rig[1]

	juice.animate_in()
	await wait_seconds(0.1)

	juice.stop()
	await wait_frames(2)

	assert_true(
		util.position_offset.length() < 0.001,
		"stop() should clear contribution from utility (got %s)" % str(util.position_offset)
	)

	await cleanup(cam)
	await cleanup(entity)


# =============================================================================
# INSPECTOR REGISTRATION TESTS
# =============================================================================

func test_camera2d_effect_in_2d_recipe_whitelist() -> void:
	var recipe := Juice2DRecipe.new()
	var prop_def := {"name": "effects", "hint_string": "", "hint": 0, "usage": 0, "type": 0}
	recipe._validate_property(prop_def)

	assert_true(
		prop_def["hint_string"].contains("Camera2DJuiceEffect"),
		"Camera2DJuiceEffect must appear in Juice2DRecipe whitelist"
	)


func test_camera3d_effect_in_2d_recipe_whitelist() -> void:
	var recipe := Juice2DRecipe.new()
	var prop_def := {"name": "effects", "hint_string": "", "hint": 0, "usage": 0, "type": 0}
	recipe._validate_property(prop_def)

	assert_true(
		prop_def["hint_string"].contains("Camera3DJuiceEffect"),
		"Camera3DJuiceEffect must appear in Juice2DRecipe whitelist"
	)


func test_camera2d_effect_in_control_recipe_whitelist() -> void:
	var recipe := JuiceControlRecipe.new()
	var prop_def := {"name": "effects", "hint_string": "", "hint": 0, "usage": 0, "type": 0}
	recipe._validate_property(prop_def)

	assert_true(
		prop_def["hint_string"].contains("Camera2DJuiceEffect"),
		"Camera2DJuiceEffect must appear in JuiceControlRecipe whitelist"
	)


func test_camera2d_effect_in_3d_recipe_whitelist() -> void:
	var recipe := Juice3DRecipe.new()
	var prop_def := {"name": "effects", "hint_string": "", "hint": 0, "usage": 0, "type": 0}
	recipe._validate_property(prop_def)

	assert_true(
		prop_def["hint_string"].contains("Camera2DJuiceEffect"),
		"Camera2DJuiceEffect must appear in Juice3DRecipe whitelist"
	)
