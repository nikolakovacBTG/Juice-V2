---
description: "Documentation sweep workflow for Juice V1 scripts. Invoke per batch of files to ensure marketplace-grade inline documentation with AI context preservation."
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

The user will specify which files to work on, OR you select the next `TODO` files from the tracker.

**Batch size:** Maximum 5 files per invocation.

**Never** start a file you can't finish in this session. If unsure, do fewer files.

---

## Step 2: Work File-By-File

For each file in the batch:

### 2a. Read the Entire File
Open and read the full file. Understand its role in the architecture before writing a single comment.

### 2b. Apply the Decision Tree
For each method, apply the `@doc-sweep` decision tree:
- Self-documenting? → SKIP
- Boilerplate? → SKIP
- Public API? → `##` comment required
- Architecturally significant private method? → `#` comment required
- Trivial helper? → SKIP or one-liner max

### 2c. Check Exports
Every `@export var` must have a `##` tooltip above it.

### 2d. Check Class Tooltip
First line of file must be `## Action-oriented sentence.`

### 2e. Sanitize History
Search for V0, V1, migration, ported, refactor references.
- Translate useful ones to pure rationale
- Delete empty ones

### 2f. Edit Using Editor Tools ONLY
**NEVER** use PowerShell/bash to write `.gd` files.
Use `replace_file_content` or `multi_replace_file_content` exclusively.
This ensures the user's editor stays in sync.

### 2g. Validate
Run `@doc-sweep` → [VALIDATION/post-edit-check.md](../skills/doc-sweep/VALIDATION/post-edit-check.md) checks.

---

## Step 3: Update Tracker

After each file is complete, update `Documentation/doc_sweep_tracker.md`:
- Change status from `TODO` to `DONE`
- Add a brief note of what was done (e.g., "3 method comments, 2 export tooltips, 1 history cleanup")

---

## Step 4: Batch Summary

After completing all files in the batch, present:

1. **Files completed** — list with one-line summary each
2. **Judgment calls** — any methods you deliberately SKIPPED and why
3. **Remaining work** — how many files left in tracker

Then STOP and wait for user review before starting the next batch.

---

## Anti-Drift Rules

- **Do NOT invent comment prefixes** (RATIONALE:, PURPOSE:, NOTE:, etc.)
- **Do NOT add comments that just restate the function name**
- **Do NOT batch-spray identical comment patterns across methods**
- **Do NOT use PowerShell to write .gd files** (causes editor desync)
- **Do NOT modify existing good comments** — if it works, leave it alone
- **Do NOT continue to the next batch without user approval**

---

## Tracker Format

The tracker file (`Documentation/doc_sweep_tracker.md`) uses this format:

```markdown
| File | Status | Notes |
|------|--------|-------|
| `Base Classes/JuiceBase.gd` | DONE | 6 methods, 2 exports, 1 history |
| `Control/TransformControlJuiceEffect.gd` | TODO | — |
```

Statuses: `TODO`, `IN PROGRESS`, `DONE`, `SKIP` (file has no methods or is auto-generated)
