# Cross-Reference Map

**Purpose:** Complete mapping of all dependencies and cross-references in the Documentation 2 system. Ensures no broken links during refactoring.

---

## L1 Core Document Dependencies

### L1-delta-first-model.md
**Dependencies:**
- References: L1-layer-contracts.md (for layer boundaries)
- Referenced by: All L2 docs (write coordination), L3 docs (delta calculation pattern)
- Skills: @juice-architecture (core contracts)
- Workflows: /architecture (smart loading)

**Cross-References:**
```markdown
See L1-layer-contracts.md for layer boundary definitions
See L2-write-coordination.md for implementation
See L3-transform-deltas.md for effect examples
```

### L1-layer-contracts.md
**Dependencies:**
- References: L1-3_CONTRACT_MATRIX.md (complete contract matrix)
- Referenced by: All L1 docs, All L2 docs, All L3 docs
- Skills: @juice-architecture (layer validation)
- Workflows: /review (contract compliance)

**Cross-References:**
```markdown
See L1-3_CONTRACT_MATRIX.md for complete contract definitions
See ARCHITECTURE_BIG_PICTURE.md for system overview
```

### L1-timing-system.md
**Dependencies:**
- References: L1-layer-contracts.md (timing contracts)
- Referenced by: L2 docs (per-frame processing), L3 docs (effect timing)
- Skills: @juice-architecture (timing patterns)
- Workflows: /port (timing considerations)

**Cross-References:**
```markdown
See L1-layer-contracts.md for timing contract definitions
See L2-write-coordination.md for per-frame implementation
```

### L1-base-interfaces.md
**Dependencies:**
- References: L1-layer-contracts.md (interface contracts)
- Referenced by: All L2 docs (base class usage), All L3 docs (effect interfaces)
- Skills: @juice-architecture (interface templates)
- Workflows: /refactor (interface changes)

**Cross-References:**
```markdown
See L1-layer-contracts.md for interface contract definitions
See L2 docs for domain-specific implementations
```

---

## L2 Domain Document Dependencies

### L2-write-coordination.md
**Dependencies:**
- References: L1-delta-first-model.md (theoretical model), L1-layer-contracts.md (layer contracts)
- Referenced by: All L2 docs (coordination pattern), L3 docs (write expectations)
- Skills: @juice-architecture (coordination patterns)
- Workflows: /architecture (write coordination validation)

**Cross-References:**
```markdown
See L1-delta-first-model.md for mathematical foundation
See L1-layer-contracts.md for write coordination contracts
See L3 docs for effect contribution expectations
```

### L2-sibling-stacking.md
**Dependencies:**
- References: L2-write-coordination.md (aggregation logic), L1-layer-contracts.md (stacking contracts)
- Referenced by: All L2 docs (stacking implementation), L3 docs (contribution reporting)
- Skills: @juice-architecture (stacking patterns)
- Workflows: /review (stacking validation)

**Cross-References:**
```markdown
See L2-write-coordination.md for delta aggregation
See L1-layer-contracts.md for stacking contract definitions
See L3 docs for effect contribution interfaces
```

### L2-domain-separation.md
**Dependencies:**
- References: L1-layer-contracts.md (domain contracts), ARCHITECTURE_BIG_PICTURE.md (domain strategy)
- Referenced by: All L2 docs (domain boundaries), L3 docs (domain-specific implementation)
- Skills: @juice-architecture (domain validation)
- Workflows: /review (domain compliance)

**Cross-References:**
```markdown
See L1-layer-contracts.md for domain boundary contracts
See ARCHITECTURE_BIG_PICTURE.md for domain separation strategy
See L3 docs for domain-specific effect patterns
```

### L2-external-move-detection.md
**Dependencies:**
- References: L2-write-coordination.md (write coordination), L1-delta-first-model.md (base capture)
- Referenced by: All L2 docs (external move handling), L3 docs (base reference expectations)
- Skills: @juice-architecture (external move patterns)
- Workflows: /bugfix (external move issues)

**Cross-References:**
```markdown
See L2-write-coordination.md for write coordination integration
See L1-delta-first-model.md for base value capture theory
```

---

