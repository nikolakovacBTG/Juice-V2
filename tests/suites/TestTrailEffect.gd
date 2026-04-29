## TestTrailEffect.gd
## Tests for TrailJuiceEffect — Line2D lifecycle, width modulation, point timing.
##
## Coverage:
##   - Instantiation and base type
##   - Registered in Juice2DRecipe only (not Control or 3D)
##   - Line2D absent before animate_in, created after _on_animate_start direct call
##   - Trail inactive after _on_animate_out_complete
##   - _restore_to_natural clears Line2D reference
##   - Width modulated by progress when flag is true
##   - Width unchanged when modulate flag is false
##   - tick() captures _last_delta for point timing
##   - _needs_sustain() reflects trail_active state
##   - Configuration warnings for trail_length < 2
##
## NOTE: Effects are Resources cloned at runtime by JuiceBase. Tests that inspect
##   internal state (_trail_line_2d, _trail_active) call effect methods directly
##   rather than going through the Juice node to avoid the clone-vs-original
##   reference issue.
extends JuiceTestSuite


func get_suite_name() -> String:
	return "trail_effect"


func get_test_methods() -> Array[String]:
	return [
		"test_trail_instantiates",
		"test_trail_registered_in_2d_recipe",
		"test_trail_not_in_control_recipe",
		"test_trail_not_in_3d_recipe",
		"test_line2d_absent_before_animate_start",
		"test_line2d_created_on_animate_start",
		"test_trail_active_on_animate_start",
		"test_trail_inactive_after_animate_out",
		"test_restore_to_natural_clears_line2d_ref",
		"test_width_modulated_by_progress",
		"test_width_unchanged_when_flag_false",
		"test_tick_captures_last_delta",
		"test_needs_sustain_true_while_active",
		"test_needs_sustain_false_when_inactive",
		"test_config_warning_trail_length_below_2",
		"test_config_warning_clear_for_valid_length",
	]


# =============================================================================
# HELPERS
# =============================================================================

# Create a TrailJuiceEffect with _host_node set so tree access works.
# world_space_trail = false → Line2D is added as sibling of target (target.get_parent()).
func _create_direct_trail_effect(host: Node) -> TrailJuiceEffect:
	var effect := TrailJuiceEffect.new()
	effect.trail_length = 10
	effect.trail_width = 8.0
	effect.point_interval = 0.01
	effect.world_space_trail = false  # Attaches to target.get_parent() = _runner.
	effect.modulate_width_by_progress = true
	effect.duration_in = 0.05
	effect.duration_out = 0.05
	effect._host_node = host
	return effect


# =============================================================================
# INSTANTIATION + REGISTRATION
# =============================================================================

func test_trail_instantiates() -> void:
	var effect := TrailJuiceEffect.new()
	assert_true(effect != null, "TrailJuiceEffect should instantiate")
	assert_true(effect is JuiceEffectBase, "should extend JuiceEffectBase")


func test_trail_registered_in_2d_recipe() -> void:
	var recipe := Juice2DRecipe.new()
	var effect := TrailJuiceEffect.new()
	recipe.effects.append(effect)
	assert_equal(recipe.effects.size(), 1,
		"TrailJuiceEffect accepted in Juice2DRecipe")


func test_trail_not_in_control_recipe() -> void:
	var recipe := JuiceControlRecipe.new()
	var props := recipe._get_property_list()
	var whitelist := ""
	for prop in props:
		if prop.name == "effects":
			whitelist = prop.get("hint_string", "")
			break
	assert_false("TrailJuiceEffect" in whitelist,
		"TrailJuiceEffect must NOT be in JuiceControlRecipe whitelist")


func test_trail_not_in_3d_recipe() -> void:
	var recipe := Juice3DRecipe.new()
	var props := recipe._get_property_list()
	var whitelist := ""
	for prop in props:
		if prop.name == "effects":
			whitelist = prop.get("hint_string", "")
			break
	assert_false("TrailJuiceEffect" in whitelist,
		"TrailJuiceEffect must NOT be in Juice3DRecipe whitelist")


# =============================================================================
# LINE2D LIFECYCLE — direct calls to avoid clone issues
# =============================================================================

func test_line2d_absent_before_animate_start() -> void:
	var target := create_2d_target()
	var effect := _create_direct_trail_effect(target)

	assert_true(effect._trail_line_2d == null,
		"Line2D should not exist before _on_animate_start")
	await cleanup(target)


