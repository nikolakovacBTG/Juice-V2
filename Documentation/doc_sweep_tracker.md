# Documentation Sweep Tracker

**Updated:** 2026-04-27 — Honest reassessment based on automated coverage scan + manual spot checks.

## Status Legend

| Status | Meaning |
|--------|---------|
| **DONE** | Phase A (structural) + Phase B (method comprehension) both complete. All methods consciously triaged. |
| **STRUCTURAL** | Phase A complete (headers, exports, history, visibility rules). Methods NOT yet triaged per Phase B. |
| **TODO** | Not yet reviewed at all |
| **SKIP** | No methods (domain registration stubs) or auto-generated |

## Context: What the previous sweep accomplished

The previous sweep (Apr 2026) successfully completed Phase A across the **entire codebase**:
- ✅ Class tooltips (action-oriented `##`)
- ✅ WHY blocks
- ✅ `##` vs `#` visibility rules (public API vs private helpers)
- ✅ Export tooltips
- ✅ History sanitization
- ✅ TODO triage

It also completed Phase B (method comprehension) for the core architecture files.
It did NOT complete Phase B for concrete effects, domain transform bases, or most utilities.

---

## Base Classes

| File | Methods | Commented | Status | Assessment |
|------|---------|-----------|--------|------------|
| `JuiceBase.gd` | 73 | 45 | **DONE** | Public API excellent. Internal methods have strong inline comments explaining state machine, Container deferred timing, and completion flow. 28 uncommented methods are genuinely self-documenting (boilerplate, trivial flag resets, process loops with good inline comments). |
| `JuiceEffectBase.gd` | 47 | 31 | **DONE** | Public API (`start`, `tick`, `stop`) and virtual stubs all documented. Inline comments within `tick()` explain each state machine branch. 16 uncommented are boilerplate helpers and state resets. |
| `JuiceRecipe.gd` | 4 | 4 | **DONE** | Fully documented. |
| `JuiceLedger.gd` | 10 | — | **DONE** | Already clean. Static utility with clear method names. |
| `JuiceTriggerRouter.gd` | 3 | — | **DONE** | Already clean. |
| `TriggerHintBuilder.gd` | 2 | — | **DONE** | Already clean. |
| `Juice2DRecipe.gd` | 1 | 1 | **DONE** | |
| `Juice3DRecipe.gd` | 1 | 1 | **DONE** | |
| `JuiceControlRecipe.gd` | 1 | 1 | **DONE** | |
| `Juice2DAppearanceEffect.gd` | 2 | 2 | **DONE** | |
| `Juice3DAppearanceEffect.gd` | 2 | 2 | **DONE** | |
| `JuiceControlAppearanceEffect.gd` | 2 | 2 | **DONE** | |
| `Juice2DEffectBase.gd` | 1 | 0 | **SKIP** | Single `_get_domain_tag` override. |
| `Juice3DEffectBase.gd` | 1 | 0 | **SKIP** | Single `_get_domain_tag` override. |
| `JuiceControlEffectBase.gd` | 1 | 0 | **SKIP** | Single `_get_domain_tag` override. |

---

## Domain Nodes

| File | Methods | Commented | Status | Assessment |
|------|---------|-----------|--------|------------|
| `JuiceControl.gd` | 16 | 9 | **STRUCTURAL** | Phase A done. 7 uncommented methods include `_post_tick_write`, `_pre_tick`, `_temporarily_undo_visual` — these are the domain-specific write coordination methods. A developer extending JuiceControl needs to understand what these do and when they're called by JuiceBase. |
| `Juice2D.gd` | 15 | 8 | **STRUCTURAL** | Same pattern as JuiceControl — domain write coordination methods need Phase B. |
| `Juice3D.gd` | 18 | 12 | **STRUCTURAL** | Better coverage than 2D/Control but same gaps in domain write methods. |

---

## Domain Transform Bases (the architectural backbone of Transform effects)

| File | Methods | Commented | Status | Assessment |
|------|---------|-----------|--------|------------|
| `JuiceControlTransformEffect.gd` | 42 | 12 | **STRUCTURAL** | Phase A done. 30 uncommented methods include the entire property list system, the capture lifecycle orchestration (`_on_animate_start` calling `_do_capture_base` → `_capture_from_self_*` → `_do_resolve_from_to_refs`), and the `_apply_effect` dispatcher. This is the most important file for understanding how Transform effects work — and it's essentially undocumented at the method level. |
| `Juice2DTransformEffect.gd` | 47 | 14 | **STRUCTURAL** | Same pattern. |
| `Juice3DTransformEffect.gd` | 48 | 13 | **STRUCTURAL** | Same pattern. |

