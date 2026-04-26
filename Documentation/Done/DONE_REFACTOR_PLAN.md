# Refactor: Transform Magnitude Standardization
Date: 2026-04-12
Status: In Progress

## Objective
Add relative unit functionality (e.g. `OWN_SIZE`, `PARENT_SIZE`) to the Noise, Shake, and Progress effect families across all three domains (2D, Control, 3D), providing better UX for artists.

## Scope
- Files affected: All Transform, Noise, Shake, and Progress effect classes (2D, Control, 3D). And intermediate Transform bases.
- Systems impacted: Juice V1 Effects

## Changes
| Item | From | To | Status |
|------|------|-----|--------|
| Juice2DTransformEffect | Empty | Add size inference math | ⬜ Pending |
| JuiceControlTransformEffect | Empty | Add size inference math | ⬜ Pending |
| Juice3DTransformEffect | Empty | Add size inference math | ⬜ Pending |
| Transform2DJuiceEffect | Has math | Use inherited math | ⬜ Pending |
| TransformControlJuiceEffect | Has math | Use inherited math | ⬜ Pending |
| Transform3DJuiceEffect | Has math | Use inherited math | ⬜ Pending |
| Noise2/C/3DJuiceEffect | Hardcoded pixels | Selectable Unit Enum | ⬜ Pending |
| Shake2/C/3DJuiceEffect | Hardcoded pixels | Selectable Unit Enum | ⬜ Pending |
| Progress2/C/3DJuiceEffect | Hardcoded pixels | Selectable Unit Enum | ⬜ Pending |

## Validation Plan
- [ ] All references updated
- [ ] Godot project reloaded
- [ ] No errors in output
- [ ] Affected functionality tested

## Rollback
git revert to HEAD (clean state right now)
