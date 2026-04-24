# Documentation Sweep Tracker

Generated: 2026-04-24

## Status Legend
- **TODO** — Not yet reviewed
- **PARTIAL** — Gemini touched this file but work needs validation
- **BLOCKED** — Doc-clean but contains valid TODO that user must resolve first
- **DONE** — Fully reviewed and approved by user
- **SKIP** — No methods or auto-generated

## 2D

| File | Methods | Uncommented | Status | Notes |
|------|---------|-------------|--------|-------|
| `Appearance2DJuiceEffect.gd` | 28 | 21 | TODO | — |
| `Noise2DJuiceEffect.gd` | 19 | 19 | TODO | — |
| `Progress2DJuiceEffect.gd` | 23 | 17 | TODO | — |
| `Shake2DJuiceEffect.gd` | 16 | 16 | TODO | — |
| `SquashStretch2DJuiceEffect.gd` | 10 | 4 | TODO | — |
| `Transform2DJuiceEffect.gd` | 37 | 37 | TODO | — |

## 3D

| File | Methods | Uncommented | Status | Notes |
|------|---------|-------------|--------|-------|
| `Appearance3DJuiceEffect.gd` | 26 | 20 | TODO | — |
| `Noise3DJuiceEffect.gd` | 18 | 18 | TODO | — |
| `Progress3DJuiceEffect.gd` | 25 | 22 | TODO | — |
| `Shake3DJuiceEffect.gd` | 16 | 16 | TODO | — |
| `SquashStretch3DJuiceEffect.gd` | 10 | 4 | TODO | — |
| `Transform3DJuiceEffect.gd` | 38 | 38 | TODO | — |

## Base Classes

| File | Methods | Uncommented | Status | Notes |
|------|---------|-------------|--------|-------|
| `Juice2D.gd` | 14 | 7 | DONE | Already clean, all ## on virtual overrides |
| `Juice2DAppearanceEffect.gd` | 2 | 0 | DONE | Downgraded _clear_modulate and _get_seq_contribution ##→# |
| `Juice2DEffectBase.gd` | 0 | 0 | SKIP | No methods |
| `Juice2DRecipe.gd` | 1 | 0 | DONE | Already clean, no changes needed |
| `Juice2DTransformEffect.gd` | 47 | 33 | TODO | — |
| `Juice3D.gd` | 17 | 6 | DONE | Downgraded 4 internal 3D appearance helpers ##→# |
| `Juice3DAppearanceEffect.gd` | 2 | 0 | DONE | Downgraded _clear_appearance and _get_seq_contribution ##→# |
| `Juice3DEffectBase.gd` | 0 | 0 | SKIP | No methods |
| `Juice3DRecipe.gd` | 1 | 0 | DONE | Already clean, no changes needed |
| `Juice3DTransformEffect.gd` | 48 | 35 | TODO | — |
| `JuiceBase.gd` | 73 | 28 | PARTIAL | Gemini added comments to Public API section, needs validation |
| `JuiceControl.gd` | 15 | 7 | BLOCKED | Doc-clean, but 2 valid TODOs: META_KEY→JuiceLedger (L281, L352) |
| `JuiceControlAppearanceEffect.gd` | 2 | 0 | DONE | Downgraded _clear_modulate and _get_seq_contribution ##→# |
| `JuiceControlEffectBase.gd` | 0 | 0 | SKIP | No methods |
| `JuiceControlRecipe.gd` | 1 | 0 | DONE | Already clean, no changes needed |
| `JuiceControlTransformEffect.gd` | 42 | 30 | TODO | — |
| `JuiceEffectBase.gd` | 46 | 16 | PARTIAL | Gemini added comments, RATIONALE: stripped, needs validation |
| `JuiceLedger.gd` | 10 | 0 | DONE | Validated Gemini work, tightened 3 redundant comments |
| `JuiceRecipe.gd` | 3 | 0 | BLOCKED | Doc-clean, but 1 valid TODO: chain-walk preview duration (L96) |
| `JuiceTriggerRouter.gd` | 3 | 0 | DONE | Already clean, no changes needed |
| `TriggerHintBuilder.gd` | 2 | 1 | DONE | Already clean, _full_hint_for_domain deliberately skipped (trivial) |

## Camera

