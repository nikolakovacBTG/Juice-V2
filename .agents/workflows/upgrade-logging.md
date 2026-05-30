---
description: Re-audit existing Juice debug logging and upgrade to full chain coverage. Enforces the Contract/Chain/Coverage protocol per effect family. Use this workflow when logging already exists but quality is insufficient.
---

You are in UPGRADE-LOGGING MODE.

This workflow re-audits and upgrades *existing* logging in instrumented Juice files.
It enforces the positivist standard: log the effect's computation chain faithfully so that
any bug is visible as a deviation in the log — no bug-guessing required.

**Skills auto-invoked:** `@juice-logging-upgrade`, `@juice-debug-logging`
**Does NOT add logging from scratch** — use `/add-logging` for new/uninstrumented files.

---

## What This Fixes

Previous instrumentation passes added logging mechanically: one `log_capture` at start,
one `log_delta` in `_apply_effect()`. These are syntactically compliant but semantically
thin — intermediate computation stages are invisible, config payloads are incomplete subsets,
and silent bail-outs have no warning.

This workflow replaces each insufficient logging point with one that makes the entire
computation chain observable.

---

## Step 0: Prerequisites (Once Per Session)

0a. **Read the upgrade skill:**
```
Read: @juice-logging-upgrade SKILL.md
```
This contains the Contract/Chain/Coverage protocol and the per-family coverage reference.
Do not skip — it is the design framework for every decision in this workflow.

0b. **Check JuiceLogger API** if needed:
```
Read: @juice-debug-logging TEMPLATES.md
```

---

## Step 1: Select a Family Batch

Process one effect family per batch — all 3 domains simultaneously.
Never mix families in one batch.

| Batch | Files | Complexity |
|-------|-------|------------|
| **Transform** | `JuiceControlTransformEffect` + `TransformControlJuiceEffect`, `Juice2DTransformEffect` + `Transform2DJuiceEffect`, `Juice3DTransformEffect` + `Transform3DJuiceEffect` | Complex (6 files) |
| **Shake** | `ShakeControlJuiceEffect`, `Shake2DJuiceEffect`, `Shake3DJuiceEffect` | Simple (3 files) |
| **Noise** | `NoiseControlJuiceEffect`, `Noise2DJuiceEffect`, `Noise3DJuiceEffect` | Simple (3 files) |
| **Appearance** | `AppearanceControlJuiceEffect`, `Appearance2DJuiceEffect`, `Appearance3DJuiceEffect` | Complex (3 files + shader paths) |
| **Progress + SquashStretch** | `Progress*` (3) + `SquashStretch*` (3) | Simple (6 files) |
| **Property Meta** | `InterpolatePropertyJuiceEffectBase`, `NoisePropertyJuiceEffectBase`, `ShakePropertyJuiceEffectBase`, `ProgressPropertyJuiceEffectBase` | Simple (4 files) |
| **Domain Nodes** | `JuiceControl`, `Juice2D`, `Juice3D` | Complex (3 files) |
| **Base Classes** | `JuiceBase`, `JuiceEffectBase` | Complex (2 files) |

**Recommended priority order (highest diagnostic value first):**
1. Transform — highest complexity, most user-facing
2. Shake + Noise — most used, oscillation chain often partially logged
3. Appearance — shader bugs are hardest to trace without chain coverage
4. Progress + SquashStretch
5. Property Meta
6. Domain Nodes + Base Classes

---

## Step 2: Execute the Contract/Chain/Coverage Protocol

For **each file** in the batch, write the following before opening the file to edit:

```
CONTRACT: [one sentence — what it computes, what goes in, what comes out]

CHAIN:
  [input_stage(key_vars)]
    → [stage_name(key_vars)]
    → [stage_name(key_vars)]
    → [output_channel]

COVERAGE AUDIT:
  Config at start:     FULL / PARTIAL / MISSING  → [action]
  [stage_name]:        LOGGED / NO              → [action]
  [stage_name]:        LOGGED / NO              → [action]
  Output delta:        LOGGED / NO              → [action]
  Silent returns:      COVERED / UNCOVERED      → [action]
```

**This is not a formality.** Writing the chain before reading the existing code forces you
to define what "correct" looks like independently of what was implemented. Gaps become
obvious when you compare the chain against the existing log calls.

---

## Step 3: Identify All Gaps

Consolidate the coverage audits from Step 2 into a concrete fix list:

```
FIXES FOR [family] BATCH:
- [File]: log_capture at start missing: [list of fields]
- [File]: oscillation intermediate not logged → add log_delta before _convert_to_pixels
- [File]: warn missing on null target cast in _apply_effect
- [File]: per-frame log only logs delta, not desired_absolute → add desired_absolute to payload
```

Do not start editing until this list is complete for all files in the batch.

---

## Step 4: Apply the Upgrades

Work through the fix list file by file:

