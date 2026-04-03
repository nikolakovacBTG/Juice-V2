## L1 Delta-First Model

**Purpose:** Define the mathematical foundation and architectural contracts for Juice's delta-first animation system.

**Mission:** Provide the theoretical model that enables effect stacking while maintaining performance and architectural integrity.

**Vision:** Enable unlimited effect combination through mathematical precision rather than implementation complexity.

---

# ============================================================================
# WHAT: Mathematical foundation for Juice effect stacking and performance optimization
# EXPECTS: L2 domain nodes to implement write coordination and base value capture
# PROVIDES: Delta calculation contracts and stacking coordination patterns to L2/L3
# ARCHITECTURE: L1 core infrastructure that all domains must implement for effect stacking
# ============================================================================

## Core Mathematical Model

### The Delta-First Innovation
**Traditional Animation Systems:**
```
Effect1 writes final position to target
Effect2 overwrites position with its final position
Effect3 overwrites position with its final position
Result: Only last effect visible, stacking impossible
```

**Juice Delta-First System:**
```
Effect1 calculates delta: position_change_1
Effect2 calculates delta: position_change_2  
Effect3 calculates delta: position_change_3
Domain node aggregates: total_delta = sum(all_deltas)
Domain node writes: target.position = natural_base + total_delta
Result: All effects combine mathematically
```

### The Fundamental Formula
```
final_target_value = natural_base_value + Σ(effect_delta_values)
```

**Where:**
- `natural_base_value` = Target's value without any Juice effects
- `effect_delta_values` = Each effect's contribution (offset from natural)
- `Σ` = Sum of all active effect contributions
- `final_target_value` = Value written to target each frame

---

## Architectural Contracts

### L1 Provides to L2 (Domain Nodes)
**Base Value Capture Contract:**
```gdscript
# L1 defines this interface that L2 must implement:
func _capture_natural_base() -> void:
    # Capture target's natural state before effects
    _natural_position = target.position
    _natural_rotation = target.rotation
    _natural_scale = target.scale
```

**External-Move Detection Contract:**
```gdscript
# L1 defines this pattern that L2 must implement:
func _detect_external_move() -> bool:
    # Check if target moved by external forces
    return target.position != _last_written_position
```

**Write Coordination Contract:**
```gdscript
# L1 defines this timing that L2 must honor:
func _process(delta):
    # Aggregate all effects, then write once per property
    var total_delta = _aggregate_all_effect_deltas()
    _write_final_values(natural_base + total_delta)
```

### L1 Provides to L3 (Effects)
**Delta Calculation Contract:**
```gdscript
# L1 defines this interface that L3 must implement:
func _get_seq_contribution() -> Dictionary:
    # Return only delta, never final values
    return {"position": calculated_delta_from_natural}
```

**Reference Capture Contract:**
```gdscript
# L1 defines this pattern that L3 must follow:
func _capture_references():
    # Capture From/To references at animation start
    _from_reference = _resolve_reference(from_source)
    _to_reference = _resolve_reference(to_source)
```

**Stateless Calculation Contract:**
```gdscript
# L1 requires this behavior from L3:
func _apply_effect(progress):
    # Calculate based on progress, no side effects
    return _calculate_delta_at_progress(progress)
```

---

## Implementation Patterns

### Base Value Capture Pattern
```gdscript
# L1 provides this pattern for L2 implementation:
class JuiceBase:
    var _natural_base: Dictionary = {}
    var _external_move_detected: bool = false
    
    func _capture_natural_base():
        _natural_base = {
            "position": target.position,
            "rotation": target.rotation, 
            "scale": target.scale
        }
    
    func _detect_external_move() -> bool:
        for property in _natural_base.keys():
            if target.get(property) != _last_written.get(property):
                return true
        return false
```

### Delta Aggregation Pattern
```gdscript
# L1 provides this pattern for L2 implementation:
func _aggregate_effect_deltas() -> Dictionary:
    var total_delta = {}
    
    # Initialize all properties to zero
    for effect in active_effects:
        var contribution = effect._get_seq_contribution()
        for property in contribution.keys():
            if not total_delta.has(property):
                total_delta[property] = Vector2.ZERO  # Domain-specific
    
    # Sum all contributions
    for effect in active_effects:
        var contribution = effect._get_seq_contribution()
        for property in contribution.keys():
            total_delta[property] += contribution[property]
    
    return total_delta
```

### Effect Delta Pattern
```gdscript
# L1 provides this pattern for L3 implementation:
class JuiceEffectBase:
    var _captured_from: Variant
    var _captured_to: Variant
    var _captured_natural: Variant
    
    func _get_seq_contribution() -> Dictionary:
        var current_value = _interpolate(_captured_from, _captured_to, progress)
        var delta = current_value - _captured_natural
        return {"position": delta}  # Property-specific
```

---

## Performance Implications

