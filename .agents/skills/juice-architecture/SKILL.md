---
name: juice-architecture
description: Core architecture rules and code templates for the Juice V1 addon. Auto-invoke when reading or writing any file in addons/Juice_V1/. Contains delta-first write model, effect-as-Resource contract, domain parity rules, and GDScript templates for effects and tests.
---

# Juice V1 Architecture Skill

**When to use:** Any time you read, write, or modify files in `addons/Juice_V1/`.

## Before ANY Code Change

1. **Read the relevant section** of `Documentation/JuiceStack_Design.md`
2. **Read `architecture-rules.md`** in this skill folder — it contains the condensed non-negotiable rules
3. **Check `Documentation/Port_Master_Tracker.md`** for current port status
4. If porting a new effect, use the templates in this folder as structural starting points

## Templates Available

| Template | Use when... |
|----------|-------------|
| `effect-template-control.gd` | Creating a new Control-domain effect |
| `test-template.gd` | Creating a new test suite for any effect |

For 2D and 3D effects, adapt the Control template by:
- Changing `extends JuiceControlTransformEffect` → `extends Juice2DTransformEffect` / `extends Juice3DTransformEffect`
- Changing `Vector2` → `Vector2` (2D) or `Vector3` (3D) for position/scale
- Changing `Control` → `Node2D` / `Node3D` for target type
- Changing `JuiceControl` → `Juice2D` / `Juice3D` for host node

## Quality Gate

Before declaring any V1 code change "done":
1. Run `/test` — full suite must pass
2. Cite specific test names that verify the change
3. If no test exists for this feature, write one first
4. Invoke `@verify-claims` before any "done" statement
