# L2 Domain Contracts

## Write Coordination
- Base value capture before effects
- External move detection (pre-tick)
- Delta aggregation per channel
- Write-once-per-frame: `target.property = base + sum(deltas)`

## Sibling Stacking
- Multiple nodes on same target
- Contribution tracking prevents overwrites
- Tree order = processing order

## Domain Separation
- Control: Container hold pattern
- 2D/3D: Vector2/Vector3 math differences
- External move detection in all domains

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
In `_pre_tick()`, if `target.property != _expected_property`, the difference is absorbed into `_base_*` and `_expected_*` is updated.
This pattern MUST exist in all 3 domain nodes. Removing it breaks stacking after external moves.
