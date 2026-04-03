## L2 External Move Detection

**Purpose:** Detect when external forces move targets between frames and recapture base values.

**Mission:** Maintain delta-first accuracy when user code, physics, or other systems move targets.

**Vision:** Create robust external move detection that preserves effect stacking during external target manipulation.

---

# ============================================================================
# WHAT: External target move detection and base value recapture for delta-first accuracy
# EXPECTS: L1 delta-first model and external target changes from user code/physics
# PROVIDES: Move detection and base recapture to maintain stacking accuracy
# ARCHITECTURE: L2 domain coordination that implements L1 contracts for external moves
# ============================================================================

## Detection Model

### The Problem
Target moves during animation:
```
Frame 1: Juice writes position = (100, 50)
Frame 2: User code moves target = (200, 75)
Frame 3: Juice calculates from old base = wrong result
```

### Solution Pattern
```gdscript
# L2 implements detection and recovery:
func _process(delta: float) -> void:
    # 1. Detect external move
    if _detect_external_move():
        # 2. Recapture base values
        _recapture_base_values()
        # 3. Clear stale contributions
        _clear_stale_contributions()
    
    # 4. Process effects with updated base
    _process_frame_effects()
```

---

## Detection Algorithm

### Expected Value Tracking
```gdscript
# L2 tracks what was written:
class JuiceBase:
    var _last_written: Dictionary = {}
    
    func _write_target_values(total_delta: Dictionary) -> void:
        for property in total_delta.keys():
            var final_value = _natural_base[property] + total_delta[property]
            target.set(property, final_value)
            _last_written[property] = final_value
```

### Move Detection
```gdscript
# L2 implements detection:
func _detect_external_move() -> bool:
    for property in _natural_base.keys():
        var current = target.get(property)
        var expected = _last_written.get(property, _natural_base[property])
        if not _values_approximately_equal(current, expected):
            return true
    return false

func _values_approximately_equal(a, b) -> bool:
    if a is Vector2 and b is Vector2:
        return a.distance_to(b) < 0.001
    if a is Vector3 and b is Vector3:
        return a.distance_to(b) < 0.001
    if a is float and b is float:
        return abs(a - b) < 0.001
    return a == b
```

---

## Recovery Process

### Base Recapture
```gdscript
# L2 recaptures natural base:
func _recapture_base_values() -> void:
    for property in _natural_base.keys():
        # Clear stale contribution
        var stale_contribution = _last_written[property] - _natural_base[property]
        _clear_contribution(property, stale_contribution)
        
        # Capture new base
        _natural_base[property] = target.get(property)
```

### Contribution Clearing
```gdscript
# L2 clears stale contributions:
func _clear_contribution(property: String, contribution: Variant) -> void:
    # Remove stale contribution from aggregation
    # This ensures next frame starts from correct base
    pass
```

---

## Domain-Specific Implementation

### Control Detection
```gdscript
# L2 Control handles position detection:
class JuiceControl extends JuiceBase:
    func _detect_external_move() -> bool:
        var current = target.position
        var expected = _last_written.position
        return not current.is_equal_approx(expected, 0.001)
```

### Node2D Detection
```gdscript
# L2 Node2D handles transform detection:
class Juice2D extends JuiceBase:
    func _detect_external_move() -> bool:
        return _check_property("position") or \
               _check_property("rotation") or \
               _check_property("scale")
    
    func _check_property(property: String) -> bool:
        var current = target.get(property)
        var expected = _last_written[property]
        return not _values_approximately_equal(current, expected)
```

### Node3D Detection
```gdscript
# L2 Node3D handles 3D transform detection:
class Juice3D extends JuiceBase:
    func _detect_external_move() -> bool:
        return _check_3d_property("position") or \
               _check_3d_property("rotation_degrees") or \
               _check_3d_property("scale")
    
    func _check_3d_property(property: String) -> bool:
        var current = target.get(property)
        var expected = _last_written[property]
        return not current.is_equal_approx(expected)
```

---

## Performance Optimization

### Efficient Detection
```gdscript
# L2 optimizes detection with early exit:
func _detect_external_move() -> bool:
    # Check most likely property first
    if _check_position():
        return true
    
    # Check other properties only if needed
    return _check_rotation() or _check_scale()
```

### Minimal Recapture
```gdscript
# L2 recaptures only changed properties:
func _recapture_base_values() -> void:
    for property in _natural_base.keys():
        if _property_changed_externally(property):
            _natural_base[property] = target.get(property)
```

---

## Validation Rules

### Detection Validation
- [ ] External moves detected accurately
- [ ] False positives minimized
- [ ] Performance impact is minimal
- [ ] Domain-specific detection works

### Recovery Validation
- [ ] Base values recaptured correctly
- [ ] Stale contributions cleared
- [ ] Effect stacking preserved
- [ ] Animation continues smoothly

### Architectural Validation
- [ ] L1 delta-first contracts honored
- [ ] L3 effect contributions handled correctly
- [ ] Domain-specific implementation appropriate
- [ ] Cross-domain consistency maintained

---

## Cross-References

**Foundational Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-layer-contracts.md for detection contracts

**Implementation Documents:**
- See L2-write-coordination.md for write coordination
- See L2-domain-separation.md for domain differences

**Effect Documents:**
- See L3 docs for effect contribution patterns

---

## This Document's Role

### During Implementation
- **Detection Reference:** Implement external move detection correctly
- **Recovery Guide:** Handle base recapture and contribution clearing
- **Validation Source:** Verify detection contracts are honored

### During Refactoring
- **Detection Consistency:** Maintain detection accuracy across changes
- **Recovery Preservation:** Ensure recovery patterns are maintained
- **Contract Validation:** Verify L1 contracts are implemented

### For Developers
- **Implementation Pattern:** Understand how to detect and recover from external moves
- **Performance Guidelines:** Write efficient detection code
- **Domain Rules:** Know domain-specific detection requirements

---

## Cross-References

**Foundational Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-layer-contracts.md for detection contracts

**Related L2 Documents:**
- See L2-write-coordination.md for write coordination
- See L2-domain-separation.md for domain differences

**L3 Integration:**
- See L3 docs for effect contribution interfaces

This external move detection system ensures delta-first accuracy when external forces manipulate targets, preserving effect stacking and animation integrity.
