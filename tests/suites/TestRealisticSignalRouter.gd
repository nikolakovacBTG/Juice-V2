## TestRealisticSignalRouter.gd
## ============================================================================
## WHAT: Realistic integration tests for JuiceSignalRouter and SignalEmit
##       utilities in the Control domain.
## WHY:  Verifies the full developer workflow: adding a SignalEmit utility to a
##       recipe, triggering animation, and observing that user-defined signals
##       fire on the correct nodes with the correct payloads. Covers both
##       host-node emission and owner-bubbling for the prefab-as-black-box
##       pattern. Also validates the Phase A color interpolation fix.
## SYSTEM: Tests (tests/suites/)
## DOES NOT: Test 2D/3D domains — this suite focuses on Control domain only.
##           Does not test editor preview or transport lifecycle.
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "realistic_signal_router"


func get_test_methods() -> Array[String]:
	return [
		"test_signal_registered_on_host_node",
		"test_signal_fires_with_payload_on_host",
		"test_signal_bubbles_to_owner",
		"test_signal_no_bubble_when_disabled",
		"test_empty_signal_name_still_emits_resource_signal",
		"test_cross_node_color_interpolation",
	]


# =============================================================================
# HELPERS
# =============================================================================

# Creates a standard SignalEmit rig: Button → JuiceControl → recipe with a
# single SignalEmitControlJuiceUtility containing one entry.
# Returns [JuiceControl, Button, SignalEmitControlJuiceUtility, SignalEmitEntry].
func _create_signal_rig(
		signal_name: String = "on_hit",
		emit_on: int = SignalEmitJuiceUtilityBase.EmitTiming.ON_START,
		payload: Variant = "test",
		emit_to_owner: bool = true
) -> Array:
	var target := create_control_target("SignalBtn")

	var entry := SignalEmitEntry.new()
	entry.emit_on = emit_on
	entry.payload = payload
	entry.signal_name = signal_name

	var effect := SignalEmitControlJuiceUtility.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_in = 0.1
	effect.duration_out = 0.1
	effect.entries = [entry]
	effect.emit_to_owner = emit_to_owner

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	return [juice, target, effect, entry]


# =============================================================================
# TEST 1: Signal registered on host node
# =============================================================================

## Developer adds a SignalEmit utility with signal_name='on_hit'.
## After animate_in(), the JuiceControl host node should have the user signal
## registered (has_user_signal('on_hit') == true).
func test_signal_registered_on_host_node() -> void:
	var rig := await _create_signal_rig("on_hit")
	var juice: JuiceControl = rig[0]
	var target: Button = rig[1]

	# After _ready() + deferred frame: signal must ALREADY be registered thanks
	# to _register_early_signals() called during JuiceBase._ready(), BEFORE
	# JuiceTriggerRouter.wire_manual(). This is the Phase B fix verification.
	assert_true(juice.has_user_signal("on_hit"),
		"Pre-animate: JuiceControl must have 'on_hit' registered during _ready() (early registration)")

	juice.animate_in()
	await wait_frames(3)

	# After animation starts: signal still registered (idempotent safety net).
	assert_true(juice.has_user_signal("on_hit"),
		"Post-animate: JuiceControl must still have 'on_hit' user signal registered")

	await cleanup(target)


# =============================================================================
# TEST 2: Signal fires with payload on host
# =============================================================================

## Developer connects to the host node's 'on_hit' signal.
## After animate_in(), the connected callback receives the configured payload.
func test_signal_fires_with_payload_on_host() -> void:
	var rig := await _create_signal_rig("on_hit",
			SignalEmitJuiceUtilityBase.EmitTiming.ON_START, "hit_data")
	var juice: JuiceControl = rig[0]
	var target: Button = rig[1]

	# Pre-register the signal manually so we can connect before animation.
	# In real scenes, the designer connects in the editor's Signal dialog;
	# here we simulate by registering + connecting before animate_in().
	JuiceSignalRouter.register_signal(juice, "on_hit")

	var received_payloads: Array = []
	juice.connect("on_hit", func(payload: Variant) -> void:
		received_payloads.append(payload)
	)

	juice.animate_in()
	await wait_frames(5)

	assert_true(received_payloads.size() > 0,
		"Host signal must fire at least once (received %d emissions)" % received_payloads.size())
	if received_payloads.size() > 0:
		assert_equal(received_payloads[0], "hit_data",
			"Payload must match configured value 'hit_data'")

	await cleanup(target)


