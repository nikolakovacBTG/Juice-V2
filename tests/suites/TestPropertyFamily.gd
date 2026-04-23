## TestPropertyFamily.gd
## Tests for PropertyTarget inspector layout (no duplicates, conditional display)
## and runtime behavior of Noise/Interpolate Property effects.
extends JuiceTestSuite


func get_suite_name() -> String:
	return "property_family"


func get_test_methods() -> Array[String]:
	return [
		# --- Unit: no duplicate properties ---
		"test_noise_target_no_duplicate_node_path",
		"test_noise_target_no_duplicate_property_path",
		"test_shake_target_no_duplicate_node_path",
		"test_interpolate_target_no_duplicate_node_path",
		# --- Unit: conditional amplitude display ---
		"test_noise_target_type_float_shows_only_float_amplitude",
		"test_noise_target_type_vec2_shows_only_vec2_amplitude",
		"test_noise_target_type_nil_shows_all_amplitudes",
		"test_shake_target_type_float_shows_only_float_strength",
		# --- Unit: base value capture ---
		"test_property_target_captures_float_base",
		"test_property_target_captures_color_base",
		# --- Runtime: NoisePropertyEffect drives property ---
		"test_noise_property_drives_float_property",
		# --- Runtime: InterpolatePropertyEffect ---
		"test_interpolate_property_float_reaches_target",
		"test_interpolate_property_on_trigger_captures_current",
		# --- Recipe registration ---
		"test_noise_property_control_in_recipe_whitelist",
		"test_interpolate_property_control_in_recipe_whitelist",
	]


# =============================================================================
# HELPERS
# =============================================================================

func _count_prop_name(props: Array, pname: String) -> int:
	var count := 0
	for p: Dictionary in props:
		if p.get("name", "") == pname:
			count += 1
	return count


func _editor_visible_count(props: Array, pname: String) -> int:
	var count := 0
	for p: Dictionary in props:
		if p.get("name", "") == pname and (p.get("usage", 0) & PROPERTY_USAGE_EDITOR) != 0:
			count += 1
	return count


func _create_noise_property_rig(
	p_property: String = "modulate:a",
	p_amplitude: float = 0.3,
	p_duration: float = 0.2
) -> Array:
	var ctrl := create_control_target("NoisePropTarget")

	var target := NoisePropertyTarget.new()
	target.node_path = NodePath("")
	target.property_path = p_property
	target.amplitude_float = p_amplitude
	# In headless mode, _detect_type() is skipped. Set explicitly so the effect
	# knows which amplitude field to use (same as what editor sets at design-time).
	target._detected_type = TYPE_FLOAT

	var effect := PropertyNoiseControlJuiceEffect.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_in = p_duration
	effect.duration_out = p_duration
	effect.property_targets.append(target)

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	ctrl.add_child(juice)

	await wait_frames(3)
	return [ctrl, juice]


func _create_interpolate_property_rig(
	p_from: float,
	p_to: float,
	p_duration: float = 0.2,
	p_capture_from: int = InterpolatePropertyTarget.CaptureMode.CUSTOM
) -> Array:
	var ctrl := create_control_target("InterpPropTarget")
	ctrl.modulate = Color(1, 1, 1, p_from)

	var target := InterpolatePropertyTarget.new()
	target.node_path = NodePath("")
	target.property_path = "modulate:a"
	target.capture_from = p_capture_from
	target.from_float = p_from
	target.capture_to = InterpolatePropertyTarget.CaptureMode.CUSTOM
	target.to_float = p_to
	# In headless mode, _detect_type() is skipped. Set explicitly so _compute_lerp
	# doesn't bail on TYPE_NIL.
	target._detected_type = TYPE_FLOAT

	var effect := PropertyInterpolateControlJuiceEffect.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = p_duration
	effect.property_targets.append(target)

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	ctrl.add_child(juice)

	await wait_frames(3)
	return [ctrl, juice]


# =============================================================================
# UNIT: No duplicate properties
# Each PropertyTarget subclass calls _get_property_list() on its portion only.
# The parent's portion is called separately by the Godot engine.
# =============================================================================

