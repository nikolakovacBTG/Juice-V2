## L2 Sibling Stacking

**Purpose:** Coordinate multiple Juice nodes on the same target to enable effect stacking without conflicts.

**Mission:** Aggregate contributions from multiple Juice nodes while maintaining individual effect control.

**Vision:** Enable unlimited effect combination through coordinated sibling node management.

---

# ============================================================================
# WHAT: Multi-node coordination and contribution aggregation for effect stacking
# EXPECTS: L1 delta-first model and L3 effect contributions from multiple nodes
# PROVIDES: Sibling coordination and aggregation patterns to multiple Juice nodes
# ARCHITECTURE: L2 domain coordination that handles multi-node scenarios
# ============================================================================

## Sibling Stacking Model

### The Challenge
Multiple Juice nodes on same target:
```
Target (Control)
├── JuiceNode1 (Transform effect)
├── JuiceNode2 (Appearance effect)  
└── JuiceNode3 (Noise effect)
```

**Without Coordination:** Each node overwrites others
**With Coordination:** All effects combine mathematically

### Coordination Pattern
```gdscript
# Each Juice node contributes to shared aggregation:
class JuiceBase:
    func _process(delta: float) -> void:
        # 1. Calculate my contribution
        var my_delta = _calculate_my_delta()
        
        # 2. Find sibling Juice nodes
        var siblings = _find_sibling_juice_nodes()
        
        # 3. Aggregate all contributions
        var total_delta = _aggregate_sibling_deltas(siblings, my_delta)
        
        # 4. Write final result
        _write_target_values(total_delta)
```

---

## Sibling Discovery

### Type-Safe Discovery
```gdscript
# L2 implements type-safe sibling discovery:
func _find_sibling_juice_nodes() -> Array[JuiceBase]:
    var siblings: Array[JuiceBase] = []
    var parent = target.get_parent()
    
    if parent:
        for child in parent.get_children():
            if child is JuiceBase and child != self:
                siblings.append(child)
    
    return siblings
```

### Domain-Specific Discovery
```gdscript
# L2 implements domain-specific discovery:
class JuiceControl extends JuiceBase:
    func _find_sibling_juice_nodes() -> Array[JuiceControl]:
        var siblings: Array[JuiceControl] = []
        var parent = target.get_parent()
        
        if parent:
            for child in parent.get_children():
                if child is JuiceControl and child != self:
                    siblings.append(child)
    
        return siblings
```

---

## Contribution Aggregation

### Aggregation Algorithm
```gdscript
# L2 aggregates contributions from all siblings:
func _aggregate_sibling_deltas(siblings: Array, my_delta: Dictionary) -> Dictionary:
    var total_delta = my_delta.duplicate()
    
    # Add contributions from all siblings
    for sibling in siblings:
        if sibling.is_playing:
            var sibling_delta = sibling._get_seq_contribution()
            _add_deltas(total_delta, sibling_delta)
    
    return total_delta

func _add_deltas(total: Dictionary, contribution: Dictionary) -> void:
    for property in contribution.keys():
        if total.has(property):
            total[property] += contribution[property]
        else:
            total[property] = contribution[property]
```

### Conflict Resolution
```gdscript
# L2 handles conflicting contributions:
func _resolve_conflicts(total_delta: Dictionary) -> Dictionary:
    # Priority: last node wins for conflicts
    # Or implement domain-specific resolution
    return total_delta
```

---

## Performance Optimization

### Efficient Sibling Discovery
```gdscript
# L2 caches sibling discovery:
class JuiceBase:
    var _cached_siblings: Array[JuiceBase] = []
    var _siblings_cache_frame: int = 0
    
    func _find_sibling_juice_nodes() -> Array[JuiceBase]:
        var current_frame = Engine.get_process_frames()
        if current_frame != _siblings_cache_frame:
            _cached_siblings = _discover_siblings()
            _siblings_cache_frame = current_frame
        
        return _cached_siblings
```

