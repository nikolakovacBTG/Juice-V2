## TestAppearanceEffects.gd
## ============================================================================
## WHAT: Tests for Appearance2DJuiceEffect, AppearanceControlJuiceEffect,
##       and Appearance3DJuiceEffect — all three domains.
## WHY: Appearance is a controlled deviation (writes directly to modulate /
##      material). Tests verify effects apply visible changes and that
##      stop() / completion restores natural state.
## SYSTEM: Juice V1 test suite
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "appearance_effects"


func get_test_methods() -> Array[String]:
	return [
		# 2D
		"test_2d_fade_changes_alpha",
		"test_2d_fade_restores_after_completion",
		"test_2d_tint_changes_rgb",
		"test_2d_tint_restores_after_completion",
		"test_2d_overbright_exceeds_one",
		"test_2d_overbright_restores_after_completion",
		"test_2d_outline_installs_shader_material",
		"test_2d_outline_restores_after_completion",
		"test_2d_grayscale_installs_shader_material",
		"test_2d_grayscale_restores_after_completion",
		"test_2d_dissolve_installs_shader_material",
		"test_2d_dissolve_restores_after_completion",
		"test_2d_blend_mode_installs_canvas_item_material",
		"test_2d_blend_mode_restores_after_completion",
		# Control
		"test_ctrl_fade_changes_alpha",
		"test_ctrl_fade_restores_after_completion",
		"test_ctrl_tint_changes_rgb",
		"test_ctrl_tint_restores_after_completion",
		"test_ctrl_grayscale_installs_shader_material",
		"test_ctrl_grayscale_restores_after_completion",
		# 3D
		"test_3d_fade_changes_alpha",
		"test_3d_fade_restores_after_completion",
		"test_3d_tint_changes_albedo",
		"test_3d_grayscale_installs_shader_material",
		"test_3d_dissolve_installs_shader_material",
	]


# =============================================================================
# RIG HELPERS
# =============================================================================

func _create_2d_rig(effect: Juice2DEffectBase, duration: float = 0.2) -> Array:
	var target := Node2D.new()
	_runner.add_child(target)

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = duration

	await wait_frames(2)
	return [target, juice]


func _create_ctrl_rig(effect: JuiceControlEffectBase, duration: float = 0.2) -> Array:
	var target := Button.new()
	target.custom_minimum_size = Vector2(80, 30)
	_runner.add_child(target)

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = duration

	await wait_frames(2)
	return [target, juice]


func _create_3d_rig(effect: Juice3DEffectBase, duration: float = 0.2) -> Array:
	var target := Node3D.new()
	_runner.add_child(target)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mesh_inst.set_surface_override_material(0, mat)
	target.add_child(mesh_inst)

	var juice := Juice3D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := Juice3DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)

	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = duration

	await wait_frames(2)
	return [target, juice, mesh_inst]


# =============================================================================
# 2D TESTS
# =============================================================================

func test_2d_fade_changes_alpha() -> void:
	var effect := Appearance2DJuiceEffect.new()
	effect.effect_type = Appearance2DJuiceEffect.AppearanceEffect.FADE
	effect.fade_target_alpha = 0.0

	var rig := await _create_2d_rig(effect, 0.3)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.1)

	assert_true(target.modulate.a < 0.9, "FADE mid-animation: alpha must be < 0.9")
	await cleanup(target)


func test_2d_fade_restores_after_completion() -> void:
	var effect := Appearance2DJuiceEffect.new()
	effect.effect_type = Appearance2DJuiceEffect.AppearanceEffect.FADE
	effect.fade_target_alpha = 0.0

	var rig := await _create_2d_rig(effect, 0.15)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	target.modulate = Color(1, 1, 1, 1.0)

	juice.animate_in()
	await wait_seconds(0.5)
	juice.stop()

	assert_approx_float(target.modulate.a, 1.0, "FADE after completion: alpha must restore to 1.0")
	await cleanup(target)


func test_2d_tint_changes_rgb() -> void:
	var effect := Appearance2DJuiceEffect.new()
	effect.effect_type = Appearance2DJuiceEffect.AppearanceEffect.TINT
	effect.tint_color = Color(1, 0, 0, 1)
	effect.tint_blend = 1.0

	var rig := await _create_2d_rig(effect, 0.3)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	target.modulate = Color(1, 1, 1, 1)

	juice.animate_in()
	await wait_seconds(0.15)

	assert_true(target.modulate.g < 0.8, "TINT mid-animation: green must be reduced (tinting toward red)")
	await cleanup(target)


