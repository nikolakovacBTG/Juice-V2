# Juice Demo Project Rules

## Project Purpose

This is the **Juice Demo Project** — a standalone Godot 4.x project that showcases every component of the Juice addon (`addons/juice/`). It serves as:

1. **Marketable demo** — polished visual demos for marketplace listing
2. **Beta testing** — real usage exposes real bugs
3. **Preset library** — ready-to-copy recipe scenes
4. **Documentation source** — footage capture, tutorials, GIFs

**Sync method:** Git Subtree via standalone Juice repo.
**Fix flow:** Fix directly in Demo → subtree push to standalone repo → pull into other projects as needed.

---

## Naming Conventions

| Category | Convention | Example |
|----------|------------|---------|
| **Juice Components** | `XxxJuiceComp` suffix | `TransformControlJuiceComp`, `Shake2DJuiceComp` |
| **Juice Utilities** | `XxxJuiceUtility` suffix | `CallMethodJuiceUtility`, `Interaction3DJuiceUtility` |
| **Base Classes** | `XxxBase` suffix | `JuiceCompBase` |
| **File = class_name** | Always match | `ActionDef.gd` → `class_name ActionDef` |
| **Demo scenes** | Descriptive, lowercase with underscores | `transform_control_demo.tscn` |

## Anti-Patterns (DO NOT)

- Do NOT use string IDs in arrays — use typed resource arrays
- Do NOT hardcode magic numbers — expose in inspector with clear names
- Do NOT find nodes by hardcoded string names — use type-safe discovery (see below)
- Do NOT add external project dependencies (GameController, SignalBus, etc.)

## Type-Safe Discovery Pattern

When searching for components or nodes dynamically:
- **Use `is` operator** for type checking: `if child is MyComponent:`
- **NEVER use hardcoded node names**: `get_node("MyComponent")` ← BAD
- **NEVER use string matching**: `if child.name == "MyComponent"` ← BAD

**Correct pattern:**
```gdscript
func _find_component_on_node(parent: Node) -> MyComponent:
    for child in parent.get_children():
        if child is MyComponent:
            return child
    return null
```

