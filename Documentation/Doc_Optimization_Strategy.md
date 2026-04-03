# Documentation Reading Optimization Strategy

**Goal:** Reduce 40,000+ token documentation reading overhead while maintaining quality and precision

---

## Current Problem Analysis

### What We Read Now (40,000 tokens)
- `JuiceStack_Design.md` (8,000 tokens) - Full architecture document
- `Appearance_Architecture_Plan.md` (12,000 tokens) - Complete phase plan
- Current implementation files (12,000 tokens) - All domain effects
- Port tracker and related files (8,000 tokens) - Status and context

### Why This Is Expensive
- **Full document scans** - We read entire documents when we only need specific sections
- **Repeated reads** - Same documents read for every effect change
- **No caching** - No persistent memory of architectural decisions
- **Context switching** - Jumping between multiple large documents

---

## Optimization Strategy: "Just-In-Time Architecture"

### 1. Pre-Computed Architecture Memory

#### Create "Architecture Nuggets" (Memory Entries)
Instead of reading full docs, create focused memory entries:

**Memory: `appearance_from_to_design`**
```
## Appearance Effects From/To Design

**Pattern:** From/To lives in concrete classes only
**Infrastructure:** 
- enum AppearanceReference { CUSTOM, SELF }
- enum CaptureAt { TRIGGER, READY, IN_EDITOR }
- Per-effect: from_* and to_* fields

**Domain Differences:**
- Control: writes to self_modulate, captures self_modulate
- 2D/3D: writes to modulate, captures modulate
- 3D Outline: uses overlay_3d.gdshader via next_pass

**Key Rule:** Never use absolute writes - always delta-first
```

**Memory: `sibling_stacking_contract`**
```
## Sibling Stacking Contract

**Problem:** Multiple Juice nodes overwrite each other's modulate

**Solution:** Per-node contribution tracking
- Each node: _own_modulate_contribution
- Natural base stored in metadata (except Control = WHITE)
- Sibling rescan: multiply all contributions
- Write: base * product_of_contributions

**Domain Variations:**
- Control: target.self_modulate = product (no base)
- 2D/3D: target.modulate = base * product
```

#### Token Cost: ~2,000 tokens vs 20,000 tokens (90% reduction)

### 2. Smart Document Sectioning

#### Tag Document Sections for Quick Retrieval
Instead of full documents, tag specific sections:

**In `JuiceStack_Design.md`:**
```markdown
<!-- TAG: delta-first-model -->
## Delta-First Write Model
...section content...
<!-- END-TAG -->

<!-- TAG: domain-separation -->
## Domain Separation Rules
...section content...
<!-- END-TAG -->
```

**AI Tool:** `grep_search` with specific tags instead of reading full file

#### Token Cost: ~1,000 tokens vs 8,000 tokens (87.5% reduction)

### 3. Context-Aware Skill Enhancement

#### Enhance `@juice-architecture-contracts`
Add "Quick Load" functionality:

```markdown
## Quick Load Patterns

### For Appearance Changes:
- Load memory: appearance_from_to_design
- Load memory: sibling_stacking_contract
- Read: current effect files only

### For Transform Changes:
- Load memory: transform_delta_contract
- Read: domain node write coordination

### For New Effects:
- Load memory: layer_contracts
- Read: template files only
```

#### Token Cost: ~3,000 tokens vs 40,000 tokens (92.5% reduction)

### 4. Incremental Context Building

#### "Context Stack" Pattern
Build context incrementally, not all at once:

**Level 1: Core Contracts** (500 tokens)
- Layer contracts
- Delta-first model
- Domain separation

**Level 2: Effect-Specific** (1,000 tokens)
- Load only if working on specific effect type
- Appearance, Transform, Noise, etc.

**Level 3: Implementation Details** (1,500 tokens)
- Current implementation files
- Only read files being modified

#### Token Cost: ~3,000 tokens vs 40,000 tokens (92.5% reduction)

---

## Implementation Plan

### Phase 1: Memory Architecture (1 hour)

1. **Create 10-15 focused memory entries** covering:
   - Layer contracts
   - Delta-first model
   - Domain separation rules
   - Effect-specific patterns
   - Common anti-patterns

2. **Tag existing documents** with section markers
   - Add <!-- TAG: name --> markers to key sections
   - Update grep_search patterns

### Phase 2: Skill Enhancement (30 minutes)

1. **Update `@juice-architecture-contracts`** with:
   - Quick Load patterns
   - Context stack logic
   - Smart document retrieval

2. **Update `@juice-architecture`** with:
   - Memory-first approach
   - Section-based reading

### Phase 3: Workflow Integration (30 minutes)

1. **Update `/port` workflow** to use:
   - Memory loading instead of full doc reads
   - Section-based retrieval

2. **Update `/review` workflow** to use:
   - Context stack building
   - Targeted verification

---

## Quality Assurance Strategy

### 1. Memory Validation
- **Memory checksums** - Verify memory entries are up-to-date
- **Cross-reference checks** - Ensure memory matches source docs
- **Version tracking** - Mark memory entries with doc versions

### 2. Fallback Mechanism
- **Full doc read on failure** - If memory missing, read full docs
- **Discrepancy detection** - Alert if memory differs from docs
- **Manual override** - Option to read full docs when needed

### 3. Precision Maintenance
- **Source citations** - Memory entries cite source document sections
- **Update propagation** - When docs change, update related memories
- **Regular audits** - Weekly memory vs source verification

---

## Expected Results

### Token Reduction
| Current | Optimized | Reduction |
|---------|-----------|-----------|
| 40,000 tokens | 3,000 tokens | 92.5% |
| 55 seconds | 8 seconds | 85% |

### Quality Maintenance
- **Precision:** Memory entries focus on critical decisions only
- **Accuracy:** Regular validation against source docs
- **Completeness:** Fallback to full docs when needed

### Developer Experience
- **Faster startup:** 8 seconds vs 55 seconds
- **Focused context:** Only relevant information loaded
- **Consistent quality:** Same architectural decisions enforced

---

## Risk Mitigation

### Risks
1. **Memory staleness** - Memory becomes outdated
2. **Missing context** - Memory misses edge cases
3. **Over-optimization** - Critical details lost

### Mitigations
1. **Automated validation** - Weekly memory vs source checks
2. **Fallback mechanism** - Auto-read full docs on uncertainty
3. **Conservative approach** - Keep full docs as safety net

---

## Success Metrics

1. **Token reduction:** Target 85%+ reduction in doc reading
2. **Time savings:** Target 80%+ reduction in setup time
3. **Quality maintenance:** Zero regression in architectural compliance
4. **Developer satisfaction:** Faster workflow without precision loss
