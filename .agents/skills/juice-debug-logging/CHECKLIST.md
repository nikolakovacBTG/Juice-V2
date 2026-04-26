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

### Batch 3B: Core Infrastructure ✅
- [x] `JuiceLedger.gd` — NO CHANGES (static utility; callers log aggregation)
- [x] `JuiceEffectBase.gd` — start/stop lifecycle + _get_domain_tag() virtual
- [x] `JuiceRecipe.gd` — NO CHANGES (data container; no logging insertion points)

### Batch 3C: Domain Effect Bases ✅
- [x] `JuiceControlEffectBase.gd` — _get_domain_tag() → "Control"
- [x] `Juice2DEffectBase.gd` — _get_domain_tag() → "2D"
- [x] `Juice3DEffectBase.gd` — _get_domain_tag() → "3D"

### Batch 3D: Transform Effect Bases ✅
- [x] `JuiceControlTransformEffect.gd` — 4 prints → log_info (FROMTO_DBG removed)
- [x] `Juice2DTransformEffect.gd` — 1 print → log_info
- [x] `Juice3DTransformEffect.gd` — 1 print → log_info

### Batch 3E: Appearance Effect Bases ✅
- [x] `AppearanceControlJuiceEffect.gd` — 1 print → log_info, 1 push_warning → warn
- [x] `Appearance2DJuiceEffect.gd` — 14 dev leftovers REMOVED, 2 prints → log_info, 1 push_warning → warn, 6 resolvers simplified
- [x] `Appearance3DJuiceEffect.gd` — 1 print → log_info

---

## Phase 4: Concrete Effects

### Batch 4A: Transform (concrete) ✅
- [x] `TransformControlJuiceEffect.gd` — 13 prints → JuiceLogger (captures/info), 1 removed (per-frame), 3 push_warning → warn
- [x] `Transform2DJuiceEffect.gd` — 10 prints → JuiceLogger (captures), 3 push_warning → warn
- [x] `Transform3DJuiceEffect.gd` — 9 prints → JuiceLogger (captures), 3 push_warning → warn

### Batch 4B: Shake ✅
- [x] `ShakeControlJuiceEffect.gd` — 1 print → log_info
- [x] `Shake2DJuiceEffect.gd` — 1 print → log_info
- [x] `Shake3DJuiceEffect.gd` — 1 print → log_info

### Batch 4C: Noise ✅
- [x] `NoiseControlJuiceEffect.gd` — 1 print → log_info
- [x] `Noise2DJuiceEffect.gd` — 1 print → log_info
- [x] `Noise3DJuiceEffect.gd` — 1 print → log_info

### Batch 4D: Progress ✅
- [x] `ProgressControlJuiceEffect.gd` — 4 prints → log_info/log_capture, 1 push_warning → warn
- [x] `Progress2DJuiceEffect.gd` — 3 prints → log_info/log_capture, 1 push_warning → warn
- [x] `Progress3DJuiceEffect.gd` — 4 prints → log_info/log_capture, 1 push_warning → warn

### Batch 4E: SquashStretch ✅ (no prints — already clean)
- [x] `SquashStretchControlJuiceEffect.gd` — N/A
- [x] `SquashStretch2DJuiceEffect.gd` — N/A
- [x] `SquashStretch3DJuiceEffect.gd` — N/A

### Batch 4F: Appearance (concrete) ✅ (instrumented in Batch 3E)
- [x] `AppearanceControlJuiceEffect.gd` — done in 3E
- [x] `Appearance2DJuiceEffect.gd` — done in 3E
- [x] `Appearance3DJuiceEffect.gd` — done in 3E

### Batch 4G: Property Effects (Meta bases — 5 files, simple) ✅
- [x] `PropertyJuiceEffectBase.gd` — N/A (no prints)
- [x] `InterpolatePropertyJuiceEffectBase.gd` — 1 push_warning → warn
- [x] `NoisePropertyJuiceEffectBase.gd` — N/A (no prints)
- [x] `ShakePropertyJuiceEffectBase.gd` — N/A (no prints)
- [x] `ProgressPropertyJuiceEffectBase.gd` — 3 prints → log_info/log_capture

### Batch 4H: Property Effects (Meta concrete Control — 5 files, simple) ✅ (no prints — already clean)
- [x] `InterpolatePropertyControlJuiceEffect.gd` — N/A
- [x] `NoisePropertyControlJuiceEffect.gd` — N/A
- [x] `ShakePropertyControlJuiceEffect.gd` — N/A
- [x] `ProgressPropertyControlJuiceEffect.gd` — N/A
- [x] `TimeControlJuiceEffect.gd` — N/A

