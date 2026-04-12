# Appearance Comp Redesign — Full Design Document

> **Created:** 2026-03-13
> **Status:** Design — awaiting implementation authorization
> **Replaces:** `Appearance2DJuiceComp`, `AppearanceControlJuiceComp`, `Appearance3DJuiceComp`
> **Absorbs functionality from:** `Outline2DJuiceComp`, `OutlineControlJuiceComp`, `Outline3DJuiceComp`, `VisibilityJuiceComp`
> **Does NOT touch legacy comps** — they remain until new Appearance is proven, then deleted manually.

---

## 1. Purpose & Scope

### What problem does this system solve?

The current Appearance comps are narrow tint animators disguised under a broad name. Meanwhile, related visual effects (outline, visibility/blink/flicker, blend modes, shader effects) are scattered across 6+ separate components with inconsistent UX. Users must:

- Know which comp to pick for each visual effect
- Understand domain-specific rendering (modulate vs material vs StyleBox)
- Set up shaders, materials, or StyleBoxes manually for outline/dissolve/grayscale
- Accept that "Appearance" only means "tint" despite the name suggesting more

This redesign consolidates all per-node appearance effects into one enum-driven component per domain, with a universal temporal modulation layer (flicker) that works on any effect.

### What it explicitly does NOT solve

- **Screen-space effects** — `ScreenOverlayJuiceComp` remains separate (not per-node)
- **Custom shader uniform animation** — `ShaderPropertyJuiceComp` remains separate (power-user tool for arbitrary uniforms)
- **Transform effects** — position, rotation, scale are separate comp families
- **VFX spawning** — `VFXJuiceComp`, `TrailJuiceComp` spawn new geometry, fundamentally different
- **Complex shader effects** — hologram, glitch, freeze, burn, etc. are deferred to a Shader DLC

### Assumptions

- `JuiceBase` provides timing, triggering, looping, curves, `_apply_effect(progress)` lifecycle
- `_target_node` is resolved by `JuiceBase` (parent or configured node)
- `hold_at_peak` is available in `JuiceBase` for flash-style effects
- `@tool` is used for editor preview compatibility
- Godot 4.x API (typed GDScript, `_get_property_list`, `_validate_property`)

---

## 2. System Boundaries

### Inputs

| Input | Source | Description |
|-------|--------|-------------|
| `progress` (0.0–1.0) | `JuiceBase` | Animation timeline position |
| `_target_node` | `JuiceBase` | The node whose appearance is being modified |
| `delta` | `_process` / `_physics_process` | Frame time for flicker temporal modulation |
| Inspector configuration | User / scene file | Effect type, colors, sizes, flicker settings |

### Outputs

| Output | Consumer | Description |
|--------|----------|-------------|
| Modified `modulate` | CanvasItem (2D/Control) | Tint, overbright, fade |
| Modified `CanvasItemMaterial.blend_mode` | CanvasItem (2D/Control) | Blend mode effect |
| Modified `ShaderMaterial` uniforms | CanvasItem (2D) | Outline, grayscale, dissolve |
| Modified `StyleBoxFlat` borders | Control | Outline via theme overrides |
| Modified `StandardMaterial3D` properties | GeometryInstance3D (3D) | Albedo, emission, roughness, grow, etc. |
| Modified `StandardMaterial3D` next_pass | GeometryInstance3D (3D) | Inverted hull outline |
| Modified `visible` / `modulate.a` / `transparency` | Target node | Fade/blink visibility |

### Who consumes outputs

Godot's rendering pipeline. No other Juice systems consume these outputs directly.

---

## 3. Data & State

### Data the system owns (persistent — serialized to .tscn)

All `@export` and `_get_property_list` backed variables:

- `appearance_effect` — enum selecting active effect
- Effect-specific parameters (per-effect, detailed in section 4)
- Flicker group settings (`use_flicker`, `flicker_mode`, `hard_flicker`, etc.)

### Data the system reads but does NOT own

- `_target_node` — owned by `JuiceBase`
- `progress` — owned by `JuiceBase` animation system
- Target node's current `modulate`, material, StyleBox, etc. — owned by the target node

### Transient state (runtime only — NOT serialized)

