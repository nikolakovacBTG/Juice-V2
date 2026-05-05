# Appearance Effects — Architecture Plan (Phases A–C)

> Phase D (Test Suite) and Phase E (Doc Comments) are separate plan artifacts.
> Checkpoint file: `.claude/memory/appearance_bugfix_status.md` — updated at end of each phase.

---

## Confirmed Bugs & Gaps

| # | Issue | Phase |
|---|---|---|
| 1 | No From/To paradigm on Appearance effects | A |
| 2 | Sibling Juice domain nodes overwrite each other's modulate (absolute write) | B |
| 3 | Flicker multiplies progress instead of output delta | C |
| 4 | Missing doc comments | E (separate) |
| 5 | Test coverage gaps | D (separate) |

---

## Phase A — From/To API

### Class level

Follows the Transform precedent exactly: From/To lives in the **concrete classes** (`Appearance2DJuiceEffect`, `AppearanceControlJuiceEffect`, `Appearance3DJuiceEffect`). The **intermediate bases** (`Juice2DAppearanceEffect`, `JuiceControlAppearanceEffect`, `Juice3DAppearanceEffect`) remain contribution-storage only — no change.

### Shared reference infrastructure (per concrete class)

```gdscript
enum AppearanceReference { CUSTOM, SELF }
enum CaptureAt { TRIGGER, READY, IN_EDITOR }

var from_reference: int = AppearanceReference.SELF
var to_reference: int = AppearanceReference.CUSTOM
var capture_at: int = CaptureAt.TRIGGER
```

These are exposed via `_get_property_list()` for TINT, FADE, OVERBRIGHT (and OUTLINE `to_width` only — OUTLINE `from_width` is always CUSTOM).

### Per-effect From/To fields

**TINT** — both from and to have `color` + `blend`:
```gdscript
var from_tint_color: Color = Color.WHITE  # default = no tint (identity)
var from_tint_blend: float = 0.0          # 0.0 = no tint from (identity)
var to_tint_color: Color = Color(1, 0.4, 0.4, 1)
var to_tint_blend: float = 1.0
```
- `from_factor = lerp(WHITE, from_tint_color, from_tint_blend)`
- `to_factor   = lerp(WHITE, to_tint_color,   to_tint_blend)`
- `_modulate_factor = from_factor.lerp(to_factor, progress)`
- With flicker: `_modulate_factor = from_factor.lerp(to_factor, progress * flicker)`

Note on `lerp(WHITE, color, blend)`: WHITE is the multiplicative identity for modulate. `lerp(WHITE, RED, 0.5) = Color(1, 0.5, 0.5, 1)` means "red channel unchanged, green/blue halved" — a red shift. This is the correct and standard Godot modulate-tint formula.

SELF capture (2D/3D): captures `target.modulate` into `_captured_natural: Color`. SELF capture (Control): captures `target.self_modulate` — prevents double-applying parent Container dimming when writing back to `self_modulate`. If `self_modulate` is `WHITE` (no prior override), captured value is `WHITE` = identity; the parent's contribution is preserved implicitly.

**FADE**:
```gdscript
var from_alpha: float = 1.0
var to_alpha: float = 0.0
```
- `_modulate_factor = Color(1, 1, 1, lerpf(from_alpha_resolved, to_alpha_resolved, progress * flicker))`
- SELF resolves `from_alpha`/`to_alpha` from `target.modulate.a` (2D/3D) or `target.self_modulate.a` (Control) at capture time.

**OVERBRIGHT**:
```gdscript
var from_brightness: float = 1.0
var to_brightness: float = 2.0
```
- `var boost = lerpf(from_b, to_b, progress * flicker)`
- `_modulate_factor = Color(boost, boost, boost, 1.0)`
- SELF resolves from `target.modulate` RGB max (2D/3D) or `target.self_modulate` RGB max (Control).

**3D OVERBRIGHT — keep albedo approach, add configuration warning**:

`albedo_color > 1.0` is intentional — it is a true HDR brightness boost, not an additive glow. Emission is a different visual result. Keep the current albedo implementation.

