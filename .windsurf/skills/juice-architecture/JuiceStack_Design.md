# JuiceStack Architecture — Implementation Reference

**Purpose:** Cascade's internal reference to prevent drift during the refactor. Every decision below is final unless the user explicitly changes it.

## Mission

Replace individual effect Nodes with Resource-based effects inside host Nodes. Every feature in the current system (`addons/juice/`) has a counterpart in the new system (`addons/Juice_V1/`). **No feature cuts. No deferrals. No simplifications.**

---

## Core Types

| Type | Base | Role |
|---|---|---|
| `JuiceEffectBase` | `Resource` | Config + `apply(progress, target)` virtual. Can hold state (spring velocity, noise time). No Node lifecycle. |
| `JuiceRecipe` | `Resource` | `Array[JuiceEffectBase]`. Savable `.tres`, shareable, distributable as marketplace asset. `resource_local_to_scene` for runtime independence. |
| `JuiceBase` | `Node` | Unified base for domain nodes. Has STACK/SEQUENCER `mode` enum. Owns trigger, timing loop, Quick Overrides, chaining execution, looper, random, editor preview. |
| `JuiceControl` | `JuiceBase` | Control domain. Target = parent Control (Stack) or NodePath array (Sequencer). |
| `Juice2D` | `JuiceBase` | Node2D domain. |
| `Juice3D` | `JuiceBase` | Node3D domain. |

## Naming

- **Nodes:** `JuiceControl`, `Juice2D`, `Juice3D` — `Juice` prefix, then domain
- **Effects:** `TransformControlEffect`, `Noise2DEffect`, `Shake3DEffect`, etc.
- **Meta effects:** `[Name]JuiceEffectBase` (domain-agnostic base) + `[Name]{Control|2D|3D}JuiceEffect` domain wrappers
  - Examples: `TimeJuiceEffectBase`, `SignalEmitJuiceEffectBase`, `CallMethodJuiceEffectBase`
  - Domain wrappers are thin subclasses (3–5 lines) that satisfy the recipe whitelist type system
  - Meta effects live in `addons/Juice_V1/Meta/`
- **Recipe:** `JuiceRecipe`
- **Base:** `JuiceEffectBase`, `JuiceBase`

---

## Unified Node (STACK + SEQUENCER modes)

One node, two modes. `@export var mode: Mode` (STACK, SEQUENCER).

### STACK mode
- Target = parent node
- All unchained effects fire simultaneously on trigger
- Delta-first contribution tracking (for inter-node coordination when multiple nodes on same target)
- External-move detection (once per node, not per effect)
- Container hold pattern (Control domain only)

### SEQUENCER mode
- Targets = `Array[NodePath]`
- Stagger config (delay between targets)
- Target order (sequential, reverse, random)
- Each target gets the full recipe behavior (simultaneous + chains)
- Per-target animation state management

### Shared (both modes)
- `@export var recipe: JuiceRecipe`
- Trigger config (trigger_on, trigger_behaviour, auto_connect, retrigger_policy)
- Quick Overrides group
- Looper (loop_iterations, loop_delay)
- Random (random effect pick from recipe)
- Chaining execution (when effect completes, fire its chain_to)
- Editor preview API
- Signals: `started`, `completed`
- Start delay + generation counter for stale coroutine safety

---

## Chaining Model

- Effects can optionally `chain_to` another effect in the same recipe
- **Array order is irrelevant for execution** — chain pointers define ordering
- Effects with NO incoming chain pointer fire on trigger (simultaneously)
- Effects WITH an incoming chain pointer wait until predecessor completes
- This replaces current `next_component: NodePath`

### Example
```
Recipe: [ScaleEffect, PositionEffect, PauseEffect, VFXEffect]

On trigger:
  ScaleEffect    → fires immediately (no chain pointer)
  PositionEffect → fires immediately (no chain pointer)
                    chain_to → PauseEffect
                               chain_to → VFXEffect
```
Scale and Position fire simultaneously. Position completes → Pause → VFX.

### Nesting (cross-node)
- `TriggerStackEffect` — triggers another node in Stack mode (type-safe NodePath)
- `TriggerSequencerEffect` — triggers another node in Sequencer mode (type-safe NodePath)
- Two separate effect types for inspector type safety — NOT a generic TriggerNodeEffect

---

## Trigger Ownership

Trigger config lives on the **node**, never on effects:
- `trigger_on`, `trigger_behaviour`, `auto_connect`, `trigger_source_path`, `manual_trigger_signal`
- `retrigger_policy`

Different triggers on same target = different nodes. A Button with hover noise + press bounce = two ControlJuice nodes.

---

## JuiceRecipe

```
class_name JuiceRecipe extends Resource
@export var effects: Array[JuiceEffectBase] = []
```

