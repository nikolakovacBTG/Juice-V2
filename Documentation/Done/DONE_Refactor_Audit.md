# Juice V1 — Phase 0 Refactor Audit
**Branch:** `refactor/lean-out`  
**Date:** 2026-04-15  
**Test baseline:** 370 passed, 0 failed  
**Scope:** `addons/Juice_V1/` only

---

## 1. JuiceBase.gd — Responsibility Map

2,267 lines across 14 logical sections identified by banner comments:

| Section | Lines | Phase Target | Notes |
|---------|-------|-------------|-------|
| Header / Enums / Signals | ~80 | Stays | Shared vocabulary, keep |
| Configuration (`@export` groups) | ~139 | Phase 2 | Thin out after sequencer extracted |
| Conditional Export System | ~64 | Phase 2 | Follows config |
| Internal State | ~82 | Phase 2 | Split between modes |
| **Lifecycle** (`_notification`, `_ready`, `_process`) | **237** | Phase 2 | Core orchestration, keep lean |
| Public API (`animate_in`, `stop`, etc.) | ~84 | Phase 2 | Stays, delegates to kernel |
| Trigger Handling | ~106 | Phase 2 | → `JuiceTriggerRouter` |
| Core Logic (`_start_effects`) | ~164 | Phase 2 | Stays, calls kernel |
| **Sequencer Logic** | **525** | Phase 2 | → `JuiceSequencerKernel` |
| Domain Virtual Hooks | ~124 | Stays | Contract stubs, must remain |
| Configuration Warnings | ~59 | Stays | Light editor tooling |
| Helpers | ~115 | Phase 2 | Split by destination |
| **Auto-Connect + Signal Callbacks** | **430** | Phase 2 | → `JuiceTriggerRouter` |
| **Ledger Statics** | **~170** | Phase 1 | → `JuiceLedger` |

**Largest extraction targets:** Sequencer (525), Signal Callbacks (430), Ledger (170).  
After Phase 1 + Phase 2, estimated JuiceBase residual: **~600 lines.**

---

## 2. Write Path Audit — Two Systems Coexist

The codebase currently has **two parallel write systems** that run simultaneously.

### System A: Old Direct-Write (bypasses ledger)

```
effect.tick() → updates internal _pos_delta
             ↓
domain._post_tick_write() → iterates effects, sums deltas locally
             ↓
target.property = local_base + local_sum   ← DIRECT WRITE, no ledger awareness
```

**Active call sites:**

| File | Lines | Properties | Status |
|------|-------|-----------|--------|
| `JuiceControl.gd` | 266–268 | `ctrl.position`, `ctrl.rotation`, `ctrl.scale` | ⚠️ OLD PATH |
| `Juice3D.gd` | 256–258 | `n3d.position`, `n3d.rotation`, `n3d.scale` | ⚠️ OLD PATH |

> [!WARNING]
> `Juice3D` is the only domain that has NOT been migrated to the ledger-based
> write path. Its `_post_tick_write()` still uses local variable accumulation
> (`base_pos + total_pos`) instead of querying the ledger. This means 3D
> effects do NOT participate in multi-writer stacking correctly.

### System B: Ledger-Based Write (correct path)

```
effect.tick() → registers delta into ledger via JuiceBase static helpers
             ↓
domain._post_tick_write() → reads base + total from ledger
             ↓
target.property = _ledger_get_base_value() + _ledger_get_total()
```

**Active call sites:**

| File | Lines | Properties | Status |
|------|-------|-----------|--------|
| `JuiceControl.gd` | 355–357 | `ctrl.position`, `ctrl.rotation`, `ctrl.scale` | ✅ LEDGER PATH |
| `Juice2D.gd` | 327–329 | `n2d.position`, `n2d.rotation`, `n2d.scale` | ✅ LEDGER PATH |
| `Juice3D.gd` | 375–377 | `n3d.position`, `n3d.rotation`, `n3d.scale` | ✅ LEDGER PATH (reapply only) |

> [!IMPORTANT]
> `JuiceControl` has BOTH paths active. Investigation needed:
> which path does `_post_tick_write()` **actually call**? Lines 266–268 vs
> 355–357 — one of these is dead code. Identify and remove before Phase 4.

### pivot_offset — Not In Ledger (Intentional Gap)

`ctrl.pivot_offset` is written directly (no ledger registration) in 5 effect files:

