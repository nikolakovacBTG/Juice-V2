# Juice V1 — Documentation & Logging Tracker

**Updated:** 2026-05-05

Tracks two workstreams across the entire `addons/Juice_V1/` codebase:

1. **In-script documentation** — structural (Phase A) and method comprehension (Phase B). Follow the `/doc-sweep` workflow to complete Phase B items.
2. **Debug logging instrumentation** — whether the file uses `JuiceLogger` for auditable runtime tracing.

---

## Status Legend

### Documentation Status

| Status | Meaning |
|--------|---------|
| ✅ **DONE** | Phase A + Phase B complete. Every method consciously triaged via `/doc-sweep` decision tree. |
| 🔶 **NEEDS TRIAGE** | Phase A complete (structure clean). Methods not yet triaged. Use `/doc-sweep`. |
| ⬜ **TODO** | Not yet reviewed at all. |
| ⏭️ **SKIP** | No methods (registration stubs, domain wrappers). |

### Logging Status

| Status | Meaning |
|--------|---------|
| ✅ | Uses `JuiceLogger` — logging implemented per SOP. |
| **N/A** | Logging not applicable (registration stub, recipe, data class). |

---

## Context

**Phase A (structural)** was completed across the entire codebase in Apr 2026: headers, WHY blocks, export tooltips, history sanitization, visibility rules.

**Phase B (method comprehension)** was completed for core architecture files. Concrete effects, utilities, and domain bases still need triage via `/doc-sweep`.

**Logging sprint (Apr–May 2026)** instrumented 55 scripts with `JuiceLogger`. Files without logging are exclusively registration stubs, recipes, and data classes.

**Property family** deferred to V1.1 and deleted from master. Not tracked here. See `Documentation/Future/Juice_V1.1_Features.md` §4.

---

## Base Classes

| File | Doc | Log | Notes |
|------|-----|-----|-------|
| `JuiceBase.gd` | ✅ | ✅ | |
| `JuiceEffectBase.gd` | ✅ | ✅ | |
| `JuiceRecipe.gd` | ✅ | **N/A** | |
| `JuiceLedger.gd` | ✅ | **N/A** | |
| `JuiceTriggerRouter.gd` | ✅ | ✅ | |
| `TriggerHintBuilder.gd` | ✅ | **N/A** | |
| `Juice2DRecipe.gd` | ✅ | **N/A** | |
| `Juice3DRecipe.gd` | ✅ | **N/A** | |
| `JuiceControlRecipe.gd` | ✅ | **N/A** | |
| `Juice2DAppearanceEffect.gd` | ✅ | **N/A** | |
| `Juice3DAppearanceEffect.gd` | ✅ | **N/A** | |
| `JuiceControlAppearanceEffect.gd` | ✅ | **N/A** | |
| `Juice2DEffectBase.gd` | ⏭️ | **N/A** | |
| `Juice3DEffectBase.gd` | ⏭️ | **N/A** | |
| `JuiceControlEffectBase.gd` | ⏭️ | **N/A** | |

---

## Domain Nodes

| File | Doc | Log | Notes |
|------|-----|-----|-------|
| `JuiceControl.gd` | ✅ | ✅ | Phase B complete. All L2 hooks already had `##` docs. Pivot conflict checker well-commented. |
| `Juice2D.gd` | ✅ | ✅ | Phase B complete. All L2 hooks already documented. |
| `Juice3D.gd` | ✅ | ✅ | Phase B complete. All L2 hooks, working material lifecycle, and outline support documented. |

---

## Domain Transform Bases

| File | Doc | Log | Notes |
|------|-----|-----|-------|
| `JuiceControlTransformEffect.gd` | ✅ | ✅ | Phase B complete. Lifecycle orchestration, dispatch, cache invalidation, and unit conversion documented. |
| `Juice2DTransformEffect.gd` | ✅ | ✅ | Phase B complete. Pivot compensation and Node2D size heuristic documented. |
| `Juice3DTransformEffect.gd` | ✅ | ✅ | Phase B complete. Split pivot strategy and AABB size heuristic documented. |

---

## Control Effects

