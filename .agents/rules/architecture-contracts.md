## RULE: Architecture Contracts

**Purpose:** Define Juice architectural contracts and boundaries.

**Mission:** Ensure architectural integrity across all Juice components.

---

# ============================================================================
# WHAT: Juice architectural contracts and boundaries
# EXPECTS: All Juice components respect L1-3 layer boundaries
# PROVIDES: Architectural integrity and system stability
# ARCHITECTURE: Rules layer that enforces L1-3 separation and contracts
# ============================================================================

## Layer Contracts

### L1 Core (Foundation)
- **Responsibility:** Core timing, interfaces, base classes
- **Boundaries:** Never touches domain-specific code
- **Contract:** Provides pure mathematical foundations

### L2 Domain (Coordination)
- **Responsibility:** Write coordination, delta aggregation
- **Boundaries:** Never calculates deltas directly
- **Contract:** Aggregates L3 deltas and writes once per frame

### L3 Effects (Implementation)
- **Responsibility:** Delta calculations only
- **Boundaries:** Never writes to targets directly
- **Contract:** Provides pure delta calculations to L2

## Delta-First Model Rules

### Effects Calculate Deltas Only
```gdscript
# ✅ CORRECT - Effect calculates delta
func _get_seq_contribution() -> Dictionary:
    var current = from.lerp(to, _progress)
    var delta = current - _natural_base
    return {"property": delta}

# ❌ WRONG - Effect writes to target
func _apply_effect():
    target.position = from.lerp(to, _progress)
```

### Domain Nodes Write Once Per Frame
```gdscript
# ✅ CORRECT - Domain aggregates and writes
func _post_tick_write():
    var total_delta = Vector2.ZERO
    for effect in _active_effects:
        var contribution = effect._get_seq_contribution()
        total_delta += contribution.get("position", Vector2.ZERO)
    target.position = _base_position + total_delta
```

## Domain Separation Rules

### Strict Domain Boundaries
- **Control:** Position only (no rotation/scale)
- **Node2D:** Full transform (position, rotation, scale)
- **Node3D:** Full 3D transform

### No Cross-Domain Dependencies
- Effects must extend domain-specific base classes
- No Control effects in Node2D domains
- No Node2D effects in Control domains

## External Move Detection Rules

### All Domains Must Detect
If external-move detection exists in one domain, it must exist in all domains.

### Generic Implementation
```gdscript
# ✅ CORRECT - Generic property detection
func _detect_external_move():
    for property in _tracked_properties:
        var current = target.get(property)
        if current != _last_written[property]:
            _recapture_base_values()
            break
```

## Container Hold Pattern Rules

### Control Only
Container hold pattern applies only to Control nodes inside Containers.

### Implementation Pattern
```gdscript
# ✅ CORRECT - Control-specific hold
func _process(delta):
    for entry in _held_entries:
        entry.effect._apply_effect(entry.progress)
```

## Validation Rules

### Architectural Compliance
- [ ] Effects never write directly to targets
- [ ] Domain nodes aggregate deltas before writing
- [ ] All three domains have equivalent features
- [ ] L1-3 boundaries are never crossed

### Contract Validation
- [ ] L1 provides pure mathematical foundations
- [ ] L2 coordinates but doesn't calculate
- [ ] L3 calculates but doesn't write
- [ ] Cross-domain dependencies don't exist

---

## Cross-References

**Related Rules:**
- See RULE-coding-standards.md for implementation standards
- See RULE-anti-patterns.md for prohibited patterns

**Implementation Guides:**
- See L1-layer-contracts.md for detailed L1-3 contracts
- See L2 docs for domain coordination patterns
- See L3 docs for effect implementation patterns

This architecture contracts rule ensures system integrity and proper L1-3 separation.
