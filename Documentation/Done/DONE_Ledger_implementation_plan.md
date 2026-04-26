# Metadata Ledger — Write Coordination Architecture

## Background & Problem Statement

### The Root Problem: Nested Packed Scenes

Godot allows — and Juice users will naturally use — nested packed scene composition. The canonical failure case:

- **Scene A ("JuicyButton" prefab):** A `Button` node with a `JuiceControl` child.
  Effects: hover scale (ON_MOUSE_ENTERED), fly-in (ON_READY).
- **Scene B ("Menu"):** Instantiates 3× JuicyButton. Has its own `JuiceControl`
  Sequencer that staggers those 3 button instances onto the screen with a delay.
- **Scene C and deeper:** Nothing stops further nesting.

Each `Button` in Scene B is now targeted by **two independent Juice write sources**:
1. The `JuiceControl` baked into Scene A (the prefab's own animation)
2. The Sequencer in Scene B (the menu-level stagger)

These two nodes are in **different packed scenes**. They do not share a parent in
the same scene tree level. They have no awareness of each other at author time.

### Why The Old System Fails Here

The pre-ledger write model ("Isolated Relative Subtraction") stored each Juice
node's contribution privately and corrected on write:

```
natural = current_position - my_last_contribution
write   = natural + new_delta
```

This breaks in the nested-prefab scenario in three ways:

1. **Base pollution on startup.** Scene A's `JuiceControl` captures `base_position`
   at its own `_ready()`. If ON_READY fires immediately (fly-in), the Button moves
   before Scene B's Sequencer even initializes. The Sequencer then sees a displaced
   position as its "natural" baseline.

2. **`_temporarily_undo_visual()` is scoped to one node.** When either source wants
   to capture a clean From/To snapshot (calling `_on_animate_start` on effects), it
   temporarily undoes *its own* contribution — but the other source's delta is still
   applied to the target. Effects see a polluted property value and bake a wrong From.

3. **Write order is non-deterministic.** Two independent Juice nodes both write
   `ctrl.position = natural + delta` on the same frame. Whichever runs second wins
   and silently clobbers the other's contribution, causing jitter or teleportation.

> **The VBoxContainer jolt** (original observed artifact) is a special case of
> problem (1): when `start_delay > 0`, the Sequencer holds at From state. Each frame
> the Container re-sorts snap the Button's position, the Sequencer's external-displacement
> detection misinterprets it as a game-authored move and shifts the base, producing an
> ever-growing offset that launches buttons "into deep space" on release.

### Why This Is The Right Problem To Solve

A Juice addon that cannot compose across packed scene boundaries is not a real
composable system. Single-scene stacking already works reasonably. The nested prefab
case is the litmus test. Solve it here and the VBoxContainer case, the same-scene
sibling case, and Sequencer + STACK coexistence all improve as corollaries.

---

## Implementation Status

> [!IMPORTANT]
> The Metadata Ledger **already exists and is partially deployed.**
> `JuiceBase.gd` contains the full static helper API. `JuiceControl` already uses it
> for transform properties. `Juice2D` and `Juice3D` may or may not — verify before planning further work.
>
> This plan describes the **remaining gaps**, not a greenfield implementation.

### Already Implemented ✅
- `LEDGER_KEY` metadata stored directly on the target node (`Node.set_meta`)
- `_ledger_ensure_initialized(target, props)` — creates ledger on first contact
- `_ledger_update_external_displacement(target, props)` — detects Container snaps vs true drift
- `_ledger_set_delta(target, source, prop, delta)` — keyed by `source.get_instance_id()`
- `_ledger_get_total(target, prop, zero)` — sums all source deltas
- `_ledger_get_base_value(target, prop, fallback)` — reads the stored natural baseline
- `_ledger_cleanup_source(target, source, permanently)` — removes a source's deltas on exit
- `JuiceControl._post_tick_write()` — uses ledger for transform write
- `JuiceControl._temporarily_undo_visual()` — strips own slice from ledger, writes remainder

### Remaining Gaps ❌

#### Gap 1: Effect From/To capture still reads `target.get(prop)`

Every effect's `_on_animate_start()` snapshots its From and To values by calling
`target.get("position")` (or equivalent). This is the source of problem (2) above.

When Juice source A calls `_temporarily_undo_visual()` and then fires effects, those
effects see `target.position` — which still includes source B's active delta. The
ledger's `base["position"]` is the true natural state, but effects never consult it.

**Fix required:** Effects must be provided the ledger base as the canonical natural
value. Two options:
- Pass `ledger_base` into `_on_animate_start()` as an explicit argument, OR
- Have the domain node temporarily call `_temporarily_undo_visual()` on **all**
  Juice sources on this target, not just self (requires discovering all sources).

Option A (pass ledger base explicitly) is simpler and doesn't require cross-source
discovery. It is the preferred approach.

#### Gap 2: Sequencer still maintains `_seq_target_contributions` (redundant)

The Sequencer's RECIPE mode has its own per-target contribution dict
(`_seq_target_contributions`, `_seq_expected_after_write`) that duplicates part of
what the ledger already provides. This is dead weight and a source of divergence.

**Fix required:** Delete these dicts. Rewrite `_seq_post_tick_write_target()` to
push deltas into the target's ledger and read total back, identical to how
`JuiceControl._post_tick_write()` works.

#### Gap 3: Juice2D and Juice3D audit

Verify whether `Juice2D` and `Juice3D` have been migrated to use the ledger or are
still on the old isolated relative subtraction model. If the latter, port them
following the `JuiceControl` pattern.

---

## Proposed Changes

### Core Infrastructure

#### [MODIFY] [JuiceBase.gd](file:///d:/Godot_projekti/juice-demo/addons/Juice_V1/Base%20Classes/JuiceBase.gd)

- **Sequencer state cleanup:** Delete `_seq_target_contributions` and
  `_seq_expected_after_write` from internal state.
- **`_seq_post_tick_write_target()` rewrite:** Push dynamic property deltas into the
  target's ledger via `_ledger_set_delta`, read total via `_ledger_get_total`, write
  absolute: `target.set(prop, ledger_base + total_delta)`.
- **Remove sequencer memory leak risk:** The dictionaries deleted above had their own
  cleanup paths in `_seq_stop()`. Ensure ledger cleanup calls replace them.

#### [MODIFY] JuiceEffectBase (all relevant subclasses)

- **`_on_animate_start(target, host, ledger_base: Dictionary = {})`:** Extend signature
  (or add a parallel virtual) so the domain node can pass the ledger's `base` dict
  as the authoritative natural snapshot. Effects use this for From capture instead
  of reading `target.get(prop)` directly.
- Effects that don't receive a ledger base fall back to current behavior (no regression
  for non-ledger targets).

