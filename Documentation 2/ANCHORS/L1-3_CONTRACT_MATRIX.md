# L1-3 Contract Matrix

**Purpose:** Complete mapping of all layer contracts, boundaries, and responsibilities. Immutable reference for validation during refactoring.

---

## Layer Responsibility Matrix

| Responsibility | L1 Core | L2 Domain | L3 Effect |
|----------------|---------|-----------|-----------|
| **Target Type Handling** | ❌ Never handles targets | ✅ Handles one target type only | ✅ Knows its target type |
| **Effect Math Implementation** | ❌ Never implements effects | ❌ Never implements effect logic | ✅ Implements specific effect math |
| **Writing to Targets** | ❌ Never writes to targets | ✅ Writes once per frame per property | ❌ Never writes to targets |
| **Delta Calculation** | ❌ Never calculates deltas | ❌ Never calculates deltas | ✅ Calculates deltas only |
| **Base Value Capture** | ❌ Never captures values | ✅ Captures natural base values | ✅ Captures From/To references |
| **Timing Management** | ✅ Provides timing infrastructure | ✅ Manages per-frame timing | ✅ Uses timing for calculations |
| **Recipe Management** | ✅ Provides recipe base classes | ✅ Manages recipe execution | ✅ Stored in recipes as resources |
| **Domain Knowledge** | ❌ Domain-agnostic | ✅ Domain-specific knowledge | ✅ Domain-specific implementation |
| **Cross-Effect Coordination** | ❌ No coordination needed | ✅ Coordinates multiple effects | ❌ No coordination with other effects |
| **External-Move Detection** | ❌ No detection needed | ✅ Detects external target changes | ❌ No detection needed |

---

## Contract Boundaries

### L1 → L2 Contract (Core Provides to Domain)
```gdscript
# L1 provides these interfaces that L2 must implement:
class JuiceBase:
    # Recipe and timing management
    func _ready() # Base setup
    func _process(delta) # Frame timing
    func animate_in() # Trigger interface
    func stop() # Cleanup interface
    
class JuiceEffectBase:
    # Effect resource interface
    func _apply_effect(progress: float) -> Dictionary # Delta calculation
    func _get_seq_contribution() -> Dictionary # Stacking support

# L2 must honor these contracts:
class JuiceControl extends JuiceBase:
    # Must implement domain-specific target validation
    # Must implement per-frame write coordination
    # Must implement sibling stacking logic
    # Must implement external-move detection
```

### L2 → L3 Contract (Domain Provides to Effects)
```gdscript
# L2 provides these guarantees to L3:
class JuiceControl:
    # Target will be valid Control node
    # Base values captured before effects start
    # External moves detected and handled
    # Deltas aggregated correctly
    # Single write per property per frame
    
    # L3 must honor these contracts:
    # Effect extends JuiceControlEffectBase
    # Effect calculates deltas only
    # Effect has no side effects
    # Effect reports contribution accurately
```

### L3 → L2 Contract (Effect Provides to Domain)
```gdscript
# L3 effect must provide:
class TransformControlJuiceEffect extends JuiceControlEffectBase:
    # Delta calculation only
    func _get_seq_contribution() -> Dictionary:
        return {"position": calculated_delta}
    
    # No direct target manipulation
    # No side effects beyond calculation
    # Consistent mathematical behavior
```

---

## Data Flow Contracts

### Animation Start Flow
```
1. L2 Domain Node captures natural base values
2. L2 Domain Node captures effect From/To references
3. L2 Domain Node enables effect processing
4. L3 Effects calculate initial deltas
5. L2 Domain Node aggregates and writes first frame
```

### Per-Frame Processing Flow
```
1. L2 Domain Node detects external moves (if any)
2. L2 Domain Node updates base values if needed
3. L3 Effects calculate current frame deltas
4. L2 Domain Node aggregates all effect deltas
5. L2 Domain Node writes final values once per property
```

### Animation End Flow
```
1. L2 Domain Node stops effect processing
2. L2 Domain Node restores natural values (if needed)
3. L2 Domain Node clears effect contributions
4. L3 Effects reset internal state
```

