# Juice V2 Refactor Tracker

**Branch**: `v2/refactor`
**V1 Baseline**: Tag `v1-baseline` — 588/588 tests pass (Godot 4.6.1)
**Baseline Log**: `tests/results/v1_baseline_results.log`

---

## Phase Completion

| Phase | Name | Status | Commit | Notes |
|-------|------|--------|--------|-------|
| 0 | Branch Setup & V1 Baseline | ✅ Complete | — | Tag created, V1 `.gdignore`'d, V2 dir created |
| 1 | SOP Authoring | ✅ Complete | — | Skipped formal phase — SOPs pre-existed |
| 2 | Test Infrastructure | ✅ Complete | — | All 8 empty suite stubs registered in runner |
| 3.1 | Plugin Shell + JuiceBase Migration | ✅ Complete | e76632d | Plugin created, show/hide migrated |
| 3.2 | Domain Node Wrapper Migration | ✅ Complete | e76632d | `_validate_property` restored (hint-only, hybrid) |
| 3.3 | TestEditorInspectorPlugin + MCP F1/F2 | ✅ Complete | e76632d | 8 headless + 2 MCP tests pass |
| 4A | Orchestrator + Factory Build | ✅ Complete | 91efe4d | JuiceOrchestrator + JuiceOrchestratorFactory |
| 4B | Wire PreviewDirector + Tests | ✅ Complete | 91efe4d | transport 30/30, orchestrator 9/9, factory 5/5 |
| 5A | Orchestrator: `extends Object` → `extends Node` | ✅ Complete | e52ae8b | `queue_free()` replaces `call_deferred("free")` |
| 5B1 | Extract `JuiceBase.tick()`, wire PREVIEW orch `_process` | ✅ Complete | 2c879a5 | Orchestrator drives PREVIEW tick via `_node.tick()` |
| 5B2 | RUNTIME orchestrator — STACK mode | ✅ Complete | d68b0d9 | `_start_effects()` STACK path through orch |
| 5B3 | RUNTIME orchestrator — SEQUENCER mode | ✅ Complete | fb54f23 | Sequencer tick delegated to orch |
| 5C1 | Move `_runtime_effects` + `_active_indices` to Orch | ✅ Complete | c905ea0 | Effect cloning in `Orchestrator.setup()` |
| 5C2 | Inline STACK tick body into `JuiceOrchestrator._process` | ✅ Complete | bfd024d | JuiceBase.tick() deleted |
| 5C3a | Orchestrator owns ledger cleanup via `_exit_tree` | ✅ Complete | 6081aea | Ledger registration/deregistration in orch |
| 5C4 | Orchestrator drives SEQUENCER directly, tick deleted | ✅ Complete | 9f4030e | JuiceBase.tick_sequencer() deleted |
| 5D | Strip `_process()` and editor-preview spawn guards | ✅ Complete | 4fc12a3 | Zero `set_process()` calls in domain nodes |
| 5E | Align factory signature to architecture doc | ✅ Complete | e5e03a7 | `create(node, recipe, target, mode)` |
| 5 gate | TestConfigWarnings — 5 tests | ✅ Complete | 5258dd3 | config_warnings 5/5 |
| 5 fixes | Juice2D dead override, superseded guard, timing | ✅ Complete | e98d503 | Runtime regressions resolved |
| 5 fixes | First-run seq jump + VFX persistence (partial) | ✅ Complete | ac3f77c | Ledger seed virtual, `is_playing` guard removed |
| 6 | Property Family Reintroduction | ⏸ Deferred | — | Deferred — V1 feature parity first |
| **7.1** | **Audit editor guards (5-file sweep)** | **✅ Complete** | — | Verified keeps: SoftTrigger/Interaction. Removed dead Appearance2D warning guard |
| **7.2** | **IN_EDITOR regression tests (TestEditorCache)** | **✅ Complete** | — | 11/11 pass: baked-cache fallback, ledger-override, cache-clear, pre-save routing |
| **7.3** | **`NOTIFICATION_EDITOR_PRE_SAVE` guard confirmed** | **✅ Complete** | — | Routing verified; `_do_update_editor_cache` guarded by `Engine.is_editor_hint()` — headless-safe |
| 8 | Polish, Documentation & Merge | ✅ Complete | 5d55e21 | Merged into main, 652/652 tests pass |
| 9 | Custom Inspector GUI | ✅ Complete | f5f71e9 | Fully integrated rich array editor, picker, and tooltips |

**Current test count: 652/652 (0 failures)**

---

## Phase 7 — Complete ✅

Phase 7 audited all V2 files for editor-specific code correctness. All three sub-phases passed.

### 7.1 — Editor guard audit (5-file sweep)
- **Kept (legitimate bootstrap guards):** `ScreenJuiceEffect`, `SceneActionJuiceUtilityBase`, `Camera3DJuiceEffect`, `Camera2DJuiceEffect` — all prevent dirty editor scenes on `@tool` load.
- **Removed dead code:** `Appearance2DJuiceEffect.gd` — permanently unreachable configuration warning with `not Engine.is_editor_hint()` condition inside a Godot-editor-only warning path.
- **IN_EDITOR cache guards confirmed correct:** `Juice2DTransformEffect.gd` lines 124–127 clear editor cache when switching `from_capture_at` away from `IN_EDITOR`. Guarded by `Engine.is_editor_hint()` for write side.

### 7.2 — `TestEditorCache` regression suite (11 tests)
- **from-cache fallback:** empty ledger → baked editor cache wins.
- **from-cache ledger-override:** ledger present → ledger wins (true natural state).
- **to-cache fallback + ledger-override:** same guarantees for `to_capture_at` slot.
- **cache-clear on mode switch:** position, rotation, scale all zeroed when switching away from `IN_EDITOR`.
- **NOTIFICATION_EDITOR_PRE_SAVE routing:** chain reaches effects without crash in headless (`_do_update_editor_cache` exits early, guarded by `Engine.is_editor_hint()`).

### 7.3 — Pre-save guard confirmation
`_do_update_editor_cache()` in all transform effects is correctly guarded by `Engine.is_editor_hint()` — headless-safe, no runtime contamination. No migration needed (routing stays in `JuiceBase._notification()`, which is the correct hook location for per-node pre-save callbacks).

---

## Key Decisions Log

| Date | Decision |
|------|----------|
| 2026-05-07 | Domain nodes keep `@tool` for config warnings only |
| 2026-05-07 | Effect Resources keep `@tool` for dynamic `_get_property_list()` |
| 2026-05-07 | Shared JuiceLedger (static dict) — no changes needed for V2 |
| 2026-05-07 | Godot 4.7 Container cleanup deferred until 4.7 stable |
| 2026-05-07 | Single orchestrator class with mode enum (PREVIEW/RUNTIME) |
| 2026-05-07 | Phase 6 (Property Family) deferred — V1 feature parity ships first |
| 2026-05-07 | VFX EXTERNAL_SCENE persistence across replays — known issue, deferred |
