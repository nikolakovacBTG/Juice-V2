## TestIntegrationDemoSequencer.gd
## ============================================================================
## WHAT: Integration tests that replicate the real Main_Demo_Scene setup:
##       VBoxContainer with Button children, a stagger sequencer applying a
##       TRIGGER-mode SELF snapshot recipe, and per-button hover JuiceControls.
## WHY:  Unit tests use simplified programmatic rigs that don't catch real-world
##       composability bugs. These tests guard against the specific failures
##       found during development:
##         1. TRIGGER vs IN_EDITOR capture — buttons stacking at (0,0)
##         2. Dirty FROM snapshot during seq — hover jumps at trigger moment
##         3. _seq_stop() write-through — buttons stuck at displaced position
##       The hover JuiceControls are triggered via emit_signal("mouse_entered")
##       to simulate real mouse input, matching the actual production signal path.
## SYSTEM: Tests (tests/suites/)
## DOES NOT: Test 2D/3D domains, or scenarios requiring actual rendering/physics.
## ============================================================================
extends "res://tests/JuiceTestSuite.gd"


func get_suite_name() -> String:
	return "integration_demo_sequencer"


func get_test_methods() -> Array[String]:
	return [
		"test_sequencer_slides_each_button_to_own_position",
		"test_hover_from_clean_ledger_during_sequencer",
		"test_hover_after_seq_complete_natural_return",
		"test_sequencer_stop_restores_button_positions",
	]


# =============================================================================
# RIG BUILDERS
# =============================================================================

## Build a VBoxContainer with 3 Buttons (like the Main_Demo_Scene Menu).
## Returns [vbox, [btn0, btn1, btn2]].
## All buttons have a fixed minimum size so the VBox assigns distinct Y positions.
func _create_demo_rig() -> Array:
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 0)
	_runner.add_child(vbox)

	var buttons: Array[Button] = []
	for i in 3:
		var btn := Button.new()
		btn.text = "Demo Btn %d" % i
		btn.custom_minimum_size = Vector2(200.0, 40.0)
		vbox.add_child(btn)
		buttons.append(btn)

	return [vbox, buttons]


## Build a sequencer JuiceControl targeting sibling Buttons in the VBoxContainer.
## Recipe: TransformControl — FROM CUSTOM(-150px, 0) → TO SELF (TRIGGER capture).
## TRIGGER capture is the correct mode: each button clone captures its OWN
## Container position at warmup time via the injected ledger base.
func _create_demo_sequencer(vbox: VBoxContainer, stagger: float = 0.1) -> JuiceControl:
	# Effect: slide in from -150px left → natural Container position
	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	# FROM: a fixed offset to the left of natural position
	effect.from_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.from_position = Vector2(-150.0, 0.0)
	effect.from_position_in = JuiceControlTransformEffect.PositionIn.PIXELS
	# TO: SELF — each button clone captures its own ledger base position at warmup.
	# to_capture_at defaults to TRIGGER (0): dynamic capture, NOT IN_EDITOR (2).
	# IN_EDITOR would bake a single shared position (0,0) into the recipe resource,
	# making all buttons animate to (0,0) = top of VBox instead of their own slot.
	effect.to_reference = TransformControlJuiceEffect.TransformReference.SELF
	effect.duration_in = 0.3
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.PLAY_IN_ONLY

	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)

	# Sequencer: targets siblings (the Buttons in this VBox).
	# seq_skip_juice_nodes=true (default) — skips the sequencer's own siblings
	# that are JuiceBase nodes, targeting only real Buttons.
	var seq := JuiceControl.new()
	seq.mode = JuiceBase.Mode.SEQUENCER
	seq.juice_source = JuiceBase.JuiceSource.RECIPE
	seq.target_scope = JuiceBase.TargetScope.SIBLINGS
	seq.seq_stagger_delay = stagger
	seq.trigger_on = JuiceBase.TriggerEvent.MANUAL
	seq.recipe = recipe
	vbox.add_child(seq)
	return seq


