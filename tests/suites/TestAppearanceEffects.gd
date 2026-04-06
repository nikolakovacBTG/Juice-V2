## TestAppearanceEffects.gd
## ============================================================================
## WHAT: Comprehensive tests for Appearance effects across all three domains
##       (2D, Control, 3D) — FADE, TINT, OVERBRIGHT, OUTLINE.
## WHY: Validates the Appearance Architecture Plan implementation: From/To API,
##      Phase B sibling stacking, Phase C flicker redesign, OutlineFlickerTarget.
## SYSTEM: Juice V1 test suite
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "appearance_effects"


func get_test_methods() -> Array[String]:
	return [
		# ---- 2D FADE ----
		"test_2d_fade_changes_alpha",
		"test_2d_fade_restores_after_stop",
		"test_2d_fade_from_custom_to_custom",
		"test_2d_fade_from_self_to_custom",
		# ---- 2D TINT ----
		"test_2d_tint_changes_rgb",
		"test_2d_tint_restores_after_stop",
		"test_2d_tint_blend_zero_is_identity",
		"test_2d_tint_blend_one_is_full_color",
		# ---- 2D OVERBRIGHT ----
		"test_2d_overbright_exceeds_one",
		"test_2d_overbright_restores_after_stop",
		"test_2d_overbright_from_1_to_2",
		# ---- 2D OUTLINE ----
		"test_2d_outline_installs_shader_material",
		"test_2d_outline_restores_after_stop",
		# ---- 2D STACKING (same recipe) ----
		"test_2d_fade_plus_tint_both_apply",
		# ---- 2D STACKING (sibling Juice nodes) ----
		"test_2d_sibling_fade_nodes_both_contribute",
		"test_2d_sibling_first_stops_second_continues",
		# ---- 2D FLICKER ----
		"test_2d_flicker_random_varies_fade_output",
		"test_2d_flicker_scales_with_progress",
		# ---- 2D STOP/RESTART ----
		"test_2d_stop_then_reanimate_clean",
		# ---- CONTROL FADE ----
		"test_ctrl_fade_changes_alpha",
		"test_ctrl_fade_restores_after_stop",
		"test_ctrl_fade_writes_self_modulate_not_modulate",
		# ---- CONTROL TINT ----
		"test_ctrl_tint_changes_rgb",
		"test_ctrl_tint_restores_after_stop",
		# ---- CONTROL OVERBRIGHT ----
		"test_ctrl_overbright_exceeds_one",
		"test_ctrl_overbright_restores_after_stop",
		# ---- CONTROL OUTLINE ----
		"test_ctrl_outline_installs_shader_material",
		"test_ctrl_outline_restores_after_stop",
		# ---- CONTROL STACKING (sibling) ----
		"test_ctrl_sibling_fade_stack",
		"test_ctrl_sibling_first_stops_second_continues",
		# ---- CONTROL FLICKER ----
		"test_ctrl_flicker_random_varies_fade_output",
		# ---- 3D FADE ----
		"test_3d_fade_changes_alpha",
		"test_3d_fade_restores_after_stop",
		# ---- 3D TINT ----
		"test_3d_tint_changes_albedo",
		"test_3d_tint_restores_after_stop",
		# ---- 3D OVERBRIGHT ----
		"test_3d_overbright_exceeds_one",
		"test_3d_overbright_restores_after_stop",
		# ---- 3D STACKING (sibling) ----
		"test_3d_sibling_fade_stack",
		"test_3d_sibling_first_stops_second_continues",
		# ---- 3D FLICKER ----
		"test_3d_flicker_random_varies_fade_alpha",
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


func _create_2d_multi_rig(effects: Array, duration: float = 0.2) -> Array:
	var target := Node2D.new()
	_runner.add_child(target)
	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := Juice2DRecipe.new()
	for eff in effects:
		eff.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
		eff.duration_in = duration
		recipe.effects.append(eff)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)
	return [target, juice]


