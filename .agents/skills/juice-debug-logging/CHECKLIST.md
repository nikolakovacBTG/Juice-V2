# Debug Logging Instrumentation Checklist

Track progress file-by-file. Status: `[ ]` pending, `[/]` in progress, `[x]` done.

## Phase 2: Infrastructure

- [x] `JuiceLogger.gd` — NEW static utility class
- [x] `JuiceProjectSettings.gd` — add master switch + log_to_file settings
- [ ] `JuiceDebugReport.gd` — NEW bug report exporter

---

## Phase 2b: JuiceBase Audit + Migration

Audit existing ~44 prints. Decide keep/remove per call, then convert.

- [x] `JuiceBase.gd` — audit pass (sub-batch 1: lines 1-1000) ✅
- [x] `JuiceBase.gd` — audit pass (sub-batch 2: lines 1000-2075) ✅

---

## Phase 3: Base Classes

### Batch 3A: Domain Nodes ✅ (gap-fill pass complete)
- [x] `JuiceControl.gd` — capture, pre_tick, post_tick_write
- [x] `Juice2D.gd` — capture, pre_tick, post_tick_write
- [x] `Juice3D.gd` — capture, pre_tick, post_tick_write

### Batch 3B: Core Infrastructure
- [ ] `JuiceLedger.gd` — aggregation trace
- [ ] `JuiceEffectBase.gd` — start/tick/stop lifecycle + _get_domain_tag()
- [ ] `JuiceRecipe.gd` — domain guardrails (Category 6)

### Batch 3C: Domain Effect Bases
- [ ] `JuiceControlEffectBase.gd` — _get_domain_tag()
- [ ] `Juice2DEffectBase.gd` — _get_domain_tag()
- [ ] `Juice3DEffectBase.gd` — _get_domain_tag()

### Batch 3D: Transform Effect Bases
- [ ] `JuiceControlTransformEffect.gd` — delta trace in _apply_effect()
- [ ] `Juice2DTransformEffect.gd` — delta trace in _apply_effect()
- [ ] `Juice3DTransformEffect.gd` — delta trace in _apply_effect()

### Batch 3E: Appearance Effect Bases
- [ ] `JuiceControlAppearanceEffect.gd` — shader diagnostics
- [ ] `Juice2DAppearanceEffect.gd` — shader diagnostics
- [ ] `Juice3DAppearanceEffect.gd` — shader diagnostics

---

## Phase 4: Concrete Effects

### Batch 4A: Transform (concrete)
- [ ] `TransformControlJuiceEffect.gd`
- [ ] `Transform2DJuiceEffect.gd`
- [ ] `Transform3DJuiceEffect.gd`

### Batch 4B: Shake
- [ ] `ShakeControlJuiceEffect.gd`
- [ ] `Shake2DJuiceEffect.gd`
- [ ] `Shake3DJuiceEffect.gd`

### Batch 4C: Noise
- [ ] `NoiseControlJuiceEffect.gd`
- [ ] `Noise2DJuiceEffect.gd`
- [ ] `Noise3DJuiceEffect.gd`

### Batch 4D: Progress
- [ ] `ProgressControlJuiceEffect.gd`
- [ ] `Progress2DJuiceEffect.gd`
- [ ] `Progress3DJuiceEffect.gd`

### Batch 4E: SquashStretch
- [ ] `SquashStretchControlJuiceEffect.gd`
- [ ] `SquashStretch2DJuiceEffect.gd`
- [ ] `SquashStretch3DJuiceEffect.gd`

### Batch 4F: Appearance (concrete)
- [ ] `AppearanceControlJuiceEffect.gd`
- [ ] `Appearance2DJuiceEffect.gd`
- [ ] `Appearance3DJuiceEffect.gd`

### Batch 4G: Property Effects (Meta bases — 5 files, simple)
- [ ] `PropertyJuiceEffectBase.gd`
- [ ] `InterpolatePropertyJuiceEffectBase.gd`
- [ ] `NoisePropertyJuiceEffectBase.gd`
- [ ] `ShakePropertyJuiceEffectBase.gd`
- [ ] `ProgressPropertyJuiceEffectBase.gd`