# =============================================================================
# TEST 3: Signal bubbles to owner
# =============================================================================

## Developer creates a sub-scene pattern: a root Node with a child Button that
## has JuiceControl. With emit_to_owner=true, the signal should fire on BOTH
## the JuiceControl (host) AND the root/owner node.
func test_signal_bubbles_to_owner() -> void:
	# Build hierarchy: scene_root → target(Button) → juice(JuiceControl)
	var scene_root := Node.new()
	_runner.add_child(scene_root)

	var target := Button.new()
	target.text = "BubbleBtn"
	target.custom_minimum_size = Vector2(120, 40)
	scene_root.add_child(target)
	target.owner = scene_root  # Simulate packed scene ownership

	var entry := SignalEmitEntry.new()
	entry.emit_on = SignalEmitJuiceUtilityBase.EmitTiming.ON_START
	entry.payload = "bubble_test"
	entry.signal_name = "on_hit"

	var effect := SignalEmitControlJuiceUtility.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_in = 0.1
	effect.duration_out = 0.1
	effect.entries = [entry]
	effect.emit_to_owner = true

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	juice.owner = scene_root  # JuiceSignalRouter reads _host_node.owner

	await wait_frames(2)

	# Pre-register signals on both nodes so we can connect before animation.
	JuiceSignalRouter.register_signal(juice, "on_hit")
	JuiceSignalRouter.register_signal(scene_root, "on_hit")

	var host_received: Array = []
	var owner_received: Array = []

	juice.connect("on_hit", func(payload: Variant) -> void:
		host_received.append(payload)
	)
	scene_root.connect("on_hit", func(payload: Variant) -> void:
		owner_received.append(payload)
	)

	juice.animate_in()
	await wait_frames(5)

	assert_true(host_received.size() > 0,
		"Bubble: host (JuiceControl) must receive signal (got %d)" % host_received.size())
	assert_true(owner_received.size() > 0,
		"Bubble: owner (scene_root) must receive bubbled signal (got %d)" % owner_received.size())

	if owner_received.size() > 0:
		assert_equal(owner_received[0], "bubble_test",
			"Bubble: owner payload must match 'bubble_test'")

	await cleanup(scene_root)


# =============================================================================
# TEST 4: Signal does NOT bubble when disabled
# =============================================================================

## Same owner setup but emit_to_owner=false.
## Signal fires only on host, NOT on owner.
func test_signal_no_bubble_when_disabled() -> void:
	# Build hierarchy: scene_root → target(Button) → juice(JuiceControl)
	var scene_root := Node.new()
	_runner.add_child(scene_root)

	var target := Button.new()
	target.text = "NoBubbleBtn"
	target.custom_minimum_size = Vector2(120, 40)
	scene_root.add_child(target)
	target.owner = scene_root

	var entry := SignalEmitEntry.new()
	entry.emit_on = SignalEmitJuiceUtilityBase.EmitTiming.ON_START
	entry.payload = "no_bubble"
	entry.signal_name = "on_hit"

	var effect := SignalEmitControlJuiceUtility.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_AND_OUT
	effect.duration_in = 0.1
	effect.duration_out = 0.1
	effect.entries = [entry]
	effect.emit_to_owner = false  # Disabled!

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	juice.owner = scene_root

	await wait_frames(2)

	# Pre-register on both nodes.
	JuiceSignalRouter.register_signal(juice, "on_hit")
	JuiceSignalRouter.register_signal(scene_root, "on_hit")

	var host_received: Array = []
	var owner_received: Array = []

	juice.connect("on_hit", func(payload: Variant) -> void:
		host_received.append(payload)
	)
	scene_root.connect("on_hit", func(payload: Variant) -> void:
		owner_received.append(payload)
	)

	juice.animate_in()
	await wait_frames(5)

	assert_true(host_received.size() > 0,
		"No-bubble: host must still receive signal (got %d)" % host_received.size())
	assert_equal(owner_received.size(), 0,
		"No-bubble: owner must NOT receive signal when emit_to_owner=false (got %d)" % owner_received.size())

	await cleanup(scene_root)