func _create_2d_sibling_rig(eff_a: Juice2DEffectBase, eff_b: Juice2DEffectBase, dur: float = 0.3) -> Array:
	var target := Node2D.new()
	_runner.add_child(target)
	eff_a.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	eff_a.duration_in = dur
	eff_b.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	eff_b.duration_in = dur
	var juice_a := Juice2D.new()
	juice_a.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe_a := Juice2DRecipe.new()
	recipe_a.effects.append(eff_a)
	juice_a.recipe = recipe_a
	target.add_child(juice_a)
	var juice_b := Juice2D.new()
	juice_b.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe_b := Juice2DRecipe.new()
	recipe_b.effects.append(eff_b)
	juice_b.recipe = recipe_b
	target.add_child(juice_b)
	await wait_frames(2)
	return [target, juice_a, juice_b]


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


func _create_ctrl_sibling_rig(eff_a: JuiceControlEffectBase, eff_b: JuiceControlEffectBase, dur: float = 0.3) -> Array:
	var target := Button.new()
	target.custom_minimum_size = Vector2(80, 30)
	_runner.add_child(target)
	eff_a.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	eff_a.duration_in = dur
	eff_b.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	eff_b.duration_in = dur
	var juice_a := JuiceControl.new()
	juice_a.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe_a := JuiceControlRecipe.new()
	recipe_a.effects.append(eff_a)
	juice_a.recipe = recipe_a
	target.add_child(juice_a)
	var juice_b := JuiceControl.new()
	juice_b.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe_b := JuiceControlRecipe.new()
	recipe_b.effects.append(eff_b)
	juice_b.recipe = recipe_b
	target.add_child(juice_b)
	await wait_frames(2)
	return [target, juice_a, juice_b]


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


func _create_3d_sibling_rig(eff_a: Juice3DEffectBase, eff_b: Juice3DEffectBase, dur: float = 0.3) -> Array:
	var target := Node3D.new()
	_runner.add_child(target)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mesh_inst.set_surface_override_material(0, mat)
	target.add_child(mesh_inst)
	eff_a.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	eff_a.duration_in = dur
	eff_b.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	eff_b.duration_in = dur
	var juice_a := Juice3D.new()
	juice_a.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe_a := Juice3DRecipe.new()
	recipe_a.effects.append(eff_a)
	juice_a.recipe = recipe_a
	target.add_child(juice_a)
	var juice_b := Juice3D.new()
	juice_b.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe_b := Juice3DRecipe.new()
	recipe_b.effects.append(eff_b)
	juice_b.recipe = recipe_b
	target.add_child(juice_b)
	await wait_frames(2)
	return [target, juice_a, juice_b, mesh_inst]


# =============================================================================
# EFFECT FACTORY HELPERS
# =============================================================================

func _make_2d_fade(to_alpha: float = 0.0) -> Appearance2DJuiceEffect:
	var e := Appearance2DJuiceEffect.new()
	e.effect_type = Appearance2DJuiceEffect.AppearanceEffect.FADE
	e.fade_target_alpha = to_alpha
	return e

func _make_2d_tint(color: Color = Color(1, 0, 0, 1), blend: float = 1.0) -> Appearance2DJuiceEffect:
	var e := Appearance2DJuiceEffect.new()
	e.effect_type = Appearance2DJuiceEffect.AppearanceEffect.TINT
	e.tint_color = color
	e.tint_blend = blend
	return e

func _make_2d_overbright(strength: float = 2.0) -> Appearance2DJuiceEffect:
	var e := Appearance2DJuiceEffect.new()
	e.effect_type = Appearance2DJuiceEffect.AppearanceEffect.OVERBRIGHT
	e.overbright_strength = strength
	return e

func _make_ctrl_fade(to_alpha: float = 0.0) -> AppearanceControlJuiceEffect:
	var e := AppearanceControlJuiceEffect.new()
	e.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.FADE
	e.fade_target_alpha = to_alpha
	return e

func _make_ctrl_tint(color: Color = Color(0, 1, 0, 1), blend: float = 1.0) -> AppearanceControlJuiceEffect:
	var e := AppearanceControlJuiceEffect.new()
	e.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.TINT
	e.tint_color = color
	e.tint_blend = blend
	return e