Add `_get_configuration_warnings()` to detect incompatible render pipeline:

```gdscript
if effect_type == AppearanceEffect.OVERBRIGHT:
    var method := ProjectSettings.get_setting(
        "rendering/renderer/rendering_method", "forward_plus") as String
    if method != "forward_plus":
        warnings.append(
            "OVERBRIGHT requires Forward+ renderer with HDR enabled. " +
            "Renderer '%s' does not support albedo > 1.0. " +
            "Effect will be clamped to normal brightness." % method)
```

**3D OUTLINE — port gap, implementation via `next_pass` on working material**:

There is no `outline_3d.gdshader`. The V0 3D outline effect uses `overlay_3d.gdshader` — which is **explicitly designed as a `next_pass` material** (renders after the primary surface pass, reads screen texture, mixes flat color over the mesh). This is how it achieves an "outline" / overlay look in 3D.

Hookup is non-conflicting with the working material:

```gdscript
# In _apply_effect for OUTLINE (3D):
if _ensure_appearance_working_mat():
    if _outline_mat == null:
        _outline_mat = ShaderMaterial.new()
        _outline_mat.shader = preload("res://addons/Juice_V1/Shaders/overlay_3d.gdshader")
    _outline_mat.set_shader_parameter("outline_color", outline_color)
    _outline_mat.set_shader_parameter("amount", lerpf(from_width_factor, to_width_factor, progress))
    _appearance_working_mat.next_pass = _outline_mat

# In _restore_to_natural / stop:
if _appearance_working_mat != null:
    _appearance_working_mat.next_pass = null
```

`next_pass` is a property on `Material` — it chains a second render pass after the primary material without replacing it. TINT/FADE/OVERBRIGHT operate on the working `StandardMaterial3D`; OUTLINE chains onto `working_mat.next_pass`. **No conflict. Multiple `next_pass` can be chained** (`next_pass.next_pass = ...`) so multiple OUTLINE effects from sibling Juice nodes technically stack — each adds its own pass.

**`Juice3D` additions needed**:
- `_appearance_outline_mat: ShaderMaterial = null` — owned by domain node (not the effect)
- On appearance teardown (`_clear_appearance_working_mat()`): also clear `next_pass`

**`Appearance3DJuiceEffect` additions**:
- Add `OUTLINE` to `AppearanceEffect` enum
- Add `outline_color: Color`, `from_width_factor: float = 0.0`, `to_width_factor: float = 1.0` (the overlay `amount` parameter acts as the "width" equivalent)
- Show/hide in `_get_property_list()` per `effect_type == OUTLINE`

**OUTLINE (2D and Control only)**:
```gdscript
var from_width: float = 0.0   # always CUSTOM, no SELF option
var to_width: float = 2.0
# to_reference can be CUSTOM (explicit width)
# from_reference is always CUSTOM
```
- `width = lerpf(from_width, to_width, progress)`
- Apply flicker per `outline_flicker_target` (see Phase C)

**OUTLINE (3D)**: Port gap — added in Phase A. Uses `overlay_3d.gdshader` via `working_mat.next_pass` (a second render pass that reads the screen texture and blends a flat overlay color). Non-conflicting with the working `StandardMaterial3D` used for TINT/FADE/OVERBRIGHT. Multiple OUTLINE effects can chain via `next_pass.next_pass`. `from_width_factor` / `to_width_factor` drive the `amount` uniform (0.0–1.0).

### Control domain write target — `self_modulate`

All JuiceControl appearance writes go to `target.self_modulate`, never `target.modulate`:
- `self_modulate` = local override only; parent Container's modulate is preserved separately
- Natural state = `self_modulate == WHITE` (identity, no override)
- Stop/restore = `self_modulate = WHITE` — parent inheritance resumes cleanly

