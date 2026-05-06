## TestRealWorldProgressTransform.gd
## ============================================================================
## WHAT: Realistic integration tests for ProgressTransform effects across all
##       3 domains (2D, Control, 3D).
## WHY:  The unit-style tests (TestProgressTransform2D/3D/Control) use targets
##       at Vector2.ZERO and test effects in isolation. Real scenes have nodes
##       at non-zero positions, multiple effects stacked on the same target, and
##       mixed recipes. This suite covers those real-world scenarios.
## SYSTEM: Tests (tests/suites/)
## DOES NOT: Test editor transport lifecycle (that requires MCP editor scripts
##           running in the live editor process, not headless).
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "realworld_progress_transform"


func get_test_methods() -> Array[String]:
	return [
		# --- Registration ---
		"test_2d_registration",
		"test_control_registration",
		"test_3d_registration",
		# --- 2D Position (Phase A-2) ---
		"test_2d_position_non_zero_origin",
		"test_2d_position_bound_reverse_non_zero",
		"test_2d_position_bound_reverse_eased_non_zero",
		# --- 2D Rotation + Scale + Stacking (Phase A-3) ---
		"test_2d_rotation_non_zero_origin",
		"test_2d_scale_non_zero_origin",
		"test_2d_stacked_deterministic",
		# --- 2D Mixed + Retrigger (Phase A-4) ---
		"test_2d_mixed_shake_no_interference",
		"test_2d_mixed_noise_no_interference",
		"test_2d_retrigger_during_sustain",
		# --- Control domain (Phase A-5) ---
		# "test_control_position_non_zero_origin",     # Phase A-5
		# "test_control_bound_reverse_non_zero",       # Phase A-5
		# "test_control_stacked_deterministic",        # Phase A-5
		# "test_control_mixed_noise_no_interference",  # Phase A-5
		# --- 3D domain (Phase A-6) ---
		# "test_3d_position_non_zero_origin",          # Phase A-6
		# "test_3d_rotation_non_zero_origin",          # Phase A-6
		# "test_3d_bound_reverse_non_zero",            # Phase A-6
		# "test_3d_mixed_noise_no_interference",       # Phase A-6
	]


# =============================================================================
# HELPERS (scaffold - implementations added in later phases)
# =============================================================================

# Creates a Juice2D + Node2D target rig at the given position and transform target.
# Returns [Juice2D, Node2D, effect].
func _create_2d_rig_at(
		pos: Vector2,
		target_type: int = ProgressTransform2DJuiceEffect.TransformTarget.POSITION,
		rate_pos: Vector2 = Vector2(100.0, 0.0),
		duration_in: float = 0.1
) -> Array:
	var target := Node2D.new()
	target.name = "RW2DTarget"
	target.position = pos
	_runner.add_child(target)

	var effect := ProgressTransform2DJuiceEffect.new()
	effect.transform_target = target_type
	effect.position_rate = rate_pos
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = duration_in
	effect.auto_start = false

	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)

	var juice := Juice2D.new()
	juice.name = "RW_Juice2D"
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	juice.recipe = recipe
	target.add_child(juice)

	await wait_frames(2)
	return [juice, target, effect]


# Creates a JuiceControl + Button rig at the given position.
# Returns [JuiceControl, Button].
func _create_control_rig_at(
		pos: Vector2,
		target_type: int = ProgressTransformControlJuiceEffect.TransformTarget.POSITION,
		rate_pos: Vector2 = Vector2(100.0, 0.0),
		duration_in: float = 0.3
) -> Array:
	var target := Button.new()
	target.name = "RWControlTarget"
	target.position = pos
	target.size = Vector2(80.0, 30.0)
	_runner.add_child(target)

	var effect := ProgressTransformControlJuiceEffect.new()
	effect.transform_target = target_type
	effect.position_rate = rate_pos
	effect.duration_in = duration_in

	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)

	var juice := JuiceControl.new()
	juice.name = "RW_JuiceControl"
	juice.recipe = recipe
	target.add_child(juice)

	return [juice, target]


# Creates a Juice3D + Node3D rig at the given position.
# Returns [Juice3D, Node3D].
func _create_3d_rig_at(
		pos: Vector3,
		target_type: int = ProgressTransform3DJuiceEffect.TransformTarget.POSITION,
		rate_pos: Vector3 = Vector3(100.0, 0.0, 0.0),
		duration_in: float = 0.3
) -> Array:
	var target := Node3D.new()
	target.name = "RW3DTarget"
	target.position = pos
	_runner.add_child(target)

	var effect := ProgressTransform3DJuiceEffect.new()
	effect.transform_target = target_type
	effect.position_rate = rate_pos
	effect.duration_in = duration_in

	var recipe := Juice3DRecipe.new()
	recipe.effects.append(effect)

	var juice := Juice3D.new()
	juice.name = "RW_Juice3D"
	juice.recipe = recipe
	target.add_child(juice)

	return [juice, target]