func test_line2d_created_on_animate_start() -> void:
	var target := create_2d_target()
	var effect := _create_direct_trail_effect(target)

	effect._on_animate_start(target)
	await wait_frames(2)

	assert_true(effect._trail_line_2d != null,
		"Line2D should be created after _on_animate_start")
	assert_true(is_instance_valid(effect._trail_line_2d),
		"Line2D should be a valid node")

	# Cleanup: free the Line2D manually since it was added outside normal lifecycle.
	effect._cleanup_trail()
	await cleanup(target)


func test_trail_active_on_animate_start() -> void:
	var target := create_2d_target()
	var effect := _create_direct_trail_effect(target)

	assert_false(effect._trail_active, "trail inactive before start")
	effect._on_animate_start(target)
	assert_true(effect._trail_active, "trail active after _on_animate_start")

	effect._cleanup_trail()
	await cleanup(target)


func test_trail_inactive_after_animate_out() -> void:
	var target := create_2d_target()
	var effect := _create_direct_trail_effect(target)

	effect._on_animate_start(target)
	assert_true(effect._trail_active, "trail active after start")

	effect._on_animate_out_complete(target)
	assert_false(effect._trail_active, "trail inactive after _on_animate_out_complete")

	# Fade-out creates a tween but we don't need to wait — just check the flag.
	# Clean up the Line2D node that animate_out will free via tween.
	if effect._trail_line_2d != null and is_instance_valid(effect._trail_line_2d):
		effect._trail_line_2d.queue_free()
	effect._trail_line_2d = null
	await cleanup(target)


func test_restore_to_natural_clears_line2d_ref() -> void:
	var target := create_2d_target()
	var effect := _create_direct_trail_effect(target)

	effect._on_animate_start(target)
	assert_true(effect._trail_line_2d != null, "Line2D exists after animate_start")

	effect._restore_to_natural(target)
	assert_true(effect._trail_line_2d == null,
		"Line2D reference null after _restore_to_natural")
	await cleanup(target)


# =============================================================================
# WIDTH MODULATION
# =============================================================================

func test_width_modulated_by_progress() -> void:
	var target := create_2d_target()
	var effect := _create_direct_trail_effect(target)
	effect.trail_width = 8.0
	effect.modulate_width_by_progress = true

	effect._on_animate_start(target)
	assert_true(effect._trail_line_2d != null, "Line2D must exist")

	effect._apply_effect(0.5, target)
	assert_approx_float(effect._trail_line_2d.width, 4.0,
		"width should be trail_width * 0.5 = 4.0", 0.1)

	effect._cleanup_trail()
	await cleanup(target)


func test_width_unchanged_when_flag_false() -> void:
	var target := create_2d_target()
	var effect := _create_direct_trail_effect(target)
	effect.trail_width = 8.0
	effect.modulate_width_by_progress = false

	effect._on_animate_start(target)
	assert_true(effect._trail_line_2d != null, "Line2D must exist")

	effect._apply_effect(0.0, target)
	assert_approx_float(effect._trail_line_2d.width, 8.0,
		"width should remain at trail_width when modulate is false", 0.1)

	effect._cleanup_trail()
	await cleanup(target)


# =============================================================================
# TICK / DELTA CAPTURE
# =============================================================================

func test_tick_captures_last_delta() -> void:
	var target := create_2d_target()
	var effect := TrailJuiceEffect.new()
	effect.duration_in = 1.0
	effect.start(target, true, false, target)
	await wait_frames(1)

	effect.tick(0.123, target)
	assert_approx_float(effect._last_delta, 0.123,
		"_last_delta should capture the delta passed to tick()", 0.001)
	await cleanup(target)


func test_needs_sustain_true_while_active() -> void:
	var effect := TrailJuiceEffect.new()
	effect._trail_active = true
	assert_true(effect._needs_sustain(),
		"_needs_sustain() true while trail is active")


func test_needs_sustain_false_when_inactive() -> void:
	var effect := TrailJuiceEffect.new()
	effect._trail_active = false
	assert_false(effect._needs_sustain(),
		"_needs_sustain() false when trail is inactive")


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func test_config_warning_trail_length_below_2() -> void:
	var effect := TrailJuiceEffect.new()
	effect.trail_length = 1
	var warnings := effect._get_configuration_warnings()
	assert_true(warnings.size() > 0,
		"warning expected when trail_length < 2")


func test_config_warning_clear_for_valid_length() -> void:
	var effect := TrailJuiceEffect.new()
	effect.trail_length = 5
	var warnings := effect._get_configuration_warnings()
	assert_equal(warnings.size(), 0,
		"no warning for valid trail_length")