## L3 Effect Document Dependencies

### L3-appearance-from-to.md
**Dependencies:**
- References: L2-domain-separation.md (domain differences), L1-timing-system.md (From/To timing)
- Referenced by: L2 docs (appearance effect handling), Skills (appearance templates)
- Skills: @juice-architecture (appearance patterns)
- Workflows: /port (appearance effect porting)

**Cross-References:**
```markdown
See L2-domain-separation.md for domain-specific appearance handling
See L1-timing-system.md for From/To timing integration
```

### L3-transform-deltas.md
**Dependencies:**
- References: L1-delta-first-model.md (delta calculation), L2-domain-separation.md (transform differences)
- Referenced by: L2 docs (transform effect handling), Skills (transform templates)
- Skills: @juice-architecture (transform patterns)
- Workflows: /port (transform effect porting)

**Cross-References:**
```markdown
See L1-delta-first-model.md for delta calculation foundation
See L2-domain-separation.md for domain-specific transform handling
```

### L3-procedural-animation.md
**Dependencies:**
- References: L1-timing-system.md (procedural timing), L2-domain-separation.md (domain math)
- Referenced by: L2 docs (procedural effect handling), Skills (procedural templates)
- Skills: @juice-architecture (procedural patterns)
- Workflows: /port (procedural effect porting)

**Cross-References:**
```markdown
See L1-timing-system.md for procedural timing patterns
See L2-domain-separation.md for domain-specific math
```

### L3-shader-integration.md
**Dependencies:**
- References: L2-domain-separation.md (shader differences), L1-base-interfaces.md (effect interfaces)
- Referenced by: L2 docs (shader effect handling), Skills (shader templates)
- Skills: @juice-architecture (shader patterns)
- Workflows: /port (shader effect porting)

**Cross-References:**
```markdown
See L2-domain-separation.md for domain-specific shader handling
See L1-base-interfaces.md for effect interface contracts
```

### L3-meta-effects.md
**Dependencies:**
- References: L1-timing-system.md (meta timing), L2-domain-separation.md (meta coordination)
- Referenced by: L2 docs (meta effect handling), Skills (meta templates)
- Skills: @juice-architecture (meta patterns)
- Workflows: /port (meta effect porting)

**Cross-References:**
```markdown
See L1-timing-system.md for meta effect timing
See L2-domain-separation.md for meta coordination patterns
```

### L3-utility-patterns.md
**Dependencies:**
- References: L1-base-interfaces.md (utility interfaces), L2-domain-separation.md (utility coordination)
- Referenced by: L2 docs (utility handling), Skills (utility templates)
- Skills: @juice-architecture (utility patterns)
- Workflows: /port (utility porting)

**Cross-References:**
```markdown
See L1-base-interfaces.md for utility interface contracts
See L2-domain-separation.md for utility coordination patterns
```

---

## Rules Document Dependencies

### RULE-coding-standards.md
**Dependencies:**
- References: L1-layer-contracts.md (layer boundaries), RULE-documentation-headers.md (header format)
- Referenced by: All documentation files (format compliance), Skills (code generation)
- Skills: @juice-architecture (standards enforcement)
- Workflows: /review (standards validation)

**Cross-References:**
```markdown
See L1-layer-contracts.md for layer boundary standards
See RULE-documentation-headers.md for header format requirements
```

### RULE-architecture-contracts.md
**Dependencies:**
- References: L1-3_CONTRACT_MATRIX.md (complete contracts), ARCHITECTURE_BIG_PICTURE.md (architectural truth)
- Referenced by: All L1-3 docs (contract compliance), Skills (contract validation)
- Skills: @juice-architecture (contract enforcement)
- Workflows: /review (contract validation)

**Cross-References:**
```markdown
See L1-3_CONTRACT_MATRIX.md for complete contract definitions
See ARCHITECTURE_BIG_PICTURE.md for architectural foundation
```

### RULE-documentation-headers.md
**Dependencies:**
- References: RULE-coding-standards.md (overall standards), L1-layer-contracts.md (header examples)
- Referenced by: All documentation files (header format), Skills (header generation)
- Skills: @juice-architecture (header validation)
- Workflows: /review (header compliance)

