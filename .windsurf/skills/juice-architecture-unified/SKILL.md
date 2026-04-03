---
name: juice-architecture-unified
description: Unified Juice V1 architecture skill combining core rules and contracts. Auto-invoke when reading or writing any file in addons/Juice_V1/. Provides delta-first write model, effect-as-Resource contract, domain parity rules, layer contracts, decision tree, and GDScript templates for effects and tests.
---

# Juice V1 Unified Architecture Skill

**When to use:** Any time you read, write, or modify files in `addons/Juice_V1/`.

**Purpose:** Unified skill providing complete Juice V1 architecture guidance - core rules, contracts, templates, and validation in one place.

---

## Architecture Overview

### L1-3 Layer System
- **L1 Core:** Delta-first model, timing system, base interfaces
- **L2 Domain:** Write coordination, sibling stacking, domain separation, external move detection  
- **L3 Effects:** Transform deltas, appearance, procedural animation, shader integration, meta effects, utility patterns

### Core Contracts
- **Effects calculate deltas only** - never write directly to targets
- **Domain nodes aggregate and write once per frame**
- **All three domains must have equivalent features**
- **Delta-first mathematical model** for all animations

---

## Before ANY Code Change

1. **Read the relevant section** of `Documentation 2/L1/`, `Documentation 2/L2/`, or `Documentation 2/L3/`
2. **Check architecture contracts** in this skill
3. **Verify domain completeness** - all 3 domains must have equivalent features
4. **Use templates** as structural starting points

---

## Templates Available

| Template | Use when... |
|----------|-------------|
| `effect-template-control.gd` | Creating a new Control-domain effect |
| `test-template.gd` | Creating a new test suite for any effect |

### Domain Adaptation
For 2D and 3D effects, adapt the Control template by:
- `extends JuiceControlTransformEffect` → `extends Juice2DTransformEffect` / `extends Juice3DTransformEffect`
- `Vector2` → `Vector2` (2D) or `Vector3` (3D) for position/scale
- `Control` → `Node2D` / `Node3D` for target type
- `JuiceControl` → `Juice2D` / `Juice3D` for host node

---

## Layer Decision Tree

### Is this a core system change?
**YES** → L1 Core (timing, interfaces, mathematical foundations)
**NO** → Continue

### Is this coordinating multiple effects?
**YES** → L2 Domain (write coordination, sibling stacking)
**NO** → Continue

### Is this a specific animation effect?
**YES** → L3 Effect (delta calculations only)
**NO** → Re-evaluate

---

## Critical Validation Checklist

### Layer Contract Compliance
- [ ] L1 provides pure mathematical foundations
- [ ] L2 coordinates but doesn't calculate deltas
- [ ] L3 calculates deltas but doesn't write
- [ ] Cross-domain dependencies don't exist

### Domain Completeness
- [ ] All features exist in Control, Node2D, and Node3D domains
- [ ] Domain-specific math is correct (Vector2 vs Vector3)
- [ ] Container hold pattern works for Control only
- [ ] External move detection exists in all domains

### Anti-Patterns to Avoid
- [ ] Effects writing directly to targets
- [ ] Domain nodes calculating deltas
- [ ] Hardcoded property channels
- [ ] Per-domain copy-paste logic
- [ ] String IDs in arrays
- [ ] External project dependencies

---

## Quick Reference

### Documentation Resources
- **Architecture Big Picture:** `Documentation 2/ANCHORS/ARCHITECTURE_BIG_PICTURE.md`
- **L1-3 Contract Matrix:** `Documentation 2/ANCHORS/L1-3_CONTRACT_MATRIX.md`
- **Layer Documentation:** `Documentation 2/L1/`, `Documentation 2/L2/`, `Documentation 2/L3/`
- **Rules:** `Documentation 2/Rules/`

### Common Tasks
- **Adding Effects:** Create L3 resources for all 3 domains, register in recipes, write tests
- **Architecture Issues:** Identify violation type, apply fix, validate with test suite
- **Performance:** Profile delta calculations, optimize write coordination

---

## Quality Gate

Before declaring any V1 code change "done":
1. **Run test suite** - all tests must pass
2. **Cite specific test names** that verify the change
3. **Verify layer contracts** - no architectural violations
4. **Check domain completeness** - all 3 domains covered

---

## Error Handling

### Common Architecture Errors
- **Layer breach:** L3 writing to targets or L2 calculating deltas
- **Domain incompleteness:** Feature exists in one domain but not others
- **Anti-patterns:** Hardcoded properties, string IDs, external dependencies

### Recovery Process
1. Identify error type using contracts
2. Reference appropriate documentation
3. Apply fix according to patterns
4. Validate with test suite

---

This unified skill provides complete Juice V1 architecture guidance while maintaining lean context for AI agents.