func _make_ctrl_overbright(strength: float = 2.0) -> AppearanceControlJuiceEffect:
	var e := AppearanceControlJuiceEffect.new()
	e.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.OVERBRIGHT
	e.overbright_strength = strength
	return e

func _make_3d_fade(to_alpha: float = 0.0) -> Appearance3DJuiceEffect:
	var e := Appearance3DJuiceEffect.new()
	e.effect_type = Appearance3DJuiceEffect.AppearanceEffect.FADE
	e.fade_target_alpha = to_alpha
	return e

func _make_3d_tint(color: Color = Color(1, 0, 0, 1), blend: float = 1.0) -> Appearance3DJuiceEffect:
	var e := Appearance3DJuiceEffect.new()
	e.effect_type = Appearance3DJuiceEffect.AppearanceEffect.TINT
	e.tint_color = color
	e.tint_blend = blend
	return e

func _make_3d_overbright(strength: float = 2.0) -> Appearance3DJuiceEffect:
	var e := Appearance3DJuiceEffect.new()
	e.effect_type = Appearance3DJuiceEffect.AppearanceEffect.OVERBRIGHT
	e.overbright_strength = strength
	return e


# =============================================================================
# 2D — FADE
# =============================================================================

func test_2d_fade_changes_alpha() -> void:
	var rig := await _create_2d_rig(_make_2d_fade(), 0.3)
	var target: Node2D = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.1)
	assert_true(target.modulate.a < 0.9, "2D FADE mid: alpha < 0.9")
	await cleanup(target)

func test_2d_fade_restores_after_stop() -> void:
	var rig := await _create_2d_rig(_make_2d_fade(), 0.15)
	var target: Node2D = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.5)
	rig[1].stop()
	assert_approx_float(target.modulate.a, 1.0, "2D FADE restore: alpha==1.0")
	await cleanup(target)

func test_2d_fade_from_custom_to_custom() -> void:
	var e := _make_2d_fade(0.3)
	e.from_reference = Appearance2DJuiceEffect.AppearanceReference.CUSTOM
	e.from_alpha = 0.8
	e.to_reference = Appearance2DJuiceEffect.AppearanceReference.CUSTOM
	var rig := await _create_2d_rig(e, 0.3)
	var target: Node2D = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.15)
	# Mid-animation alpha should be between from(0.8) and to(0.3)
	assert_true(target.modulate.a < 0.8, "2D FADE custom->custom: alpha < from(0.8)")
	assert_true(target.modulate.a > 0.3, "2D FADE custom->custom: alpha > to(0.3)")
	await cleanup(target)

func test_2d_fade_from_self_to_custom() -> void:
	var e := _make_2d_fade(0.0)
	e.from_reference = Appearance2DJuiceEffect.AppearanceReference.SELF
	var rig := await _create_2d_rig(e, 0.3)
	var target: Node2D = rig[0]
	# SELF captures from target.modulate.a which should be 1.0
	rig[1].animate_in()
	await wait_seconds(0.1)
	assert_true(target.modulate.a < 0.9, "2D FADE self->custom: alpha decreasing")
	await cleanup(target)


# =============================================================================
# 2D — TINT
# =============================================================================

func test_2d_tint_changes_rgb() -> void:
	var rig := await _create_2d_rig(_make_2d_tint(), 0.3)
	var target: Node2D = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.15)
	assert_true(target.modulate.g < 0.8, "2D TINT mid: green reduced (tinting red)")
	await cleanup(target)

func test_2d_tint_restores_after_stop() -> void:
	var rig := await _create_2d_rig(_make_2d_tint(), 0.15)
	var target: Node2D = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.5)
	rig[1].stop()
	assert_approx_float(target.modulate.g, 1.0, "2D TINT restore: green==1.0")
	await cleanup(target)

func test_2d_tint_blend_zero_is_identity() -> void:
	var e := _make_2d_tint(Color.RED, 0.0)
	var rig := await _create_2d_rig(e, 0.3)
	var target: Node2D = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.15)
	# blend=0 means no tint applied even at full progress — modulate stays WHITE
	assert_approx_float(target.modulate.g, 1.0, "2D TINT blend=0: g stays 1.0", 0.05)
	await cleanup(target)