| File | Doc | Log | Notes |
|------|-----|-----|-------|
| `TransformControlJuiceEffect.gd` | ✅ | ✅ | Phase B complete. 35 methods triaged, 2 documented (ledger capture, Sequencer stacking fix). |
| `AppearanceControlJuiceEffect.gd` | ✅ | ✅ | Re-audit confirmed. 25 methods triaged, 0 new (existing comments adequate). |
| `NoiseControlJuiceEffect.gd` | ✅ | ✅ | Phase B complete. 18 methods triaged, 1 documented (noise→delta conversion). |
| `ProgressTransformControlJuiceEffect.gd` | ✅ | ✅ | Phase B complete. 24 methods triaged, 3 documented (accumulation model, delta stashing, drift absorption). |
| `ShakeControlJuiceEffect.gd` | ✅ | ✅ | Phase B complete. 14 methods triaged, 0 documented (all already well-commented or self-describing). |
| `SquashStretchControlJuiceEffect.gd` | ✅ | ✅ | Re-audit confirmed. 12 methods triaged, 0 new (sin-curve, volume math, pivot, interrupt identity all already documented). |
| `VFXControlJuiceEffect.gd` | ✅ | **N/A** | Domain wrapper — logging in base. |

---

## 2D Effects

| File | Doc | Log | Notes |
|------|-----|-----|-------|
| `Transform2DJuiceEffect.gd` | ✅ | ✅ | Phase B complete. 37 methods triaged, 1 documented (2D pivot inference strategy). |
| `Appearance2DJuiceEffect.gd` | ✅ | ✅ | Re-audit: _on_animate_start documented (modulate vs self_modulate + OUTLINE path). _perform_from_capture filler replaced. 25 methods triaged, 2 documented. |
| `Noise2DJuiceEffect.gd` | ✅ | ✅ | Phase B complete. 19 methods triaged, 1 documented (visual center heuristic). |
| `ProgressTransform2DJuiceEffect.gd` | ✅ | ✅ | Phase B complete. 23 methods triaged, 1 documented (pivot recomputation in absorb). |
| `Shake2DJuiceEffect.gd` | ✅ | ✅ | Phase B complete. 16 methods triaged, 0 documented (all already well-commented). |
| `SquashStretch2DJuiceEffect.gd` | ✅ | ✅ | Re-audit: _on_animate_start improved with deliberate no-pivot explanation (Node2D has no pivot_offset). 11 methods triaged, 1 documented. |
| `VFX2DJuiceEffect.gd` | ✅ | **N/A** | Domain wrapper. |

---

## 3D Effects

| File | Doc | Log | Notes |
|------|-----|-----|-------|
| `Transform3DJuiceEffect.gd` | ✅ | ✅ | Phase B complete. 38 methods triaged, 1 documented (AABB-based scale pivot). Re-audit: stripped cross-domain comparison. |
| `Appearance3DJuiceEffect.gd` | ✅ | ✅ | Re-audit: _apply_effect documented (indirect write contract — domain owns all material writes). 24 methods triaged, 1 documented. |
| `Noise3DJuiceEffect.gd` | ✅ | ✅ | Phase B complete. 18 methods triaged, 0 documented (all self-describing or parallels 2D). |
| `ProgressTransform3DJuiceEffect.gd` | ✅ | ✅ | Phase B complete. 22 methods triaged, 1 documented (_absorb pivot arc). Bug fixed: _collect_aabb pass-by-value replaced with base class calls. |
| `Shake3DJuiceEffect.gd` | ✅ | ✅ | Phase B complete. 16 methods triaged, 0 documented. |
| `SquashStretch3DJuiceEffect.gd` | ✅ | ✅ | Re-audit confirmed. 13 methods triaged, 0 new (sqrt volume math and pivot_offset compensation already documented). |
| `VFX3DJuiceEffect.gd` | ✅ | **N/A** | Domain wrapper. |

---

## Camera

| File | Doc | Log | Notes |
|------|-----|-----|-------|
| `Camera2DJuiceEffect.gd` | ✅ | ✅ | 15 methods triaged, 5 documented (_needs_sustain: shake-sustain rationale; _on_animate_start: SHAKE-only note; _apply_effect: re-discover-every-frame rationale; _restore_to_natural: delta-subtraction; _apply_position: SHAKE/DET × PIXELS/PERCENT_VIEWPORT dual-branch). |
| `Camera3DJuiceEffect.gd` | ✅ | ✅ | 15 methods triaged, 7 documented (_needs_sustain, _on_animate_start, _apply_effect, _restore_to_natural, _apply_position: local-space basis note, _apply_fov: zoom_offset channel note, _find_camera_3d: no-bootstrap rationale). |
| `CameraJuiceUtility.gd` | ✅ | ✅ | 8 methods triaged, 5 documented (_ready: group reg, _initialize_camera: dual-domain detection + default rescale, _physics_process: idle-guard + physics order, _apply_to_3d: undo-then-reapply pattern, _apply_to_2d: Camera2D offset/Vector2-zoom differences). |