| File | Count |
|------|-------|
| `TransformControlJuiceEffect.gd` | 2 sites |
| `NoiseControlJuiceEffect.gd` | 3 sites |
| `ShakeControlJuiceEffect.gd` | 2 sites |
| `SquashStretchControlJuiceEffect.gd` | 2 sites |
| `ProgressTransformControlJuiceEffect.gd` | 2 sites |

`pivot_offset` is Control-specific and affects visual pivot only. Currently
**last-write-wins** across effects. This causes the documented "pivot conflict"
(see `TestContainerControl::test_two_effects_different_pivots_on_same_node`).
Adding `pivot_offset` to the ledger would resolve this — flagged for Phase 4.

---

## 3. Ledger Raw Access Map

All `has_meta(LEDGER_KEY)` / `get_meta(LEDGER_KEY)` / `remove_meta(LEDGER_KEY)`
calls across the entire addon:

**Result: ALL raw ledger access is contained in `JuiceBase.gd` only.**

| File | Count | Location |
|------|-------|----------|
| `JuiceBase.gd` | 20+ call sites | Last ~170 lines (ledger static helpers) |
| All other files | 0 | Zero raw LEDGER_KEY access |

This is the best possible starting condition for Phase 1. The extraction
boundary is clean — no other file needs to change its imports when
`JuiceLedger.gd` is created. Only JuiceBase's internal ledger helpers move out.

### The Ledger API That Exists Today (in JuiceBase)

| Function | Phase 1 Target Name |
|----------|-------------------|
| `_ledger_ensure_initialized(target, props)` | `JuiceLedger.ensure(target, props)` |
| `_ledger_update_external_displacement(target, props)` | `JuiceLedger.sync_base_if_moved(target, props)` |
| `_ledger_set_delta(target, source, prop, delta)` | `JuiceLedger.register_delta(target, source, prop, delta)` |
| `_ledger_get_total(target, prop, zero_val)` | `JuiceLedger.get_total(target, prop, zero)` |
| `_ledger_get_base_value(target, prop, fallback)` | `JuiceLedger.get_base(target, prop, fallback)` |
| `_ledger_get_base_dict(target)` | `JuiceLedger.get_base_dict(target)` |
| `_ledger_cleanup_source(target, source, permanently)` | `JuiceLedger.cleanup_source(target, source, permanently)` |
| `_ledger_write_to_target(target)` | `JuiceLedger.flush(target)` |
| `_seq_zero_for(value)` | `JuiceLedger.zero_for(value)` (internal helper) |
| `LEDGER_KEY` constant | `JuiceLedger.LEDGER_KEY` (private) |

---

## 4. Second Shadow Meta System — `META_KEY` in JuiceControl

`JuiceControl.gd` maintains a **separate, undocumented metadata cache** for
appearance base-color tracking under a key called `META_KEY` (not `LEDGER_KEY`).

**Sites:**

| Line | Operation | Purpose |
|------|-----------|---------|
| 293 | `has_meta(META_KEY)` | Check if appearance base color cached |
| 298 | `get_meta(META_KEY)` | Read cached base `self_modulate` |
| 339 | `has_meta(META_KEY)` | Cleanup check |
| 340 | `remove_meta(META_KEY)` | Remove when no appearance effects active |
| 362 | `has_meta(META_KEY)` | Restore check in `_temporarily_reapply_visual` |
| 363 | `get_meta(META_KEY)` | Restore base color |

This is effectively a **manual ledger for one property** (`self_modulate`)
implemented before the ledger existed. It duplicates ledger logic but isn't
connected to it.

> [!IMPORTANT]
> Phase 1 should absorb this into the main ledger. `self_modulate` would be
> registered as a ledger property like any other. The `META_KEY` system
> and all its guard logic would be removed.

---

## 5. `_temporarily_undo_visual` / `_temporarily_reapply_visual` Contract

This pattern exists to support **Godot's editor save pipeline**: before Godot
saves the `.tscn` file, it must see the node in its *natural* (un-animated)
state, not the current animated state.

**Call sites in JuiceBase:**

| Line | Context | Direction |
|------|---------|-----------|
| 602 | `_notification(NOTIFICATION_EDITOR_PRE_SAVE)` | undo |
| 868 | `_start_effects()` — before warmup snapshot | undo |
| 878 | `_start_effects()` — after warmup snapshot | reapply |

**Implementation sites:**

| File | Notes |
|------|-------|
| `JuiceBase.gd` | Stubs (pass) |
| `JuiceControl.gd` | Full impl — writes ledger base to ctrl, then restores |
| `Juice2D.gd` | Full impl — `_temporarily_reapply_visual` only |
| `Juice3D.gd` | Full impl — both undo and reapply |
| `JuiceEffectBase.gd` | Stubs on effect side |
| `AppearanceControlJuiceEffect.gd` | Full impl — manages shader/modulate state |