func test_2d_tint_blend_one_is_full_color() -> void:
	var e := _make_2d_tint(Color(1, 0, 0, 1), 1.0)
	var rig := await _create_2d_rig(e, 0.2)
	var target: Node2D = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.5)
	# At progress=1 with blend=1, modulate.g should be near 0 (full red tint)
	assert_true(target.modulate.g < 0.15, "2D TINT blend=1 at end: g near 0")
	await cleanup(target)


# =============================================================================
# 2D — OVERBRIGHT
# =============================================================================

func test_2d_overbright_exceeds_one() -> void:
	var rig := await _create_2d_rig(_make_2d_overbright(), 0.3)
	var target: Node2D = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.15)
	assert_true(target.modulate.r > 1.0, "2D OVERBRIGHT mid: r > 1.0")
	await cleanup(target)

func test_2d_overbright_restores_after_stop() -> void:
	var rig := await _create_2d_rig(_make_2d_overbright(), 0.15)
	var target: Node2D = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.5)
	rig[1].stop()
	assert_approx_float(target.modulate.r, 1.0, "2D OVERBRIGHT restore: r==1.0")
	await cleanup(target)

func test_2d_overbright_from_1_to_2() -> void:
	var e := _make_2d_overbright(2.0)
	e.from_brightness = 1.0
	e.from_reference = Appearance2DJuiceEffect.AppearanceReference.CUSTOM
	var rig := await _create_2d_rig(e, 0.3)
	var target: Node2D = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.15)
	assert_true(target.modulate.r > 1.0, "2D OVERBRIGHT 1->2: r increasing above 1.0")
	assert_true(target.modulate.r < 2.1, "2D OVERBRIGHT 1->2: r not beyond 2.0")
	await cleanup(target)


# =============================================================================
# 2D — OUTLINE
# =============================================================================

func test_2d_outline_installs_shader_material() -> void:
	var e := Appearance2DJuiceEffect.new()
	e.effect_type = Appearance2DJuiceEffect.AppearanceEffect.OUTLINE
	e.outline_color = Color.WHITE
	e.outline_width = 3.0
	var rig := await _create_2d_rig(e, 0.3)
	var target: Node2D = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.1)
	assert_true(target.material is ShaderMaterial, "2D OUTLINE: ShaderMaterial installed")
	await cleanup(target)

func test_2d_outline_restores_after_stop() -> void:
	var e := Appearance2DJuiceEffect.new()
	e.effect_type = Appearance2DJuiceEffect.AppearanceEffect.OUTLINE
	e.outline_color = Color.WHITE
	e.outline_width = 3.0
	var rig := await _create_2d_rig(e, 0.15)
	var target: Node2D = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.5)
	rig[1].stop()
	assert_true(target.material == null, "2D OUTLINE restore: material null")
	await cleanup(target)


# =============================================================================
# 2D — STACKING (same recipe)
# =============================================================================

func test_2d_fade_plus_tint_both_apply() -> void:
	var fade_e := _make_2d_fade(0.3)
	var tint_e := _make_2d_tint(Color(1, 0, 0, 1), 1.0)
	var rig := await _create_2d_multi_rig([fade_e, tint_e], 0.3)
	var target: Node2D = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.15)
	# Both effects should be visible: alpha < 1 (fade) AND green < 1 (tint)
	assert_true(target.modulate.a < 0.9, "2D stack fade+tint: alpha < 0.9")
	assert_true(target.modulate.g < 0.8, "2D stack fade+tint: green < 0.8")
	await cleanup(target)


# =============================================================================
# 2D — STACKING (sibling Juice nodes)
# =============================================================================

func test_2d_sibling_fade_nodes_both_contribute() -> void:
	var eff_a := _make_2d_fade(0.5)
	var eff_b := _make_2d_fade(0.5)
	var rig := await _create_2d_sibling_rig(eff_a, eff_b, 0.3)
	var target: Node2D = rig[0]
	var juice_a: Juice2D = rig[1]
	var juice_b: Juice2D = rig[2]
	juice_a.animate_in()
	juice_b.animate_in()
	await wait_seconds(0.5)
	# Both fading to 0.5 should multiply: ~0.5 * 0.5 = 0.25
	assert_true(target.modulate.a < 0.5, "2D sibling fade: combined alpha < 0.5 (multiplicative)")
	await cleanup(target)