- The distributable, savable creative work
- Same recipe works in both STACK and SEQUENCER modes
- Inspector: click recipe slot → expand → see effects array inline
- "Make Unique" for per-instance customization
- Runtime swap: `node.recipe = preload("res://recipes/punchy.tres")`
- `resource_local_to_scene = true` or clone at `_ready()` for runtime independence

---

## Quick Overrides

```
@export_group("Quick Overrides")
@export var use_quick_overrides: bool = false
@export var override_start_delay: float = 0.0
@export var override_duration: float = 0.3
# etc.
```

- Live on the node (instance-level), NOT on recipe
- When enabled, propagate to all effects in the recipe
- Effects still store their own values — user can tweak per-effect after

---

## Absorbed Features

| Old | New | Where |
|---|---|---|
| `LooperJuiceComp` | `loop_iterations` + `loop_delay` on node | Both modes |
| `PauseJuiceComp` | `PauseEffect` (resource) | Both modes, used in chains |
| `RandomJuiceComp` | Random option on node | Both modes (random effect pick) |
| `TimeJuiceComp` | `TimeEffect` (resource) | Both modes |

---

## Pivot

- **ALL domains use position compensation** — no direct `pivot_offset` writes
- Each effect owns its own pivot config (for creative freedom: different pivots per effect)
- This unifies pivot approach across Control/2D/3D

---

## What Stays as Nodes (NOT effects)

These are trigger sources or scene infrastructure, not visual effects:
- `Interaction2DJuiceUtility`, `Interaction3DJuiceUtility`
- `SoftTrigger2DJuiceUtility`, `SoftTrigger3DJuiceUtility`, `SoftTriggerControlJuiceUtility`
- `SignalRelayJuiceUtility`
- `TimeCoordinatorJuiceUtility`
- `CameraJuiceUtility`
- `ScreenJuiceUtility`
- `SceneActionJuiceUtility`

---

## JuiceCompBase Split

Current `JuiceCompBase` (2154 lines) splits into:

### → JuiceEffectBase (Resource)
- Duration, easing, curves config
- hold_at_peak
- Per-effect loop_count, ping_pong, loop_delay, loop_phase_offset
- crossfade_time
- `chain_to` reference (another effect in same recipe)
- `interrupt_siblings` (same-type effects)
- `debug_enabled`
- Virtuals: `_apply_effect(progress, target)`, `_on_animate_start(target)`, `_on_animate_out_complete(target)`, `_restore_to_natural(target)`, `_invalidate_base_cache()`
- Easing math

### → JuiceBase (Node)
- `@export var mode: Mode` (STACK, SEQUENCER)
- `@export var recipe: JuiceRecipe`
- Quick Overrides group
- Trigger config
- Looper config
- Random config
- `_process()` loop — ticks all active effects
- `_ready()` — target discovery, trigger connections, recipe cloning
- Auto-connect system
- Trigger handling
- Start delay + generation counter
- Chaining execution
- Delta-first tracking (Stack mode)
- External-move detection (Stack mode)
- Targets array + stagger (Sequencer mode)
- `_exit_tree()` cleanup
- `_temporarily_undo_visual()` / `_temporarily_reapply_visual()`
- Editor preview API
- Configuration warnings
- Signals

### → Domain Nodes (JuiceControl, Juice2D, Juice3D)
- Target type validation
- Domain-specific aggregation (write position/rotation/scale once per frame)
- Domain-specific external-move detection
- Container hold pattern (Control only)

---

## Complete Effect Map

### Transform (3)
TransformControlJuiceComp → `TransformControlEffect`
Transform2DJuiceComp → `Transform2DEffect`
Transform3DJuiceComp → `Transform3DEffect`

### Noise (3)
NoiseControlJuiceComp → `NoiseControlEffect`
Noise2DJuiceComp → `Noise2DEffect`
Noise3DJuiceComp → `Noise3DEffect`

### Shake (3)
ShakeControlJuiceComp → `ShakeControlEffect`
Shake2DJuiceComp → `Shake2DEffect`
Shake3DJuiceComp → `Shake3DEffect`

### Spring (3)
SpringControlJuiceComp → `SpringControlEffect`
Spring2DJuiceComp → `Spring2DEffect`
Spring3DJuiceComp → `Spring3DEffect`

### Appearance (3)
AppearanceControlJuiceComp → `AppearanceControlEffect`
Appearance2DJuiceComp → `Appearance2DEffect`
Appearance3DJuiceComp → `Appearance3DEffect`

### Progress (4)
ProgressControlJuiceComp → `ProgressControlEffect`
Progress2DJuiceComp → `Progress2DEffect`
Progress3DJuiceComp → `Progress3DEffect`
ProgressPropertyJuiceComp → `ProgressPropertyEffect`

