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
| **7** | **Systematic Effect Audit (editor code cleanup)** | **⬅ NEXT** | — | See Phase 7 targets below |
| 8 | Polish, Documentation & Merge | ❌ Not started | — | Requires Phase 7 complete |
| 9 | Custom Inspector GUI | ❌ Not started | — | Post-merge |

**Current test count: 615/615 (0 failures)**

---

## Phase 7 — Targets

Phase 7 audits all V2 files for editor-specific code that should not be in the runtime path. Prerequisite (Phase 5 complete) is met.

### 7.1 — Migrate `_enter/_exit_editor_preview` from JuiceBase → JuicePreviewDirector

These lifecycle methods were left in JuiceBase at Phase 5D because PreviewDirector still called them. They must move before Phase 8.

**Remaining items in JuiceBase (confirmed by audit):**
- `Engine.is_editor_hint()` at lines 206, 237, 244, 252 — `_on_recipe_changed()` / `_ready()` editor hooks (legitimate, keep as-is)
- `Engine.is_editor_hint()` at line 433 — `_resolve_hint_source_node()` guard (legitimate editor helper, keep as-is)
- `Engine.is_editor_hint()` at line 1846 — `NOTIFICATION_EDITOR_PRE_SAVE` handler — **move to `juice_plugin.gd _save_external_data()`**
- `Engine.is_editor_hint()` at line 1913 — `_do_update_editor_cache()` in effect domain — **Phase 7 audit target**

**Remaining items in Transform effects (IN_EDITOR cache baking):**
- `JuiceControlTransformEffect.gd` lines 127, 136
- `Juice3DTransformEffect.gd` lines 137, 146
- `Juice2DTransformEffect.gd` lines 126, 135
- `Transform3DJuiceEffect.gd` line 216
- `Transform2DJuiceEffect.gd` line 184
- `Appearance2DJuiceEffect.gd` lines 700–701

**Utilities (legitimate `@tool` guards — likely keep as-is):**
- `SoftTriggerControlJuiceUtility.gd`, `SoftTrigger2DJuiceUtility.gd`, `SoftTrigger3DJuiceUtility.gd`
- `Interaction2DJuiceUtility.gd`, `Interaction3DJuiceUtility.gd`

### 7.2 — Write baked cache regression test for `CaptureAt.IN_EDITOR` effects

Gate: test confirms editor-cached positions survive a Play→Stop→Play cycle without re-baking.

### 7.3 — `NOTIFICATION_EDITOR_PRE_SAVE` handler → `juice_plugin.gd`

Move the pre-save undo/redo of visual state from `JuiceBase._notification()` to `juice_plugin._save_external_data()`.

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
