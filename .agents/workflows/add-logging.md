---
description: Batch-oriented workflow for adding debug logging to Juice V1 scripts. Invokes @juice-debug-logging skill.
---

You are in ADD-LOGGING MODE.

This workflow adds structured debug logging to Juice V1 scripts in controlled batches.
It enforces batch discipline, skill-guided patterns, and test verification.

**Skills auto-invoked:** `@juice-debug-logging`
**Required rule:** `add-logging-rule.md`

---

## Anti-Patterns This Workflow Prevents

| To Prevent: | You MUST: |
|---|---|
| **Context overflow** | Process 3 files/batch (complex) or 5 files/batch (simple). Never mix domains. |
| **Inconsistent format** | Read `@juice-debug-logging` TEMPLATES.md before every batch. Use JuiceLogger exclusively. |
| **Raw print leftovers** | Audit existing prints: keep useful ones (convert), remove dev leftovers. |
| **Missing guards** | Every log goes through JuiceLogger which handles OS.is_debug_build() + master switch + debug_enabled. |
| **Untested changes** | Run `/test` after each batch. |
| **Drift from spec** | Re-read LOG_POINTS.md at the start of each batch to confirm insertion points. |

---

## Step 0: Prerequisites (Once Per Session)

0a. **Read the skill:**
```
Read: @juice-debug-logging SKILL.md
```

0b. **Read the rule:**
```
Read: .agents/rules/add-logging-rule.md
```

0c. **Confirm JuiceLogger exists.** If not, it must be created first (Phase 2 of the plan).

---

## Step 1: Select Batch

1a. Open [CHECKLIST.md](.agents/skills/juice-debug-logging/CHECKLIST.md) and find the next unchecked batch.

1b. Confirm batch size:
- **Complex files** (base classes, domain nodes, Appearance, Transform): **3 files max**
- **Simple files** (concrete effects, Meta stubs, utilities): **5 files max**
- **Never mix domains** in one batch (all Control, or all 2D, or all 3D)

1c. Mark selected files as `[/]` (in progress).

---

## Step 2: Read Log Points

2a. Open `@juice-debug-logging` [LOG_POINTS.md](.agents/skills/juice-debug-logging/LOG_POINTS.md).

2b. Find the section matching your batch (Base Classes, Effects, Utilities, etc.).

2c. For each file in the batch, list the methods that need logging and their category.

---

## Step 2.5: Pre-Implementation Design (MANDATORY — Do Not Skip)

For **each file** in the batch, produce all three of the following **before opening the
file to edit**. They cannot be faked without reading the code — that is the point.

**0. Contract + Chain (write this first, before Artifacts 1 and 2):**
```
CONTRACT: [one sentence — what it computes, what goes in, what comes out]

CHAIN:
  [input_stage(key_vars)]
    → [stage_name(key_vars)]
    → [stage_name(key_vars)]
    → [output_channel]
```
For effect families, use the chain maps in `@juice-logging-upgrade SKILL.md §
Per-Family Chain Reference` as a starting point — then verify against the actual code.

**Artifact 1 — Config Variable Map:** List every `@export var` and config variable by
exact GDScript name. Assign each to a chain stage, ROUTING, SIDE_EFFECT, or UNUSED.
Every variable mapped to a computation stage must appear in `log_capture`.

**Artifact 2 — Expected Log Template:** Write what the actual log payload should contain
before writing any `log_capture` or `log_delta` call. Real key names, realistic values.
The implementation must match this template — it is the spec.

**LOG_POINTS.md (Step 2) tells you WHERE to log.
Contract+Chain tells you WHAT the chain IS.
Artifacts 1 and 2 tell you WHAT the payload must contain.**
All three are required. None replaces the others.

---

## Step 3: Audit Existing Prints (If Any)

For each `if debug_enabled: print(...)` found in the batch files:

3a. **Read the print** — what info does it convey?

3b. **Classify** — which of the 6 categories does it map to?

3c. **Evaluate** — would this help diagnose a bug reported by a marketplace user?
- **YES** → will be converted in Step 4
- **NO** → remove it (dev leftover)

3d. Document audit decisions before making changes.

---

## Step 4: Instrument

