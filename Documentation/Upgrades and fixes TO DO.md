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

