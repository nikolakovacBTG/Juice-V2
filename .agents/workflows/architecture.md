---
description: Architecture workflow - base for port, review, refactor workflows with Juice architecture context
---

You are in ARCHITECTURE MODE.

This is the base workflow for Juice architecture-related tasks. It provides context and smart loading for specialized sub-workflows.

**Skills auto-invoked:** `@juice-architecture`, `@juice-architecture-contracts`

---

## Architecture Context

### Juice L1-3 Architecture
- **L1 Core:** Delta-first model, timing system, base interfaces
- **L2 Domain:** Write coordination, sibling stacking, domain separation, external move detection
- **L3 Effects:** Transform deltas, appearance, procedural animation, shader integration, meta effects, utility patterns

### Key Architectural Contracts
- **Effects calculate deltas only** - never write directly to targets
- **Domain nodes aggregate and write once per frame**
- **All three domains must have equivalent features**
- **Delta-first mathematical model** for all animations

---

## Sub-Workflow Selection

Based on your task, invoke the appropriate sub-workflow:

### /port - Port V0 Effects
```
/port [effect_name]
```
Ports a V0 Juice effect component to the resource-based architecture.
Batches all 3 domains together with auto-testing and verification.

### /review - Architecture Compliance Review
```
/review [files_or_scope]
```
Reviews code against Juice architecture patterns and project standards.
Analyzes layer contracts, anti-patterns, and quality criteria.

### /refactor - Safe Architecture Refactoring
```
/refactor [scope_description]
```
Systematic refactoring with backup, validation, and documentation.
Maintains behavior while improving structure and compliance.

---

## Architecture Resources

### Quick Reference
- **Architecture Big Picture:** `Documentation 2/ANCHORS/ARCHITECTURE_BIG_PICTURE.md`
- **L1-3 Contract Matrix:** `Documentation 2/ANCHORS/L1-3_CONTRACT_MATRIX.md`
- **Cross-Reference Map:** `Documentation 2/ANCHORS/CROSS_REFERENCE_MAP.md`

### Layer Documentation
- **L1 Core:** `Documentation 2/L1/` - delta-first model, timing, interfaces
- **L2 Domain:** `Documentation 2/L2/` - write coordination, stacking, separation
- **L3 Effects:** `Documentation 2/L3/` - effect implementation patterns

### Rules and Standards
- **Coding Standards:** `Documentation 2/Rules/RULE-coding-standards.md`
- **Architecture Contracts:** `Documentation 2/Rules/RULE-architecture-contracts.md`
- **Documentation Headers:** `Documentation 2/Rules/RULE-documentation-headers.md`

---

## Architecture Validation

### Layer Contract Compliance
- [ ] L1 provides pure mathematical foundations
- [ ] L2 coordinates but doesn't calculate deltas
- [ ] L3 calculates deltas but doesn't write
- [ ] Cross-domain dependencies don't exist

### Domain Completeness
- [ ] All features exist in Control, Node2D, and Node3D domains
- [ ] Domain-specific math is correct (Vector2 vs Vector3)
- [ ] Container hold pattern works for Control only
- [ ] External move detection exists in all domains

### Quality Standards
- [ ] Header formatting follows EXPECTS/PROVIDES/ARCHITECTURE pattern
- [ ] No hardcoded magic numbers
- [ ] Type-safe discovery patterns used
- [ ] Anti-patterns avoided

---

## Context Management Strategies

### For Long-Running Tasks

When working on complex tasks that may span multiple sessions or require significant context:

#### Phase Identification
- **Assess task complexity** - Identify natural break points in the work
- **Functional completeness** - Each phase should deliver complete functionality
- **Dependency mapping** - Understand what each phase depends on
- **Risk assessment** - Identify high-risk areas that might need isolation

#### Context Preservation
- **Commit boundaries** - Create clear git commits at phase boundaries
- **Documentation checkpoints** - Document phase status and next steps
- **State markers** - Use tags or branches to mark phase completion
- **Handoff preparation** - Ensure next session can understand current state

#### Headroom Management
- **Context budgeting** - Keep active context under 4,000 tokens per session
- **Smart loading** - Load only phase-relevant documentation
- **Context cleanup** - Clear unused context between phases
- **Progressive disclosure** - Start with essential, add detail as needed

#### Multi-Session Coordination
- **Session goals** - Define clear objectives for each work session
- **State communication** - Document session end state and next session start
- **Continuity planning** - Ensure smooth handoff between sessions
- **Rollback preparation** - Maintain ability to return to previous phase states

---

## Common Architecture Tasks

### Adding New Effects
1. Create L3 effect resources for all 3 domains
2. Follow delta-first calculation pattern
3. Register in recipe whitelists
4. Write tests for all domains
5. Verify layer contract compliance

### Architecture Compliance Issues
1. Identify violation type (layer breach, domain incompleteness, anti-pattern)
2. Reference appropriate L1-3 documentation
3. Apply fix according to architecture contracts
4. Validate with test suite

### Performance Optimization
1. Profile delta calculations in L3 effects
2. Optimize write coordination in L2 domains
3. Verify no per-frame allocations
4. Test with multiple stacked effects

---

## Integration Points

### With Documentation System
- All architecture changes should reference Documentation 2 files
- Cross-reference integrity must be maintained
- Header formatting must follow new standards

### With Test System
- All architecture changes require test coverage
- Use @verify-claims skill for validation
- Test suite must pass before marking complete

### With Git Workflow
- Follow RULE-git-discipline.md for commit standards
- Use feature branches for architecture changes
- Commit in logical units with validation

---

## Architecture Decision Process

When making architecture decisions:

1. **Check L1-3 contracts** - does this violate layer boundaries?
2. **Verify domain completeness** - will this work in all 3 domains?
3. **Consult documentation** - is this pattern already documented?
4. **Consider performance** - what are the performance implications?
5. **Plan testing** - how will this be validated?

---

## Skills Integration

This workflow automatically invokes:
- **@juice-architecture** - Core architecture rules and code templates
- **@juice-architecture-contracts** - One-page contracts and decision tree

These skills provide:
- Smart loading of relevant architecture documentation
- Code templates for L1-3 implementation
- Validation checklists and contracts
- Cross-reference navigation

---

## Error Handling

### Common Architecture Errors
- **Layer breach:** L3 writing to targets or L2 calculating deltas
- **Domain incompleteness:** Feature exists in one domain but not others
- **Anti-patterns:** Hardcoded properties, string IDs, external dependencies
- **Performance issues:** Per-frame allocations, inefficient delta calculations

### Recovery Process
1. Identify error type using architecture contracts
2. Reference appropriate L1-3 documentation
3. Apply fix according to established patterns
4. Validate with test suite
5. Document lessons learned

---

This architecture workflow provides the foundation for all Juice architecture-related work while ensuring compliance with established patterns and quality standards.