func test_2d_tint_restores_after_completion() -> void:
	var effect := Appearance2DJuiceEffect.new()
	effect.effect_type = Appearance2DJuiceEffect.AppearanceEffect.TINT
	effect.tint_color = Color(1, 0, 0, 1)
	effect.tint_blend = 1.0

	var rig := await _create_2d_rig(effect, 0.15)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	target.modulate = Color(1, 1, 1, 1)

	juice.animate_in()
	await wait_seconds(0.5)
	juice.stop()

	assert_approx_float(target.modulate.g, 1.0, "TINT after completion: green must restore to 1.0")
	await cleanup(target)


func test_2d_overbright_exceeds_one() -> void:
	var effect := Appearance2DJuiceEffect.new()
	effect.effect_type = Appearance2DJuiceEffect.AppearanceEffect.OVERBRIGHT
	effect.overbright_strength = 2.0

	var rig := await _create_2d_rig(effect, 0.3)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	target.modulate = Color(0.6, 0.6, 0.6, 1.0)

	juice.animate_in()
	await wait_seconds(0.15)

	assert_true(target.modulate.r > 0.6, "OVERBRIGHT mid-animation: r must exceed base 0.6")
	await cleanup(target)


func test_2d_overbright_restores_after_completion() -> void:
	var effect := Appearance2DJuiceEffect.new()
	effect.effect_type = Appearance2DJuiceEffect.AppearanceEffect.OVERBRIGHT
	effect.overbright_strength = 2.0

	var rig := await _create_2d_rig(effect, 0.15)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	target.modulate = Color(0.6, 0.6, 0.6, 1.0)

	juice.animate_in()
	await wait_seconds(0.5)
	juice.stop()

	assert_approx_float(target.modulate.r, 0.6, "OVERBRIGHT after completion: r must restore to 0.6")
	await cleanup(target)


func test_2d_outline_installs_shader_material() -> void:
	var effect := Appearance2DJuiceEffect.new()
	effect.effect_type = Appearance2DJuiceEffect.AppearanceEffect.OUTLINE
	effect.outline_color = Color.WHITE
	effect.outline_width = 3.0

	var rig := await _create_2d_rig(effect, 0.3)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.1)

	assert_true(target.material is ShaderMaterial, "OUTLINE mid-animation: ShaderMaterial must be installed")
	await cleanup(target)


func test_2d_outline_restores_after_completion() -> void:
	var effect := Appearance2DJuiceEffect.new()
	effect.effect_type = Appearance2DJuiceEffect.AppearanceEffect.OUTLINE
	effect.outline_color = Color.WHITE
	effect.outline_width = 3.0

	var rig := await _create_2d_rig(effect, 0.15)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.5)
	juice.stop()

	assert_true(target.material == null, "OUTLINE after completion: material must restore to null")
	await cleanup(target)


func test_2d_grayscale_installs_shader_material() -> void:
	var effect := Appearance2DJuiceEffect.new()
	effect.effect_type = Appearance2DJuiceEffect.AppearanceEffect.GRAYSCALE
	effect.grayscale_amount = 1.0

	var rig := await _create_2d_rig(effect, 0.3)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.1)

	assert_true(target.material is ShaderMaterial, "GRAYSCALE mid-animation: ShaderMaterial must be installed")
	var mat := target.material as ShaderMaterial
	assert_true(mat.get_shader_parameter("amount") > 0.0, "GRAYSCALE: shader amount must be > 0 during animation")
	await cleanup(target)


func test_2d_grayscale_restores_after_completion() -> void:
	var effect := Appearance2DJuiceEffect.new()
	effect.effect_type = Appearance2DJuiceEffect.AppearanceEffect.GRAYSCALE
	effect.grayscale_amount = 1.0

	var rig := await _create_2d_rig(effect, 0.15)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.5)
	juice.stop()

	assert_true(target.material == null, "GRAYSCALE after completion: material must restore to null")
	await cleanup(target)


func test_2d_dissolve_installs_shader_material() -> void:
	var effect := Appearance2DJuiceEffect.new()
	effect.effect_type = Appearance2DJuiceEffect.AppearanceEffect.DISSOLVE

	var rig := await _create_2d_rig(effect, 0.3)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.1)

	assert_true(target.material is ShaderMaterial, "DISSOLVE mid-animation: ShaderMaterial must be installed")
	var mat := target.material as ShaderMaterial
	assert_true(mat.get_shader_parameter("threshold") > 0.0, "DISSOLVE: threshold must be > 0 during animation")
	await cleanup(target)


