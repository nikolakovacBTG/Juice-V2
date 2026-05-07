---
description: "One-time: Build the single JuiceOrchestrator class and factory"
---

You are in ORCHESTRATOR BUILD MODE.

This is a **one-time build workflow** for Juice V2 Phase 4. It creates the single `JuiceOrchestrator` class with mode enum and the `JuiceOrchestratorFactory`.

**Skills auto-invoked:** `@juice-architecture`, `@unit-test-patterns`, `@verify-claims`

---

## Checklist

### 1. Create Orchestrator
- [ ] Create `addons/Juice_V2/Base Classes/JuiceOrchestrator.gd` (`@tool`)
- [ ] Mode enum: `PREVIEW`, `RUNTIME`
- [ ] `setup(recipe, target, mode)` → clone effects, resolve target, register ledger
- [ ] `play()` → begin `_process` loop
- [ ] `reset()` → clear effect state, restart (RUNTIME retrigger — zero allocation)
- [ ] `stop()` → stop animation, restore target
- [ ] `teardown()` → restore, deregister ledger, `queue_free()` (PREVIEW only)

### 2. Create Factory
- [ ] Create `addons/Juice_V2/Base Classes/JuiceOrchestratorFactory.gd`
- [ ] `static func create(recipe, target, mode) -> JuiceOrchestrator`

### 3. Wire Preview Director
- [ ] Update `JuicePreviewDirector.gd` to use factory for PREVIEW mode

### 4. Test
- [ ] PREVIEW lifecycle: spawn → play → teardown → freed
- [ ] RUNTIME lifecycle: spawn → play → complete → idle → retrigger → no new allocation
- [ ] Ledger cleanup: `JuiceLedger.has_ledger(target)` returns `false` after both modes
- [ ] Retrigger allocation: child count unchanged after `reset()`
- [ ] Run full test suite

**Gate**: Single orchestrator handles both modes. Zero per-trigger allocation in RUNTIME.
