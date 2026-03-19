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

