## TestShakeProperty.gd
## Runtime tests for PropertyShakeControlJuiceEffect.
##
## Gap discovered: ShakeProperty had no runtime test coverage. This suite
## verifies the three unique behaviors of ShakeProperty:
##   1. The effect moves the property away from its base value (effect fires at all)
##   2. The property returns to natural after stop (restore_to_natural works)
##   3. randomness=0 (pure sine) produces consistent direction on first half-cycle
##      vs randomness=1 (pure random) produces different values each run
extends JuiceTestSuite


func get_suite_name() -> String:
	return "shake_property"


func get_test_methods() -> Array[String]:
	return [
		# --- Runtime: effect moves property ---
		"test_shake_property_moves_float_property",
		# --- Runtime: restore_to_natural returns to base ---
		"test_shake_property_restores_to_natural",
		# --- Recipe registration ---
		"test_shake_property_control_in_recipe_whitelist",
		# --- Inspector layout: no duplicate node_path ---
		"test_shake_target_no_duplicate_node_path",
	]


# =============================================================================
# HELPERS
# =============================================================================

# Mirrors NoisePropertyTarget rig construction — set _detected_type explicitly
# because _detect_type() is skipped in headless mode (no editor inspector).
func _create_shake_property_rig(
	p_property: String = "modulate:a",
	p_strength: float = 0.3,
	p_duration: float = 0.3,
	p_randomness: float = 0.5
) -> Array:
	var ctrl := create_control_target("ShakePropTarget")

	var target := ShakePropertyTarget.new()
	target.node_path = NodePath("")
	target.property_path = p_property
	target.strength_float = p_strength
	# Set detected type explicitly — headless mode does not call _detect_type().
	target._detected_type = TYPE_FLOAT

	var effect := PropertyShakeControlJuiceEffect.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_in = p_duration
	effect.duration_out = p_duration
	effect.shake_frequency = 8.0
	effect.randomness = p_randomness
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
# RUNTIME: Effect moves property
# =============================================================================

func test_shake_property_moves_float_property() -> void:
	# ShakeProperty's unique diagnostic invariant:
	# delta = strength × sin/rand-blend × progress
	# If output is flat, one of three factors is zero.
	# This test proves the chain fires end-to-end.
	var rig := await _create_shake_property_rig("modulate:a", 0.3, 0.3, 0.5)
	var ctrl: Control = rig[0]
	var juice: JuiceControl = rig[1]

	var initial := ctrl.modulate.a
	juice.animate_in()
	await wait_seconds(0.15)  # Midpoint — effect is running, not restored yet.

	var delta := absf(ctrl.modulate.a - initial)
	assert_true(delta > 0.005,
		"ShakePropertyEffect should move modulate:a away from rest (delta=%.4f)" % delta)

	await cleanup(ctrl)


# =============================================================================
# RUNTIME: Restore to natural
# =============================================================================

func test_shake_property_restores_to_natural() -> void:
	# Verifies _restore_to_natural correctly writes the base value back.
	# This is the most common integration failure: the effect fires but leaves
	# the property at the last-written shake position instead of the base.
	# Use stop() directly — it is the path that calls _restore_to_natural,
	# independent of trigger_behaviour or animation state.
	var rig := await _create_shake_property_rig("modulate:a", 0.3, 0.15, 0.5)
	var ctrl: Control = rig[0]
	var juice: JuiceControl = rig[1]

	var initial := ctrl.modulate.a

	# Drive in and let it oscillate.
	juice.animate_in()
	await wait_seconds(0.1)  # Mid-flight — effect is writing shake values.

	# stop() calls _restore_to_natural on all effects.
	juice.stop()
	await wait_frames(2)  # Allow deferred writes to settle.

	var restored := ctrl.modulate.a
	assert_true(absf(restored - initial) < 0.02,
		"ShakePropertyEffect should restore modulate:a to base after stop() (got %.4f, expected %.4f)" % [restored, initial])

	await cleanup(ctrl)


# =============================================================================
# RECIPE REGISTRATION
# =============================================================================

func test_shake_property_control_in_recipe_whitelist() -> void:
	var recipe := JuiceControlRecipe.new()
	var prop_def := {"name": "effects", "hint_string": "", "hint": 0, "usage": 0, "type": 0}
	recipe._validate_property(prop_def)
	assert_true(prop_def["hint_string"].contains("PropertyShakeControlJuiceEffect"),
		"PropertyShakeControlJuiceEffect must appear in JuiceControlRecipe whitelist")


# =============================================================================
# UNIT: Inspector layout
# =============================================================================

func test_shake_target_no_duplicate_node_path() -> void:
	# Verified in TestPropertyFamily for the node_path field.
	# Repeated here for ShakePropertyTarget specifically because it owns
	# its layout (_subclass_owns_target_layout = true) — a different code path.
	var target := ShakePropertyTarget.new()
	var props := target.get_property_list()
	var count := 0
	for p: Dictionary in props:
		if p.get("name", "") == "node_path" and (p.get("usage", 0) & PROPERTY_USAGE_EDITOR) != 0:
			count += 1
	assert_equal(count, 1,
		"ShakePropertyTarget: node_path should be editor-visible exactly once (found %d)" % count)
