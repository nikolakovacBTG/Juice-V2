# V0 → V1 Port Master Tracker

> **Purpose:** Single-glance status of every V0 component's V1 port.
> Updated after every `/port` cycle. Dates prove recency.
>
> **Legend:** ✅ Ported + tested | 🔧 In progress | ❌ Not started | ➖ Absorbed/Legacy

---

## Infrastructure (Base Classes)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `JuiceCompBase` | `JuiceBase` + `JuiceEffectBase` | 🔧 Foundation bugs (B1, B2, D1-D3) | `TestNodeProperties` | 2026-03-21 |

## Domain Nodes

| V0 (implicit in comps) | V1 Class | Status | Tests | Last Verified |
|------------------------|----------|--------|-------|---------------|
| — | `JuiceControl` | 🔧 Working, Container hold untested | `TestTransformControl` | 2026-03-21 |
| — | `Juice2D` | 🔧 Working | `TestTransform2D` | 2026-03-21 |
| — | `Juice3D` | 🔧 Working | `TestTransform3D` | 2026-03-21 |

## Transform (3 effects)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `TransformControlJuiceComp` | `TransformControlJuiceEffect` | ✅ | `TestTransformControl` | 2026-03-21 |
| `Transform2DJuiceComp` | `Transform2DJuiceEffect` | ✅ | `TestTransform2D` | 2026-03-21 |
| `Transform3DJuiceComp` | `Transform3DJuiceEffect` | ✅ | `TestTransform3D` | 2026-03-21 |

## SquashStretch (3 effects)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `SquashStretchControlJuiceComp` | `SquashStretchControlJuiceEffect` | ✅ | `TestSquashStretchControl` | 2026-03-21 |
| `SquashStretch2DJuiceComp` | `SquashStretch2DJuiceEffect` | ✅ | `TestSquashStretch2D` | 2026-03-21 |
| `SquashStretch3DJuiceComp` | `SquashStretch3DJuiceEffect` | ✅ | `TestSquashStretch3D` | 2026-03-21 |

## Noise (3 effects)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `NoiseControlJuiceComp` | `NoiseControlJuiceEffect` | ✅ | `TestNoiseControl` | 2026-03-29 |
| `Noise2DJuiceComp` | `Noise2DJuiceEffect` | ✅ | `TestNoise2D` | 2026-03-29 |
| `Noise3DJuiceComp` | `Noise3DJuiceEffect` | ✅ | `TestNoise3D` | 2026-03-29 |

## Shake (3 effects)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `ShakeControlJuiceComp` | `ShakeControlJuiceEffect` | ✅ | `TestShakeControl` | 2026-03-29 |
| `Shake2DJuiceComp` | `Shake2DJuiceEffect` | ✅ | `TestShake2D` | 2026-03-29 |
| `Shake3DJuiceComp` | `Shake3DJuiceEffect` | ✅ | `TestShake3D` | 2026-03-29 |

## Spring (3 effects)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `SpringControlJuiceComp` | `SpringControlJuiceEffect` | ✅ | `TestSpringControl` | 2026-03-29 |
| `Spring2DJuiceComp` | `Spring2DJuiceEffect` | ✅ | `TestSpring2D` | 2026-03-29 |
| `Spring3DJuiceComp` | `Spring3DJuiceEffect` | ✅ | `TestSpring3D` | 2026-03-29 |

## Appearance (3 effects)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `AppearanceControlJuiceComp` | `AppearanceControlJuiceEffect` | ✅ | `TestAppearanceEffects` | 2026-03-29 |
| `Appearance2DJuiceComp` | `Appearance2DJuiceEffect` | ✅ | `TestAppearanceEffects` | 2026-03-29 |
| `Appearance3DJuiceComp` | `Appearance3DJuiceEffect` | ✅ | `TestAppearanceEffects` | 2026-03-29 |

## Progress (4 effects)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `ProgressControlJuiceComp` | `ProgressControlJuiceEffect` | ❌ | — | — |
| `Progress2DJuiceComp` | `Progress2DJuiceEffect` | ❌ | — | — |
| `Progress3DJuiceComp` | `Progress3DJuiceEffect` | ❌ | — | — |
| `ProgressPropertyJuiceComp` | `ProgressPropertyJuiceEffect` | ❌ | — | — |