func test_2d_sibling_first_stops_second_continues() -> void:
	var eff_a := _make_2d_fade(0.3)
	var eff_b := _make_2d_fade(0.3)
	var rig := await _create_2d_sibling_rig(eff_a, eff_b, 0.3)
	var target: Node2D = rig[0]
	var juice_a: Juice2D = rig[1]
	var juice_b: Juice2D = rig[2]
	juice_a.animate_in()
	juice_b.animate_in()
	await wait_seconds(0.15)
	# Stop first, second continues
	juice_a.stop()
	await wait_seconds(0.3)
	# Second should still be fading
	assert_true(target.modulate.a < 0.9, "2D sibling: after A stops, B still fading")
	juice_b.stop()
	await wait_frames(5)
	assert_approx_float(target.modulate.a, 1.0, "2D sibling: after both stop, alpha restored")
	await cleanup(target)


# =============================================================================
# 2D — FLICKER
# =============================================================================

func test_2d_flicker_random_varies_fade_output() -> void:
	var e := _make_2d_fade(0.0)
	e.flicker_mode = Appearance2DJuiceEffect.FlickerMode.RANDOM
	e.flicker_min = 0.0
	e.flicker_max = 1.0
	e.flicker_rate = 10.0
	var rig := await _create_2d_rig(e, 0.5)
	var target: Node2D = rig[0]
	rig[1].animate_in()
	# Collect samples over 0.5s
	var samples: Array[float] = []
	for i in 10:
		await wait_seconds(0.05)
		samples.append(target.modulate.a)
	# Check variance: not all samples should be identical
	var all_same := true
	for i in range(1, samples.size()):
		if absf(samples[i] - samples[0]) > 0.01:
			all_same = false
			break
	assert_false(all_same, "2D flicker FADE: alpha varies over time (not constant)")
	await cleanup(target)

func test_2d_flicker_scales_with_progress() -> void:
	var e := _make_2d_fade(0.0)
	e.flicker_mode = Appearance2DJuiceEffect.FlickerMode.RANDOM
	e.flicker_min = 0.0
	e.flicker_max = 1.0
	e.flicker_rate = 10.0
	var rig := await _create_2d_rig(e, 2.0)
	var target: Node2D = rig[0]
	rig[1].animate_in()
	# At very start (progress near 0), flicker * progress ≈ 0, so alpha ≈ from_val (1.0)
	await wait_frames(2)
	assert_true(target.modulate.a > 0.8, "2D flicker at start: alpha near 1.0 (progress~0)")
	await cleanup(target)


# =============================================================================
# 2D — STOP/RESTART
# =============================================================================

func test_2d_stop_then_reanimate_clean() -> void:
	var rig := await _create_2d_rig(_make_2d_fade(), 0.2)
	var target: Node2D = rig[0]
	var juice: Juice2D = rig[1]
	juice.animate_in()
	await wait_seconds(0.1)
	assert_true(target.modulate.a < 0.9, "2D stop/restart: mid-animation alpha < 0.9")
	juice.stop()
	await wait_frames(3)
	assert_approx_float(target.modulate.a, 1.0, "2D stop/restart: after stop alpha==1.0")
	juice.animate_in()
	await wait_seconds(0.1)
	assert_true(target.modulate.a < 0.9, "2D stop/restart: re-animated alpha < 0.9")
	juice.stop()
	await cleanup(target)


# =============================================================================
# CONTROL — FADE
# =============================================================================

func test_ctrl_fade_changes_alpha() -> void:
	var rig := await _create_ctrl_rig(_make_ctrl_fade(), 0.3)
	var target: Control = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.1)
	assert_true(target.self_modulate.a < 0.9, "Ctrl FADE mid: alpha < 0.9")
	await cleanup(target)