- `_base_color: Color` — captured modulate/albedo at animation start
- `_base_alpha: float` — captured alpha at animation start
- `_base_value: Variant` — captured material property value at start
- `_shader_material: ShaderMaterial` — created/found at runtime for shader effects
- `_outline_material: StandardMaterial3D` — created at runtime for 3D outline
- `_outline_styles: Dictionary` — created StyleBoxFlat instances for Control outline
- `_original_overrides: Dictionary` — saved original theme overrides for Control outline
- `_original_material: Material` — saved original material for restoration
- `_original_blend_mode: int` — saved original CanvasItemMaterial blend mode
- `_canvas_item_material: CanvasItemMaterial` — created for blend mode effect
- `_is_material_duplicated: bool` — whether we duplicated a shared material
- `_has_base_captured: bool` — guard against re-capture
- `_flicker_time: float` — accumulated time for flicker oscillation
- `_flicker_multiplier: float` — current flicker output (0.0–1.0)

### State lifecycle

1. **Initialization** (`_ready`): Call `super._ready()`. No base capture yet.
2. **Animation start** (`_on_animate_start`): Capture base values from target node. Set up materials/shaders if needed.
3. **Animation tick** (`_apply_effect(progress)`): Calculate effective progress (apply flicker modulation), apply the selected effect.
4. **Animation complete** (`_on_animate_out_complete`): Restore base values. Tear down created materials/shaders. Reset transient state.
5. **Cache invalidation** (`_invalidate_base_cache`): Clear all transient state. Forces re-capture on next animation.

---

## 4. Composition Model

### Architecture: 3 per-domain scripts, no shared base beyond JuiceBase

```
JuiceBase
  ├── Appearance2DJuiceComp        (CanvasItem / Node2D targets)
  ├── AppearanceControlJuiceComp   (Control targets)
  └── Appearance3DJuiceComp        (Node3D / GeometryInstance3D targets)
```

No intermediate base class. No static helper. Logic duplicated per domain where needed.

### Top-level enum: `AppearanceEffect`

Each domain has its own enum. Shared effects have the same name across domains; domain-exclusive effects only appear in that domain's enum.

#### Control domain

```
enum AppearanceEffect {
    TINT,          # Animate modulate color
    OVERBRIGHT,    # Animate modulate > 1.0 (HDR bloom)
    OUTLINE,       # StyleBox border animation
    BLEND_MODE,    # CanvasItemMaterial blend mode
    FADE,          # Animate modulate.a (alpha)
    GRAYSCALE,     # Shader-based desaturation (⚠️ limited on Controls)
    DISSOLVE,      # Shader-based dissolve (⚠️ limited on Controls)
}
```

#### 2D domain

```
enum AppearanceEffect {
    TINT,          # Animate modulate color
    OVERBRIGHT,    # Animate modulate > 1.0 (HDR bloom)
    OUTLINE,       # Shader-based edge detection outline
    BLEND_MODE,    # CanvasItemMaterial blend mode
    FADE,          # Animate modulate.a (alpha)
    GRAYSCALE,     # Shader-based desaturation
    DISSOLVE,      # Shader-based dissolve
}
```

#### 3D domain

```
enum AppearanceEffect {
    TINT,              # Animate albedo_color
    OVERBRIGHT,        # Animate emission_energy
    OUTLINE,           # Inverted Hull (next_pass material)
    BLEND_MODE,        # BaseMaterial3D.blend_mode
    FADE,              # Animate transparency
    GRAYSCALE,         # Shader-based desaturation
    DISSOLVE,          # Shader-based dissolve
    # --- 3D exclusive ---
    EMISSION,          # Animate emission color
    ROUGHNESS,         # Animate roughness
    METALLIC,          # Animate metallic
    GROW,              # Animate vertex grow
    RIM,               # Animate rim lighting
    CLEARCOAT,         # Animate clearcoat
    REFRACTION,        # Animate refraction
}
```

### Effect parameters (shown conditionally via `_get_property_list`)

#### TINT

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `color_from` | Color | White | Start color |
| `color_to` | Color | White | End color |
| `animate_alpha` | bool | false | Whether alpha is part of the tint animation |
| `affect_children` | bool | true | Use `modulate` (affects children) vs `self_modulate` (2D/Control only) |

**2D/Control implementation:** `modulate = lerp(color_from, color_to, effective_progress)`
**3D implementation:** `albedo_color = lerp(color_from, color_to, effective_progress)` on StandardMaterial3D