### Batch 4I: Property Effects (Meta concrete 2D — 5 files, simple) ✅ (no prints — already clean)
- [x] `InterpolateProperty2DJuiceEffect.gd` — N/A
- [x] `NoiseProperty2DJuiceEffect.gd` — N/A
- [x] `ShakeProperty2DJuiceEffect.gd` — N/A
- [x] `ProgressProperty2DJuiceEffect.gd` — N/A
- [x] `Time2DJuiceEffect.gd` — N/A

### Batch 4J: Property Effects (Meta concrete 3D — 5 files, simple) ✅ (no prints — already clean)
- [x] `InterpolateProperty3DJuiceEffect.gd` — N/A
- [x] `NoiseProperty3DJuiceEffect.gd` — N/A
- [x] `ShakeProperty3DJuiceEffect.gd` — N/A
- [x] `ProgressProperty3DJuiceEffect.gd` — N/A
- [x] `Time3DJuiceEffect.gd` — N/A

### Batch 4K: Camera + Screen (5 files) ✅
- [x] `Camera2DJuiceEffect.gd` — 1 push_warning → warn, 1 print → log_info
- [x] `Camera3DJuiceEffect.gd` — 1 push_warning → warn, 1 print → log_info
- [x] `ScreenJuiceEffect.gd` — 2 push_warning → warn, 1 print → log_info
- [x] `ScreenOverlayJuiceEffectBase.gd` — 1 push_warning → warn, 1 print → log_info
- [x] `CameraJuiceUtility.gd` — 1 push_warning → warn, 3 prints → log_info

### Batch 4L: Screen Overlay Concrete (3 files) ✅ (no prints — already clean)
- [x] `ScreenOverlayControlJuiceEffect.gd` — N/A
- [x] `ScreenOverlay2DJuiceEffect.gd` — N/A
- [x] `ScreenOverlay3DJuiceEffect.gd` — N/A

### Batch 4M: Meta Utilities (5 files) ✅
- [x] `CallMethodJuiceUtilityBase.gd` — 4 push_warning → warn, 1 print → log_info
- [x] `SignalEmitJuiceUtilityBase.gd` — 1 print → log_info
- [x] `SceneActionJuiceUtilityBase.gd` — 1 print → log_info
- [x] `TimeJuiceEffectBase.gd` — 1 push_warning → warn, 6 prints → log_info
- [x] `_JuiceSceneActionOrchestrator.gd` — 8 push_warning/error → warn, 14 prints → log_info, 6 push_error → warn

### Batch 4N: Meta Utility Concrete (5 files) ✅ (no prints — already clean)
- [x] `CallMethodControlJuiceUtility.gd` — N/A
- [x] `CallMethod2DJuiceUtility.gd` — N/A
- [x] `CallMethod3DJuiceUtility.gd` — N/A
- [x] `SignalEmitControlJuiceUtility.gd` — N/A
- [x] `SignalEmit2DJuiceUtility.gd` — N/A

### Batch 4O: Meta Utility Concrete continued (4 files) ✅ (no prints — already clean)
- [x] `SignalEmit3DJuiceUtility.gd` — N/A
- [x] `SceneActionControlJuiceUtility.gd` — N/A
- [x] `SceneAction2DJuiceUtility.gd` — N/A
- [x] `SceneAction3DJuiceUtility.gd` — N/A

---

## Phase 4-Utilities: Standalone Utilities

### Batch 4P: Interaction + SoftTrigger (3 files) ✅
- [x] `Interaction2DJuiceUtility.gd` — 1 push_warning → warn, 14 prints → log_info
- [x] `Interaction3DJuiceUtility.gd` — 2 push_warning → warn, 14 prints → log_info
- [x] `SoftTriggerControlJuiceUtility.gd`

### Batch 4Q: SoftTrigger + Coordinator (3 files, complex) ✅
- [x] `SoftTrigger2DJuiceUtility.gd`
- [x] `SoftTrigger3DJuiceUtility.gd`
- [x] `TimeCoordinatorJuiceUtility.gd` ✅ (compliant)

### Batch 4R: Support (3 files) ✅
- [x] `_JuiceTransitionHandler.gd`
- [x] `SignalRelayJuiceUtility.gd` — 5 push_warning → warn, 2 prints → log_info
- [x] `JuiceScreenOverlayProvider.gd` — 2 push_error → warn (always-on, static class)

---

## Phase 4-Remediation: Gap-Fill (LOG_POINTS.md compliance)

Previous batches (4G–4R) only converted existing prints but did NOT add new
log points mandated by LOG_POINTS.md. These remediation batches close the gaps.

### Batch R-A: Cat 3 — Delta logging in Shake effects (3 files) ✅
- [x] `ShakeControlJuiceEffect.gd` — NEW `log_delta` in `_apply_effect()`
- [x] `Shake2DJuiceEffect.gd` — NEW `log_delta` in `_apply_effect()`
- [x] `Shake3DJuiceEffect.gd` — NEW `log_delta` in `_apply_effect()`