func test_ctrl_fade_restores_after_stop() -> void:
	var rig := await _create_ctrl_rig(_make_ctrl_fade(), 0.15)
	var target: Control = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.5)
	rig[1].stop()
	assert_approx_float(target.self_modulate.a, 1.0, "Ctrl FADE restore: alpha==1.0")
	await cleanup(target)

func test_ctrl_fade_writes_self_modulate_not_modulate() -> void:
	var rig := await _create_ctrl_rig(_make_ctrl_fade(), 0.3)
	var target: Control = rig[0]
	target.modulate = Color(1, 1, 1, 1)
	rig[1].animate_in()
	await wait_seconds(0.1)
	# modulate should NOT change — only self_modulate should
	assert_approx_float(target.modulate.a, 1.0, "Ctrl FADE: modulate.a unchanged", 0.01)
	assert_true(target.self_modulate.a < 0.9, "Ctrl FADE: self_modulate.a changed")
	await cleanup(target)


# =============================================================================
# CONTROL — TINT
# =============================================================================

func test_ctrl_tint_changes_rgb() -> void:
	var rig := await _create_ctrl_rig(_make_ctrl_tint(), 0.3)
	var target: Control = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.15)
	assert_true(target.self_modulate.r < 0.8, "Ctrl TINT mid: red reduced")
	await cleanup(target)

func test_ctrl_tint_restores_after_stop() -> void:
	var rig := await _create_ctrl_rig(_make_ctrl_tint(), 0.15)
	var target: Control = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.5)
	rig[1].stop()
	assert_approx_float(target.self_modulate.r, 1.0, "Ctrl TINT restore: red==1.0")
	await cleanup(target)


# =============================================================================
# CONTROL — OVERBRIGHT
# =============================================================================

func test_ctrl_overbright_exceeds_one() -> void:
	var rig := await _create_ctrl_rig(_make_ctrl_overbright(), 0.3)
	var target: Control = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.15)
	assert_true(target.self_modulate.r > 1.0, "Ctrl OVERBRIGHT mid: r > 1.0")
	await cleanup(target)

func test_ctrl_overbright_restores_after_stop() -> void:
	var rig := await _create_ctrl_rig(_make_ctrl_overbright(), 0.15)
	var target: Control = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.5)
	rig[1].stop()
	assert_approx_float(target.self_modulate.r, 1.0, "Ctrl OVERBRIGHT restore: r==1.0")
	await cleanup(target)


# =============================================================================
# CONTROL — OUTLINE
# =============================================================================

func test_ctrl_outline_installs_shader_material() -> void:
	var e := AppearanceControlJuiceEffect.new()
	e.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.OUTLINE
	e.outline_color = Color.WHITE
	e.outline_width = 3.0
	var rig := await _create_ctrl_rig(e, 0.3)
	var target: Control = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.1)
	assert_true(target.material is ShaderMaterial, "Ctrl OUTLINE: ShaderMaterial installed")
	await cleanup(target)

func test_ctrl_outline_restores_after_stop() -> void:
	var e := AppearanceControlJuiceEffect.new()
	e.effect_type = AppearanceControlJuiceEffect.AppearanceEffect.OUTLINE
	e.outline_color = Color.WHITE
	e.outline_width = 3.0
	var rig := await _create_ctrl_rig(e, 0.15)
	var target: Control = rig[0]
	rig[1].animate_in()
	await wait_seconds(0.5)
	rig[1].stop()
	assert_true(target.material == null, "Ctrl OUTLINE restore: material null")
	await cleanup(target)


# =============================================================================
# CONTROL — STACKING (sibling Juice nodes)
# =============================================================================

func test_ctrl_sibling_fade_stack() -> void:
	var eff_a := _make_ctrl_fade(0.5)
	var eff_b := _make_ctrl_fade(0.5)
	var rig := await _create_ctrl_sibling_rig(eff_a, eff_b, 0.3)
	var target: Control = rig[0]
	rig[1].animate_in()
	rig[2].animate_in()
	await wait_seconds(0.5)
	# Both fading to 0.5: combined ~ 0.5 * 0.5 = 0.25
	assert_true(target.self_modulate.a < 0.5, "Ctrl sibling fade: multiplicative alpha < 0.5")
	await cleanup(target)

