---
description: "One-time: Build the single JuiceOrchestrator class and factory"
---

You are in ORCHESTRATOR BUILD MODE.

This is a **one-time build workflow** for Juice V2 Phase 4. It creates the single `JuiceOrchestrator` class with mode enum and the `JuiceOrchestratorFactory`.

**Phase 4 uses a DELEGATING pattern** — orchestrator wraps JuiceBase method calls.
JuiceBase still owns the tick loop. Effect cloning and ledger registration move to the orchestrator in Phase 5.

**Skills auto-invoked:** `@juice-architecture`, `@verify-claims`

---

## Phase 4A — Build Classes (no tests yet)

### 1. Create JuiceOrchestrator
- [ ] Create `addons/Juice_V2/Editor/JuiceOrchestrator.gd` (`@tool extends Object`)
- [ ] Mode enum: `PREVIEW`, `RUNTIME`
- [ ] `setup(node: JuiceBase, recipe: JuiceRecipe, target: Node, mode: Mode)` → store references only
- [ ] `play_in()` → delegates: `_node.animate_in()`
- [ ] `play_out()` → delegates: `_node.animate_out()`
- [ ] `reset()` → RUNTIME only: `_node.stop()` then `_node.animate_in()` — same object, zero allocation
- [ ] `stop()` → RUNTIME: `_node.stop()` (stays alive) | PREVIEW: `_node.stop()`
- [ ] `teardown()` → both modes: `_node.stop()` then `free()` on self

### 2. Create Factory
- [ ] Create `addons/Juice_V2/Editor/JuiceOrchestratorFactory.gd`
- [ ] `static func create(node: JuiceBase, mode: JuiceOrchestrator.Mode) -> JuiceOrchestrator`
- [ ] Verify both files parse without errors (check via `get_godot_errors`)

---

## Phase 4B — Wire Director + Tests

### 3. Wire PreviewDirector
- [ ] Add `_orchestrators: Dictionary` (JuiceBase → JuiceOrchestrator) to PreviewDirector
- [ ] `_add_preview_node()` → spawn orchestrator via factory, store in `_orchestrators`
- [ ] `play()`, `play_in()`, `play_out()` → delegate to orchestrator
- [ ] `stop()`, `deselect()` → call `orchestrator.teardown()`
- [ ] Run transport suite before and after wiring (must stay 30/30)

### 4. Test (only after wiring — write tests against working system)
- [ ] Headless TestOrchestrator: PREVIEW lifecycle, RUNTIME retrigger, teardown
- [ ] Headless TestOrchestratorFactory: create() PREVIEW, create() RUNTIME
- [ ] MCP G1 — Basic play, MCP G2 — Deselect teardown
- [ ] Run full suite — no new failures beyond pre-existing noise_3d flake

**Gate**: Transport 30/30. TestOrchestrator ≥6 tests. TestOrchestratorFactory ≥3 tests. G1+G2 pass.
