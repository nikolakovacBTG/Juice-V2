# Juice V1 Architecture Rules (Condensed)

> Source of truth: `Documentation/JuiceStack_Design.md`
> This file is a quick-reference. When in doubt, re-read the full design doc.

---

## Rule 1: Effects Are Pure Delta Calculators

- Effects compute a **delta** (offset from natural state) at a given progress
- Effects **NEVER write** to the target node — the domain node writes once per frame
- Effects **NEVER track** `_my_*_contribution`, `_last_written_*`, or `_base_*` at the node level — effects track their own base values per-effect
- Effects **NEVER detect** external moves — the domain node does that
- Effects store deltas in `_pos_delta`, `_rot_delta`, `_scale_delta` (inherited from domain EffectBase)

## Rule 2: Domain Nodes Own Write Coordination

Each domain node (`JuiceControl`, `Juice2D`, `Juice3D`) implements:
1. **Base value capture** — natural pos/rot/scale before any effects
2. **External-move detection** — once per frame, pre-tick
3. **Delta aggregation** — sum all active effects' deltas per channel
4. **Write-once-per-frame** — `target.property = base + sum(deltas)`
5. **`_temporarily_undo/reapply_visual()`** — for editor save pipeline

## Rule 3: All Three Domains — Always

- When implementing ANY feature, implement in **all 3 domain nodes** before moving on
- When porting ANY effect, port **all 3 domain variants** in one batch
- If a feature exists in one domain, its absence in another is a **bug**
- Only allowed domain-specific difference: property types (Vector2 vs Vector3), Container hold (Control only), pivot compensation math

## Rule 4: Effects Are Resources

- `extends JuiceEffectBase` (which extends Resource)
- No `_ready()`, `_process()`, `_exit_tree()`, `set_process()`
- Target is passed as parameter, never discovered
- `_host_node` is set by the domain node at ready time
- Use `_get_property_list()` / `_set()` / `_get()` for conditional exports (NOT `@export`)

## Rule 5: Trigger Belongs to the Node

- `trigger_on`, `trigger_behaviour`, `auto_connect`, `retrigger_policy` — all on JuiceBase
- Different triggers on same target = different nodes
- Effects never handle triggers directly

## Rule 6: Chaining Model

- `chain_to` points to another effect in the same recipe (Resource reference)
- Array order is irrelevant — chain pointers define execution order
- Effects with NO incoming chain pointer fire simultaneously on trigger
- Effects WITH an incoming chain pointer wait until predecessor completes

## Rule 7: No Feature Cuts

- Every V0 comp becomes a V1 effect. No skipping. No deferring.
- Every V0 property must exist in V1. If unsure where it belongs, ASK.
- Never rename properties/enums/signals without explicit user approval.
- Never invent new names for existing concepts.

## Rule 8: Naming

| Category | Pattern | Example |
|----------|---------|---------|
| Domain nodes | `Juice[Domain]` | `JuiceControl`, `Juice2D`, `Juice3D` |
| Domain effect base | `Juice[Domain]EffectBase` | `JuiceControlEffectBase` |
| Domain recipe | `Juice[Domain]Recipe` | `JuiceControlRecipe` |
| Concrete effects | `[Effect][Domain]JuiceEffect` | `TransformControlJuiceEffect`, `Shake2DJuiceEffect` |

## Rule 9: Script Section Ordering

1. Header comment
2. Signals
3. Enums
4. Configuration (vars shown via `_get_property_list`)
5. Conditional export system (`_get_property_list`, `_set`, `_get`)
6. Internal state
7. Lifecycle / Virtual method overrides
8. Public API
9. Core logic (effect-specific math)
10. Helpers
11. Configuration warnings

## Rule 10: Anti-Drift Checklist

Before implementing, verify:
- [ ] Does this match `JuiceStack_Design.md`?
- [ ] Does V0 have this feature? Where?
- [ ] Is V1 improving on V0, or just copying? (Document the improvement)
- [ ] Are all 3 domains covered?
- [ ] Is there a test for this?
