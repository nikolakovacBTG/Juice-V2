# Juice V1 — Project Status

> Auto-generated from deep scan on 2026-03-28. Update as work progresses.

## Architecture Summary

| Layer | V0 (Legacy) | V1 (Current) |
|-------|-------------|--------------|
| Effect model | Node-per-effect (`JuiceCompBase`) | Resource-per-effect (`JuiceEffectBase`) |
| Host node | Each comp IS the node | Domain nodes: `JuiceControl`, `Juice2D`, `Juice3D` |
| Recipe | N/A (chaining via NodePath) | `JuiceRecipe` resource (array of effects) |
| Write pattern | Each comp writes directly | Domain node aggregates deltas, writes once |
| Trigger | Per-comp auto-connect | Per-node trigger ownership |
| Mode | N/A | STACK (overlay) / SEQUENCER (stagger) |

## Ported Effects (V1 — DONE)

All 5 effect types exist in all 3 domains (15 total effect scripts):

| Effect Type | Control | 2D | 3D | Status |
|-------------|---------|----|----|--------|
| **Transform** | `TransformControlJuiceEffect` | `Transform2DJuiceEffect` | `Transform3DJuiceEffect` | ✅ Complete |
| **Shake** | `ShakeControlJuiceEffect` | `Shake2DJuiceEffect` | `Shake3DJuiceEffect` | ✅ Complete |
| **Noise** | `NoiseControlJuiceEffect` | `Noise2DJuiceEffect` | `Noise3DJuiceEffect` | ✅ Complete |
| **Spring** | `SpringControlJuiceEffect` | `Spring2DJuiceEffect` | `Spring3DJuiceEffect` | ✅ Complete |
| **SquashStretch** | `SquashStretchControlJuiceEffect` | `SquashStretch2DJuiceEffect` | `SquashStretch3DJuiceEffect` | ✅ Complete |

## Base Classes (V1 — DONE)

| Class | File | Status |
|-------|------|--------|
| `JuiceBase` | `Base Classes/JuiceBase.gd` | ✅ Complete — STACK + SEQUENCER modes, triggers, lifecycle |
| `JuiceEffectBase` | `Base Classes/JuiceEffectBase.gd` | ✅ Complete — Pure delta calculator contract |
| `JuiceRecipe` | `Base Classes/JuiceRecipe.gd` | ✅ Complete |
| `JuiceControl` | `Base Classes/JuiceControl.gd` | ✅ Complete — Container hold pattern |
| `Juice2D` | `Base Classes/Juice2D.gd` | ✅ Complete |
| `Juice3D` | `Base Classes/Juice3D.gd` | ✅ Complete |
| `JuiceControlRecipe` | `Base Classes/JuiceControlRecipe.gd` | ✅ Complete |
| `Juice2DRecipe` | `Base Classes/Juice2DRecipe.gd` | ✅ Complete |
| `Juice3DRecipe` | `Base Classes/Juice3DRecipe.gd` | ✅ Complete |
| `JuiceControlEffectBase` | `Base Classes/JuiceControlEffectBase.gd` | ✅ Complete |
| `Juice2DEffectBase` | `Base Classes/Juice2DEffectBase.gd` | ✅ Complete |
| `Juice3DEffectBase` | `Base Classes/Juice3DEffectBase.gd` | ✅ Complete |
| `JuiceControlTransformEffect` | `Base Classes/JuiceControlTransformEffect.gd` | ✅ Complete |
| `Juice2DTransformEffect` | `Base Classes/Juice2DTransformEffect.gd` | ✅ Complete |
| `Juice3DTransformEffect` | `Base Classes/Juice3DTransformEffect.gd` | ✅ Complete |

## Unported V0 Effects (NOT YET in V1)

These V0 effects exist in `addons/juice/` but have no V1 equivalent yet:

### Appearance (HIGH PRIORITY — Design doc exists in Done/)
- [ ] `TintJuiceComp` → Appearance effect (tint channel)
- [ ] `OverbrightJuiceComp` → Appearance effect (overbright channel)
- [ ] `FadeJuiceComp` → Appearance effect (fade/alpha channel)
- [ ] `GrayscaleJuiceComp` → Appearance effect (grayscale channel)
- [ ] `DissolveJuiceComp` → Appearance effect (dissolve channel)
- [ ] `BlendModeJuiceComp` → Appearance effect (blend mode channel)
- [ ] `FlickerJuiceComp` → Appearance effect (flicker temporal layer)

### Outline
- [ ] `OutlineJuiceComp` → Absorbed into Appearance per design doc

### Visibility
- [ ] `VisibilityJuiceComp` → Absorbed into Appearance per design doc

### Camera
- [ ] `CameraShake2DJuiceComp`
- [ ] `CameraShake3DJuiceComp`
- [ ] `CameraZoom2DJuiceComp`
- [ ] `CameraZoom3DJuiceComp`

### Screen
- [ ] `ScreenFlashJuiceComp`
- [ ] `ScreenFreezeJuiceComp`
- [ ] `TimeScaleJuiceComp`

### VFX
- [ ] `TrailJuiceComp`
- [ ] `AfterImageJuiceComp`
- [ ] `ParticleEmitJuiceComp`
- [ ] `ParticleBurstJuiceComp`

### Events/Flow
- [ ] `CallMethodJuiceUtility`
- [ ] `EmitSignalJuiceUtility`
- [ ] `PlaySoundJuiceUtility`
- [ ] `SpawnSceneJuiceUtility`

### Property
- [ ] `PropertyJuiceComp` (generic property tweener)

### Utilities (remain as Nodes per design doc)
- [ ] `Interaction2DJuiceUtility`
- [ ] `Interaction3DJuiceUtility`

## Shaders Present in V1

| Shader | Status |
|--------|--------|
| `screen_juice.gdshader` | Present |
| `blend_mode_2d` | Present |
| `dissolve_2d` / `dissolve_3d` | Present |
| `grayscale_2d` / `grayscale_3d` | Present |
| `outline_2d` | Present |
| `overlay_2d` / `overlay_3d` | Present |

## Test Coverage

19 test suites in `tests/suites/` covering:
- Node properties (36 tests): timing, loops, triggers, easing
- Transform (Control: 12, 2D: 9, 3D: 8)
- SquashStretch (Control: 5, 2D: 3, 3D: 3)
- Shake (Control: 5, 2D: 3, 3D: 3)
- Noise (Control: 4, 2D: 3, 3D: 3)
- Spring (Control: 4, 2D: 2, 3D: 2)

## Documentation Cross-Reference

| Document | In Done/? | Corresponding Code | Status |
|----------|-----------|-------------------|--------|
| `Transform_FromTo_Design.md` | ✅ Done | All Transform effects | ✅ Implemented |
| `DONE_Appearance_Comp_Redesign.md` | ✅ Done | No V1 Appearance effect yet | ⚠️ DESIGN DONE, CODE NOT PORTED |
| `JuiceStack_Design.md` | Main docs | Core architecture | ✅ Architecture implemented |
| `Port_Master_Tracker.md` | Main docs | Tracking doc | Reference only |
| `Base_Architecture_Parity.md` | Main docs | Base classes | Reference |
| `!_REFRACTOR_PLAN.md` | Main docs | Refactoring plans | Reference |