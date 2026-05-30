# L1-3 Contract Matrix - **AUTHORITATIVE REFERENCE**

**Purpose:** Single source of truth for all layer contracts, boundaries, and responsibilities. Referenced by all other skill docs.

---

## Core Responsibility Matrix

| Layer | Target Access | Effect Math | Write Target | Delta Calc | Base Capture | External Detect |
|-------|--------------|-------------|-------------|------------|--------------|----------------|
| **L1 Core** | ❌ Never | ❌ Never | ❌ Never | ❌ Never | ❌ Never | ❌ Never |
| **L2 Domain** | ✅ One type | ❌ Never | ✅ Once/frame | ❌ Never | ✅ Natural | ✅ Yes |
| **L3 Effect** | ❌ Never | ✅ Specific | ❌ Never | ✅ Only | ✅ From/To | ❌ Never |

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

## Performance & Error Requirements

### L1: Core Infrastructure
- **Validate recipe structure** before processing
- **Minimal per-frame overhead** for timing management
- **Fail gracefully** when resources are missing
- **Efficient recipe iteration** and effect activation

### L2: Domain Coordination
- **Validate target node type** before processing
- **Single write per property per frame** maximum
- **Handle missing targets** gracefully
- **Fast external-move detection** with minimal overhead

### L3: Effects
- **Validate effect parameters** before calculation
- **Fast delta calculations** with minimal allocations
- **Handle mathematical edge cases** (division by zero, etc.)
- **Return zero deltas** for invalid states

---

## Validation Checklist

**For any implementation change, verify:**

### L1 Compliance
- [ ] No direct target access
- [ ] No effect-specific logic  
- [ ] Proper interface provision
- [ ] Domain-agnostic behavior

### L2 Compliance  
- [ ] Single target type only
- [ ] Single write per property per frame
- [ ] External-move detection implemented
- [ ] Sibling stacking coordination

### L3 Compliance
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

## Reference Usage

**When to reference this document:**
- During implementation: Check layer boundaries
- During refactoring: Validate architectural integrity  
- During debugging: Identify contract violations
- During code review: Ensure compliance

**Related documents reference this for:**
- Contract validation rules
- Layer boundary explanations
- Property access patterns
- Performance requirements

---

**Remember:** These contracts are the foundation of Juice. Violating them breaks the delta-first model.
