# Juice V1 Architecture - Big Picture Overview

**Purpose:** Immutable reference document that maintains complete system overview during refactoring. Never modify this document - it's the architectural north star.

---

## System Architecture at a Glance

### The Core Problem Juice Solves
**Godot Animation Pain Points:**
- Manual tween setup for every animation
- No unified system for stacking effects
- Domain fragmentation (Control vs 2D vs 3D)
- No reusable animation patterns
- Poor performance from duplicated work

### Juice V1 Solution
**Unified Architecture:**
- Single node per target (JuiceControl/Juice2D/Juice3D)
- Recipe-based effect composition
- Delta-first mathematical model for effect stacking
- Domain-specific implementations with shared contracts
- Performance-optimized per-frame write coordination

---

## L1-3 Layer Architecture

### L1: Core Infrastructure (The Foundation)
**Responsibility:** Provide unified interfaces, timing, and base classes that all domains use.

**Key Components:**
- `JuiceBase` - Unified node lifecycle and recipe management
- `JuiceEffectBase` - Effect resource interface and delta calculation contract
- `JuiceRecipe` - Effect container and sequencing logic
- Timing system - Animation lifecycle, chaining, and coordination

**Critical Contracts:**
- Effects compute deltas only (never write to targets)
- Domain nodes handle all target writes once per frame
- Base value capture and external-move detection
- Unified trigger system across all domains
> **See:** `L1-3_CONTRACT_MATRIX.md` for complete contract specifications, validation rules, and code examples

### L2: Domain Coordination (The Conductor)
**Responsibility:** Filter targets by domain type, coordinate multiple effects, and handle domain-specific challenges.

**Key Components:**
- `JuiceControl` - Control-targeted effects and Container hold patterns
- `Juice2D` - Node2D effects and pivot compensation
- `Juice3D` - Node3D effects and spatial coordination
- Sibling stacking logic - Multiple Juice nodes on same target
- Write coordination - Prevent conflicting writes per frame

**Critical Contracts:**
- Each domain only handles its target type (strict separation)
- Per-frame aggregation of all active effect deltas
- External-move detection and base value recapture
- Container-specific behavior (Control only)

### L3: Effect Implementation (The Performers)
**Responsibility:** Compute specific effect deltas using domain-appropriate math and patterns.

**Key Components:**
- Transform effects (position, rotation, scale)
- Appearance effects (visibility, modulate, shader params)
- Procedural effects (noise, shake, spring)
- Meta effects (time, properties, utilities)
- From/To reference resolution (CUSTOM, SELF, TARGET_NODE)

**Critical Contracts:**
- Pure delta calculators (no side effects)
- Domain-specific math and pivot handling
- Reference capture at animation start
- Contribution reporting for stacking coordination

---

## Delta-First Mathematical Model

### The Core Innovation
**Traditional Approach:** Effects write final values directly to targets
**Juice Approach:** Effects compute deltas, domain nodes write natural + sum(deltas)

### Why This Matters
**Stacking:** Multiple effects can contribute to the same property without conflicts
**External Changes:** User code, physics, or other systems can move targets between frames
**Performance:** Single write per property per frame instead of multiple writes
**Predictability:** Clear mathematical relationship between effects and final result

### The Formula
```
final_target_value = natural_base_value + sum(all_effect_deltas)
```

### Implementation Pattern
```gdscript
# Effect calculates delta
func _get_seq_contribution() -> Dictionary:
    return {"position": desired_position - _captured_base_position}

# Domain node aggregates and writes
func _post_tick_write():
    var total_delta = Vector2.ZERO
    for effect in active_effects:
        total_delta += effect._get_seq_contribution().position
    target.position = _captured_natural_position + total_delta
```

---

## Domain Separation Strategy

### Why Separate Domains?
**Godot's Architecture:** Control, Node2D, and Node3D have fundamentally different:
- Property types (Vector2 vs Vector3 vs position-only)
- Coordinate systems and pivot behavior
- Rendering and layout systems
- Performance characteristics