#### OVERBRIGHT

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `overbright_intensity` | float | 2.0 | Peak brightness multiplier (>1.0 for bloom) |
| `overbright_color` | Color | White | Tint direction of the overbright |

**2D/Control implementation:** `modulate = overbright_color * lerp(1.0, overbright_intensity, effective_progress)`
**3D implementation:** Animate `emission_energy_multiplier` from 0.0 to `overbright_intensity`. Set `emission` to `overbright_color` if emission not already enabled.

#### OUTLINE

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `outline_color` | Color | Yellow | Color of the outline |
| `outline_width` | float | 3.0 (Control/2D), 0.02 (3D) | Width in pixels (2D/Control) or world units (3D) |
| `corner_radius` | int | -1 | Corner radius for Control outline (-1 = inherit). Control only. |
| `auto_create_outline` | bool | true | 3D only: auto-create Next Pass material if none exists |
| `geometry_path` | NodePath | empty | 3D only: which child GeometryInstance3D to outline |

**Control implementation:** Duplicate existing StyleBox, add animated `border_width` + `expand_margin`. Restore originals on complete. (Same as current `OutlineControlJuiceComp`)
**2D implementation:** Apply `outline_2d.gdshader` ShaderMaterial, animate `outline_width` and `outline_color` uniforms. (Same as current `Outline2DJuiceComp`)
**3D implementation:** Inverted Hull via Next Pass StandardMaterial3D with `cull_front`, animate `grow_amount`. (Same as current `Outline3DJuiceComp`)

#### BLEND_MODE

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `target_blend_mode` | enum | ADD | Target blend mode to animate toward |

**Blend mode enum (2D/Control):**
```
enum TargetBlendMode2D {
    ADD,             # CanvasItemMaterial.BLEND_MODE_ADD
    SUB,             # CanvasItemMaterial.BLEND_MODE_SUB
    MUL,             # CanvasItemMaterial.BLEND_MODE_MUL
    PREMULT_ALPHA,   # CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
}
```

**Blend mode enum (3D):**
```
enum TargetBlendMode3D {
    ADD,   # BaseMaterial3D.BLEND_MODE_ADD
    SUB,   # BaseMaterial3D.BLEND_MODE_SUB
    MUL,   # BaseMaterial3D.BLEND_MODE_MUL
}
```

**Implementation:** Blend modes are discrete — you can't smoothly interpolate between MIX and ADD. The approach:
1. On `_on_animate_start()`: Save original material/blend_mode. Create/get `CanvasItemMaterial` (2D/Control) or modify `StandardMaterial3D` (3D). Set to `target_blend_mode`.
2. During animation: Animate `modulate.a` (2D/Control) or material alpha (3D) from 0→1 by `effective_progress`, which fades the blend effect in.
3. On `_on_animate_out_complete()`: Restore original material/blend_mode.

This gives a smooth fade-in of the compositing effect. At progress=0 the node looks normal. At progress=1 the full blend mode effect is visible.

#### FADE

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `fade_target_alpha` | float | 0.0 | Target alpha at full effect (0.0 = invisible, 1.0 = full visible) |

**2D/Control implementation:** `modulate.a = lerp(_base_alpha, fade_target_alpha, effective_progress)`
**3D implementation:** `transparency = lerp(_base_transparency, 1.0 - fade_target_alpha, effective_progress)` on GeometryInstance3D

#### GRAYSCALE

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `grayscale_strength` | float | 1.0 | How fully desaturated at peak (0.0 = no effect, 1.0 = full grayscale) |

**Implementation (2D/Control/3D):** Apply a grayscale shader. Single uniform `amount` animated from 0.0 to `grayscale_strength * effective_progress`.

**Shader (fragment):**
```glsl
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    vec4 tex = texture(TEXTURE, UV);  // 2D
    float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    COLOR = vec4(mix(tex.rgb, vec3(gray), amount), tex.a);
}
```

3D variant operates on `ALBEDO` in the fragment shader, applied via `next_pass`.

**Control caveat:** Controls draw multiple primitives. A CanvasItem shader applies per-draw-call. Grayscale will work on simple Controls (Panel, ColorRect) but may look odd on complex Controls (Button with icon + text). Add a configuration warning for this.

