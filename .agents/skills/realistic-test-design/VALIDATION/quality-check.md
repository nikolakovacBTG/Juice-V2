# Realistic Test Quality Check

Run this checklist before declaring any realistic test suite complete.

## Anti-Patterns — Fail if ANY are true

- [ ] **Internal-API-only tests**: Test calls `_enter_editor_preview()`, `_deferred_editor_preview_init()`, or other `_private` methods directly without going through a developer-facing API
- [ ] **Zero-position targets**: All targets are at `(0, 0)` — real scenes never are
- [ ] **Single-effect-only**: No stacking scenario tested
- [ ] **No restore assertion**: Effect applies but test never asserts target returns to natural state
- [ ] **Headless-only for editor features**: Any `@tool` path, transport, or inspector behavior tested headless only
- [ ] **MCP tests not documented**: Tier 2 tests not documented in test file header comment

## Required Coverage — Must have at least one of each

- [ ] First-time setup scenario (Family A or F)
- [ ] Multi-effect stacking on a single recipe (Family B)
- [ ] **Concurrent multi-source stacking** — two Juice nodes, same target, triggered independently with overlap (Family B2 or J)
- [ ] **Runtime robustness** — at minimum K1 (instantiate), K2 (cleanup), K4 (target deleted) (Family K)
- [ ] **Editor robustness** — at minimum L4 (node duplication) (Family L)
- [ ] Restore-to-natural assertion after stop
- [ ] Non-zero position target
- [ ] Tier 2 transport/preview scenario if effect has any editor-side behavior

## Quality Bar

A realistic test suite passes quality check when:
1. A QA engineer reading it would recognize the scenarios as things they'd do manually
2. It catches bugs that unit tests won't (position offsets, stacking conflicts, container interference, editor state leaks)
3. Every Tier 2 test has a clear "what a developer does" framing in its comment
