---
description: Port a V0 Juice effect to V1 architecture — batches all 3 domains, auto-tests, auto-commits
---

You are in PORT MODE.

This workflow ports a V0 Juice effect (comp) to V1 architecture (resource-based effect).
It enforces batching all 3 domains together, using code templates, and auto-verifying.

**Skills auto-invoked:** `@juice-architecture`, `@verify-claims`

---

## Anti-Patterns This Workflow Prevents

| Anti-Pattern | Prevention |
|---|---|
| Porting one domain, forgetting others | Step 3 batches all 3 domains |
| Copying V0 bugs into V1 | Step 2 identifies improvements |
| Wrong structure | Templates from @juice-architecture |
| No tests | Step 4 writes tests BEFORE marking done |
| Self-evaluation | Step 5 auto-runs test suite |

---

## Step 1: Read Before Touch

Read ALL of these before writing any code:

1a. **Architecture quick reference** — understand where this fits:
```
Auto-invoked: @juice-architecture-contracts
Review: One-page layer contracts + decision tree
```

1b. **Design doc section** for this effect category:
```
Read: Documentation/JuiceStack_Design.md
Find: the "Complete Effect Map" section for this effect type
```

1c. **V0 source** — read ALL domain variants in parallel:
```
Read: addons/juice/Control/[Effect]ControlJuiceComp.gd
Read: addons/juice/2D/[Effect]2DJuiceComp.gd
Read: addons/juice/3D/[Effect]3DJuiceComp.gd
```

1d. **Port Master Tracker** — confirm this effect isn't already ported:
```
Read: Documentation/Port_Master_Tracker.md
```

1e. Present a summary to the user:
```
## Port Summary — [EffectName]

V0 files read: [list]
V0 properties: [list all @export vars and enums]
V0 behaviors: [list key behaviors, e.g., "uses sin curve", "has volume preservation"]

V1 improvements over V0:
- [List what V1 does BETTER, not just the same]
- [e.g., "delta-first instead of direct write", "no _process override needed"]

Domain-specific differences:
- Control: [any Control-only behavior]
- 2D: [any 2D-only behavior]
- 3D: [any 3D-only behavior, e.g., Vector3 instead of Vector2]
```

Wait for user approval before proceeding.

---

## Step 2: Create All 3 Domain Effects (Batch)

Using the templates from `@juice-architecture`:

2a. Create `addons/Juice_V1/Control/[Effect]ControlJuiceEffect.gd`
2b. Create `addons/Juice_V1/2D/[Effect]2DJuiceEffect.gd`
2c. Create `addons/Juice_V1/3D/[Effect]3DJuiceEffect.gd`

**Rules:**
- Copy structure from `effect-template-control.gd`, adapt for each domain
- Use the EXACT naming from `JuiceStack_Design.md` Effect Map
- Port ALL V0 properties — no cuts, no deferrals
- Implement `_apply_effect()` math as delta calculations (NEVER write to target)
- Set `_contributes_position/rotation/scale` flags correctly
- Override `_get_seq_contribution()` if the effect contributes channels beyond the base pos/rot/scale (the base implementation in domain effect bases already handles those three). New channels (e.g., `modulate`, `self_modulate`) must be added to the returned Dictionary keyed by Godot property name.
- Include the full conditional export system (`_get_property_list`, `_set`, `_get`)

2d. **Register in recipe whitelists** (MANDATORY — effects won't appear in inspector without this):
- Add to `_CONCRETE_EFFECTS` in `addons/Juice_V1/Base Classes/JuiceControlRecipe.gd`
- Add to `_CONCRETE_EFFECTS` in `addons/Juice_V1/Base Classes/Juice2DRecipe.gd`
- Add to `_CONCRETE_EFFECTS` in `addons/Juice_V1/Base Classes/Juice3DRecipe.gd`

2e. **Validate header formatting** (MANDATORY — prevents broken tooltips in Godot):
- Each script MUST follow the Juice2D.gd pattern:
  - First line: Single `##` with concise description (becomes the tooltip)
  - Optional: Additional `##` lines for more detail (won't show in tooltip)  
  - Then: `# ============================================================================` separator for detailed WHAT/WHY section
- WRONG: Multiple `##` lines before the separator (causes broken tooltips)
- Reference: `addons/Juice_V1/Base Classes/Juice2D.gd` lines 1-12`

---

## Step 3: Write Tests (All 3 Domains)

Using the test template from `@juice-architecture`:

3a. Create `tests/suites/Test[Effect]Control.gd`
3b. Create `tests/suites/Test[Effect]2D.gd`
3c. Create `tests/suites/Test[Effect]3D.gd`
3d. Register all 3 in `tests/JuiceTestRunner.gd` → `_register_suites()`

**Minimum test coverage per effect:**
- Basic effect applies (visible change during animation)
- Returns to natural after completion
- Effect-specific behavior (e.g., volume preservation for SquashStretch)
- Stacking with Transform effect on same target

---

## Step 4: Run Full Test Suite

// turbo
```powershell
& "C:\Portable Software\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64_console.exe" --headless --path "D:\Godot projekti\juice-demo" res://tests/run_tests.tscn
```

Read results:
// turbo
```powershell
Get-Content "D:\Godot projekti\juice-demo\tests\results\summary.log"
```

**Success criteria:**
- ALL new tests pass
- ALL previously passing tests still pass (no regressions)
- Zero failures

**If failures:** Do NOT proceed. Invoke `/bugfix` with the failures.

---

## Step 5: Commit + Update Tracker

// turbo
```powershell
cd "D:\Godot projekti\juice-demo"; git add -A; git commit -m "Port [EffectName] effect to V1 — all 3 domains + tests"
```

Update `Documentation/Port_Master_Tracker.md`:
- Set status to ✅ for all 3 domain variants
- Add test file references
- Update the date

---

## Step 6: Report

```
## Port Complete — [EffectName]

**Files created:**
- addons/Juice_V1/Control/[Effect]ControlJuiceEffect.gd
- addons/Juice_V1/2D/[Effect]2DJuiceEffect.gd
- addons/Juice_V1/3D/[Effect]3DJuiceEffect.gd
- tests/suites/Test[Effect]Control.gd
- tests/suites/Test[Effect]2D.gd
- tests/suites/Test[Effect]3D.gd

**Test results:** X passed, 0 failed (full suite)
**Improvements over V0:** [list]
**Port Master Tracker:** Updated
```
