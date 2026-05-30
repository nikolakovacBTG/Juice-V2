# Juice Demo Project Rules

## Project Purpose

This is the **Juice Demo Project** — a standalone Godot 4.x project that showcases every component of the Juice (`addons/Juice_V2/`) addon. It serves as:

1. **Marketable demo** — polished visual demos for marketplace listing
2. **Beta testing** — real usage exposes real bugs
3. **Preset library** — ready-to-copy recipe scenes
4. **Documentation source** — footage capture, tutorials, GIFs

**Sync method:** Git Subtree via standalone Juice V2 repo.
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
1. **Header comment** explaining what it does, what system it belongs to, and what it does NOT handle.
2. **Inspector-exposed configuration** for gameplay values.
3. **Debug toggle** (`@export var debug_enabled: bool = false`).
4. **Method Documentation**: Use `##` for public methods AND virtual override points (`_apply_effect`, `_on_animate_start`, `_needs_sustain`, `_restore_to_natural`, `_on_animate_in_complete`, `_on_animate_out_complete`). Use `#` for internal helpers (private methods that are not meant to be overridden). This ensures F1 Help documents the subclass API while hiding plumbing.
5. **The Translation Rule (No Historical Baggage):** Transform legacy/versioning comments ('V0', 'ported', 'refactor') into structural rationale. Explain *why* the architecture demands a specific approach, without referencing past versions.

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
| `## Brief sentence.` | First line = Add Child Node tooltip. MUST be concise, action-oriented. | Tooltip + Script docs |
| `##` (blank) then `## Paragraph` | Detailed class description | Script docs viewer only |
| `## @tutorial(Name): URL` | Links to external docs/videos | Script docs "Online Tutorials" |
| `## @experimental` / `## @deprecated` | Stability markers | Script docs badge |
| `## Above @export` | Inspector property tooltip | Inspector hover + Script docs |
| `## Above public func` | Public API documentation & rationale | Script docs viewer only |
| `## Above virtual func _override` | Subclass API (methods effect authors override) | Script docs viewer only |
| `# Above private func _helper` | Internal logic documentation & rationale | Source code only |
| `# Single hash` | Dev notes, architecture, WHY. NEVER use for migration history. | Source code only |

**The `# WHY` Block Standard:**
The `# WHY:` block must define the class's architectural purpose and the constraints it enforces (e.g. 'Effects are pure delta calculators to prevent write-conflicts'). Do not explain migration history.

## Shell Commands (PowerShell)

- **NEVER use `&&`** for command chaining — PowerShell doesn't support it
- Use semicolon: `git add -A; git commit -m "message"`
- Or run commands separately

## Subtree Sync Commands

### Juice V2 (`addons/Juice_V2/` ↔ `https://github.com/nikolakovacBTG/Juice-V2.git`, branch `main`)

```powershell
# Pull latest V2 from standalone repo into Demo
git subtree pull --prefix=addons/Juice_V2 juice-v2-standalone main --squash

# Push Demo V2 fixes upstream to standalone repo
git subtree push --prefix=addons/Juice_V2 juice-v2-standalone main
```

### Remotes Reference

| Remote | URL | Used For |
|--------|-----|----------|
| `origin` | https://github.com/nikolakovacBTG/Juice-Demo.git | This demo repo |
| `juice-v2-standalone` | https://github.com/nikolakovacBTG/Juice-V2.git | Juice V2 addon (`addons/Juice_V2/`) |

## Godot Version

This project uses **Godot 4.x**. Use GDScript typed syntax and modern patterns.

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
| `@doc-sweep` | Skill | Auto: documentation work on `addons/Juice_V2/` | Quality standard card + per-file checklist + examples |
| `@juice-architecture` | Skill | Auto: touching `addons/Juice_V2/` | Architecture rules + code templates |
| `@verify-claims` | Skill | Auto: about to say "done/fixed/working" | Demands test evidence |
| `@juice-debug-logging` | Skill | Auto: adding logging to `addons/Juice_V2/` | Log points, templates, checklist |
| `/doc-sweep` | Workflow | Manual | Per-batch documentation sweep with context reset |
| `/test` | Workflow | Manual | Run test suite, categorize failures |
| `/bugfix` | Workflow | Manual | Structured fix cycle after test failures |
| `/port` | Workflow | Manual | Port V2 effect across domains (batches all 3 domains) |
| `/review` | Workflow | Manual | Code review against project standards |
| `/refactor` | Workflow | Manual | Systematic refactoring with validation |
| `/add-logging` | Workflow | Manual | Batch-oriented debug logging instrumentation |

**Composition chain:** `/port` → `@juice-architecture` + `@verify-claims` → `/test` → `/bugfix` if needed
**Documentation chain:** `/doc-sweep` → `@doc-sweep` (quality standard re-read per batch)
**Logging chain:** `/add-logging` → `@juice-debug-logging` + `@verify-claims` → `/test`

**When discussing Juice code changes and no skill/workflow has been invoked, remind the user which are available.**

---

## Pre-Ship Checklist

Tasks to complete before marketplace release:

- [ ] **Script section ordering pass** — Audit all `addons/juice/` scripts and reorder sections to match the canonical Script Section Ordering above. Priority targets: `TransformControlJuiceComp`, `JuiceCompBase`, `SequencerJuiceComp` (largest scripts with most drift).
