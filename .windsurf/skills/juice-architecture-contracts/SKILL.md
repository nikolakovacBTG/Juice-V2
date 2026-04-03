---
name: juice-architecture-contracts
description: One-page Juice V1 architecture reference. Auto-invoke when reading or writing any file in addons/Juice_V1/. Provides layer contracts, decision tree, and quick validation to keep AI context lean while maintaining architectural integrity.
---

# Juice V1 Architecture Contracts

**When to use:** Any time you read, write, or modify files in `addons/Juice_V1/`.

**Purpose:** One-page reference for AI agents to quickly identify layers, contracts, and decision boundaries without reading the entire codebase.

**What it provides:**
- Layer decision tree
- Critical contracts (delta-first, domain separation, write coordination)
- Quick validation checklist
- Anti-patterns to avoid