## Attach a hover JuiceControl to a Button.
## Effect: FROM SELF (TRIGGER capture, reads ledger base) → TO CUSTOM (+20px right).
## Triggered via ON_MOUSE_ENTERED; exited via mouse_exited which JuiceBase auto-
## connects using the polarity pattern (is_polarity=true → always plays the exit dir).
func _attach_hover(btn: Button) -> JuiceControl:
	var effect := TransformControlJuiceEffect.new()
	effect.transform_target = TransformControlJuiceEffect.TransformTarget.POSITION
	# FROM: SELF with TRIGGER capture — reads ledger base at animation start.
	# This is the fixed path: it will read the gap-1-injected _ledger_base_snapshot
	# instead of dirty ctrl.position (which would include the sequencer's delta).
	effect.from_reference = TransformControlJuiceEffect.TransformReference.SELF
	# from_capture_at defaults to TRIGGER (0) — no override needed
	# TO: +20px right of natural position (CUSTOM, absolute offset)
	effect.to_reference = TransformControlJuiceEffect.TransformReference.CUSTOM
	effect.to_position = Vector2(20.0, 0.0)
	effect.to_position_in = JuiceControlTransformEffect.PositionIn.PIXELS
	effect.duration_in = 0.3
	effect.duration_out = 0.3
	# TOGGLE: plays IN on mouse_entered, OUT on mouse_exited (via polarity auto-connect).
	# PLAY_IN_AND_OUT would auto-play OUT immediately after IN completes (full cycle),
	# returning delta to 0 without waiting for mouse_exited — wrong for hover.
	effect.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.TOGGLE

	var recipe := JuiceControlRecipe.new()
	recipe.effects.append(effect)

	var juice := JuiceControl.new()
	juice.trigger_on = JuiceBase.TriggerEvent.ON_MOUSE_ENTERED
	# TOGGLE at node-level matches the demo prefab (trigger_behaviour=3).
	# With polarity (is_polarity=true): mouse_entered→IN always, mouse_exited→OUT always.
	juice.trigger_behaviour = JuiceEffectBase.TriggerBehaviour.TOGGLE
	juice.recipe = recipe
	btn.add_child(juice)
	return juice


# =============================================================================
# TEST 1: Each button ends at its own Container Y position (not all at 0,0)
# =============================================================================

## Regression guard for the IN_EDITOR capture bug.
## With to_capture_at=IN_EDITOR the recipe had ONE baked position (0,0) shared
## across all 4 button targets → all buttons animated TO (0,0) = top of VBox.
## With to_capture_at=TRIGGER each button clone dynamically captures its own
## Container position at warmup → each button returns to its own slot. ✓
func test_sequencer_slides_each_button_to_own_position() -> void:
	var rig := _create_demo_rig()
	var vbox: VBoxContainer = rig[0]
	var buttons: Array = rig[1]
	var btn0: Button = buttons[0]
	var btn1: Button = buttons[1]
	var btn2: Button = buttons[2]

	# Let the Container run its layout pass and assign distinct positions
	await wait_frames(5)

	var natural_0 := btn0.position
	var natural_1 := btn1.position
	var natural_2 := btn2.position

	# Sanity check: VBox DID assign distinct Y positions
	assert_true(natural_1.y > natural_0.y,
		"VBox layout: Btn1.y (%.0f) > Btn0.y (%.0f)" % [natural_1.y, natural_0.y])
	assert_true(natural_2.y > natural_1.y,
		"VBox layout: Btn2.y (%.0f) > Btn1.y (%.0f)" % [natural_2.y, natural_1.y])

	# Build sequencer (0.1s stagger) and fire
	var seq := _create_demo_sequencer(vbox, 0.1)
	await wait_frames(2)
	seq.animate_in()

	# Wait for all 3 targets to complete (3 x 0.1s stagger + 0.3s duration + margin)
	await wait_seconds(0.9)

	# KEY: each button ends at its OWN natural Container position
	assert_approx_vec2(btn0.position, natural_0,
		"Btn0 should end at its own VBox slot (y=%.0f)" % natural_0.y, 3.0)
	assert_approx_vec2(btn1.position, natural_1,
		"Btn1 should end at its own VBox slot (y=%.0f)" % natural_1.y, 3.0)
	assert_approx_vec2(btn2.position, natural_2,
		"Btn2 should end at its own VBox slot (y=%.0f)" % natural_2.y, 3.0)

	# Regression check: buttons must NOT all share the same position
	assert_not_approx_vec2(btn1.position, btn0.position,
		"Btn0 and Btn1 must be at DIFFERENT Y positions in VBox", 10.0)
	assert_not_approx_vec2(btn2.position, btn1.position,
		"Btn1 and Btn2 must be at DIFFERENT Y positions in VBox", 10.0)

	await cleanup(vbox)


