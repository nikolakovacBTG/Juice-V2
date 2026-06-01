# Upgrades and Fixes TO DO

> Active upgrade and fix plans for the Juice Demo project.
> Completed designs are moved to `Documentation/Done/`.

---

## Architecture Debt: Appearance Family is Not Ledger-Compliant

**Discovered:** 2026-05-11 during Phase 6.2 (InterpolateProperty family) — triggered by Color stacking analysis.  
**Severity:** High — silent conflict potential with Property-family effects on the same target.  
**Scope:** All 3 domains (Control, 2D, 3D) × {effect file + base class + domain node} = **9 V2 files**, 9 V1 files.

### Root cause

During the V1 Ledger port, AI agents correctly identified that `Color` cannot be stacked additively (it requires multiplicative blending). They implemented a dedicated `_modulate_factor` accumulator: each Appearance effect sets a `Color` factor on itself, and the domain node (`JuiceControl`, `Juice2D`, `Juice3D`) reads all active effects' factors, multiplies them together, and writes the result directly to `self_modulate` — **bypassing `JuiceLedger` entirely**.

The decision was structurally correct for a system where only Appearance effects ever touched `self_modulate`. The gap: the Property family was not yet designed, and the assumption that "nobody else will touch Color" was not documented as an architectural constraint.

### Consequence

If an `AppearanceXxxJuiceEffect` and an `InterpolatePropertyXxxJuiceEffect` (targeting `self_modulate` or `modulate`) are both active on the same node simultaneously:

- Appearance writes `self_modulate` via the domain node's `_modulate_factor` multiplication loop.
- Property writes `modulate`/`self_modulate` via `JuiceLedger.flush()`.
- Both write to the same property in the same frame via **two independent pipelines with no coordination**.
- **Last write wins. Silent conflict. No error.**

### What the documents say

- `JuiceLedger_Migration_Handover.md` mentions `force_base()` for "3D appearance seeding" — a hint at special handling — but does not flag this as an architectural exception.
- `VFXJuiceEffectBase.gd` header explicitly marks itself `# APPROVED EXCEPTION` (side-effects, nothing to aggregate). No equivalent documentation exists for Appearance.
- **No architectural document formally designates Appearance as a Ledger exception.** The non-compliance was implicit and undocumented.

### Other effect families — compliance status

| Family | Ledger-compliant? | Notes |
|--------|------------------|-------|
| Transform (Shake, Noise, SquashStretch, ProgressTransform, Transform) | ✅ Yes | All route through `register_delta()` on domain nodes |
| Property (InterpolateProperty, future Noise/ShakeProperty) | ✅ Yes | `PropertyJuiceEffectBase._apply_effect()` is the Ledger gateway |
| **Appearance** | ❌ **No** | Uses `_modulate_factor` + domain node loop — parallel write path |
| VFX | ✅ Approved exception | Side-effect (particles/spawns). `_apply_effect()` is a no-op. Documented in file header. |
| Trail | ✅ Approved exception | Spawns a child trail node. No persistent property write on target. |
| Time | ✅ Approved exception | Modifies `Engine.time_scale`. Engine global, not a node property. |
| Meta (CallMethod, SignalEmit, SceneAction, Pause) | ✅ Approved exception | Pure side-effects. No node property writes. |
| Camera | ⚠️ To audit | Writes to Camera2D/3D node properties. Separate node from animation target — probably fine, but no Ledger stacking for concurrent camera effects. |
| Screen Overlay | ⚠️ To audit | Writes to CanvasLayer overlay shader params. Separate node — probably fine. |

### The fix

1. **Remove `_modulate_factor`** from all 3 Appearance effect classes and all 3 domain nodes.
2. **Remove the multiplication loop** from `JuiceControl`, `Juice2D`, `Juice3D` that aggregates `_modulate_factor` values.
3. **Migrate Appearance to the Ledger**: in `_on_animate_start()` call `JuiceLedger.ensure(target, ["self_modulate"])`. In `_apply_effect()` return the desired Color from `_compute_property_value()` and let the base class register the Color factor via `register_delta()`.
4. **Optionally**: Appearance effect base classes could extend `PropertyJuiceEffectBase` directly, making `self_modulate` just another property path entry. This is the cleanest architectural end-state.

### Infrastructure already available

The `TYPE_COLOR` branch in `PropertyJuiceEffectBase._apply_effect()` (added Phase 6.2, 2026-05-11) already implements the correct Color factor logic (`desired / base → register_delta`). **No new Ledger infrastructure is needed for this refactor.**

### Files to change

| File | Change needed |
|------|--------------|
| `Juice_V2/Control/AppearanceControlJuiceEffect.gd` | Remove `_modulate_factor`, use Ledger |
| `Juice_V2/2D/Appearance2DJuiceEffect.gd` | Remove `_modulate_factor`, use Ledger |
| `Juice_V2/3D/Appearance3DJuiceEffect.gd` | Remove `_modulate_factor`, use Ledger |
| `Juice_V2/Base Classes/JuiceControlAppearanceEffect.gd` | Remove `_modulate_factor` field + accumulation helpers |
| `Juice_V2/Base Classes/Juice2DAppearanceEffect.gd` | Same |
| `Juice_V2/Base Classes/JuiceControl.gd` | Remove multiplication loop + `_modulate_factor` read |
| `Juice_V2/Base Classes/Juice2D.gd` | Same |
| `Juice_V2/Base Classes/Juice3D.gd` | Same + remove `force_base()` appearance seeding pattern |
| V1 equivalents | Same changes mirrored in `Juice_V1/` |

> [!NOTE]
> The OUTLINE mode in `AppearanceControlJuiceEffect` writes directly to `target.material` (shader parameters), not to a CanvasItem Color property. OUTLINE is **not** part of this problem — shader parameter writes have no Ledger equivalent and are an approved per-effect-owned resource pattern.

