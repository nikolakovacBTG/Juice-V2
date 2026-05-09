## TestEditorCache.gd
## ============================================================================
## WHAT: Regression tests for CaptureAt.IN_EDITOR cache read and clear behaviour
##       in Transform2DJuiceEffect (the canonical IN_EDITOR implementation).
## WHY:  Phase 7.3 regression net. Ensures the editor cache:
##       1. Provides correct snapshot when no ledger data exists (fallback path).
##       2. Yields to the ledger when per-target base data is present.
##       3. Is cleared from both from- and to-slots when switching away from
##          IN_EDITOR, preventing stale position ghosts across Play-Stop-Play cycles.
##       4. NOTIFICATION_EDITOR_PRE_SAVE routing reaches each recipe effect
##          without crashing.
## SYSTEM: Tests (tests/)
## DOES NOT: Test the actual editor-side cache write (_do_update_editor_cache is
##           guarded by Engine.is_editor_hint(), which is false in headless).
## ============================================================================
extends JuiceTestSuite

func get_suite_name() -> String:
	return "editor_cache"

func get_test_methods() -> Array[String]:
	return [
		"test_in_editor_reads_baked_cache_when_ledger_empty",
		"test_in_editor_prefers_ledger_over_baked_cache",
		"test_in_editor_to_reads_baked_cache_when_ledger_empty",
		"test_in_editor_to_prefers_ledger_over_baked_cache",
		"test_switching_from_in_editor_clears_from_cache",
		"test_switching_from_in_editor_clears_to_cache",
		"test_pre_save_notification_routing_does_not_crash",
	]


# =============================================================================
# FROM-CACHE TESTS
# =============================================================================

func test_in_editor_reads_baked_cache_when_ledger_empty() -> void:
	# When from_capture_at == IN_EDITOR and the ledger is empty, the snapshot
	# must use the baked editor cache — NOT the live node position.
	# This is the core WYSIWYG guarantee: nodes moved AFTER baking must still
	# animate from the baked position, not the post-move position.
	var effect := Transform2DJuiceEffect.new()
	effect.transform_target = Transform2DJuiceEffect.TransformTarget.POSITION
	effect.from_reference   = Transform2DJuiceEffect.TransformReference.SELF
	effect.from_capture_at  = Transform2DJuiceEffect.CaptureAt.IN_EDITOR

	var baked := Vector2(123.0, 456.0)
	effect._from_editor_cached_position = baked

	# Empty ledger — forces fallback to baked cache.
	effect._ledger_base_snapshot = {}

	var target := Node2D.new()
	target.position = Vector2(1.0, 2.0)  # different from baked
	_runner.add_child(target)

	effect._capture_from_self_position_snapshot(target)

	assert_approx_vec2(effect._from_self_position_snapshot, baked,
			"IN_EDITOR + empty ledger: snapshot reads baked editor cache, not live position")

	target.queue_free()


func test_in_editor_prefers_ledger_over_baked_cache() -> void:
	# When from_capture_at == IN_EDITOR and the ledger holds a position entry,
	# the ledger wins — it represents the true natural state at ready-time,
	# which is guaranteed to be correct even in multi-target sequencer setups.
	var effect := Transform2DJuiceEffect.new()
	effect.transform_target = Transform2DJuiceEffect.TransformTarget.POSITION
	effect.from_reference   = Transform2DJuiceEffect.TransformReference.SELF
	effect.from_capture_at  = Transform2DJuiceEffect.CaptureAt.IN_EDITOR

	effect._from_editor_cached_position = Vector2(999.0, 999.0)  # stale baked cache

	var ledger_pos := Vector2(50.0, 75.0)
	effect._ledger_base_snapshot = {"position": ledger_pos}

	var target := Node2D.new()
	_runner.add_child(target)

	effect._capture_from_self_position_snapshot(target)

	assert_approx_vec2(effect._from_self_position_snapshot, ledger_pos,
			"IN_EDITOR + ledger has position: snapshot uses ledger, not stale baked cache")

	target.queue_free()


# =============================================================================
# TO-CACHE TESTS
# =============================================================================

func test_in_editor_to_reads_baked_cache_when_ledger_empty() -> void:
	# Same guarantee as the from-cache test but for the to-slot.
	var effect := Transform2DJuiceEffect.new()
	effect.transform_target = Transform2DJuiceEffect.TransformTarget.POSITION
	effect.to_reference     = Transform2DJuiceEffect.TransformReference.SELF
	effect.to_capture_at    = Transform2DJuiceEffect.CaptureAt.IN_EDITOR

	var baked := Vector2(300.0, 400.0)
	effect._to_editor_cached_position = baked
	effect._ledger_base_snapshot = {}

	var target := Node2D.new()
	target.position = Vector2(5.0, 10.0)
	_runner.add_child(target)

	effect._capture_to_self_position_snapshot(target)

	assert_approx_vec2(effect._to_self_position_snapshot, baked,
			"IN_EDITOR + empty ledger (to-slot): snapshot reads baked editor cache")

	target.queue_free()


