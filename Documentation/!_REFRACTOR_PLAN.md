# Refactor: Extract Transform Intermediate Classes
Date: 2026-03-23
Status: In Progress

## Objective
Separate domain filtering (recipe type safety) from transform delta storage.
Domain effect bases become pure domain markers. New intermediate classes hold
`_pos_delta`/`_rot_delta`/`_scale_delta` for transform effects only.
Non-transform effects (Appearance, Progress, VFX, etc.) extend the domain base
directly without carrying unused transform fields.

## Scope
- Files affected: 21 (3 base strip + 3 new intermediate + 15 effect extends updates + 3 domain node cast updates)
- Systems impacted: Effect inheritance hierarchy, domain node write loop

## Changes
| Item | From | To | Status |
|------|------|-----|--------|
| JuiceControlEffectBase | Domain filter + transform deltas | Domain filter only | ⬜ |
| NEW JuiceControlTransformEffect | — | extends JuiceControlEffectBase, holds pos/rot/scale deltas | ⬜ |
| Juice2DEffectBase | Domain filter + transform deltas | Domain filter only | ⬜ |
| NEW Juice2DTransformEffect | — | extends Juice2DEffectBase, holds pos/rot/scale deltas | ⬜ |
| Juice3DEffectBase | Domain filter + transform deltas | Domain filter only | ⬜ |
| NEW Juice3DTransformEffect | — | extends Juice3DEffectBase, holds pos/rot/scale deltas | ⬜ |
| TransformControlJuiceEffect | extends JuiceControlEffectBase | extends JuiceControlTransformEffect | ⬜ |
| SquashStretchControlJuiceEffect | extends JuiceControlEffectBase | extends JuiceControlTransformEffect | ⬜ |
| NoiseControlJuiceEffect | extends JuiceControlEffectBase | extends JuiceControlTransformEffect | ⬜ |
| ShakeControlJuiceEffect | extends JuiceControlEffectBase | extends JuiceControlTransformEffect | ⬜ |
| SpringControlJuiceEffect | extends JuiceControlEffectBase | extends JuiceControlTransformEffect | ⬜ |
| Transform2DJuiceEffect | extends Juice2DEffectBase | extends Juice2DTransformEffect | ⬜ |
| SquashStretch2DJuiceEffect | extends Juice2DEffectBase | extends Juice2DTransformEffect | ⬜ |
| Noise2DJuiceEffect | extends Juice2DEffectBase | extends Juice2DTransformEffect | ⬜ |
| Shake2DJuiceEffect | extends Juice2DEffectBase | extends Juice2DTransformEffect | ⬜ |
| Spring2DJuiceEffect | extends Juice2DEffectBase | extends Juice2DTransformEffect | ⬜ |
| Transform3DJuiceEffect | extends Juice3DEffectBase | extends Juice3DTransformEffect | ⬜ |
| SquashStretch3DJuiceEffect | extends Juice3DEffectBase | extends Juice3DTransformEffect | ⬜ |
| Noise3DJuiceEffect | extends Juice3DEffectBase | extends Juice3DTransformEffect | ⬜ |
| Shake3DJuiceEffect | extends Juice3DEffectBase | extends Juice3DTransformEffect | ⬜ |
| Spring3DJuiceEffect | extends Juice3DEffectBase | extends Juice3DTransformEffect | ⬜ |
| JuiceControl._post_tick_write | cast to JuiceControlEffectBase | cast to JuiceControlTransformEffect | ⬜ |
| Juice2D._post_tick_write | cast to Juice2DEffectBase | cast to Juice2DTransformEffect | ⬜ |
| Juice3D._post_tick_write | cast to Juice3DEffectBase | cast to Juice3DTransformEffect | ⬜ |

## Validation Plan
- [ ] All references updated (grep verified)
- [ ] Godot project reimported (class_names registered)
- [ ] All existing tests pass (run full suite)
- [ ] No errors in output

## Rollback
git reset --hard 8fe378f