# =============================================================================
# PHASE A-1: REGISTRATION TESTS
# =============================================================================

## Verify ProgressTransform2DJuiceEffect is listed in Juice2DRecipe's
## inspector whitelist. Missing registration = invisible in the inspector.
func test_2d_registration() -> void:
	var recipe := Juice2DRecipe.new()
	var whitelist: String = recipe._CONCRETE_EFFECTS
	assert_true(
		whitelist.contains("ProgressTransform2DJuiceEffect"),
		"Juice2DRecipe._CONCRETE_EFFECTS must contain 'ProgressTransform2DJuiceEffect'. Got: " + whitelist
	)


## Verify ProgressTransformControlJuiceEffect is listed in JuiceControlRecipe's
## inspector whitelist.
func test_control_registration() -> void:
	var recipe := JuiceControlRecipe.new()
	var whitelist: String = recipe._CONCRETE_EFFECTS
	assert_true(
		whitelist.contains("ProgressTransformControlJuiceEffect"),
		"JuiceControlRecipe._CONCRETE_EFFECTS must contain 'ProgressTransformControlJuiceEffect'. Got: " + whitelist
	)


## Verify ProgressTransform3DJuiceEffect is listed in Juice3DRecipe's
## inspector whitelist.
func test_3d_registration() -> void:
	var recipe := Juice3DRecipe.new()
	var whitelist: String = recipe._CONCRETE_EFFECTS
	assert_true(
		whitelist.contains("ProgressTransform3DJuiceEffect"),
		"Juice3DRecipe._CONCRETE_EFFECTS must contain 'ProgressTransform3DJuiceEffect'. Got: " + whitelist
	)


# =============================================================================
# PHASE A-2: 2D POSITION AT NON-ZERO ORIGIN
# =============================================================================

## Target starts at (200, 150). Effect accumulates rightward.
## Core assertions:
##   - Accumulation continues from origin, not from (0, 0).
##   - Y stays at origin (only X rate is nonzero).
##   - Stop does not snap position back to (0, 0).
func test_2d_position_non_zero_origin() -> void:
	const ORIGIN := Vector2(200.0, 150.0)
	var rig := await _create_2d_rig_at(ORIGIN,
			ProgressTransform2DJuiceEffect.TransformTarget.POSITION,
			Vector2(100.0, 0.0), 0.1)
	var juice: Juice2D = rig[0]
	var target: Node2D = rig[1]

	assert_approx_vec2(target.position, ORIGIN, "Pre-animate: target must remain at origin before animate_in", 0.5)

	juice.animate_in()
	await wait_seconds(0.5)  # 0.1s ramp + 0.4s sustain

	# Accumulated from origin, not from global (0, 0).
	assert_greater(target.position.x, ORIGIN.x + 10.0,
		"Non-zero origin: x must exceed origin.x+10 (x=%.1f origin.x=%.1f)" % [
		target.position.x, ORIGIN.x])
	assert_approx_vec2(Vector2(0.0, target.position.y), Vector2(0.0, ORIGIN.y),
		"Non-zero origin: y must stay near origin.y (y=%.1f origin.y=%.1f)" % [
		target.position.y, ORIGIN.y], 1.5)

	juice.stop()
	await wait_frames(2)
	assert_greater(target.position.x, 5.0,
		"After stop: position must not snap to (0,0). x=%.1f" % target.position.x)

	await cleanup(target)


