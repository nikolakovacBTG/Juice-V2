---
description: Comprehensive UX and Integration testing for Juice effects simulating real-world scenarios.
---

You are in REALISTIC TEST MODE.

This workflow is used to validate effects after they have been ported or developed. It goes beyond unit tests to verify how effects behave in complex, real-world scenes.

**Parent workflow:** `/port` or `/architecture`

---

## 1. Setup Test Infrastructure

Before writing realistic tests, ensure the required helper functions exist in `tests/JuiceTestRunner.gd` or `JuiceTestSuite`:

*   `create_control_grid(rows, cols)`: Creates a grid of Control nodes at unique positions.
*   `create_2d_grid(rows, cols)`: Creates a grid of Sprite2D nodes.
*   `create_3d_grid(rows, cols)`: Creates a grid of MeshInstance3D nodes.
*   `assert_changing_over_time(node, property, duration)`: Verifies a property continuously changes (for procedural effects).
*   `assert_stable(node, property, value, duration)`: Verifies a property remains constant.

## 2. Test Scene Layout

Instead of testing a single target at `(0,0)`, realistic tests MUST use:
*   **Control domain:** A grid of Buttons inside a `GridContainer`.
*   **2D domain:** A grid of `Sprite2D` nodes distributed in space.
*   **3D domain:** A grid of `MeshInstance3D` nodes distributed in 3D space.

## 3. Required Test Scenarios

You must implement tests covering the following real-world categories for the target effect(s):

| Scenario | Objective |
| :--- | :--- |
| **Position-relative tests** | Verify effects work correctly when the target is NOT at `(0,0)`. Test custom offsets and viewport-relative units. |
| **Stacking tests** | Apply 2+ Juice nodes to the same target (e.g., one-shot + procedural). Verify they don't fight over external-move detection. |
| **Container tests (Control)** | Apply effects to children of `VBoxContainer`, `HBoxContainer`, or `GridContainer`. Verify the Container hold pattern prevents `_sort_children()` from resetting positions. |
| **Sequencer integration** | Test stagger forward, reverse, and random across a grid of targets. Verify timing and per-target cloning. |
| **Sustained procedural** | For Noise/Shake/Spring: Use `PLAY_IN_ONLY` and verify continuous animation over time without decaying. |
| **Toggle lifecycle** | Use the `TOGGLE` trigger on procedural effects. Verify it sustains between toggles and cleans up correctly. |
| **Mixed recipes** | Combine a Transform effect and a Noise effect in the same recipe. Verify both execute without interference. |
| **Chained effects** | Chain a Transform effect to a Noise effect (`chain_to`). Test chaining with sustained effects. |
| **Retrigger during sustain** | Trigger a `RESTART` policy on an already-sustaining effect. Verify it restarts cleanly. |
| **Inspector presence** | Verify the effect is registered in the appropriate `_CONCRETE_EFFECTS` whitelist and appears in the inspector dropdown. |

## 4. Execution & Validation

1.  Write the tests in a new suite (e.g., `tests/suites/TestRealWorld[Category].gd`).
2.  Register the suite.
3.  Run the tests using MCP0 or the
    ```powershell
    & "[TEST_BAT]"
    ```
4.  If tests fail, diagnose whether it's a bug in the effect or the test setup, fix it, and re-run.

## 5. Report

Provide a summary of the realistic testing outcomes to the user, highlighting which scenarios passed and any edge cases discovered.
