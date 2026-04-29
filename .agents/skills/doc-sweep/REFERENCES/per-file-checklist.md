# Per-File Documentation Checklist

Run through this for every `.gd` file in the sweep.

---

## Phase A: Structural Foundation (Quick — minutes per file)

These items are mechanical and fast. They ensure the file has the right scaffolding.

### A1. Class Tooltip (`##` at top of file)

- [ ] First line is a concise, action-oriented sentence (shows in Create New Node menu)
- [ ] Additional `##` paragraphs provide architectural context (shows in script docs only)
- [ ] No historical references (V0, V1, migration, ported)

### A2. Header WHY Block (`# ============` block)

- [ ] WHAT: one sentence saying what this class does
- [ ] WHY: one sentence saying why it exists as a separate class (not "because we need it")
- [ ] SYSTEM: which system it belongs to
- [ ] DOES NOT: what responsibilities are explicitly excluded
- [ ] No historical references

### A3. Export Tooltips

- [ ] Every `@export var` has a `##` comment above it (shows in Inspector hover)
- [ ] Tooltips describe what the value controls, not implementation details
- [ ] For `_get_property_list()` exports: tooltips are in the `hint_string` or in `##` above the backing `var`

### A4. History Sanitization

- [ ] Zero occurrences of: V0, V1, migration, ported, refactor (in comments)
- [ ] Zero occurrences of dev-phase prefixes: `Phase A/B/C:`, `Sprint N:`, `TODO(phase-N):`, `SEQUENCER Phase N`
- [ ] Historical comments with useful info translated to pure rationale
- [ ] Historical comments with no useful info deleted

### A5. TODO / FIXME / HACK Triage

- [ ] Search the file for `TODO`, `FIXME`, `HACK` (case-insensitive)
- [ ] Stale: Delete or replace with accurate comment
- [ ] Valid: Report as blocker, do NOT delete, do NOT implement during sweep

**Phase A alone does NOT make a file DONE.** It makes it STRUCTURALLY CLEAN.

---

## Phase B: Method Comprehension (Slow — this is where quality lives)

This phase requires genuine understanding of the code. It cannot be rushed.

### B0. Comprehension Gate (MANDATORY — before writing any method comment)

Before documenting methods, prove you understand the file by answering these questions. Write the answers in your batch report — this forces genuine engagement:

1. **What base class does this extend, and what virtual hooks does it implement?**
2. **When are this file's methods called?** (e.g., "called by JuiceControlTransformEffect._on_animate_start during animation startup")
3. **What data does this class own vs. inherit?** (e.g., "_base_position is typed here, but _has_base flag is in the domain base")

If you cannot answer these, READ THE BASE CLASS FIRST. Do not guess. Do not document methods you don't understand.

### B1. Method Triage (apply the decision tree to EVERY method)

For each `func` in the file, explicitly decide:

| Method | Decision | Reason |
|--------|----------|--------|
| `_do_capture_base` | DOCUMENT | Non-obvious: reads from ledger, not target; skip-guard prevents double capture |
| `_set` | SKIP | Godot boilerplate |
| `_resolve_from_position` | DOCUMENT | Resolver with 3 branches (CUSTOM/SELF/TARGET_NODE) — reader needs to know the resolution strategy |
| `_clear_from_editor_cache_typed` | SKIP | Obvious reset-to-defaults, 3 lines |

**Report this triage table in your batch summary.** This is how we verify that every method was consciously considered — not skipped by accident.

### B2. Write Method Comments

For methods marked DOCUMENT in the triage:

- [ ] Public API methods have `##` with: what it does, when to call it, notable side effects
- [ ] Virtual hook implementations have `#` or `##` explaining: **when called** (by which base class method), **what it does** specifically in this class, and any non-obvious behavior
- [ ] Private methods with architectural significance have `#` explaining what problem they solve
- [ ] No comment just restates the function name as a sentence
- [ ] No `RATIONALE:`, `PURPOSE:`, `NOTE:` prefixes

### B3. Inline Comments

- [ ] Complex branching logic has brief `#` explaining the branch condition's purpose
- [ ] Magic numbers have `#` explaining what they represent
- [ ] No stale/outdated inline comments referring to code that's changed
- [ ] Existing good inline comments preserved — DO NOT rewrite them

---

## What "DONE" Means

A file is DONE when:
1. ✅ Phase A is complete (structural foundation)
2. ✅ Phase B0 comprehension gate was passed (understanding proven)
3. ✅ Phase B1 method triage was explicitly performed (every method consciously triaged)
4. ✅ Phase B2-B3 comments were written for methods that need them
5. ✅ The adversarial test passes on every comment written

A file that passes Phase A but skips Phase B is **STRUCTURAL ONLY** — not DONE.

---

## Status Definitions

| Status | Meaning |
|--------|---------|
| `TODO` | Not yet reviewed |
| `STRUCTURAL` | Phase A complete. Headers, exports, history clean. Methods NOT triaged. |
| `IN PROGRESS` | Phase B started but not finished |
| `DONE` | Both phases complete. Methods triaged and documented where needed. |
| `SKIP` | No methods (domain registration stubs, auto-generated) |
| `BLOCKED` | Contains valid TODO that user must resolve first |