# =============================================================================
# TEST 2: Hover FROM snapshot reads ledger base — not dirty animated position
# =============================================================================

## Regression guard for the dirty-read snapshot bug.
## Old behavior: hover's _on_animate_start() captured ctrl.position directly.
##   ctrl.position during seq = base + seq_delta (e.g. -75px at 50% progress).
##   FROM snapshot = -75. At hover progress=0: desired=-75, hover_delta=-75.
##   Total: base + seq_delta + hover_delta = 0 + (-75) + (-75) = -150. JUMP!
## New behavior: from_snapshot reads _ledger_base_snapshot["position"] = 0 (natural).
##   FROM snapshot = 0. At hover progress=0: desired=0, hover_delta=0. No jump. ✓
func test_hover_from_clean_ledger_during_sequencer() -> void:
	var rig := _create_demo_rig()
	var vbox: VBoxContainer = rig[0]
	var buttons: Array = rig[1]
	var btn0: Button = buttons[0]

	await wait_frames(5)

	# Attach hover to btn0 and add sequencer (0 stagger: btn0 starts immediately)
	var _hover := _attach_hover(btn0)
	var seq := _create_demo_sequencer(vbox, 0.0)
	await wait_frames(2)

	# Start sequencer — btn0 slides from -150px left → natural (0px)
	seq.animate_in()

	# Wait until btn0 is mid-animation: approx 50% progress (0.15s into 0.3s duration)
	await wait_seconds(0.15)

	# Capture btn0's position just before hover triggers
	var pre_hover_x := btn0.position.x

	# Confirm the sequencer IS displacing btn0 to the left
	assert_true(pre_hover_x < -5.0,
		"During seq: Btn0.x (%.1f) should be displaced left" % pre_hover_x)

	# Trigger hover via the real signal path (same as actual mouse input)
	btn0.emit_signal("mouse_entered")

	# Wait 2 frames for JuiceControl to process the trigger and apply delta
	await wait_frames(2)

	# KEY ASSERTION: btn0 must NOT jump to a worse position at hover start.
	# If FROM reads dirty: hover_delta at t=0 = (pre_hover_x - base) = negative.
	#   Total = 0 + seq_delta + dirty_delta ≈ pre_hover_x + pre_hover_x = 2x jump.
	# If FROM reads ledger base: hover_delta at t=0 = 0. No jump.
	#   Total = 0 + seq_delta + 0 = pre_hover_x (unchanged). ✓
	assert_true(absf(btn0.position.x - pre_hover_x) < 12.0,
		"Hover start: Btn0 must not jump (pre=%.1f, post=%.1f). Dirty-read would give ≈%.1f" % [
			pre_hover_x, btn0.position.x, pre_hover_x * 2.0])

	# Wait for sequencer AND hover to complete
	await wait_seconds(0.7)

	# After seq finishes (delta=0) and hover finishes IN (delta=+20):
	# Btn0 should be at natural (0px) + hover offset (+20px) = 20px
	assert_true(btn0.position.x > 15.0,
		"After completion: Btn0.x (%.1f) should be at natural+20 from hover" % btn0.position.x)

	await cleanup(vbox)


# =============================================================================
# TEST 3: Hover after sequencer complete — no ledger drift
# =============================================================================

