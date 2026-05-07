---
name: juice-architecture
description: Juice V2 architecture contracts and patterns. Auto-invoke for addons/Juice_V2/ changes.
---

# Juice V2 Architecture

## Quick Reference
- **L1 Core**: [CONTRACTS/l1-core.md](CONTRACTS/l1-core.md)
- **L2 Domain**: [CONTRACTS/l2-domain.md](CONTRACTS/l2-domain.md)  
- **L3 Effects**: [CONTRACTS/l3-effects.md](CONTRACTS/l3-effects.md)
- **Domain Parity**: [domain-parity.md](domain-parity.md)
- **Architecture Rules**: [architecture-rules.md](architecture-rules.md) ← Rules 1–15, includes write path
- **V2 Constraints**: Rules `v2-architecture-contracts.md`, `v2-tool-surface.md`, `v2-anti-patterns.md`

## Key Architecture Boundaries
- **Domain nodes** (`@tool`): thin wiring only — `_ready()` guard, `_get_configuration_warnings()`, recipe/target refs. Zero `_process()`, zero preview code, zero `_validate_property()`.
- **Orchestrator** owns animation lifecycle: single `JuiceOrchestrator`, mode enum (`PREVIEW` / `RUNTIME`). RUNTIME reuses via `reset()`, PREVIEW `queue_free()`s on teardown.
- **Inspector plugin** owns property visibility: `JuiceEditorInspectorPlugin._parse_property()`.
- **Effects** are pure delta calculators (Resources, `@tool` for dynamic `_get_property_list()`).

## Key Infrastructure Files (Base Classes/)
| File | Purpose |
|------|---------|
| `JuiceLedger.gd` | Static write coordinator — all domain nodes flush through this |
| `JuiceTriggerRouter.gd` | Static signal wiring — MANUAL trigger routing, visibility connect |
| `Juice2DTransformEffect.gd` | Domain transform base for Node2D effects |
| `JuiceControlTransformEffect.gd` | Domain transform base for Control effects |
| `Juice3DTransformEffect.gd` | Domain transform base for Node3D effects |

## Decision Tree
```
Core system? → L1
Coordination? → L2 (domain node = wiring, orchestrator = lifecycle)
Specific effect? → L3
Editor concern? → Inspector plugin or PreviewDirector
```

## Validation
Use [VALIDATION/architecture-checklist.md](VALIDATION/architecture-checklist.md) before declaring "done". Use MCP0 for scene validation.

## Source of Truth
The master sources are the `@ARCHITECTURE_BIG_PICTURE`, `@L1-3_CONTRACT_MATRIX`, and `@JuiceStack_Design` documents located in this folder. 
**Note:** Do not read these full design docs for daily tasks as they consume too much token budget. Rely on the focused support docs and contracts listed above instead.

## External Skills
Effect creation: Use `@juice-inspector-layout` skill
Test design: Use `@test-design-for-effects` skill

## MCP Integration
Use MCP0 for Godot operations, MCP1 for documentation verification.
