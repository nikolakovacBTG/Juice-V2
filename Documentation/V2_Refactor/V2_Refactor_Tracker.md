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
| 3.2 | Domain Node Wrapper Migration | ✅ Complete | e76632d | _validate_property restored (hint-only, hybrid) |
| 3.3 | TestEditorInspectorPlugin + MCP F1/F2 | ✅ Complete | e76632d | 8 headless + 2 MCP tests pass |
| 4A | Orchestrator + Factory Build | ✅ Complete | 91efe4d | JuiceOrchestrator + JuiceOrchestratorFactory |
| 4B | Wire PreviewDirector + Tests | ✅ Complete | 91efe4d | transport 30/30, orchestrator 9/9, factory 5/5 |
| 5 | Gut Domain Nodes + Config Warnings | ❌ Not started | | Tick loop extraction → JuiceOrchestrator |
| 6 | Property Family Reintroduction | ❌ Not started | | |
| 7 | Systematic Effect Audit | ❌ Not started | | |
| 8 | Polish, Documentation & Merge | ❌ Not started | | |
| 9 | Custom Inspector GUI | ❌ Not started | | |

**Current test count: 610/610 (0 failures)**

---

## Key Decisions Log

| Date | Decision |
|------|----------|
| 2026-05-07 | Domain nodes keep `@tool` for config warnings only |
| 2026-05-07 | Effect Resources keep `@tool` for dynamic `_get_property_list()` |
| 2026-05-07 | Shared JuiceLedger (static dict) — no changes needed for V2 |
| 2026-05-07 | Godot 4.7 Container cleanup deferred until 4.7 stable |
| 2026-05-07 | Single orchestrator class with mode enum (PREVIEW/RUNTIME) |