# =============================================================================
# TEST 5: Empty signal_name still emits Resource-level juice_signal
# =============================================================================

## Entry with empty signal_name. Resource-level juice_signal should still fire.
## No Node-level signal should be registered.
func test_empty_signal_name_still_emits_resource_signal() -> void:
	var rig := await _create_signal_rig("",
			SignalEmitJuiceUtilityBase.EmitTiming.ON_START, "fallback_data")
	var juice: JuiceControl = rig[0]
	var target: Button = rig[1]

	# Connect to the RUNTIME effect's juice_signal — JuiceBase clones recipe
	# effects at startup, so the template effect in the recipe never fires.
	var runtime_effect: SignalEmitJuiceUtilityBase = juice._runtime_effects[0]
	var resource_received: Array = []
	runtime_effect.juice_signal.connect(func(payload: Variant) -> void:
		resource_received.append(payload)
	)

	juice.animate_in()
	await wait_frames(5)

	# Resource-level signal must fire even without a signal_name.
	assert_true(resource_received.size() > 0,
		"Empty name: Resource juice_signal must fire (got %d)" % resource_received.size())
	if resource_received.size() > 0:
		assert_equal(resource_received[0], "fallback_data",
			"Empty name: juice_signal payload must be 'fallback_data'")

	# No user signal should be registered on the host for an empty name.
	assert_false(juice.has_user_signal(""),
		"Empty name: no user signal registered with empty string")

	await cleanup(target)


# =============================================================================
# TEST 6: Cross-node color interpolation (Phase A fix)
# =============================================================================

## Developer uses PropertyInterpolateControlJuiceEffect to animate modulate
## from WHITE to RED. At progress=1.0, the modulate should be RED.
## This validates the color interpolation path through the Ledger.
func test_cross_node_color_interpolation() -> void:
	var target := create_control_target("ColorBtn")

	# Target starts at WHITE (default modulate).
	assert_equal(target.modulate, Color.WHITE,
		"Pre-animate: modulate must start at WHITE")

	# Configure an InterpolatePropertyTarget for modulate: WHITE → RED.
	var prop_target := InterpolatePropertyTarget.new()
	prop_target.property_path = "modulate"
	prop_target._detected_type = TYPE_COLOR
	prop_target.from_reference = InterpolatePropertyTarget.ReferenceSource.CUSTOM
	prop_target.from_color = Color.WHITE
	prop_target.to_reference = InterpolatePropertyTarget.ReferenceSource.CUSTOM
	prop_target.to_color = Color.RED

	var effect := PropertyInterpolateControlJuiceEffect.new()
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY
	effect.duration_in = 0.15
	effect.property_targets = [prop_target]

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)
	juice.recipe = recipe
	target.add_child(juice)
	await wait_frames(2)

	juice.animate_in()
	# Wait long enough for the 0.15s animation to complete fully.
	await wait_seconds(0.4)

	# At progress=1.0 the color should have interpolated to RED.
	# Color.RED = (1, 0, 0, 1). Allow some tolerance for float rounding.
	assert_approx_float(target.modulate.r, 1.0,
		"Color interp: red channel must be ~1.0 at completion", 0.05)
	assert_approx_float(target.modulate.g, 0.0,
		"Color interp: green channel must be ~0.0 at completion", 0.05)
	assert_approx_float(target.modulate.b, 0.0,
		"Color interp: blue channel must be ~0.0 at completion", 0.05)
	assert_approx_float(target.modulate.a, 1.0,
		"Color interp: alpha channel must be ~1.0 at completion", 0.05)

	await cleanup(target)
