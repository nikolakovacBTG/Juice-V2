# Juice V1 — Roadmap (Porting vs. Innovation)

> Features found in docs/ideas that are NOT yet in code. Tracked here to maintain "Port vs. Innovate" balance.

## Legend
- 🔴 = Not started
- 🟡 = Design exists, no code
- 🟢 = In progress
- ✅ = Done

## Priority 1: Port from V0 (Proven Effects)

### Appearance Effects 🟡
**Design doc: `Done/DONE_Appearance_Comp_Redesign.md`** — Design complete, code not ported.
- [ ] Unified Appearance effect (enum-driven: tint, overbright, fade, grayscale, dissolve, blend mode)
- [ ] Flicker temporal modulation layer
- [ ] Outline (absorbed into Appearance)
- [ ] Visibility (absorbed into Appearance)
- All 3 domains required

### Camera Effects 🔴
- [ ] CameraShake2D / CameraShake3D
- [ ] CameraZoom2D / CameraZoom3D

### Screen Effects 🔴
- [ ] ScreenFlash
- [ ] ScreenFreeze
- [ ] TimeScale

### VFX Effects 🔴
- [ ] Trail
- [ ] AfterImage
- [ ] ParticleEmit / ParticleBurst

### Event/Flow Utilities 🔴
- [ ] CallMethod
- [ ] EmitSignal
- [ ] PlaySound
- [ ] SpawnScene

### Property Effects 🔴
- [ ] Generic Property tweener

### Interaction Utilities 🔴
- [ ] Interaction2DJuiceUtility (remains as Node per design)
- [ ] Interaction3DJuiceUtility (remains as Node per design)

## Priority 2: Innovation (New for V1, from Ideas/Scratchpad)

### Shader Effects DLC Concepts 🔴
From `Juice_DLC_Ideas.md`:
- [ ] Pixelate
- [ ] Wave/wobble
- [ ] Chromatic aberration
- [ ] Hue shift
- [ ] Hologram
- [ ] Glitch

### Advanced Motion Concepts 🔴
- [ ] Orbit
- [ ] Bezier paths
- [ ] Elastic chains

### Audio Juice Concepts 🔴
- [ ] Pitch/volume reactive
- [ ] Beat-sync

### UI Shader Concepts 🔴
- [ ] StyleBox-based shader effects
- [ ] Faux-3D perspective tilt (Balatro-style)

### Physics-Driven Concepts 🔴
- [ ] Pendulum
- [ ] Jiggle
- [ ] Momentum-based effects

## Port Progress Summary

| Category | V0 Count | V1 Ported | Remaining |
|----------|----------|-----------|-----------|
| Transform | ~6 | ✅ 3×3=9 | 0 |
| Shake | ~3 | ✅ 3×3=9 | 0 (Camera shake separate) |
| Spring | ~3 | ✅ 3×3=9 | 0 |
| Noise | ~3 | ✅ 3×3=9 | 0 |
| SquashStretch | ~3 | ✅ 3×3=9 | 0 |
| Appearance | ~7 | 🔴 0 | ~7 (consolidated into 1 enum-driven effect ×3) |
| Camera | ~4 | 🔴 0 | ~4 |
| Screen | ~3 | 🔴 0 | ~3 |
| VFX | ~4 | 🔴 0 | ~4 |
| Events/Flow | ~4 | 🔴 0 | ~4 |
| Property | ~1 | 🔴 0 | ~1 |
| Interaction | ~2 | 🔴 0 | ~2 |
| **Total** | **~43** | **15** | **~25-28** |

## Shipping Phases (from JUICE_CONTEXT.md)

| Phase | Status |
|-------|--------|
| 0 — Extraction | ✅ Done |
| 1 — Inventory | ✅ Done |
| 2 — Code Review | 🔲 Not started |
| 2.5 — Test Harness | 🔲 Not started (framework exists, coverage incomplete) |
| 3 — Demo | 🟡 Partial |
| 4 — Docs | 🔲 Not started |
| 5 — Ship | 🔲 Not started |