### Write Optimization
**Before Delta-First:**
- N effects × M properties = N×M writes per frame
- Each effect overwrites previous effects
- Performance degrades with effect count

**After Delta-First:**
- 1 write per property per frame = M writes total
- Mathematical combination instead of sequential overwrites
- Performance scales with property count, not effect count

### Memory Optimization
**State Management:**
- Effects store only their delta contribution
- Domain node manages aggregation state
- No duplicate state storage across effects

**Garbage Collection:**
- Minimal per-frame allocations
- Reusable delta dictionaries
- No temporary object creation in hot paths

### CPU Optimization
**Calculation Efficiency:**
- Vector math is highly optimized
- Simple addition operations for aggregation
- Branch prediction friendly patterns

---

## Stacking Scenarios

### Multiple Transform Effects
```gdscript
# Effect 1: Move from (0,0) to (100,0)
# Effect 2: Rotate from 0° to 90°
# Effect 3: Scale from (1,1) to (2,2)

# Frame at 50% progress:
natural_base = (10, 15), rotation=0°, scale=(1,1)
effect1_delta = (50, 0)  # 50% of (100,0)
effect2_delta = 45°       # 50% of 90°
effect3_delta = (0.5, 0.5) # 50% of (1,1) scale increase

final_position = (10,15) + (50,0) = (60,15)
final_rotation = 0° + 45° = 45°
final_scale = (1,1) + (0.5,0.5) = (1.5,1.5)
```

### External Move Recovery
```gdscript
# User code moves target during animation:
frame_1: target.position = (60,15)  # Juice applied
frame_2: user_code.target.position = (200,50)  # External move
frame_3: Juice detects external move, recaptures base
frame_3_final: (200,50) + effect_deltas = (250,50)
```

### Container Hold Patterns
```gdscript
# Control in VBoxContainer tries to move:
container_wants_position = (100,0)  # Layout system
juice_wants_position = (150,25)     # Effect animation
delta_first_result = natural_base + juice_delta
# Domain node re-applies every frame to beat container re-sort
```

---

## Mathematical Properties

### Commutative Property
Effect order doesn't matter:
```
effect_a_delta + effect_b_delta = effect_b_delta + effect_a_delta
```

### Associative Property  
Grouping doesn't matter:
```
(effect_a_delta + effect_b_delta) + effect_c_delta = 
effect_a_delta + (effect_b_delta + effect_c_delta)
```

### Identity Property
Zero delta has no effect:
```
natural_base + zero_delta = natural_base
```

### Inverse Property
Negative delta reverses effect:
```
natural_base + effect_delta = final_value
final_value + (-effect_delta) = natural_base
```

---

## Validation Rules

### Mathematical Validation
- [ ] Delta calculations are mathematically sound
- [ ] Aggregation preserves mathematical properties
- [ ] Base capture is accurate and complete
- [ ] External move detection is reliable

### Performance Validation  
- [ ] Single write per property per frame maximum
- [ ] No per-frame memory allocations in hot paths
- [ ] CPU usage scales with properties, not effects
- [ ] Garbage collection impact is minimal

### Architectural Validation
- [ ] Effects never write directly to targets
- [ ] Domain nodes handle all write coordination
- [ ] Base values captured before effect processing
- [ ] External moves detected and handled correctly

---

## Cross-References

**Foundational Documents:**
- See L1-layer-contracts.md for layer boundary definitions
- See ARCHITECTURE_BIG_PICTURE.md for system-wide context

**Implementation Documents:**
- See L2-write-coordination.md for domain implementation
- See L3-transform-deltas.md for effect implementation examples

**Validation Documents:**
- See L1-3_CONTRACT_MATRIX.md for complete contract definitions
- See VALIDATION_STANDARDS.md for quality requirements

---

## Examples

### Simple Position Delta
```gdscript
# Effect: Move from (0,0) to (100,0) over 1 second
# Natural base: (10, 15)
# At 0.5 second progress:

captured_from = (0, 0)
captured_to = (100, 0)
captured_natural = (10, 15)
current_value = (50, 0)  # 50% interpolation
delta = (50, 0) - (10, 15) = (40, -15)

# L2 domain node writes:
target.position = (10, 15) + (40, -15) = (50, 0)
```

### Complex Multi-Property Delta
```gdscript
# Transform effect with position, rotation, scale:
delta_contribution = {
    "position": Vector2(40, -15),
    "rotation": 45.0,
    "scale": Vector2(0.5, 0.5)
}

# L2 domain node aggregates with other effects and writes:
target.position = natural_base.position + total_delta.position
target.rotation = natural_base.rotation + total_delta.rotation  
target.scale = natural_base.scale + total_delta.scale
```

---

This model provides the mathematical foundation that makes Juice's effect stacking possible while maintaining performance and architectural integrity. All L2 domain nodes and L3 effects must honor these contracts to participate in the delta-first system.
