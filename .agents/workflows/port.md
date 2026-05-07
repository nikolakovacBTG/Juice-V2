---
description: Port a Juice V2 effect across domains (Sequential 2D → Control → 3D)
---

You are in PORT MODE.

This workflow ports a Juice V2 effect across all three domains.
It enforces **strict sequential domain porting** (2D → Control → 3D) to prevent context overflow and ensure quality.
Effects are Resources with `@tool` (for dynamic `_get_property_list()`). The orchestrator owns lifecycle — effects remain pure delta calculators.

**Skills auto-invoked:** `@juice-architecture`, `@unit-test-patterns`, `@verify-claims`, `@doc-sweep`, `@juice-debug-logging`

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

1e. Present an **Implementation Plan Artifact** to the user:
```markdown
# Port Plan — [EffectName]

## V1 Improvements
- [List improvements]

## Proposed Changes
- [NEW] addons/Juice_V1/2D/[Effect]2DJuiceEffect.gd
- [NEW] addons/Juice_V1/Control/[Effect]ControlJuiceEffect.gd
- [NEW] addons/Juice_V1/3D/[Effect]3DJuiceEffect.gd
```

**Set `request_feedback = true`** in the Artifact metadata and wait for explicitly "Yes" or "/" in chat.

---

## Step 2: Port 2D Domain

2a. **Create File**: Use `mcp_create_script` for `addons/Juice_V1/2D/[Effect]2DJuiceEffect.gd`.

**Rules:**
- Use `@juice-inspector-layout` for structure.
- Follow `@registration-guard` for inclusion.
- Use the EXACT naming from `JuiceStack_Design.md`.
- Port ALL V0 properties — no cuts.
- Implement `_apply_effect()` math as delta calculations (NEVER write to target).
- Include the full conditional export system (`_get_property_list`, `_set`, `_get`).

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
& "[TEST_BAT]"
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
& "[TEST_BAT]"
```
Wait for tests to pass.

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
& "[TEST_BAT]"
```
Wait for tests to pass.

---

## Step 5: Realistic Testing

Run the comprehensive integration tests using the `/realistic-test` workflow.
This verifies the effect works in real-world scenarios (stacking, containers, sequencers) across all domains.

---

## Step 6: Documentation Sweep

Invoke `@doc-sweep` on every newly created effect and test file.
Do this **before committing** — the commit should include polished docs, not a TODO.

For each file created in Steps 2–4:
```
Apply: @doc-sweep
Targets: all new addons/Juice_V1/ scripts for this port
```

The sweep must verify:
- Class tooltip (`##` first line) — concise, action-oriented
- `@export` property tooltips (`##` above each export)
- `## Above public func` doc for every public method
- `## Above virtual func` doc for every override point
- No migration history comments ("V0", "ported", "refactor") remain
- WHAT/WHY/SYSTEM/DOES NOT header block is accurate and complete

---

## Step 7: Debug Logging

Invoke `@juice-debug-logging` on every newly created effect file.
Do this **before committing** — logging must ship with the effect, not be retrofitted.

For each new effect script:
```
Apply: @juice-debug-logging
Targets: all new addons/Juice_V1/ effect scripts for this port
```

Mandatory pre-implementation protocol (from QUALITY_GATE.md):
1. **State the contract** — what invariants this effect guarantees
2. **Map the chain** — list every method in call order that needs a log point
3. **Audit coverage** — confirm animate_start, delta compute, and animate_complete are covered

Then instrument. Skipping the protocol produces mechanical logging — that is a defect.

---

## Step 8: Commit + Update Tracker

```powershell
cd "[PROJECT_ROOT]"; git add -A; git commit -m "Port [EffectName] effect to V1 — all domains + tests + docs + logging"
```

Update `Documentation/Port_Master_Tracker.md`:
- Set status to ✅ for all ported domain variants
- Add test file references
- Update the date

Report completion to user using this exact format:
```markdown
## Port Complete — [EffectName]

**Visual Proof**:
![[EffectName] in action]([Path to screenshot captured via mcp_get_running_scene_screenshot])

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
**Doc sweep:** ✅ All new scripts swept
**Debug logging:** ✅ Contract/Chain/Coverage protocol applied
**Port Master Tracker:** Updated
```
