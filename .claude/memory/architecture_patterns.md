# Juice V1 — Architecture Patterns & GDScript 2.0 Standards

> Canonical reference for how V1 code must be structured. Derived from `JuiceStack_Design.md` and existing V1 implementations.

## Core Architecture Pattern

### The Delta-First Model

```
JuiceBase (Node)                    # Drives lifecycle, triggers, timing
  └─ JuiceRecipe (Resource)         # Container for effects array
       └─ JuiceEffectBase[] (Resource)  # Pure delta calculators
```

**Flow per frame:**
1. Domain node detects external moves (pre-tick)
2. Domain node calls `effect.tick(progress, delta)` on each active effect
3. Each effect returns a **delta** (offset from natural state)
4. Domain node **sums all deltas** per channel (position, rotation, scale)
5. Domain node writes **once**: `target.property = base + sum(deltas)`

### Effects Are PURE Delta Calculators — Rules

1. Effects compute delta at given progress — nothing more
2. Effects **NEVER write** to the target node
3. Effects **NEVER track** contributions, base values, or last-written state
4. Effects **NEVER detect** external moves
5. Effects **NEVER implement** `_temporarily_undo/reapply_visual()`
6. Effects **capture From/To references** at animation start (node has undone visuals)
7. For TARGET references: the **node resolves** NodePath → the effect reads the resolved Node

### Domain Nodes Own Write Coordination

Each domain node (`JuiceControl`, `Juice2D`, `Juice3D`) implements:
1. **Base value capture** — natural state before any effects
2. **External-move detection** — once per frame, pre-tick
3. **Delta aggregation** — sum all active effects' deltas
4. **Write-once-per-frame** — after all effects tick
5. **`_temporarily_undo/reapply_visual()`** — for editor save pipeline
6. **Container hold pattern** (Control only) — re-apply every frame

## V1 Naming Conventions

| Category | Convention | Example |
|----------|------------|---------|
| Domain Nodes | `Juice[Domain]` | `JuiceControl`, `Juice2D`, `Juice3D` |
| Domain EffectBase | `Juice[Domain]EffectBase` | `JuiceControlEffectBase` |
| Domain Recipe | `Juice[Domain]Recipe` | `JuiceControlRecipe` |
| Concrete Effects | `[EffectName][Domain]JuiceEffect` | `TransformControlJuiceEffect` |
| Shared Base Classes | `JuiceXxx` | `JuiceBase`, `JuiceEffectBase` |
| File = class_name | Always match | `JuiceControl.gd` → `class_name JuiceControl` |

**Rule:** `Juice` always comes before the domain token. Domain goes in the middle for concrete effects (avoids `2DJuice` starting with digit).

## GDScript 2.0 Standards

### Typing
- **All variables must be typed**: `var speed: float = 10.0`
- **All function parameters typed**: `func apply(progress: float, target: Node) -> void:`
- **All return types declared**: `func get_delta() -> Vector2:`
- **Use `class_name`** for every script that needs external reference
- **Typed arrays**: `var effects: Array[JuiceEffectBase] = []`

### Script Decorators
- All addon scripts are `@tool` (run in editor)
- Use `@export` for inspector-facing configuration
- Use `@export_group()` and `@export_subgroup()` for organization
- Every configurable script has `@export var debug_enabled: bool = false`

### Script Section Ordering (Canonical)

| # | Section | Contents |
|---|---------|----------|
| 1 | Header comment | `##` class doc + `#` WHAT/WHY/SYSTEM block |
| 2 | Signals | `signal` declarations |
| 3 | Enums | `enum` declarations |
| 4 | Configuration | `@export` groups, backing vars |
| 5 | Conditional exports | `_validate_property()` or `_get_property_list()` |
| 6 | Internal state | Private vars, caches, flags |
| 7 | Lifecycle | `_ready()`, `_process()`, `_notification()` |
| 8 | Public API | `animate_in()`, `animate_out()`, `stop()` |
| 9 | Core logic | Domain-specific methods |
| 10 | Helpers | Small utility functions |
| 11 | Recipe/Sequencer | `_recipe_capture_natural()`, etc. |
| 12 | Config warnings | `_get_configuration_warnings()` |
| 13 | Virtual methods | `_apply_effect()` stubs |

### Comment Convention

| Syntax | Purpose | Visible in |
|--------|---------|------------|
| `## Brief sentence.` | Tooltip + script docs | Editor UI |
| `## @experimental` | Stability marker | Script docs badge |
| `# Single hash` | Dev notes, WHY | Source only |

### Anti-Patterns (NEVER DO)

- ❌ String IDs in arrays — use typed resource arrays
- ❌ Magic numbers — expose with `@export` and clear names
- ❌ Hardcoded node names — use `is` operator for discovery
- ❌ External dependencies (GameController, SignalBus)
- ❌ `get_node("Name")` — use type-safe discovery
- ❌ `child.name == "Something"` — use `child is SomeType`

### Type-Safe Discovery Pattern

```gdscript
func _find_component_on_node(parent: Node) -> MyComponent:
    for child in parent.get_children():
        if child is MyComponent:
            return child
    return null
```

### Conditional Export Pattern

```gdscript
@export var use_position: bool = false:
    set(v):
        use_position = v
        notify_property_list_changed()

func _validate_property(property: Dictionary) -> void:
    if property.name == "position_offset" and not use_position:
        property.usage = PROPERTY_USAGE_NO_EDITOR
```

## V1 Modes

| Mode | Description |
|------|-------------|
| **STACK** | All effects overlay simultaneously, deltas summed per channel |
| **SEQUENCER** | Effects fire in sequence with configurable stagger timing |

## Domain-Specific Differences

| Feature | Control | 2D | 3D |
|---------|---------|----|----|
| Position type | `Vector2` (pixels) | `Vector2` | `Vector3` |
| Rotation type | `float` (degrees) | `float` (radians) | `Vector3` (radians) |
| Scale type | `Vector2` | `Vector2` | `Vector3` |
| Container hold | ✅ Re-apply every frame | N/A | N/A |
| Pivot compensation | Position compensation | Position compensation | Position compensation |
| Position units | pixels, own_size, parent_size, viewport | local units | local units |

## Recipe System

- `JuiceRecipe` = `Resource` containing `Array[JuiceEffectBase]`
- Domain-specific recipes (`JuiceControlRecipe`, etc.) type-narrow the array
- Recipes are `.tres` files — savable, shareable, marketplace-ready
- Effects within a recipe can have `chain_to` pointers; unchained fire simultaneously