#### DISSOLVE

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `dissolve_texture` | NoiseTexture2D | null | Noise pattern for dissolve (auto-creates if null) |
| `dissolve_edge_color` | Color | Orange | Color of the dissolve edge |
| `dissolve_edge_width` | float | 0.05 | Width of the colored edge band |

**Implementation (2D/Control/3D):** Apply a dissolve shader. Uniform `threshold` animated from 0.0 to `effective_progress`.

**Shader (fragment, 2D):**
```glsl
uniform float threshold : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D dissolve_noise;
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);
uniform float edge_width = 0.05;
void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float noise = texture(dissolve_noise, UV).r;
    if (noise < threshold) discard;
    float edge = smoothstep(threshold, threshold + edge_width, noise);
    COLOR = vec4(mix(edge_color.rgb, tex.rgb, edge), tex.a);
}
```

3D variant uses `next_pass` shader with `ALPHA_SCISSOR_THRESHOLD`.

**Auto-create noise:** If `dissolve_texture` is null at animation start, create a `NoiseTexture2D` with `FastNoiseLite` (type: Simplex, frequency: 0.05) programmatically.

**Control caveat:** Same as GRAYSCALE — works on simple Controls, may look odd on complex ones. Configuration warning.

#### 3D-exclusive effects (EMISSION, ROUGHNESS, METALLIC, GROW, RIM, CLEARCOAT, REFRACTION)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `float_offset` | float | 1.0 | Delta added to base value at peak |
| `color_target` | Color | White | Target color (EMISSION only) |
| `geometry_path` | NodePath | empty | Which child GeometryInstance3D to affect |

**Implementation:** Identical to current `Appearance3DJuiceComp` logic. Find StandardMaterial3D, capture base value, apply `base + (float_offset * effective_progress)` for numeric, `base.lerp(color_target, effective_progress)` for EMISSION color. Enable the corresponding material feature flag if needed (e.g., `emission_enabled`, `grow`, `rim_enabled`).

### Flicker — Temporal Modulation Layer

The flicker system is a cross-cutting modifier that applies to ANY appearance effect. It modulates `effective_progress` before it reaches the effect logic.

#### Flicker parameters (conditional — shown only when `use_flicker == true`)

| Parameter | Type | Default | Group | Description |
|-----------|------|---------|-------|-------------|
| `use_flicker` | bool | false | Flicker | Master toggle |
| `flicker_mode` | enum | RANDOM | Flicker | RANDOM or CUSTOM |
| `hard_flicker` | bool | false | Flicker | Clamp multiplier to 0 or 1 (binary on/off) |
| `flicker_rate` | float | 10.0 | Flicker | Oscillations per second (RANDOM) or cycles per second (CUSTOM) |
| `flicker_min` | float | 0.0 | Flicker | Minimum multiplier (RANDOM only) |
| `flicker_max` | float | 1.0 | Flicker | Maximum multiplier (RANDOM only) |
| `flicker_curve` | Curve | null | Flicker | Custom temporal pattern (CUSTOM only) |

```
enum FlickerMode {
    RANDOM,   # Random value between min/max each interval
    CUSTOM,   # Sample flicker_curve over time
}
```

#### Flicker logic

```gdscript
func _get_effective_progress(progress: float, delta: float) -> float:
    if not use_flicker:
        return progress

    _flicker_time += delta

    var multiplier: float
    match flicker_mode:
        FlickerMode.RANDOM:
            # New random value each interval (1.0 / flicker_rate)
            var interval := 1.0 / flicker_rate
            if _flicker_time >= interval:
                _flicker_time = fmod(_flicker_time, interval)
                _flicker_multiplier = randf_range(flicker_min, flicker_max)
            multiplier = _flicker_multiplier
        FlickerMode.CUSTOM:
            if flicker_curve:
                var t := fmod(_flicker_time * flicker_rate, 1.0)
                multiplier = flicker_curve.sample(t)
            else:
                multiplier = 1.0

    if hard_flicker:
        multiplier = 1.0 if multiplier >= 0.5 else 0.0

    return progress * multiplier
```

#### Use case examples