### Batch R-B: Cat 3 — Delta logging in Noise effects (3 files) ✅
- [x] `NoiseControlJuiceEffect.gd` — NEW `log_delta` in `_apply_effect()`
- [x] `Noise2DJuiceEffect.gd` — NEW `log_delta` in `_apply_effect()`
- [x] `Noise3DJuiceEffect.gd` — NEW `log_delta` in `_apply_effect()`

### Batch R-C: Cat 3 — Delta logging in SquashStretch effects (3 files) ✅
- [x] `SquashStretchControlJuiceEffect.gd` — NEW `log_delta` in `_apply_effect()`
- [x] `SquashStretch2DJuiceEffect.gd` — NEW `log_delta` in `_apply_effect()`
- [x] `SquashStretch3DJuiceEffect.gd` — NEW `log_delta` in `_apply_effect()` (includes pos_delta for pivot)

### Batch R-D: Cat 3 — Delta logging in Transform effects (3 files, complex) ✅
- [x] `TransformControlJuiceEffect.gd` — via base `JuiceControlTransformEffect._apply_effect()`
- [x] `Transform2DJuiceEffect.gd` — via base `Juice2DTransformEffect._apply_effect()`
- [x] `Transform3DJuiceEffect.gd` — via base `Juice3DTransformEffect._apply_effect()`

### Batch R-E: Cat 3+2 — Delta + Capture in Appearance effects (3 files, complex) ✅
- [x] `AppearanceControlJuiceEffect.gd` — NEW `log_delta` + `log_capture` (from/to)
- [x] `Appearance2DJuiceEffect.gd` — NEW `log_delta` + `log_capture` (from/to)
- [x] `Appearance3DJuiceEffect.gd` — NEW `log_delta(albedo/alpha)` + `log_capture` (from/to)

### Batch R-F: Cat 4 — Shader diagnostics in Appearance effects (3 files, complex) ✅
- [x] `AppearanceControlJuiceEffect.gd` — NEW `log_shader` in OUTLINE branch
- [x] `Appearance2DJuiceEffect.gd` — NEW `log_shader` in OUTLINE branch
- [x] `Appearance3DJuiceEffect.gd` — NEW `log_shader` for computed outline values (domain writes)

### Batch R-G: Cat 3+2 — Delta + Capture in Property Meta effects (3 files)
- [ ] `InterpolatePropertyJuiceEffectBase.gd` — `_apply_effect()` needs `log_delta`, `_on_animate_start()` needs `log_capture`
- [ ] `NoisePropertyJuiceEffectBase.gd` — `_apply_effect()` needs `log_delta`
- [ ] `ShakePropertyJuiceEffectBase.gd` — `_apply_effect()` needs `log_delta`

### Batch R-H: Cat 2 — Capture logging in Shake/Noise/SquashStretch _on_animate_start (5 files, simple)
- [ ] `ShakeControlJuiceEffect.gd` — `_on_animate_start()` needs `log_capture`
- [ ] `Shake2DJuiceEffect.gd` — `_on_animate_start()` needs `log_capture`
- [ ] `Shake3DJuiceEffect.gd` — `_on_animate_start()` needs `log_capture`
- [ ] `NoiseControlJuiceEffect.gd` — `_on_animate_start()` needs `log_capture`
- [ ] `Noise2DJuiceEffect.gd` — `_on_animate_start()` needs `log_capture`

### Batch R-I: Cat 2 continued + Cat 3 Progress (5 files, simple)
- [ ] `Noise3DJuiceEffect.gd` — `_on_animate_start()` needs `log_capture`
- [ ] `SquashStretchControlJuiceEffect.gd` — `_on_animate_start()` needs `log_capture`
- [ ] `SquashStretch2DJuiceEffect.gd` — `_on_animate_start()` needs `log_capture`
- [ ] `SquashStretch3DJuiceEffect.gd` — `_on_animate_start()` needs `log_capture`
- [ ] `ProgressControlJuiceEffect.gd` — `_apply_effect()` needs `log_delta`

### Batch R-J: Cat 3 — Progress deltas + Cat 6 domain guardrails (5 files, simple)
- [ ] `Progress2DJuiceEffect.gd` — `_apply_effect()` needs `log_delta`
- [ ] `Progress3DJuiceEffect.gd` — `_apply_effect()` needs `log_delta`
- [ ] `ProgressPropertyJuiceEffectBase.gd` — `_apply_effect()` needs `log_delta`
- [ ] `JuiceBase.gd` — `_ready()` or `_start_effects()` needs `warn_domain_mismatch` (Cat 6)
- [ ] `JuiceRecipe.gd` — validation path needs `warn_domain_mismatch` (Cat 6)

---

## Phase 5: Bug Report System

- [ ] `JuiceDebugReport.gd` — state snapshot + log export
- [ ] Editor plugin menu item: "Tools → Export Juice Bug Report"
