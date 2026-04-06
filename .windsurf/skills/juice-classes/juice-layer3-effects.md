# Layer 3: Concrete Effects

**Layer 3** consists of the effect subclasses of `JuiceEffectBase` (e.g., `Transform2DJuiceEffect`, `SquashStretchControlJuiceEffect`, `Noise3DJuiceEffect`). These are Resources.

## The Rule of Pure Deltas

L3 effects are "Pure Delta Calculators." Their only job is to provide an offset from the natural state based on a `progress` float (0.0 to 1.0).

**Strict Prohibitions (Never do these in an L3 effect):**
1. Never write to the physical properties of the `target` node (`position`, `rotation`, `scale`). That's L2's job.
2. Never track `_my_*_contribution` or `_last_written_*`. L2 tracks contributions.
3. Never detect external moves. L2 does this.
4. Never implement `_temporarily_undo_visual()` or `_temporarily_reapply_visual()`. L2 handles editor saves.

## What L3 Actually Does
1. Defines the Inspector GUI layout (using `@universal-layout-pattern`).
2. Configures domain-specific settings (`amplitude`, `squash_amount`).
3. Captures references (e.g., caching the `TARGET` node's current position) at animation start (`_on_animate_start`).
4. Overrides `_get_seq_contribution()` to return a dictionary of calculated deltas based on the `progress` float. For example, `{ "position": Vector2(10, 0) }`.