func test_noise_target_no_duplicate_node_path() -> void:
	# Godot auto-scan adds var declarations with SCRIPT_VARIABLE (not EDITOR).
	# The _get_property_list() adds a DEFAULT entry. Only ONE should be EDITOR-visible.
	# Before the fix, super._get_property_list() caused TWO editor-visible entries.
	var target := NoisePropertyTarget.new()
	var props := target.get_property_list()
	var editor_count := _editor_visible_count(props, "node_path")
	assert_equal(editor_count, 1,
		"node_path should be editor-visible exactly once (found %d)" % editor_count)


func test_noise_target_no_duplicate_property_path() -> void:
	var target := NoisePropertyTarget.new()
	var props := target.get_property_list()
	var editor_count := _editor_visible_count(props, "property_path")
	assert_equal(editor_count, 1,
		"property_path should be editor-visible exactly once (found %d)" % editor_count)


func test_shake_target_no_duplicate_node_path() -> void:
	var target := ShakePropertyTarget.new()
	var props := target.get_property_list()
	var editor_count := _editor_visible_count(props, "node_path")
	assert_equal(editor_count, 1,
		"ShakePropertyTarget: node_path should be editor-visible exactly once (found %d)" % editor_count)


func test_interpolate_target_no_duplicate_node_path() -> void:
	var target := InterpolatePropertyTarget.new()
	var props := target.get_property_list()
	var editor_count := _editor_visible_count(props, "node_path")
	assert_equal(editor_count, 1,
		"InterpolatePropertyTarget: node_path should be editor-visible exactly once (found %d)" % editor_count)


# =============================================================================
# UNIT: Conditional amplitude display
# _detected_type is set directly to test display logic without editor context.
# =============================================================================

func test_noise_target_type_float_shows_only_float_amplitude() -> void:
	var target := NoisePropertyTarget.new()
	target._detected_type = TYPE_FLOAT
	var props := target.get_property_list()

	assert_equal(_editor_visible_count(props, "amplitude_float"), 1,
		"amplitude_float should be editor-visible for TYPE_FLOAT")
	assert_equal(_editor_visible_count(props, "amplitude_vec2"), 0,
		"amplitude_vec2 should NOT be editor-visible for TYPE_FLOAT")
	assert_equal(_editor_visible_count(props, "amplitude_vec3"), 0,
		"amplitude_vec3 should NOT be editor-visible for TYPE_FLOAT")
	assert_equal(_editor_visible_count(props, "amplitude_color"), 0,
		"amplitude_color should NOT be editor-visible for TYPE_FLOAT")


func test_noise_target_type_vec2_shows_only_vec2_amplitude() -> void:
	var target := NoisePropertyTarget.new()
	target._detected_type = TYPE_VECTOR2
	var props := target.get_property_list()

	assert_equal(_editor_visible_count(props, "amplitude_float"), 0,
		"amplitude_float should NOT be editor-visible for TYPE_VECTOR2")
	assert_equal(_editor_visible_count(props, "amplitude_vec2"), 1,
		"amplitude_vec2 should be editor-visible for TYPE_VECTOR2")
	assert_equal(_editor_visible_count(props, "amplitude_vec3"), 0,
		"amplitude_vec3 should NOT be editor-visible for TYPE_VECTOR2")


func test_noise_target_type_nil_shows_all_amplitudes() -> void:
	var target := NoisePropertyTarget.new()
	# _detected_type == TYPE_NIL by default — Issue 11 fix: all amplitude fields
	# are now HIDDEN when no property is picked. This prevents visual clutter
	# before the user picks a property path.
	var props := target.get_property_list()

	assert_equal(_editor_visible_count(props, "amplitude_float"), 0,
		"amplitude_float should be HIDDEN for TYPE_NIL (pick property first)")
	assert_equal(_editor_visible_count(props, "amplitude_vec2"), 0,
		"amplitude_vec2 should be HIDDEN for TYPE_NIL (pick property first)")
	assert_equal(_editor_visible_count(props, "amplitude_vec3"), 0,
		"amplitude_vec3 should be HIDDEN for TYPE_NIL (pick property first)")
	assert_equal(_editor_visible_count(props, "amplitude_color"), 0,
		"amplitude_color should be HIDDEN for TYPE_NIL (pick property first)")


func test_shake_target_type_float_shows_only_float_strength() -> void:
	var target := ShakePropertyTarget.new()
	target._detected_type = TYPE_FLOAT
	var props := target.get_property_list()

	assert_equal(_editor_visible_count(props, "strength_float"), 1,
		"strength_float should be editor-visible for TYPE_FLOAT")
	assert_equal(_editor_visible_count(props, "strength_vec2"), 0,
		"strength_vec2 should NOT be editor-visible for TYPE_FLOAT")


