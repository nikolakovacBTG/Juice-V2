---
name: realistic-test-design
description: Design and write high-quality Juice V2 realistic tests. Auto-invoke when writing /realistic-test scenarios. Prevents thin, lifecycle-only tests by enforcing user-behaviour-first design.
---

# Juice V2 Realistic Test Design

Realistic tests offset manual testing from the human developer. They simulate **real developer workflows**, not just technical lifecycle hooks.

## Decision Tree

**Designing Tier 1 (headless) scenarios?**
→ [REFERENCES/tier1-scenarios.md](REFERENCES/tier1-scenarios.md)

**Designing Tier 2 (MCP editor) scenarios?**
→ [REFERENCES/tier2-scenarios.md](REFERENCES/tier2-scenarios.md)

**Writing the test code?**
→ [TEMPLATES/tier1-template.md](TEMPLATES/tier1-template.md) or [TEMPLATES/tier2-template.md](TEMPLATES/tier2-template.md)

**Validating test quality?**
→ [VALIDATION/quality-check.md](VALIDATION/quality-check.md)

## The Core Rule

> **Test what a developer would do, not what the code does internally.**

A developer does not call `_enter_editor_preview()`. A developer:
1. Adds a Juice node to their scene
2. Assigns a recipe with effects
3. Connects a trigger
4. Presses Play or uses the transport
5. Observes the animation in context with other nodes

Every realistic test must trace back to one of these user actions.

## Quick Validation
Before finalizing any test suite, run [VALIDATION/quality-check.md](VALIDATION/quality-check.md).