### Batch 4H: Property Effects (Meta concrete Control — 5 files, simple)
- [ ] `InterpolatePropertyControlJuiceEffect.gd`
- [ ] `NoisePropertyControlJuiceEffect.gd`
- [ ] `ShakePropertyControlJuiceEffect.gd`
- [ ] `ProgressPropertyControlJuiceEffect.gd`
- [ ] `TimeControlJuiceEffect.gd`

### Batch 4I: Property Effects (Meta concrete 2D — 5 files, simple)
- [ ] `InterpolateProperty2DJuiceEffect.gd`
- [ ] `NoiseProperty2DJuiceEffect.gd`
- [ ] `ShakeProperty2DJuiceEffect.gd`
- [ ] `ProgressProperty2DJuiceEffect.gd`
- [ ] `Time2DJuiceEffect.gd`

### Batch 4J: Property Effects (Meta concrete 3D — 5 files, simple)
- [ ] `InterpolateProperty3DJuiceEffect.gd`
- [ ] `NoiseProperty3DJuiceEffect.gd`
- [ ] `ShakeProperty3DJuiceEffect.gd`
- [ ] `ProgressProperty3DJuiceEffect.gd`
- [ ] `Time3DJuiceEffect.gd`

### Batch 4K: Camera + Screen (5 files)
- [ ] `Camera2DJuiceEffect.gd`
- [ ] `Camera3DJuiceEffect.gd`
- [ ] `ScreenJuiceEffect.gd`
- [ ] `ScreenOverlayJuiceEffectBase.gd`
- [ ] `CameraJuiceUtility.gd`

### Batch 4L: Screen Overlay Concrete (3 files)
- [ ] `ScreenOverlayControlJuiceEffect.gd`
- [ ] `ScreenOverlay2DJuiceEffect.gd`
- [ ] `ScreenOverlay3DJuiceEffect.gd`

### Batch 4M: Meta Utilities (5 files, simple)
- [ ] `CallMethodJuiceUtilityBase.gd`
- [ ] `SignalEmitJuiceUtilityBase.gd`
- [ ] `SceneActionJuiceUtilityBase.gd`
- [ ] `TimeJuiceEffectBase.gd`
- [ ] `_JuiceSceneActionOrchestrator.gd`

### Batch 4N: Meta Utility Concrete (5 files, simple)
- [ ] `CallMethodControlJuiceUtility.gd`
- [ ] `CallMethod2DJuiceUtility.gd`
- [ ] `CallMethod3DJuiceUtility.gd`
- [ ] `SignalEmitControlJuiceUtility.gd`
- [ ] `SignalEmit2DJuiceUtility.gd`

### Batch 4O: Meta Utility Concrete continued (4 files)
- [ ] `SignalEmit3DJuiceUtility.gd`
- [ ] `SceneActionControlJuiceUtility.gd`
- [ ] `SceneAction2DJuiceUtility.gd`
- [ ] `SceneAction3DJuiceUtility.gd`

---

## Phase 4-Utilities: Standalone Utilities

### Batch 4P: Interaction + SoftTrigger (3 files, complex)
- [ ] `Interaction2DJuiceUtility.gd`
- [ ] `Interaction3DJuiceUtility.gd`
- [x] `SoftTriggerControlJuiceUtility.gd`

### Batch 4Q: SoftTrigger + Coordinator (3 files, complex) ✅
- [x] `SoftTrigger2DJuiceUtility.gd`
- [x] `SoftTrigger3DJuiceUtility.gd`
- [x] `TimeCoordinatorJuiceUtility.gd` ✅ (compliant)

### Batch 4R: Support (3 files)
- [x] `_JuiceTransitionHandler.gd`
- [ ] `SignalRelayJuiceUtility.gd`
- [ ] `JuiceScreenOverlayProvider.gd`

---

## Phase 5: Bug Report System

- [ ] `JuiceDebugReport.gd` — state snapshot + log export
- [ ] Editor plugin menu item: "Tools → Export Juice Bug Report"
