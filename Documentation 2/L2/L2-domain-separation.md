## L2 Domain Separation

**Purpose:** Define strict boundaries between Control, Node2D, and Node3D domains to prevent architectural violations.

**Mission:** Maintain domain integrity while enabling consistent patterns across domains.

**Vision:** Create clear domain separation that enables specialized implementations without cross-domain contamination.

---

# ============================================================================
# WHAT: Control/2D/3D domain boundaries and specialized implementation patterns
# EXPECTS: L1 contracts to be implemented domain-specific and L3 effects to honor domain boundaries
# PROVIDES: Domain-specific validation, coordination, and implementation patterns
# ARCHITECTURE: L2 domain coordination that enforces strict separation between domains
# ============================================================================

## Domain Boundaries

### Control Domain
**Target Type:** Control nodes only
**Properties:** position (Vector2)
**Challenges:** Container layout, pixel snapping, parent-child relationships
**Specifics:** No rotation/scale, layout system interference

### Node2D Domain  
**Target Type:** Node2D nodes only
**Properties:** position (Vector2), rotation (float), scale (Vector2)
**Challenges:** No pivot point, global/local transforms, Z-index
**Specifics:** Transform math, pivot compensation

### Node3D Domain
**Target Type:** Node3D nodes only  
**Properties:** position (Vector3), rotation (Vector3), scale (Vector3)
**Challenges:** 3D transforms, coordinate spaces, camera integration
**Specifics:** Spatial math, viewport transforms

---

## Domain Validation

### Type-Safe Validation
```gdscript
# L2 implements domain-specific validation:
class JuiceControl extends JuiceBase:
    func _validate_target() -> bool:
        return get_parent() is Control

class Juice2D extends JuiceBase:
    func _validate_target() -> bool:
        return get_parent() is Node2D

class Juice3D extends JuiceBase:
    func _validate_target() -> bool:
        return get_parent() is Node3D
```

### Property Validation
```gdscript
# L2 validates domain-specific properties:
class JuiceControl extends JuiceBase:
    func _validate_properties() -> bool:
        # Control only has position
        return target.has_method("set_position")

class Juice2D extends JuiceBase:
    func _validate_properties() -> bool:
        # Node2D has transform properties
        return target.has_method("set_position") and \
               target.has_method("set_rotation") and \
               target.has_method("set_scale")
```

---

## Domain-Specific Implementation

### Control Implementation
```gdscript
# L2 Control handles position-only coordination:
class JuiceControl extends JuiceBase:
    var _natural_base: Vector2
    
    func _capture_natural_base() -> void:
        _natural_base = target.position
    
    func _write_target_values(total_delta: Dictionary) -> void:
        if total_delta.has("position"):
            target.position = _natural_base + total_delta.position
```

### Node2D Implementation
```gdscript
# L2 Node2D handles transform coordination:
class Juice2D extends JuiceBase:
    var _natural_base: Dictionary = {"position": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE}
    
    func _capture_natural_base() -> void:
        _natural_base.position = target.position
        _natural_base.rotation = target.rotation
        _natural_base.scale = target.scale
    
    func _write_target_values(total_delta: Dictionary) -> void:
        if total_delta.has("position"):
            target.position = _natural_base.position + total_delta.position
        if total_delta.has("rotation"):
            target.rotation = _natural_base.rotation + total_delta.rotation
        if total_delta.has("scale"):
            target.scale = _natural_base.scale + total_delta.scale
```

### Node3D Implementation
```gdscript
# L2 Node3D handles 3D transform coordination:
class Juice3D extends JuiceBase:
    var _natural_base: Dictionary = {"position": Vector3.ZERO, "rotation": Vector3.ZERO, "scale": Vector3.ONE}
    
    func _capture_natural_base() -> void:
        _natural_base.position = target.position
        _natural_base.rotation = target.rotation_degrees
        _natural_base.scale = target.scale
    
    func _write_target_values(total_delta: Dictionary) -> void:
        if total_delta.has("position"):
            target.position = _natural_base.position + total_delta.position
        if total_delta.has("rotation"):
            target.rotation_degrees = _natural_base.rotation + total_delta.rotation
        if total_delta.has("scale"):
            target.scale = _natural_base.scale + total_delta.scale
```

