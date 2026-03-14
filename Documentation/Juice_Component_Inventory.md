# Juice Component Inventory

> **Created:** 2026-02-21  |  **Updated:** 2026-03-14 (Appearance Control + 2D finished)
> **Purpose:** Master checklist for shipping readiness
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
| 1 | `JuiceCompBase` | | | | — | Abstract base class. hold_at_peak, retrigger, loop, ping-pong. |

## Control Domain

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 2 | `TransformControlJuiceComp` | | | | | **BUG: Still uses old offset paradigm. Needs From/To rewrite to match 2D/3D.** |
| 3 | `SquashStretchControlJuiceComp` | | | | | |
| 4 | `ShakeControlJuiceComp` | | | | | |
| 5 | `SpringControlJuiceComp` | | | | | |
| 6 | `NoiseControlJuiceComp` | | | | | |
| 7 | `ProgressControlJuiceComp` | | | | | |
| 8 | `AppearanceControlJuiceComp` | ✅ | | | | Enum-driven effects + Flicker + Blending Mode layer. Outline = ghost Panel + StyleBoxFlat (no shader, no 9-slice). Dynamic corner radius. Blend mode on ghost. |
| 9 | `OutlineControlJuiceComp` | | | | | Legacy — Appearance comp absorbs this |

## 2D Domain

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 10 | `Transform2DJuiceComp` | | | | | From/To model, delta-first write, pivot modes |
| 11 | `SquashStretch2DJuiceComp` | | | | | |
| 12 | `Shake2DJuiceComp` | | | | | |
| 13 | `Spring2DJuiceComp` | | | | | |
| 14 | `Noise2DJuiceComp` | | | | | |
| 15 | `Progress2DJuiceComp` | | | | | |
| 16 | `Appearance2DJuiceComp` | ✅ | | | | Enum-driven effects + Flicker + Blending Mode layer. Outline = outline_2d.gdshader (alpha-edge + vertex expansion). |
| 17 | `Outline2DJuiceComp` | | | | | Legacy — Appearance comp absorbs this |

## 3D Domain

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 18 | `Transform3DJuiceComp` | | | | | From/To model, delta-first write, quat slerp, pivot |
| 19 | `SquashStretch3DJuiceComp` | | | | | |
| 20 | `Shake3DJuiceComp` | | | | | |
| 21 | `Spring3DJuiceComp` | | | | | |
| 22 | `Noise3DJuiceComp` | | | | | |
| 23 | `Progress3DJuiceComp` | | | | | |
| 24 | `Appearance3DJuiceComp` | | | | | Enum-driven effects + Flicker + Blending Mode layer + 3D-exclusive |
| 25 | `Outline3DJuiceComp` | | | | | Legacy — Appearance comp absorbs this |

## Property Domain

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 26 | `ProgressPropertyJuiceComp` | | | | | |
| 27 | `ShakePropertyJuiceComp` | | | | | |
| 28 | `SpringPropertyJuiceComp` | | | | | |
| 29 | `NoisePropertyJuiceComp` | | | | | NoiseDirection enum, merged "Effect" group |
| 30 | `ShaderPropertyJuiceComp` | | | | | |

## Camera & Screen

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 31 | `Camera3DJuiceComp` | | | | | |
| 32 | `Camera2DJuiceComp` | | | | | |
| 33 | `CameraJuiceUtility` | | | | — | Attach to Camera (was CameraJuiceReceiverComp) |
| 34 | `ScreenMotionJuiceComp` | | | | | |
| 35 | `ScreenJuiceUtility` | | | | — | Attach to WorldEnvironment (was ScreenJuiceReceiver) |
| 36 | `ScreenOverlayJuiceComp` | | | | | |
| 37 | `JuiceScreenOverlayProvider` | | | | — | RefCounted helper for overlay lifecycle |

## Events & Flow

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 38 | `SequencerJuiceComp` | | | | | Pure orchestrator, no @export vars |
| 39 | `RandomJuiceComp` | | | | | |
| 40 | `LooperJuiceComp` | | | | | |
| 41 | `PauseJuiceComp` | | | | | |
| 42 | `TimeJuiceComp` | | | | | |

## VFX

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 43 | `VFXJuiceComp` | | | | | |
| 44 | `TrailJuiceComp` | | | | | |

## Visibility

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 45 | `VisibilityJuiceComp` | | | | | Legacy — Appearance FADE absorbs this |

## Utilities

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 46 | `Interaction3DJuiceUtility` | | | | — | Trigger/interactable utility |
| 47 | `Interaction2DJuiceUtility` | | | | — | Trigger/interactable utility |
| 48 | `SoftTrigger3DJuiceUtility` | | | | — | Proximity soft trigger |
| 49 | `SoftTrigger2DJuiceUtility` | | | | — | Proximity soft trigger |
| 50 | `SoftTriggerControlJuiceUtility` | | | | — | Hover/focus soft trigger |
| 51 | `SignalEmitJuiceUtility` | | | | — | Emits custom signal on juice event |
| 52 | `SignalRelayJuiceUtility` | | | | — | Relays local signal to global bus |
| 53 | `CallMethodJuiceUtility` | | | | — | Calls a method on juice event |
| 54 | `SceneActionJuiceUtility` | | | | — | Scene transition actions |
| 55 | `TimeCoordinatorJuiceUtility` | | | | — | Optional time scale coordinator |
| 56 | `_JuiceTransitionHandler` | | | | — | Internal helper for scene transitions |

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
| 61 | `grayscale_2d.gdshader` | | | | — | 2D/Control grayscale desaturation |
| 62 | `grayscale_3d.gdshader` | | | | — | 3D grayscale (next_pass) |
| 63 | `dissolve_2d.gdshader` | | | | — | 2D/Control noise dissolve |
| 64 | `dissolve_3d.gdshader` | | | | — | 3D noise dissolve (material_override) |
| 65 | `overlay_2d.gdshader` | | | | — | 2D/Control color overlay |
| 66 | `overlay_3d.gdshader` | | | | — | 3D color overlay (next_pass) |
| 67 | `trail_uv_pan.gdshader` | | | | — | Trail UV scrolling |
| 68 | `blend_mode_2d.gdshader` | | | | — | Standalone blend mode for non-shader effects (Tint, Overbright, Fade) |

---

**Total: 68 items** (56 scripts + 2 internal helpers + 10 shaders)

## Known Issues

- **TransformControlJuiceComp** still uses old offset paradigm (`position_offset`, `rotation_offset_degrees`, `scale_offset` + single `transform_target_node`). Needs full From/To rewrite to match Transform2D and Transform3D.
- **Outline2D/3D/ControlJuiceComp** are legacy — their functionality is absorbed by the Appearance comps. Delete after Appearance is proven in demo.
- **VisibilityJuiceComp** is legacy — FADE effect in Appearance comps replaces it.