**Cross-References:**
```markdown
See RULE-coding-standards.md for overall coding standards
See L1-layer-contracts.md for header format examples
```

### RULE-git-discipline.md
**Dependencies:**
- References: ARCHITECTURE_BIG_PICTURE.md (project scope), Memory docs (version control strategy)
- Referenced by: All workflows (git operations), Skills (git-aware operations)
- Skills: @juice-architecture (git integration)
- Workflows: All workflows (git discipline)

**Cross-References:**
```markdown
See ARCHITECTURE_BIG_PICTURE.md for project scope context
See Memory docs for version control strategy
```

### RULE-verification.md
**Dependencies:**
- References: RULE-architecture-contracts.md (contract validation), Memory docs (testing patterns)
- Referenced by: All workflows (verification steps), Skills (claim validation)
- Skills: @verify-claims (verification enforcement)
- Workflows: /test, /review, /bugfix (verification)

**Cross-References:**
```markdown
See RULE-architecture-contracts.md for contract validation
See Memory docs for testing and verification patterns
```

### RULE-anti-patterns.md
**Dependencies:**
- References: RULE-architecture-contracts.md (contract violations), Memory docs (historical bugs)
- Referenced by: All documentation files (anti-pattern avoidance), Skills (anti-pattern detection)
- Skills: @juice-architecture (anti-pattern prevention)
- Workflows: /review (anti-pattern detection)

**Cross-References:**
```markdown
See RULE-architecture-contracts.md for contract violation patterns
See Memory docs for historical bug patterns and solutions
```

---

## Memory Document Dependencies

### MEMORY-architecture-decisions.md
**Dependencies:**
- References: ARCHITECTURE_BIG_PICTURE.md (current state), L1-3_CONTRACT_MATRIX.md (decision rationale)
- Referenced by: All L1-3 docs (decision context), Skills (decision guidance)
- Skills: @juice-architecture (decision context)
- Workflows: /design (decision reference)

**Cross-References:**
```markdown
See ARCHITECTURE_BIG_PICTURE.md for current architectural state
See L1-3_CONTRACT_MATRIX.md for decision impact on contracts
```

### MEMORY-bug-fixes-patterns.md
**Dependencies:**
- References: RULE-anti-patterns.md (prevention), Memory docs (bug patterns)
- Referenced by: All L3 docs (bug avoidance), Skills (bug prevention)
- Skills: @juice-architecture (bug pattern awareness)
- Workflows: /bugfix (bug pattern reference)

**Cross-References:**
```markdown
See RULE-anti-patterns.md for bug prevention patterns
See other Memory docs for related bug patterns
```

### MEMORY-domain-specific-behavior.md
**Dependencies:**
- References: L2-domain-separation.md (domain contracts), ARCHITECTURE_BIG_PICTURE.md (domain strategy)
- Referenced by: All L2 docs (domain behavior), All L3 docs (domain implementation)
- Skills: @juice-architecture (domain guidance)
- Workflows: /port (domain-specific considerations)

**Cross-References:**
```markdown
See L2-domain-separation.md for domain contract definitions
See ARCHITECTURE_BIG_PICTURE.md for domain separation strategy
```

### MEMORY-performance-optimizations.md
**Dependencies:**
- References: L1-3_CONTRACT_MATRIX.md (performance contracts), RULE-coding-standards.md (performance standards)
- Referenced by: All L1-3 docs (performance considerations), Skills (performance guidance)
- Skills: @juice-architecture (performance optimization)
- Workflows: /refactor (performance considerations)

**Cross-References:**
```markdown
See L1-3_CONTRACT_MATRIX.md for performance contract requirements
See RULE-coding-standards.md for performance coding standards
```

### MEMORY-user-preferences.md
**Dependencies:**
- References: RULE-coding-standards.md (user standards), Memory docs (user history)
- Referenced by: All documentation files (user context), Skills (user-aware behavior)
- Skills: @juice-architecture (user preference awareness)
- Workflows: All workflows (user context)

**Cross-References:**
```markdown
See RULE-coding-standards.md for user-defined standards
See other Memory docs for user historical preferences
```

