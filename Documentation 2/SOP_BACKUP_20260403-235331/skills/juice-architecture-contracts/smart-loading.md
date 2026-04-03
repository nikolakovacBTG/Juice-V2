# Smart Documentation Loading Strategy

## 1. Enforcing "Load Only What You Need"

### Trigger-Based Loading Pattern

**Current Problem:** AI agents read everything upfront because they don't know what they'll need later.

**Solution:** Just-in-time loading with explicit triggers

```markdown
## Enhanced Skill Pattern

### @juice-architecture-contracts
**Auto-invokes:** When touching `addons/Juice_V1/`
**Initial Load:** Core contracts only (500 tokens)
**Triggers:** 
- "appearance" → Load appearance memory
- "transform" → Load transform memory  
- "stacking" → Load stacking contract
- "From/To" → Load from/to design

### Decision Points in Code
When AI encounters specific patterns:
1. **Writing _apply_effect()** → Trigger effect-specific memory load
2. **Modifying domain nodes** → Trigger stacking contract load
3. **Adding new effect** → Trigger template + layer contracts
```

### Implementation: Smart Load Triggers

```gdscript
# In skill logic:
if user_intent.contains("appearance effects"):
    load_memory("appearance_from_to_design")
    load_memory("sibling_stacking_contract")
    
if user_intent.contains("domain nodes"):
    load_memory("layer_contracts")
    load_memory("write_coordination")
    
if user_intent.contains("_apply_effect"):
    load_memory("delta_first_model")
    load_effect_specific_memory()
```

### Stop-at-Right-Moment Rules

1. **Intent Detection** - Analyze what user wants to accomplish
2. **Minimal Initial Load** - Load only core contracts (500 tokens)
3. **Progressive Loading** - Add more context as intent becomes clear
4. **Explicit Triggers** - User can specify "I need X documentation"

## 2. Documentation Fragmentation Strategy

### From Few Big Docs → Many Focused Docs

**Current Problems with Big Docs:**
1. **All-or-nothing reading** - Must read 8,000 tokens for 500 tokens of info
2. **Context switching** - Jumping between sections in large files
3. **Memory overhead** - Keeping irrelevant information in context
4. **Slow loading** - Large files take more time to process

### Proposed Fragmentation

#### Core Architecture Documents (500-800 tokens each)
```
delta-first-model.md          - Write coordination model
domain-separation.md         - Control/2D/3D boundaries
layer-contracts.md           - L1/L2/L3 responsibilities
external-move-detection.md   - Base capture logic
multi-writer-coordination.md - Sibling stacking
```

#### Effect-Specific Documents (600-1,000 tokens each)
```
appearance-from-to.md        - Appearance From/To patterns
transform-deltas.md          - Transform delta calculations
procedural-animation.md      - Noise/Shake/Spring patterns
shader-integration.md        - Material/Shader handling
```

### Smart Reassembly System

#### Document Cross-References
```markdown
## delta-first-model.md

**Related Documents:**
- multi-writer-coordination.md (for sibling stacking)
- external-move-detection.md (for base capture)
- domain-separation.md (for domain-specific writes)

**When to also load:**
- If implementing domain nodes → load domain-specifics
- If fixing stacking bugs → load multi-writer-coordination
```

#### Expected Results

| Current | Fragmented | Reduction |
|---------|------------|-----------|
| 8,000 (full design) | 500-1,000 (specific) | 87-94% |
| 12,000 (appearance) | 800 (from/to) | 93% |
| 20,000 (multiple docs) | 2,000 (relevant) | 90% |

## 3. Project Documentation MCP Analysis

### MCP vs Current Approach

#### Current Approach: Skills + Files
- **Skills:** Provide guidance and templates
- **Files:** Store documentation in markdown
- **Loading:** AI reads files directly
- **Cost:** File reading + skill invocation

#### MCP Approach: Dedicated Documentation Server
- **MCP Server:** Manages all documentation
- **Methods:** Structured doc retrieval, search, caching
- **Loading:** MCP calls instead of file reads
- **Cost:** MCP call overhead + structured data

### MCP Benefits

#### 1. Structured Query Interface
```javascript
// Instead of reading full file:
const fullDoc = read_file("JuiceStack_Design.md"); // 8,000 tokens

// MCP call:
const deltaModel = mcp.getDocumentation({
  topic: "delta-first-model",
  includeRelated: ["external-move-detection"]
}); // 1,200 tokens
```

#### 2. Intelligent Caching
- **Server-side caching** - Common queries cached
- **Version tracking** - Know when docs change
- **Dependency management** - Auto-load related docs

#### 3. Search & Discovery
```javascript
// Find all docs about "stacking":
const stackingDocs = mcp.searchDocumentation({
  query: "stacking sibling nodes",
  maxResults: 5
});
```

#### 4. Context-Aware Retrieval
```javascript
// Based on current work:
const relevantDocs = mcp.getContextualDocs({
  currentFile: "AppearanceControlJuiceEffect.gd",
  currentMethod: "_apply_effect",
  intent: "implementing from/to"
});
```

### MCP Costs

#### Implementation Overhead
- **Server code** - Need to write and maintain MCP server
- **Schema design** - Structure all documentation
- **Integration** - Update skills to use MCP

#### Runtime Overhead
- **MCP call latency** - Small overhead per call
- **Network/IPC** - Inter-process communication
- **Memory usage** - Server process memory

### Recommendation: **Smart Approach, Not Overkill**

#### Why MCP Makes Sense Here

1. **High documentation complexity** - Juice has deep architectural dependencies
2. **Frequent AI access** - AI agents constantly need documentation
3. **Token cost pressure** - Clear need to reduce reading overhead
4. **Quality requirements** - Can't sacrifice precision for speed

#### Hybrid Approach Recommendation

**Phase 1: Fragmentation + Smart Skills (Immediate)**
- Fragment big docs into focused pieces
- Enhance skills with trigger-based loading
- Implement cross-reference system

**Phase 2: MCP Layer (Later)**
- Add MCP server on top of fragmented docs
- Provides structured query interface
- Maintains all benefits of fragmentation

#### Expected Combined Benefits

| Approach | Token Reduction | Implementation Cost | Quality |
|----------|------------------|-------------------|---------|
| Current | 0% | 0 | 100% |
| Fragmentation | 90% | Low | 100% |
| Fragmentation + MCP | 95% | Medium | 105% |

### Final Recommendation

**Start with fragmentation** - 90% of benefits with 10% of effort
**Add MCP later** - Additional 5% benefits for specialized use cases

The fragmentation strategy gives you most of the token reduction immediately, with MCP providing the final optimization for complex scenarios.
