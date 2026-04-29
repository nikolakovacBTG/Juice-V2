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
| `ProgressPropertyJuiceComp` | `PropertyProgressJuiceEffect` | 🧪 | `TestProgressProperty` | 2026-04-23 |

> **Inspector note (2026-04-17):** Rate, Pivot, Bound demoted from top-level GROUPs to flat properties inside the Effect group. `bound_enabled` tooltip improved. `_leaf_owns_layout` applied to suppress duplicate Effect header.

## Outline (3 effects — Legacy, absorbed by Appearance)

| V0 Class | V1 Class | Status | Notes |
|----------|----------|--------|-------|
| `OutlineControlJuiceComp` | — | ➖ | Absorbed by AppearanceControl |
| `Outline2DJuiceComp` | — | ➖ | Absorbed by Appearance2D |
| `Outline3DJuiceComp` | — | ➖ | Absorbed by Appearance3D |

## Camera (2 effects + CameraJuiceUtility)

> **Design note:** `CameraJuiceUtility` is auto-bootstrapped onto the active camera on first effect tick — no manual placement required. Camera switches mid-animation are handled automatically.

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `Camera2DJuiceComp` | `Camera2DJuiceEffect` | ✅ | `TestCameraJuice` | 2026-04-16 |
| `Camera3DJuiceComp` | `Camera3DJuiceEffect` | 🧪 | `TestCameraJuice` (2D only tested headless) | 2026-04-16 |
| `CameraJuiceUtility` | `CameraJuiceUtility` | ✅ | `TestCameraJuice` | 2026-04-16 |

## Screen (2 effects + ScreenJuiceUtility)

> **Design note:** `ScreenJuiceUtility` is auto-bootstrapped at `SceneTree.root` on first effect tick — no manual CanvasLayer/ColorRect setup required. Survives scene changes. Manual placement respected as opt-in.

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `ScreenMotionJuiceComp` | `ScreenMotionJuiceEffect` | 🔧 | — | — |
| `ScreenOverlayJuiceComp` | `ScreenOverlayJuiceEffect` | 🧪 | `TestScreenOverlay` | — |
| `ScreenJuiceUtility` | `ScreenJuiceUtility` | 🔧 | — | — |

## Property Family (7 effects — includes 4 NEW)

> **Architecture note (2026-04-23):** The Property family uses a shared `PropertyTarget` resource with a custom picker dialog (`PropertyPickerDialog`). Integer variant types (Vector2i, Vector3i, int) are auto-normalized to float equivalents.
>
> **Open polish (2026-04-23):** NodePath editor-time resolution is fragile (selection-based). Dialog theming via ConfirmationDialog landed but needs visual verification. Multi-select target addition needs UX testing.

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `NoisePropertyJuiceComp` | `PropertyNoise{Control\|2D\|3D}JuiceEffect` | 🧪 | `TestPropertyFamily` | 2026-04-23 |
| `ShakePropertyJuiceComp` | `PropertyShake{Control\|2D\|3D}JuiceEffect` | 🧪 | `TestPropertyFamily` | 2026-04-23 |
| NEW | `PropertyInterpolate{Control\|2D\|3D}JuiceEffect` | 🧪 | `TestPropertyFamily` | 2026-04-23 |
| `SpringPropertyJuiceComp` | — | ➖ | Physically reactive — deferred to future product |
| `ShaderPropertyJuiceComp` | — | ➖ | Absorbed into PropertyInterpolate/Noise/Shake via shader_parameter/ path support |

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
| `PauseJuiceComp` | `PauseJuiceEffectBase` + `Pause{Control|2D|3D}JuiceEffect` | ✅ | `TestPauseEffect` | 2026-04-29 |
| NEW | `TriggerStackJuiceEffect` | ➖ | Surpassed by Signal Emit and Method Call utilities |
| NEW | `TriggerSequencerJuiceEffect` | ➖ | Surpassed by Signal Emit and Method Call utilities |

