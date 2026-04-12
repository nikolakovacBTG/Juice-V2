---
trigger: glob
glob: "**/*JuiceEffect.gd"
description: Enforces Juice inspector layout standards. All effects must use @juice-inspector-layout skill.
---

# Juice Inspector Layout Enforcement

## Mandatory Requirement

**ALL Juice effects MUST use `@juice-inspector-layout` skill** before implementing inspector layouts. DO NOT invent custom layouts.

## Core Enforcement

### Required Skill Usage
1. Read `@juice-inspector-layout` completely before implementation
2. Select appropriate pattern (universal, conditional exports, or from/to)
3. Follow exact 9-step hierarchy specified in skill
4. Use skill's validation checklist before committing

### Critical Rules (from skill)
- NEVER call `super._get_property_list()` in subclasses
- All `@export` variables MUST have `##` tooltips
- Use `_get_effect_base_properties()` for timing parameters
- Follow exact group order and placement

### Validation
- Use skill's validation checklist for compliance
- Ensure 9-step hierarchy is followed exactly
- Verify no custom layout inventions

## Enforcement

This Rule ensures compliance by requiring the skill for all Juice effect inspector layouts. The skill provides detailed patterns; this rule enforces their usage.

**Bottom line**: Use `@juice-inspector-layout` skill for every effect. No exceptions.
