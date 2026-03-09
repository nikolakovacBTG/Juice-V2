You are in CODING MODE.

Your task is to implement code ONLY after a design exists.
Assume the design is approved and complete.

---

## Authorization Gate (MANDATORY)

Before making ANY write changes, I must ask for explicit authorization if the work involves:

- **Migrations** (changing configs/behaviour across scenes or systems)
- **Any edits to** `.tscn`, `.tres`, `.res`
- **Any revert/restore/cleanup** (including undoing user testing tweaks)

If authorization is not explicitly given, I may only do read-only investigation (search, read, report).

If the user asks "can you start?", treat it as a capability/readiness question, not as authorization to begin changes.
Authorization is given by a normal positive/negative answer to a direct authorization question.

Primary goals:
- Clarity over cleverness
- Simplicity over abstraction
- Elegance through restraint
- Code that can be read and understood months later

General coding principles:
- No shorthand logic that harms readability.
- No unnecessary complexity.
- Prefer explicit steps over compressed expressions.
- Every script should be understandable in isolation.

## Feature Completeness (MANDATORY — enforces Global Rule #1)

- Implement ALL features from the approved design. Do NOT skip, simplify, or "phase" features unless the user explicitly authorizes it.
- Do NOT cut down functionality without authorization. If a feature is in the design, it MUST be in the code.
- Do NOT add stub/placeholder implementations that silently drop designed behavior.
- If implementation reveals a design gap, STOP and ask — do not silently reduce scope.
- The user decides what ships. The coder implements what was designed.

Godot-specific expectations:
- Assume Godot 4.x.
- Use composition-friendly patterns.
- Scripts should be reusable and inspector-driven.
- Avoid tight coupling between systems.
- Use type-safe discovery (see below).

For EVERY script you write, follow these rules:

---

### 1. Script Intent (MANDATORY HEADER COMMENT)

At the top of every script, include a comment explaining:
- What this script does
- Why it exists
- What system it belongs to
- What it explicitly does NOT handle

This explanation must be readable by a non-author.

---

### 2. Inspector-Exposed Configuration

- All gameplay-relevant values must be exposed in the inspector.
- These values should be clearly named and grouped.
- Assume designers will tweak these values without touching code.
- Hardcoded “magic numbers” are NOT allowed unless trivial and explained.

---

### 2b. Conditional Export Display (`_get_property_list` Pattern)

When a property should only appear in the inspector based on the value of another property (e.g., `custom_pivot` only visible when `pivot_mode == CUSTOM`):

**Use `_get_property_list()` + `_set()` + `_get()` for dynamic properties.** Do NOT use `@export` for properties that need conditional visibility.

**Key rules:**

1. **Backing variables** must be plain `var` (not `@export`). They are shown/hidden by `_get_property_list()`.
2. **Controlling variable** (the one that determines visibility of others) MUST have a **GDScript setter** that calls `notify_property_list_changed()`:
   ```gdscript
   var pivot_mode: int = PivotMode.AUTO_CENTER:
       set(value):
           pivot_mode = value
           notify_property_list_changed()
   ```
3. **In `_get_property_list()`**, conditionally include the dependent property:
   ```gdscript
   func _get_property_list() -> Array[Dictionary]:
       var props: Array[Dictionary] = []
       props.append({"name": "pivot_mode", "type": TYPE_INT, ...})
       if pivot_mode == PivotMode.CUSTOM:
           props.append({"name": "custom_pivot", "type": TYPE_VECTOR2, ...})
       return props
   ```
4. **`_set()` and `_get()`** must handle ALL conditional properties (even when hidden) so serialization works.

**CRITICAL: Do NOT rely on `notify_property_list_changed()` called only from `_set()`.** Godot may bypass `_set()` and set the member variable directly when a matching variable name exists on the class. The GDScript setter on the variable itself is the only reliable way to trigger the inspector refresh.

---

### 3. Debugging Strategy

- Debugging must be switchable via an exposed boolean flag.
- Debug output must:
  - Be silent when debug is disabled
  - Clearly describe what is happening when enabled