### Minimal Aggregation
```gdscript
# L2 minimizes aggregation overhead:
func _aggregate_sibling_deltas(siblings: Array, my_delta: Dictionary) -> Dictionary:
    # Early exit if no siblings
    if siblings.is_empty():
        return my_delta
    
    # Aggregate only active siblings
    var total_delta = my_delta.duplicate()
    for sibling in siblings:
        if sibling.is_playing:
            var sibling_delta = sibling._get_seq_contribution()
            _add_deltas(total_delta, sibling_delta)
    
    return total_delta
```

---

## Coordination Contracts

### Sibling Node Contract
```gdscript
# L2 provides this contract to sibling nodes:
class JuiceBase:
    # Must provide contribution calculation
    func _get_seq_contribution() -> Dictionary:
        # Return my delta contribution
        pass
    
    # Must provide playing state
    var is_playing: bool = false
    
    # Must not write directly to target
    # Let coordination handle writes
```

### Aggregation Contract
```gdscript
# L2 provides this aggregation contract:
func _aggregate_sibling_deltas(siblings: Array, my_delta: Dictionary) -> Dictionary:
    # Must aggregate all active contributions
    # Must handle domain-specific math
    # Must return combined delta
    pass
```

---

## Domain-Specific Patterns

### Control Sibling Stacking
```gdscript
# L2 Control handles position-only stacking:
class JuiceControl extends JuiceBase:
    func _aggregate_sibling_deltas(siblings: Array[JuiceControl], my_delta: Dictionary) -> Dictionary:
        var total_delta = my_delta.position
        
        for sibling in siblings:
            if sibling.is_playing:
                var sibling_delta = sibling._get_seq_contribution()
                total_delta += sibling_delta.position
        
        return {"position": total_delta}
```

### Node2D Sibling Stacking
```gdscript
# L2 Node2D handles transform stacking:
class Juice2D extends JuiceBase:
    func _aggregate_sibling_deltas(siblings: Array[Juice2D], my_delta: Dictionary) -> Dictionary:
        var total_delta = {
            "position": my_delta.position,
            "rotation": my_delta.rotation,
            "scale": my_delta.scale
        }
        
        for sibling in siblings:
            if sibling.is_playing:
                var sibling_delta = sibling._get_seq_contribution()
                total_delta.position += sibling_delta.position
                total_delta.rotation += sibling_delta.rotation
                total_delta.scale += sibling_delta.scale
        
        return total_delta
```

---

## Validation Rules

### Stacking Validation
- [ ] Sibling discovery is type-safe
- [ ] Contribution aggregation is mathematically correct
- [ ] No write conflicts between siblings
- [ ] Performance scales with sibling count

### Coordination Validation
- [ ] All siblings provide valid contributions
- [ ] Aggregation handles domain-specific math
- [ ] Cache invalidation works correctly
- [ ] Early exit optimization works

### Architectural Validation
- [ ] L1 delta-first contracts honored
- [ ] L3 effect contributions properly aggregated
- [ ] Domain-specific implementation correct
- [ ] Cross-domain coordination maintained

---

## Cross-References

**Foundational Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-layer-contracts.md for stacking contracts

**Implementation Documents:**
- See L2-write-coordination.md for write coordination
- See L2-domain-separation.md for domain differences

**Effect Documents:**
- See L3 docs for effect contribution patterns
- See L3-transform-deltas.md for delta examples

---

## This Document's Role

### During Implementation
- **Stacking Reference:** Ensure proper sibling coordination implementation
- **Performance Guide:** Optimize multi-node coordination
- **Validation Source:** Verify stacking contracts are honored

### During Refactoring
- **Stacking Consistency:** Maintain sibling coordination across changes
- **Performance Preservation:** Ensure optimization patterns are maintained
- **Contract Validation:** Verify L1 contracts are implemented

### For Developers
- **Implementation Pattern:** Understand how to coordinate multiple nodes
- **Performance Guidelines:** Write efficient stacking code
- **Domain Rules:** Know domain-specific stacking requirements

---

## Cross-References

**Foundational Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-layer-contracts.md for stacking contracts

**Related L2 Documents:**
- See L2-write-coordination.md for write coordination
- See L2-domain-separation.md for domain differences

**L3 Integration:**
- See L3 docs for effect contribution interfaces
- See L3-transform-deltas.md for delta calculation examples

This sibling stacking system enables unlimited effect combination through coordinated multi-node management while maintaining performance and architectural integrity.