**SELF FROM/TO reference for Control**: captures `target.self_modulate` (not `target.modulate`). At progress=0 the factor written back is the captured `self_modulate` value (usually WHITE). Displayed = `parent_modulate * self_modulate`. If `self_modulate` was WHITE before animation, at progress=0 the displayed color equals the inherited parent — correct natural state. Using `target.modulate` for capture would cause double-parent-dimming at progress=0 (`parent * parent * factor`).

**Awareness of inherited effective color**: The Phase B stacking base still reads `target.modulate` once (pre-Juice, via metadata) to know what colour the user SEES as the natural state — but this value is only used for the sibling rescan logic in Juice2D/3D. JuiceControl's sibling rescan base is always `Color.WHITE` (see Phase B).

### ShaderMaterial single-slot limitation (2D and Control OUTLINE)

**Known architectural limitation**: Godot 2D/Control nodes have a single `.material` slot. Only one OUTLINE effect can be active on a given target at a time. If a second OUTLINE tries to install its ShaderMaterial, it will overwrite the first.

**Handling**:
1. `_get_configuration_warnings()`: emit a clear warning if the recipe contains more than one OUTLINE effect, or if a sibling Juice node also has an active OUTLINE.
2. At runtime in `_on_animate_start()`: check `target.material` — if it is already a `ShaderMaterial` installed by another Juice effect, push a warning and skip installation. The second OUTLINE does not animate and logs clearly.
3. Document this as a known limitation in `JUICE_CONTEXT.md`.

### `_apply_effect()` refactoring

All three concrete classes need `_apply_effect()` refactored. Current flat `lerp(WHITE, x, p)` replaced with:
```gdscript
var from_val := _resolve_from(target)  # per-effect resolver
var to_val   := _resolve_to(target)
# then lerp with progress (and flicker from Phase C)
```

Each effect type gets `_resolve_from_*()` and `_resolve_to_*()` methods that handle `CUSTOM` vs `SELF`.

---

## Phase B — Sibling Juice node stacking fix

### Root cause

`_post_tick_write()` writes `target.modulate = _base_modulate * combined_factor` — an **absolute write** using a snapshot. Two sibling Juice nodes each compute their own absolute result and the second overwrites the first.

### Fix — per-node contribution slot + sibling rescan

**Remove from all domain nodes**: `_base_modulate`, `_has_modulate_base`

**Add to each domain node**:
```gdscript
var _own_modulate_contribution: Color = Color.WHITE
```

**`_post_tick_write()` new modulate logic (Juice2D)**:

```gdscript
# 1. Compute this node's combined contribution from its own effects
var own_combined := Color.WHITE
for effect in _runtime_effects:
    var app := effect as Juice2DAppearanceEffect
    if app == null or not app._contributes_modulate:
        continue
    own_combined *= app._modulate_factor
_own_modulate_contribution = own_combined

# 2. Retrieve shared natural base from target metadata.
#    Captured ONCE at _capture_base_values() time by the first Juice2D
#    to initialize on this target. At that moment, no Juice effect has
#    written yet, so target.modulate == the true natural value.
#    Key is never overwritten while any Juice node is active.
const META_KEY := &"juice_modulate_natural"
var base_color: Color = target.get_meta(META_KEY, target.modulate)
if not target.has_meta(META_KEY):
    target.set_meta(META_KEY, target.modulate)

# 3. Scan all sibling Juice2D nodes on same parent, multiply contributions
var final_factor := Color.WHITE
for child in target.get_children():
    var j := child as Juice2D
    if j == null:
        continue
    final_factor.r *= j._own_modulate_contribution.r
    final_factor.g *= j._own_modulate_contribution.g
    final_factor.b *= j._own_modulate_contribution.b
    final_factor.a *= j._own_modulate_contribution.a

# 4. Write once: base * product of all sibling contributions
target.modulate = Color(
    base_color.r * final_factor.r,
    base_color.g * final_factor.g,
    base_color.b * final_factor.b,
    base_color.a * final_factor.a)
```