- Never remove debug logic; it must be safe to leave in production.

---

### 4. Comments & Explanation Style

Comments must:
- Explain WHY something is done, not just WHAT.
- Describe control flow when it is non-trivial.
- Clearly explain interactions with other systems.

Avoid:
- Obvious comments (e.g. “this sets a variable”)
- Over-commenting trivial one-liners

Use clear, plain language.
No abbreviations.
No implicit assumptions.

---

### 5. Connections to Other Systems

Whenever the script:
- Talks to another system
- Emits signals
- Receives external data
- Depends on autoloads or managers

You MUST explain in comments:
- What system it connects to
- Why the connection exists
- What data flows in or out
- What happens if that system is missing or inactive

---

### 6. Code Style & Structure

- One clear responsibility per script.
- Functions should be short and focused.
- Avoid deeply nested logic.
- Avoid clever tricks that reduce readability.
- Prefer early returns over complex branching where appropriate.

Code should feel:
- Calm
- Predictable
- Intentional

---

### 7. Folder Awareness (PATH PLACEHOLDERS)

DO NOT hardcode paths yet.

Instead, use clearly marked placeholders for later configuration:

- Demo scenes → [DEMOS_PATH]
- Presets → [PRESETS_PATH]
- Shared assets → [ASSETS_PATH]
- Documentation → [DOCUMENTATION_PATH]

These placeholders should be easy to replace later without refactoring code.

---

### 7b. MCP Scene Editing Safety (MANDATORY)

When creating or modifying nodes in Godot scenes via MCP tools:

**NEVER use `mcp0_duplicate_node` for nodes with children.**
Duplicated children lose their `owner` reference to the scene root, so Godot's serializer silently drops them on save. The nodes appear in the editor tree but vanish from the .tscn file.

**Instead:** Use `mcp0_execute_editor_script` to build node hierarchies programmatically, explicitly setting `node.owner = scene_root` for EVERY node (including all children, grandchildren, etc.).

**After any MCP scene edits:**
1. Save the scene (via editor script or manual save)
2. Verify the .tscn file is in the git changeset before committing: `git status` or `git diff --name-only`
3. If a scene file is missing from the changeset, the scene was NOT saved — re-save before committing

---

### 8. Error Handling & Safety

- Validate external references.
- Fail gracefully.
- When something is missing, log a clear debug message (if debug is enabled).
- Never assume a dependency exists unless enforced by design.

---

### 9. Final Quality Check (BEFORE RESPONDING)

Before outputting code, confirm:
- Assume this code will be maintained by someone who did not write it.
- The script matches the approved design.
- All important values are inspector-exposed.
- Debugging can be toggled.
- All external connections are documented.
- No unnecessary logic exists.

Rules:
- Do NOT redesign the system.
- Do NOT add features beyond the design.
- Do NOT optimize prematurely.
- Do NOT compress code for style points.
- Do NOT cut down functionality without authorization

If the design is unclear or missing:
- STOP.
- Ask precise clarification questions before writing code.

---

### 10. Project Architecture Patterns

The following patterns are established for this project. Follow them for consistency:

#### Addon Boundary
- `addons/juice/` is a **read-only subtree**. Do NOT modify files in it directly.
- If a bug is found, document it and fix in Cold Soul, then sync via subtree.

#### Demo Scene Pattern
- Each demo showcases 1-3 related comps in a visually appealing context
- Demos are self-contained scenes — drag into any project
- Every demo has a brief on-screen description of what's happening
- Presets are minimal scenes with just the juice comp stack — copy-paste ready

#### Type-Safe Discovery Pattern
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

---

### 11. Juice Subtree Sync (Demo Project Only)

Before starting new Juice development in the Demo project, ensure you have the latest changes:

// turbo
```powershell
git subtree pull --prefix=addons/juice juice-standalone main --squash
```

**Why this matters:** The Demo project's `addons/juice/` is a read-only subtree. All Juice development happens in Cold Soul, then gets synced here.

**Rule:** Do NOT modify files inside `addons/juice/` directly in the Demo project. If you find a bug, document it and fix it in Cold Soul, then sync.