4a. Read `@juice-debug-logging` [TEMPLATES.md](.agents/skills/juice-debug-logging/TEMPLATES.md) for the matching category patterns.

4b. For each file in the batch:
1. Remove dev-leftover prints (from Step 3)
2. Convert keep-worthy prints to `JuiceLogger` calls
3. Add new logging calls at insertion points from LOG_POINTS.md
4. Ensure `_get_domain_tag()` is implemented (for effect classes)

4c. **Silent returns:** Add `warn()` only on **unexpected** silent returns — returns that
represent a configuration error or impossible state. Normal animation behavior
(e.g. fade-out reaching `intensity=0.0`, hold phase active) must **NOT** warn.
Silent bail-outs that represent bugs in user setup always get a `warn()`.

4d. **Intermediate stages:** Every chain stage from the Contract+Chain map that is
computed then discarded must appear in a `log_delta` before its result is used.
Do not log only input and output — the intermediate is where bugs live.

4e. **Interpolation effects:** Log `desired_absolute` AND `delta` together. If desired
is correct but delta is wrong, the bug is in base-value capture — without both
values you cannot distinguish the two failure modes.

4f. **`_restore_to_natural`:** Every effect must log what it cleared and the value
written back. Failure to reset is the #1 undiagnosable marketplace bug class.

4g. Follow `/code` workflow rules for all changes (header comments, inspector config, etc.)

---

## Step 5a: Evidence Collection (MANDATORY — cannot be skipped)

The Completeness Test in Step 5b requires real log output. Code reasoning is not permitted.

**1. Clear the log file first:**
```powershell
Remove-Item "C:\Users\nikol\AppData\Roaming\Godot\app_userdata\Juice Demo\juice_debug.log" -ErrorAction SilentlyContinue
```

**2. Run the test suite (all suites, or a family filter if the batch is a single family):**

// turbo
```powershell
cmd /c "D:\Godot_projekti\juice-demo\tests\run_tests.bat"
```
For single-family batches use `-- --suite=<family>` (e.g. `--suite=shake`).
The `--suite` filter uses partial matching — `shake` matches Control, 2D, and 3D in one run.

**3. Read the log and filter to the instrumented family:**
```powershell
Get-Content "C:\Users\nikol\AppData\Roaming\Godot\app_userdata\Juice Demo\juice_debug.log" | Select-String "\[FamilyTag\]"
```

**4. Paste the relevant lines** — the lifecycle `log_capture` and at least 3 consecutive
per-frame `log_delta` lines from each domain tested (Control, 2D, 3D where applicable).

Do not proceed to Step 5b without quoted log lines in hand.

---

## Step 5b: Completeness Test

Answer these three questions **by quoting specific lines from the log output obtained
in Step 5a**. Answering from code reasoning is self-certification and is invalid.

> **1. Wrong output:** Can you find where in the chain actual diverged from expected?
>    → Quote the `log_delta` line(s) that would expose the divergence.
>
> **2. No output:** Can you find which early return fired?
>    → Quote the `warn()` line, or the absence of `log_delta` lines as evidence.
>
> **3. Reconstruction:** Can you reconstruct the full computation from lifecycle log + 10 per-frame lines?
>    → Quote the `log_capture` line and at least 3 consecutive `log_delta` lines.

All three must be **YES** before the batch is marked done. If any requires reasoning
rather than quoting → a stage is missing. Return to Step 4.

---

## Step 5c: Fix Test Failures

If any test suite failures were found in Step 5a: fix before proceeding.
Do NOT move to the next batch with failing tests.

---

## Step 6: Mark Progress

6a. Update [CHECKLIST.md](.agents/skills/juice-debug-logging/CHECKLIST.md): mark completed files as `[x]`.

6b. Commit the batch:
```powershell
cd "D:\Godot_projekti\juice-demo"; git add -A; git commit -m "logging: instrument [batch name] with JuiceLogger"
```

6c. Report batch completion:
```markdown
## Batch Complete — [Batch Name]

**Files instrumented:** [list]
**Existing prints:** [N kept, M removed]
**New log points added:** [count]
**Test results:** X passed, 0 failed
**Next batch:** [name from CHECKLIST.md]
```

---

## Step 7: Repeat

Return to Step 1 for the next batch. Continue until CHECKLIST.md is fully checked.