**Can the ledger replace this?** Partially. The undo step could become
`JuiceLedger.flush(target, base_only=true)` — writes `base` with zero total,
no delta summation. The reapply step becomes `JuiceLedger.flush(target)` —
standard write. However, `AppearanceControlJuiceEffect` manages shader
material state that the ledger doesn't model — that part cannot be simplified.

**Phase 4 action:** Simplify Transform undo/reapply via ledger API.
Keep Appearance undo/reapply as-is (shader state is not ledger-tracked).

---

## 6. Signal Wiring Complexity

The `AUTO-CONNECT + SIGNAL CALLBACKS` block spans **~430 lines** and handles
17 `TriggerEvent` variants via a complex `_auto_connect_domain_signals()`
dispatch and 15+ individual `_on_*` handler functions.

**Key observation:** All signal wiring logic is IN `JuiceBase`. Domain subclasses
(`JuiceControl`, `Juice2D`, `Juice3D`) call `super._auto_connect_domain_signals()`
and add domain-specific signals (e.g., `gui_input` for Control, `input_event`
for 3D collision nodes). The domain contributions are small (~20 lines each).

**Phase 2 extraction to `JuiceTriggerRouter`:** The router moves the 430-line
block out. JuiceBase calls:
```gdscript
_router = JuiceTriggerRouter.new()
_router.wire(trigger_on, trigger_source, _handle_trigger)
```
This preserves the domain subclass extension pattern while removing the bulk
from JuiceBase.

---

## 7. Effect Duplication Quantification

Across the 3 Transform domain files, duplication is confirmed at ~85%:

| Code Section | In base? | Shared? | Lines per domain |
|-------------|---------|---------|-----------------|
| `@export` groups (TransformTarget, from/to, easing) | No | Could be | ~200 |
| Capture logic (SELF/CUSTOM/TARGET) | No | Could be | ~150 |
| `_validate_property` for conditional display | No | Could be | ~100 |
| `_apply_effect()` (lerp + delta calc) | No | Could be | ~150 |
| Domain property read/write | No | **Domain-specific** | ~50 |
| Pivot handling (Control only) | No | Control-only | ~30 |

**Extractable to `TransformJuiceEffectBase`: ~650 lines (shared once)**  
**Remaining per domain: ~50–80 lines**  
**Current: ~1,000 lines × 3 = ~3,000 lines total**  
**After: ~650 + 3×80 = ~890 lines total → 70% reduction**

Same pattern applies to Noise, Shake, Appearance, Progress, SquashStretch.

---

## 8. Structural Inconsistencies Found

| Issue | Location | Severity | Phase Fix |
|-------|----------|----------|-----------|
| `Juice3D` still on old write path | `Juice3D.gd:256–258` | 🔴 High — 3D multi-writer broken | 4 |
| Dead OLD write path in `JuiceControl` | `JuiceControl.gd:266–268` | 🟡 Medium — dead code, confusion | 4 |
| Second shadow ledger (`META_KEY`) | `JuiceControl.gd` | 🟡 Medium — parallel system | 1 |
| 20+ raw `get_meta(LEDGER_KEY)` calls | `JuiceBase.gd` | 🟡 Medium — no type safety | 1 |
| `pivot_offset` outside ledger | 5 Control effects | 🟡 Medium — last-write-wins conflict | 4 |
| Juice3D partially on ledger path (reapply only) | `Juice3D.gd:375–377` | 🟡 Medium — inconsistent | 3/4 |
| 3× duplication of effect logic | Transform/Noise/Shake/Appearance/Progress | 🟡 Medium — maintenance burden | 3 |

---

## 9. Phase 1 — Exact Extraction Checklist

Everything needed to produce `JuiceLedger.gd`:

- [ ] Create `addons/Juice_V1/Base Classes/JuiceLedger.gd` with typed static API
- [ ] Move: `LEDGER_KEY`, `_seq_zero_for`, all 8 `_ledger_*` static functions
- [ ] Replace all call sites in `JuiceBase.gd` with `JuiceLedger.*` calls
- [ ] Absorb `META_KEY` from `JuiceControl.gd` into `JuiceLedger` as `self_modulate` property
- [ ] Remove `META_KEY`, `has_meta(META_KEY)`, `get_meta(META_KEY)`, `remove_meta(META_KEY)` from `JuiceControl.gd`
- [ ] Write `tests/suites/TestJuiceLedger.gd` — ~15 isolation tests
- [ ] Verify: zero `has_meta(LEDGER_KEY)` / `get_meta(LEDGER_KEY)` outside `JuiceLedger.gd`
- [ ] Full test suite: 370+ tests, 0 failures