## Meta Effects (5 — includes 3 NEW)

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|-----------|
| `TimeJuiceComp` | `TimeJuiceEffectBase` + `Time{Control\|2D\|3D}JuiceEffect` | ✅ | `TestTimeEffect` | 2026-03-30 |
| NEW | `SignalEmitJuiceUtilityBase` + `SignalEmit{Control\|2D\|3D}JuiceUtility` | ✅ | `TestMetaEffects` | 2026-04-17 |
| NEW | `CallMethodJuiceUtilityBase` + `CallMethod{Control\|2D\|3D}JuiceUtility` | ✅ | `TestMetaEffects` | 2026-04-17 |
| `ProgressPropertyJuiceComp` | `PropertyProgressJuiceEffectBase` + `PropertyProgress{Control\|2D\|3D}JuiceEffect` | 🧪 | `TestProgressProperty` | 2026-04-23 |
| `PauseJuiceComp` | `PauseJuiceEffectBase` + `Pause{Control\|2D\|3D}JuiceEffect` | ✅ | `TestPauseEffect` | 2026-04-29 |

> **Inspector note (2026-04-17):** SignalEmit + CallMethod refactored — single "Trigger" group, crossfade_time hidden (no-op for meta effects), icons corrected (JuiceUtilitySignals / JuiceUtilityMethods / JuiceUtilityTimeCoord). Time2D/3D icons also corrected to JuiceUtilityTimeCoord.

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
| `CameraJuiceUtility` | Same | ✅ | `TestCameraJuice` | 2026-04-16 |
| `ScreenJuiceUtility` | Same | 🔧 | — | — |
| `TimeCoordinatorJuiceUtility` | Same | 🧪 | — | — |

## Editor Tooling

> **Transport + Camera/Screen preview — implemented (2026-04-29):**
> `JuicePreviewDirector.play()` / `play_in()` / `play_out()` now call `_bootstrap_preview_utilities()`, which:
> - **Camera:** finds the active Camera2D or Camera3D in the primary node's viewport and pre-places a `CameraJuiceUtility` on it (`owner=null` → not serialized). The effect's `_find_or_create_utility()` now checks for an existing utility *before* the `is_editor_hint()` bail, so it finds the Director-placed one without self-bootstrapping.
> - **Screen:** bootstraps `ScreenJuiceUtility` + `CanvasLayer` inside `EditorInterface.get_editor_viewport_2d()` (not `SceneTree.root`) and sets the static `instance`. The effect already checks `instance` first, so it finds it automatically.
> Both are freed by `_cleanup_preview_utilities()` on every `stop()` / `deselect()`. `owner=null` means the serializer never sees them — scene cannot be dirtied.

| V0 Class | V1 Class | Status | Tests | Last Verified |
|----------|----------|--------|-------|---------------|
| `JuicePreviewDirector` | `JuicePreviewDirector` + `juice_plugin.gd` | 🧪 | `TestTransport` (31 tests) | 2026-04-27 |
| `juice_plugin.gd` | `juice_plugin.gd` | 🧪 | Transport UI: play/stop/loop/scrub/sustained-warning | 2026-04-27 |

---

## Summary

| Category | Total | Ported | Pending UX | In Progress | Not Started | Legacy/Cut |
|----------|-------|--------|------------|-------------|-------------|--------|
| Effects | ~43 | 30 | 7 | 1 | 2 | 12 |
| Utilities | ~10 | 9 | 0 | 1 | 1 | 0 |
| Infrastructure | 4 | 4 | 0 | 0 | 0 | 0 |
| Editor Tooling | 2 | 0 | 2 | 0 | 0 | 0 |
| **Total** | **~59** | **43** | **9** | **2** | **3** | **12** |

> **Last updated:** 2026-04-27 — Editor Transport (`JuicePreviewDirector` + `juice_plugin.gd`) implemented and verified with 31 automated tests. Sequencer replay bug fixed in all 3 exit paths (natural completion, explicit stop, loop boundary). Sustained-effect warning label finalized. Test suite: 498/498 passing.

