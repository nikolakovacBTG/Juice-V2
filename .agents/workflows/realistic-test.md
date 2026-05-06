---
description: Comprehensive UX and Integration testing for Juice effects simulating real-world scenarios.
---

You are in REALISTIC TEST MODE.

This workflow is used to validate effects after they have been ported or developed. It goes beyond unit tests to verify how effects behave in complex, real-world scenes.

**Parent workflow:** `/port` or `/architecture`

---

## 1. Two Testing Tiers

Juice realistic tests operate on **two tiers**. Both are required. Neither replaces the other.

| Tier | Runner | What it reaches | When to use |
|------|--------|-----------------|-------------|
| **Headless** | `run_tests.tscn` via `--headless` | Runtime logic, ledger math, accumulation, bounds, stacking, lifecycle | Always — fast CI regression |
| **MCP Editor** | `mcp_godot-mcp_execute_editor_script` in live Godot editor | `@tool` paths, `_enter_editor_preview`, `_temporarily_undo_visual`, `NOTIFICATION_EDITOR_PRE_SAVE`, transport lifecycle | Required for any feature that fires in `Engine.is_editor_hint()` context |

**Never claim editor lifecycle features are tested with headless alone.**
The headless runner never enters `_editor_preview_active` mode, never fires `NOTIFICATION_EDITOR_PRE_SAVE` the same way the editor does, and never exercises the plugin transport path.

---

## 2. Setup Test Infrastructure

Before writing realistic tests, ensure the required helper functions exist in `tests/JuiceTestSuite.gd`:

*   `_create_2d_rig_at(pos, target_type)`: Creates a Juice2D + Node2D at a specific non-zero position.
*   `_create_control_rig_at(pos, target_type)`: Creates a JuiceControl + Button at a specific position.
*   `_create_3d_rig_at(pos, target_type)`: Creates a Juice3D + Node3D at a specific position.
*   `assert_changing_over_time(node, property, duration)`: Verifies a property continuously changes (for procedural effects).
*   `assert_stable(node, property, value, duration)`: Verifies a property remains constant.

---

## 3. Test Scene Layout

Instead of testing a single target at `(0,0)`, realistic tests MUST use:
*   **Control domain:** A grid of Buttons inside a `GridContainer`.
*   **2D domain:** Node2D targets distributed at non-zero positions.
*   **3D domain:** Node3D targets distributed at non-zero 3D positions.

---

## 4. Required Test Scenarios (Headless Tier)

You must implement tests covering the following real-world categories for the target effect(s):

| Scenario | Objective |
| :--- | :--- |
| **Position-relative tests** | Verify effects work correctly when the target is NOT at `(0,0)`. Test custom offsets. |
| **Stacking — deterministic** | Apply a tween-based effect + the effect under test on the same target. Assert combined delta is correct and neither overwrites the other. |
| **Stacking — random** | Apply Shake and Noise effects alongside the effect under test. Assert target returns to correct non-zero origin after stop. |
| **Container tests (Control)** | Apply effects to children of `VBoxContainer`, `HBoxContainer`, or `GridContainer`. Verify Container hold pattern prevents `_sort_children()` from resetting positions. |
| **Sequencer integration** | Test stagger forward, reverse, and random across a grid of targets. Verify timing and per-target cloning. |
| **Sustained procedural** | For Noise/Shake/Progress: Use `PLAY_IN_ONLY` and verify continuous animation over time without decaying. |
| **Toggle lifecycle** | Use the `TOGGLE` trigger on procedural effects. Verify it sustains between toggles and cleans up correctly. |
| **Mixed recipes** | Combine the effect under test with both a deterministic effect and a random effect in the same recipe. Verify all execute without interference. |
| **Chained effects** | Chain the effect under test to a Noise effect (`chain_to`). Test chaining with sustained effects. |
| **Retrigger during sustain** | Trigger a `RESTART` policy on an already-sustaining effect. Verify it restarts cleanly without snapping. |
| **Inspector registration** | Verify the effect is registered in the appropriate `_CONCRETE_EFFECTS` whitelist. Missing = invisible in inspector. |

---

## 5. Required Test Scenarios (MCP Editor Tier)

These tests MUST be written for any effect that touches the editor lifecycle.
Run them using `mcp_godot-mcp_execute_editor_script` against a live open scene.

| Scenario | Objective |
| :--- | :--- |
| **Transport preview — base capture** | Call `_enter_editor_preview()` on a Juice node whose target is at a non-zero position. Sample the target's position at t+1, t+3, and t+5 deferred frames. Assert position never snaps to `(0,0)`. |
| **Transport preview — ledger base accuracy** | After `_deferred_editor_preview_init` fires, read the ledger base via `JuiceLedger.get_base(target, "position", Vector2.ZERO)`. Assert it matches the actual `target.position`. |
| **Editor save lifecycle** | With the transport active and the node mid-preview, simulate Ctrl+S by calling `_apply_changes()` on the plugin. Assert the target's position is restored to the natural value, not `(0,0)`. |
| **Deselect restore** | Call `_exit_editor_preview()`. Assert target position is restored. |
| **Special node types** | Repeat the above for `TileMapLayer`, `SubViewport`, or other Godot-internal `@tool` nodes that use deferred position initialization. |

### MCP Editor Test Pattern

```gdscript
# Example execute_editor_script structure for transport preview tests:
func run():
    var scene_root = EditorInterface.get_edited_scene_root()
    var tile_layer = scene_root.find_child("Platform 2", true, false)
    var juice_node = null
    for child in tile_layer.get_children():
        if child is Juice2D:
            juice_node = child
            break

    var pos_before = tile_layer.position
    juice_node._enter_editor_preview()

    # Sample across multiple frames to catch deferred race conditions
    var results = {"before": pos_before, "f1": null, "f3": null, "f5": null}
    # (Use nested call_deferred or OS.delay_msec pattern per frame)
    return results
```

---

## 6. Execution & Validation

### Headless tier
1.  Write tests in `tests/suites/TestRealWorld[Category].gd`.
2.  Register the suite in `JuiceTestRunner.gd`.
3.  Run: `& "[GODOT_EXE]" --headless --path "[PROJECT_ROOT]" res://tests/run_tests.tscn`
4.  If tests fail, diagnose effect vs. test setup bug, fix, re-run.

### MCP Editor tier
1.  Write the diagnostic GDScript as a `func run():` block.
2.  Execute via `mcp_godot-mcp_execute_editor_script`.
3.  Assert the returned values meet expectations.
4.  These tests are NOT registered in `JuiceTestRunner.gd` — they are MCP tool calls documented in the test file header.

---

## 7. Report

Provide a summary covering:
- Headless suite results (pass/fail count)
- MCP editor test results (position values before/after across sampled frames)
- Any edge cases discovered