func test_ctrl_sibling_first_stops_second_continues() -> void:
	var eff_a := _make_ctrl_fade(0.3)
	var eff_b := _make_ctrl_fade(0.3)
	var rig := await _create_ctrl_sibling_rig(eff_a, eff_b, 0.3)
	var target: Control = rig[0]
	rig[1].animate_in()
	rig[2].animate_in()
	await wait_seconds(0.15)
	rig[1].stop()
	await wait_seconds(0.3)
	assert_true(target.self_modulate.a < 0.9, "Ctrl sibling: B still fading after A stops")
	rig[2].stop()
	await wait_frames(5)
	assert_approx_float(target.self_modulate.a, 1.0, "Ctrl sibling: both stopped, restored")
	await cleanup(target)


# =============================================================================
# CONTROL — FLICKER
# =============================================================================

func test_ctrl_flicker_random_varies_fade_output() -> void:
	var e := _make_ctrl_fade(0.0)
	e.flicker_mode = AppearanceControlJuiceEffect.FlickerMode.RANDOM
	e.flicker_min = 0.0
	e.flicker_max = 1.0
	e.flicker_rate = 10.0
	var rig := await _create_ctrl_rig(e, 0.5)
	var target: Control = rig[0]
	rig[1].animate_in()
	var samples: Array[float] = []
	for i in 10:
		await wait_seconds(0.05)
		samples.append(target.self_modulate.a)
	var all_same := true
	for i in range(1, samples.size()):
		if absf(samples[i] - samples[0]) > 0.01:
			all_same = false
			break
	assert_false(all_same, "Ctrl flicker FADE: alpha varies over time")
	await cleanup(target)


# =============================================================================
# 3D — FADE
# =============================================================================

func test_3d_fade_changes_alpha() -> void:
	var rig := await _create_3d_rig(_make_3d_fade(), 0.3)
	var target: Node3D = rig[0]
	var mesh_inst: MeshInstance3D = rig[2]
	rig[1].animate_in()
	await wait_seconds(0.1)
	var mat := mesh_inst.get_surface_override_material(0) as StandardMaterial3D
	assert_true(mat != null, "3D FADE mid: material exists")
	assert_true(mat.albedo_color.a < 0.9, "3D FADE mid: alpha < 0.9")
	await cleanup(target)

func test_3d_fade_restores_after_stop() -> void:
	var rig := await _create_3d_rig(_make_3d_fade(), 0.15)
	var target: Node3D = rig[0]
	var mesh_inst: MeshInstance3D = rig[2]
	var original_mat := mesh_inst.get_surface_override_material(0)
	rig[1].animate_in()
	await wait_seconds(0.5)
	rig[1].stop()
	var restored := mesh_inst.get_surface_override_material(0)
	assert_true(restored == original_mat, "3D FADE restore: original material restored")
	await cleanup(target)


# =============================================================================
# 3D — TINT
# =============================================================================

func test_3d_tint_changes_albedo() -> void:
	var rig := await _create_3d_rig(_make_3d_tint(), 0.3)
	var target: Node3D = rig[0]
	var mesh_inst: MeshInstance3D = rig[2]
	rig[1].animate_in()
	await wait_seconds(0.15)
	var mat := mesh_inst.get_surface_override_material(0) as StandardMaterial3D
	assert_true(mat != null, "3D TINT mid: material exists")
	assert_true(mat.albedo_color.g < 0.8, "3D TINT mid: green reduced (tinting red)")
	await cleanup(target)

func test_3d_tint_restores_after_stop() -> void:
	var rig := await _create_3d_rig(_make_3d_tint(), 0.15)
	var target: Node3D = rig[0]
	var mesh_inst: MeshInstance3D = rig[2]
	rig[1].animate_in()
	await wait_seconds(0.5)
	rig[1].stop()
	var mat := mesh_inst.get_surface_override_material(0) as StandardMaterial3D
	assert_true(mat != null, "3D TINT restore: material exists")
	assert_approx_float(mat.albedo_color.g, 1.0, "3D TINT restore: green==1.0")
	await cleanup(target)


