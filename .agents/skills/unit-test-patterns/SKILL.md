---
name: unit-test-patterns
description: Unit testing patterns for Juice V2 effects and orchestrator. Auto-invoke during /port workflow.
---

# Unit Testing Patterns

## Quick Start
1. **Template**: Use [unit_test_template.md](unit_test_template.md)
2. **Assertions**: Use [core_assertions.md](core_assertions.md)

## Core Requirements
- **One Suite Per Domain**: `Test[Effect]2D.gd`, `Test[Effect]Control.gd`, `Test[Effect]3D.gd`
- **Register Suite**: Add to `_register_suites()` in `tests/JuiceTestRunner.gd`
- **Minimum Coverage**:
  - `test_basic_effect_applies`
  - `test_returns_to_natural_after_completion`
  - Effect-specific property tests

## Orchestrator Test Patterns
- **RUNTIME lifecycle**: spawn → play → complete → idle → retrigger via `reset()` → verify no new node allocation
- **PREVIEW lifecycle**: spawn → play → teardown → verify `queue_free()` fired and node is freed
- **Ledger cleanup**: after both modes, verify `JuiceLedger.has_ledger(target)` returns `false`
- **Retrigger allocation**: count children before/after `reset()` — must be identical (zero new nodes)

## Test Environment
- Tests run headless via `.bat` file (see MCP integration rule)
- Target nodes must be created via helper functions (`create_control_target`, etc.)
- Use `await wait_frames(2)` before capturing natural state to allow `_ready` propagation
