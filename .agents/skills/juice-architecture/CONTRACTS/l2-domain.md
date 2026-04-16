# L2 Domain Contracts

## Write Coordination (JuiceLedger)

All domain nodes write via `JuiceLedger` — never via direct property assignment.

- `JuiceLedger.ensure(target)` — initialises ledger entry on first contact
- `JuiceLedger.set_base(target, prop, val)` — records the target's natural (pre-effect) value
- `JuiceLedger.get_base(target, prop, fallback)` — reads natural value safely
- `JuiceLedger.register_delta(target, source_id, prop, val)` — registers one Juice node's contribution
- `JuiceLedger.flush(target, props=[])` — writes `base + Σdeltas` to target; props filter restricts which properties are flushed (used for selective undo/reapply)
- `JuiceLedger.cleanup_source(target, source_id)` — removes a Juice node's contribution slice (called on stop)

**Old pattern (DO NOT USE):** `target.position = base_pos + total_pos_delta`
**New pattern:** `JuiceLedger.flush(target)` — ledger is the single write authority

## Sibling Stacking

- Multiple JuiceBase nodes on same target each hold a `source_id` (their `instance_id`)
- Ledger aggregates contributions from all active sources keyed by `source_id`
- Tree order = processing order; ledger write is still once-per-frame (final flush wins)

## Domain Separation

- Control: Container hold pattern (re-apply every frame to beat deferred `_sort_children`)
- 2D/3D: Vector2/Vector3 math differences
- External move detection in all domains (`_expected_*` tracking in `_pre_tick()`)

## Protected Invariants (DO NOT REMOVE)

### Virtual Stubs in JuiceBase
`JuiceBase` MUST define these virtual methods (overridden by domain nodes):
`_capture_base_values()`, `_pre_tick()`, `_post_tick_write()`, `_temporarily_undo_visual()`, `_temporarily_reapply_visual()`
Without these stubs, domain overrides are silently unreachable and the system fails.

### JIT Sync Before Capture
`_start_effects()` MUST call `_pre_tick()` immediately before `_temporarily_undo_visual()`.
This detects layout shifts (e.g. Container re-sorts) that occurred while the node was idle (`set_process(false)`).
Without this, the first animation after an idle period captures stale base values → teleportation.

### External-Move Tracking (`_expected_*`)
Each domain node tracks `_expected_position/rotation/scale` — the values it last wrote or observed.
In `_pre_tick()`, if `target.property != _expected_property`, the difference is absorbed into the ledger base and `_expected_*` is updated.
This pattern MUST exist in all 3 domain nodes. Removing it breaks stacking after external moves.

### flush() Selective Filter
`JuiceLedger.flush(target, props)` with a non-empty `props` array flushes ONLY those properties.
`_temporarily_undo_visual()` uses this to flush only transform props (not modulate).
`_post_tick_write()` uses bare `flush(target)` to flush everything.
Mixing these up causes visual glitches — check which call site you're modifying.
