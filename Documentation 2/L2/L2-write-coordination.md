## L2 Write Coordination

**Purpose:** Define per-frame write coordination and delta aggregation patterns that enable effect stacking while preventing write conflicts.

**Mission:** Coordinate multiple effect contributions into single, optimized writes per property per frame.

**Vision:** Create a write coordination system that seamlessly combines unlimited effects while maintaining performance and preventing conflicts.

---

# ============================================================================
# WHAT: Per-frame write coordination and delta aggregation for effect stacking
# EXPECTS: L1 delta-first model and L3 effect contributions for aggregation
# PROVIDES: Single-write coordination and conflict prevention to L3 effects
# ARCHITECTURE: L2 domain coordination that implements L1 contracts for L3 effects
# ============================================================================

## Write Coordination Model

### The Write Problem
**Without Coordination:**
```
Effect1 writes target.position = (100, 50)
Effect2 writes target.position = (150, 25)  # Overwrites Effect1
Effect3 writes target.position = (75, 100) # Overwrites Effect2
Result: Only Effect3 visible, stacking broken
```

**With Coordination:**
```
Effect1 contributes delta = (90, 35)
Effect2 contributes delta = (140, 10)
Effect3 contributes delta = (65, 85)
Domain node aggregates = (295, 130)
Domain node writes: target.position = natural + (295, 130)
Result: All effects combine mathematically
```

### Core Coordination Pattern
```gdscript
# L2 implements this coordination pattern:
func _process(delta: float) -> void:
    # 1. Detect external moves
    if _detect_external_move():
        _recapture_base_values()
    
    # 2. Aggregate all effect deltas
    var total_delta = _aggregate_effect_deltas()
    
    # 3. Write once per property
    _write_target_values(total_delta)
```

---

## Delta Aggregation

### Aggregation Algorithm
```gdscript
# L2 provides this aggregation method:
func _aggregate_effect_deltas() -> Dictionary:
    var total_delta = {}
    
    # Initialize all properties to zero
    for effect in active_effects:
        var contribution = effect._get_seq_contribution()
        for property in contribution.keys():
            if not total_delta.has(property):
                total_delta[property] = _get_zero_vector(property)
    
    # Sum all contributions
    for effect in active_effects:
        var contribution = effect._get_seq_contribution()
        for property in contribution.keys():
            total_delta[property] += contribution[property]
    
    return total_delta
```

### Domain-Specific Zero Vectors
```gdscript
# L2 implements domain-specific zero vectors:
func _get_zero_vector(property: String) -> Variant:
    match property:
        "position":
            return Vector2.ZERO  # Control/2D or Vector3.ZERO for 3D
        "rotation":
            return 0.0
        "scale":
            return Vector2.ONE
        "modulate":
            return Color.WHITE
```

---

## Single Write Pattern

### Write Coordination Contract
```gdscript
# L2 must write each property exactly once per frame:
func _write_target_values(total_delta: Dictionary) -> void:
    # Capture what we're about to write
    _last_written = {}
    
    # Write each property once
    for property in total_delta.keys():
        var final_value = _natural_base[property] + total_delta[property]
        target.set(property, final_value)
        _last_written[property] = final_value
```

### External Move Detection
```gdscript
# L2 implements external move detection:
func _detect_external_move() -> bool:
    for property in _natural_base.keys():
        var current_value = target.get(property)
        var expected_value = _last_written.get(property, _natural_base[property])
        if not _values_approximately_equal(current_value, expected_value):
            return true
    return false

func _values_approximately_equal(a, b) -> bool:
    # Domain-specific comparison logic
    if a is Vector2 and b is Vector2:
        return a.distance_to(b) < 0.001
    if a is float and b is float:
        return abs(a - b) < 0.001
    return a == b
```

---

## Performance Optimization

### Write Minimization
```gdscript
# L2 minimizes writes with dirty checking:
func _write_target_values(total_delta: Dictionary) -> void:
    for property in total_delta.keys():
        var delta = total_delta[property]
        if delta != _last_delta.get(property, _get_zero_vector(property)):
            var final_value = _natural_base[property] + delta
            target.set(property, final_value)
            _last_delta[property] = delta
```

