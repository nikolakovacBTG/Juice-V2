---
description: Re-audit existing Juice V1 debug logging and upgrade to full chain coverage. Enforces the Contract/Chain/Coverage protocol per effect family. Use this workflow when logging already exists but quality is insufficient.
---

You are in UPGRADE-LOGGING MODE.

This workflow re-audits and upgrades *existing* logging in instrumented Juice V1 files.
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
4c. Add `warn()` on every silent early return that skips effect work.
4d. Remove any per-frame log that only echoes static config (noise without signal).
4e. Ensure `desired_absolute` is logged alongside `delta` for interpolation effects
    (if one is correct but the other is wrong, it pinpoints whether the bug is in
    the interpolation or in the base-value capture).

Refer to `@juice-debug-logging TEMPLATES.md` for `JuiceLogger` call syntax.

---

## Step 5: Apply the Completeness Test

Before marking the batch done, answer these three questions from the log output alone —
**no source code allowed:**

> **1. Wrong output:** If the effect produced an unexpected value, can you identify the
>    exact chain stage where actual diverged from expected?
>
> **2. No output:** If the effect produced nothing, can you determine which early return
>    or zero-condition fired?
>
> **3. Reconstruction:** Can you reconstruct the full computation — all inputs, all
>    intermediate values, the final result — from the lifecycle log + 10 consecutive
>    per-frame lines?

If any answer is **NO**, a stage is still missing. Return to Step 4.

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
**Completeness Test:** PASS (all 3 questions YES)
**Tests:** X passed, 0 failed
**Next batch:** [name from Step 1 priority order]
```

---

## Step 8: Next Batch

Return to Step 1. Continue until all families pass the Completeness Test.
