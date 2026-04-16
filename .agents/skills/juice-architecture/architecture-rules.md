# Juice V1 Architecture Rules (Condensed)

> Source of truth: `Documentation/JuiceStack_Design.md`
> This file is a quick-reference. When in doubt, re-read the full design doc.

---

## Rule 1: Effects Are Pure Delta Calculators

- Effects compute a **delta** (offset from natural state) at a given progress
- Effects **NEVER write** to the target node — the domain node writes once per frame
- Effects **NEVER track** `_my_*_contribution`, `_last_written_*`, or `_base_*` at the node level — effects track their own base values per-effect
- Effects **NEVER detect** external moves — the domain node does that
- Effects store deltas in `_pos_delta`, `_rot_delta`, `_scale_delta` (inherited from domain TransformEffect)
- Non-transform effects (Appearance, VFX, etc.) extend the domain EffectBase directly

## Rule 2: Domain Nodes Own Write Coordination

Each domain node (`JuiceControl`, `Juice2D`, `Juice3D`) implements:
1. **Base value capture** — stored in `JuiceLedger`
2. **External-move detection** — `_pre_tick()` via `_expected_*` tracking
3. **Delta registration** — `JuiceLedger.register_delta()` after effects tick
4. **Write-once-per-frame** — `JuiceLedger.flush(target)` — NOT direct property assignment
5. **`_temporarily_undo/reapply_visual()`** — `JuiceLedger.flush(target, props)` with filter

Full ledger API: see `l2-domain.md` or read `JuiceLedger.gd` directly.

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
| Domain transform base | `Juice[Domain]TransformEffect` | `JuiceControlTransformEffect` |
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

## Rule 11: Generic Protocols at Effect↔Node Boundaries

When effects need to report data to domain nodes (or vice versa), use **generic protocols**, never hardcoded channel reads.

**The pattern:** Each domain effect base implements a protocol method returning a Dictionary keyed by Godot property names. The node consumes it generically via `target.get(key)` / `target.set(key, val)`.

**Existing protocol: Sequencer contributions**
- Effects implement `_get_seq_contribution() -> Dictionary` (e.g., `{"position": Vector2, "rotation": float, "scale": Vector2}`)
- `JuiceBase._seq_post_tick_write_target()` aggregates all effects' dicts and applies via `target.get/set` — one implementation, zero per-domain overrides
- `JuiceBase._seq_restore_target_natural()` subtracts stored contributions generically — prevents warmup from polluting base re-capture
- `JuiceBase._seq_zero_for(val)` returns the zero value for any Variant type

**How to add a new effect type to Sequencer RECIPE mode:**
1. Override `_get_seq_contribution()` in your effect class
2. Return property names as keys, additive deltas as values
3. Done — no domain node changes needed

**The litmus test:** "Would adding a new effect type require modifying the aggregation/write code?" If yes, the protocol is not generic enough.

## Rule 13: Meta Effects Pattern

Meta effects (Time, SignalEmit, CallMethod, etc.) are **domain-agnostic** — they don't write to the target node's transform/appearance. They still follow the `JuiceEffectBase` contract:

- Extend `JuiceEffectBase` directly (no domain-specific base needed)
- Named `[Name]JuiceEffectBase` — the domain suffix goes on thin wrapper subclasses
- Domain wrappers (`[Name]{Control|2D|3D}JuiceEffect`) are 3–5 line subclasses whose only role is satisfying the recipe whitelist type system
- Live in `addons/Juice_V1/Meta/`
- `_apply_effect()` is a no-op or performs the meta action (time scale, signal emit, method call)
- For effects that trigger at specific lifecycle points (start/complete), override `_on_animate_start()` and `_on_animate_out_complete()`
- For smooth transitions (e.g. time scale lerp), override `tick()` and correct engine-scaled delta before calling `super.tick()`

**Composing meta effects inside Nodes:** When a Node utility needs time manipulation (e.g. `SceneActionJuiceUtility`), create a `TimeJuiceEffectBase` instance internally — do NOT duplicate the time-coordination logic.

## Rule 12: No Band-Aid Fixes

When a fix touches a protocol boundary (how effects report data, how nodes aggregate/write):
- Never hardcode specific properties or types
- Never copy-paste logic into all 3 domain nodes
- If you recognize an architectural choice (narrow vs generic), STOP and present both options to the user
- The generic approach is almost always correct at protocol boundaries

## Rule 14: Domain Transform Base Hierarchy

```
JuiceEffectBase
  └── Juice[Domain]EffectBase
        └── Juice[Domain]TransformEffect   ← enums, config, property list, delta vars
              └── Transform[Domain]JuiceEffect  ← typed vars + domain-specific math only
```

- Domain bases own: enums, shared exports, `_get_property_list()`, guard flags, delta vars
- Concrete effects own: typed vars (`Vector2`/`Vector3`), typed casts, typed resolvers
- Do NOT add a cross-domain base — GDScript has no generics; Vector2/Vector3 split makes it worse

## Rule 15: JuiceTriggerRouter for Signal Wiring

- MANUAL trigger wiring → `JuiceTriggerRouter.wire_manual(source, sig_name, on_momentary, on_progress)`
- Visibility trigger → `JuiceTriggerRouter.connect_visibility(source, on_changed)`
- Signal callbacks (`_on_trigger_momentary` etc.) stay on JuiceBase — they are `self` methods
- Domain-specific connections stay in each domain's `_auto_connect_domain_signals()` override