---

## Property Access Contracts

### L1 Property Access Rules
- **Never access target nodes directly**
- **Never read/write target properties**
- **Only manage recipe and timing state**
- **Provide interfaces for L2 implementation**

### L2 Property Access Rules
- **Access only target type's properties**
- **Read properties for base value capture**
- **Write properties once per frame per property**
- **Detect external property changes**
- **Coordinate multiple effect contributions**

### L3 Property Access Rules
- **Never access target nodes directly**
- **Never read/write target properties**
- **Only calculate mathematical deltas**
- **Use captured reference values for calculations**

---

## Domain-Specific Contracts

### Control Domain Contracts
```gdscript
# L2 Control must handle:
- Container hold patterns (VBoxContainer re-sorting)
- Position-only properties (no rotation/scale)
- Pixel snapping and integer coordinates
- Parent-child layout relationships
- Control-specific signals and events

# L3 Control effects must use:
- Vector2 position deltas only
- Control-specific property names
- Container-aware behavior when needed
```

### Node2D Domain Contracts
```gdscript
# L2 Node2D must handle:
- Transform properties (position, rotation, scale)
- Pivot compensation (no built-in pivot)
- Global vs local coordinate transforms
- Z-index and drawing order
- Node2D-specific signals and events

# L3 Node2D effects must use:
- Vector2 position deltas
- Float rotation deltas (degrees)
- Vector2 scale deltas
- Transform-specific math
```

### Node3D Domain Contracts
```gdscript
# L2 Node3D must handle:
- 3D transforms and spatial relationships
- Multiple coordinate spaces (local, global, viewport)
- Camera and viewport transformations
- Physics and collision integration
- Node3D-specific signals and events

# L3 Node3D effects must use:
- Vector3 position deltas
- Vector3 rotation deltas (radians)
- Vector3 scale deltas
- 3D-specific math and transforms
```

---

## Error Handling Contracts

### L1 Error Handling
- **Validate recipe structure** before processing
- **Provide clear error messages** for invalid configurations
- **Fail gracefully** when resources are missing
- **Never crash** due to user configuration errors

### L2 Error Handling
- **Validate target node type** before processing
- **Handle missing targets** gracefully
- **Recover from external move detection** errors
- **Provide domain-specific error context**

### L3 Error Handling
- **Validate effect parameters** before calculation
- **Handle mathematical edge cases** (division by zero, etc.)
- **Return zero deltas** for invalid states
- **Never cause target manipulation errors**

---

## Performance Contracts

### L1 Performance Requirements
- **Minimal per-frame overhead** for timing management
- **Efficient recipe iteration** and effect activation
- **Low memory footprint** for base classes
- **Fast signal handling** and trigger processing

### L2 Performance Requirements
- **Single write per property per frame** maximum
- **Efficient delta aggregation** across multiple effects
- **Fast external-move detection** with minimal overhead
- **Optimized base value capture** and restoration

### L3 Performance Requirements
- **Fast delta calculations** with minimal allocations
- **Efficient mathematical operations** for effect patterns
- **Low memory usage** for effect state
- **Optimized reference resolution** for From/To patterns

---

## Validation Rules

### Contract Compliance Checklist
For any implementation change, verify:

**L1 Compliance:**
- [ ] No direct target access
- [ ] No effect-specific logic
- [ ] Proper interface provision
- [ ] Domain-agnostic behavior

**L2 Compliance:**
- [ ] Single target type only
- [ ] Single write per property per frame
- [ ] External-move detection implemented
- [ ] Sibling stacking coordination

**L3 Compliance:**
- [ ] Delta calculation only
- [ ] No direct target manipulation
- [ ] Proper domain-specific math
- [ ] Consistent contribution reporting

### Cross-Layer Validation
- [ ] L1 interfaces properly implemented by L2
- [ ] L2 contracts honored by L3 effects
- [ ] Data flow follows contract boundaries
- [ ] Property access rules followed
- [ ] Performance requirements met

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

**Remember:** These contracts are the foundation of Juice V1's architecture. Violating them breaks the delta-first model and compromises the entire system.