### Domain-Specific Challenges
**Control:**
- Container layout system re-sorts children every frame
- No transform properties (only position)
- Pixel snapping and integer coordinates
- Parent-child layout relationships

**Node2D:**
- Transform properties (position, rotation, scale)
- No pivot point (origin at top-left)
- Global vs local coordinate transforms
- Z-index and drawing order

**Node3D:**
- 3D transforms and spatial relationships
- Multiple coordinate spaces (local, global, viewport)
- Camera and viewport transformations
- Physics and collision integration

### Cross-Domain Consistency
**Shared Contracts:**
- All domains use delta-first model
- All domains implement same effect interface
- All domains handle sibling stacking
- All domains support From/To reference resolution

**Domain-Specific Implementation:**
- Different property types and math
- Different base capture methods
- Different external-move detection
- Different performance optimizations

---

## Effect Categories and Patterns

### Transform Effects
**Purpose:** Animate position, rotation, scale with tween-based easing
**Pattern:** From/To animation with reference resolution
**Examples:** TransformControlJuiceEffect, Transform2DJuiceEffect, Transform3DJuiceEffect

### Appearance Effects
**Purpose:** Animate visual properties like visibility, color, shaders
**Pattern:** Direct property animation with optional From/To
**Examples:** AppearanceControlJuiceEffect, Appearance2DJuiceEffect, Appearance3DJuiceEffect

### Procedural Effects
**Purpose:** Generate ongoing mathematical animations (noise, shake, spring)
**Pattern:** Reactive to external forces, no fixed endpoints
**Examples:** Noise2DJuiceEffect, ShakeControlJuiceEffect, Spring3DJuiceEffect

### Meta Effects
**Purpose:** Non-visual coordination and utility functions
**Pattern:** System-level behaviors and cross-cutting concerns
**Examples:** TimeJuiceEffect, PropertyJuiceEffect, SceneActionJuiceUtility

---

## Critical Architectural Invariants

### Must Never Change
1. **Delta-First Model:** Effects never write directly to targets
2. **Domain Separation:** Each domain only handles its target type
3. **Single Write Per Frame:** Domain nodes write each property once per frame
4. **Effect Purity:** Effects have no side effects beyond delta calculation
5. **Base Capture:** Natural values captured before any effects apply

### Must Always Honor
1. **External-Move Detection:** Detect and handle target changes between frames
2. **Sibling Stacking:** Multiple Juice nodes on same target must work together
3. **Reference Resolution:** From/To references resolved correctly at animation start
4. **Timing Consistency:** All effects share unified timing and lifecycle
5. **Performance Optimization:** Minimal per-frame overhead

---

## Integration Points and Dependencies

### Core Dependencies
- **Godot 4.x** - Engine version and API compatibility
- **Node Tree** - Parent-child relationships and signal connections
- **Resource System** - Effect resources and recipe serialization
- **Animation System** - Integration with Godot's animation players

### External Systems
- **User Code** - Scripts that may animate targets independently
- **Physics Engine** - Forces and collisions that move targets
- **UI System** - Container layouts and control positioning
- **Rendering Pipeline** - Material and shader property access

### Performance Considerations
- **Per-Frame Overhead** - Minimize calculations in _process()
- **Memory Allocation** - Avoid garbage collection during animation
- **Batch Operations** - Group similar operations together
- **Early Exit** - Skip work when effects are inactive

---

## This Document's Role

### During Refactoring
- **North Star:** Maintains complete system view while working on individual pieces
- **Validation Source:** Check that changes don't break core architectural contracts
- **Context Anchor:** Re-read when losing big picture awareness during micro-batching

### After Refactoring
- **Onboarding Reference:** New developers can understand complete system quickly
- **Decision Guide:** Architectural decisions trace back to core principles
- **Maintenance Guard:** Changes must honor these invariants to remain valid

**Remember:** This document represents the architectural truth of Juice V1. All other documents should align with these principles, not contradict them.
