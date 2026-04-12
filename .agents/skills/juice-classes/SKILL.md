---
name: juice-classes
description: Master router for Juice V1 class roles, contracts, and architecture. Use this to understand the boundary between Nodes and Resources.
---

# Juice V1 Class Architecture

**DO NOT** guess which class handles which logic. Juice V1 uses a strict Layer 1/2/3 separation between Nodes (coordination) and Resources (math/config).

## Quick Start (The L1/L2/L3 Split)

If you are modifying or creating Juice files, review the relevant layer contract:

- **Layer 1 (Core Infrastructure)**: `@juice-layer1-core`
  `JuiceBase` (Node) and `JuiceEffectBase` (Resource). These define the timing, signals, and virtual methods. You rarely modify these.

- **Layer 2 (Domain Nodes)**: `@juice-layer2-domain`
  `JuiceControl`, `Juice2D`, `Juice3D`. These are Nodes. They handle the `_process` loop, target discovery, external move detection, and writing to the target.

- **Layer 3 (Concrete Effects)**: `@juice-layer3-effects`
  e.g., `Transform2DJuiceEffect`. These are Resources. They are "Pure Delta Calculators." They contain the inspector GUI configuration and the math to calculate offsets, but **they never write to the target**.

## Source of Truth
This skill and its support docs are distilled directly from the master design documents: `@ARCHITECTURE_BIG_PICTURE`, `@L1-3_CONTRACT_MATRIX`, and `@JuiceStack_Design` (located in the `juice-architecture` skill folder). 
**Note:** Reading the full design docs is explicitly discouraged for daily tasks to save token budget. Use the lean support docs above instead. The messy, fragmented notes in `Documentation 2` and `Documentation` are considered historical/drafts and are superseded by these focused skills.
