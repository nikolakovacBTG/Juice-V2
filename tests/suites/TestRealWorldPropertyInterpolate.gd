## TestRealWorldPropertyInterpolate.gd
## Realistic integration tests for InterpolatePropertyJuiceEffectBase across
## all three domains (Control, 2D, 3D). Covers new type families introduced in
## the Phase 2 refactor: int, Color, Vector2, bool threshold-flip, and
## ON_TRIGGER capture. Tests use grids of targets at non-zero positions so that
## spatial offset does not mask bugs.
##
## These tests complement the unit tests in TestPropertyFamily.gd which cover
## inspector display logic only. Here we verify that values actually reach their
## targets at runtime through the full animate_in() lifecycle.

# =============================================================================
# WHAT: Realistic runtime tests for PropertyInterpolate — grid layouts, all
#       three domains, new type families (int, Vector2, Color, bool flip).
# WHY:  Unit tests set _detected_type directly and skip the lerp path for most
#       types. Realistic tests drive the full animate_in() lifecycle on the live
#       Juice node to catch lerp-branch regressions and domain-specific wiring.
# SYSTEM: Tests (tests/suites/)
# DOES NOT: Test editor-time capture buttons or picker dialog UI — those require
#            a running editor context and are covered by manual test plans.
# =============================================================================

extends JuiceTestSuite


func get_suite_name() -> String:
	return "real_world_property_interpolate"


func get_test_methods() -> Array[String]:
	return [
		# --- Control domain ---
		"test_control_float_grid_all_reach_target",
		"test_control_color_reaches_target",
		"test_control_bool_flips_at_threshold",
		"test_control_vector2_reaches_target",
		"test_control_on_trigger_captures_current_value",
		"test_control_in_container_not_reset_by_sort",
		# --- 2D domain ---
		"test_2d_int_reaches_target",
		"test_2d_ledger_property_is_blocked",
		"test_2d_int_z_index_reaches_target",
		# --- 3D domain ---
		"test_3d_int_process_priority_reaches_target",
	]


# =============================================================================
# HELPERS
# =============================================================================

# Build a minimal Control + JuiceControl + PropertyInterpolate rig.
# Returns [Control (Button), JuiceControl].
func _make_control_interpolate_rig(
		property: String,
		detected_type: int,
		from_val,
		to_val,
		capture_from: int = InterpolatePropertyTarget.CaptureMode.CUSTOM,
		capture_to: int = InterpolatePropertyTarget.CaptureMode.CUSTOM,
		duration: float = 0.25
) -> Array:
	var ctrl := create_control_target("InterpCtrl")

	var target := InterpolatePropertyTarget.new()
	target.property_path  = property
	target.capture_from   = capture_from
	target.capture_to     = capture_to
	# Force detected type — headless mode skips _detect_type() because
	# Node.get_indexed() may return TYPE_NIL without a rendered scene.
	target._detected_type = detected_type

	# Assign the correct backing var for the type so _custom_value() reads it.
	match detected_type:
		TYPE_BOOL:
			target.from_bool      = from_val
			target.to_bool        = to_val
			target.flip_threshold = 0.5
		TYPE_INT:
			target.from_int  = from_val
			target.to_int    = to_val
		TYPE_FLOAT:
			target.from_float = from_val
			target.to_float   = to_val
		TYPE_VECTOR2:
			target.from_vec2 = from_val
			target.to_vec2   = to_val
		TYPE_COLOR:
			target.from_color = from_val
			target.to_color   = to_val

	var effect := PropertyInterpolateControlJuiceEffect.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = duration
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
# CONTROL DOMAIN TESTS
# =============================================================================

# Verifies the core float path on a 6-node grid at varied positions.
# If any positional offset or stacking bug exists at least one node will fail.
func test_control_float_grid_all_reach_target() -> void:
	var nodes: Array = []
	var juices: Array = []

	for i in range(6):
		var rig := await _make_control_interpolate_rig(
			"modulate:a", TYPE_FLOAT, 0.0, 1.0)
		var ctrl: Control = rig[0]
		ctrl.position = Vector2(i * 40, i * 20)  # Non-zero positions
		ctrl.modulate.a = 0.0
		nodes.append(ctrl)
		juices.append(rig[1])

	for j: JuiceControl in juices:
		j.animate_in()

	await wait_seconds(0.5)

	for idx in range(nodes.size()):
		var alpha: float = nodes[idx].modulate.a
		assert_true(alpha > 0.85,
			"Grid[%d]: modulate:a should reach ~1.0 (got %.3f)" % [idx, alpha])

	for n in nodes:
		await cleanup(n)