## Outline (3 effects — Legacy, absorbed by Appearance)

| V0 Class | V1 Class | Status | Notes |
|----------|----------|--------|-------|
| `OutlineControlJuiceComp` | — | ➖ | Absorbed by AppearanceControl |
| `Outline2DJuiceComp` | — | ➖ | Absorbed by Appearance2D |
| `Outline3DJuiceComp` | — | ➖ | Absorbed by Appearance3D |

## Camera (2 effects)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `Camera2DJuiceComp` | `Camera2DJuiceEffect` | ❌ | — | — |
| `Camera3DJuiceComp` | `Camera3DJuiceEffect` | ❌ | — | — |

## Screen (2 effects)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `ScreenMotionJuiceComp` | `ScreenMotionJuiceEffect` | ❌ | — | — |
| `ScreenOverlayJuiceComp` | `ScreenOverlayJuiceEffect` | ❌ | — | — |

## Property (4 effects)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `NoisePropertyJuiceComp` | `NoisePropertyJuiceEffect` | ❌ | — | — |
| `ShakePropertyJuiceComp` | `ShakePropertyJuiceEffect` | ❌ | — | — |
| `SpringPropertyJuiceComp` | `SpringPropertyJuiceEffect` | ❌ | — | — |
| `ShaderPropertyJuiceComp` | `ShaderPropertyJuiceEffect` | ❌ | — | — |

## Visibility (1 effect — Legacy)

| V0 Class | V1 Class | Status | Notes |
|----------|----------|--------|-------|
| `VisibilityJuiceComp` | — | ➖ | FADE in Appearance absorbs this |

## VFX (2 effects)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `VFXJuiceComp` | `VFXJuiceEffect` | ❌ | — | — |
| `TrailJuiceComp` | `TrailJuiceEffect` | ❌ | — | — |

## Meta Effects (4 — includes 2 NEW)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `PauseJuiceComp` | `PauseJuiceEffect` | ❌ | — | — |
| `TimeJuiceComp` | `TimeJuiceEffect` | ❌ | — | — |
| NEW | `TriggerStackJuiceEffect` | ❌ | — | — |
| NEW | `TriggerSequencerJuiceEffect` | ❌ | — | — |

## Utility-Comps That Become Effects (2)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `SignalEmitJuiceUtility` | `SignalEmitJuiceEffect` | ❌ | — | — |
| `CallMethodJuiceUtility` | `CallMethodJuiceEffect` | ❌ | — | — |

## Utilities (Stay as Nodes)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `Interaction3DJuiceUtility` | Same (no change needed) | ❌ | — | — |
| `Interaction2DJuiceUtility` | Same (no change needed) | ❌ | — | — |
| `SoftTrigger3DJuiceUtility` | Same | ❌ | — | — |
| `SoftTrigger2DJuiceUtility` | Same | ❌ | — | — |
| `SoftTriggerControlJuiceUtility` | Same | ❌ | — | — |
| `SignalRelayJuiceUtility` | Same | ❌ | — | — |
| `SceneActionJuiceUtility` | Same | ❌ | — | — |
| `CameraJuiceUtility` | Same | ❌ | — | — |
| `ScreenJuiceUtility` | Same | ❌ | — | — |
| `TimeCoordinatorJuiceUtility` | NEW | ❌ | — | — |

## Editor Tooling

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `JuicePreviewDirector` | TBD | ❌ | — | — |
| `juice_plugin.gd` | `juice_plugin.gd` | 🔧 Basic registration | — | — |

---

## Summary

| Category | Total | Ported | In Progress | Not Started | Legacy |
|----------|-------|--------|-------------|-------------|--------|
| Effects | ~40 | 6 | 0 | ~30 | 4 |
| Utilities | ~10 | 0 | 0 | ~10 | 0 |
| Infrastructure | 4 | 0 | 4 | 0 | 0 |
| **Total** | **~54** | **6** | **4** | **~40** | **4** |
