## L1 Layer Contracts

**Purpose:** Define the architectural boundaries and responsibilities between L1 core infrastructure, L2 domain coordination, and L3 effect implementation.

**Mission:** Establish clear contracts that prevent architectural violations while enabling flexible domain-specific implementations.

**Vision:** Create a layered architecture where each layer has well-defined responsibilities and predictable interactions with other layers.

---

# ============================================================================
# WHAT: Layer boundary definitions and architectural contracts for Juice V1
# EXPECTS: L2 domain nodes to implement core contracts and L3 effects to honor interface boundaries
# PROVIDES: Architectural contract definitions and validation criteria to all layers
# ARCHITECTURE: L1 core infrastructure that defines the rules all layers must follow
# ============================================================================

## Layer Responsibility Contracts

### L1 Core Infrastructure Responsibilities
**What L1 Provides:**
- Unified interfaces and base classes
- Timing infrastructure and animation lifecycle
- Recipe management and effect resource patterns
- Mathematical foundations (delta-first model)
- Architectural contracts and validation rules

**What L1 Never Does:**
- Handle domain-specific logic (Control/2D/3D)
- Implement effect-specific mathematics
- Access target nodes directly
- Write to target properties
- Coordinate between multiple effects

### L2 Domain Coordination Responsibilities
**What L2 Provides:**
- Domain-specific target validation and filtering
- Per-frame write coordination and aggregation
- Sibling stacking logic and contribution tracking
- External-move detection and base value recapture
- Domain-specific challenges and solutions

**What L2 Never Does:**
- Implement effect-specific mathematical calculations
- Access other domains' target types
- Define core architectural contracts
- Handle timing infrastructure (uses L1)
- Implement effect resources (uses L3)

### L3 Effect Implementation Responsibilities
**What L3 Provides:**
- Effect-specific mathematical calculations
- Domain-appropriate delta computations
- From/To reference resolution and capture
- Effect state management and progression
- Concrete effect implementations

**What L3 Never Does:**
- Write directly to target nodes
- Coordinate with other effects
- Handle domain-specific write coordination
- Define architectural boundaries
- Manage timing infrastructure (uses L1)

---

## Interface Contracts

### L1 → L2 Interface Contract
```gdscript
# L1 provides these interfaces that L2 must implement:

# Base Node Interface
class JuiceBase:
    # Lifecycle management
    func _ready() -> void                    # Base setup
    func _process(delta: float) -> void     # Frame timing
    func _exit_tree() -> void                # Cleanup
    
    # Animation control
    func animate_in() -> void                # Start animation
    func animate_out() -> void               # Reverse animation
    func stop() -> void                      # Stop and reset
    
    # Recipe management
    func set_recipe(recipe: JuiceRecipe) -> void
    func get_recipe() -> JuiceRecipe
    
    # State queries
    func is_playing() -> bool
    func is_stopped() -> bool

# Effect Resource Interface
class JuiceEffectBase:
    # Delta calculation (core contract)
    func _apply_effect(progress: float) -> Dictionary
    
    # Stacking support
    func _get_seq_contribution() -> Dictionary
    
    # Lifecycle hooks
    func _on_animate_start() -> void
    func _on_animate_stop() -> void
```

### L2 Implementation Requirements
```gdscript
# L2 must implement these contracts for each domain:

class Juice[Domain] extends JuiceBase:
    # Domain-specific target validation
    func _validate_target() -> bool
    
    # Base value capture
    func _capture_natural_base() -> void
    
    # External move detection
    func _detect_external_move() -> bool
    
    # Write coordination
    func _post_tick_write_target() -> void
    
    # Sibling stacking
    func _aggregate_effect_deltas() -> Dictionary
```

### L2 → L3 Guarantee Contract
```gdscript
# L2 provides these guarantees to L3 effects:

class Juice[Domain] extends JuiceBase:
    # Target environment guarantees
    var target: [Domain]                    # Valid domain target
    var _natural_base: Dictionary          # Captured before effects
    var _external_moves_handled: bool       # External moves detected
    
    # Write coordination guarantees
    # Single write per property per frame
    # Delta aggregation completed before write
    # External moves handled before effect processing
    
    # Timing guarantees
    # Progress values are 0.0 to 1.0
    # Frame delta is accurate and consistent
    # Animation lifecycle events fire correctly
```

### L3 Effect Requirements
```gdscript
# L3 must honor these contracts:

class [Effect][Domain]JuiceEffect extends Juice[Domain]EffectBase:
    # Delta calculation only (no side effects)
    func _get_seq_contribution() -> Dictionary
    
    # Reference capture at animation start
    func _capture_references() -> void
    
    # Domain-specific math only
    func _calculate_domain_delta(progress: float) -> Variant
    
    # No direct target access
    # No coordination with other effects
    # No write operations
```

---

## Data Flow Contracts

### Animation Start Data Flow
```
1. L2 Domain Node captures natural base values
2. L2 Domain Node validates target and environment
3. L2 Domain Node enables effect processing
4. L3 Effects capture From/To references
5. L3 Effects calculate initial deltas
6. L2 Domain Node aggregates and writes first frame
```

### Per-Frame Processing Data Flow
```
1. L1 Base provides _process(delta) timing
2. L2 Domain Node detects external moves
3. L2 Domain Node updates base values if needed
4. L3 Effects calculate current frame deltas
5. L2 Domain Node aggregates all effect deltas
6. L2 Domain Node writes final values once per property
```

