---
description: Port a V0 Juice effect to V1 architecture (Sequential 2D → Control → 3D)
---

You are in PORT MODE.

This workflow ports a V0 Juice effect (comp) to V1 architecture (resource-based effect).
It enforces **strict sequential domain porting** (2D → Control → 3D) to prevent context overflow and ensure quality.

**Skills auto-invoked:** `@juice-architecture`, `@unit-test-patterns`, `@verify-claims`

**Parent workflow:** `/architecture`

---

## Anti-Patterns This Workflow Prevents

| To Prevent: | You MUST: |
|---|---|
| **Context Overflow** | Do strict sequential porting (2D → Control → 3D). You MUST finish and test 2D before even looking at Control. |
| **Copying V0 bugs into V1** | Explicitly identify architectural improvements (e.g., "delta-first instead of direct write") in Step 1 before coding. |
| **Wrong structure** | Use the `@juice-inspector-layout` skill to ensure the correct top-to-bottom section order in scripts. |
| **No tests** | Write full unit tests covering: basic apply, return to natural, ALL effect-specific math/behaviors, and stacking before moving to the next domain. |
| **Self-evaluation** | Auto-run the test suite via shell/bat script. You cannot claim an effect works without executing the test suite. |
| **Loss of UX features** | Document visible UX behaviors (e.g., "bounces past target", "preserves volume") in Step 1, preventing silent feature cuts during mechanical porting. |

---

## Step 1: Read Before Touch (2D Domain)

Read ALL of these before writing any code:

1a. **Architecture quick reference** — understand where this fits:
```
Review: @juice-architecture layer contracts
```

1b. **Design doc section** for this effect category:
```
Read: Documentation/JuiceStack_Design.md
Find: the "Complete Effect Map" section for this effect type
```

1c. **Port Master Tracker** — confirm this effect isn't already ported:
```
Read: Documentation/Port_Master_Tracker.md
```

1d. **V0 source (2D ONLY)** — read the 2D variant first:
```
Read: addons/juice/2D/[Effect]2DJuiceComp.gd
```

1e. Present a summary to the user:
```
## Port Analysis — [EffectName] (2D)

V0 files read: [list]
V0 properties: [list all @export vars and enums]
V0 behaviors: [list key behaviors, e.g., "uses sin curve", "has volume preservation" - not just coding terms, actual UX features that a user experiences]

V1 improvements over V0:
- [List what V1 does BETTER, not just the same]
- [e.g., "delta-first instead of direct write", "no _process override needed"]

Domain-specific differences to anticipate:
- Control: [any Control-only behavior]
- 2D: [any 2D-only behavior]
- 3D: [any 3D-only behavior, e.g., Vector3 instead of Vector2]
```

Wait for user approval before proceeding.

---

## Step 2: Port 2D Domain

2a. Create `addons/Juice_V1/2D/[Effect]2DJuiceEffect.gd`

**Rules:**
- Use `@juice-inspector-layout` for structure
- Use the EXACT naming from `JuiceStack_Design.md` Effect Map
- Port ALL V0 properties — no cuts, no deferrals
- Implement `_apply_effect()` math as delta calculations (NEVER write to target)
- Set `_contributes_position/rotation/scale` flags correctly
- Override `_get_seq_contribution()` if the effect contributes channels beyond the base pos/rot/scale (e.g., `modulate`, `self_modulate` must be added to the returned Dictionary).
- Include the full conditional export system (`_get_property_list`, `_set`, `_get`)

2b. **Validate header formatting** (MANDATORY — prevents broken tooltips in Godot):
- Each script MUST follow the Juice2D.gd pattern:
  - First line: Single `##` with concise description (becomes the tooltip)
  - Optional: Additional `##` lines for more detail (won't show in tooltip)  
  - Then: `# ============================================================================` separator for detailed WHAT/WHY section
- WRONG: Multiple `##` lines before the separator (causes broken tooltips)

2c. **Register in recipe whitelist** (MANDATORY):
- Add to `_CONCRETE_EFFECTS` in `addons/Juice_V1/Base Classes/Juice2DRecipe.gd`

2d. **Write Tests**: Create `tests/suites/Test[Effect]2D.gd` and register in `JuiceTestRunner.gd`.
**Minimum test coverage:**
- Basic effect applies (visible change during animation)
- Returns to natural after completion
- Effect-specific behavior (e.g., volume preservation for SquashStretch)
- Stacking with Transform effect on same target

2e. **Run Test Suite**:
```powershell
cmd /c "D:\Godot_projekti\juice-demo\tests\run_tests.bat"
```
Wait for tests to pass. If failures occur, fix them before moving to Step 3.

---

## Step 3: Port Control Domain

3a. **Read V0 Source**: `addons/juice/Control/[Effect]ControlJuiceComp.gd`
- Identify Domain-specific differences (e.g., Control-only behavior, UI quirks like containers re-sorting).

3b. **Create**: `addons/Juice_V1/Control/[Effect]ControlJuiceEffect.gd`
- Adapt 2D logic for Control.
- Follow all coding rules from Step 2a/2b.

3c. **Register**: Add to `JuiceControlRecipe.gd`.

3d. **Write Tests**: Create `tests/suites/Test[Effect]Control.gd` and register in `JuiceTestRunner.gd`. Follow minimum coverage requirements.

3e. **Run Test Suite**:
```powershell
cmd /c "D:\Godot_projekti\juice-demo\tests\run_tests.bat"
```
Must pass before proceeding.

---

## Step 4: Port 3D Domain

4a. **Read V0 Source**: `addons/juice/3D/[Effect]3DJuiceComp.gd`
- Identify Domain-specific differences (e.g., Vector3 instead of Vector2).

4b. **Create**: `addons/Juice_V1/3D/[Effect]3DJuiceEffect.gd`
- Adapt logic for 3D.
- Follow all coding rules from Step 2a/2b.

4c. **Register**: Add to `Juice3DRecipe.gd`.

4d. **Write Tests**: Create `tests/suites/Test[Effect]3D.gd` and register in `JuiceTestRunner.gd`. Follow minimum coverage requirements.

4e. **Run Test Suite**:
```powershell
cmd /c "D:\Godot_projekti\juice-demo\tests\run_tests.bat"
```
Must pass before proceeding.

---

## Step 5: Realistic Testing

Run the comprehensive integration tests using the `/realistic-test` workflow.
This verifies the effect works in real-world scenarios (stacking, containers, sequencers) across all domains.

---

## Step 6: Commit + Update Tracker

```powershell
cd "D:\Godot_projekti\juice-demo"; git add -A; git commit -m "Port [EffectName] effect to V1 — all domains + tests"
```

Update `Documentation/Port_Master_Tracker.md`:
- Set status to ✅ for all 3 domain variants
- Add test file references
- Update the date

Report completion to user using this exact format:
```
## Port Complete — [EffectName]

**Files created:**
- addons/Juice_V1/Control/[Effect]ControlJuiceEffect.gd
- addons/Juice_V1/2D/[Effect]2DJuiceEffect.gd
- addons/Juice_V1/3D/[Effect]3DJuiceEffect.gd
- tests/suites/Test[Effect]Control.gd
- tests/suites/Test[Effect]2D.gd
- tests/suites/Test[Effect]3D.gd

**Test results:** X passed, 0 failed (full suite + realistic tests)
**Improvements over V0:** [list]
**Domain-specific adaptations made:** 
- Control: [list]
- 3D: [list]
**Port Master Tracker:** Updated
```
