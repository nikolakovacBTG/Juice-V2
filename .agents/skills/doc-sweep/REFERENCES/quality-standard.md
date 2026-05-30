# Documentation Quality Standard

Re-read this card before working on EVERY file. No exceptions.

## The Core Principle

**Understand first. Document second.**

A comment written without understanding the code it describes is worse than no comment at all. Before writing any method comment, you must be able to explain — in your own words — what architectural problem the method solves and when it is called. If you cannot, stop and trace the call chain until you can.

Mechanical documentation ("add a comment above every func") produces noise that actively misleads readers. The goal is a codebase where a developer, an AI agent, or an adversarial reviewer can read any file and understand:
1. What role this class plays in the system
2. How its methods connect to the broader architecture
3. Why non-obvious decisions were made

## The Comprehension Gate

Before writing comments on a file's methods, you MUST be able to answer:

1. **What calls this class's methods?** Trace the inheritance chain. If `_do_capture_base()` exists in a concrete effect, which base class method calls it and when?
2. **What data flows through?** What does this method read, what does it write, and what depends on that write?
3. **What would break if this method were removed?** This tells you its architectural significance.

If you cannot answer these for a method, you are not ready to document it. Read the base class. Read the caller. Understand the chain. Then write.

## The 6 Rules

1. **No history.** Never reference V0, migration, porting, refactoring, or previous versions. The code presents as if this version has always existed.

2. **No filler prefixes.** Never write `RATIONALE:`, `PURPOSE:`, `NOTE:`, or any prefix that creates "explanation: explanation" redundancy. Just write the explanation naturally.

3. **Comments explain WHY, not WHAT.** If the comment just restates the function name as a sentence, delete it. A comment must tell the reader something they can't already see from the code.

4. **Preserve existing good comments.** If a comment already explains something well, leave it alone. Don't rewrite working comments to "improve" them — that's how information gets destroyed.

5. **Less is more.** A file with 5 excellent comments is better than one with 30 mediocre ones. Self-documenting code needs no comment. Complex architectural decisions need thorough ones.

6. **No development phase labels.** Never prefix comments with `Phase A:`, `Phase B:`, `Sprint N:`, `TODO(phase-N):`, `SEQUENCER Phase N`, or any internal milestone/sprint naming. Strip the prefix and keep any useful content after it.
   - **Exception:** Sequential algorithm step labels inside a single method (`# Step 1: Cover`, `# Step 2: Execute`) describe the *algorithm*, not the *development timeline*.

## The Three Failures

These are the ways documentation sweeps fail. Recognize them and stop immediately if you catch yourself doing any:

### 1. Mechanical Application
Adding `# Does X` above every `func _do_X()`. This produces comments that mirror function names and add zero insight. The decision tree exists to PREVENT this — use it honestly.

### 2. Structural-Only Pass
Checking headers, WHY blocks, exports, and history — then marking "DONE" without ever reading the method bodies. This is what happened before. Structural checks are necessary but NOT sufficient.

### 3. Fabrication
Writing a comment that sounds plausible but doesn't match what the code actually does. This happens when you document without understanding. A wrong comment is worse than no comment — it actively misleads the next developer.

**If you catch yourself doing any of these, stop the batch and report it honestly.**

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

- **Public API methods** — anything a developer or game script would call
- **Virtual hook implementations** — when the method is called by a base class, what the base class expects, and what this implementation specifically does. The reader should not need to trace 3 levels of inheritance to understand the call chain.
- **Methods with side effects** — writes to scene tree, modifies engine state, has ordering dependencies
- **Non-obvious architectural decisions** — why this approach instead of the obvious one
- **Complex branching logic** — anything >10 lines with non-trivial control flow
- **Class-level `##` tooltip** — every `class_name` must have one for the Create New Node menu

## What to SKIP

- `_init()` that just sets a flag
- `_get_property_list()` / `_set()` / `_get()` — Godot boilerplate whose structure IS its documentation
- Trivial one-liner overrides where the base class comment already explains the contract AND the implementation is obvious from the body
- `_get_target_resource_type()` returning a string literal
- Any method whose name + signature + 1-2 line body is completely self-describing
- `_clear_*_editor_cache_typed()` — obvious reset-to-defaults

## The Adversarial Test

Before writing a comment, ask: *"Would an adversarial code reviewer flag this comment as useless filler?"* If yes, don't write it. A missing comment is neutral. A bad comment is negative.

After writing a comment, ask: *"Does this tell the reader something they could NOT figure out from the code alone in under 30 seconds?"* If no, delete it.

## Translation Rule (Historical Comments)

When you encounter a comment referencing V0, migration, porting, refactoring, **or development phases/sprints**:
1. Read it carefully — it may contain useful architectural insight
2. Extract the TECHNICAL RATIONALE (the "why" behind the decision)
3. Rewrite it as pure structural reasoning without any historical or phase reference
4. If the comment has NO useful information beyond history, delete it

**Before:** `# Mirrors V0's direct-apply pattern: initialises effects on first call`
**After:** `## Bypasses the standard animation loop to allow external systems to drive the effect. Initialises effects on first call, then writes deltas directly each call.`

**Before:** `# Phase B: Sibling stacking with metadata-based natural base capture`
**After:** `# Sibling stacking with metadata-based natural base capture`

## No TODO / FIXME / HACK in Shipping Code

`TODO`, `FIXME`, and `HACK` comments signal "this isn't finished" to marketplace buyers. They belong in issue trackers, not source files.

- Before deleting a TODO, verify whether the work was already done (stale) or is still needed
- If still needed, track it externally and delete the comment
- If stale, just delete it
- Never blindly nuke TODOs without checking — they may flag real incomplete features
