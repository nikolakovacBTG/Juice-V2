# Upgrades and Fixes TO DO

> Active upgrade and fix plans for the Juice Demo project.
> Completed designs are moved to `Documentation/Done/`.

---

## SOP Gap: `/realistic-test` workflow missing MCP Interactive Testing tier

The `/realistic-test` workflow only covers headless GDUnit4 tests. It has no guidance for the non-headless testing tier that MCP0 enables.

**What needs to be added (without pseudocode dumping or bloating the workflow):**
- A lean second tier in the workflow that points to a skill
- A `@mcp-interactive-testing` skill with proper progressive disclosure (router + pattern files)
- Pattern files covering: simulate_input user flows, screenshot assertion, live node state inspection, editor transport — each as a focused, separate pattern doc

**Design constraints learned from the failed attempt:**
- Workflows must stay lean — directive, not tutorial
- Skills hold the depth via progressive disclosure (SKILL.md = router only, patterns in subfiles)
- The scope is broader than just the preview transport: simulate_input for real user behavior, get_node_properties for live state, screenshots for visual assertion are all first-class patterns
- Do NOT dump pseudocode into the workflow or skill router

**Files to create:**
- `.agents/workflows/realistic-test.md` — add a single lean Tier 2 block pointing to `@mcp-interactive-testing`
- `.agents/skills/mcp-interactive-testing/SKILL.md` — router only
- `.agents/skills/mcp-interactive-testing/PATTERNS/simulate-user-behavior.md`
- `.agents/skills/mcp-interactive-testing/PATTERNS/screenshot-assertion.md`
- `.agents/skills/mcp-interactive-testing/PATTERNS/live-state-inspection.md`
- `.agents/skills/mcp-interactive-testing/PATTERNS/editor-transport.md`

