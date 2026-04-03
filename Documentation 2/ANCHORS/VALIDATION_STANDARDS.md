# Validation Standards

**Purpose:** Quality criteria and validation requirements for all Documentation 2 content. Immutable reference for maintaining quality during refactoring.

---

## Document Quality Standards

### Content Quality Requirements

#### L1 Documents (Core Architecture)
**Token Count:** 500-800 tokens per document
**Validation Criteria:**
- [ ] Content is domain-agnostic (no Control/2D/3D specifics)
- [ ] Defines clear interfaces and contracts
- [ ] Provides theoretical foundation for L2/L3
- [ ] Includes concrete examples with class names
- [ ] Cross-references to related L1 documents

**Structure Requirements:**
```
## Header (with EXPECTS/PROVIDES/ARCHITECTURE)
## Core Concept Definition
## Interface Contracts
## Implementation Guidelines
## Cross-References
## Examples (with actual class names)
```

#### L2 Documents (Domain Coordination)
**Token Count:** 400-600 tokens per document
**Validation Criteria:**
- [ ] Content is domain-specific (Control/2D/3D)
- [ ] References L1 contracts and interfaces
- [ ] Provides implementation patterns for L3
- [ ] Includes domain-specific challenges and solutions
- [ ] Cross-references to L1 foundations and L3 effects

**Structure Requirements:**
```
## Header (with EXPECTS/PROVIDES/ARCHITECTURE)
## Domain-Specific Challenges
## L1 Contract Implementation
## L3 Effect Coordination
## Performance Considerations
## Cross-References
## Domain-Specific Examples
```

#### L3 Documents (Effect Implementation)
**Token Count:** 600-1,000 tokens per document
**Validation Criteria:**
- [ ] Content is effect-specific with domain variants
- [ ] References L2 coordination patterns
- [ ] Provides mathematical patterns and algorithms
- [ ] Includes specific method and property references
- [ ] Cross-references to L2 coordination and L1 foundations

**Structure Requirements:**
```
## Header (with EXPECTS/PROVIDES/ARCHITECTURE)
## Effect Category Definition
## Mathematical Foundation
## Domain-Specific Implementation
## Method and Property References
## Performance Considerations
## Cross-References
## Concrete Examples
```

#### Rules Documents
**Token Count:** 300-500 tokens per document
**Validation Criteria:**
- [ ] Content is prescriptive with clear do/don't rules
- [ ] References relevant L1-3 contracts
- [ ] Includes concrete examples with class names
- [ ] Provides validation checklists
- [ ] Cross-references to related rules and contracts

**Structure Requirements:**
```
## Header (with EXPECTS/PROVIDES/ARCHITECTURE)
## Rule Definition and Rationale
## Applicability Scope
## Implementation Requirements
## Validation Checklist
## Examples (Good vs Bad)
## Cross-References
## Enforcement Methods
```

#### Memory Documents
**Token Count:** 400-700 tokens per document
**Validation Criteria:**
- [ ] Content is historical/contextual with current relevance
- [ ] References relevant L1-3 architecture
- [ ] Includes specific examples and lessons learned
- [ ] Provides actionable guidance for current development
- [ ] Cross-references to related architecture and rules

**Structure Requirements:**
```
## Header (with EXPECTS/PROVIDES/ARCHITECTURE)
## Historical Context
## Lessons Learned
## Current Relevance
## Actionable Guidance
## Cross-References
## Examples
```

---

## Header Format Standards

### Mandatory Header Structure
```gdscript
## [Document Title]

**Purpose:** [Single sentence describing document's role]

**Mission:** [Single sentence describing document's contribution to overall mission]

**Vision:** [Single sentence describing how document enables the vision]

---

## Header (with EXPECTS/PROVIDES/ARCHITECTURE format)

# ============================================================================
# WHAT: [What this document provides - single line]
# EXPECTS: [What this document expects from other components - specific classes/systems]
# PROVIDES: [What this document provides to other components - specific classes/systems]
# ARCHITECTURE: [L1-3 position and relationship to other layers]
# ============================================================================
```

### Header Validation Checklist
- [ ] Uses `#` not `##` for section dividers
- [ ] Includes WHAT, EXPECTS, PROVIDES, ARCHITECTURE sections
- [ ] EXPECTS mentions specific classes or systems
- [ ] PROVIDES mentions specific classes or systems
- [ ] ARCHITECTURE specifies L1-3 position
- [ ] All sections are concrete and actionable

---

## Cross-Reference Standards

### Cross-Reference Requirements
- [ ] All referenced documents exist in Documentation 2/
- [ ] Relative paths use correct Documentation 2/ structure
- [ ] Anchor names are descriptive and consistent
- [ ] Cross-references are bidirectional (if A references B, B should reference A)
- [ ] No circular dependencies in cross-references

### Cross-Reference Format
```markdown
See [Document Name](relative/path/to/document.md) for [specific topic]
See L1-layer-contracts.md for contract definitions
See L2-sibling-stacking.md for implementation patterns
```

