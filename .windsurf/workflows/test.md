---
description: Run the Juice V1 automated test suite and report results
---

You are in TEST MODE.

**Skills auto-invoked:** `@verify-claims` (all pass/fail claims must cite evidence)

Your task is to execute tests, report results, and categorize failures.
You do NOT debug or propose fixes. You do NOT design new tests during execution.
Your outputs must be precise, structured, and clearly report all results.

---

## Authorization Gate (MANDATORY)

In test mode, I must NOT make write changes to production code.

If anything would require:

- **Migrations** (changing configs/behaviour across scenes or systems)
- **Any edits to** `.tscn`, `.tres`, `.res`, or addon scripts
- **Any revert/restore/cleanup** (including undoing user testing tweaks)

Then I must STOP, report the finding, and ask for explicit authorization before switching modes.

**Exception:** Editing test files (`tests/`) is allowed when fixing test expectation bugs (NOT production bugs).

Primary goals:
- Execute the automated test suite and report results.
- Detect deviations from expected behavior.
- Categorize failures as TEST BUG vs REAL BUG vs NEEDS DISCUSSION.
- Forward real failures to /debug for investigation.

GENERAL STOP RULE:
Do NOT propose fixes to production code. Do NOT make system changes outside test files. Only execute and report.

---

## Step 1: Run Full Automated Suite

// turbo
Run all tests headless:

```powershell
& "C:\Portable Software\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64_console.exe" --headless --path "D:\Godot projekti\juice-demo" res://tests/run_tests.tscn
```

**If Godot fails to start** (script parse errors, import errors):
1. Run an import pass first: `& "..." --headless --import --path "D:\Godot projekti\juice-demo"`
2. Ignore errors from `addons/juice/` (V0, .gdignored) — they are expected.
3. Retry the test run.

---

## Step 2: Read Log Files

// turbo
Read ALL generated log files in `tests/results/`:

```powershell
Get-Content "D:\Godot projekti\juice-demo\tests\results\summary.log"
```

Then read each suite log:
- `tests/results/{suite_name}.log` for each suite

Extract from each log:
- Total pass/fail counts
- Every `[FAIL]` line with full assertion message

---

## Step 3: Run Filtered Suites (Optional)

If the user wants to re-run specific suites or tests:

```powershell
# Filter by suite name
& "..." --headless --path "..." res://tests/run_tests.tscn -- --suite=node_properties

# Filter by test name
& "..." --headless --path "..." res://tests/run_tests.tscn -- --test=test_start_delay
```

---

## Step 4: Categorize Failures

For each `[FAIL]`, classify as one of:

| Category | Meaning | Action |
|----------|---------|--------|
| **TEST BUG** | Wrong test expectation, timing issue, bad assertion | Fix in test file (allowed in /test mode) |
| **REAL BUG** | Production code doesn't match design intent | Forward to /debug with full context |
| **NEEDS DISCUSSION** | Unclear whether test or code is wrong; may be architectural | Flag for user — do NOT touch code |

**Classification rules:**
- If the actual value is close but epsilon is too tight → TEST BUG (loosen epsilon)
- If timing-dependent and marginal → TEST BUG (increase wait time)
- If actual value is completely wrong (order of magnitude off, wrong sign) → likely REAL BUG
- If the feature being tested might not be fully implemented → NEEDS DISCUSSION
- If the failure pattern spans multiple domains → likely REAL BUG (architectural)

---

## Step 5: Report

Present results in this exact format:

```
## Test Results — [date]

**Total: X passed, Y failed out of Z assertions across N suites**

### Passing Suites
- suite_name: X/X ✅

### Failures

#### [CATEGORY] suite_name::test_name
- **Expected:** ...
- **Actual:** ...
- **Classification:** TEST BUG | REAL BUG | NEEDS DISCUSSION
- **Reasoning:** One sentence explaining why this classification.
- **Recommended action:** ...
```

---

## Step 6: Fix TEST BUGs (if any)

If failures are classified as TEST BUG:
1. Edit the test file to fix expectations
2. Re-run the affected suite to confirm the fix
3. Do NOT touch production code

---

## Step 7: Forward to /debug

For REAL BUG failures, prepare a handoff:

```
## /debug Handoff — [failure name]

**Failing test:** suite::test_name
**Expected:** ...
**Actual:** ...
**Relevant files:** (list production code files that likely contain the bug)
**Hypothesis:** (brief, if obvious — otherwise "needs investigation")
**Cross-domain check needed:** YES/NO (does this failure pattern suggest other domains are affected?)
```

---

## Available Test Suites

| Suite | File | Tests | Domain |
|-------|------|-------|--------|
| `node_properties` | `TestNodeProperties.gd` | start_delay, loop, retrigger, trigger_behaviour | Control (domain-agnostic features) |
| `transform_control` | `TestTransformControl.gd` | position units, rotation, scale, stacking, ext-move | Control |
| `transform_2d` | `TestTransform2D.gd` | position, rotation, scale, stacking, ext-move | 2D |
| `transform_3d` | `TestTransform3D.gd` | position, rotation, scale, stacking, ext-move | 3D |
| `squash_stretch_control` | `TestSquashStretchControl.gd` | vertical/horizontal, volume, end state | Control |
| `squash_stretch_2d` | `TestSquashStretch2D.gd` | squash, volume, end state | 2D |
| `squash_stretch_3d` | `TestSquashStretch3D.gd` | squash, volume, end state | 3D |

---

## Adding New Tests

When asked to add tests (outside /test mode):

1. Create `tests/suites/TestXxx.gd` extending `"res://tests/JuiceTestSuite.gd"`
2. Implement `get_suite_name()` and `get_test_methods()`
3. Register in `tests/JuiceTestRunner.gd` → `_register_suites()`
4. Run full suite to confirm no regressions

---

## Completion Criteria

A test session is complete when:

- All suites have been executed
- All failures are categorized (TEST BUG / REAL BUG / NEEDS DISCUSSION)
- TEST BUGs are fixed and re-verified
- REAL BUGs are documented for /bugfix handoff
- Results are reported in the structured format above

**Next step:** Hand REAL BUG failures to `/bugfix` (not `/debug`)