# =============================================================================
# 3D — OVERBRIGHT
# =============================================================================

func test_3d_overbright_exceeds_one() -> void:
	var rig := await _create_3d_rig(_make_3d_overbright(), 0.3)
	var target: Node3D = rig[0]
	var mesh_inst: MeshInstance3D = rig[2]
	rig[1].animate_in()
	await wait_seconds(0.15)
	var mat := mesh_inst.get_surface_override_material(0) as StandardMaterial3D
	assert_true(mat != null, "3D OVERBRIGHT mid: material exists")
	assert_true(mat.albedo_color.r > 1.0, "3D OVERBRIGHT mid: r > 1.0")
	await cleanup(target)

func test_3d_overbright_restores_after_stop() -> void:
	var rig := await _create_3d_rig(_make_3d_overbright(), 0.15)
	var target: Node3D = rig[0]
	var mesh_inst: MeshInstance3D = rig[2]
	rig[1].animate_in()
	await wait_seconds(0.5)
	rig[1].stop()
	var mat := mesh_inst.get_surface_override_material(0) as StandardMaterial3D
	assert_true(mat != null, "3D OVERBRIGHT restore: material exists")
	assert_approx_float(mat.albedo_color.r, 1.0, "3D OVERBRIGHT restore: r==1.0")
	await cleanup(target)


# =============================================================================
# 3D — STACKING (sibling Juice nodes)
# =============================================================================

func test_3d_sibling_fade_stack() -> void:
	var eff_a := _make_3d_fade(0.5)
	var eff_b := _make_3d_fade(0.5)
	var rig := await _create_3d_sibling_rig(eff_a, eff_b, 0.3)
	var target: Node3D = rig[0]
	var mesh_inst: MeshInstance3D = rig[3]
	rig[1].animate_in()
	rig[2].animate_in()
	await wait_seconds(0.5)
	var mat := mesh_inst.get_surface_override_material(0) as StandardMaterial3D
	assert_true(mat != null, "3D sibling fade: material exists")
	# Both at 0.5: combined ~0.5*0.5=0.25
	assert_true(mat.albedo_color.a < 0.5, "3D sibling fade: multiplicative alpha < 0.5")
	await cleanup(target)

func test_3d_sibling_first_stops_second_continues() -> void:
	var eff_a := _make_3d_fade(0.3)
	var eff_b := _make_3d_fade(0.3)
	var rig := await _create_3d_sibling_rig(eff_a, eff_b, 0.3)
	var target: Node3D = rig[0]
	var mesh_inst: MeshInstance3D = rig[3]
	rig[1].animate_in()
	rig[2].animate_in()
	await wait_seconds(0.15)
	rig[1].stop()
	await wait_seconds(0.3)
	var mat := mesh_inst.get_surface_override_material(0) as StandardMaterial3D
	assert_true(mat != null, "3D sibling: material exists after A stops")
	assert_true(mat.albedo_color.a < 0.9, "3D sibling: B still fading after A stops")
	await cleanup(target)


# =============================================================================
# 3D — FLICKER
# =============================================================================

func test_3d_flicker_random_varies_fade_alpha() -> void:
	var e := _make_3d_fade(0.0)
	e.flicker_mode = Appearance3DJuiceEffect.FlickerMode.RANDOM
	e.flicker_min = 0.0
	e.flicker_max = 1.0
	e.flicker_rate = 10.0
	var rig := await _create_3d_rig(e, 0.5)
	var target: Node3D = rig[0]
	var mesh_inst: MeshInstance3D = rig[2]
	rig[1].animate_in()
	var samples: Array[float] = []
	for i in 10:
		await wait_seconds(0.05)
		var mat := mesh_inst.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			samples.append(mat.albedo_color.a)
	var all_same := true
	for i in range(1, samples.size()):
		if absf(samples[i] - samples[0]) > 0.01:
			all_same = false
			break
	assert_false(all_same, "3D flicker FADE: alpha varies over time")
	await cleanup(target)


