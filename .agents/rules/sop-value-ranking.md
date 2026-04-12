---
trigger: always_on
description: Enforces the SOP mechanism value ranking and token budget allocation. Rules and AGENTS.md are prioritized over Skills, Workflows, and Memories.
---

# SOP Value Ranking and Implementation Strategy

## SOP Mechanism ROI Ranking

1. **Skills (High ROI)** - Reference knowledge with progressive disclosure
2. **Workflows (High ROI)** - Complex procedure orchestration, user-controlled
3. **MCP Integration (High ROI)** - Direct Godot engine and documentation access
4. **Rules (Medium ROI)** - Simple guidelines, but not enforceable
5. **AGENTS.md (Medium ROI)** - Location-specific rules
6. **Memories (Zero ROI)** - Unreliable

## Token Budget Allocation

- **Skills**: 30% of SOP context budget
- **Workflows**: 30% of SOP context budget
- **MCP Integration**: 30% of SOP context budget
- **Rules**: 10% of SOP context budget
- **Memories**: 0% - use Skills instead

## Implementation Guidance

Use `@create-quality-skill` for Skill patterns and `@create-quality-rules` for Rule standards.

**Bottom line**: Skills, Workflows, and MCP for complex procedures, Rules for simple guidelines, no Memories.