| File | Methods | Uncommented | Status | Notes |
|------|---------|-------------|--------|-------|
| `Camera2DJuiceEffect.gd` | 17 | 13 | TODO | — |
| `Camera3DJuiceEffect.gd` | 17 | 15 | TODO | — |
| `CameraJuiceUtility.gd` | 6 | 5 | TODO | — |

## Control

| File | Methods | Uncommented | Status | Notes |
|------|---------|-------------|--------|-------|
| `AppearanceControlJuiceEffect.gd` | 28 | 22 | TODO | — |
| `NoiseControlJuiceEffect.gd` | 18 | 16 | TODO | — |
| `ProgressControlJuiceEffect.gd` | 24 | 24 | TODO | — |
| `ShakeControlJuiceEffect.gd` | 14 | 14 | TODO | — |
| `SquashStretchControlJuiceEffect.gd` | 11 | 4 | TODO | ⚠️ Contains valid TODO: _get_interrupt_identity sharing (L193) |
| `TransformControlJuiceEffect.gd` | 35 | 35 | TODO | — |

## Editor

| File | Methods | Uncommented | Status | Notes |
|------|---------|-------------|--------|-------|
| `JuiceEditorContext.gd` | 2 | 0 | TODO | — |
| `JuiceProjectSettings.gd` | 2 | 0 | TODO | — |
| `PropertyPickerDialog.gd` | 8 | 5 | TODO | — |
| `PropertyPickerPlugin.gd` | 12 | 7 | TODO | — |

## Juice_V1

| File | Methods | Uncommented | Status | Notes |
|------|---------|-------------|--------|-------|
| `juice_plugin.gd` | 2 | 2 | DONE | Boilerplate, no doc needed |

## Meta

| File | Methods | Uncommented | Status | Notes |
|------|---------|-------------|--------|-------|
| `_JuiceSceneActionOrchestrator.gd` | 25 | 0 | DONE | Removed 6 redundant Gemini restatements |
| `CallMethod2DJuiceUtility.gd` | 0 | 0 | SKIP | No methods |
| `CallMethod3DJuiceUtility.gd` | 0 | 0 | SKIP | No methods |
| `CallMethodControlJuiceUtility.gd` | 0 | 0 | SKIP | No methods |
| `CallMethodEntry.gd` | 4 | 4 | DONE | Already clean, all methods boilerplate (SKIP) |
| `CallMethodJuiceUtilityBase.gd` | 12 | 10 | DONE | Added 1 comment on _do_call |
| `InterpolateProperty2DJuiceEffect.gd` | 0 | 0 | SKIP | No methods |
| `InterpolateProperty3DJuiceEffect.gd` | 0 | 0 | SKIP | No methods |
| `InterpolatePropertyControlJuiceEffect.gd` | 0 | 0 | SKIP | No methods |
| `InterpolatePropertyJuiceEffectBase.gd` | 6 | 1 | DONE | Removed 2 redundant restatement comments |
| `InterpolatePropertyTarget.gd` | 13 | 9 | DONE | Downgraded _value_props ##→#, added # on _resolve_editor_node |
| `NoiseProperty2DJuiceEffect.gd` | 0 | 0 | SKIP | No methods |
| `NoiseProperty3DJuiceEffect.gd` | 0 | 0 | SKIP | No methods |
| `NoisePropertyControlJuiceEffect.gd` | 0 | 0 | SKIP | No methods |
| `NoisePropertyJuiceEffectBase.gd` | 13 | 4 | DONE | Removed 2 redundant restatements on _sample_noise, _compute_noise_delta |
| `NoisePropertyTarget.gd` | 4 | 4 | DONE | Already clean, all methods boilerplate (SKIP) |
| `ProgressProperty2DJuiceEffect.gd` | 0 | 0 | SKIP | No methods |
| `ProgressProperty3DJuiceEffect.gd` | 0 | 0 | SKIP | No methods |
| `ProgressPropertyControlJuiceEffect.gd` | 0 | 0 | SKIP | No methods |
| `ProgressPropertyJuiceEffectBase.gd` | 18 | 4 | DONE | Added 2 missing export tooltips (auto_start, hold_on_stop) |
| `PropertyJuiceEffectBase.gd` | 12 | 5 | DONE | Already clean, excellent documentation |
| `PropertyTarget.gd` | 12 | 5 | DONE | Downgraded 3 internal helpers ##→# |
| `SceneAction2DJuiceUtility.gd` | 0 | 0 | SKIP | No methods |
| `SceneAction3DJuiceUtility.gd` | 0 | 0 | SKIP | No methods |
| `SceneActionControlJuiceUtility.gd` | 0 | 0 | SKIP | No methods |
| `SceneActionJuiceUtilityBase.gd` | 10 | 9 | DONE | Added ## on _on_animate_start, downgraded _is_destructive ##→# |
| `ShakeProperty2DJuiceEffect.gd` | 0 | 0 | SKIP | No methods |
| `ShakeProperty3DJuiceEffect.gd` | 0 | 0 | SKIP | No methods |
| `ShakePropertyControlJuiceEffect.gd` | 0 | 0 | SKIP | No methods |
| `ShakePropertyJuiceEffectBase.gd` | 10 | 4 | DONE | Already clean, no changes needed |
| `ShakePropertyTarget.gd` | 4 | 4 | DONE | Already clean, all methods boilerplate (SKIP) |
| `SignalEmit2DJuiceUtility.gd` | 0 | 0 | SKIP | No methods |
| `SignalEmit3DJuiceUtility.gd` | 0 | 0 | SKIP | No methods |
| `SignalEmitControlJuiceUtility.gd` | 0 | 0 | SKIP | No methods |
| `SignalEmitEntry.gd` | 3 | 3 | DONE | Already clean, all methods boilerplate (SKIP) |
| `SignalEmitJuiceUtilityBase.gd` | 9 | 8 | DONE | Already clean, no changes needed |
| `Time2DJuiceEffect.gd` | 0 | 0 | SKIP | No methods |
| `Time3DJuiceEffect.gd` | 0 | 0 | SKIP | No methods |
| `TimeControlJuiceEffect.gd` | 0 | 0 | SKIP | No methods |
| `TimeJuiceEffectBase.gd` | 18 | 4 | DONE | Removed 2 redundant restatements on tick, _compute_static_scale |

