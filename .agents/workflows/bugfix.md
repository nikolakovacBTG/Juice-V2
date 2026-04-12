---
description: Structured bugfix cycle after test failures — prevents AI drift, pinhole fixes, and silent architecture changes
---

You are in BUGFIX MODE.

**Skills auto-invoked:** `@juice-architecture` (architecture rules), `@verify-claims` (no false "done")

This workflow is triggered AFTER `/test` has been run and failures have been categorized.
It defines a structured, repeatable cycle for investigating and fixing bugs found by the
automated test suite. It is specifically designed to prevent common AI failure modes.

---

## Anti-Patterns This Workflow Prevents

| Anti-Pattern | Description | Prevention |
|-------------|-------------|------------|
| **Pinhole vision** | Fixing the exact symptom without checking if it affects other domains/properties | Cross-domain sweep (Step 3) |
| **AI drift** | Silently changing architecture or renaming things while "fixing" | Design checkpoint (Step 4) |
| **Whack-a-mole** | Fix one bug, create another, fix that, repeat | Batch analysis + full re-test (Steps 2, 7) |
| **Test-chasing** | Modifying tests to pass instead of fixing the real bug | Classification gate from /test (input) |
| **Scope creep** | Discovering 5 more things to "improve" while fixing 1 bug | Strict scope lock (Step 1) |

---

## Inputs

Before starting, you MUST have:

1. **`/test` report** with categorized failures (TEST BUG / REAL BUG / NEEDS DISCUSSION)
2. Only **REAL BUG** items enter this workflow. TEST BUGs are fixed in /test. NEEDS DISCUSSION items are paused for user input.

---

## Step 1: Scope Lock

List ONLY the failures entering this cycle. Do not add discovered issues mid-cycle.

```
## Bugfix Scope — [date]
Failures from /test:
1. suite::test_name — one-line summary
2. suite::test_name — one-line summary
...

SCOPE LOCK: Only these items will be investigated and fixed in this cycle.
If new issues are discovered, they are DOCUMENTED and DEFERRED to the next cycle.
```

If you discover something new during investigation, add it to a "Discovered Issues" list
but do NOT fix it in this cycle unless the user explicitly approves scope expansion.

---

## Step 2: Batch Root-Cause Analysis

Analyze ALL scoped failures TOGETHER before touching any code.

For each failure:

### 2a. Read the evidence
- Read the full test log line
- Read the test code to understand what it expects
- Read the production code path that the test exercises

### 2b. Form hypotheses
- What is the most likely cause?
- Is this a NEW bug or an INCOMPLETE FEATURE that was never implemented?
- Could this be a timing/environment issue rather than a logic bug?

### 2c. Check for shared root causes
- Do multiple failures share a code path? (e.g., both loop tests failing = one root cause)
- Group failures by likely root cause
- A single root cause should get a single fix, not per-symptom patches

### 2d. Present analysis to user BEFORE any code changes

```
## Root-Cause Analysis

### Group A: [description]
Affected tests: test_x, test_y
Likely root cause: [explanation]
Confidence: HIGH / MEDIUM / LOW
Files involved: [list]

### Group B: [description]
...
```

---

## Step 3: Cross-Domain Sweep

For EACH root cause identified, check if it affects other domains or properties.

**Mandatory checklist:**

- [ ] Does this code path exist in JuiceControl? Affected?
- [ ] Does this code path exist in Juice2D? Affected?
- [ ] Does this code path exist in Juice3D? Affected?
- [ ] Does this affect POSITION? ROTATION? SCALE?
- [ ] Does this affect PLAY_IN_ONLY? PLAY_OUT_ONLY? PLAY_IN_AND_OUT? TOGGLE?
- [ ] Does this interact with start_delay? loop_count? retrigger?
- [ ] Is there a V0 equivalent that works correctly? What changed?

If the bug exists in one domain, check ALL domains. Incomplete coverage is itself a bug.

---

## Step 4: Design Checkpoint (MANDATORY)

Re-read the relevant section of `Documentation/JuiceStack_Design.md` (invoked via `@juice-architecture`).

Before writing ANY fix, classify the root cause:

| Classification | Meaning | Action |
|---------------|---------|--------|
| **Clear bug** | Code doesn't match documented design intent | Fix it (proceed to Step 5) |
| **Missing implementation** | Feature was designed but never coded | Implement it (proceed to Step 5) |
| **Design ambiguity** | Design doc doesn't specify this interaction | STOP — present to user for design decision |
| **Architecture question** | Fix would change how systems interact | STOP — present to user for design decision |