4a. Expand `log_capture` payloads — every field that feeds the computation chain.
4b. Add intermediate `log_delta` at stages that were invisible.
4c. Add `warn()` on **unexpected** silent early returns only — returns that are normal
    animation behavior (e.g. fade-out reaching intensity=0.0) must NOT warn. Only warn
    when the skip represents a configuration error or an impossible state.
4d. Remove any per-frame log that only echoes static config (noise without signal).
4e. Ensure `desired_absolute` is logged alongside `delta` for interpolation effects
    (if one is correct but the other is wrong, it pinpoints whether the bug is in
    the interpolation or in the base-value capture).
4f. Log `_restore_to_natural` — this is the #1 undiagnosable marketplace bug class.
    Every effect must log what it cleared/restored and to what value.

Refer to `@juice-debug-logging TEMPLATES.md` for `JuiceLogger` call syntax.

---

## Step 5a: Evidence Collection (MANDATORY — cannot be skipped)

**This step operationalizes the Completeness Test. Without it, Step 5b is self-certification
from code reading and is invalid.**

The test suite already exercises every effect family across all 3 domains with
`juice/debug/enabled = true` and `log_to_file = true`. Use it directly — no custom
verify scenes are needed or permitted.

**1. Clear the log file first (prevents last session's data polluting evidence):**
```powershell
Remove-Item "C:\Users\nikol\AppData\Roaming\Godot\app_userdata\Juice Demo\juice_debug.log" -ErrorAction SilentlyContinue
```

**2. Run only the batch-relevant suites using the `--suite` filter:**

| Batch | Filter command |
|-------|---------------|
| Shake | `cmd /c "D:\Godot_projekti\juice-demo\tests\run_tests.bat" -- --suite=shake` |
| Noise | `cmd /c "D:\Godot_projekti\juice-demo\tests\run_tests.bat" -- --suite=noise` |
| Transform | `cmd /c "D:\Godot_projekti\juice-demo\tests\run_tests.bat" -- --suite=transform` |
| Appearance | `cmd /c "D:\Godot_projekti\juice-demo\tests\run_tests.bat" -- --suite=appearance` |
| Squash+Progress | `cmd /c "D:\Godot_projekti\juice-demo\tests\run_tests.bat" -- --suite=squash` and `--suite=progress` |
| Property Meta | `cmd /c "D:\Godot_projekti\juice-demo\tests\run_tests.bat" -- --suite=property` |

The `--suite` filter uses partial string matching — `shake` matches `shake_control`,
`shake_2d`, and `shake_3d` in one run.

**3. After the run, read the log file:**
```powershell
Get-Content "C:\Users\nikol\AppData\Roaming\Godot\app_userdata\Juice Demo\juice_debug.log" | Select-String "\[Shake\]"
```
Replace `\[Shake\]` with the family tag for the current batch (e.g. `\[Noise\]`, `\[Transform\]`).

**4. Paste the relevant lines here** — the lifecycle `log_capture` line(s) and at least
3 consecutive per-frame `log_delta` lines from each domain (Control, 2D, 3D).

Do not proceed to Step 5b without quoted log lines covering all 3 domains.

---

## Step 5b: Apply the Completeness Test

Answer these three questions **by quoting specific lines from the log output obtained
in Step 5a**. Each answer must cite the log line(s) it is based on.
Answering from code reasoning is not permitted.

> **1. Wrong output:** If the effect produced an unexpected value, can you identify the
>    exact chain stage where actual diverged from expected?
>    → Quote the log_delta line(s) showing the intermediate where divergence would appear.
>
> **2. No output:** If the effect produced nothing (zero delta, no change), can you
>    determine which early return or zero-condition fired?
>    → Quote the warn() or the log_capture line that would show the bail-out.
>
> **3. Reconstruction:** Can you reconstruct the full computation — all inputs, all
>    intermediate values, the final result — from the lifecycle log + 10 consecutive
>    per-frame lines?
>    → Quote both the log_capture line and 3+ consecutive log_delta lines as evidence.

If any answer requires reasoning about what the code *would* produce rather than quoting
actual output, that stage is not logged. Return to Step 4.

---

## Step 6: Run Tests

// turbo
```powershell
cmd /c "D:\Godot_projekti\juice-demo\tests\run_tests.bat"
```

If failures: fix before committing. Do NOT move to the next batch with failing tests.

---

## Step 7: Commit

```powershell
cd "D:\Godot_projekti\juice-demo"; git add -A; git commit -m "logging: upgrade [family] chain coverage — positivist standard"
```

Report batch completion:

```markdown
## Upgrade Complete — [Family Batch]

**Files upgraded:** [list]
**Contracts stated:** [yes — one per file]
**Gaps fixed:**
  - [File]: [what was missing → what was added]
  - [File]: [what was missing → what was added]
**Evidence collected:** [quoted log_capture line] + [N per-frame lines from Step 5a]
**Completeness Test:** PASS — each answer cites a quoted log line
**Tests:** X passed, 0 failed
**Next batch:** [name from Step 1 priority order]
```

---

## Step 8: Next Batch

Return to Step 1. Continue until all families pass the Completeness Test.
