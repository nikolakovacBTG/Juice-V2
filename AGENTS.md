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
