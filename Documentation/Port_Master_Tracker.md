# V0 → V1 Port Master Tracker

> **Purpose:** Single-glance status of every V0 component's V1 port.
> Updated after every `/port` cycle. Dates prove recency.
>
> **Legend:** ✅ Ported + Verified | 🧪 Ported (Pending UX verify) | 🔧 In progress | ❌ Not started | ➖ Absorbed/Legacy

---

## Infrastructure (Base Classes)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `JuiceBase` | `JuiceBase` + `JuiceEffectBase` | ✅ | `TestNodeProperties` | 2026-04-12 |

## Domain Nodes

| V0 (implicit in comps) | V1 Class | Status | Tests | Last Verified |
|------------------------|----------|--------|-------|---------------|
| — | `JuiceControl` | ✅ | `TestTransformControl` | 2026-04-12 |
| — | `Juice2D` | ✅ | `TestTransform2D` | 2026-04-12 |
| — | `Juice3D` | ✅ | `TestTransform3D` | 2026-03-21 |

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

## Spring (3 effects — Cut, deferred)

| V0 Class | V1 Class | Status | Notes |
|----------|----------|--------|-------|
| `SpringControlJuiceComp` | — | ➖ | Physically reactive — deferred to future product |
| `Spring2DJuiceComp` | — | ➖ | Physically reactive — deferred to future product |
| `Spring3DJuiceComp` | — | ➖ | Physically reactive — deferred to future product |

## Appearance (3 effects)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `AppearanceControlJuiceComp` | `AppearanceControlJuiceEffect` | ✅ | `TestAppearanceEffects` | 2026-03-29 |
| `Appearance2DJuiceComp` | `Appearance2DJuiceEffect` | ✅ | `TestAppearanceEffects` | 2026-03-29 |
| `Appearance3DJuiceComp` | `Appearance3DJuiceEffect` | ✅ | `TestAppearanceEffects` | 2026-03-29 |

## Progress (4 effects)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `ProgressControlJuiceComp` | `ProgressControlJuiceEffect` | 🧪 | `TestProgressControl` | — |
| `Progress2DJuiceComp` | `Progress2DJuiceEffect` | 🧪 | `TestProgress2D` | — |
| `Progress3DJuiceComp` | `Progress3DJuiceEffect` | 🧪 | `TestProgress3D` | — |
| `ProgressPropertyJuiceComp` | `ProgressPropertyJuiceEffect` | 🧪 | `TestProgressProperty` | — |

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
| `ScreenOverlayJuiceComp` | `ScreenOverlayJuiceEffect` | 🧪 | `TestScreenOverlay` | — |

## Property (4 effects)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `NoisePropertyJuiceComp` | `NoisePropertyJuiceEffect` | ❌ | — | — |
| `ShakePropertyJuiceComp` | `ShakePropertyJuiceEffect` | ❌ | — | — |
| `SpringPropertyJuiceComp` | — | ➖ | Physically reactive — deferred to future product |
| `ShaderPropertyJuiceComp` | `ShaderPropertyJuiceEffect` | ❌ | — | — |

## Visibility (1 effect — Legacy, absorbed by Appearance)

| V0 Class | V1 Class | Status | Notes |
|----------|----------|--------|-------|
| `VisibilityJuiceComp` | — | ➖ | FADE in Appearance absorbs this |

## VFX (2 effects)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `VFXJuiceComp` | `VFXJuiceEffect` | ❌ | — | — |
| `TrailJuiceComp` | `TrailJuiceEffect` | ❌ | — | — |

## Events & Flow (Legacy, absorbed by JuiceBase)

| V0 Class | V1 Class | Status | Notes |
|----------|----------|--------|-------|
| `SequencerJuiceComp` | `JuiceBase` | ➖ | Absorbed into `Mode.SEQUENCER` |
| `LooperJuiceComp` | `JuiceBase` | ➖ | Absorbed into `Loop` group |
| `RandomJuiceComp` | `JuiceBase` | ➖ | Absorbed into `SequenceType.RANDOM` |
| `PauseJuiceComp` | `PauseJuiceEffect` | ❌ | Port pending |
| NEW | `TriggerStackJuiceEffect` | ➖ | Native logic in `Mode.STACK` |
| NEW | `TriggerSequencerJuiceEffect` | ➖ | Native logic in `Mode.SEQUENCER` |

## Meta Effects (4 — includes 2 NEW)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|-----------|
| `TimeJuiceComp` | `TimeJuiceEffectBase` + `Time{Control\|2D\|3D}JuiceEffect` | ✅ | `TestTimeEffect` | 2026-03-30 |
| `SignalEmitJuiceUtility` | `SignalEmitJuiceEffectBase` + `SignalEmit{Control\|2D\|3D}JuiceEffect` | ✅ | `TestMetaEffects` | 2026-03-30 |
| `CallMethodJuiceUtility` | `CallMethodJuiceEffectBase` + `CallMethod{Control\|2D\|3D}JuiceEffect` | ✅ | `TestMetaEffects` | 2026-03-30 |

## Utilities (Nodes & Helpers)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `Interaction3DJuiceUtility` | Same | 🧪 | `TestInteraction3D` | — |
| `Interaction2DJuiceUtility` | Same | 🧪 | `TestInteraction2D` | — |
| `SoftTrigger3DJuiceUtility` | Same | 🧪 | `TestSoftTrigger3D` | — |
| `SoftTrigger2DJuiceUtility` | Same | 🧪 | `TestSoftTrigger2D` | — |
| `SoftTriggerControlJuiceUtility` | Same | 🧪 | `TestSoftTriggerControl` | — |
| `SignalRelayJuiceUtility` | Same | 🧪 | `TestSignalRelay` | — |
| `SceneActionJuiceUtility` | Same | ✅ | `TestSceneAction` | 2026-04-12 |
| `CameraJuiceUtility` | Same | ❌ | — | — |
| `ScreenJuiceUtility` | Same | ❌ | — | — |
| `TimeCoordinatorJuiceUtility` | Same | 🧪 | — | — |

## Editor Tooling

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `JuicePreviewDirector` | TBD | ❌ | — | — |
| `juice_plugin.gd` | `juice_plugin.gd` | 🔧 Basic registration | — | — |

---

## Summary

| Category | Total | Ported | In Progress | Not Started | Legacy/Cut |
|----------|-------|--------|-------------|-------------|--------|
| Effects | ~43 | 28 | 0 | 8 | 11 |
| Utilities | ~10 | 8 | 0 | 2 | 0 |
| Infrastructure | 4 | 4 | 0 | 0 | 0 |
| **Total** | **~57** | **40** | **0** | **10** | **11** |
