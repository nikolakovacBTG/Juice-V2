---
name: doc-sweep
description: In-script documentation quality sweep for Juice V1. Ensures method comments, class tooltips, export tooltips, and history sanitization meet marketplace standards. Use when documenting scripts or reviewing documentation quality.
---

# Documentation Sweep Skill

Ensures every script in `addons/Juice_V1/` meets marketplace-grade documentation standards.
Invoked automatically by the `/doc-sweep` workflow, or manually when touching documentation.

## Quality Standard (re-read before EVERY file)

See [REFERENCES/quality-standard.md](REFERENCES/quality-standard.md) — the compact rules card.

## Decision Tree

Before commenting a method, ask:

1. **Is the method body ≤ 2 lines AND the name is self-describing?** → SKIP (e.g. `_needs_sustain() -> bool: return true`)
2. **Is it Godot boilerplate?** (`_get_property_list`, `_set`, `_get`, `_init` setting a flag) → SKIP unless non-obvious logic exists
3. **Is it a public API method?** (`##` comment) → MUST document: what it does, when to call it, side effects
4. **Is it a private method with architectural significance?** (side effects, ordering dependencies, >10 lines) → MUST document with `#`: what problem it solves
5. **Is it a trivial helper?** (pure function, <5 lines, obvious from name) → SKIP or one-liner max

## What to Check Per File

See [REFERENCES/per-file-checklist.md](REFERENCES/per-file-checklist.md).

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
