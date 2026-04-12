---
name: juice-inspector-layout
description: Expert guidance for organizing Inspector GUI layout in Juice effects. Routes to specific layout pattern support docs.
---

# Juice Inspector GUI Layout

**DO NOT** guess Inspector layouts. Juice effects follow a strict, unified hierarchy that balances designer usability with complex technical needs.

## Quick Start
Before implementing an effect's layout, review the relevant support document based on the effect's complexity:

- **All Effects (MANDATORY)**: `@universal-layout-pattern`
  Read this first. Defines the strict 1-to-9 top-to-bottom group order (Effect → Subgroups → From/To → Animate In → etc.) that ALL effects must follow.

- **Complex/Dynamic Interfaces**: `@conditional-exports-hybrid`
  Read when your effect needs to show/hide properties or entire groups based on a selector (e.g. `transform_target`, `appearance_effect`). Details the hybrid `_validate_property` vs `_get_property_list` approach.

- **Transform / Start-End Effects**: `@from-to-layout-pattern`
  Read when your effect moves a property from a starting state to an ending state. Distilled from `@Transform_FromTo_Design`.

## Core Directives

1. **Never call `super._get_property_list()`** in a `JuiceEffectBase` subclass. Godot combines them automatically; calling super causes duplicate properties.
2. **Standard Timing Parameters** (`trigger_behaviour`, `start_delay`, `crossfade_time`, `loop_count`) are injected via `_get_effect_base_properties()`. They generally appear after core effect parameters.
3. **Every exposed property** MUST have a `##` doc comment for tooltips.
4. **Conditional Display** is not just for hiding properties—entire groups (like `From` and `To`) should only be emitted if the effect's nature allows them.