func test_2d_dissolve_restores_after_completion() -> void:
	var effect := Appearance2DJuiceEffect.new()
	effect.effect_type = Appearance2DJuiceEffect.AppearanceEffect.DISSOLVE

	var rig := await _create_2d_rig(effect, 0.15)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.5)
	juice.stop()

	assert_true(target.material == null, "DISSOLVE after completion: material must restore to null")
	await cleanup(target)


func test_2d_blend_mode_installs_canvas_item_material() -> void:
	var effect := Appearance2DJuiceEffect.new()
	effect.effect_type = Appearance2DJuiceEffect.AppearanceEffect.BLEND_MODE
	effect.blend_mode_target = CanvasItemMaterial.BLEND_MODE_ADD

	var rig := await _create_2d_rig(effect, 0.3)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.1)

	assert_true(target.material is CanvasItemMaterial, "BLEND_MODE mid-animation: CanvasItemMaterial must be installed")
	var mat := target.material as CanvasItemMaterial
	assert_true(mat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "BLEND_MODE: blend_mode must match blend_mode_target")
	await cleanup(target)


func test_2d_blend_mode_restores_after_completion() -> void:
	var effect := Appearance2DJuiceEffect.new()
	effect.effect_type = Appearance2DJuiceEffect.AppearanceEffect.BLEND_MODE
	effect.blend_mode_target = CanvasItemMaterial.BLEND_MODE_ADD

	var rig := await _create_2d_rig(effect, 0.15)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]

	juice.animate_in()
	await wait_seconds(0.5)
	juice.stop()

	assert_true(target.material == null, "BLEND_MODE after completion: material must restore to null")
	await cleanup(target)


# =============================================================================
# CONTROL TESTS
# =============================================================================

func test_ctrl_fade_changes_alpha() -> void:
	var effect := AppearanceControlJuiceEffect.new()
	effect.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.FADE
	effect.fade_target_alpha = 0.0

	var rig := await _create_ctrl_rig(effect, 0.3)
	var target: Control = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	await wait_seconds(0.1)

	assert_true(target.modulate.a < 0.9, "Control FADE mid-animation: alpha must be < 0.9")
	await cleanup(target)


func test_ctrl_fade_restores_after_completion() -> void:
	var effect := AppearanceControlJuiceEffect.new()
	effect.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.FADE
	effect.fade_target_alpha = 0.0

	var rig := await _create_ctrl_rig(effect, 0.15)
	var target: Control = rig[0]
	var juice: JuiceControl = rig[1]
	target.modulate = Color(1, 1, 1, 1.0)

	juice.animate_in()
	await wait_seconds(0.5)
	juice.stop()

	assert_approx_float(target.modulate.a, 1.0, "Control FADE after completion: alpha must restore to 1.0")
	await cleanup(target)


func test_ctrl_tint_changes_rgb() -> void:
	var effect := AppearanceControlJuiceEffect.new()
	effect.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.TINT
	effect.tint_color = Color(0, 1, 0, 1)
	effect.tint_blend = 1.0

	var rig := await _create_ctrl_rig(effect, 0.3)
	var target: Control = rig[0]
	var juice: JuiceControl = rig[1]
	target.modulate = Color(1, 1, 1, 1)

	juice.animate_in()
	await wait_seconds(0.15)

	assert_true(target.modulate.r < 0.8, "Control TINT mid-animation: red must be reduced (tinting toward green)")
	await cleanup(target)


func test_ctrl_tint_restores_after_completion() -> void:
	var effect := AppearanceControlJuiceEffect.new()
	effect.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.TINT
	effect.tint_color = Color(0, 1, 0, 1)
	effect.tint_blend = 1.0

	var rig := await _create_ctrl_rig(effect, 0.15)
	var target: Control = rig[0]
	var juice: JuiceControl = rig[1]
	target.modulate = Color(1, 1, 1, 1)

	juice.animate_in()
	await wait_seconds(0.5)
	juice.stop()

	assert_approx_float(target.modulate.r, 1.0, "Control TINT after completion: red must restore to 1.0")
	await cleanup(target)