# =============================================================================
# UNIT: Base value capture via capture_base(host)
# =============================================================================

func test_property_target_captures_float_base() -> void:
	var ctrl := create_control_target("capture_float")
	ctrl.modulate = Color(1, 1, 1, 0.75)

	var target := NoisePropertyTarget.new()
	target.property_path = "modulate:a"
	target.capture_base(ctrl)

	assert_true(absf(float(target._base_value) - 0.75) < 0.001,
		"capture_base should store modulate:a = 0.75 (got %s)" % str(target._base_value))
	await cleanup(ctrl)


func test_property_target_captures_color_base() -> void:
	var ctrl := create_control_target("capture_color")
	ctrl.modulate = Color(0.2, 0.4, 0.6, 1.0)

	var target := NoisePropertyTarget.new()
	target.property_path = "modulate"
	target.capture_base(ctrl)

	var captured: Color = target._base_value
	assert_true(captured is Color and absf(captured.r - 0.2) < 0.01,
		"capture_base should store full modulate Color (got %s)" % str(captured))
	await cleanup(ctrl)


# =============================================================================
# RUNTIME: NoisePropertyEffect drives property
# =============================================================================

func test_noise_property_drives_float_property() -> void:
	var rig := await _create_noise_property_rig("modulate:a", 0.3, 0.3)
	var ctrl: Control = rig[0]
	var juice: JuiceControl = rig[1]

	var initial := ctrl.modulate.a
	juice.animate_in()
	await wait_seconds(0.15)

	var delta := absf(ctrl.modulate.a - initial)
	assert_true(delta > 0.005,
		"NoisePropertyEffect should move modulate:a away from rest (delta=%.4f)" % delta)

	await cleanup(ctrl)


# =============================================================================
# RUNTIME: InterpolatePropertyEffect
# =============================================================================

func test_interpolate_property_float_reaches_target() -> void:
	var rig := await _create_interpolate_property_rig(0.0, 1.0, 0.2)
	var ctrl: Control = rig[0]
	var juice: JuiceControl = rig[1]

	juice.animate_in()
	await wait_seconds(0.5)

	assert_true(ctrl.modulate.a > 0.9,
		"InterpolatePropertyEffect should drive modulate:a to ~1.0 (got %.4f)" % ctrl.modulate.a)
	await cleanup(ctrl)


func test_interpolate_property_on_trigger_captures_current() -> void:
	var rig := await _create_interpolate_property_rig(
		0.0, 1.0, 0.2, InterpolatePropertyTarget.CaptureMode.ON_TRIGGER)
	var ctrl: Control = rig[0]
	var juice: JuiceControl = rig[1]
	ctrl.modulate.a = 0.42  # value to be captured at trigger time

	juice.animate_in()
	await wait_frames(2)

	var rt_target: InterpolatePropertyTarget = juice._runtime_effects[0].property_targets[0]
	var captured := float(rt_target._runtime_from) if rt_target._runtime_from != null else -1.0
	assert_true(absf(captured - 0.42) < 0.02,
		"ON_TRIGGER should capture modulate:a=0.42 as _runtime_from (got %.4f)" % captured)
	await cleanup(ctrl)


# =============================================================================
# RECIPE REGISTRATION
# =============================================================================

func test_noise_property_control_in_recipe_whitelist() -> void:
	var recipe := JuiceControlRecipe.new()
	var prop_def := {"name": "effects", "hint_string": "", "hint": 0, "usage": 0, "type": 0}
	recipe._validate_property(prop_def)
	assert_true(prop_def["hint_string"].contains("PropertyNoiseControlJuiceEffect"),
		"PropertyNoiseControlJuiceEffect must appear in JuiceControlRecipe whitelist")


func test_interpolate_property_control_in_recipe_whitelist() -> void:
	var recipe := JuiceControlRecipe.new()
	var prop_def := {"name": "effects", "hint_string": "", "hint": 0, "usage": 0, "type": 0}
	recipe._validate_property(prop_def)
	assert_true(prop_def["hint_string"].contains("PropertyInterpolateControlJuiceEffect"),
		"PropertyInterpolateControlJuiceEffect must appear in JuiceControlRecipe whitelist")