### Domain Node Implementation

#### [MODIFY] JuiceControl.gd

- **`_start_effects()` (via JuiceBase):** After `_temporarily_undo_visual()`, extract
  `ledger["base"]` and pass it into `effect.start(target, play_in, is_root, host,
  ledger_base)` so effects bake the correct From value.
- No other changes — ledger write coordination is already correct here.

#### [MODIFY] Juice2D.gd / Juice3D.gd

- Audit and port to ledger write coordination if not already done.
- Same `_capture_base_values`, `_pre_tick`, `_post_tick_write`, `_temporarily_undo_visual`,
  `_temporarily_reapply_visual` pattern as `JuiceControl`.

---

## Open Questions

> [!NOTE]
> Which gap to tackle first?
>
> **Proposed order:**
> 1. Gap 2 (delete sequencer dicts, port to ledger) — removes active technical debt and
>    immediately stabilizes the VBoxContainer jolt artifact
> 2. Gap 3 (audit Juice2D/Juice3D) — low risk, parallel to Gap 1 work
> 3. Gap 1 (effect From/To via ledger base) — most invasive, requires touching
>    JuiceEffectBase virtual signatures; do last when the ledger wiring is battle-tested

> [!NOTE]
> Branch strategy: all of this work should be done on `experiment/metadata-ledger`
> and merged only after the verification plan below passes.

---

## Verification Plan

### Automated Tests

- Run the full `/test` suite (Unit + Realistic) after each gap is closed.
- Pay particular attention to: TransformControl, TransformControl stacking,
  Sequencer stagger, and any test involving `_temporarily_undo_visual`.

### Manual Verification — Nested Packed Scene Test (Primary)

Create a minimal test scene:
1. **JuicyButton prefab:** `Button` + `JuiceControl` (ON_READY fly-in, `start_delay=0`)
2. **Menu scene:** Instantiate 3× JuicyButton + `JuiceControl Sequencer` targeting siblings,
   `STAGGER_FORWARD`, `seq_stagger_delay=0.15`, `start_delay=0.3`
3. Play the Menu scene

**Pass Criteria:**
- Buttons arrive at their Container-assigned positions without jolting right or
  drifting left during the `start_delay` window
- The stagger fires cleanly: button 1 → 2 → 3 in sequence with correct delay
- Hover effects (from the prefab) work correctly during and after the stagger
- `start_delay` can be changed to any value without causing position explosions

### Manual Verification — VBoxContainer Jolt (Secondary)

Play `Main_Demo_Scene`, observe the 4 buttons inside VBoxContainer.

**Pass Criteria:**
- Initial launch plays the SEQUENCER stagger cleanly with no right-jolt anticipation
- No teleportation or leftward drift during delay window
- Changing `seq_stagger_delay` fractionally does not cause positional explosions