**For "Design ambiguity" or "Architecture question":**

Present the options to the user:

```
## Design Decision Needed — [topic]

The test expects [behavior], but the code does [other behavior].
The design doc says: [quote or "silent on this"].

Option A: [describe] — implies [consequence]
Option B: [describe] — implies [consequence]

Which matches your intent?
```

Do NOT pick an option yourself. Do NOT implement a "reasonable default."

---

## Step 5: Design Fix (All Groups Together)

For each root-cause group, design the fix:

```
## Proposed Fix — Group [X]

**Root cause:** [one sentence]
**Fix:** [description of code change]
**Files changed:** [list with specific functions]
**Lines of change:** ~N (estimate)
**Risk:** LOW / MEDIUM / HIGH
**Side effects:** [list, or "none expected"]
**Regression risk:** [what existing passing tests could break]
```

### 5b. Architectural Quality Gate (MANDATORY)

Before presenting the fix, answer these questions:

- [ ] **Generic vs hardcoded?** Does this fix hardcode specific channels/properties/types, or does it use a generic protocol that extends to future cases? If hardcoded, redesign.
- [ ] **Per-domain duplication?** Does this fix require copy-pasting logic into JuiceControl, Juice2D, AND Juice3D? If yes, the logic likely belongs in JuiceBase or in a shared protocol method on effect bases.
- [ ] **Future effect types?** Would a new effect type (e.g., Appearance, Audio) automatically benefit from this fix, or would it require modifying the fix? If the latter, the fix is a band-aid.
- [ ] **Protocol boundary?** Does this fix touch how effects report data to nodes? If yes, it MUST use a generic protocol (e.g., `_get_seq_contribution()` returning a Dictionary keyed by property names), not hardcoded field reads.

If ANY answer reveals a band-aid approach: **STOP and present the generic alternative to the user.** Never default to the quick narrow fix at a protocol boundary.

Present ALL fixes together. Wait for user approval before implementing.

---

## Step 6: Implement (Minimal, Upstream)

Rules for implementation:

1. **Minimal** — fewest lines possible. No "while I'm here" improvements.
2. **Upstream** — fix the root cause, not the symptom. No downstream workarounds.
3. **Match existing style** — zero creative drift. Same naming, same patterns.
4. **No new comments unless necessary** — don't add explanatory comments that restate the code.
5. **One commit per root-cause group** — atomic, revertable.

After implementing, do NOT test yourself. Proceed to Step 7 for automated verification.

---

## Step 7: Verification (`@verify-claims` enforced)

// turbo
```powershell
& "[GODOT_EXE]" --headless --path "[PROJECT_ROOT]" [TEST_SCENE]
```

// turbo
```powershell
Get-Content "[LOG_SUMMARY]"
```

**Success criteria:**
- ALL previously passing tests still pass (no regressions)
- ALL scoped failures now pass
- No new failures introduced

**If regressions appear:**
- Do NOT patch the regression. STOP.
- The fix was wrong or incomplete. Go back to Step 2 with the NEW evidence.
- This is a signal that the root cause was misidentified.

---

## Step 4: Port the Fix (Regression Testing)

1. Apply the fix to ALL 3 domains (even if logic slightly differs).
2. Run full suite again:
// turbo
```powershell
& "[TEST_BAT]"
```

---

## Step 5: Commit

// turbo
```powershell
cd "[PROJECT_ROOT]"; git add -A; git commit -m "Fix: [describe root cause groups fixed]"
```

1. Update TODO.md and `Documentation/V0_V1_Feature_Parity_Matrix.md` if any matrix items changed status
2. If "Discovered Issues" were logged in Step 1, present them to the user for the next cycle
3. Report final results:

```
## Bugfix Cycle Complete — [date]

**Fixed:** N failures across M root-cause groups
**Regressions:** 0
**Discovered issues (deferred):** [list or "none"]
**Total suite status:** X passed, 0 failed
```

---

## The Full Cycle (Summary)

```
/test → categorize failures
  ↓
/bugfix Step 1 → scope lock
  ↓
Step 2 → batch root-cause analysis (present to user)
  ↓
Step 3 → cross-domain sweep
  ↓
Step 4 → design checkpoint (STOP if ambiguous)
  ↓
Step 5 → design fix (present to user)
  ↓
Step 6 → implement (minimal, upstream)
  ↓
Step 7 → /test re-run (full suite)
  ↓
  ├── regressions? → back to Step 2
  └── all pass? → Step 8 → close
```
