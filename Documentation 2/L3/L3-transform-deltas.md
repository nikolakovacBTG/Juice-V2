## L3 Transform Deltas

**Purpose:** Define transform effect delta calculations for position, rotation, and scale across domains.

**Mission:** Provide mathematical patterns for transform animations using delta-first model.

**Vision:** Create consistent transform effects that work seamlessly across all domains.

---

# ============================================================================
# WHAT: Transform delta calculations for position, rotation, scale animations
# EXPECTS: L2 write coordination and L1 timing system for effect processing
# PROVIDES: Transform delta calculations to L2 domain nodes for aggregation
# ARCHITECTURE: L3 effect implementation that extends domain effect bases
# ============================================================================

## Transform Delta Model

### Core Pattern
```gdscript
# L3 transform effects calculate deltas only:
func _get_seq_contribution() -> Dictionary:
    var current_value = _interpolate(_from, _to, _progress)
    var delta = current_value - _natural_base
    return {"property": delta}
```

### From/To Resolution
```gdscript
# L3 handles From/To reference resolution:
func _capture_references():
    _from = _resolve_reference(_from_source)
    _to = _resolve_reference(_to_source)
    _natural_base = _get_current_target_value()
```

---

## Domain-Specific Implementation

### Control Transform
```gdscript
# L3 Control handles position only:
class TransformControlJuiceEffect extends JuiceControlEffectBase:
    var from_position: Vector2
    var to_position: Vector2
    
    func _get_seq_contribution() -> Dictionary:
        var current = from_position.lerp(to_position, _progress)
        var delta = current - _natural_base.position
        return {"position": delta}
```

### Node2D Transform
```gdscript
# L3 Node2D handles full transform:
class Transform2DJuiceEffect extends Juice2DEffectBase:
    var from_position: Vector2
    var to_position: Vector2
    var from_rotation: float
    var to_rotation: float
    var from_scale: Vector2
    var to_scale: Vector2
    
    func _get_seq_contribution() -> Dictionary:
        return {
            "position": _calculate_position_delta(),
            "rotation": _calculate_rotation_delta(),
            "scale": _calculate_scale_delta()
        }
    
    func _calculate_position_delta() -> Vector2:
        var current = from_position.lerp(to_position, _progress)
        return current - _natural_base.position
```

### Node3D Transform
```gdscript
# L3 Node3D handles 3D transform:
class Transform3DJuiceEffect extends Juice3DEffectBase:
    var from_position: Vector3
    var to_position: Vector3
    var from_rotation: Vector3
    var to_rotation: Vector3
    var from_scale: Vector3
    var to_scale: Vector3
    
    func _get_seq_contribution() -> Dictionary:
        return {
            "position": _calculate_3d_position_delta(),
            "rotation": _calculate_3d_rotation_delta(),
            "scale": _calculate_3d_scale_delta()
        }
```

---

## Reference Resolution

### Reference Types
```gdscript
# L3 resolves From/To references:
enum ReferenceSource {
    CUSTOM,      # Explicit value
    SELF,        # Snapshot at animation start
    TARGET_NODE  # Live node reference
}

func _resolve_reference(source: ReferenceSource) -> Variant:
    match source:
        ReferenceSource.CUSTOM:
            return _custom_value
        ReferenceSource.SELF:
            return _captured_self_value
        ReferenceSource.TARGET_NODE:
            return _target_node.get(_property_name)
```

### Live Reference Tracking
```gdscript
# L3 tracks live node references:
func _process(delta: float) -> void:
    if _to_source == ReferenceSource.TARGET_NODE:
        _to = _target_node.get(_property_name)
        # Recalculate based on live target
```

---

## Easing Integration

### Easing Application
```gdscript
# L3 applies easing to interpolation:
func _interpolate(from: Variant, to: Variant, progress: float) -> Variant:
    var eased_progress = _apply_easing(progress)
    
    if from is Vector2 and to is Vector2:
        return from.lerp(to, eased_progress)
    elif from is float and to is float:
        return lerp(from, to, eased_progress)
    elif from is Vector3 and to is Vector3:
        return from.lerp(to, eased_progress)
    
    return to
```

---

## Pivot Compensation

### Node2D Pivot Handling
```gdscript
# L3 Node2D compensates for missing pivot:
func _apply_rotation_with_pivot(delta: float) -> void:
    var pivot_offset = _get_pivot_offset()
    
    # Move to pivot, rotate, move back
    target.position += pivot_offset
    target.rotation += delta
    target.position -= pivot_offset

func _get_pivot_offset() -> Vector2:
    return target.get_size() * 0.5  # Default to center
```

---

## Performance Optimization

### Minimal Calculations
```gdscript
# L3 minimizes per-frame work:
func _get_seq_contribution() -> Dictionary:
    if not _needs_recalculation:
        return _cached_contribution
    
    _cached_contribution = _calculate_contribution()
    _needs_recalculation = false
    return _cached_contribution
```

---

## Validation Rules

### Delta Calculation Validation
- [ ] Deltas calculated correctly (current - natural)
- [ ] No direct target manipulation
- [ ] Domain-specific math is correct
- [ ] Pivot compensation works where needed

### Reference Resolution Validation
- [ ] From/To references resolve correctly
- [ ] Live references update properly
- [ ] Self snapshots captured at start
- [ ] Custom values used directly

### Performance Validation
- [ ] Minimal per-frame calculations
- [ ] Caching works where appropriate
- [ ] No unnecessary allocations
- [ ] Efficient interpolation

---

## Cross-References

**Foundational Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-timing-system.md for progress integration

**Domain Documents:**
- See L2-write-coordination.md for delta aggregation
- See L2-domain-separation.md for domain-specific math

**Effect Documents:**
- See L3-appearance-from-to.md for reference patterns
- See L3-procedural-animation.md for mathematical effects

---

## This Document's Role

### During Implementation
- **Transform Reference:** Implement transform effects correctly
- **Math Guide:** Use proper delta calculations
- **Domain Guide:** Handle domain-specific differences

### During Refactoring
- **Transform Consistency:** Maintain transform behavior across changes
- **Math Preservation:** Ensure calculations remain accurate
- **Domain Compatibility:** Preserve domain-specific handling

### For Developers
- **Implementation Pattern:** Understand transform delta calculation
- **Domain Rules:** Know domain-specific requirements
- **Reference Guide:** Resolve From/To references correctly

---

## Cross-References

**Foundational Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-base-interfaces.md for effect interfaces

**Related L3 Documents:**
- See L3-appearance-from-to.md for reference resolution
- See L3-procedural-animation.md for mathematical patterns

**L2 Integration:**
- See L2 docs for delta aggregation and write coordination

This transform delta system provides the mathematical foundation for all transform animations while maintaining delta-first architectural integrity.