This ensures:
- Refactor-proof (renaming nodes doesn't break discovery)
- Type-safe (compiler catches errors)
- Marketable (works in any project without path assumptions)

## Juice Test Scenes (ALL 3 domains — ALWAYS)

When adding or modifying Juice components, test in ALL THREE domains:

| Domain | Scene File | Structure |
|--------|-----------|-----------|
| **Control** | TBD — Demo project control demo scene | Buttons with Juice comps auto-connected |
| **2D** | TBD — Demo project 2D demo scene | Node2D targets with Sprite2D + Interaction2DJuiceUtility |
| **3D** | TBD — Demo project 3D demo scene | Area3D with Interaction3DJuiceUtility + MeshInstance3D |

**NEVER skip the 2D test scene.** All three domains must have test coverage for every Juice component.

## Script Standards

Every script must have:
1. **Header comment** explaining what it does and what system it belongs to
2. **Inspector-exposed configuration** for gameplay values
3. **Debug toggle** (`@export var debug_enabled: bool = false`)
4. **Comments explaining WHY**, not just what

## Script Section Ordering

All Juice addon scripts follow a canonical top-down section order. Each section is delimited by a `# =====` banner comment. Skip sections that don't apply.

| Order | Section | What goes here |
|-------|---------|---------------|
| 1 | **Header comment** | `##` class doc + `#` WHAT/WHY/SYSTEM/DOES NOT block |
| 2 | **Signals** | `signal` declarations |
| 3 | **Enums** | `enum` declarations |
| 4 | **Configuration** | `@export` groups, backing `var`s, inspector-facing config |
| 5 | **Conditional export system** | `_validate_property()` or `_get_property_list()`/`_set()`/`_get()` |
| 6 | **Internal state** | Private `var`s, caches, flags (not inspector-exposed) |
| 7 | **Lifecycle** | `_ready()`, `_process()`, `_notification()` |
| 8 | **Public API** | `animate_in()`, `animate_out()`, `stop()`, static helpers |
| 9 | **Core logic** | Domain-specific methods (effect application, scene switching, etc.) |
| 10 | **Helpers** | Small utility functions, getters, converters |
| 11 | **Recipe / Sequencer contract** | `_recipe_capture_natural()`, `_inject_editor_cache()`, etc. |
| 12 | **Configuration warnings** | `_get_configuration_warnings()` |
| 13 | **Virtual methods** | `_apply_effect()`, `_on_animate_start()` stubs |

**Rationale:** Config at top (what designers care about), logic in middle (what devs care about), plumbing at bottom (rarely touched). Marketplace buyers browsing source find things predictably.

## Comment Convention

| Syntax | Purpose | Visible In |
|--------|---------|------------|
| `## Brief sentence.` | First line = Add Child Node tooltip | Tooltip + Script docs |
| `##` (blank) then `## Paragraph` | Detailed class description | Script docs viewer only |
| `## @tutorial(Name): URL` | Links to external docs/videos | Script docs "Online Tutorials" |
| `## @experimental` / `## @deprecated` | Stability markers | Script docs badge |
| `## Above @export` | Inspector property tooltip | Inspector hover + Script docs |
| `# Single hash` | Dev notes, architecture, WHY | Source code only (never in editor) |

## Shell Commands (PowerShell)

- **NEVER use `&&`** for command chaining — PowerShell doesn't support it
- Use semicolon: `git add -A; git commit -m "message"`
- Or run commands separately

## Subtree Sync Commands

```powershell
# Pull latest Juice from standalone repo into Demo
git subtree pull --prefix=addons/juice juice-standalone main --squash

# Push Demo fixes upstream to standalone repo
git subtree push --prefix=addons/juice juice-standalone main
```

## Godot Version

This project uses **Godot 4.x**. Use GDScript typed syntax and modern patterns.

---

## V1 Naming Conventions (`addons/Juice_V1/`)

| Category | Convention | Example |
|----------|------------|---------|
| **Domain Nodes** | `Juice[Domain]` | `JuiceControl`, `Juice2D`, `Juice3D` |
| **Domain EffectBase** | `Juice[Domain]EffectBase` | `JuiceControlEffectBase`, `Juice2DEffectBase` |
| **Domain Recipe** | `Juice[Domain]Recipe` | `JuiceControlRecipe`, `Juice2DRecipe` |
| **Concrete Effects** | `[EffectName][Domain]JuiceEffect` | `TransformControlJuiceEffect`, `Shake2DJuiceEffect` |
| **Shared Base Classes** | Unchanged | `JuiceBase`, `JuiceEffectBase`, `JuiceRecipe` |
| **File = class_name** | Always match | `JuiceControl.gd` → `class_name JuiceControl` |

**Rule:** `Juice` always comes before the domain token. This avoids invalid identifiers (`2DJuice` starts with digit). Effects put domain in the middle because they have a leading effect name (`Transform2DJuiceEffect`).

---

## V1 Architectural Rules (Sprint-Specific)

**Design doc:** `Documentation/JuiceStack_Design.md` is the authoritative reference. Every decision must trace back to it.

### Effects Are Pure Delta Calculators

1. Effects compute a **delta** (offset from natural state) at a given progress — nothing more
2. Effects **NEVER write** to the target node — the domain node writes once per frame
3. Effects **NEVER track** `_my_*_contribution`, `_last_written_*`, or `_base_*` — that's node work
4. Effects **NEVER detect** external moves — the domain node does that once per frame, pre-tick
5. Effects **NEVER implement** `_temporarily_undo_visual()` / `_temporarily_reapply_visual()` — the domain node does
6. Effects **capture their own From/To references** at animation start (when the node has temporarily undone all visuals)
7. For `TARGET` references (From/To pointing to another node): the **node resolves** the NodePath and provides the resolved Node to the effect. The effect reads it but never resolves paths.

### Domain Nodes Own Write Coordination

Each domain node (`JuiceControl`, `Juice2D`, `Juice3D`) implements:

1. **Base value capture** — natural position/rotation/scale before any effects
2. **External-move detection** — once per frame, pre-tick: did something else change the target?
3. **Delta aggregation** — sum all active effects' deltas per channel (position, rotation, scale)
4. **Write-once-per-frame** — `target.property = base + sum(deltas)`, applied after all effects tick
5. **`_temporarily_undo/reapply_visual()`** — subtract/add total contribution for editor save pipeline
6. **Container hold pattern** (Control only) — re-apply every frame to beat deferred `_sort_children()`
7. **JIT `_pre_tick()` in `_start_effects()`** — called before `_temporarily_undo_visual()` to catch layout shifts while idle. All 5 L2 virtual methods (`_capture_base_values`, `_pre_tick`, `_post_tick_write`, `_temporarily_undo_visual`, `_temporarily_reapply_visual`) MUST have stubs in `JuiceBase` — without them, domain overrides are silently dead. See `CONTRACTS/l2-domain.md § Protected Invariants`.

### All Three Domains — Always

- When implementing ANY node-level feature, implement it in **all 3 domain nodes** before moving on
- If a feature exists in one domain, its absence in another domain is a **bug**
- The only domain-specific differences are: property types (Vector2 vs Vector3), Container hold (Control only), pivot compensation math

### Build Order

1. `JuiceBase` infrastructure (hooks, virtual methods)
2. All 3 domain nodes (JuiceControl, Juice2D, Juice3D) — simultaneously
3. Strip effects to pure delta calculators — all 3 domains simultaneously
4. Verify stacking + Container behavior

### Anti-Drift

- Before implementing, **re-read the relevant section** of `JuiceStack_Design.md`
- If implementation differs from design doc, **STOP and ask** — don't rationalize the deviation
- If a design gap is discovered, **document it and ask** — don't fill it silently

---

## Verification Rule (MANDATORY)

**Never claim a feature works without citing a test name and its result.**

- If a test exists: cite `suite_name::test_method` and whether it PASSes
- If no test exists: say "NO TEST EXISTS" and write one before claiming completion
- Code review is not verification. Only test results can mark something ✅.

## Skills & Workflows Integration

The following skills and workflows form a composable system for quality control:

| Tool | Type | Trigger | Purpose |
|------|------|---------|---------|
| `@juice-architecture` | Skill | Auto: touching `addons/Juice_V1/` | Architecture rules + code templates |
| `@verify-claims` | Skill | Auto: about to say "done/fixed/working" | Demands test evidence |
| `/test` | Workflow | Manual | Run test suite, categorize failures |
| `/bugfix` | Workflow | Manual | Structured fix cycle after test failures |
| `/port` | Workflow | Manual | Port V0 effect to V1 (batches all 3 domains) |
| `/review` | Workflow | Manual | Code review against project standards |
| `/refactor` | Workflow | Manual | Systematic refactoring with validation |

**Composition chain:** `/port` → `@juice-architecture` + `@verify-claims` → `/test` → `/bugfix` if needed

**When discussing V1 code changes and no skill/workflow has been invoked, remind the user which are available.**

---

## Pre-Ship Checklist

Tasks to complete before marketplace release:

- [ ] **Script section ordering pass** — Audit all `addons/juice/` scripts and reorder sections to match the canonical Script Section Ordering above. Priority targets: `TransformControlJuiceComp`, `JuiceCompBase`, `SequencerJuiceComp` (largest scripts with most drift).