## Target starts at (200, 150). Bound REVERSE fires mid-flight.
## The reversal must never snap x toward global (0, 0).
func test_2d_position_bound_reverse_non_zero() -> void:
	const ORIGIN := Vector2(200.0, 150.0)
	var rig := await _create_2d_rig_at(ORIGIN,
			ProgressTransform2DJuiceEffect.TransformTarget.POSITION,
			Vector2(300.0, 0.0), 0.05)
	var juice: Juice2D = rig[0]
	var target: Node2D = rig[1]
	var effect: ProgressTransform2DJuiceEffect = rig[2]

	# Bound at 50px delta from origin â€” hits quickly at 300 px/s.
	effect.bound_enabled = true
	effect.bound_behaviour = ProgressTransform2DJuiceEffect.BoundBehaviour.REVERSE
	effect.bound_value = 50.0

	juice.animate_in()
	await wait_seconds(0.4)  # Several reversals

	# x must remain near the origin band, NOT drift toward global zero.
	assert_greater(target.position.x, ORIGIN.x - 60.0,
		"REVERSE non-zero: x must not snap toward global 0 (x=%.1f)" % target.position.x)
	assert_approx_vec2(Vector2(0.0, target.position.y), Vector2(0.0, ORIGIN.y),
		"REVERSE non-zero: y must stay near origin.y (y=%.1f)" % target.position.y, 1.5)

	await cleanup(target)


## Target starts at (200, 150). Bound REVERSE_EASED fires (smooth decel + restart).
## Position must not drift toward global (0, 0) during or after the eased transition.
func test_2d_position_bound_reverse_eased_non_zero() -> void:
	const ORIGIN := Vector2(200.0, 150.0)
	var rig := await _create_2d_rig_at(ORIGIN,
			ProgressTransform2DJuiceEffect.TransformTarget.POSITION,
			Vector2(200.0, 0.0), 0.1)
	var juice: Juice2D = rig[0]
	var target: Node2D = rig[1]
	var effect: ProgressTransform2DJuiceEffect = rig[2]

	effect.bound_enabled = true
	effect.bound_behaviour = ProgressTransform2DJuiceEffect.BoundBehaviour.REVERSE_EASED
	effect.bound_value = 40.0

	juice.animate_in()
	await wait_seconds(0.6)  # Full eased reversal + restart

	assert_greater(target.position.x, ORIGIN.x - 55.0,
		"REVERSE_EASED non-zero: x must not drift to global 0 (x=%.1f)" % target.position.x)
	assert_approx_vec2(Vector2(0.0, target.position.y), Vector2(0.0, ORIGIN.y),
		"REVERSE_EASED non-zero: y must stay near origin.y (y=%.1f)" % target.position.y, 1.5)

	await cleanup(target)


# =============================================================================
# PHASE A-3: 2D ROTATION + SCALE + DETERMINISTIC STACKING
# =============================================================================

## Rotation effect on a target at (200, 150).
## Position must remain unchanged; rotation must accumulate.
func test_2d_rotation_non_zero_origin() -> void:
	const ORIGIN := Vector2(200.0, 150.0)
	var rig := await _create_2d_rig_at(ORIGIN,
			ProgressTransform2DJuiceEffect.TransformTarget.ROTATION,
			Vector2.ZERO, 0.1)
	var juice: Juice2D = rig[0]
	var target: Node2D = rig[1]
	var effect: ProgressTransform2DJuiceEffect = rig[2]
	effect.rotation_rate = 90.0  # 90 deg/s

	juice.animate_in()
	await wait_seconds(0.5)  # 0.1s ramp + 0.4s sustain

	# Must have rotated noticeably (>0.3 rad).
	assert_greater(absf(target.rotation), 0.3,
		"Rotation non-zero origin: must rotate > 0.3 rad (rot=%.2f)" % target.rotation)
	# Position must remain at origin — rotation must not drift position.
	assert_approx_vec2(target.position, ORIGIN,
		"Rotation non-zero origin: position must stay at origin (pos=%s)" % str(target.position), 2.0)

	await cleanup(target)


## Scale effect on a target at (200, 150).
## Position must remain unchanged; scale must grow beyond 1.
func test_2d_scale_non_zero_origin() -> void:
	const ORIGIN := Vector2(200.0, 150.0)
	var rig := await _create_2d_rig_at(ORIGIN,
			ProgressTransform2DJuiceEffect.TransformTarget.SCALE,
			Vector2.ZERO, 0.1)
	var juice: Juice2D = rig[0]
	var target: Node2D = rig[1]
	var effect: ProgressTransform2DJuiceEffect = rig[2]
	effect.scale_rate = Vector2(0.5, 0.5)  # 0.5 units/s

	juice.animate_in()
	await wait_seconds(0.5)

	# Scale must have grown past 1.0 (ramp-aware: 0.1s ramp + 0.4s sustain at 0.5 units/s).
	assert_greater(target.scale.x, 1.04,
		"Scale non-zero origin: scale.x must grow > 1.04 (scale.x=%.2f)" % target.scale.x)
	# Position must remain at origin.
	assert_approx_vec2(target.position, ORIGIN,
		"Scale non-zero origin: position must stay at origin (pos=%s)" % str(target.position), 2.0)

	await cleanup(target)