| Desired behavior | Configuration |
|-----------------|---------------|
| **Smooth random alpha pulse** | FADE + RANDOM flicker, hard_flicker=false |
| **Classic blink (hard on/off)** | FADE + RANDOM flicker, hard_flicker=true, min=0, max=1 |
| **Flickering light** | OVERBRIGHT + RANDOM flicker |
| **SOS morse code blink** | FADE + CUSTOM flicker, hand-drawn curve, hard_flicker=true |
| **Pulsing outline** | OUTLINE + CUSTOM flicker, smooth sine-like curve |
| **Strobe tint** | TINT + RANDOM flicker, hard_flicker=true |
| **Dissolve with glitchy flicker** | DISSOLVE + RANDOM flicker |

---

## 5. Control Flow

### Normal operation

1. **User adds** `Appearance2DJuiceComp` as child of a Sprite2D
2. **User selects** `appearance_effect = TINT` in inspector
3. **Inspector shows** TINT-specific params (`color_from`, `color_to`, `animate_alpha`, `affect_children`)
4. **User optionally enables** flicker group (`use_flicker = true`)
5. **Trigger fires** (ON_PRESS, ON_HOVER_START, etc.) → `JuiceBase` calls `_on_animate_start()`
6. **`_on_animate_start()`**: Capture base values from target. Set up materials/shaders if needed for the selected effect.
7. **Each frame**: `JuiceBase` calls `_apply_effect(progress)`
   - a. Compute `effective_progress = _get_effective_progress(progress, delta)`
   - b. Match on `appearance_effect`
   - c. Apply the selected effect using `effective_progress`
8. **Animation completes**: `JuiceBase` calls `_on_animate_out_complete()`
   - a. Restore all base values
   - b. Clean up created materials/shaders/StyleBoxes
   - c. Reset transient state

### Shader effect setup flow (OUTLINE/GRAYSCALE/DISSOLVE in 2D)

1. `_on_animate_start()` detects shader-based effect
2. Check if target already has a ShaderMaterial → if yes, save reference
3. If no ShaderMaterial, create one with the appropriate shader
4. If target had a different material, save it for restoration
5. Set initial uniform values (width=0, amount=0, threshold=0)
6. Each frame: set uniform = value * `effective_progress`
7. On complete: restore original material (or remove created one)

### Material setup flow (3D outline — Inverted Hull)

1. `_on_animate_start()` finds GeometryInstance3D (via `geometry_path` or type-safe search)
2. Get current material's `next_pass`
3. If `auto_create_outline` and no next_pass: create StandardMaterial3D with `cull_front`, set as `next_pass`
4. Save `_base_grow` from outline material
5. Each frame: `_outline_material.grow_amount = _base_grow + outline_width * effective_progress`
6. On complete: restore `_base_grow` (or remove created material)

### Blend mode setup flow (2D/Control)

1. `_on_animate_start()`: Save target's current `material` reference
2. If no CanvasItemMaterial exists, create one
3. Save original `blend_mode`
4. Set `blend_mode` to `target_blend_mode`
5. Store original `modulate.a`
6. Each frame: `modulate.a = _base_alpha * effective_progress` (fades the blend effect in)
7. On complete: Restore original `blend_mode` and `modulate.a`. Remove created CanvasItemMaterial if we created it.

### Edge cases

#### Retrigger during animation
`JuiceBase` handles retrigger via `retrigger_policy` (RESTART, IGNORE, QUEUE). The Appearance comp's `_on_animate_start()` will re-capture base values only if `_has_base_captured == false`. On RESTART, `_invalidate_base_cache()` is called first, forcing re-capture.

#### Target node has no material (3D)
For effects that need a `StandardMaterial3D` (TINT/OVERBRIGHT/3D-exclusive), if none is found:
- Create a new StandardMaterial3D and set as `material_override`
- `_is_material_duplicated = true`
- Restore/remove on complete

#### Target node has ShaderMaterial instead of StandardMaterial3D (3D)
For effects that need StandardMaterial3D: show configuration warning. Effect won't apply. User should use `ShaderPropertyJuiceComp` for custom shader targets.