## After the sequencer completes, each button rests at its own Container position.
## Hover should drive it +20px right from that natural position.
## After mouse_exited (via polarity auto-connect), it returns to natural exactly.
## Any ledger drift would prevent the return-to-natural and signal a base corruption.
func test_hover_after_seq_complete_natural_return() -> void:
	var rig := _create_demo_rig()
	var vbox: VBoxContainer = rig[0]
	var buttons: Array = rig[1]
	var btn1: Button = buttons[1]  # Middle button — has non-zero Y in VBox

	await wait_frames(5)
	var natural_pos := btn1.position  # Record before any animation

	var _hover := _attach_hover(btn1)
	var seq := _create_demo_sequencer(vbox, 0.0)
	await wait_frames(2)

	# Run sequencer to completion
	seq.animate_in()
	await wait_seconds(0.7)  # Well past 0.3s duration

	# Verify: sequencer returned btn1 to its natural position (no drift)
	assert_approx_vec2(btn1.position, natural_pos,
		"After seq complete: Btn1 should be at natural pos (%.0f, %.0f)" % [natural_pos.x, natural_pos.y], 2.0)

	# Trigger hover in
	btn1.emit_signal("mouse_entered")
	await wait_seconds(0.45)

	# Hover IN complete: btn1 should be +20px right of natural
	assert_approx_vec2(btn1.position, natural_pos + Vector2(20.0, 0.0),
		"After hover IN: Btn1 should be natural+20", 3.0)

	# Release hover — mouse_exited fires the exit animation (polarity auto-connect)
	btn1.emit_signal("mouse_exited")
	await wait_seconds(0.4)

	# Hover OUT complete: btn1 must return to its exact natural Container position.
	# Failure here means the ledger base was drifted during the seq+hover interaction.
	assert_approx_vec2(btn1.position, natural_pos,
		"After hover OUT: Btn1 must return to natural — no ledger drift", 1.5)

	await cleanup(vbox)


# =============================================================================
# TEST 4: _seq_stop() writes-through — buttons physically restored on stop()
# =============================================================================

## Regression guard for the _seq_stop write-through bug.
## Before the fix: _seq_stop() zeroed the sequencer's ledger delta but never
## wrote the restored position back to ctrl.position. With no active _process
## loop after stop(), the button stayed at its last animated value indefinitely.
## After the fix: _ledger_write_to_target() is called per-target in _seq_stop(),
## which writes base + remaining_total → ctrl.position is immediately correct.
func test_sequencer_stop_restores_button_positions() -> void:
	var rig := _create_demo_rig()
	var vbox: VBoxContainer = rig[0]
	var buttons: Array = rig[1]
	var btn0: Button = buttons[0]
	var btn1: Button = buttons[1]

	await wait_frames(5)
	var natural_0 := btn0.position
	var natural_1 := btn1.position

	# No hover attached — isolates the sequencer stop behavior
	var seq := _create_demo_sequencer(vbox, 0.0)
	await wait_frames(2)

	# Start sequencer — all buttons slide from -150px left
	seq.animate_in()
	await wait_seconds(0.15)

	# Confirm buttons are displaced (mid-animation)
	assert_true(btn0.position.x < -5.0,
		"Mid-seq: Btn0 is displaced left (x=%.1f)" % btn0.position.x)
	assert_true(btn1.position.x < -5.0,
		"Mid-seq: Btn1 is displaced left (x=%.1f)" % btn1.position.x)

	# Stop mid-animation — should restore all buttons to their natural positions
	seq.stop()
	await wait_frames(2)

	# KEY ASSERTION: without the write-through fix, CTR.position stays at the
	# last written displaced value (e.g. -75px) after ledger delta is zeroed.
	assert_approx_vec2(btn0.position, natural_0,
		"After stop: Btn0 must be at natural (%.0f, %.0f)" % [natural_0.x, natural_0.y], 2.0)
	assert_approx_vec2(btn1.position, natural_1,
		"After stop: Btn1 must be at natural (%.0f, %.0f)" % [natural_1.x, natural_1.y], 2.0)

	await cleanup(vbox)
