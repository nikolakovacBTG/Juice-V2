## L3 Meta Effects

**Purpose:** Define non-visual effect patterns for time, property, and system-level coordination.

**Mission:** Provide meta-level effects that coordinate system behavior and property animation.

**Vision:** Create meta effects that enhance system capabilities beyond visual animation.

---

# ============================================================================
# WHAT: Meta delta calculations for time, property, and system-level effects
# EXPECTS: L2 write coordination and L1 timing system for meta effect processing
# PROVIDES: Meta delta calculations to L2 domain nodes for system coordination
# ARCHITECTURE: L3 effect implementation that extends domain effect bases
# ============================================================================

## Meta Effect Model

### Core Pattern
```gdscript
# L3 meta effects calculate system deltas:
func _get_seq_contribution() -> Dictionary:
    var delta = _calculate_meta_delta()
    return {"property": delta}
```

### Meta Categories
- **Time Effects:** Animation timing and coordination
- **Property Effects:** Non-visual property animation
- **System Effects:** Cross-cutting coordination

---

## Time Effects

### Time Manipulation
```gdscript
# L3 time effects control animation timing:
class TimeJuiceEffect extends JuiceEffectBase:
    var time_scale: float = 1.0
    var time_offset: float = 0.0
    
    func _get_seq_contribution() -> Dictionary:
        # Time effects don't write to target
        # They coordinate with L1 timing system
        return {}
    
    func _apply_time_scale():
        # Apply time scale to domain node
        if target.has_method("set_time_scale"):
            target.set_time_scale(time_scale)
```

### Animation Coordination
```gdscript
# L3 meta effects coordinate multiple animations:
class SequenceJuiceEffect extends JuiceEffectBase:
    var target_nodes: Array[NodePath]
    var delay_between: float = 0.1
    
    func _get_seq_contribution() -> Dictionary:
        # Coordinate with other Juice nodes
        _trigger_sequential_targets()
        return {}
    
    func _trigger_sequential_targets():
        for i in range(target_nodes.size()):
            var target_node = get_node(target_nodes[i])
            if target_node and target_node.has_method("animate_in"):
                var delay = i * delay_between
                _trigger_with_delay(target_node, delay)
```

---

## Property Effects

### Property Animation
```gdscript
# L3 property effects animate non-visual properties:
class PropertyJuiceEffect extends JuiceEffectBase:
    var property_name: String = ""
    var from_value: Variant
    var to_value: Variant
    
    func _get_seq_contribution() -> Dictionary:
        var current = _interpolate_property(from_value, to_value, _progress)
        var delta = current - _natural_property_value
        return {property_name: delta}
    
    func _get_natural_property_value() -> Variant:
        if target.has_method("get"):
            return target.get(property_name)
        return null
```

### Custom Property Types
```gdscript
# L3 handles different property types:
func _interpolate_property(from: Variant, to: Variant, progress: float) -> Variant:
    match typeof(from):
        TYPE_FLOAT:
            return lerp(from, to, progress)
        TYPE_VECTOR2:
            return from.lerp(to, progress)
        TYPE_VECTOR3:
            return from.lerp(to, progress)
        TYPE_COLOR:
            return from.lerp(to, progress)
        _:
            return to
```

---

## Domain-Specific Implementation

### Control Meta Effects
```gdscript
# L3 Control handles Control-specific meta effects:
class MetaControlJuiceEffect extends JuiceControlEffectBase:
    func _get_seq_contribution() -> Dictionary:
        match meta_type:
            MetaType.TIME:
                return _handle_time_effect()
            MetaType.PROPERTY:
                return _handle_property_effect()
            MetaType.SYSTEM:
                return _handle_system_effect()
```

### Node2D Meta Effects
```gdscript
# L3 Node2D handles Node2D-specific meta effects:
class Meta2DJuiceEffect extends Juice2DEffectBase:
    func _get_seq_contribution() -> Dictionary:
        return _calculate_2d_meta_delta()
```

### Node3D Meta Effects
```gdscript
# L3 Node3D handles Node3D-specific meta effects:
class Meta3DJuiceEffect extends Juice3DEffectBase:
    func _get_seq_contribution() -> Dictionary:
        return _calculate_3d_meta_delta()
```

---

## Cross-References

**Foundational Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-timing-system.md for time coordination

**Domain Documents:**
- See L2-write-coordination.md for meta delta aggregation
- See L2-domain-separation.md for domain-specific meta handling

**Effect Documents:**
- See L3-transform-deltas.md for transform patterns
- See L3-appearance-from-to.md for visual patterns

---

## This Document's Role

### During Implementation
- **Meta Reference:** Implement system-level effects correctly
- **Time Guide:** Handle timing coordination properly
- **Domain Guide:** Know domain-specific meta requirements

### During Refactoring
- **Meta Consistency:** Maintain system-level behavior across changes
- **Time Preservation:** Ensure timing coordination works correctly
- **Domain Compatibility:** Preserve domain-specific meta handling

### For Developers
- **Implementation Pattern:** Understand meta delta calculation
- **Domain Rules:** Know domain-specific meta requirements
- **System Guide:** Handle cross-cutting coordination correctly

---

## Cross-References

**Foundational Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-base-interfaces.md for effect interfaces

**Related L3 Documents:**
- See L3-transform-deltas.md for transform patterns
- See L3-procedural-animation.md for mathematical effects

**L2 Integration:**
- See L2 docs for meta delta aggregation and write coordination

This meta effect system provides system-level coordination while maintaining delta-first architectural integrity across all domains.
