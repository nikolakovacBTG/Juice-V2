# Documentation Quality Standard

Re-read this card before working on EVERY file. No exceptions.

## The 6 Rules

1. **No history.** Never reference V0, V1, migration, porting, refactoring, or previous versions. The code presents as if this version has always existed.

2. **No filler prefixes.** Never write `RATIONALE:`, `PURPOSE:`, `NOTE:`, or any prefix that creates "explanation: explanation" redundancy. Just write the explanation naturally.

3. **Comments explain WHY, not WHAT.** If the comment just restates the function name as a sentence, delete it. A comment must tell the reader something they can't already see from the code.

4. **Preserve existing good comments.** If a comment already explains something well, leave it alone. Don't rewrite working comments to "improve" them — that's how information gets destroyed.

5. **Less is more.** A file with 5 excellent comments is better than one with 30 mediocre ones. Self-documenting code needs no comment. Complex architectural decisions need thorough ones.

6. **No development phase labels.** Never prefix comments with `Phase A:`, `Phase B:`, `Sprint N:`, `TODO(phase-N):`, `SEQUENCER Phase N`, or any internal milestone/sprint naming. These are internal development artifacts that mean nothing to a marketplace buyer. Strip the prefix and keep any useful content after it.
   - **Exception:** Sequential algorithm step labels inside a single coroutine method (`# Step 1: Cover`, `# Step 2: Execute`) are fine — they describe the *algorithm*, not the *development timeline*.

## Comment Syntax Rules (from AGENTS.md)

| Where | Syntax | Visible In |
|-------|--------|------------|
| Class tooltip (first line) | `## Action-oriented sentence.` | Create New Node menu + tooltips |
| Class details | `##` (blank) then `## Paragraph` | Script docs viewer only |
| Above `@export` | `## Tooltip text` | Inspector hover |
| Above public `func` | `## What + when + side effects` | Script docs (F1) |
| Above virtual `func _override` | `## Subclass API contract` | Script docs (F1) |
| Above private `func _helper` | `# What problem this solves` | Source code only |
| Inline dev notes | `# Single hash` | Source code only |

**Virtual override points** (use `##`): `_apply_effect`, `_on_animate_start`, `_needs_sustain`,
`_restore_to_natural`, `_on_animate_in_complete`, `_on_animate_out_complete`, `tick` (public override).
**Internal helpers** (use `#`): everything else prefixed with `_`.

## What MUST Be Documented

- **Public API methods** — anything a marketplace user would call from their own code
- **Methods with side effects** — writes to scene tree, modifies engine state, has ordering dependencies
- **Non-obvious architectural decisions** — why this approach instead of the obvious one
- **Complex branching logic** — anything >10 lines with non-trivial control flow
- **Class-level `##` tooltip** — every `class_name` must have one for the Create New Node menu

## What to SKIP

- `_init()` that just sets a flag
- `_get_property_list()` / `_set()` / `_get()` — Godot boilerplate whose structure IS its documentation
- Trivial one-liner overrides where the base class comment already explains the contract
- `_get_target_resource_type()` returning a string literal
- Any method whose name + signature + 1-2 line body is completely self-describing

## The Adversarial Test

Before writing a comment, ask: *"Would an adversarial code reviewer flag this comment as useless filler?"* If yes, don't write it. A missing comment is neutral. A bad comment is negative.

## Translation Rule (Historical Comments)

When you encounter a comment referencing V0, V1, migration, porting, refactoring, **or development phases/sprints**:
1. Read it carefully — it may contain useful architectural insight
2. Extract the TECHNICAL RATIONALE (the "why" behind the decision)
3. Rewrite it as pure structural reasoning without any historical or phase reference
4. If the comment has NO useful information beyond history, delete it

**Before:** `# Mirrors V0's direct-apply pattern: initialises effects on first call`
**After:** `## Bypasses the standard animation loop to allow external systems to drive the effect. Initialises effects on first call, then writes deltas directly each call.`

**Before:** `# Phase B: Sibling stacking with metadata-based natural base capture`
**After:** `# Sibling stacking with metadata-based natural base capture`

**Before:** `# TODO(phase-4): Absorb META_KEY into JuiceLedger`
**After:** Resolve the work item, then delete the comment entirely. No `TODO` comments in shipping code.

## No TODO / FIXME / HACK in Shipping Code

`TODO`, `FIXME`, and `HACK` comments signal "this isn't finished" to marketplace buyers. They belong in issue trackers, not source files.

- Before deleting a TODO, verify whether the work was already done (stale) or is still needed
- If still needed, track it externally and delete the comment
- If stale, just delete it
- Never blindly nuke TODOs without checking — they may flag real incomplete features
