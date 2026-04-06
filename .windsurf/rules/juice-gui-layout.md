---
description: Enforces the preferred Inspector GUI layout pattern for all Juice effects.
---

# Juice Inspector GUI Layout Rule

**When creating or modifying Juice effects, you MUST follow the universal Inspector GUI layout pattern.**

The preferred pattern is strictly defined in the `@juice-inspector-layout` skill. Do not deviate from this hierarchy or invent custom group organizations.

## Core Mandates:
1. **Always consult `@universal-layout-pattern`** (via the `juice-inspector-layout` skill) before designing an effect's exported properties.
2. The layout must follow the strict top-to-bottom sequence: `Effect` → `[Subgroups]` → `[From/To]` → `Animate In` → `Animate Out` → `Chaining` → `Debug` → `Resource`.
3. Standard timing parameters (`trigger_behaviour`, `start_delay`, `crossfade_time`, `loop_count`) must be injected via `_get_effect_base_properties()`.
4. Never call `super._get_property_list()`.
5. All exposed properties must have `##` doc comments.

If an effect's current GUI does not match this specification, it is considered legacy and should be updated to comply with the `@juice-inspector-layout` skill.