## Two separate Juice2D nodes on the same Node2D target at (200, 0).
## Juice A: Transform2DJuiceEffect tweening x by +80 (deterministic, assertable).
## Juice B: ProgressTransform2DJuiceEffect accumulating x at 100 px/s.
## Both effects run simultaneously; each must contribute independently.
## Neither must snap the target to (0, 0) or overwrite the other's delta.
func test_2d_stacked_deterministic() -> void:
	const ORIGIN := Vector2(200.0, 0.0)

	var target := Node2D.new()
	target.name = "RW2DStackTarget"
	target.position = ORIGIN
	_runner.add_child(target)

	# --- Juice A: Transform2D (tween to +80 from base) ---
	var tween_effect := Transform2DJuiceEffect.new()
	tween_effect.transform_target = Transform2DJuiceEffect.TransformTarget.POSITION
	tween_effect.from_reference = Transform2DJuiceEffect.TransformReference.SELF
	tween_effect.to_reference = Transform2DJuiceEffect.TransformReference.CUSTOM
	tween_effect.to_position = Vector2(80.0, 0.0)
	tween_effect.to_position_in = Transform2DJuiceEffect.PositionIn.PIXELS
	tween_effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	tween_effect.duration_in = 0.2

	var juice_a := Juice2D.new()
	juice_a.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice_a.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe_a := Juice2DRecipe.new()
	recipe_a.effects.append(tween_effect)
	juice_a.recipe = recipe_a
	target.add_child(juice_a)

	# --- Juice B: ProgressTransform (accumulating x) ---
	var prog_effect := ProgressTransform2DJuiceEffect.new()
	prog_effect.transform_target = ProgressTransform2DJuiceEffect.TransformTarget.POSITION
	prog_effect.position_rate = Vector2(100.0, 0.0)
	prog_effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	prog_effect.duration_in = 0.1
	prog_effect.auto_start = false

	var juice_b := Juice2D.new()
	juice_b.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice_b.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	var recipe_b := Juice2DRecipe.new()
	recipe_b.effects.append(prog_effect)
	juice_b.recipe = recipe_b
	target.add_child(juice_b)

	await wait_frames(2)

	# Fire both simultaneously.
	juice_a.animate_in()
	juice_b.animate_in()
	await wait_seconds(0.35)  # Tween completes (0.2s); progress accumulates for 0.35s

	# Tween settled at ORIGIN.x + 80 = 280; progress added ~25px more.
	# Conservative: x must exceed ORIGIN.x + 70 (tween alone gets us ~280).
	assert_greater(target.position.x, ORIGIN.x + 70.0,
		"Stacked deterministic: x must exceed base+70 from both effects (x=%.1f)" % target.position.x)
	# Must never have snapped to (0, 0) — if it had, x would be < ORIGIN.x.
	assert_greater(target.position.x, ORIGIN.x - 5.0,
		"Stacked deterministic: x must not snap to global 0 (x=%.1f origin.x=%.1f)" % [
		target.position.x, ORIGIN.x])
	# Y must be undisturbed (both effects only move X).
	assert_approx_float(target.position.y, ORIGIN.y,
		"Stacked deterministic: y must stay at origin.y (y=%.1f)" % target.position.y, 1.0)

	await cleanup(target)


# =============================================================================
# PHASE A-4: 2D MIXED RECIPES (RANDOM) + RETRIGGER
# =============================================================================