# Verifies the TYPE_COLOR lerp branch via the modulate Color property.
func test_control_color_reaches_target() -> void:
	var rig := await _make_control_interpolate_rig(
		"modulate", TYPE_COLOR,
		Color(0.0, 0.0, 0.0, 0.0), Color(1.0, 1.0, 1.0, 1.0))
	var ctrl: Control = rig[0]
	var juice: JuiceControl = rig[1]
	ctrl.modulate = Color(0, 0, 0, 0)

	juice.animate_in()
	await wait_seconds(0.5)

	var c: Color = ctrl.modulate
	assert_true(c.r > 0.85 and c.g > 0.85 and c.b > 0.85 and c.a > 0.85,
		"COLOR lerp: all channels should be ~1.0 (got %s)" % str(c))
	await cleanup(ctrl)


# Verifies threshold-flip semantics for TYPE_BOOL on the `visible` property.
# flip_threshold=0.5 means the flip occurs halfway through the animation curve.
func test_control_bool_flips_at_threshold() -> void:
	var ctrl := create_control_target("BoolFlipCtrl")
	ctrl.visible = false

	var target := InterpolatePropertyTarget.new()
	target.property_path  = "visible"
	target.capture_from   = InterpolatePropertyTarget.CaptureMode.CUSTOM
	target.capture_to     = InterpolatePropertyTarget.CaptureMode.CUSTOM
	target._detected_type = TYPE_BOOL
	target.from_bool      = false
	target.to_bool        = true
	target.flip_threshold = 0.5

	var effect := PropertyInterpolateControlJuiceEffect.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.4
	effect.property_targets.append(target)

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	ctrl.add_child(juice)
	await wait_frames(3)

	juice.animate_in()

	# At ~20% through (0.08s into 0.4s), visible should still be false.
	await wait_seconds(0.08)
	assert_false(ctrl.visible,
		"Before threshold (20%%): `visible` should still be false")

	# At ~70% through (0.28s total), flip_threshold=0.5 has been passed.
	await wait_seconds(0.20)
	assert_true(ctrl.visible,
		"After threshold (70%%): `visible` should now be true")

	await cleanup(ctrl)


# Verifies the TYPE_VECTOR2 lerp branch on custom_minimum_size.
func test_control_vector2_reaches_target() -> void:
	var ctrl := create_control_target("Vec2Ctrl")
	ctrl.custom_minimum_size = Vector2(0, 0)

	var target := InterpolatePropertyTarget.new()
	target.property_path  = "custom_minimum_size"
	target.capture_from   = InterpolatePropertyTarget.CaptureMode.CUSTOM
	target.capture_to     = InterpolatePropertyTarget.CaptureMode.CUSTOM
	target._detected_type = TYPE_VECTOR2
	target.from_vec2      = Vector2(0, 0)
	target.to_vec2        = Vector2(80, 60)

	var effect := PropertyInterpolateControlJuiceEffect.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.25
	effect.property_targets.append(target)

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	ctrl.add_child(juice)
	await wait_frames(3)

	juice.animate_in()
	await wait_seconds(0.45)

	var sz: Vector2 = ctrl.custom_minimum_size
	assert_true(sz.x > 65.0 and sz.y > 48.0,
		"VECTOR2 lerp: custom_minimum_size should reach ~(80,60) (got %s)" % str(sz))
	await cleanup(ctrl)


# Verifies ON_TRIGGER capture mode stores the property value at trigger time.
func test_control_on_trigger_captures_current_value() -> void:
	var rig := await _make_control_interpolate_rig(
		"modulate:a", TYPE_FLOAT, 0.0, 1.0,
		InterpolatePropertyTarget.CaptureMode.ON_TRIGGER,
		InterpolatePropertyTarget.CaptureMode.CUSTOM)
	var ctrl: Control = rig[0]
	var juice: JuiceControl = rig[1]
	ctrl.modulate.a = 0.37  # This value should be captured at trigger time

	juice.animate_in()
	await wait_frames(2)

	var rt_effect: PropertyInterpolateControlJuiceEffect = juice._runtime_effects[0]
	var rt_target: InterpolatePropertyTarget = rt_effect.property_targets[0]
	var captured_from := float(rt_target._runtime_from) if rt_target._runtime_from != null else -1.0
	assert_true(absf(captured_from - 0.37) < 0.02,
		"ON_TRIGGER should capture modulate:a=0.37 at trigger time (got %.3f)" % captured_from)
	await cleanup(ctrl)


# Verifies that a Control inside a VBoxContainer is not reset by Container._sort_children().
func test_control_in_container_not_reset_by_sort() -> void:
	var vbox := VBoxContainer.new()
	_runner.add_child(vbox)

	var rig := await _make_control_interpolate_rig(
		"modulate:a", TYPE_FLOAT, 0.0, 1.0)
	var ctrl: Control = rig[0]
	var juice: JuiceControl = rig[1]
	ctrl.modulate.a = 0.0
	# Re-parent ctrl into the vbox; juice remains a child of ctrl so the rig is intact.
	ctrl.reparent(vbox)
	await wait_frames(5)

	juice.animate_in()
	await wait_seconds(0.45)

	assert_true(ctrl.modulate.a > 0.85,
		"Container-hosted Control: modulate:a should still reach ~1.0 (got %.3f)" % ctrl.modulate.a)

	vbox.queue_free()
	await wait_frames(3)