**Estimated scope:** ~200 lines moved, ~50 lines new (JuiceLedger wrapper code),
~30 lines removed (META_KEY system), ~150 lines new tests.  
**Risk: Low.** Only JuiceBase.gd and JuiceControl.gd change behavior.
All external callers (effects, domain nodes) are unaffected.

---

## 10. Summary Table — What Refactor Unlocks Per Phase

| Phase | Removes | Adds | Net |
|-------|---------|------|-----|
| 1 (JuiceLedger) | ~170 lines from JuiceBase, ~30 META_KEY lines | ~200 lines JuiceLedger, ~150 tests | Cleaner, tested infra |
| 2 (JuiceBase decompose) | ~1,100 lines from JuiceBase | ~600 JuiceSequencerKernel, ~200 JuiceTriggerRouter | JuiceBase → ~600 lines |
| 3 (Effect shared bases) | ~5,000 duplicate effect lines | ~2,000 shared base classes | 60% reduction in effect code |
| 4 (Write path unify) | ~50 old write path lines, META_KEY path, dead code | 0 net | Clean, single writer |
| 5 (Validate) | 0 | ~50 new ledger + router tests | Test coverage complete |

**Total estimated line reduction: ~6,000 lines from 21,904 = 27% leaner**  
**Porting cost per new V0 effect after refactor: ~700 lines vs ~3,000 lines today**

---

## 11. Phase Completion Record

**Branch:** `refactor/lean-out` → merged to `master` 2026-04-15  
**Final test count:** 391 passed, 0 failed  
**Final JuiceBase.gd size:** ~2,035 lines (from 2,267)

### What Was Done (vs Plan)

| Phase | Planned | Actual | Δ |
|-------|---------|--------|---|
| 0 | Codebase audit | ✅ `Refactor_Audit.md` created | On plan |
| 1 | JuiceLedger extraction | ✅ `JuiceLedger.gd` + 21 unit tests | On plan |
| 2 (partial) | `JuiceTriggerRouter` | ✅ 60 lines removed from JuiceBase | Reduced scope (see below) |
| 2 (dropped) | `JuiceSequencerKernel` | ❌ Not extracted | **Decision: dropped** |
| 3a | Domain transform bases | ✅ 3 × domain base files, Transform effects halved | On plan |
| 3b | Cross-domain effect base | ❌ Not extracted | **Decision: dropped** |
| 4 | Unified write path | ✅ All 3 domains use `JuiceLedger.flush()` | On plan |
| 5 | Docs + SOP update | ✅ architecture-rules.md, l2-domain.md, SKILL.md | On plan |

### Key Architectural Decisions Made During Execution

**JuiceSequencerKernel (Phase 2) — DROPPED**
- 527 sequencer lines are well-sectioned, well-commented, well-tested inside JuiceBase
- Extraction would require a Node child (for `await get_tree()...timeout`), `_owner: JuiceBase` coupling, and same code count across two files
- Decision: well-separated code in one file beats same-code in two files

**Cross-Domain TransformJuiceEffectBase (Phase 3b) — DROPPED**
- Phase 3a domain bases already halved Transform effect files (1050 → 500 lines each)
- Remaining ~500 lines are ~63% genuinely domain-specific (typed vars, typed casts, pivot math)
- The ~37% that could be shared requires Variant gymnastics — GDScript lacks generics
- Decision: stop at domain bases; cross-domain extraction makes code worse, not better

### New Files Added

| File | Purpose |
|------|---------|
| `addons/Juice_V1/Base Classes/JuiceLedger.gd` | Static multi-source write coordinator |
| `addons/Juice_V1/Base Classes/JuiceTriggerRouter.gd` | Static signal wiring utilities |
| `addons/Juice_V1/Base Classes/Juice2DTransformEffect.gd` | Domain transform base — Node2D |
| `addons/Juice_V1/Base Classes/JuiceControlTransformEffect.gd` | Domain transform base — Control |
| `addons/Juice_V1/Base Classes/Juice3DTransformEffect.gd` | Domain transform base — Node3D |
| `tests/suites/TestJuiceLedger.gd` | 21 JuiceLedger unit tests |
