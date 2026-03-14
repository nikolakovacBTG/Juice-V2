# Juice DLC Ideas

> **Purpose:** Running log of future expansion ideas — shader effects, advanced comps, content packs.
> **Not part of v1.0 scope.** These are post-ship expansion concepts.
> **Add ideas freely.** Each entry needs: brief description, domain applicability, complexity estimate.

---

## Shader Effects DLC (Visual Effects Pack)

High-value shader-based appearance effects that plug into the Appearance comp's enum system.

| Effect | Description | Domains | Complexity | Notes |
|--------|-------------|---------|------------|-------|
| **Pixelate** | Snap UV to grid for retro/censoring effect | 2D, 3D | Low | Single uniform: pixel_size |
| **Wave/Distort** | UV sine distortion for heat shimmer, underwater, dream | 2D, 3D | Low-Med | Uniforms: amplitude, frequency, speed |
| **Chromatic Aberration** | Offset RGB channels for damage/drunk/sci-fi feel | 2D, 3D | Low-Med | Uniform: offset_amount per channel |
| **Hue Shift** | Rotate hue in HSV space for power-up cycling, mood | 2D, 3D | Low | Uniform: hue_offset (0-360) |
| **Invert** | 1.0 - color for hit reaction, dimension shift | 2D, 3D | Trivial | Uniform: amount |
| **Brightness/Contrast** | Adjust brightness and contrast curves | 2D, 3D | Low | Uniforms: brightness, contrast |
| **Color Replace** | Swap one color range for another (team colors, palette swap) | 2D, 3D | Medium | Uniforms: source_color, target_color, tolerance |
| **Hologram** | Scanlines + transparency + color shift + noise | 2D, 3D | High | Multiple uniforms, time-based |
| **Glitch** | Time-based UV displacement + channel offset | 2D, 3D | High | Needs randomness, time seed |
| **Freeze/Ice** | Rim frost + blue tint + noise edge | 3D (2D partial) | High | Best with fresnel in 3D |
| **Burn** | Gradient noise + multi-color ramp dissolution | 2D, 3D | High | Variant of dissolve with color ramp |
| **Shield Hit** | Impact point + expanding ring + fresnel | 3D | High | Needs world-space hit position |
| **Force Field** | Animated fresnel + procedural noise | 3D | High | next_pass shader |
| **Blur** | Gaussian/box blur | 2D | High | Quality needs multi-pass or SubViewport |
| **CRT/Scanlines** | Retro TV effect with scanlines + curvature | 2D, Screen | Medium | Multiple overlapping effects |
| **Vignette** | Darken edges for cinematic feel | Screen | Low | Could be Appearance or Screen effect |

---

## Other DLC Concepts

### Advanced Motion Pack
- Bezier path following
- Orbit/circular motion
- Physics-based bounce with configurable restitution
- Magnetic attraction/repulsion toward target

### Audio Juice Pack
- Reactive visuals driven by audio amplitude
- Beat-synced triggering
- Audio spectrum analyzer driving multiple comps

### UI Juice Shader StyleBox

Extending Godot's StyleBox system with procedural juice effects. Could be driven by a
future Juice subclass or as new AppearanceControl effects (e.g., light streak — a linear
gradient running over a UI element to make it look shiny).

**Approach 1 — `StyleBoxTexture` + Shader:**
- Use `StyleBoxTexture` in your theme
- Drive its texture with a CanvasItem shader (gradient, animated color, scrolling effects)
- Optionally render the shader via a small `Viewport` → `ViewportTexture` if needed
- Assign the `StyleBoxTexture` to Button/Panel/etc states in your theme
- Optional: combine with `StyleBoxFlat` for crisp borders or corners

**Approach 2 — GDScript StyleBox Extensions:**
- Extend `StyleBox` in GDScript and override `_draw(to_canvas_item: RID, rect: Rect2)`
- Inside `_draw()`: draw gradients manually (`draw_rect`/`draw_line`/`draw_polygon`),
  draw textures (including shader-generated), apply procedural effects (noise, stripes, pulses)
- Can render a shader to a texture (via `ViewportTexture` or `TextureRect`) and draw it:
  `draw_texture_rect(my_shader_texture, rect)`
- Enables animated gradients, procedural patterns, time-based effects
  (use `Engine.get_time()` or pass uniforms from GDScript)

**Theme Compatibility:**
- Any custom StyleBox (GDScript or C++) can be assigned to a Theme normally
- `Button.normal`, `Panel.panel`, etc. → custom StyleBox
- Margins/padding still respected
- Controls remain fully scalable and dynamically laid out

**Benefits:** scalable, theme-compatible, dynamic, reusable, preserves margins/padding.
Allows fully animated, procedural, scalable UI while staying theme-friendly.

### Faux-3D Perspective Tilt (Card Flip / Balatro Style)

A fully 2D illusion that makes flat rectangular elements look like they rotate in 3D space.
Inspired by Balatro's card hover effect — the card subtly orients toward the cursor, creating
convincing depth from simple 2D manipulations. Domains: **Control, 2D**.

**Core Mechanism:**
- Dynamic `skew` + non-uniform scale tapering to fake perspective foreshortening
- Godot's `Transform2D` supports skew natively (4.x+), so no shader required for basic mode
- Optional shader-based quad distortion (4-corner pin) for pixel-perfect perspective at
  extreme angles ("quality mode")

**Input Modes:**
- `CURSOR_RELATIVE` — Balatro style: tilt toward mouse position relative to element center
- `SOFT_TRIGGER` — driven by `SoftTriggerJuiceComp` (normalized Vector2 → tilt angles)
- `ANIMATION` — driven by Juice progress for canned tilt sequences (e.g., card deal, card flip)

**Shadow Layer:**
- Sells the "floating above surface" depth illusion
- Modes: `NONE`, `FIXED_OFFSET`, `DYNAMIC` (shadow shifts opposite to tilt direction)
- Implementation: offset duplicate with darkened modulate, or flat ColorRect/StyleBoxFlat behind

**Backface Support:**
- Configurable flip threshold angle (default 90°) where frontface hides and backface shows
- Backface can be a Sprite, a Control node, or a packed scene (.tscn)
- Toggle via `visible` or shader-based UV flip

**Light Streak / Specular Highlight:**
- Subtle gradient overlay that shifts with tilt angle to fake surface reflection
- Massively sells the illusion (ties into the UI Juice Shader StyleBox DLC concept)

**Why It's Valuable:**
- Faux perspective distortion is broadly useful beyond card games — menus, item previews,
  inventory slots, achievement popups, dialog boxes
- Simple to configure (just add comp + optional shadow/backface), dramatic visual payoff
- No actual 3D nodes needed — stays in the 2D/Control rendering pipeline

### Particle Presets Pack
- Pre-configured GPUParticles2D/3D scenes for common effects
- Explosion, sparkle, rain, fire, smoke, confetti
- Wired into Juice triggering system

---

## How to Add Ideas

Add a row to the appropriate table, or create a new section if the idea doesn't fit existing categories. Include:
1. **Name** — short, descriptive
2. **Description** — one sentence of what it does
3. **Domains** — which domains it applies to (2D, 3D, Control, Screen)
4. **Complexity** — Trivial / Low / Medium / High
5. **Notes** — implementation hints, dependencies, gotchas
