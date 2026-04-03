# SOP Token Cost Analysis - Appearance Effect Refactor

**Scenario:** Complete refactor of Appearance effects according to established SOPs  
**Based on:** Appearance_Architecture_Plan.md (Phases A-C)  
**Goal:** Identify token costs per SOP step to optimize our processes

---

## Step-by-Step Procedure with Token Estimates

### 1. Initial Skill Invocation (Auto)
**Trigger:** Touching `addons/Juice_V1/` files

**Skills invoked:**
- `@juice-architecture` (~3,000 tokens)
- `@juice-architecture-contracts` (~500 tokens)

**Cost:** ~3,500 tokens  
**Time:** 5 seconds

---

### 2. Architecture Review Phase

#### 2a. Read Design Documentation
**Files read:**
- `Documentation/JuiceStack_Design.md` (~8,000 tokens)
- `Documentation/Appearance_Architecture_Plan.md` (~12,000 tokens)

**Cost:** ~20,000 tokens  
**Time:** 30 seconds

#### 2b. Read Current Implementation
**Files read (parallel):**
- `addons/Juice_V1/Control/AppearanceControlJuiceEffect.gd` (~4,000 tokens)
- `addons/Juice_V1/2D/Appearance2DJuiceEffect.gd` (~4,000 tokens)
- `addons/Juice_V1/3D/Appearance3DJuiceEffect.gd` (~4,000 tokens)

**Cost:** ~12,000 tokens  
**Time:** 15 seconds

#### 2c. Read Port Status & Related Files
**Files read:**
- `Documentation/Port_Master_Tracker.md` (~2,000 tokens)
- Domain node files for stacking behavior (~6,000 tokens total)

**Cost:** ~8,000 tokens  
**Time:** 10 seconds

**Subtotal Phase 2:** ~40,000 tokens, ~55 seconds

---

### 3. Planning Phase

#### 3a. Create Implementation Plan
Based on architecture plan, break down:
- Phase A: From/To API implementation
- Phase B: Sibling stacking fix
- Phase C: Flicker redesign

**Cost:** ~2,000 tokens (internal reasoning)  
**Time:** 20 seconds

#### 3b. Update TODO/Progress Tracking
**Files updated:**
- Create/update TODO.md with phases
- Memory updates for current state

**Cost:** ~1,000 tokens  
**Time:** 10 seconds

**Subtotal Phase 3:** ~3,000 tokens, ~30 seconds

---

### 4. Implementation Phase A - From/To API

#### 4a. Add From/To Infrastructure (Control)
**File:** `addons/Juice_V1/Control/AppearanceControlJuiceEffect.gd`
- Add enums and reference variables
- Implement _get_property_list() updates
- Add capture logic

**Cost:** ~3,000 tokens (reading + writing)  
**Time:** 45 seconds

#### 4b. Add From/To Infrastructure (2D)
**File:** `addons/Juice_V1/2D/Appearance2DJuiceEffect.gd`
- Same pattern as Control

**Cost:** ~3,000 tokens  
**Time:** 45 seconds

#### 4c. Add From/To Infrastructure (3D)
**File:** `addons/Juice_V1/3D/Appearance3DJuiceEffect.gd`
- Same pattern + 3D-specific outline via next_pass

**Cost:** ~4,000 tokens (more complex)  
**Time:** 60 seconds

#### 4d. Refactor _apply_effect() Methods
All three domains:
- Replace flat lerp with from/to resolution
- Add _resolve_from_*() and _resolve_to_*() methods

**Cost:** ~6,000 tokens  
**Time:** 90 seconds

**Subtotal Phase 4:** ~16,000 tokens, ~4 minutes

---

### 5. Implementation Phase B - Sibling Stacking

#### 5a. Update Domain Nodes (Control)
**File:** `addons/Juice_V1/Control/JuiceControl.gd`
- Remove _base_modulate
- Add _own_modulate_contribution
- Implement sibling rescan logic

**Cost:** ~4,000 tokens  
**Time:** 60 seconds

#### 5b. Update Domain Nodes (2D)
**File:** `addons/Juice_V1/2D/Juice2D.gd`
- Same pattern with metadata base capture

**Cost:** ~4,000 tokens  
**Time:** 60 seconds

#### 5c. Update Domain Nodes (3D)
**File:** `addons/Juice_V1/3D/Juice3D.gd`
- Same pattern for albedo/alpha

**Cost:** ~4,000 tokens  
**Time:** 60 seconds

**Subtotal Phase 5:** ~12,000 tokens, ~3 minutes

---

