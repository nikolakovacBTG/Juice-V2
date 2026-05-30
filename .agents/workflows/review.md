---
description: Comprehensive code review against project standards, architecture patterns, and quality criteria
---

You are in REVIEW MODE.

**Parent workflow:** `/architecture` - See `/architecture` for Juice architecture context

---

## Authorization Gate (MANDATORY)

In review mode, I must NOT make write changes.

If a fix would involve:

- **Migrations** (changing configs/behaviour across scenes or systems)
- **Any edits to** `.tscn`, `.tres`, `.res`
- **Any revert/restore/cleanup** (including undoing user testing tweaks)

Then I must STOP, describe the proposed change, and ask for explicit authorization before switching to /code.

Your task is to perform a thorough, systematic code review.
You do NOT fix code directly in review mode. You analyze, document, and report.
Fixes are proposed and prioritized, but implementation happens in /code mode.

Primary goals:
- Verify code correctness and completeness against design specifications.
- Ensure adherence to project naming conventions and folder organization.
- Identify architecture pattern violations and anti-patterns.
- Assess code quality, readability, and maintainability.
- Document all findings with severity, location, and actionable recommendations.

GENERAL STOP RULE:
If the scope of review is unclear, STOP and ASK before proceeding.

---

### 1. Scope Identification (MANDATORY)

Before reviewing, explicitly confirm:
- What files or systems are being reviewed?
- Is there an approved design specification to review against?
- What is the primary concern? (correctness, style, architecture, performance)

If scope is not provided:
- Check for uncommitted changes via `git diff`
- If no changes, ask user what to review
- Never assume scope

---

### 2. Project Standards Check

Review all code against established project conventions:

#### Naming Conventions (from AGENTS.md)
- [ ] Component Nodes: `XxxComp` suffix
- [ ] Resource Definitions: `XxxDef` suffix
- [ ] Base Classes: `XxxBase` suffix (no underscore prefix)
- [ ] Managers/Controllers: Full descriptive names
- [ ] File names match `class_name` exactly

#### Required Script Elements
- [ ] Header comment explaining purpose, system, and non-responsibilities
- [ ] `@export var debug_enabled: bool = false` for debug toggle
- [ ] All gameplay values exposed via `@export`
- [ ] No hardcoded magic numbers without explanation
- [ ] Comments explain WHY, not just WHAT

#### Folder Organization
- [ ] Juice addon untouched in `addons/juice/` (read-only subtree)
- [ ] Demo scenes organized by domain or feature
- [ ] Presets in dedicated presets folder
- [ ] Documentation in `Documentation/`

---

### 3. Architecture Pattern Compliance

**Quick reference:** `@juice-architecture-contracts` one-page contracts

Verify adherence to established patterns:

#### Layer Contract Compliance
- [ ] L1 (Core) has no domain-specific logic
- [ ] L2 (Domain) filters targets correctly and writes once per frame
- [ ] L3 (Effects) compute deltas only, never write directly
- [ ] Data flow follows L1→L2→L3→L2 contract pattern

#### Addon Boundary
- [ ] No files modified inside `addons/juice/` (read-only subtree)
- [ ] Demo scripts do not import or depend on Cold Soul systems
- [ ] Any Juice bugs documented for upstream fix

#### Component Pattern
- [ ] Components are self-contained and reusable
- [ ] Communicate via signals for loose coupling
- [ ] Use NodePath exports for sibling references
- [ ] Have `_get_configuration_warnings()` for required dependencies

#### Demo Scene Pattern
- [ ] Each demo is self-contained and showcases 1-3 related comps
- [ ] On-screen descriptions explain what's happening
- [ ] Presets are minimal, copy-paste ready

---

### 4. Anti-Pattern Detection

Flag the following anti-patterns from AGENTS.md:

- [ ] String IDs in arrays instead of typed resource arrays
- [ ] Modifications inside `addons/juice/` (should be read-only)
- [ ] Hardcoded magic numbers
- [ ] Dependencies on Cold Soul systems (GameController, SignalBus, etc.)
- [ ] Tight coupling between unrelated systems
- [ ] God objects (scripts doing too much)
- [ ] Deep inheritance hierarchies
- [ ] Circular dependencies
- [ ] Missing configuration warnings for required dependencies
- [ ] Hardcoded paths to non-existent resources
- [ ] **Hardcoded property channels** — code that enumerates specific properties ("position", "rotation", "scale") instead of using a generic protocol (e.g., `_get_seq_contribution() -> Dictionary`). Symptom: adding a new effect type would require modifying the aggregation/write code.
- [ ] **Per-domain copy-paste** — identical logic duplicated across JuiceControl, Juice2D, Juice3D that should live in JuiceBase or in a shared protocol method on effect bases
- [ ] **Band-aid protocol fixes** — fixes at effect↔node boundaries that only cover known cases instead of defining an extensible contract

---

### 5. Code Quality Assessment

Evaluate overall code quality:

#### Readability
- [ ] Functions are short and focused (single responsibility)
- [ ] Variable names are descriptive
- [ ] Logic flow is clear and predictable
- [ ] No deeply nested conditionals
- [ ] Early returns used appropriately

#### Maintainability
- [ ] Changes can be made without side effects
- [ ] Dependencies are explicit and documented
- [ ] Error handling is graceful with clear messages
- [ ] External connections are documented in comments

#### Type Safety
- [ ] Type hints used on function parameters
- [ ] Type hints used on return values
- [ ] Typed arrays used (e.g., `Array[ActionDef]`)
- [ ] Null checks where appropriate

#### Debugging
- [ ] Debugging is enabled via `debug_enabled` flag
- [ ] Debug logging is used for tracing
- [ ] Debug logging is disabled in release builds

#### Performance
- [ ] Performance is optimized
- [ ] Memory usage is minimized
- [ ] CPU usage is minimized

#### Documentation and Comments
- [ ] Documentation is up-to-date
- [ ] Documentation is clear and concise
- [ ] Documentation is easy to understand
- [ ] Comments explain WHY, not just WHAT
- [ ] Inline comments that serve as tooltips are clear and concise and formated to be easily readable in the editor 
---

### 6. Design Specification Alignment

If a design document exists:
- [ ] Implementation matches approved design
- [ ] All specified features are implemented
- [ ] No features added beyond design scope
- [ ] Data flow matches design specification
- [ ] Integration points are correctly implemented

---

## Step 4: Visual Inspector Audit (MANDATORY)

Code consistency isn't just about syntax; it's about the UX in the Godot Inspector.

1. Create a temporary scene with a `Juice` node (Control, 2D, or 3D).
2. Attach the effect under review to a Recipe on that node.
3. Use `mcp_get_editor_screenshot` to capture the Inspector view of the effect.
4. **Audit**:
    - Are `@export` names readable?
    - Are groups (`_get_property_list`) correctly separated?
    - Are tooltips (`##` comments) showing correctly?
5. Include the screenshot in the review report.

---

## Step 5: Report Results

Structure all findings as follows:

#### Summary
[1-2 sentence overall assessment of code quality]

#### Critical Issues (Must Fix)
| Severity | File:Line | Issue | Impact | Recommendation |
|----------|-----------|-------|--------|----------------|
| 🔴 Critical | ... | ... | ... | ... |

#### Warnings (Should Fix)
| Severity | File:Line | Issue | Impact | Recommendation |
|----------|-----------|-------|--------|----------------|
| 🟡 Warning | ... | ... | ... | ... |

#### Style Issues (Consider Fixing)
| Severity | File:Line | Issue | Recommendation |
|----------|-----------|-------|----------------|
| 🔵 Style | ... | ... | ... |

#### Positive Observations
[Things done well that should be maintained]

#### Architecture Notes
[Observations about system design and patterns]

---

### 8. Prioritized Action Plan

After documenting findings:
1. Rank issues by severity and impact
2. Group related issues for efficient fixing
3. Identify quick wins vs major refactors
4. Recommend order of implementation

---

### 9. Post-Review Options

After presenting findings, offer:
- "Would you like me to fix any of these issues?" → Switch to /code mode
- "Would you like me to create a refactor plan?" → Switch to /refactor mode
- "Would you like more details on any finding?" → Elaborate

FINAL RULES:
- Analyze and report only — no fixes in review mode
- Be thorough but concise in findings
- Always provide actionable recommendations
- Maintain objectivity and cite specific evidence