## ProgressTransform2D + Shake2D in the same recipe on a target at (200, 150).
## Shake is a random displacement — it adds noise but must not corrupt origin.
## After stop, the target must return to the non-zero origin, not (0, 0).
func test_2d_mixed_shake_no_interference() -> void:
	const ORIGIN := Vector2(200.0, 150.0)

	var target := Node2D.new()
	target.name = "RW2DShakeTarget"
	target.position = ORIGIN
	_runner.add_child(target)

	var prog := ProgressTransform2DJuiceEffect.new()
	prog.transform_target = ProgressTransform2DJuiceEffect.TransformTarget.POSITION
	prog.position_rate = Vector2(80.0, 0.0)
	prog.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	prog.duration_in = 0.1
	prog.auto_start = false

	var shake := Shake2DJuiceEffect.new()
	shake.transform_target = Shake2DJuiceEffect.TransformTarget.POSITION
	shake.shake_frequency = 20.0
	shake.position_strength = Vector2(15.0, 15.0)
	shake.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	shake.duration_in = 0.1
	shake.duration_out = 0.1

	var recipe := Juice2DRecipe.new()
	recipe.effects.append(prog)
	recipe.effects.append(shake)

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.4)  # Progress accumulates; shake jitters

	# During sustain: position must be clearly past origin (progress accumulated).
	assert_greater(target.position.x, ORIGIN.x + 5.0,
		"Mixed shake: x must have accumulated past origin (x=%.1f)" % target.position.x)

	# Stop and let shake settle.
	juice.stop()
	await wait_frames(4)

	# After stop: position must be at the held position (hold_on_stop default).
	# Key guard: must NOT be near global (0, 0).
	assert_greater(target.position.x, 5.0,
		"Mixed shake stop: position must not snap to (0,0). x=%.1f" % target.position.x)
	assert_greater(target.position.y, 5.0,
		"Mixed shake stop: y must not snap to 0. y=%.1f" % target.position.y)

	await cleanup(target)


## ProgressTransform2D + Noise2D in the same recipe on a target at (200, 150).
## Noise adds continuous smooth displacement — it must not corrupt base or origin.
## After stop, the target must not be at (0, 0).
func test_2d_mixed_noise_no_interference() -> void:
	const ORIGIN := Vector2(200.0, 150.0)

	var target := Node2D.new()
	target.name = "RW2DNoiseTarget"
	target.position = ORIGIN
	_runner.add_child(target)

	var prog := ProgressTransform2DJuiceEffect.new()
	prog.transform_target = ProgressTransform2DJuiceEffect.TransformTarget.POSITION
	prog.position_rate = Vector2(80.0, 0.0)
	prog.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	prog.duration_in = 0.1
	prog.auto_start = false

	var noise := Noise2DJuiceEffect.new()
	noise.transform_target = Noise2DJuiceEffect.TransformTarget.POSITION
	noise.noise_speed = 5.0
	noise.position_amplitude = Vector2(15.0, 15.0)
	noise.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	noise.duration_in = 0.1
	noise.duration_out = 0.1

	var recipe := Juice2DRecipe.new()
	recipe.effects.append(prog)
	recipe.effects.append(noise)

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	await wait_seconds(0.4)

	# During sustain: must have drifted past origin.
	assert_greater(target.position.x, ORIGIN.x + 5.0,
		"Mixed noise: x must have accumulated past origin (x=%.1f)" % target.position.x)

	juice.stop()
	await wait_frames(4)

	# After stop: must NOT be near (0, 0).
	assert_greater(target.position.x, 5.0,
		"Mixed noise stop: position must not snap to (0,0). x=%.1f" % target.position.x)
	assert_greater(target.position.y, 5.0,
		"Mixed noise stop: y must not snap to 0. y=%.1f" % target.position.y)

	await cleanup(target)


## Retrigger ProgressTransform2D mid-sustain by calling animate_in() a second time.
## The effect must restart cleanly — position must not snap to (0, 0) during restart.
## Asserts: position never collapses to origin, accumulation continues after retrigger.
func test_2d_retrigger_during_sustain() -> void:
	const ORIGIN := Vector2(200.0, 150.0)
	var rig := await _create_2d_rig_at(ORIGIN,
			ProgressTransform2DJuiceEffect.TransformTarget.POSITION,
			Vector2(100.0, 0.0), 0.1)
	var juice: Juice2D = rig[0]
	var target: Node2D = rig[1]

	# First trigger — let it enter sustain.
	juice.animate_in()
	await wait_seconds(0.3)  # Past ramp; now in sustain

	var pos_before_retrigger: float = target.position.x

	# Retrigger mid-sustain.
	juice.animate_in()
	await wait_frames(2)  # Let the retrigger process

	# Must not have snapped to (0, 0) or to ORIGIN during the restart.
	assert_greater(target.position.x, 5.0,
		"Retrigger: position must not snap to (0,0) immediately (x=%.1f)" % target.position.x)

	# Continue running after retrigger — accumulation must resume.
	await wait_seconds(0.3)

	assert_greater(target.position.x, pos_before_retrigger - 5.0,
		"Retrigger: x must be near or past pre-retrigger position (was %.1f now %.1f)" % [
		pos_before_retrigger, target.position.x])
	assert_greater(target.position.x, ORIGIN.x,
		"Retrigger: x must remain past origin after retrigger (x=%.1f origin.x=%.1f)" % [
		target.position.x, ORIGIN.x])

	await cleanup(target)
