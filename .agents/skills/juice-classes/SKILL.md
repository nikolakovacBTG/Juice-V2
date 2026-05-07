---
name: juice-classes
description: Master router for Juice V2 class roles, contracts, and architecture. Use this to understand the boundary between Nodes, Resources, and Editor classes.
---

# Juice V2 Class Architecture

**DO NOT** guess which class handles which logic. Juice V2 uses a strict Layer 1/2/3 separation between Nodes (coordination) and Resources (math/config), plus dedicated Editor classes.

## Quick Start (The L1/L2/L3 Split)

If you are modifying or creating Juice files, review the relevant layer contract:

- **Layer 1 (Core Infrastructure)**: `@juice-layer1-core`
  `JuiceBase` (Node) and `JuiceEffectBase` (Resource). These define the timing, signals, and virtual methods. You rarely modify these.

- **Layer 2 (Domain Nodes)**: `@juice-layer2-domain`
  `JuiceControl`, `Juice2D`, `Juice3D`. Thin wiring — hold recipe/target refs, spawn orchestrator, provide config warnings. Zero `_process()`, zero preview code.

- **Layer 2 (Orchestrator)**: `JuiceOrchestrator` (Node, `@tool`). Owns animation tick, effect cloning, ledger registration. Mode enum: PREVIEW (transient) / RUNTIME (persistent, `reset()` for retrigger).

- **Layer 3 (Concrete Effects)**: `@juice-layer3-effects`
  e.g., `Transform2DJuiceEffect`. Resources (`@tool` for dynamic inspector). Pure delta calculators — inspector config + math, **never write to the target**.

- **Editor Classes**:
  | Class | Role |
  |-------|------|
  | `JuiceEditorInspectorPlugin` | Property visibility via `_parse_property()` |
  | `JuiceOrchestratorFactory` | Creates orchestrators: `create(recipe, target, mode)` |
  | `JuiceConfigValidator` | Pure-read validation for `_get_configuration_warnings()` |
  | `JuicePreviewDirector` | Editor transport (play/stop/scrub) |

## Source of Truth
This skill and its support docs are distilled directly from the master design documents: `@ARCHITECTURE_BIG_PICTURE`, `@L1-3_CONTRACT_MATRIX`, and `@JuiceStack_Design` (located in the `juice-architecture` skill folder). 
**Note:** Reading the full design docs is explicitly discouraged for daily tasks to save token budget. Use the lean support docs above instead.