---

## Control Effects

| File | Methods | Commented | Status | Assessment |
|------|---------|-----------|--------|------------|
| `TransformControlJuiceEffect.gd` | 35 | 0 | **STRUCTURAL** | Phase A done (excellent header block). Zero method comments. 35 virtual hook implementations including capture, resolve, and apply methods — all need Phase B to explain the call chain. |
| `AppearanceControlJuiceEffect.gd` | 28 | 6 | **STRUCTURAL** | Phase A done. 22 uncommented methods include shader parameter writes, modulate blending, and appearance delta computation. |
| `NoiseControlJuiceEffect.gd` | 18 | 2 | **STRUCTURAL** | Phase A done. 16 uncommented including noise sampling, delta computation, and the discrete-time advancement system. |
| `ProgressControlJuiceEffect.gd` | 24 | 0 | **STRUCTURAL** | Phase A done. Zero method comments. 24 methods covering pivot application, center inference, and the full From/To resolution chain. |
| `ShakeControlJuiceEffect.gd` | 14 | 0 | **STRUCTURAL** | Phase A done. Zero method comments. Shake-specific capture and apply methods. |
| `SquashStretchControlJuiceEffect.gd` | 12 | 8 | **STRUCTURAL** | Better coverage. Some methods may be genuinely DONE after triage. |

---

## 2D Effects

| File | Methods | Commented | Status | Assessment |
|------|---------|-----------|--------|------------|
| `Transform2DJuiceEffect.gd` | 37 | 0 | **STRUCTURAL** | Mirrors TransformControlJuiceEffect. Zero method comments. |
| `Appearance2DJuiceEffect.gd` | 28 | 7 | **STRUCTURAL** | Mirrors AppearanceControl. |
| `Noise2DJuiceEffect.gd` | 19 | 0 | **STRUCTURAL** | Mirrors NoiseControl. Zero method comments. |
| `Progress2DJuiceEffect.gd` | 23 | 7 | **STRUCTURAL** | Mirrors ProgressControl. Some base coverage exists. |
| `Shake2DJuiceEffect.gd` | 16 | 0 | **STRUCTURAL** | Mirrors ShakeControl. Zero method comments. |
| `SquashStretch2DJuiceEffect.gd` | 11 | 7 | **STRUCTURAL** | Better coverage. |

---

## 3D Effects

| File | Methods | Commented | Status | Assessment |
|------|---------|-----------|--------|------------|
| `Transform3DJuiceEffect.gd` | 38 | 0 | **STRUCTURAL** | Mirrors TransformControl. Zero method comments. |
| `Appearance3DJuiceEffect.gd` | 26 | 6 | **STRUCTURAL** | Mirrors AppearanceControl. |
| `Noise3DJuiceEffect.gd` | 18 | 0 | **STRUCTURAL** | Mirrors NoiseControl. Zero method comments. |
| `Progress3DJuiceEffect.gd` | 25 | 3 | **STRUCTURAL** | Mirrors ProgressControl. |
| `Shake3DJuiceEffect.gd` | 16 | 0 | **STRUCTURAL** | Mirrors ShakeControl. Zero method comments. |
| `SquashStretch3DJuiceEffect.gd` | 11 | 7 | **STRUCTURAL** | Better coverage. |

---

## Camera

| File | Methods | Commented | Status | Assessment |
|------|---------|-----------|--------|------------|
| `Camera2DJuiceEffect.gd` | 17 | 4 | **STRUCTURAL** | Phase A done. Camera offset/rotation/zoom apply methods need triage. |
| `Camera3DJuiceEffect.gd` | 17 | 2 | **STRUCTURAL** | Same pattern. |
| `CameraJuiceUtility.gd` | 6 | 1 | **STRUCTURAL** | Phase A done. Registry/cleanup methods need triage. |

---

## Screen

| File | Methods | Commented | Status | Assessment |
|------|---------|-----------|--------|------------|
| `ScreenJuiceEffect.gd` | 22 | 5 | **STRUCTURAL** | Phase A done. Shader uniform writes and utility bootstrap need triage. |
| `ScreenJuiceUtility.gd` | 6 | 1 | **STRUCTURAL** | Registry pattern needs triage. |
| `ScreenOverlayJuiceEffectBase.gd` | 14 | 0 | **STRUCTURAL** | Zero method comments. Overlay lifecycle needs full Phase B. |
| `JuiceScreenOverlayProvider.gd` | 4 | — | **DONE** | Already clean. |