**Natural base capture timing**: In `_capture_base_values()` (called before any effects animate), the domain node writes `target.set_meta(META_KEY, target.modulate)` if the meta doesn't already exist. This captures the pre-Juice natural colour exactly once. On stop: if all siblings have `_own_modulate_contribution == WHITE`, the meta is removed and `target.modulate` is restored to the stored base.

**`_temporarily_undo_visual()`**: Set `_own_modulate_contribution = Color.WHITE`, then re-trigger the sibling rescan write so remaining contributors stay correct.

**JuiceControl — diverges from Juice2D**:
- Writes to `target.self_modulate` (not `target.modulate`)
- Natural base is always `Color.WHITE` (identity for `self_modulate`) — no metadata needed
- Sibling rescan formula: `target.self_modulate = product_of_all_own_contributions` (no base multiplication)
- On stop (all siblings white): `target.self_modulate = Color.WHITE`

**Juice3D**: Same pattern as Juice2D for `_own_albedo_contribution: Color` and `_own_alpha_contribution: float` applied to the shared working material albedo. Natural base stored in metadata key `juice_albedo_natural` and `juice_alpha_natural`.

---

## Phase C — Flicker redesign

### Remove

`_get_effective_progress()` — deleted from all 3 concrete classes.

### Add

```gdscript
func _compute_flicker_multiplier() -> float:
    if flicker_mode == FlickerMode.NONE:
        return 1.0
    var raw: float
    match flicker_mode:
        FlickerMode.RANDOM:
            raw = (_flicker_noise.get_noise_1d(_flicker_time * flicker_rate) + 1.0) * 0.5
        FlickerMode.CUSTOM:
            raw = flicker_curve.sample(fmod(_flicker_time * flicker_rate, 1.0)) if flicker_curve else 1.0
    var m := lerpf(flicker_min, flicker_max, raw)
    if hard_flicker:
        m = 1.0 if m >= (flicker_min + flicker_max) * 0.5 else 0.0
    return m
```

### `_apply_effect()` per effect type with flicker

```gdscript
var f := _compute_flicker_multiplier()

# TINT:
var from_f = lerp(WHITE, from_tint_color, from_tint_blend)
var to_f   = lerp(WHITE, to_tint_color,   to_tint_blend)
_modulate_factor = from_f.lerp(to_f, progress * f)

# FADE:
_modulate_factor = Color(1, 1, 1, lerpf(from_alpha, to_alpha, progress * f))

# OVERBRIGHT (2D/Control):
var boost := lerpf(from_brightness, to_brightness, progress * f)
_modulate_factor = Color(boost, boost, boost, 1.0)

# OVERBRIGHT (3D) — albedo > 1.0 (HDR, Forward+ only — same as 2D/Control):
var boost := lerpf(from_brightness, to_brightness, progress * f)
_albedo_factor = Color(boost, boost, boost, 1.0)

# OUTLINE:
var width := lerpf(from_width, to_width, progress)
match outline_flicker_target:
    OutlineFlickerTarget.WIDTH:
        mat.set_shader_parameter("outline_width", width * f)
        mat.set_shader_parameter("outline_color", outline_color)
    OutlineFlickerTarget.COLOR_ALPHA:
        mat.set_shader_parameter("outline_width", width)
        mat.set_shader_parameter("outline_color",
            Color(outline_color.r, outline_color.g, outline_color.b, outline_color.a * f))
    OutlineFlickerTarget.COLOR:
        mat.set_shader_parameter("outline_width", width)
        # Lerp between outline_color and flicker_color_to using flicker multiplier
        mat.set_shader_parameter("outline_color", outline_color.lerp(flicker_color_to, 1.0 - f))
```

`outline_flicker_target` and `flicker_color_to` only appear in inspector when `effect_type == OUTLINE AND flicker_mode != NONE`.

### Flicker meta-fade in/out

Achieved automatically: at progress=0, `progress * f = 0` regardless of flicker — effect is identity. At progress=1 (peak hold), flicker oscillates at full amplitude. During animate-out (progress 1→0), flicker amplitude scales down with progress. No special code needed.

---

> All open questions resolved. No further approval items.