### Animation End Data Flow
```
1. L2 Domain Node stops effect processing
2. L2 Domain Node restores natural values
3. L2 Domain Node clears effect contributions
4. L3 Effects reset internal state
5. L1 Base handles cleanup and finalization
```

---

## Property Access Contracts

### L1 Property Access Rules
**Allowed:**
- Manage recipe and timing state
- Provide interface definitions
- Handle base class initialization
- Coordinate animation lifecycle

**Forbidden:**
- Access target nodes directly
- Read/write target properties
- Implement domain-specific logic
- Coordinate between effects

### L2 Property Access Rules
**Allowed:**
- Read domain-specific target properties
- Write target properties once per frame per property
- Detect external property changes
- Aggregate effect contributions

**Forbidden:**
- Access other domains' target types
- Write target properties multiple times per frame
- Implement effect-specific calculations
- Define core architectural contracts

### L3 Property Access Rules
**Allowed:**
- Calculate mathematical deltas
- Use captured reference values
- Manage effect internal state
- Provide domain-specific implementations

**Forbidden:**
- Access target nodes directly
- Read/write target properties
- Coordinate with other effects
- Handle timing infrastructure

---

## Validation Contracts

### L1 Compliance Validation
```gdscript
# L1 must validate:
- [ ] No domain-specific implementation details
- [ ] Clear interface definitions provided
- [ ] Theoretical foundation is sound
- [ ] Contract boundaries are well-defined
- [ ] Cross-layer dependencies are specified
```

### L2 Compliance Validation
```gdscript
# L2 must validate:
- [ ] Single target type only
- [ ] Single write per property per frame
- [ ] External-move detection implemented
- [ ] Sibling stacking coordination provided
- [ ] L1 contracts properly implemented
```

### L3 Compliance Validation
```gdscript
# L3 must validate:
- [ ] Delta calculation only
- [ ] No direct target manipulation
- [ ] Proper domain-specific math
- [ ] Consistent contribution reporting
- [ ] L2 contracts honored
```

---

## Error Handling Contracts

### L1 Error Handling Responsibilities
- Validate recipe structure before processing
- Provide clear error messages for invalid configurations
- Fail gracefully when resources are missing
- Never crash due to user configuration errors

### L2 Error Handling Responsibilities
- Validate target node type before processing
- Handle missing targets gracefully
- Recover from external move detection errors
- Provide domain-specific error context

### L3 Error Handling Responsibilities
- Validate effect parameters before calculation
- Handle mathematical edge cases (division by zero, etc.)
- Return zero deltas for invalid states
- Never cause target manipulation errors

---

## Performance Contracts

### L1 Performance Requirements
- Minimal per-frame overhead for timing management
- Efficient recipe iteration and effect activation
- Low memory footprint for base classes
- Fast signal handling and trigger processing

### L2 Performance Requirements
- Single write per property per frame maximum
- Efficient delta aggregation across multiple effects
- Fast external-move detection with minimal overhead
- Optimized base value capture and restoration

### L3 Performance Requirements
- Fast delta calculations with minimal allocations
- Efficient mathematical operations for effect patterns
- Low memory usage for effect state
- Optimized reference resolution for From/To patterns

---

## Cross-Reference Contracts

### Required Cross-References
**L1 Documents Must Reference:**
- L1-delta-first-model.md (mathematical foundation)
- L1-3_CONTRACT_MATRIX.md (complete contracts)
- ARCHITECTURE_BIG_PICTURE.md (system context)

**L2 Documents Must Reference:**
- L1-layer-contracts.md (layer boundaries)
- L1-delta-first-model.md (mathematical foundation)
- L2-sibling-stacking.md (coordination patterns)

**L3 Documents Must Reference:**
- L2-domain-separation.md (domain specifics)
- L1-base-interfaces.md (interface contracts)
- L1-timing-system.md (timing integration)

### Cross-Reference Validation
- [ ] All referenced documents exist
- [ ] Relative paths are correct
- [ ] Bidirectional references where appropriate
- [ ] No circular dependency chains

---

## This Document's Role

### During Implementation
- **Contract Reference:** Check that new code follows layer boundaries
- **Validation Source:** Ensure architectural contracts are honored
- **Error Prevention:** Catch contract violations before they cause bugs

### During Refactoring
- **Boundary Protection:** Prevent layer boundary violations during changes
- **Consistency Check:** Ensure all implementations follow same contracts
- **Quality Assurance:** Validate that refactoring maintains architectural integrity

### For Developers
- **Layer Understanding:** Clear definition of what each layer should and should not do
- **Implementation Guidance:** Specific contracts to honor when implementing
- **Validation Criteria:** Clear checklist for compliance verification

---

## Cross-References

**Foundational Documents:**
- See L1-3_CONTRACT_MATRIX.md for complete contract matrix
- See ARCHITECTURE_BIG_PICTURE.md for system-wide context

**Implementation Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-base-interfaces.md for interface definitions
- See L1-timing-system.md for timing infrastructure

**Domain Documents:**
- See L2-domain-separation.md for domain-specific implementations
- See L3 effect documents for concrete examples

**Validation Documents:**
- See VALIDATION_STANDARDS.md for quality requirements
- See RULE-architecture-contracts.md for enforcement methods

These contracts form the foundation of Juice V1's layered architecture. Violating them breaks the architectural integrity and compromises the entire system.
