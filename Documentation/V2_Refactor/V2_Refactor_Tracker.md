# Juice V2 Refactor Tracker

**Branch**: `v2/refactor`
**V1 Baseline**: Tag `v1-baseline` — 588/588 tests pass (Godot 4.6.1)
**Baseline Log**: `tests/results/v1_baseline_results.log`

---

## Phase Completion

| Phase | Name | Status | Commit | Notes |
|-------|------|--------|--------|-------|
| 0 | Branch Setup & V1 Baseline | ✅ Complete | — | Tag created, V1 `.gdignore`'d, V2 dir created |
| 1 | SOP Authoring | ❌ Not started | | |
| 2 | Test Infrastructure | ❌ Not started | | |
| 3 | EditorInspectorPlugin Extraction | ❌ Not started | | |
| 4 | Single Orchestrator & Factory | ❌ Not started | | |
| 5 | Gut Domain Nodes + Config Warnings | ❌ Not started | | |
| 6 | Property Family Reintroduction | ❌ Not started | | |
| 7 | Systematic Effect Audit | ❌ Not started | | |
| 8 | Polish, Documentation & Merge | ❌ Not started | | |
| 9 | Custom Inspector GUI | ❌ Not started | | |

---

## Key Decisions Log

| Date | Decision |
|------|----------|
| 2026-05-07 | Domain nodes keep `@tool` for config warnings only |
| 2026-05-07 | Effect Resources keep `@tool` for dynamic `_get_property_list()` |
| 2026-05-07 | Shared JuiceLedger (static dict) — no changes needed for V2 |
| 2026-05-07 | Godot 4.7 Container cleanup deferred until 4.7 stable |
| 2026-05-07 | Single orchestrator class with mode enum (PREVIEW/RUNTIME) |