### 6. Implementation Phase C - Flicker Redesign

#### 6a. Remove _get_effective_progress()
All three appearance effect files

**Cost:** ~2,000 tokens  
**Time:** 30 seconds

#### 6b. Add _compute_flicker_multiplier()
Add to all three concrete classes

**Cost:** ~3,000 tokens  
**Time:** 45 seconds

#### 6c. Update _apply_effect() with Flicker
Integrate flicker into all effect types

**Cost:** ~5,000 tokens  
**Time:** 75 seconds

**Subtotal Phase 6:** ~10,000 tokens, ~2.5 minutes

---

### 7. Test Suite Updates

#### 7a. Review Existing Tests
**Files read:**
- `tests/suites/TestAppearanceControl.gd`
- `tests/suites/TestAppearance2D.gd`
- `tests/suites/TestAppearance3D.gd`

**Cost:** ~6,000 tokens  
**Time:** 45 seconds

#### 7b. Add New Tests
- From/To behavior tests
- Sibling stacking tests
- Flicker behavior tests

**Cost:** ~8,000 tokens (writing)  
**Time:** 120 seconds

**Subtotal Phase 7:** ~14,000 tokens, ~2.75 minutes

---

### 8. Verification Phase

#### 8a. Run Test Suite
**Command:** `/test` workflow
- Execute full test suite
- Analyze results

**Cost:** ~2,000 tokens  
**Time:** 60 seconds (test execution)

#### 8b. Fix Any Failures
If tests fail, iterate with `/bugfix` workflow

**Cost:** ~5,000 tokens (estimated)  
**Time:** 90 seconds

#### 8c. Final Verification
Invoke `@verify-claims` before completion

**Cost:** ~1,000 tokens  
**Time:** 15 seconds

**Subtotal Phase 8:** ~8,000 tokens, ~2.75 minutes

---

### 9. Documentation & Commits

#### 9a. Update Documentation
- Update Port_Master_Tracker.md
- Update any relevant design docs

**Cost:** ~2,000 tokens  
**Time:** 30 seconds

#### 9b. Git Commit
Commit all changes with descriptive message

**Cost:** ~500 tokens  
**Time:** 15 seconds

**Subtotal Phase 9:** ~2,500 tokens, ~45 seconds

---

## Token Cost Summary

| Phase | Tokens | Time | % of Total |
|-------|--------|------|-----------|
| 1. Skill Invocation | 3,500 | 5s | 2.4% |
| 2. Architecture Review | 40,000 | 55s | 27.6% |
| 3. Planning | 3,000 | 30s | 2.1% |
| 4. Phase A - From/To | 16,000 | 4m | 11.0% |
| 5. Phase B - Stacking | 12,000 | 3m | 8.3% |
| 6. Phase C - Flicker | 10,000 | 2.5m | 6.9% |
| 7. Test Suite | 14,000 | 2.75m | 9.6% |
| 8. Verification | 8,000 | 2.75m | 5.5% |
| 9. Documentation | 2,500 | 45s | 1.7% |
| **TOTAL** | **109,000** | **19.5m** | **100%** |

---

## Key Findings

### Most Expensive Steps
1. **Architecture Review (27.6%)** - Reading design docs and current implementation
2. **Phase A - From/To API (11.0%)** - Core infrastructure changes
3. **Test Suite (9.6%)** - Comprehensive test coverage

### Optimization Opportunities

#### 1. Reduce Documentation Reading Overhead
**Current:** Read full design docs every time  
**Proposal:** Cache key architectural decisions in memory  
**Savings:** ~15,000 tokens (13.8%)

#### 2. Parallelize Implementation
**Current:** Sequential domain-by-domain changes  
**Proposal:** Batch similar changes across domains  
**Savings:** ~8,000 tokens (7.3%)

#### 3. Lean Test Strategy
**Current:** Full test suite for every change  
**Proposal:** Targeted tests + smoke test  
**Savings:** ~6,000 tokens (5.5%)

#### 4. Smarter Skill Invocation
**Current:** Both skills fire on any file touch  
**Proposal:** Context-aware skill selection  
**Savings:** ~2,000 tokens (1.8%)

### Recommended SOP Improvements

1. **Pre-Load Architecture Memory** - Cache design decisions before starting
2. **Domain-Batching Workflow** - Change all 3 domains in parallel
3. **Incremental Testing** - Test per phase, not just at end
4. **Selective Skill Invocation** - Choose skills based on task type

**Potential Total Savings:** ~31,000 tokens (28.5%)  
**New Estimated Total:** ~78,000 tokens (14 minutes)
