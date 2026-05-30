---
description: "Documentation sweep workflow for Juice scripts. Invoke per batch of files to ensure marketplace-grade inline documentation with AI context preservation."
---

You are in DOCUMENTATION SWEEP MODE.

**Required skill:** `@doc-sweep` — Read [SKILL.md](../skills/doc-sweep/SKILL.md) before starting.

---

## MANDATORY: Pre-Batch Context Reset

Before touching ANY file in this batch, you MUST:

1. **Read the quality standard card:** Open and read `@doc-sweep` → [REFERENCES/quality-standard.md](../skills/doc-sweep/REFERENCES/quality-standard.md)
2. **Read the per-file checklist:** Open and read `@doc-sweep` → [REFERENCES/per-file-checklist.md](../skills/doc-sweep/REFERENCES/per-file-checklist.md)
3. **Read the examples:** Open and read `@doc-sweep` → [EXAMPLES/good-vs-bad.md](../skills/doc-sweep/EXAMPLES/good-vs-bad.md)
4. **Load the tracker:** Read `Documentation/doc_sweep_tracker.md` to know what's done and what's next.

If you skip any of these steps, you WILL drift into filler comments. This is not optional.

---

## Step 1: Identify the Batch

The user will specify which files to work on, OR you select the next `STRUCTURAL` or `TODO` files from the tracker.

**Batch size:** Maximum 3 files per invocation.

Why 3, not 5? Method comprehension requires genuine engagement with each file's architecture. 3 files done well beats 5 files done mechanically. If a file is particularly complex (>40 methods), it counts as 2.

**Never** start a file you can't finish in this session. If unsure, do fewer files.

---

## Step 2: Work File-By-File

For each file in the batch:

### 2a. Read the Entire File AND Its Base Class
Open and read the full file. If it extends a base class with virtual hooks, also read the base class to understand the call chain. You must understand:
- What calls this class's methods
- What data flows through them
- How they connect to the broader animation lifecycle

### 2b. Pass the Comprehension Gate (Phase B0)
Before writing any method comments, write a brief comprehension statement for your batch report:
- What base class does this extend?
- What virtual hooks does it implement?
- When are this file's key methods called?

### 2c. Apply the Decision Tree + Triage Table (Phase B1)
For each method, apply the `@doc-sweep` decision tree:
- Self-documenting? → SKIP
- Boilerplate? → SKIP
- Public API? → `##` comment required
- Virtual hook implementation? → `#` or `##` required (WHEN called + WHAT it does here)
- Architecturally significant private method? → `#` comment required
- Trivial helper? → SKIP or one-liner max

Record your triage decisions in a table for the batch report. This is how we verify every method was consciously considered.

### 2d. Write Comments (Phase B2-B3)
Write the comments for methods marked DOCUMENT.

### 2e. Check Structural Items (Phase A — if not already STRUCTURAL)
- Class tooltip: first line must be `## Action-oriented sentence.`
- Export tooltips: every `@export var` must have `##`
- History: sanitize V0/migration/phase references
- TODO triage: check for stale/valid TODOs

### 2f. Edit Using Editor Tools ONLY
**NEVER** use PowerShell/bash to write `.gd` files.
Use `replace_file_content` or `multi_replace_file_content` exclusively.
This ensures the user's editor stays in sync.

### 2g. Validate
Run `@doc-sweep` → [VALIDATION/post-edit-check.md](../skills/doc-sweep/VALIDATION/post-edit-check.md) checks.

---

## Step 3: Update Tracker

After each file is complete, update `Documentation/doc_sweep_tracker.md`:
- Change status to `DONE` (both phases complete)
- Add a brief note summarizing what was done
- Include the count of methods triaged and methods documented

---

## Step 4: Batch Summary

After completing all files in the batch, present:

1. **Comprehension statements** — your B0 answers for each file (proves understanding)
2. **Triage tables** — your B1 method decisions for each file (proves every method was considered)
3. **Files completed** — list with one-line summary each
4. **Judgment calls** — any methods you deliberately SKIPPED and why
5. **Remaining work** — how many files left in tracker

Then STOP and wait for user review before starting the next batch.

---

## Anti-Drift Rules

- **Do NOT write comments for methods you haven't traced through the call chain**
- **Do NOT invent comment prefixes** (RATIONALE:, PURPOSE:, NOTE:, etc.)
- **Do NOT add comments that just restate the function name**
- **Do NOT batch-spray identical comment patterns across methods**
- **Do NOT use PowerShell to write .gd files** (causes editor desync)
- **Do NOT modify existing good comments** — if it works, leave it alone
- **Do NOT mark a file DONE if you only did Phase A (structural)**
- **Do NOT continue to the next batch without user approval**

---

## Tracker Format

The tracker file (`Documentation/doc_sweep_tracker.md`) uses this format:

```markdown
| File | Phase A | Phase B | Status | Notes |
|------|---------|---------|--------|-------|
| `Base Classes/JuiceBase.gd` | ✅ | ✅ | DONE | 45/73 methods documented, 28 deliberately skipped (boilerplate/trivial) |
| `Control/TransformControlJuiceEffect.gd` | ✅ | ❌ | STRUCTURAL | Headers/exports clean. 35 methods need triage. |
```

Statuses: `TODO`, `STRUCTURAL`, `IN PROGRESS`, `DONE`, `SKIP`, `BLOCKED`