### Outline (3)
OutlineControlJuiceComp → `OutlineControlEffect`
Outline2DJuiceComp → `Outline2DEffect`
Outline3DJuiceComp → `Outline3DEffect`

### SquashStretch (3)
SquashStretchControlJuiceComp → `SquashStretchControlEffect`
SquashStretch2DJuiceComp → `SquashStretch2DEffect`
SquashStretch3DJuiceComp → `SquashStretch3DEffect`

### Camera (2)
Camera2DJuiceComp → `Camera2DEffect`
Camera3DJuiceComp → `Camera3DEffect`

### Screen (2)
ScreenMotionJuiceComp → `ScreenMotionEffect`
ScreenOverlayJuiceComp → `ScreenOverlayEffect`

### Property (4)
NoisePropertyJuiceComp → `NoisePropertyEffect`
ShakePropertyJuiceComp → `ShakePropertyEffect`
SpringPropertyJuiceComp → `SpringPropertyEffect`
ShaderPropertyJuiceComp → `ShaderPropertyEffect`

### VFX / Visibility (3)
VFXJuiceComp → `VFXEffect`
TrailJuiceComp → `TrailEffect`
VisibilityJuiceComp → `VisibilityEffect`

### Meta (4)
PauseJuiceComp → `PauseEffect`
TimeJuiceComp → `TimeEffect`
NEW → `TriggerStackEffect`
NEW → `TriggerSequencerEffect`

### Utility-comps that become effects (2)
SignalEmitJuiceUtility → `SignalEmitEffect`
CallMethodJuiceUtility → `CallMethodEffect`

**Total: ~40 effect files**

---

## Effect Migration Recipe (mechanical, per comp)

1. `extends JuiceCompBase` → `extends JuiceEffectBase`
2. `class_name XxxJuiceComp` → `class_name XxxEffect`
3. **Keep:** effect-specific @export vars, enums, _apply_effect() math, internal state
4. **Keep:** _on_animate_start() — change signature to receive target
5. **Strip:** _ready(), _process(), _exit_tree(), set_process()
6. **Strip:** _target_node discovery (target passed by node)
7. **Strip:** delta-first tracking (_my_*_contribution, _last_written_*) — node handles
8. **Strip:** _temporarily_undo_visual(), _temporarily_reapply_visual() — node handles
9. **Strip:** _restore_to_natural() boilerplate — node handles cleanup
10. **Strip:** recipe/sequencer contract — node handles
11. **Strip:** _get_configuration_warnings() boilerplate — node handles target validation
12. **Strip:** base value capture boilerplate — node provides base values
13. **Strip:** pivot handling boilerplate (resize, resolution) — unify via position compensation
14. Replace `_target_node as Control` → target parameter
15. Replace `get_parent()` → not needed

---

## Implementation Phases

**Phase 0:** `.gdignore` + copy to `Juice_V1/` + git commit

**Phase 1:** Create JuiceEffectBase, JuiceRecipe, JuiceBase, JuiceControl/Juice2D/Juice3D. Test: empty node on Button, inspector works.

**Phase 2:** Port ONE simple comp (SquashStretchControl). Prove end-to-end pipeline.

**Phase 3:** Port Transform (all 3 domains). Prove: stacking, pivot, delta-first, external-move.

**Phase 4:** Mechanical port of all remaining ~35 effects.

**Phase 5:** Sequencer mode + meta effects (Pause, TriggerStack, TriggerSequencer, Time). Looper + Random integration.

**Phase 6:** Wire utilities + editor preview.

**Phase 7:** Quick Overrides, config warnings, debug, test all 3 domains.

---

## Anti-Drift Rules

1. **Every current comp becomes an effect.** No skipping. No deferring.
2. **Effects are Resources.** No _ready(), _process(), set_process(). Pure data + math + state.
3. **Trigger belongs to the node**, never to effects.
4. **chain_to is per-effect**, pointing to another effect in the same recipe. NOT array-order execution.
5. **Unchained effects fire simultaneously.** Chained effects wait for predecessor.
6. **Pivot = position compensation everywhere.** No direct pivot_offset writes.
7. **JuiceRecipe is the distributable unit.** Works in both STACK and SEQUENCER modes.
8. **Quick Overrides are instance-level** (on node), not on recipe.
9. **The original addon in `addons/juice/` is the feature reference.** When uncertain, read the original.
10. **TriggerStackEffect and TriggerSequencerEffect are SEPARATE types.** Not a generic TriggerNodeEffect.
11. **Random is an option on BOTH modes**, not Sequencer-only.
12. **Pause is an effect in BOTH modes**, not Sequencer-only.
