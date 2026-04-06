## RULE: Anti-Patterns

**Purpose:** Define prohibited patterns and common mistakes in Juice V1.

**Mission:** Prevent architectural violations and maintain code quality.

---

# ============================================================================
# WHAT: Juice V1 prohibited patterns and common mistakes
# EXPECTS: All Juice code avoids these anti-patterns
# PROVIDES: Code quality and architectural integrity
# ARCHITECTURE: Rules layer that prevents common mistakes
# ============================================================================

## Prohibited Patterns

### NEVER Do These

#### String IDs in Arrays
```gdscript
# ❌ WRONG - String IDs in arrays
var effects: Array[String] = ["shake", "bounce", "fade"]

# ✅ CORRECT - Typed resource arrays
var effects: Array[JuiceEffectResource] = [shake_res, bounce_res, fade_res]
```

#### Hardcoded Magic Numbers
```gdscript
# ❌ WRONG - Magic numbers
position.x += 42.5 * sin(time * 3.14)

# ✅ CORRECT - Inspector-exposed values
@export var shake_intensity: float = 42.5
@export var shake_frequency: float = 3.14
position.x += shake_intensity * sin(time * shake_frequency)
```

#### Hardcoded Node Names
```gdscript
# ❌ WRONG - Hardcoded node names
var my_component = get_node("MyComponent")

# ✅ CORRECT - Type-safe discovery
func _find_component_on_node(parent: Node) -> MyComponent:
    for child in parent.get_children():
        if child is MyComponent:
            return child
    return null
```

#### External Project Dependencies
```gdscript
# ❌ WRONG - External dependencies
var game_controller = get_node("/root/GameController")
game_controller.trigger_effect()

# ✅ CORRECT - Self-contained
@export var trigger_signal: Signal
trigger_signal.emit()
```

## Architectural Violations

### Effects Writing Directly to Targets
```gdscript
# ❌ WRONG - Effect writes to target
class BadEffect extends JuiceEffectBase:
    func _apply_effect():
        target.position = from.lerp(to, _progress)

# ✅ CORRECT - Effect calculates delta only
class GoodEffect extends JuiceEffectBase:
    func _get_seq_contribution() -> Dictionary:
        var current = from.lerp(to, _progress)
        var delta = current - _natural_base
        return {"position": delta}
```

### Domain Nodes Calculating Deltas
```gdscript
# ❌ WRONG - Domain calculates deltas
class BadDomain extends JuiceDomainBase:
    func _apply_effect():
        var delta = from.lerp(to, _progress)
        target.position += delta

# ✅ CORRECT - Domain aggregates only
class GoodDomain extends JuiceDomainBase:
    func _post_tick_write():
        var total_delta = Vector2.ZERO
        for effect in _active_effects:
            var contribution = effect._get_seq_contribution()
            total_delta += contribution.get("position", Vector2.ZERO)
        target.position = _base_position + total_delta
```

### Cross-Domain Dependencies
```gdscript
# ❌ WRONG - Cross-domain effects
class BadControlEffect extends JuiceControlEffectBase:
    func _apply_effect():
        # Control effects shouldn't handle rotation
        target.rotation = from_rotation.lerp(to_rotation, _progress)

# ✅ CORRECT - Domain-specific effects
class GoodControlEffect extends JuiceControlEffectBase:
    func _get_seq_contribution() -> Dictionary:
        # Control only handles position
        var current = from_position.lerp(to_position, _progress)
        var delta = current - _natural_base.position
        return {"position": delta}
```

## Development Anti-Patterns

### Assuming Features Are "Not Needed"
- **NEVER assume** a feature is "not needed" without user confirmation
- **ALWAYS discuss** scope reductions with user first
- **NEVER dismiss** use cases as "rare" without explicit confirmation

### Using Comments as Design Intent
- **NEVER use** script comments as authoritative design intent
- **Comments are development artifacts**, not requirements
- **ALWAYS verify** design intent with actual specifications

### Rushing to Quick Fixes
- **NEVER default** to hardcoded/specific solutions
- **ALWAYS consider** generic/extensible approaches
- **STOP and ask** when touching protocol boundaries
- **PRESENT tradeoffs** to user before implementing

### Incomplete Domain Coverage
- **If external-move detection** exists in one domain, it must exist in all domains
- **If a feature exists** in one domain, its absence in another is a bug
- **ALWAYS implement** features across all three domains

## Git Anti-Patterns

### PowerShell Command Chaining
```powershell
# ❌ WRONG - PowerShell doesn't support &&
git add -A && git commit -m "message"

# ✅ CORRECT - Use semicolon
git add -A; git commit -m "message"
```

### Large Batch Commits
```gdscript
# ❌ WRONG - Accumulate changes without commits
# ... 50 files changed ...
git add -A; git commit -m "Big refactor"

# ✅ CORRECT - Commit in logical units
git add -A; git commit -m "Create L1 documentation structure"
git add -A; git commit -m "Implement L2 write coordination"
```

## Validation Rules

### Anti-Pattern Detection
- [ ] No string IDs in arrays
- [ ] No hardcoded magic numbers
- [ ] No hardcoded node names
- [ ] No external project dependencies
- [ ] Effects calculate deltas only
- [ ] Domain nodes don't calculate deltas
- [ ] No cross-domain dependencies

### Development Quality
- [ ] All features discussed with user before reduction
- [ ] Comments not used as design intent
- [ ] Generic solutions preferred over specific
- [ ] All domains have equivalent features

---

## Cross-References

**Related Rules:**
- See RULE-coding-standards.md for proper patterns
- See RULE-architecture-contracts.md for architectural rules

**Implementation Guides:**
- See L1 docs for correct core patterns
- See L2 docs for correct domain patterns
- See L3 docs for correct effect patterns

This anti-patterns rule prevents common mistakes and maintains architectural integrity.
