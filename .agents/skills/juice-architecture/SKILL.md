---
name: juice-architecture
description: Juice V1 architecture contracts and patterns. Auto-invoke for addons/Juice_V1/ changes.
---

# Juice V1 Architecture

## Quick Reference
- **L1 Core**: [CONTRACTS/l1-core.md](CONTRACTS/l1-core.md)
- **L2 Domain**: [CONTRACTS/l2-domain.md](CONTRACTS/l2-domain.md)  
- **L3 Effects**: [CONTRACTS/l3-effects.md](CONTRACTS/l3-effects.md)
- **Domain Parity**: [domain-parity.md](domain-parity.md)
- **Architecture Rules**: [architecture-rules.md](architecture-rules.md) ← Rules 1–15, includes write path

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
Coordination? → L2
Specific effect? → L3
```

## Validation
Use [VALIDATION/architecture-checklist.md](VALIDATION/architecture-checklist.md) before declaring "done". Use MCP0 for scene validation.

## Source of Truth
The master sources for all V1 architecture are the `@ARCHITECTURE_BIG_PICTURE`, `@L1-3_CONTRACT_MATRIX`, and `@JuiceStack_Design` documents located in this folder. 
**Note:** Do not read these full design docs for daily tasks as they consume too much token budget. Rely on the focused support docs and contracts listed above instead.

## External Skills
Effect creation: Use `@juice-inspector-layout` skill
Test design: Use `@test-design-for-effects` skill

## MCP Integration
Use MCP0 for Godot operations, MCP1 for documentation verification.
