# Real-World Test Redesign — Stub Design Doc

> **Status:** STUB — to be designed in a separate session after all effects are ported.
> **Created:** 2026-03-23
> **Trigger:** User feedback that current tests are rudimentary and miss UX issues.

---

## Problem Statement

Current V1 tests verify "does the math produce correct deltas" but NOT "does this work when a user adds it to a real scene." Every test creates a single target at position (0,0) with one effect, programmatically via `.new()`. This misses entire categories of real-world bugs:

### What's Tested Now
- Single effect on single target at (0,0)
- Programmatic `.new()` (bypasses inspector)
- PLAY_IN_AND_OUT lifecycle only (mostly)
- Isolated effects (no stacking)
- No containers, no layout

### What's Missing

| Gap | Why It Matters |
|-----|----------------|
| **Grid of targets at real positions** | Effects at (0,0) hide position-relative bugs (e.g., Custom offsets, viewport-relative units) |
| **Multiple stacked JuiceControl nodes per target** | Two Juice nodes on same Button fight over external-move detection |
| **Effects inside Containers** (VBoxContainer, HBoxContainer) | Container `_sort_children()` resets position every frame — requires hold pattern |
| **Sequencer with stagger across grid** | Tests sequencer timing, order, and per-target cloning |
| **PLAY_IN_ONLY sustained effects** | Noise/Shake/Spring sustain at full intensity until animate_out |
| **TOGGLE trigger behaviour** | Alternating in/out on same target |
| **Inspector dropdown presence** | Effects appear in recipe inspector dropdown (whitelist registration) |
| **Mixed recipes** (Transform + Noise in same recipe) | Procedural + non-procedural effects coexisting |
| **Chained effects across different types** | Transform → Noise chain, testing chain_to with sustain |
| **Retrigger during sustain** | RESTART policy on a sustaining Noise effect |

---

## Proposed Test Architecture

### Test Scene Layout
- **Control domain:** 4x3 grid of Buttons in a GridContainer, each at a unique position
- **2D domain:** Grid of Sprite2D nodes at various positions
- **3D domain:** Grid of MeshInstance3D nodes in 3D space

### Test Categories

1. **Position-relative tests** — targets at non-zero positions, viewport-relative offsets
2. **Stacking tests** — 2+ JuiceControl nodes on same target (one-shot + procedural)
3. **Container tests** — effects on children of VBox/HBox/GridContainer
4. **Sequencer integration** — stagger forward/reverse/random on grid targets
5. **Sustained procedural tests** — Noise/Shake/Spring with PLAY_IN_ONLY, verify continuous animation over time
6. **Mixed recipe tests** — Transform + Noise in same recipe, verify both work
7. **Retrigger-during-sustain tests** — RESTART on sustaining effect, verify clean restart
8. **Toggle lifecycle tests** — TOGGLE on procedural effects, verify sustain between toggles

### Infrastructure Needs
- `create_control_grid(rows, cols)` helper in JuiceTestSuite
- `create_2d_grid(rows, cols)` helper
- `create_3d_grid(rows, cols)` helper
- `assert_changing_over_time(node, property, duration)` — verifies a property keeps changing (for procedural sustain)
- `assert_stable(node, property, value, duration)` — verifies a property stays constant (for frozen Transform)

---

## Decision Log

- **When to implement:** After all effects are ported. Real-world tests will cover ALL effects at once.
- **Scope:** New test suites (not modifications to existing per-effect suites). Existing suites stay as unit tests.
- **Priority:** These are integration/UX tests, run alongside (not replacing) existing unit tests.
