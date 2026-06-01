# Property Effect Family — V2.1 Ledger Refactor Plan

**Status:** Deferred to V2.1 (shipped as Direct-Write Exception in V2.0)  
**Author:** Juice V2 Architecture  
**Ref:** `Documentation/Future/Juice_V1.1_Features.md` Item 4

---

## Problem Statement

The Property Effect family (`InterpolateProperty*`, `NoiseProperty*`, `ShakeProperty*`,
`ProgressProperty*`) currently operates as an **approved Direct-Write Exception** to the
Juice V2 architecture. Each effect calls `target_node.set_indexed(property_path, value)`
directly in `_apply_effect()`, bypassing the JuiceLedger entirely.

This was a deliberate V2.0 pragmatic decision because:
1. The Ledger aggregates typed channels (position, rotation, scale, modulate) —
   arbitrary user-picked properties have no pre-defined delta type.
2. Implementing generic Ledger channels would have required significant L2 domain changes
   beyond the V2.0 scope.

**The consequence:** If two Property Effects in the same Recipe target the same
`property_path` simultaneously, the last writer wins. No additive blending occurs.
This is the V0 conflict problem that V2's Ledger was designed to solve — and the
Property family currently doesn't benefit from it.

---

## Architectural Goal

Make every Property Effect a **pure delta calculator** in compliance with the L3 Contract:
- Effects compute a delta (offset from natural state).
- Effects NEVER write to the target node.
- The domain node (JuiceControl / Juice2D / Juice3D) aggregates deltas per property
  and writes once per frame via `JuiceLedger.flush()`.

---

## What Needs to Change

### 1. JuiceLedger — Generic Property Channel

**File:** `addons/Juice_V1/Base Classes/JuiceLedger.gd`

The Ledger currently keys contributions by a fixed set of typed channels
(`position`, `rotation`, `scale`, `modulate`, `self_modulate`).

Required addition:
- A new `_property_deltas` dictionary keyed by `{ target_node, property_path }`.
- `register_property_delta(target: Node, source_id: int, path: String, delta: Variant)`.
- `flush_properties(target: Node)` — for each registered path, reads base + sums all
  deltas using Variant-aware addition (float + float, Vector2 + Vector2, Color + Color,
  etc.), then writes once via `target.set_indexed(path, result)`.
- `cleanup_property_source(target: Node, source_id: int)` — removes contributions for a
  source that has stopped.
- `get_property_base(target: Node, path: String, fallback: Variant)` — reads the natural
  value captured before Juice applied any effects this frame.

**Complexity:** Medium. The hardest part is Variant-aware addition for all 19 supported
types. Discrete types (bool, String, NodePath) cannot be "added" — they are threshold-flip
and must be treated as "last registration wins" with a priority order.

**Constraint (from L3 contract):** Discrete types (bool, String, StringName, NodePath,
Object) do not support additive blending. The Ledger should treat them as "highest-priority
source wins" using the source registration order, consistent with the existing channel
priority model.

---

### 2. PropertyJuiceEffectBase — Remove Direct Write

**File:** `addons/Juice_V1/Meta/PropertyJuiceEffectBase.gd`

Current `_apply_effect()`:
```gdscript
target_node.set_indexed(property_path, computed_value)
```

Required change:
```gdscript
# Compute delta from base.
var base: Variant = JuiceLedger.get_property_base(target_node, property_path, _base_value)
var delta: Variant = _compute_delta(computed_value, base)
JuiceLedger.register_property_delta(target_node, get_instance_id(), property_path, delta)
```

Where `_compute_delta(computed, base)` = `computed - base` for continuous types,
or a priority-flag for discrete types.

**Important:** `_apply_effect()` receives `progress` and `target` — the domain node
is NOT passed. The Ledger is a static singleton, so no parameter changes are needed.

---

### 3. Domain Nodes — flush_properties() Call

**Files:**
- `addons/Juice_V1/Base Classes/Juice2D.gd`
- `addons/Juice_V1/Base Classes/JuiceControl.gd`
- `addons/Juice_V1/Base Classes/Juice3D.gd`

In `_post_tick_write()`, AFTER the existing `JuiceLedger.flush(target)` for transform/
appearance channels, add:

```gdscript
JuiceLedger.flush_properties(target)
```

This writes all registered property deltas for this target in one pass.

**Constraint from L2 contract:**
- `_temporarily_undo_visual()` must also undo property writes.
- `_temporarily_reapply_visual()` must reapply them.
- Both should call `JuiceLedger.flush_properties(target)` with the same selective filter.

---

### 4. PropertyTarget — Base Capture for Ledger

**File:** `addons/Juice_V1/Meta/PropertyTarget.gd`

`capture_base()` already captures `_base_value` via `get_indexed()`. This is correct.

Required addition: at capture time, also register the base with the Ledger:
```gdscript
JuiceLedger.register_property_base(target_node, property_path, _base_value)
```

So the Ledger has the natural value to compute deltas against, consistent with how
it handles position/rotation/scale base capture in domain nodes.

---

### 5. _temporarily_undo / _temporarily_reapply — Property Support

All three domain nodes implement `_temporarily_undo_visual()` and
`_temporarily_reapply_visual()` to enable correct `.tscn` saves while Juice effects
are active (effects are undone, scene is saved, effects are reapplied).

These methods currently only handle transform/appearance channels. They must also
call `JuiceLedger.flush_properties(target)` with the appropriate undo/redo state.

---

## Conflict Resolution Model

With Ledger registration, two Property Effects on the same path in the same Recipe
are no longer a silent conflict — they stack additively (for continuous types) or
compete by priority (for discrete types).

**Additive stacking example:**
- Effect A registers `delta = +10.0` on `energy`
- Effect B registers `delta = +5.0` on `energy`
- Ledger flush writes: `base + 10 + 5 = natural_energy + 15`

This mirrors how two TransformControlJuiceEffects stacking on `position` already works.

**Configuration Warning (still needed):**
Stacking two InterpolateProperty effects on the same path should still emit a yellow
inspector warning explaining that stacking is intentional (not a mistake), so new
users aren't confused. This is NOT a conflict — it's expected additive behavior.

---

## Implementation Order

Follow the V2 Build Order contract:

1. `JuiceLedger.gd` — add generic property channel API
2. `PropertyJuiceEffectBase.gd` — remove direct write, register delta
3. All 3 domain nodes simultaneously — add `flush_properties()` call
4. `PropertyTarget.gd` — add base registration at capture time
5. All 3 domain nodes — update `_temporarily_undo/reapply_visual()`
6. Write/update tests in `TestRealWorldPropertyInterpolate.gd` covering stacking

**Rule:** Steps 3 and 5 must be done for ALL THREE domains before moving to step 4.
Partial domain coverage is a bug.

---

## Test Coverage Required Before Shipping

- `test_two_interpolate_effects_same_property_stack_additively`
- `test_interpolate_plus_noise_same_property_stack_additively`
- `test_property_effect_stopped_removes_ledger_contribution`
- `test_property_base_restored_after_all_effects_stop`
- `test_discrete_property_two_effects_priority_order`

These tests MUST PASS with the new architecture. Claims of completion require citing
test names and PASS results — no exceptions per `@verify-claims` workflow.

---

## Approved Direct-Write Exception Status After Refactor

Once this refactor is complete, the `ProgressPropertyJuiceEffectBase` entry in the
L3 contract Approved Direct-Write Exceptions list must be **removed**. All Property
family effects will be fully Ledger-compliant delta calculators.