---

## Domain-Specific Challenges

### Control Challenges
**Container Layout:**
```gdscript
# L2 Control handles container interference:
class JuiceControl extends JuiceBase:
    func _process(delta: float) -> void:
        super._process(delta)
        # Re-apply position every frame to beat container re-sort
        _apply_container_hold_pattern()
```

**Pixel Snapping:**
```gdscript
# L2 Control handles pixel coordinates:
func _write_target_values(total_delta: Dictionary) -> void:
    var final_pos = _natural_base.position + total_delta.position
    target.position = final_pos.round()  # Pixel snapping
```

### Node2D Challenges
**Pivot Compensation:**
```gdscript
# L2 Node2D handles missing pivot:
class Juice2D extends JuiceBase:
    func _apply_rotation_delta(delta: float) -> void:
        # Compensate for top-left pivot
        var pivot_offset = target.get_size() * 0.5
        target.position += pivot_offset
        target.rotation += delta
        target.position -= pivot_offset
```

### Node3D Challenges
**Coordinate Spaces:**
```gdscript
# L2 Node3D handles 3D coordinates:
class Juice3D extends JuiceBase:
    func _transform_to_local(delta: Vector3) -> Vector3:
        # Transform delta to local space
        return target.global_transform.basis * delta
```

---

## Cross-Domain Contracts

### Shared Contracts
All domains must implement:
- `_validate_target()` - Domain-specific validation
- `_capture_natural_base()` - Base value capture
- `_write_target_values()` - Single write coordination
- `_detect_external_move()` - External move detection

### Domain-Specific Contracts
Each domain implements:
- Domain-specific property handling
- Domain-specific challenge resolution
- Domain-specific optimization patterns

### Forbidden Cross-Domain Access
- Control nodes cannot access rotation/scale
- Node2D nodes cannot access 3D properties
- Node3D nodes cannot access 2D properties
- No cross-domain effect sharing

---

## Validation Rules

### Separation Validation
- [ ] Each domain only handles its target type
- [ ] No cross-domain property access
- [ ] Domain-specific challenges addressed
- [ ] Shared contracts implemented consistently

### Implementation Validation
- [ ] Type-safe validation works
- [ ] Property validation works
- [ ] Write coordination is domain-specific
- [ ] External move detection is domain-appropriate

### Architectural Validation
- [ ] L1 contracts honored in each domain
- [ ] L3 effects respect domain boundaries
- [ ] No cross-domain contamination
- [ ] Domain-specific optimizations present

---

## Cross-References

**Foundational Documents:**
- See L1-layer-contracts.md for domain contract definitions
- See ARCHITECTURE_BIG_PICTURE.md for domain strategy

**Implementation Documents:**
- See L2-write-coordination.md for write patterns
- See L2-sibling-stacking.md for stacking patterns

**Effect Documents:**
- See L3 docs for domain-specific effect patterns

---

## This Document's Role

### During Implementation
- **Separation Reference:** Ensure proper domain boundary implementation
- **Validation Guide:** Implement domain-specific validation correctly
- **Challenge Resolution:** Address domain-specific challenges

### During Refactoring
- **Separation Consistency:** Maintain domain boundaries across changes
- **Challenge Preservation:** Ensure domain-specific solutions are maintained
- **Contract Validation:** Verify domain contracts are honored

### For Developers
- **Domain Rules:** Understand what each domain can and cannot do
- **Implementation Guide:** Implement domain-specific code correctly
- **Challenge Solutions:** Know how to solve domain-specific problems

---

## Cross-References

**Foundational Documents:**
- See L1-layer-contracts.md for domain contract definitions
- See ARCHITECTURE_BIG_PICTURE.md for domain separation strategy

**Related L2 Documents:**
- See L2-write-coordination.md for domain write patterns
- See L2-sibling-stacking.md for domain stacking patterns

**L3 Integration:**
- See L3 docs for domain-specific effect implementation

This domain separation system ensures architectural integrity while enabling specialized implementations for each domain's unique challenges and requirements.
