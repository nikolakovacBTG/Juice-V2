## TestPropertyFamily.gd
## ============================================================================
## WHAT: Integration tests for the InterpolateProperty effect family (Phase 6.2).
## WHY:  Verifies that PropertyInterpolateJuiceEffectBase correctly drives the
##       Ledger for continuous (float, Vector2, Color) and discrete (bool) types,
##       and that flush() writes the expected value to the target node at
##       various progress points.
## SYSTEM: Tests (tests/)
## DOES NOT: Test the full JuiceBase lifecycle — the effect is driven manually
##            via _on_animate_start() / _apply_effect() to isolate effect logic.
## ============================================================================
## Tests written during: Phase 6.2 (InterpolateProperty Family)
extends JuiceTestSuite

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------

# Manually drives effect._on_animate_start → _apply_effect → flush.
# Returns the target node so callers can assert its property values.
func _drive(effect: PropertyInterpolateJuiceEffectBase, target: Node, progress: float) -> void:
	effect._on_animate_start(target)
	effect._apply_effect(progress, target)
	JuiceLedger.flush(target)


# Builds a minimal PropertyInterpolate2DJuiceEffect with one typed target.
func _make_2d_effect(prop: String, detected_type: int,
		from_v: Variant, to_v: Variant,
		mode: InterpolatePropertyTarget.CaptureMode = InterpolatePropertyTarget.CaptureMode.CUSTOM
) -> PropertyInterpolate2DJuiceEffect:
	var entry := InterpolatePropertyTarget.new()
	entry.property_path = prop
	entry._detected_type = detected_type
	entry.capture_from = mode
	entry.capture_to = mode
	# Assign the backing var matching detected_type.
	match detected_type:
		TYPE_FLOAT:       entry.from_float  = from_v; entry.to_float  = to_v
		TYPE_VECTOR2:     entry.from_vec2   = from_v; entry.to_vec2   = to_v
		TYPE_COLOR:       entry.from_color  = from_v; entry.to_color  = to_v
		TYPE_BOOL:        entry.from_bool   = from_v; entry.to_bool   = to_v
	var effect := PropertyInterpolate2DJuiceEffect.new()
	effect.property_targets.append(entry)
	return effect

# ---------------------------------------------------------------------------
# REGISTRATION
# ---------------------------------------------------------------------------

func get_suite_name() -> String:
	return "property_family_v2"


func get_test_methods() -> Array[String]:
	return [
		"test_interpolate_float_property_reaches_target",
		"test_interpolate_vector2_property_reaches_target",
		"test_interpolate_color_property_reaches_target",
		"test_discrete_bool_property_flips_at_threshold",
	]

# ---------------------------------------------------------------------------
# TESTS
# ---------------------------------------------------------------------------

## At progress=1.0 a float property equals to_float.
func test_interpolate_float_property_reaches_target() -> void:
	var target := create_2d_target()
	target.rotation = 0.0
	var effect := _make_2d_effect("rotation", TYPE_FLOAT, 0.0, 1.5)
	_drive(effect, target, 1.0)
	assert_approx_float(target.rotation, 1.5, "rotation should reach to_float=1.5 at progress=1.0")
	JuiceLedger.cleanup_source(target, effect)
	await cleanup(target)


## At progress=1.0 a Vector2 property equals to_vec2.
func test_interpolate_vector2_property_reaches_target() -> void:
	var target := create_2d_target()
	target.position = Vector2.ZERO
	var effect := _make_2d_effect("position", TYPE_VECTOR2, Vector2.ZERO, Vector2(100.0, 50.0))
	_drive(effect, target, 1.0)
	assert_approx_vec2(target.position, Vector2(100.0, 50.0),
			"position should reach to_vec2=(100,50) at progress=1.0")
	JuiceLedger.cleanup_source(target, effect)
	await cleanup(target)


## At progress=1.0 a Color property (modulate) equals to_color.
## Base must be non-zero: Color multiplied-factor path saturates when base channel=0.
func test_interpolate_color_property_reaches_target() -> void:
	var target := create_2d_target()
	target.modulate = Color.WHITE   # base = (1,1,1,1) — all channels non-zero
	var effect := _make_2d_effect("modulate", TYPE_COLOR, Color.WHITE, Color(1.0, 0.0, 0.0, 1.0))
	_drive(effect, target, 1.0)
	var red := Color(1.0, 0.0, 0.0, 1.0)
	assert_approx_vec2(
			Vector2(target.modulate.r, target.modulate.g),
			Vector2(red.r, red.g),
			"modulate.rg should reach RED.rg at progress=1.0")
	assert_approx_float(target.modulate.b, red.b, "modulate.b should reach RED.b=0")
	JuiceLedger.cleanup_source(target, effect)
	await cleanup(target)


## A bool (visible) flips from FROM to TO when progress crosses flip_threshold.
func test_discrete_bool_property_flips_at_threshold() -> void:
	var target := create_2d_target()
	target.visible = true   # base = true
	var effect := _make_2d_effect("visible", TYPE_BOOL, true, false)
	var entry := effect.property_targets[0] as InterpolatePropertyTarget
	entry.flip_threshold = 0.5

	# Before threshold — should hold FROM (true)
	_drive(effect, target, 0.3)
	assert_true(target.visible, "visible should remain true before flip_threshold=0.5")

	# After threshold — should hold TO (false)
	_drive(effect, target, 0.7)
	assert_false(target.visible, "visible should flip to false after flip_threshold=0.5")

	JuiceLedger.cleanup_source(target, effect)
	# cleanup_source permanently removes ledger — restore visible manually for cleanup
	target.visible = true
	await cleanup(target)