### Batch Operations
```gdscript
# L2 batches related operations:
func _write_target_values(total_delta: Dictionary) -> void:
    # Group transform writes together
    if total_delta.has("position") or total_delta.has("rotation"):
        _write_transform_batch(total_delta)
    
    # Group appearance writes together
    if total_delta.has("modulate") or total_delta.has("visible"):
        _write_appearance_batch(total_delta)
```

---

## Domain-Specific Implementation

### Control Domain Coordination
```gdscript
# L2 Control handles position-only writes:
class JuiceControl extends JuiceBase:
    func _write_target_values(total_delta: Dictionary) -> void:
        if total_delta.has("position"):
            var final_pos = _natural_base.position + total_delta.position
            target.position = final_pos
            _last_written.position = final_pos
```

### Node2D Domain Coordination
```gdscript
# L2 Node2D handles transform writes:
class Juice2D extends JuiceBase:
    func _write_target_values(total_delta: Dictionary) -> void:
        if total_delta.has("position"):
            target.position = _natural_base.position + total_delta.position
        if total_delta.has("rotation"):
            target.rotation = _natural_base.rotation + total_delta.rotation
        if total_delta.has("scale"):
            target.scale = _natural_base.scale + total_delta.scale
```

### Node3D Domain Coordination
```gdscript
# L2 Node3D handles 3D transform writes:
class Juice3D extends JuiceBase:
    func _write_target_values(total_delta: Dictionary) -> void:
        if total_delta.has("position"):
            target.position = _natural_base.position + total_delta.position
        if total_delta.has("rotation"):
            target.rotation_degrees = _natural_base.rotation + total_delta.rotation
        if total_delta.has("scale"):
            target.scale = _natural_base.scale + total_delta.scale
```

---

## Container Hold Patterns

### Container Challenge
**Problem:** VBoxContainer re-sorts children every frame, overriding position writes
**Solution:** Re-apply position every frame to beat container re-sort

```gdscript
# L2 Control implements container hold pattern:
class JuiceControl extends JuiceBase:
    var _held_entries: Array[Dictionary] = []
    
    func _process(delta: float) -> void:
        super._process(delta)
        
        # Re-apply held positions every frame
        for entry in _held_entries:
            var target = entry.target
            var delta = entry.effect._get_seq_contribution().position
            target.position = _natural_base.position + delta
```

---

## Validation Rules

### Write Coordination Validation
- [ ] Each property written exactly once per frame
- [ ] External moves detected and handled
- [ ] Delta aggregation is mathematically correct
- [ ] No write conflicts between effects

### Performance Validation
- [ ] Minimal per-frame overhead
- [ ] No unnecessary property writes
- [ ] Efficient delta aggregation
- [ ] Proper memory management

### Architectural Validation
- [ ] L1 delta-first contracts honored
- [ ] L3 effect contributions properly aggregated
- [ ] Domain-specific implementation correct
- [ ] Cross-domain coordination maintained

---

## Cross-References

**Foundational Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-layer-contracts.md for write coordination contracts

**Implementation Documents:**
- See L2-sibling-stacking.md for effect coordination
- See L2-domain-separation.md for domain-specific patterns

**Effect Documents:**
- See L3 docs for effect contribution patterns
- See L3-transform-deltas.md for delta examples

---

## This Document's Role

### During Implementation
- **Coordination Reference:** Ensure proper write coordination implementation
- **Performance Guide:** Optimize per-frame write operations
- **Validation Source:** Verify coordination contracts are honored

### During Refactoring
- **Coordination Consistency:** Maintain write coordination across changes
- **Performance Preservation:** Ensure optimization patterns are maintained
- **Contract Validation:** Verify L1 contracts are implemented

### For Developers
- **Implementation Pattern:** Understand how to coordinate multiple effects
- **Performance Guidelines:** Write efficient coordination code
- **Domain Rules:** Know domain-specific coordination requirements

---

## Cross-References

**Foundational Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-layer-contracts.md for coordination contracts

**Related L2 Documents:**
- See L2-sibling-stacking.md for effect stacking
- See L2-domain-separation.md for domain differences

**L3 Integration:**
- See L3 docs for effect contribution interfaces
- See L3-transform-deltas.md for delta calculation examples

This write coordination system enables unlimited effect stacking while maintaining performance and preventing write conflicts across all Juice domains.