func test_ctrl_grayscale_installs_shader_material() -> void:
	var effect := AppearanceControlJuiceEffect.new()
	effect.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.GRAYSCALE
	effect.grayscale_amount = 1.0

	var rig := await _create_ctrl_rig(effect, 0.3)
	var target: Control = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	await wait_seconds(0.1)

	assert_true(target.material is ShaderMaterial, "Control GRAYSCALE mid-animation: ShaderMaterial must be installed")
	await cleanup(target)


func test_ctrl_grayscale_restores_after_completion() -> void:
	var effect := AppearanceControlJuiceEffect.new()
	effect.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.GRAYSCALE
	effect.grayscale_amount = 1.0

	var rig := await _create_ctrl_rig(effect, 0.15)
	var target: Control = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	await wait_seconds(0.5)
	juice.stop()

	assert_true(target.material == null, "Control GRAYSCALE after completion: material must restore to null")
	await cleanup(target)


# =============================================================================
# 3D TESTS
# =============================================================================

func test_3d_fade_changes_alpha() -> void:
	var effect := Appearance3DJuiceEffect.new()
	effect.effect_type = Appearance3DJuiceEffect.AppearanceEffect.FADE
	effect.fade_target_alpha = 0.0

	var rig := await _create_3d_rig(effect, 0.3)
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]
	var mesh_inst: MeshInstance3D = rig[2]

	juice.animate_in()
	await wait_seconds(0.1)

	var mat := mesh_inst.get_surface_override_material(0) as StandardMaterial3D
	assert_true(mat != null, "3D FADE mid-animation: StandardMaterial3D must be installed")
	assert_true(mat.albedo_color.a < 0.9, "3D FADE mid-animation: alpha must be < 0.9")
	await cleanup(target)


func test_3d_fade_restores_after_completion() -> void:
	var effect := Appearance3DJuiceEffect.new()
	effect.effect_type = Appearance3DJuiceEffect.AppearanceEffect.FADE
	effect.fade_target_alpha = 0.0

	var rig := await _create_3d_rig(effect, 0.15)
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]
	var mesh_inst: MeshInstance3D = rig[2]
	var original_mat := mesh_inst.get_surface_override_material(0)

	juice.animate_in()
	await wait_seconds(0.5)
	juice.stop()

	var restored := mesh_inst.get_surface_override_material(0)
	assert_true(restored == original_mat, "3D FADE after completion: original material must be restored")
	await cleanup(target)


func test_3d_tint_changes_albedo() -> void:
	var effect := Appearance3DJuiceEffect.new()
	effect.effect_type = Appearance3DJuiceEffect.AppearanceEffect.TINT
	effect.tint_color = Color(1, 0, 0, 1)
	effect.tint_blend = 1.0

	var rig := await _create_3d_rig(effect, 0.3)
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]
	var mesh_inst: MeshInstance3D = rig[2]

	juice.animate_in()
	await wait_seconds(0.15)

	var mat := mesh_inst.get_surface_override_material(0) as StandardMaterial3D
	assert_true(mat != null, "3D TINT mid-animation: material must exist")
	assert_true(mat.albedo_color.g < 0.8, "3D TINT mid-animation: green must be reduced (tinting toward red)")
	await cleanup(target)


func test_3d_grayscale_installs_shader_material() -> void:
	var effect := Appearance3DJuiceEffect.new()
	effect.effect_type = Appearance3DJuiceEffect.AppearanceEffect.GRAYSCALE
	effect.grayscale_amount = 1.0

	var rig := await _create_3d_rig(effect, 0.3)
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]
	var mesh_inst: MeshInstance3D = rig[2]

	juice.animate_in()
	await wait_seconds(0.1)

	var mat := mesh_inst.get_surface_override_material(0)
	assert_true(mat is ShaderMaterial, "3D GRAYSCALE mid-animation: ShaderMaterial must be installed")
	await cleanup(target)


func test_3d_dissolve_installs_shader_material() -> void:
	var effect := Appearance3DJuiceEffect.new()
	effect.effect_type = Appearance3DJuiceEffect.AppearanceEffect.DISSOLVE

	var rig := await _create_3d_rig(effect, 0.3)
	var target: Node3D = rig[0]
	var juice: Juice3D = rig[1]
	var mesh_inst: MeshInstance3D = rig[2]

	juice.animate_in()
	await wait_seconds(0.1)

	var mat := mesh_inst.get_surface_override_material(0)
	assert_true(mat is ShaderMaterial, "3D DISSOLVE mid-animation: ShaderMaterial must be installed")
	await cleanup(target)