---

## Meta Effects

| File | Methods | Commented | Status | Assessment |
|------|---------|-----------|--------|------------|
| `PropertyJuiceEffectBase.gd` | 12 | 7 | **STRUCTURAL** | Good coverage, but the target resolution and validation chain needs triage. |
| `PropertyTarget.gd` | 12 | 7 | **STRUCTURAL** | Good coverage. Some value resolution helpers may need triage. |
| `InterpolatePropertyJuiceEffectBase.gd` | 7 | 6 | **DONE** | Near-complete. 1 remaining method likely trivial. |
| `InterpolatePropertyTarget.gd` | 13 | 5 | **STRUCTURAL** | Value props and editor node resolution need triage. |
| `NoisePropertyJuiceEffectBase.gd` | 13 | 9 | **STRUCTURAL** | Good coverage. Noise sampling methods may need triage. |
| `NoisePropertyTarget.gd` | 4 | 0 | **STRUCTURAL** | Small file. Quick triage needed. |
| `ProgressPropertyJuiceEffectBase.gd` | 18 | 14 | **DONE** | Near-complete. 4 remaining likely trivial. |
| `ShakePropertyJuiceEffectBase.gd` | 10 | 6 | **STRUCTURAL** | Good coverage. 4 remaining need triage. |
| `ShakePropertyTarget.gd` | 4 | 0 | **STRUCTURAL** | Small file. Quick triage needed. |
| `TimeJuiceEffectBase.gd` | 17 | 13 | **DONE** | Near-complete. |
| `CallMethodJuiceUtilityBase.gd` | 12 | 3 | **STRUCTURAL** | Phase A done. Method call orchestration needs triage. |
| `CallMethodEntry.gd` | 4 | 0 | **STRUCTURAL** | Small data class. Quick triage. |
| `SignalEmitJuiceUtilityBase.gd` | 9 | 1 | **STRUCTURAL** | Signal relay lifecycle needs triage. |
| `SignalEmitEntry.gd` | 3 | 0 | **STRUCTURAL** | Small data class. Quick triage. |
| `SceneActionJuiceUtilityBase.gd` | 10 | 2 | **STRUCTURAL** | Scene swap orchestration needs triage. |
| `_JuiceSceneActionOrchestrator.gd` | 24 | 24 | **DONE** | Fully documented. |

---

## Meta Domain Wrappers (registration stubs)

| File | Status | Notes |
|------|--------|-------|
| `CallMethod2DJuiceUtility.gd` | **SKIP** | No methods. Tooltip done. |
| `CallMethod3DJuiceUtility.gd` | **SKIP** | No methods. Tooltip done. |
| `CallMethodControlJuiceUtility.gd` | **SKIP** | No methods. Tooltip done. |
| `InterpolateProperty2DJuiceEffect.gd` | **SKIP** | No methods. Tooltip done. |
| `InterpolateProperty3DJuiceEffect.gd` | **SKIP** | No methods. Tooltip done. |
| `InterpolatePropertyControlJuiceEffect.gd` | **SKIP** | No methods. Tooltip done. |
| `NoiseProperty2DJuiceEffect.gd` | **SKIP** | No methods. Tooltip done. |
| `NoiseProperty3DJuiceEffect.gd` | **SKIP** | No methods. Tooltip done. |
| `NoisePropertyControlJuiceEffect.gd` | **SKIP** | No methods. Tooltip done. |
| `ProgressProperty2DJuiceEffect.gd` | **SKIP** | No methods. Tooltip done. |
| `ProgressProperty3DJuiceEffect.gd` | **SKIP** | No methods. Tooltip done. |
| `ProgressPropertyControlJuiceEffect.gd` | **SKIP** | No methods. Tooltip done. |
| `ShakeProperty2DJuiceEffect.gd` | **SKIP** | No methods. Tooltip done. |
| `ShakeProperty3DJuiceEffect.gd` | **SKIP** | No methods. Tooltip done. |
| `ShakePropertyControlJuiceEffect.gd` | **SKIP** | No methods. Tooltip done. |
| `SignalEmit2DJuiceUtility.gd` | **SKIP** | No methods. Tooltip done. |
| `SignalEmit3DJuiceUtility.gd` | **SKIP** | No methods. Tooltip done. |
| `SignalEmitControlJuiceUtility.gd` | **SKIP** | No methods. Tooltip done. |
| `Time2DJuiceEffect.gd` | **SKIP** | No methods. Tooltip done. |
| `Time3DJuiceEffect.gd` | **SKIP** | No methods. Tooltip done. |
| `TimeControlJuiceEffect.gd` | **SKIP** | No methods. Tooltip done. |
| `ScreenOverlay2DJuiceEffect.gd` | **SKIP** | No methods. Tooltip done. |
| `ScreenOverlay3DJuiceEffect.gd` | **SKIP** | No methods. Tooltip done. |
| `ScreenOverlayControlJuiceEffect.gd` | **SKIP** | No methods. Tooltip done. |