---

## Skill Dependencies

### @juice-architecture (Unified)
**Dependencies:**
- References: All L1-3 docs (complete architecture), All Rules (standards enforcement)
- Referenced by: All workflows (architecture guidance), All documentation (skill integration)
- Auto-invocation: Documentation 2/ files, .windsurf/skills/juice-architecture/

**Cross-References:**
```markdown
See L1 docs for core architecture contracts
See L2 docs for domain coordination patterns
See L3 docs for effect implementation guidelines
See Rules for coding standards and validation
```

---

## Workflow Dependencies

### /architecture (Base Workflow)
**Dependencies:**
- References: L1-3_CONTRACT_MATRIX.md (contract validation), ARCHITECTURE_BIG_PICTURE.md (system view)
- Referenced by: /port, /review, /refactor (base functionality)
- Skills: @juice-architecture (architecture guidance)

**Cross-References:**
```markdown
See L1-3_CONTRACT_MATRIX.md for contract validation steps
See ARCHITECTURE_BIG_PICTURE.md for system overview
```

### /port (Specialized Workflow)
**Dependencies:**
- References: /architecture (base workflow), L3 docs (effect patterns), Memory docs (V0 patterns)
- Referenced by: Skills (porting guidance), Documentation (porting examples)
- Skills: @juice-architecture, @verify-claims

**Cross-References:**
```markdown
See /architecture for base workflow steps
See L3 docs for effect implementation patterns
See Memory docs for V0 to V1 mapping patterns
```

### /review (Specialized Workflow)
**Dependencies:**
- References: /architecture (base workflow), RULE docs (validation standards), L1-3_CONTRACT_MATRIX.md
- Referenced by: Skills (review guidance), Documentation (review examples)
- Skills: @juice-architecture, @verify-claims

**Cross-References:**
```markdown
See /architecture for base workflow steps
See RULE docs for validation standards and criteria
See L1-3_CONTRACT_MATRIX.md for contract validation
```

### /refactor (Specialized Workflow)
**Dependencies:**
- References: /architecture (base workflow), RULE-git-discipline.md (git safety), Memory docs (refactor patterns)
- Referenced by: Skills (refactoring guidance), Documentation (refactor examples)
- Skills: @juice-architecture

**Cross-References:**
```markdown
See /architecture for base workflow steps
See RULE-git-discipline.md for git safety procedures
See Memory docs for refactoring patterns and considerations
```

---

## External Dependencies

### Godot Documentation
- **Referenced by:** L2 docs (domain-specific Godot APIs), L3 docs (effect implementation)
- **Purpose:** Godot API reference and best practices

### Existing Juice Codebase
- **Referenced by:** All docs (current implementation reference)
- **Purpose:** Concrete examples and implementation patterns

### Test Suites
- **Referenced by:** Memory docs (bug patterns), RULE-verification.md (validation)
- **Purpose:** Validation examples and test patterns

---

## Link Validation Rules

### Internal Link Validation
- [ ] All relative paths use correct Documentation 2/ structure
- [ ] All cross-references point to existing documents
- [ ] All anchor names are consistent and descriptive
- [ ] All dependency chains are complete and circular-free

### External Link Validation
- [ ] All Godot API links reference correct version
- [ ] All codebase references point to existing files
- [ ] All test references point to existing test files
- [ ] All external references are accessible and relevant

### Skill/Workflow Integration
- [ ] All skill invocations reference existing skills
- [ ] All workflow references point to existing workflows
- [ ] All auto-invocation triggers are correctly specified
- [ ] All skill/workflow dependencies are satisfied

---

## This Document's Role

### During Refactoring
- **Link Validation:** Ensure no broken links during reorganization
- **Dependency Tracking:** Maintain awareness of document interdependencies
- **Integration Verification:** Ensure skills and workflows integrate correctly

### After Refactoring
- **Maintenance Guide:** Understand impact of changes to any document
- **Navigation Aid:** Find related documents and dependencies quickly
- **Quality Assurance:** Validate that all cross-references remain functional

**Remember:** This map ensures the Documentation 2 system remains interconnected and functional throughout the refactoring process.