## Screen

| File | Methods | Uncommented | Status | Notes |
|------|---------|-------------|--------|-------|
| `JuiceScreenOverlayProvider.gd` | 4 | 1 | DONE | Already clean, no changes needed |
| `ScreenJuiceEffect.gd` | 22 | 17 | DONE | Downgraded 5 internal helpers ##→# (_sample, _find_utility, _find_or_create_utility, _bootstrap_utility, _offset_to_uv) |
| `ScreenJuiceUtility.gd` | 6 | 5 | DONE | Already clean, no changes needed |
| `ScreenOverlay2DJuiceEffect.gd` | 0 | 0 | SKIP | No methods |
| `ScreenOverlay3DJuiceEffect.gd` | 0 | 0 | SKIP | No methods |
| `ScreenOverlayControlJuiceEffect.gd` | 0 | 0 | SKIP | No methods |
| `ScreenOverlayJuiceEffectBase.gd` | 14 | 14 | DONE | Already clean, no changes needed |

## Utilities

| File | Methods | Uncommented | Status | Notes |
|------|---------|-------------|--------|-------|
| `_JuiceTransitionHandler.gd` | 13 | 12 | DONE | Already clean, internal-only class (no class_name) |
| `Interaction2DJuiceUtility.gd` | 31 | 30 | DONE | Downgraded _input_event ##→# |
| `Interaction3DJuiceUtility.gd` | 31 | 29 | DONE | Downgraded _input_event and _sync_user_signals ##→# |
| `SignalRelayJuiceUtility.gd` | 3 | 3 | DONE | Already clean, no changes needed |
| `SoftTrigger2DJuiceUtility.gd` | 19 | 11 | DONE | Downgraded 8 internal helpers ##→# (distance calc, shape, sibling discovery) |
| `SoftTrigger3DJuiceUtility.gd` | 22 | 14 | DONE | Downgraded 7 internal helpers ##→# (mouse/body progress, box/sphere, shape) |
| `SoftTriggerControlJuiceUtility.gd` | 9 | 7 | DONE | Downgraded 2 internal helpers ##→# (_calculate_rect_progress, _ensure_juice_siblings) |
| `TimeCoordinatorJuiceUtility.gd` | 10 | 10 | DONE | Moved 5 ## from inside body to above func; downgraded 3 internals ##→# |
