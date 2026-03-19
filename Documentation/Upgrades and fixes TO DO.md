# Upgrades and Fixes TO DO

> Active upgrade and fix plans for the Juice Demo project.
> Completed designs are moved to `Documentation/Done/`.

---

## Standardize Top-Level Export Group to "Effect"

**Status:** ✅ Complete.

All 40 Juice comp scripts now use `@export_group("Effect")` as their first group. Only `SequencerJuiceComp` has no @export vars (correct — it's a pure orchestrator). `JuiceCompBase` keeps `"Timing"` as its group (base class, not a comp).

For comps using `_get_property_list` (Transform, Camera, ScreenMotion), `@export_group("Effect")` wraps the selector `@export var` and the backing vars appear after it in the inspector.

---

## Convert _get_property_list to _validate_property (where applicable)

**Status:** In progress — Noise comps refactored as reference implementation.

**Finding:** Vector2/3 vertical display was a false alarm — Godot's native Vec2 layout uses 2 rows by design. Vec3 renders label + values on separate rows. Not our bug.

**Hybrid approach (documented in `.windsurf/workflows/code.md`):**
- **`_validate_property`** (Approach A): For simple show/hide of individual `@export` properties within static group structures. Simpler, fewer lines.
- **`_get_property_list`** (Approach B): Required when entire groups appear/disappear, custom property ordering is needed, or properties should not serialize when hidden.

**Completed:**
- Noise (Control/2D/3D/Property) — converted to `_validate_property` + `@export`

**Remaining (apply same pattern where applicable):**
- Transform (Control/2D/3D) — offset, pivot
- Shake (Control/2D/3D) — amplitude, pivot
- Spring (Control/2D/3D) — target values, pivot
- Property comps (Shake/Spring) — type-dependent amplitude/target values
- Progress (Control/2D/3D) — rate values

---

## Audit: Do From/To Transform Fixes Apply to Other Comp Families?

**Status:** Pending — next debug run.

**Context:** During Transform comp debugging, several infrastructure fixes were made that hardened the delta-contribution animation model against edge cases. These fixes were implemented only in the Transform comps (Control/2D/3D) because that's where the bugs were reported. However, other comp families that write to target properties (Shake, Noise, Spring, Camera, ScreenMotion) may have the same underlying vulnerabilities.

**Relevant commits to review:**

1. **Commit `1cd06a3` — Bug B save pipeline fix:**
   - Added `_temporarily_undo_visual()` / `_temporarily_reapply_visual()` virtual methods to `JuiceCompBase` (no-op defaults).
   - Transform (Control/2D/3D) overrides subtract/add their `_my_*_contribution` so Godot doesn't serialize mid-animation values into `.tscn`.
   - **Audit question:** Do Shake, Noise, Spring, Camera, ScreenMotion comps also need save-pipeline overrides? They write to `target.position`/`rotation`/`scale` (or receiver offsets) — if the editor saves mid-preview, those values could bake in.

2. **Commit `118cd5f` — Container hold + external-move detection:**
   - **Container hold:** `SequencerJuiceComp._held_entries` continuously re-applies From state on Control targets inside Containers during start_delay/stagger gaps. Currently only warmups Transform clones.
   - **External-move detection:** `_last_written_position` tracker in Transform comps detects Container re-sorts between frames and re-captures base. Shake/Noise/Spring use absolute writes (`target.prop = base + offset`) instead of delta-first — they may be immune to this class of bug, or they may have a different variant of it.
   - **FFR (Force-First-Frame):** `_apply_effect(_start_progress)` in `_animate_to()` after `set_process(true)`. This is in the base class, so all comps benefit. No per-comp audit needed.
   - **Audit question:** Do Shake/Noise/Spring comps inside Containers need held-entry support? Their absolute-write pattern (`target = base + offset`) should survive re-sorts IF `_capture_base()` re-reads after the sort. But if `_base_position` was captured before the Container settled, the base is wrong.

**Comps to audit (write to target transform properties):**
- Shake (Control/2D/3D) — absolute write: `target.position = _base_position + offset`
- Noise (Control/2D/3D) — absolute write: `target.position = _base_position + noise_offset`
- Spring (Control/2D/3D) — absolute write: `target.position = _current_value`
- Camera (2D/3D) — delta-first on receiver offsets (different target type)
- ScreenMotion — delta-first on receiver offsets

**Comps NOT needing audit (don't write persistent transform):**
- Appearance, Outline, Visibility, SquashStretch, Progress, ShaderProperty, ScreenOverlay, VFX, Trail, Time, control flow comps

**Approach:** For each comp family above, check:
1. Does `_temporarily_undo_visual()` need an override? (save pipeline safety)
2. Does external-move detection / base re-capture apply? (Container resilience)
3. Does the Sequencer held-entry warmup cover this comp type? (start_delay visual)

---

## Delta-First Stackability Audit (Full System)

**Status:** Audit complete. Conversion pending.

**Date:** March 2026

**Root cause of DEBUG #3 (rotation stuck at -90°):** `NoiseControlJuiceComp` on the same
node as `TransformControlJuiceComp`, both targeting Rotation. The Noise comp uses **absolute
writes** (`ctrl.rotation = _base_rotation + offset`) which overwrites the Transform comp's
delta-first contributions every frame. Additionally, the Noise comp captured `_base_rotation`
*after* the Transform comp's FFR had already applied the From state (-90°), so its base was
wrong from the start.

**The Juice system was designed to be fully stackable.** Multiple comps should be able to
target the same property on the same node. Delta-first writes (`target.prop += delta`) are the
mechanism that enables this — each comp tracks its own contribution and writes only the change.
Absolute writes (`target.prop = base + offset`) destroy other comps' contributions.

### Audit Results: Transform-Writing Comps

All 41 `*JuiceComp.gd` files were grep-checked at the line level for their actual write
patterns in `_apply_*` methods.

| Comp Family | Control | 2D | 3D | Property | Status |
|---|---|---|---|---|---|
| **Transform** | ✅ delta | ✅ delta | ✅ delta | N/A | **STACKABLE** |
| **Noise** | ❌ absolute | ❌ absolute | ❌ absolute | ✅ delta | **BROKEN** — Property variant fixed, 3 domain variants broken |
| **Shake** | ❌ absolute | ❌ absolute | ❌ absolute | ✅ delta | **BROKEN** — Property variant fixed, 3 domain variants broken |
| **Spring** | ❌ absolute | ❌ absolute | ❌ absolute | ❌ absolute | **ALL ABSOLUTE** |
| **SquashStretch** | ❌ absolute | ❌ absolute | ❌ absolute | N/A | **ALL ABSOLUTE** |

**Key finding:** `NoisePropertyJuiceComp` and `ShakePropertyJuiceComp` already use the correct
delta-first pattern (`current + offset - prev`). The 3 domain variants (Control, 2D, 3D) in
each family were missed during the delta conversion pass.

### Audit Results: Non-Transform Comps

| Comp Family | Writes To | Pattern | Stackable? |
|---|---|---|---|
| **Visibility** | `visible` (bool), `modulate.a` | Absolute | Conceptual limit — can't stack booleans; alpha stacking unusual |
| **Appearance** (Ctrl/2D/3D) | `modulate`, shaders | Absolute | Partial — additive tint could stack; shader effects can't |
| **Camera** (2D/3D) | Camera properties | Absolute | N/A — one camera per viewport |
| **Screen** (Motion/Overlay) | Screen-level effects | Absolute | N/A — global effects |
| **Progress** (Ctrl/2D/3D/Prop) | Range/value properties | Absolute | Low priority — usually unique per target |
| **Shader Property** | Shader uniforms | Absolute | Possible but niche |
| **Orchestrators** (Seq/Loop/etc) | Nothing | N/A | Not applicable |
| **VFX / Trail** | Spawns children | N/A | Not applicable |

### Conversion Plan

#### Tier 1 — Easy (pattern proven in Property variants) — 9 scripts

The Property variants of Noise and Shake already implement the correct pattern. The domain
variants just need the same conversion:

**Current (broken):**
```gdscript
ctrl.position = _base_position + offset
ctrl.rotation = _base_rotation + rotation_offset
ctrl.scale = _base_scale + scale_offset
```

**Target (stackable):**
```gdscript
# Track contribution per-property (new vars: _my_position_contribution, etc.)
var delta = offset - _my_position_contribution
ctrl.position += delta
_my_position_contribution = offset
# Same for rotation and scale channels
```

**Scripts to convert:**

| # | Script | Channels to convert |
|---|---|---|
| 1 | `Control/NoiseControlJuiceComp.gd` | position, rotation, scale |
| 2 | `2D/Noise2DJuiceComp.gd` | position, rotation + pivot comp, scale + pivot comp |
| 3 | `3D/Noise3DJuiceComp.gd` | position, rotation + pivot comp, scale + pivot comp |
| 4 | `Control/ShakeControlJuiceComp.gd` | position, rotation, scale |
| 5 | `2D/Shake2DJuiceComp.gd` | position, rotation + pivot comp, scale + pivot comp |
| 6 | `3D/Shake3DJuiceComp.gd` | position, rotation + pivot comp, scale + pivot comp |

**Note:** 2D/3D variants also have **pivot compensation position writes** within their
rotation and scale effect methods. Those position writes must also become delta-first, tracked
via `_my_position_contribution`.

**Per-script checklist (each of the 6 domain scripts):**

- [ ] Add `_my_position_contribution`, `_my_rotation_contribution`, `_my_scale_contribution` vars
- [ ] Add `_last_written_*` tracking vars for external-move detection
- [ ] Convert all `_apply_*_noise()` / `_apply_*_shake()` methods to delta-first
- [ ] Convert pivot compensation position writes to delta-first (2D/3D only)
- [ ] Update `_on_animate_out_complete()` to subtract contribution
- [ ] Update `_restore_to_natural()` to subtract contribution + zero tracking
- [ ] Update `_exit_tree()` to subtract contribution
- [ ] Add `_temporarily_undo_visual()` / `_temporarily_reapply_visual()` overrides
- [ ] Verify `_capture_base()` / `_invalidate_base_cache()` reset new tracking vars

#### Tier 2 — Moderate (physics/curve → delta output wrapper) — 7 scripts

Spring and SquashStretch compute an absolute `_current_value` through physics simulation or
curve evaluation. The internal simulation stays unchanged — only the **final write** converts
to delta-first.

**Conversion pattern:**
```gdscript
# Spring internally tracks _current_value (absolute)
# Write as delta instead of absolute:
var desired_offset = _current_value - _base_position
var delta = desired_offset - _my_position_contribution
target.position += delta
_my_position_contribution = desired_offset
```

**Scripts to convert:**

| # | Script | Notes |
|---|---|---|
| 7 | `Control/SpringControlJuiceComp.gd` | Wrap `_apply_spring_value()` |
| 8 | `2D/Spring2DJuiceComp.gd` | + pivot compensation |
| 9 | `3D/Spring3DJuiceComp.gd` | + pivot compensation |
| 10 | `Property/SpringPropertyJuiceComp.gd` | Generic property delta |
| 11 | `Control/SquashStretchControlJuiceComp.gd` | Scale only |
| 12 | `2D/SquashStretch2DJuiceComp.gd` | Scale only |
| 13 | `3D/SquashStretch3DJuiceComp.gd` | Scale + pivot compensation |

**Per-script checklist:**

- [ ] Add contribution tracking vars
- [ ] Wrap `_apply_spring_value()` / scale write in delta-first layer
- [ ] Same cleanup methods as Tier 1 (restore, exit_tree, undo/reapply visual)

#### Tier 3 — Low priority / different stacking semantics

Visibility, Appearance, Camera, Screen, Progress, Shader — deferred. These either can't
meaningfully stack or stacking is a niche use case. Document as known limitation for v1.

### Implementation Order

1. **Tier 1 Noise (3 scripts)** — directly fixes DEBUG #3
2. **Tier 1 Shake (3 scripts)** — same pattern, prevents future stacking bugs
3. **Tier 2 Spring (4 scripts)** — moderate effort, enables spring + transform stacking
4. **Tier 2 SquashStretch (3 scripts)** — moderate effort, enables squash + transform stacking
5. **Tier 3** — deferred to post-release or documented as limitation

### Testing Strategy

For each converted comp, test stacking on the same target in all 3 domains:

| Test | Setup | Expected |
|---|---|---|
| Noise + Transform (same property) | Transform: From -90° To 0°, Noise: rotation amplitude 5° | Smooth rotation animation with subtle noise overlay |
| Shake + Transform (same property) | Transform: From offset To self, Shake: position strength 10px | Smooth position animation with shake overlay |
| Spring + Transform (same property) | Transform: From 0 To self, Spring: rotation offset 15° | Spring settles at offset, transform animates around it |
| Multiple Noise (same property) | Two Noise comps, different frequencies/amplitudes | Both contributions visible, no overwriting |
