# Upgrades and Fixes TO DO

> Active upgrade and fix plans for the Juice Demo project.
> Completed designs are moved to `Documentation/Done/`.

---

## Standardize Top-Level Export Group to "Effect"

**Status:** Planned — apply after Noise inspector refactor is complete.

**Finding:** Every Juice comp uses a different name for its first `@export_group`:

| Component Family | Current First Group |
|---|---|
| Noise (Control/2D/3D) | `"Noise Design"` |
| Shake (Control/2D/3D) | `"Shake"` |
| Transform (Control/2D/3D) | *(none — transform_target ungrouped)* |
| Spring (Control/2D/3D) | `"Spring Physics"` |
| SquashStretch (Control/2D/3D) | `"Squash Stretch"` |
| Appearance (Control/2D/3D) | `"Appearance"` |
| Progress (Control/2D/3D) | `"Progress"` |
| Visibility | `"Visibility Effect"` |
| VFX | `"VFX"` |
| Screen Overlay | `"Overlay"` |
| Trail | `"Trail Appearance"` |
| Property comps | `"Property Target"` |

**Convention:** Rename the top-level group to **"Effect"** in ALL Juice comps. This creates a recognizable pattern — the first foldable group always holds the component's primary settings.

**Scope:** All comp scripts in `addons/juice/`. The Noise comps are being refactored first as the reference implementation.

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