#### Shader effect on node that already has a ShaderMaterial (2D)
If the target already has a ShaderMaterial (user's custom shader), we cannot replace it with our grayscale/dissolve shader without breaking their setup. Options:
- **If `resource_local_to_scene`**: Save and restore after animation
- **If shared**: Duplicate first, then save/restore
- Add a configuration warning: "Target already has a ShaderMaterial. GRAYSCALE/DISSOLVE will temporarily replace it during animation."

#### Multiple Appearance comps on same target
Supported — each comp manages its own base values and restores them independently. However, two comps modifying the same property (e.g., two TINT comps) will fight. This is the user's responsibility. JuiceBase's delta-first write pattern helps mitigate, but color effects use absolute writes (not deltas). Add a note in documentation.

#### Flicker with loop_count = -1 (infinite loop)
Works correctly. Flicker oscillates within each animation cycle. The base class handles looping; flicker just modulates within each cycle's progress.

#### Flicker time reset
`_flicker_time` resets to 0 in `_on_animate_start()` so each animation trigger starts flicker from the beginning.

### Failure / invalid input

| Scenario | Behavior |
|----------|----------|
| Target is not a CanvasItem (2D/Control comp) | Configuration warning, no effect |
| Target is not a Node3D (3D comp) | Configuration warning, no effect |
| No GeometryInstance3D found (3D outline/material) | Configuration warning via `_get_configuration_warnings()` |
| `flicker_curve` is null in CUSTOM mode | Multiplier defaults to 1.0 (no flicker), debug warning |
| `dissolve_texture` is null | Auto-create NoiseTexture2D with sensible defaults |
| Shader effect on complex Control | Configuration warning about per-primitive rendering |
| `appearance_effect` changed at runtime | Inspector refreshes via `notify_property_list_changed()`. Ongoing animation should be stopped/restarted. |

---

## 6. Integration Points

### Game loop

- Plugs in via `JuiceBase._process()` / `_physics_process()` → `_apply_effect(progress)`
- Flicker uses `delta` from the process callback for time accumulation
- No additional game loop hooks needed

### UI (Inspector)

- `appearance_effect` enum at top of "Effect" group → `notify_property_list_changed()` on change
- Effect-specific params shown/hidden via `_get_property_list()`
- "Flicker" group shown/hidden based on `use_flicker` via `_validate_property()`
- Flicker-mode-specific params shown/hidden via `_get_property_list()`

### Inspector layout (all domains)

```
Effect
├── appearance_effect: [TINT ▼]         # Top-most — always visible
├── (effect-specific params...)          # Conditional per effect
│
Flicker
├── use_flicker: [ ]                     # Checkbox
├── flicker_mode: [RANDOM ▼]            # Only when use_flicker=true
├── hard_flicker: [ ]                    # Only when use_flicker=true
├── flicker_rate: [10.0]                # Only when use_flicker=true
├── flicker_min: [0.0]                  # Only when RANDOM
├── flicker_max: [1.0]                  # Only when RANDOM
├── flicker_curve: [Curve ▼]            # Only when CUSTOM
│
Timing                                   # From JuiceBase
├── duration: [0.3]
├── curve: [Curve ▼]
├── ...
```

### Persistence / save-load

All configuration properties are serialized via `_get_property_list()` + `_get()` / `_set()` or `@export`. Runtime-only state (prefixed with `_`) is never serialized.

Properties that must survive round-trip:
- `appearance_effect` (int enum)
- All effect-specific params (color, float, NodePath, bool, Curve, Texture2D)
- All flicker params

Properties that must NOT leak into .tscn:
- `_base_color`, `_base_alpha`, `_shader_material`, `_flicker_time`, etc.

### Other Juice systems

- **SequencerJuiceComp**: Can orchestrate Appearance comps like any other JuiceComp
- **Interaction utilities**: Trigger Appearance comps via hover/click/proximity
- **ShaderPropertyJuiceComp**: Remains separate — for custom shader uniforms not covered by Appearance presets

### Contracts

- Extends `JuiceBase` — must implement: `_on_animate_start()`, `_apply_effect(progress)`, `_on_animate_out_complete()`, `_invalidate_base_cache()`
- Optionally implements: `_on_animate_in_complete()`, `_get_configuration_warnings()`
- Uses `_target_node` from base class
- Calls `notify_property_list_changed()` when `appearance_effect` or `flicker_mode` changes

---

## 7. Batch-Friendly Design

### Programmatic API

```gdscript
# Set effect type
comp.appearance_effect = Appearance2DJuiceComp.AppearanceEffect.TINT

# Configure effect
comp.color_from = Color.WHITE
comp.color_to = Color.RED

# Enable flicker
comp.use_flicker = true
comp.flicker_mode = Appearance2DJuiceComp.FlickerMode.RANDOM
comp.hard_flicker = true
comp.flicker_rate = 5.0

# Trigger
comp.animate_in()
```

All properties are settable programmatically. Enum values are accessible as class constants.

### Batch discovery

```gdscript
# Find all Appearance comps in scene
for node in get_tree().get_nodes_in_group(""):  # or iterate manually
    if node is Appearance2DJuiceComp:
        node.appearance_effect = Appearance2DJuiceComp.AppearanceEffect.FADE
```

Type-safe `is` checks work because each domain has its own `class_name`.

### Automated testing

Each effect can be tested by:
1. Instantiate a target node (Sprite2D for 2D, Button for Control, MeshInstance3D for 3D)
2. Add Appearance comp as child
3. Set `appearance_effect` and params
4. Call `animate_in()`, wait for completion, verify state change
5. Call `animate_out()` (or let one_shot handle it), verify restoration

Flicker testing:
1. Enable `use_flicker`, set `hard_flicker = true`
2. Run for N frames, sample `_flicker_multiplier` — verify it's always 0 or 1
3. Disable `hard_flicker`, verify values are in `[flicker_min, flicker_max]` range

### Batch editing

All configuration is data-driven via exported properties. Bulk configuration by iterating scene tree and setting properties works directly.

### Audit & inspection

`_get_configuration_warnings()` returns domain-appropriate warnings:
- Wrong target node type
- Shader effect on complex Control
- Missing GeometryInstance3D for 3D effects
- Both TINT color_from and color_to are identical (no visible effect)

A `get_configuration_summary() -> Dictionary` could be added:
```gdscript
func get_configuration_summary() -> Dictionary:
    return {
        "effect": AppearanceEffect.keys()[appearance_effect],
        "flicker": use_flicker,
        "target": str(_target_node.name) if _target_node else "null",
    }
```

### Serialization round-trip

All backing vars use `_get_property_list()` + `_get()` + `_set()` pattern (proven in existing comps). No runtime state has `PROPERTY_USAGE_STORAGE`. Verified by: save scene → reload → compare property values.

### Scale patterns

- **No shared state or singletons.** Each instance is fully independent.
- **Shader effects**: Each instance that uses OUTLINE/GRAYSCALE/DISSOLVE creates or references its own ShaderMaterial (duplicated if shared). No global shader state.
- **100 instances**: No concern. Each is a lightweight Node with simple math per frame.
- **1000 instances**: Shader-based effects create materials per-instance. This is normal Godot behavior — materials are lightweight. The main cost is draw calls on the target nodes, not the Juice comp logic.
- **Flicker with many instances**: Each accumulates its own `_flicker_time` and generates its own random values. RANDOM flicker on 1000 instances will generate 1000 `randf()` calls per interval — negligible.

---

## 8. Constraints & Tradeoffs

### Technical limitations (real engine constraints)

1. **Godot Curve has no constant/step interpolation mode.** Solved by `hard_flicker` flag that clamps output to 0 or 1.

2. **CanvasItem shaders apply per-draw-call on Controls.** Complex Controls (Button with icon + text + StyleBox) will have each primitive individually affected by GRAYSCALE/DISSOLVE. This is a Godot rendering architecture limitation, not something we can work around without a SubViewport (too heavy). We document this and add a configuration warning.

3. **2D has no `next_pass` equivalent.** Unlike 3D where a second material pass renders the mesh again, 2D CanvasItem can only have one material. Outline in 2D uses a shader that samples neighboring pixels — this works but has a different quality/performance profile than 3D Inverted Hull.

4. **Blend modes are discrete.** You cannot smoothly interpolate between MIX and ADD. We work around this by fading the node's alpha while the blend mode is active, which gives a perceptual smooth transition.

5. **Material conflicts.** If the target node already has a ShaderMaterial and we need to apply a different shader (GRAYSCALE/DISSOLVE), we must temporarily replace it. This is documented with a configuration warning. The original material is saved and restored.

6. **3D StandardMaterial3D assumption.** 3D material property effects (TINT via albedo, ROUGHNESS, etc.) require StandardMaterial3D. If the user has a ShaderMaterial or ORMMaterial3D, these effects won't work. Configuration warning provided. User should use ShaderPropertyJuiceComp for custom materials.

### Future extensibility (no breaking changes needed)

- **New effects**: Add enum values to `AppearanceEffect`, add params to `_get_property_list`, add match branch to `_apply_effect`. No existing behavior changes.
- **New flicker modes**: Add to `FlickerMode` enum. Existing RANDOM/CUSTOM untouched.
- **Shader DLC**: New shader effects slot into the enum just like GRAYSCALE/DISSOLVE. The pattern (create ShaderMaterial → animate uniform → restore) is the same for any shader effect.
- **Per-domain divergence**: Each domain file is independent. Adding a 3D-only effect doesn't touch 2D/Control files.

---

## 9. Implementation Readiness Check

### Prerequisites (must exist before coding)

1. **`JuiceBase`** — already exists, provides all needed lifecycle hooks ✅
2. **`outline_2d.gdshader`** — already exists in `addons/juice/Shaders/` ✅
3. **Grayscale shader** — needs to be created (trivial, ~5 lines) ⚠️
4. **Dissolve shader (2D)** — needs to be created (~15 lines) ⚠️
5. **Dissolve shader (3D)** — needs to be created (next_pass variant) ⚠️
6. **Grayscale shader (3D)** — needs to be created (next_pass variant) ⚠️

### New files to create

| File | Purpose |
|------|---------|
| `addons/juice/Shaders/grayscale_2d.gdshader` | 2D/Control grayscale effect |
| `addons/juice/Shaders/dissolve_2d.gdshader` | 2D/Control dissolve effect |
| `addons/juice/Shaders/grayscale_3d.gdshader` | 3D grayscale via next_pass |
| `addons/juice/Shaders/dissolve_3d.gdshader` | 3D dissolve via next_pass |

### Files to modify (rewrite)

| File | Scope |
|------|-------|
| `addons/juice/2D/Appearance2DJuiceComp.gd` | Full rewrite with new enum, all effects, flicker |
| `addons/juice/Control/AppearanceControlJuiceComp.gd` | Full rewrite with new enum, all effects, flicker |
| `addons/juice/3D/Appearance3DJuiceComp.gd` | Full rewrite with new enum, all effects, flicker |

### Files NOT touched (legacy — delete later when ready)

| File | Why kept |
|------|----------|
| `addons/juice/2D/Outline2DJuiceComp.gd` | Legacy, delete after new Appearance is proven |
| `addons/juice/Control/OutlineControlJuiceComp.gd` | Legacy, delete after new Appearance is proven |
| `addons/juice/3D/Outline3DJuiceComp.gd` | Legacy, delete after new Appearance is proven |
| `addons/juice/Visibility/VisibilityJuiceComp.gd` | Legacy, delete after new Appearance is proven |

### Open questions — NONE

All design decisions are locked:

| Decision | Resolution |
|----------|-----------|
| Domain-agnostic vs per-domain? | Per-domain (3 separate scripts) |
| DRY via helpers? | No — duplicate logic, no static helpers |
| Flicker modes? | RANDOM + CUSTOM (curve). No MORSE/PULSE presets. |
| Hard blink? | `hard_flicker` flag clamps to 0/1 |
| Blend Mode scope? | Launch effect, not deferred |
| Shader effects scope? | GRAYSCALE + DISSOLVE at launch. Rest → Shader DLC. |
| Rename REPLACE? | Absorbed — no more blend modes on TINT. Tint is just lerp(from, to). |
| Touch legacy comps? | No — keep until new Appearance is proven |

### Implementation order (suggested)

1. Create the 4 shader files (grayscale_2d, dissolve_2d, grayscale_3d, dissolve_3d)
2. Rewrite `Appearance2DJuiceComp.gd` — full enum, all effects, flicker
3. Rewrite `AppearanceControlJuiceComp.gd` — same structure, Control-specific implementations
4. Rewrite `Appearance3DJuiceComp.gd` — same structure, 3D-specific implementations + exclusive effects
5. Test each domain × each effect × with/without flicker
6. Update `Juice_Component_Inventory.md` to reflect absorbed comps
7. When all proven: delete legacy Outline and Visibility comps

---

**END OF DESIGN DOCUMENT**