---

## Screen

| File | Doc | Log | Notes |
|------|-----|-----|-------|
| `ScreenJuiceEffect.gd` | ✅ | ✅ | 15 methods triaged, 2 documented (_apply_effect: re-discover rationale; _remove_contribution: 7-channel delta + config-reset contract). |
| `ScreenJuiceUtility.gd` | ✅ | ✅ | 7 methods triaged, 4 documented (_ready: priority=100 order; _exit_tree: static-ref clear; _process: idle-guard + passthrough-once; _reset_shader_to_passthrough: zoom=1.0 not 0.0 rationale). |
| `ScreenOverlayJuiceEffectBase.gd` | ✅ | ✅ | 14 methods triaged, 6 documented (_on_animate_start: provider-vs-singleton + one-shot-return skip; _apply_effect: direction-alpha semantics + TextureRect branch; _on_animate_in/out_complete: peak-lock pattern; _restore_to_natural: provider.clear contract; _get_interrupt_identity: cross-domain interrupt). |
| `JuiceScreenOverlayProvider.gd` | ✅ | ✅ | |
| `ScreenOverlay2DJuiceEffect.gd` | ⏭️ | **N/A** | Domain wrapper. |
| `ScreenOverlay3DJuiceEffect.gd` | ⏭️ | **N/A** | Domain wrapper. |
| `ScreenOverlayControlJuiceEffect.gd` | ⏭️ | **N/A** | Domain wrapper. |

---

## Meta Effects

| File | Doc | Log | Notes |
|------|-----|-----|-------|
| `TimeJuiceEffectBase.gd` | ✅ | ✅ | |
| `PauseJuiceEffectBase.gd` | ✅ | ✅ | |
| `TrailJuiceEffect.gd` | ✅ | ✅ | |
| `_JuiceSceneActionOrchestrator.gd` | ✅ | ✅ | |
| `VFXJuiceEffectBase.gd` | ✅ | ✅ | 28 methods triaged, 0 documented. Already excellent: all virtual hooks, orchestrators, and helpers have `#`/`##`. `intensity_multiplier_for_trigger` is a known stub returning 1.0 — candidly commented, cleanup deferred. |
| `VFXJuiceEffect.gd` | ✅ | ✅ | 20 methods triaged, 0 documented. Already excellent: all modes, particle helpers, auto-free, and cull strategy documented. No filler detected. |
| `SceneActionJuiceUtilityBase.gd` | ✅ | ✅ | 9 methods triaged, 2 documented (_validate_property: destructive-action hide logic; _supports_editor_preview: scene-destroy rationale). |
| `CallMethodJuiceUtilityBase.gd` | ✅ | ✅ | 10 methods triaged, 3 documented (_on_animate_start, _on_animate_in_complete: ON_COMPLETE timing note, _restore_to_natural: stale-ref rationale). |
| `CallMethodEntry.gd` | ✅ | **N/A** | Pure data class. All vars have `##`. 4 boilerplate methods, 0 documented. |
| `SignalEmitJuiceUtilityBase.gd` | ✅ | ✅ | 7 methods triaged, 2 documented (_on_animate_start: no-resolve note; _on_animate_in_complete: animate_in distinction). |
| `SignalEmitEntry.gd` | ✅ | **N/A** | Pure data class. All vars have `##`, no `_get_configuration_warnings` (unlike CallMethodEntry — not a bug). 4 boilerplate methods, 0 documented. |

---

## Meta Domain Wrappers

| File | Doc | Log |
|------|-----|-----|
| `CallMethod2DJuiceUtility.gd` | ⏭️ | **N/A** |
| `CallMethod3DJuiceUtility.gd` | ⏭️ | **N/A** |
| `CallMethodControlJuiceUtility.gd` | ⏭️ | **N/A** |
| `SignalEmit2DJuiceUtility.gd` | ⏭️ | **N/A** |
| `SignalEmit3DJuiceUtility.gd` | ⏭️ | **N/A** |
| `SignalEmitControlJuiceUtility.gd` | ⏭️ | **N/A** |
| `Time2DJuiceEffect.gd` | ⏭️ | **N/A** |
| `Time3DJuiceEffect.gd` | ⏭️ | **N/A** |
| `TimeControlJuiceEffect.gd` | ⏭️ | **N/A** |
| `Pause2DJuiceEffect.gd` | ⏭️ | **N/A** |
| `Pause3DJuiceEffect.gd` | ⏭️ | **N/A** |
| `PauseControlJuiceEffect.gd` | ⏭️ | **N/A** |
| `SceneAction2DJuiceUtility.gd` | ⏭️ | **N/A** |
| `SceneAction3DJuiceUtility.gd` | ⏭️ | **N/A** |
| `SceneActionControlJuiceUtility.gd` | ⏭️ | **N/A** |