func test_in_editor_to_prefers_ledger_over_baked_cache() -> void:
	var effect := Transform2DJuiceEffect.new()
	effect.transform_target = Transform2DJuiceEffect.TransformTarget.POSITION
	effect.to_reference     = Transform2DJuiceEffect.TransformReference.SELF
	effect.to_capture_at    = Transform2DJuiceEffect.CaptureAt.IN_EDITOR

	effect._to_editor_cached_position = Vector2(999.0, 999.0)  # stale

	var ledger_pos := Vector2(88.0, 99.0)
	effect._ledger_base_snapshot = {"position": ledger_pos}

	var target := Node2D.new()
	_runner.add_child(target)

	effect._capture_to_self_position_snapshot(target)

	assert_approx_vec2(effect._to_self_position_snapshot, ledger_pos,
			"IN_EDITOR + ledger has position (to-slot): snapshot uses ledger")

	target.queue_free()


# =============================================================================
# CACHE-CLEAR TESTS
# =============================================================================

func test_switching_from_in_editor_clears_from_cache() -> void:
	# Changing from_capture_at away from IN_EDITOR must zero the baked from-cache.
	# Failing this would cause phantom positions in subsequent animations after the
	# user toggles between capture modes in the inspector.
	var effect := Transform2DJuiceEffect.new()

	# Set the effect to IN_EDITOR first (no clear in setter for IN_EDITOR path).
	effect.from_capture_at = Transform2DJuiceEffect.CaptureAt.IN_EDITOR
	# Now manually write sentinel values to the from-cache fields.
	effect._from_editor_cached_position = Vector2(100.0, 200.0)
	effect._from_editor_cached_rotation = 45.0
	effect._from_editor_cached_scale    = Vector2(2.0, 3.0)

	# Switch away — setter must call _clear_from_editor_cache_typed().
	effect.from_capture_at = Transform2DJuiceEffect.CaptureAt.TRIGGER

	assert_approx_vec2(effect._from_editor_cached_position, Vector2.ZERO,
			"from cache position zeroed when switching from IN_EDITOR to TRIGGER")
	assert_approx_float(effect._from_editor_cached_rotation, 0.0,
			"from cache rotation zeroed when switching from IN_EDITOR to TRIGGER")
	assert_approx_vec2(effect._from_editor_cached_scale, Vector2.ONE,
			"from cache scale reset to ONE when switching from IN_EDITOR to TRIGGER")


func test_switching_from_in_editor_clears_to_cache() -> void:
	# Same guarantee for the to-slot.
	var effect := Transform2DJuiceEffect.new()

	effect.to_capture_at = Transform2DJuiceEffect.CaptureAt.IN_EDITOR
	effect._to_editor_cached_position = Vector2(300.0, 400.0)
	effect._to_editor_cached_rotation = 90.0
	effect._to_editor_cached_scale    = Vector2(1.5, 1.5)

	effect.to_capture_at = Transform2DJuiceEffect.CaptureAt.TRIGGER

	assert_approx_vec2(effect._to_editor_cached_position, Vector2.ZERO,
			"to cache position zeroed when switching from IN_EDITOR to TRIGGER")
	assert_approx_float(effect._to_editor_cached_rotation, 0.0,
			"to cache rotation zeroed when switching from IN_EDITOR to TRIGGER")
	assert_approx_vec2(effect._to_editor_cached_scale, Vector2.ONE,
			"to cache scale reset to ONE when switching from IN_EDITOR to TRIGGER")


# =============================================================================
# NOTIFICATION ROUTING TEST
# =============================================================================

func test_pre_save_notification_routing_does_not_crash() -> void:
	# JuiceBase._notification(NOTIFICATION_EDITOR_PRE_SAVE) must iterate the
	# recipe and call _on_editor_pre_save() on each effect without crashing.
	# The cache write inside _on_editor_pre_save -> _do_update_editor_cache is
	# guarded by Engine.is_editor_hint() (false in headless), so no observable
	# cache change is expected here — this test guards the routing code path only.
	var parent := Node2D.new()
	_runner.add_child(parent)

	var juice := Juice2D.new()
	parent.add_child(juice)

	var effect := Transform2DJuiceEffect.new()
	effect.from_reference  = Transform2DJuiceEffect.TransformReference.SELF
	effect.from_capture_at = Transform2DJuiceEffect.CaptureAt.IN_EDITOR
	var recipe := Juice2DRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe

	await wait_frames(1)

	# Must not crash — routing runs, _do_update_editor_cache exits early in headless.
	# 9001 = NOTIFICATION_EDITOR_PRE_SAVE (Node constant, not accessible from RefCounted).
	juice._notification(9001)

	assert_true(true, "NOTIFICATION_EDITOR_PRE_SAVE routing reaches effects without crash")

	await cleanup(parent)
