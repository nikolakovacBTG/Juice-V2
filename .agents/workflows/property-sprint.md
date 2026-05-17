---
description: "Artifact-anchored execution workflow for the Property family refactor sprint. Prevents drift by locking agents to one sub-phase at a time and mandating artifact re-reads before any code edits."
---

You are executing a **Property Family Refactor Sprint**.
The design is fully documented in 4 artifacts. You do NOT improvise design — you implement what the artifacts specify.

---

## Artifact Registry (MANDATORY — read before every sub-phase)

| Artifact | Path | Contains |
|----------|------|----------|
| **From/To UX Contract** | `from_to_ux_contract.md` in the conversation artifacts dir | Reference models, inspector layout patterns, two-state vs amplitude rules |
| **Type Matrix** | `type_matrix.md` in the conversation artifacts dir | Complete type→treatment table for all 21 types × 4 effects |
| **Current State Audit** | `current_state_audit.md` in the conversation artifacts dir | Per-file gap analysis with exact missing features |
| **Sprint Plan** | `property_sprint_plan.md` in the conversation artifacts dir | Workstream/sub-phase breakdown, dependency order, success criteria |

---

## Phase Lock Protocol (MANDATORY)

1. **State your current sub-phase** before writing any code. One sentence: "I am executing Phase X.Y: [description]."
2. **Re-read the relevant artifact section** for your sub-phase. State what you read and what it requires.
3. **Cross-check the Type Matrix** before writing any match/case block. State the exact types your code must handle. If your match statement has fewer branches than the Type Matrix specifies — STOP.
4. **Do NOT jump ahead.** If you discover work that belongs to a later phase, note it and continue with the current sub-phase only.
5. **Do NOT simplify.** If the artifact says "full two-state reference model with CaptureAt", you implement full two-state reference model with CaptureAt. Signal words that indicate drift: "for now", "simplified version", "we can add later", "not needed yet" — writing any of these is a **hard stop**. Ask the user before proceeding.

---

## Pre-Edit Checklist (MANDATORY — before every file edit)

- [ ] I stated my current sub-phase
- [ ] I re-read the relevant artifact section
- [ ] I cross-checked the Type Matrix for type coverage
- [ ] I verified the Current State Audit for what already exists in this file
- [ ] My edit addresses ONLY the current sub-phase scope

---

## Completeness Gate (MANDATORY — before declaring a sub-phase done)

1. **Type coverage**: Count your match branches against the Type Matrix. Every type in the matrix MUST have a branch. List them.
2. **Inspector layout**: For target resources, verify every conditional group/field matches the From/To UX Contract layout pattern.
3. **Backing var serialization**: Every new var must appear in both `_set()` and `_get()`, and be serialized (PROPERTY_USAGE_STORAGE) when hidden.
4. **No orphaned code paths**: If you added compute logic in the effect base, verify the corresponding target resource exposes the config the compute reads.

---

## Verification (MANDATORY — after each sub-phase)

1. Run `/test` if automated tests exist for the edited files
2. If no test exists, state "NO TEST EXISTS" and note what manual check is needed
3. Screenshot the inspector layout via MCP to verify visual correctness
4. Do NOT proceed to next sub-phase until current sub-phase passes verification

---

## Integration with /code

This workflow **extends** `/code`. All rules from `/code` still apply (authorization gate, header comments, inspector standards, MCP safety, generic protocol). This workflow adds artifact anchoring on top.

When invoking: `@property-sprint Phase X.Y`
