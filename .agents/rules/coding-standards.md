## RULE: Coding Standards

**Purpose:** Define Juice coding standards and conventions.

**Mission:** Ensure consistent, maintainable code across all Juice components.

---

# ============================================================================
# WHAT: Juice coding standards and conventions
# EXPECTS: All Juice scripts follow these standards consistently
# PROVIDES: Quality baseline for code reviews and development
# ARCHITECTURE: Rules layer that enforces quality across all L1-3 components
# ============================================================================

## Script Structure

### Section Order (Canonical)
1. Header comment
2. Signals
3. Enums
4. Configuration (@export groups)
5. Conditional export system
6. Internal state (private vars)
7. Lifecycle (_ready, _process, _notification)
8. Public API (animate_in, animate_out, stop)
9. Core logic
10. Helpers
11. Recipe/Sequencer contract
12. Configuration warnings
13. Virtual methods

### Header Format
```gdscript
## Brief sentence.
# 
## Detailed description.
##
## @tutorial(Name): URL

# ============================================================================
# WHAT: What this script does
# EXPECTS: What it expects from parent/system
# PROVIDES: What it provides to parent/system  
# ARCHITECTURE: L1/L2/L3 position and relationships
# ============================================================================
```

## Naming Conventions

### Classes and Files
- **File = class_name** exactly
- **Juice Components:** `XxxJuiceComp` suffix
- **Juice Utilities:** `XxxJuiceUtility` suffix
- **Base Classes:** `XxxBase` suffix
- **Domain Nodes:** `Juice[Domain]` (JuiceControl, Juice2D, Juice3D)
- **Effects:** `[EffectName][Domain]JuiceEffect`

### Variables and Methods
- **Private:** `_snake_case` with underscore prefix
- **Public:** `snake_case`
- **Constants:** `UPPER_SNAKE_CASE`
- **Signals:** `snake_case`

## Anti-Patterns

### Never Do These
- **String IDs in arrays** - Use typed resource arrays
- **Hardcoded magic numbers** - Expose in inspector
- **Hardcoded node names** - Use type-safe discovery
- **External project dependencies** - Keep Juice standalone

### Type-Safe Discovery Pattern
```gdscript
func _find_component_on_node(parent: Node) -> MyComponent:
    for child in parent.get_children():
        if child is MyComponent:
            return child
    return null
```

## Documentation Standards

### Comments
- **`##`** for class documentation (visible in editor)
- **`#`** for internal documentation (source code only)
- **Single hash** for developer notes and architecture

### Inspector Tooltips
```gdscript
## Above @export - shows in inspector hover
@export var my_property: float = 1.0
```

## Git Standards

### PowerShell Commands
- **NEVER use `&&`** - PowerShell doesn't support it
- **Use semicolon:** `git add -A; git commit -m "message"`
- **Or run commands separately**

### Subtree Sync
```powershell
# Pull latest Juice
git subtree pull --prefix=addons/Juice_V2 juice-v2-standalone main --squash

# Push Demo fixes upstream  
git subtree push --prefix=addons/Juice_V2 juice-v2-standalone main
```

## Quality Requirements

### Every Script Must Have
1. **Header comment** explaining purpose and system
2. **Inspector-exposed configuration** for gameplay values
3. **Debug toggle** (`@export var debug_enabled: bool = false`)
4. **Comments explaining WHY**, not just what

### Validation Checklist
- [ ] Follows canonical section order
- [ ] Uses proper naming conventions
- [ ] Has complete header documentation
- [ ] Includes architectural context
- [ ] Avoids all anti-patterns

---

## Cross-References

**Related Rules:**
- See RULE-architecture-contracts.md for architectural rules
- See RULE-documentation-headers.md for header standards

**Implementation Guides:**
- See L1 docs for core patterns
- See L2 docs for domain coordination
- See L3 docs for effect implementation

This coding standards rule ensures quality and consistency across all Juice components.
