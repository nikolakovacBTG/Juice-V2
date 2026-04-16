# L2 Domain Contracts

## Write Coordination
- All writes go through `JuiceLedger.flush(target)` — NEVER direct property assignment
- `JuiceLedger.register_delta(target, source_id, prop, val)` — register one node's contribution
- `JuiceLedger.get_base(target, prop, fallback)` — read natural state
- `JuiceLedger.flush(target, props=[])` — write `base + Σdeltas`; props filter = selective flush
- `JuiceLedger.cleanup_source(target, source_id)` — remove contributions on stop
- Full API: read `JuiceLedger.gd` directly

## Sibling Stacking
- Each JuiceBase node has a unique `source_id` (instance_id); ledger keys contributions by it
- Tree order = processing order; single flush per frame

## Domain Separation
- Control: Container hold pattern (flush every frame to beat deferred `_sort_children`)
- 2D/3D: Vector2/Vector3 math differences
- External move detection in all domains (`_expected_*` tracking in `_pre_tick()`)

## Protected Invariants (DO NOT REMOVE)

### Virtual Stubs in JuiceBase
`_capture_base_values()`, `_pre_tick()`, `_post_tick_write()`, `_temporarily_undo_visual()`, `_temporarily_reapply_visual()` MUST have stubs in `JuiceBase`. Without them, domain overrides are silently dead.

### JIT Sync Before Capture
`_start_effects()` MUST call `_pre_tick()` before `_temporarily_undo_visual()`. Detects Container re-sorts while idle — skipping this causes teleportation on first trigger after idle.

### External-Move Tracking
`_expected_*` vars in domain nodes detect external (non-Juice) property changes in `_pre_tick()`. MUST exist in all 3 domains.

### flush() Selective Filter
`_temporarily_undo_visual()` → `flush(target, [pos, rot, scale])` (transform only).
`_post_tick_write()` → `flush(target)` (everything). Mixing causes visual glitches.