# =============================================================================
# 2D DOMAIN TESTS
# =============================================================================

# Verifies the 2D int lerp branch. Uses z_index — a TYPE_INT property on Node2D
# that is not ledger-managed, so set_indexed writes are not overwritten each frame.
# Doubles as a regression test for the int → float promotion path in _compute_lerp.
func test_2d_int_reaches_target() -> void:
	var node := create_2d_target()
	node.z_index = 0

	var target := InterpolatePropertyTarget.new()
	target.property_path  = "z_index"
	target.capture_from   = InterpolatePropertyTarget.CaptureMode.CUSTOM
	target.capture_to     = InterpolatePropertyTarget.CaptureMode.CUSTOM
	target._detected_type = TYPE_INT
	target.from_int       = 0
	target.to_int         = 20

	var effect := PropertyInterpolate2DJuiceEffect.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.25
	effect.property_targets.append(target)

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	node.add_child(juice)
	await wait_frames(3)

	juice.animate_in()
	await wait_seconds(0.45)

	assert_true(node.z_index >= 18,
		"2D int: z_index should reach ~20 after animation (got %d)" % node.z_index)
	await cleanup(node)


# Verifies that targeting a Ledger-managed property (modulate) is silently blocked.
# The guard in _apply_effect skips the write — value stays at 0.0 because the domain
# owns modulate and we never conflict with it. This is the CORRECT expected behavior.
func test_2d_ledger_property_is_blocked() -> void:
	var node := create_2d_target()
	node.modulate.a = 0.0

	var target := InterpolatePropertyTarget.new()
	target.property_path  = "modulate"
	target.capture_from   = InterpolatePropertyTarget.CaptureMode.CUSTOM
	target.capture_to     = InterpolatePropertyTarget.CaptureMode.CUSTOM
	target._detected_type = TYPE_COLOR
	target.from_color     = Color(0, 0, 0, 0)
	target.to_color       = Color(1, 1, 1, 1)

	var effect := PropertyInterpolate2DJuiceEffect.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.25
	effect.property_targets.append(target)

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	node.add_child(juice)
	await wait_frames(3)

	juice.animate_in()
	await wait_seconds(0.45)

	# modulate.a stays at 0 because the guard blocked the write. This is correct
	# — the Juice Ledger owns modulate, not the Property effect.
	assert_true(node.modulate.a < 0.05,
		"Ledger-guard: modulate should NOT be written by PropertyInterpolate (got %.3f)" % node.modulate.a)
	await cleanup(node)


# Uses z_index (TYPE_INT) — a native integer property on Node2D.
func test_2d_int_z_index_reaches_target() -> void:
	var node := create_2d_target()
	node.z_index = 0

	var target := InterpolatePropertyTarget.new()
	target.property_path  = "z_index"
	target.capture_from   = InterpolatePropertyTarget.CaptureMode.CUSTOM
	target.capture_to     = InterpolatePropertyTarget.CaptureMode.CUSTOM
	target._detected_type = TYPE_INT
	target.from_int       = 0
	target.to_int         = 10

	var effect := PropertyInterpolate2DJuiceEffect.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.25
	effect.property_targets.append(target)

	var juice := Juice2D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	node.add_child(juice)
	await wait_frames(3)

	juice.animate_in()
	await wait_seconds(0.4)

	assert_true(node.z_index >= 8,
		"2D int: z_index should reach ~10 (got %d)" % node.z_index)
	await cleanup(node)


# =============================================================================
# 3D DOMAIN TESTS
# =============================================================================

# Verifies PropertyInterpolate3DJuiceEffect via process_priority — a TYPE_INT
# property on Node (base class of Node3D) that is NOT ledger-managed.
# z_index does not exist on Node3D; process_priority is the cleanest neutral int.
func test_3d_int_process_priority_reaches_target() -> void:
	var node := create_3d_target()
	node.process_priority = 0

	var target := InterpolatePropertyTarget.new()
	target.property_path  = "process_priority"
	target.capture_from   = InterpolatePropertyTarget.CaptureMode.CUSTOM
	target.capture_to     = InterpolatePropertyTarget.CaptureMode.CUSTOM
	target._detected_type = TYPE_INT
	target.from_int       = 0
	target.to_int         = 10

	var effect := PropertyInterpolate3DJuiceEffect.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.25
	effect.property_targets.append(target)

	var juice := Juice3D.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := Juice3DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	node.add_child(juice)
	await wait_frames(3)

	juice.animate_in()
	await wait_seconds(0.45)

	assert_true(node.process_priority >= 8,
		"3D int: process_priority should reach ~10 (got %d)" % node.process_priority)
	await cleanup(node)
