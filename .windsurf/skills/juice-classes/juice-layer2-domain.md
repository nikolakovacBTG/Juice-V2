# Layer 2: Domain Nodes

**Layer 2** consists of the domain-specific subclasses of `JuiceBase`: `JuiceControl`, `Juice2D`, and `Juice3D`. These are Nodes.

## Single Write Authority
Domain nodes are the **only** classes allowed to write to the physical properties of the target (e.g., `position`, `rotation`, `scale`). L3 effects calculate deltas, but L2 applies them.

## Write Coordination (The STACK Fix)
- **Problem**: Multiple effects writing `base + sum(deltas)` directly corrupted base values.
- **Solution**: L2 tracks contribution per effect, subtracts old contribution, adds new contribution.
- **Once-Per-Frame**: L2 aggregates all active deltas and writes `target.property = expected + new_contribution` exactly once per frame.

## Domain Responsibilities
- **External Move Detection**: L2 detects if the target moved externally by comparing current value vs `_expected_after_my_write` before applying new deltas.
- **Visual Reapplication**: L2 implements `_temporarily_undo_visual()` and `_temporarily_reapply_visual()` to keep editor saves clean.
- **Container Hold (Control Only)**: `JuiceControl` re-applies positions every frame to beat deferred `_sort_children()`.
