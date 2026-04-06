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
