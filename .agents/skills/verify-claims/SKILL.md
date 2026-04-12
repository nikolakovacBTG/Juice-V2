---
name: verify-claims
description: Prevents false self-evaluation. Auto-invoke when about to declare something done, fixed, working, complete, verified, or passing. Demands test evidence before any completion claim.
---

# Verify Claims Skill

**HARD STOP: You cannot say any of the following without evidence:**

- "done"
- "fixed"
- "working"
- "complete"
- "verified"
- "all tests pass"
- "no regressions"

## Required Evidence

For ANY completion claim, you MUST provide ONE of:

### Option A: Cite a passing test
```
Verified by: test_suite_name::test_method_name — PASS
(from test run at [timestamp or "just now"])
```

### Option B: Run the test suite NOW
// turbo
```powershell
& "[GODOT_EXE]" --headless --path "[PROJECT_ROOT]" [TEST_SCENE]
```

Then read `tests/results/summary.log` and cite specific results.

### Option C: Explicitly state no test exists
```
NO TEST EXISTS for this feature. Before marking complete:
1. Write a test (use @juice-architecture test template)
2. Run it
3. Then claim completion with Option A
```

## What This Prevents

| Bad Pattern | What You'd Say | What You Should Say |
|---|---|---|
| False confidence | "This should work now" | "I changed X. Running tests to verify..." |
| Self-evaluation | "The logic looks correct" | "Logic changed. Test result: [PASS/FAIL]" |
| Assumption | "This fix covers all domains" | "Verified Control: PASS. Verified 2D: PASS. Verified 3D: PASS." |
| Premature closure | "Bug fixed, moving on" | "Bug fixed. Test `suite::method` now passes. No regressions in full suite." |

## Extensibility Check

When claiming a **fix** is complete, also verify:

- [ ] **Does the fix cover future cases?** Not just the reported symptom. If a new effect type or property channel were added tomorrow, would it automatically benefit from this fix?
- [ ] **Is the fix generic or hardcoded?** If it enumerates specific properties (position, rotation, scale) instead of using a protocol (e.g., `_get_seq_contribution()`), it's a band-aid — flag it.
- [ ] **Did you present the architectural choice to the user?** If you recognized a narrow vs generic approach and silently picked the narrow one, that's a process failure.

If any of these fail: the fix is NOT complete. Redesign before claiming done.

## The Rule

**Tests verify. Reviews suggest. Only test results can mark something ✅.**
