# Juice Component Inventory

> **Created:** 2026-02-21
> **Purpose:** Master checklist for shipping readiness (Phases 2–5)
> **Source:** `addons/juice/`

## Column Key

| Column | Meaning |
|--------|---------|
| **Finished** | Code is final, reviewed, no known bugs |
| **Demoed** | Has a polished demo in Juice Demo project |
| **Documented** | Inline (export tooltips, header comments) + manual + videos |
| **Presets** | Ready-to-copy preset scenes created |

---

## Base

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 1 | `JuiceCompBase` | | | | — | Abstract base class |

## Control Domain

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 2 | `TransformControlJuiceComp` | | | | | |
| 3 | `SquashStretchControlJuiceComp` | | | | | |
| 4 | `ShakeControlJuiceComp` | | | | | |
| 5 | `SpringControlJuiceComp` | | | | | |
| 6 | `NoiseControlJuiceComp` | | | | | |
| 7 | `ProgressControlJuiceComp` | | | | | |
| 8 | `AppearanceControlJuiceComp` | | | | | |
| 9 | `OutlineControlJuiceComp` | | | | | |

## 2D Domain

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 10 | `Transform2DJuiceComp` | | | | | |
| 11 | `SquashStretch2DJuiceComp` | | | | | |
| 12 | `Shake2DJuiceComp` | | | | | |
| 13 | `Spring2DJuiceComp` | | | | | |
| 14 | `Noise2DJuiceComp` | | | | | |
| 15 | `Progress2DJuiceComp` | | | | | |
| 16 | `Appearance2DJuiceComp` | | | | | |
| 17 | `Outline2DJuiceComp` | | | | | |

## 3D Domain

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 18 | `Transform3DJuiceComp` | | | | | |
| 19 | `SquashStretch3DJuiceComp` | | | | | |
| 20 | `Shake3DJuiceComp` | | | | | |
| 21 | `Spring3DJuiceComp` | | | | | |
| 22 | `Noise3DJuiceComp` | | | | | |
| 23 | `Progress3DJuiceComp` | | | | | |
| 24 | `Appearance3DJuiceComp` | | | | | |
| 25 | `Outline3DJuiceComp` | | | | | |

## Property Domain

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 26 | `ProgressPropertyJuiceComp` | | | | | |
| 27 | `ShakePropertyJuiceComp` | | | | | |
| 28 | `SpringPropertyJuiceComp` | | | | | |
| 29 | `NoisePropertyJuiceComp` | | | | | |
| 30 | `ShaderPropertyJuiceComp` | | | | | |

## Camera & Screen

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 31 | `Camera3DJuiceComp` | | | | | |
| 32 | `Camera2DJuiceComp` | | | | | |
| 33 | `CameraJuiceReceiverComp` | | | | — | Support node, attach to Camera |
| 34 | `ScreenMotionJuiceComp` | | | | | |
| 35 | `ScreenJuiceReceiver` | | | | — | Support node, attach to WorldEnvironment |
| 36 | `ScreenOverlayJuiceComp` | | | | | |
| 37 | `JuiceScreenOverlayProvider` | | | | — | RefCounted helper for overlay lifecycle |

## Events & Flow

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 38 | `SequencerJuiceComp` | | | | | |
| 39 | `RandomJuiceComp` | | | | | |
| 40 | `LooperJuiceComp` | | | | | |
| 41 | `PauseJuiceComp` | | | | | |
| 42 | `TimeJuiceComp` | | | | | |
| 43 | `EventTimeTestReactor` | | | | — | Test helper, not shipped? |

## VFX

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 44 | `VFXJuiceComp` | | | | | |
| 45 | `TrailJuiceComp` | | | | | |
| 46 | `TrailTestMover2D` | | | | — | Test helper, not shipped? |

## Visibility

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 47 | `VisibilityJuiceComp` | | | | | |

## Utilities

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 48 | `Interaction3DJuiceUtility` | | | | — | Trigger/interactable utility |
| 49 | `Interaction2DJuiceUtility` | | | | — | Trigger/interactable utility |
| 50 | `SoftTrigger3DJuiceUtility` | | | | — | Proximity soft trigger |
| 51 | `SoftTrigger2DJuiceUtility` | | | | — | Proximity soft trigger |
| 52 | `SoftTriggerControlJuiceUtility` | | | | — | Hover/focus soft trigger |
| 53 | `SignalEmitJuiceUtility` | | | | — | Emits custom signal on juice event |
| 54 | `SignalRelayJuiceUtility` | | | | — | Relays local signal to global bus |
| 55 | `CallMethodJuiceUtility` | | | | — | Calls a method on juice event |
| 56 | `TimeCoordinatorJuiceUtility` | | | | — | Optional time scale coordinator |

## Editor Tooling

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 57 | `JuicePreviewDirector` | | | | — | Editor preview lifecycle |
| 58 | `juice_plugin.gd` | | | | — | Master EditorPlugin (no class_name) |

## Shaders

| # | File | Finished | Demoed | Documented | Presets | Notes |
|---|------|:---:|:---:|:---:|:---:|-------|
| 59 | `screen_juice.gdshader` | | | | — | Screen-space post-process |
| 60 | `outline_2d.gdshader` | | | | — | 2D outline effect |
| 61 | `trail_uv_pan.gdshader` | | | | — | Trail UV scrolling |

---

**Total: 61 items** (53 scripts + 5 support/test + 3 shaders)