### Cross-Reference Validation
- [ ] All internal links resolve to existing documents
- [ ] All external links are accessible and relevant
- [ ] All skill/workflow references point to existing files
- [ ] All dependency chains are complete

---

## Token Count Standards

### Token Measurement Method
- Use consistent token counting tool
- Measure actual content only (exclude markdown formatting)
- Include code examples in token count
- Document token count in REFACTOR_PROGRESS.md

### Token Count Validation
| Document Type | Target Range | Acceptable Range |
|---------------|--------------|------------------|
| L1 Documents | 500-800 | 400-900 |
| L2 Documents | 400-600 | 300-700 |
| L3 Documents | 600-1,000 | 500-1,200 |
| Rules Documents | 300-500 | 200-600 |
| Memory Documents | 400-700 | 300-800 |

### Token Count Optimization
- [ ] Remove redundant content
- [ ] Consolidate similar examples
- [ ] Use concise language
- [ ] Optimize code examples
- [ ] Remove verbose explanations

---

## Architectural Compliance Standards

### L1 Compliance Validation
- [ ] No domain-specific implementation details
- [ ] Clear interface definitions
- [ ] Theoretical foundation provided
- [ ] Contract boundaries defined
- [ ] Cross-layer dependencies specified

### L2 Compliance Validation
- [ ] Single domain focus only
- [ ] L1 contracts properly implemented
- [ ] L3 coordination patterns defined
- [ ] Domain-specific challenges addressed
- [ ] Performance considerations included

### L3 Compliance Validation
- [ ] Effect-specific implementation
- [ ] L2 coordination patterns honored
- [ ] Mathematical foundations sound
- [ ] Domain-specific variants provided
- [ ] Method/property references accurate

### Rules Compliance Validation
- [ ] Clear prescriptive guidance
- [ ] Concrete examples provided
- [ ] Validation checklists included
- [ ] Enforcement methods defined
- [ ] Cross-references to architecture

---

## Integration Standards

### Skill Integration Validation
- [ ] All documents referenced by @juice-architecture skill
- [ ] Auto-invocation triggers correctly specified
- [ ] Skill content aligns with documentation
- [ ] No circular dependencies between skill and docs

### Workflow Integration Validation
- [ ] All documents referenced by workflows
- [ ] Workflow steps align with documentation content
- [ ] Cross-workflow dependencies are minimal
- [ ] Base workflow (/architecture) properly extended

### Memory Integration Validation
- [ ] Critical system memories extracted to Documentation 2/
- [ ] Memory content aligns with current architecture
- [ ] Memory references integrated throughout docs
- [ ] Version control visibility achieved

---

## Quality Assurance Process

### Document Creation Validation
1. **Content Review:** Verify content meets quality standards
2. **Header Validation:** Check header format compliance
3. **Cross-Reference Check:** Validate all links and dependencies
4. **Token Count Verification:** Measure and document token count
5. **Architectural Compliance:** Ensure L1-3 contract adherence
6. **Integration Test:** Verify skill/workflow integration

### Phase Completion Validation
1. **All Documents Created:** Verify checklist completion
2. **Cross-Reference Integrity:** Check all links system-wide
3. **Token Reduction Achieved:** Verify 90% reduction target
4. **Architectural Integrity:** Ensure no contract violations
5. **Integration Functionality:** Test skills and workflows
6. **Human Review:** Final quality approval

### System-Wide Validation
1. **Documentation Completeness:** All required documents exist
2. **Cross-Reference Consistency:** No broken links anywhere
3. **Token Optimization:** System-wide token targets met
4. **Architectural Coherence:** All documents align with contracts
5. **Integration Success:** Skills and workflows function correctly
6. **User Experience:** Navigation and usability validated

---

## Error Handling Standards

### Validation Error Categories
**Critical Errors:** Must fix before proceeding
- Broken cross-references
- Contract violations
- Missing mandatory content
- Integration failures

**Warning Errors:** Should fix but can proceed
- Token count over target
- Minor formatting issues
- Incomplete examples
- Suboptimal cross-references

**Informational Notes:** Nice to fix but not required
- Style improvements
- Additional examples
- Enhanced descriptions
- Better organization

### Error Resolution Process
1. **Identify Error Category:** Critical, Warning, or Informational
2. **Document Error:** Record in REFACTOR_PROGRESS.md
3. **Fix Error:** Implement correction
4. **Validate Fix:** Re-run validation
5. **Update Progress:** Mark resolution in tracking

---

## This Document's Role

### During Implementation
- **Quality Reference:** Ensure all documents meet standards
- **Validation Guide:** Step-by-step validation process
- **Error Handling:** Systematic approach to fixing issues

### During Review
- **Quality Checklist:** Comprehensive validation criteria
- **Integration Test:** Verify system-wide functionality
- **Final Approval:** Sign-off requirements for completion

### For Maintenance
- **Quality Baseline:** Standards for future updates
- **Validation Process:** Ongoing quality assurance
- **Improvement Guide:** Continuous enhancement criteria

**Remember:** These standards ensure the Documentation 2 system achieves its mission of 90% token reduction while maintaining architectural integrity and improving developer experience.
