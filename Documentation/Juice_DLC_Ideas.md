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