---

## Editor

| File | Methods | Commented | Status | Assessment |
|------|---------|-----------|--------|------------|
| `JuiceEditorContext.gd` | 2 | — | **DONE** | Already clean. |
| `JuiceProjectSettings.gd` | 2 | — | **DONE** | Already clean. |
| `PropertyPickerDialog.gd` | 8 | 3 | **STRUCTURAL** | UI builder methods need triage. |
| `PropertyPickerPlugin.gd` | 12 | 5 | **STRUCTURAL** | Inspector integration needs triage. |

---

## Utilities

| File | Methods | Commented | Status | Assessment |
|------|---------|-----------|--------|------------|
| `Interaction2DJuiceUtility.gd` | 31 | 1 | **STRUCTURAL** | Phase A done (excellent header). Public API (`set_enabled`, `reset`, `simulate_*`) has zero `##` docs. Zone gating and input handling need triage. |
| `Interaction3DJuiceUtility.gd` | 31 | 2 | **STRUCTURAL** | Same pattern as 2D. |
| `SoftTrigger2DJuiceUtility.gd` | 19 | 8 | **STRUCTURAL** | Distance calculation and shape detection need triage. |
| `SoftTrigger3DJuiceUtility.gd` | 22 | 8 | **STRUCTURAL** | Same pattern. |
| `SoftTriggerControlJuiceUtility.gd` | 9 | 2 | **STRUCTURAL** | Small, focused. Quick triage. |
| `SignalRelayJuiceUtility.gd` | 3 | 0 | **STRUCTURAL** | 3 methods. Quick triage. |
| `TimeCoordinatorJuiceUtility.gd` | 10 | 8 | **DONE** | Near-complete. |
| `_JuiceTransitionHandler.gd` | 13 | 1 | **STRUCTURAL** | Transition lifecycle (cover/uncover/execute) needs triage. |

---

## Logging System (NEW — not yet swept)

| File | Methods | Status | Assessment |
|------|---------|--------|------------|
| `JuiceLogger.gd` | TBD | **TODO** | New file. Needs full Phase A + B. |
| `JuiceDebugReport.gd` | TBD | **TODO** | New file. Needs full Phase A + B. |
| `JuiceDebugReportPlugin.gd` | TBD | **TODO** | New file. Needs full Phase A + B. |

---

## Plugin Entry

| File | Methods | Commented | Status | Assessment |
|------|---------|-----------|--------|------------|
| `juice_plugin.gd` | 3 | 1 | **DONE** | Boilerplate. No doc needed. |

---

## Summary

| Status | Count | % |
|--------|-------|---|
| **DONE** | 22 | 24% |
| **STRUCTURAL** | 41 | 44% |
| **TODO** | 3 | 3% |
| **SKIP** | 24 | 26% |
| **BLOCKED** | 0 | 0% |
| **Total** | 90 | 100% |

### Priority Order for Phase B Work

1. **Domain Transform Bases** (3 files, ~137 methods) — Architectural backbone. Everything else depends on understanding these.
2. **Concrete Transform Effects** (3 files, ~110 methods) — The files a buyer studies to learn the pattern.
3. **Domain Nodes** (3 files, ~49 methods) — Write coordination, the architectural contract.
4. **Utilities** (8 files, ~138 methods) — Public API exposure for game developers.
5. **Remaining effects** (Appearance, Noise, Shake, Progress, SquashStretch — 18 files, ~280 methods) — These mirror each other heavily across domains; documenting one domain's version informs the others.
6. **Meta effects** (CallMethod, SignalEmit, SceneAction, Property targets — ~10 files) — Smaller, more self-contained.
7. **Logging system** (3 files) — New code, needs fresh sweep.
8. **Camera/Screen/Editor** (7 files) — Specialized subsystems, lower priority.
