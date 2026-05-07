---
description: Comprehensive UX and Integration testing for Juice V2 effects simulating real-world scenarios.
---

You are in REALISTIC TEST MODE.

This workflow validates effects after porting or development. It goes beyond unit tests to verify how effects behave in complex, real-world scenes — including both headless runtime logic and live editor behavior.

**Parent workflow:** `/port` or `/architecture`

**Skills auto-invoked:** `@realistic-test-design` — use the scenario libraries and quality check before writing any tests.

---

## Authorization Gate (MANDATORY)

**This workflow STOPS at bug detection.** When a test fails:
1. Record the failure precisely: test name, expected value, actual value, reproduction steps
2. Report it in the summary
3. **STOP. Do NOT fix it.** Switch to `/bugfix` workflow for fixes.

You may edit **test files only** to fix test setup bugs (wrong assertion, wrong rig) — NOT production code bugs.
Any production code change requires explicit user authorization and switching to `/bugfix`.



## 1. Two Testing Tiers

Both tiers are required. Neither replaces the other.

| Tier | Runner | What it reaches | When to use |
|------|--------|-----------------|-------------|
| **Tier 1 — Headless** | `run_tests.tscn` via `--headless` | Runtime logic, ledger math, accumulation, stacking, lifecycle, orchestrator RUNTIME mode | Always — fast CI regression |
| **Tier 2 — MCP Editor** | `mcp_godot-mcp_execute_editor_script` in live editor | Orchestrator PREVIEW mode, inspector plugin property visibility, config warnings, editor save lifecycle | Required for any feature with editor-side behavior |

**Never claim editor lifecycle features are tested with Tier 1 alone.**
The headless runner never enters PREVIEW mode, never fires `NOTIFICATION_EDITOR_PRE_SAVE` as the editor does, and never exercises the inspector plugin path.

---

## 2. Test Infrastructure Requirements

Before writing realistic tests, verify these helpers exist in `tests/JuiceTestSuite.gd`:

- `_create_2d_rig_at(pos, target_type)` — Juice2D + Node2D at non-zero position
- `_create_control_rig_at(pos, target_type)` — JuiceControl + Button at position
- `_create_3d_rig_at(pos, target_type)` — Juice3D + Node3D at position
- `assert_changing_over_time(node, property, duration)` — verifies continuous change
- `assert_stable(node, property, value, duration)` — verifies property stays constant

---

## 3. Test Scene Layout

Realistic tests MUST NOT use targets at `(0,0)`. Use:
- **Control:** grid of Buttons inside a `GridContainer`
- **2D:** Node2D targets distributed at non-zero positions
- **3D:** Node3D targets at non-zero 3D positions

---

## 4. Required Scenarios — Tier 1 (Headless)

**Use `@realistic-test-design` → `REFERENCES/tier1-scenarios.md` for the full scenario library.**

Scenarios are organized into user-behaviour families:

| Family | User Action | Key Coverage |
|--------|------------|-------------|
| **A — First-time setup** | Add Juice node, assign recipe, call animate | Graceful failure, empty recipe, non-zero origin |
| **B — Effect stacking** | Add multiple effects to one recipe, one target | Delta accumulation, two Juice nodes same target, mid-animation stop |
| **B2 — Concurrent multi-source** | Two Juice nodes, same target, triggered at different times | Full/partial overlap, one stops early, different effect types, retrigger while other active |
| **C — UI containers** | JuiceControl in VBox/Grid, animate | Container hold, stagger across 3×3 grid, resize mid-animation |
| **D — Sequencer** | Sequencer across N targets, all stagger modes | Order correctness, retrigger mid-sequence |
| **E — Triggers & chains** | Chain effects, toggle procedural, signal trigger | Chain timing, toggle state, signal wiring |
| **K — Runtime robustness** | Spawn/free Juice at runtime, delete target mid-animation | No crash, ledger cleans up, PackedScene instances independent |

**Minimum required:** at least one scenario from families A, B, and the relevant domain family (C for Control, D/E for others).

---

## 5. Required Scenarios — Tier 2 (MCP Editor)

**Use `@realistic-test-design` → `REFERENCES/tier2-scenarios.md` for the full scenario library.**

Scenarios simulate real developer actions inside the editor:

| Family | User Action | Key Coverage |
|--------|------------|-------------|
| **F — Inspector configuration** | Add Juice node, assign recipe, add/configure effects | Config warnings, effect row visibility, value serialization |
| **G — Transport preview** | Press Play/Stop in transport, deferred-init nodes | Base capture accuracy, restore to natural, no `(0,0)` snap |
| **H — Save lifecycle** | Ctrl+S while transport idle or active | .tscn has natural position, no animation artifacts on reopen |
| **I — Multi-node scenes** | Select between Juice nodes, two nodes same target | Inspector updates correctly, stacking works in editor |
| **J — Concurrent preview stacking** | Preview two Juice nodes on same target, stop one | Sum of deltas, partial stop correct, save while both active |
| **L — Editor robustness** | Ctrl+Z, Ctrl+D, copy-paste, move asset file | Undo reverts correctly, duplicates get independent resources |

**Minimum required:** at least F (config warnings) and G (transport preview) for any effect with editor-side behavior.

### MCP Editor Test Pattern

```gdscript
func run():
    var scene_root = EditorInterface.get_edited_scene_root()
    var target = scene_root.find_child("TargetNode", true, false)
    var juice_node: Juice2D = null
    for child in target.get_children():
        if child is Juice2D:
            juice_node = child
            break

    var pos_before = target.position
    # Trigger PREVIEW orchestrator via PreviewDirector API
    JuicePreviewDirector.preview(juice_node)

    # Sample across deferred frames to catch race conditions
    return {
        "before": pos_before,
        "ledger_base": JuiceLedger.get_base(target, "position", Vector2.ZERO)
    }
```

---

## 6. Execution & Validation

### Tier 1 — Headless
1. Write tests in `tests/suites/TestRealWorld[Category].gd`
2. Register suite in `JuiceTestRunner.gd`
3. Run: `& "[GODOT_EXE]" --headless --path "[PROJECT_ROOT]" res://tests/run_tests.tscn`
4. Diagnose effect vs. test setup bug on failure, fix, re-run

### Tier 2 — MCP Editor
1. Write diagnostic GDScript as a `func run():` block
2. Execute via `mcp_godot-mcp_execute_editor_script`
3. Assert returned values meet expectations
4. These tests are NOT registered in `JuiceTestRunner.gd` — document them in the test file header

---

## 7. Report

Provide a summary covering:
- Tier 1: headless suite results (pass/fail count per suite)
- Tier 2: MCP editor test results (key values before/after, sampled frames)
- Any edge cases discovered