---

## Editor

| File | Doc | Log | Notes |
|------|-----|-----|-------|
| `JuiceLogger.gd` | ✅ | ✅ | 14 methods triaged, 0 documented. Fully documented: all 6 public log categories have `##`, all private helpers have `#` with routing/format/gate rationale. Best-documented file in the sweep. |
| `JuiceDebugReport.gd` | ✅ | ✅ | 7 methods triaged, 0 documented. All helpers have `#` explaining ring-buffer-vs-file rationale, type-safe walk, relative path for scene dock alignment. No edits needed. |
| `JuicePreviewDirector.gd` | ✅ | ✅ | |
| `JuiceEditorContext.gd` | ✅ | **N/A** | |
| `JuiceProjectSettings.gd` | ✅ | ✅ | |

---

## Utilities

| File | Doc | Log | Notes |
|------|-----|-----|-------|
| `Interaction2DJuiceUtility.gd` | ✅ | ✅ | 24 methods triaged, 15 documented: 8 private (#: _ready, _ensure_shapes, _unhandled/_input split, _wire_zone_signals, _on_zone_object_entered/exited, _sync_user_signals) + 7 public (##: set_enabled, reset, simulate_click, simulate_input_action, simulate_zone_enter/exit, get_configuration_summary). |
| `Interaction3DJuiceUtility.gd` | ✅ | ✅ | 24 methods triaged, 7 documented (## public API only — private methods already had inline comments or mirror 2D patterns; _sync_user_signals has no-remove_user_signal note already). |
| `SoftTrigger2DJuiceUtility.gd` | ✅ | ✅ | 18 methods triaged, 4 documented: _process (shape-boundary routing), _on_object_entered (first-in-wins), _release_all (0.0→-1.0 two-step), _ensure_juice_siblings (dirty-flag cache). |
| `SoftTrigger3DJuiceUtility.gd` | ✅ | ✅ | 21 methods triaged, 5 documented: _process (surface vs volumetric routing), _release_all (0.0→-1.0), _ensure_collision_shape (BoxShape3D + editor owner), _update_auto_shape_size (editor-only guard), _ensure_juice_siblings (dirty-flag cache). |
| `SoftTriggerControlJuiceUtility.gd` | ✅ | ✅ | 9 methods triaged, 1 documented: _on_mouse_exited (0.0→-1.0 two-step release rationale). |
| `SignalRelayJuiceUtility.gd` | ✅ | ✅ | 3 methods triaged, 2 documented: _ready (5-stage validation before connect), _on_source_triggered (optional _interactor arg for signals-with-args compatibility). |
| `TimeCoordinatorJuiceUtility.gd` | ✅ | ✅ | |
| `_JuiceTransitionHandler.gd` | ✅ | ✅ | 13 methods triaged, 9 documented: _process (manual detached-effect tick), _execute_no_transition (process_frame settle wait), _execute_overlay_transition (7-phase cover→action→reveal with async load overlap), _execute_scene_transition (signal-contract vs fallback-timer duality), _perform_scene_action (async-loaded resource preference), _create_overlay_effect_cover (TO_COLOR + PLAY_IN_ONLY), _configure_overlay_effect_reveal (in-place mutation for reuse), _start_async_load (cache check), _await_async_load (frame-polling + failure warnings). |

---

## Plugin Entry

| File | Doc | Log |
|------|-----|-----|
| `juice_plugin.gd` | ✅ | **N/A** |

---

## Summary

### Documentation

| Status | Count |
|--------|-------|
| ✅ DONE | 26 |
| 🔶 NEEDS TRIAGE | 38 |
| ⬜ TODO | 2 |
| ⏭️ SKIP | 24 |

### Logging

| Status | Count |
|--------|-------|
| ✅ Instrumented | 55 |
| **N/A** | 35 |
