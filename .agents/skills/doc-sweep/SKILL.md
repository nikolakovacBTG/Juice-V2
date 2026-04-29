---
name: doc-sweep
description: "Skill: In-script documentation quality sweep for Juice V1. Ensures method comments, class tooltips, export tooltips, and history sanitization meet marketplace standards."
---

# Documentation Sweep Skill

Ensures every script in `addons/Juice_V1/` meets marketplace-grade documentation standards.
Invoked automatically by the `/doc-sweep` workflow, or manually when touching documentation.

## The Non-Negotiable Principle

**You must understand the code before you document it.**

Documentation is not a formatting pass. It is a comprehension exercise where the output happens to be comments. If you find yourself writing comments without having traced the call chain, understood the inheritance hierarchy, or grasped the architectural role of a method — STOP. You are producing noise, not documentation.

The previous sweep covered structural elements (headers, WHY blocks, export tooltips, history cleanup) across the entire codebase, but left method-level documentation incomplete in concrete effects and utilities. The structural work is solid and should not be redone. The remaining work is method comprehension — the hardest and most valuable part.

## Quality Standard (re-read before EVERY file)

See [REFERENCES/quality-standard.md](REFERENCES/quality-standard.md) — the compact rules card.

## Per-File Checklist (the two-phase process)

See [REFERENCES/per-file-checklist.md](REFERENCES/per-file-checklist.md).

The checklist has two phases:
- **Phase A (Structural)** — headers, exports, tooltips, history. Fast. Already complete for most files.
- **Phase B (Method Comprehension)** — understanding the code, triaging every method, writing comments where needed. Slow. This is where quality lives.

**A file that passes Phase A but skips Phase B is STRUCTURAL, not DONE.**

## Decision Tree

Before commenting a method, ask:

1. **Is the method body ≤ 2 lines AND the name is self-describing?** → SKIP (e.g. `_needs_sustain() -> bool: return true`)
2. **Is it Godot boilerplate?** (`_get_property_list`, `_set`, `_get`, `_init` setting a flag) → SKIP unless non-obvious logic exists
3. **Is it a public API method?** (`##` comment) → MUST document: what it does, when to call it, side effects
4. **Is it a virtual hook implementation?** → MUST document with `#` or `##`: when it's called by the base class, what this implementation does, any non-obvious behavior (ledger reads, skip guards, fallback chains)
5. **Is it a private method with architectural significance?** (side effects, ordering dependencies, >10 lines) → MUST document with `#`: what problem it solves
6. **Is it a trivial helper?** (pure function, <5 lines, obvious from name) → SKIP or one-liner max

**Critical addition from experience:** Rule 4 is new and addresses the biggest gap from the previous sweep. Virtual hook implementations (like `_do_capture_base`, `_apply_position_effect`, `_capture_from_self_position_snapshot`) are the methods that connect concrete effects to the architecture. Without comments explaining WHEN they're called and WHAT they do in this specific class, a developer must trace through 3 levels of inheritance to understand the system. This is the primary documentation failure we are correcting.

## Good vs Bad Examples

See [EXAMPLES/good-vs-bad.md](EXAMPLES/good-vs-bad.md) — real examples from this codebase.

## TODO Triage Protocol

When a file contains `TODO`, `FIXME`, or `HACK` comments:

1. **Verify** — read the surrounding code to determine if the work was already done (stale) or is still needed (valid)
2. **Stale** — delete or replace with an accurate comment explaining the current behavior. Fix in-place during the sweep.
3. **Valid** — do NOT delete, do NOT implement during the sweep. Report as a **blocker** in the batch summary. The file stays at status `BLOCKED` until the user resolves the underlying work item.

The sweep must never silently delete a TODO that represents real incomplete work.

## Diagnostic Script

See [scripts/audit.ps1](scripts/audit.ps1) — generates per-file coverage report.

## Validation

After editing a file, run [VALIDATION/post-edit-check.md](VALIDATION/post-edit-check.md).
