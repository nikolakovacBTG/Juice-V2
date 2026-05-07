## RULE: V2 @tool Surface Whitelist

**Purpose:** Define exactly which files may use `@tool` in `addons/Juice_V2/` and why.

**Scope:** Only applies to code in `addons/Juice_V2/`.

---

## Whitelist

### Domain Nodes — `@tool` for config warnings only

| File | Why `@tool` is needed |
|------|----------------------|
| `JuiceBase.gd` | `_get_configuration_warnings()` requires `@tool` to display scene-tree warning icons |
| `Juice2D.gd` | Inherits from `JuiceBase` — same reason |
| `Juice3D.gd` | Inherits from `JuiceBase` — same reason |
| `JuiceControl.gd` | Inherits from `JuiceBase` — same reason |

**Constraint:** Domain nodes must have **zero** `_process()`, **zero** preview code, **zero** `_validate_property()`. The only permitted `Engine.is_editor_hint()` guard is in `_ready()` to skip orchestrator spawning in the editor.

### Effect Resources — `@tool` for dynamic inspector

All effect Resource scripts (extending `JuiceEffectBase` and domain-specific bases) keep `@tool` because:

- `_get_property_list()` on Resources requires `@tool` to dynamically show/hide properties when the user changes an enum in the inspector.
- Resources have no `_process()`, `_ready()`, or scene tree lifecycle — zero runtime overhead.

### Editor Classes — `@tool` by necessity

| File | Why `@tool` is needed |
|------|----------------------|
| `juice_plugin.gd` | EditorPlugin — must be `@tool` |
| `JuiceEditorInspectorPlugin.gd` | EditorInspectorPlugin — must be `@tool` |
| `JuicePreviewDirector.gd` | Runs preview animations in-editor — must be `@tool` |
| `JuiceOrchestrator.gd` | Ticks `_process()` for both preview and runtime — must be `@tool` |

---

## Enforcement

Any file in `addons/Juice_V2/` with `@tool` that is NOT on this whitelist is a **bug**.

To verify: `grep -r "^@tool" addons/Juice_V2/ --include="*.gd"` — every match must appear in this whitelist.

---

## Cross-References

- `v2-architecture-contracts.md` — why domain nodes are gutted
- `v2-anti-patterns.md` — what domain nodes must NOT contain
