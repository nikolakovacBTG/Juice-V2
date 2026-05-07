## RULE: V2 Architecture Contracts

**Purpose:** Define V2-specific architectural boundaries that build on the existing L1-L3 layer contracts.

**Scope:** Only applies to code in `addons/Juice_V2/`. Does not replace `architecture-contracts.md` — extends it.

---

## L2 Domain Split: Runtime vs Editor

V2 separates L2 into two sub-layers. The existing L1-L3 contracts remain unchanged.

### L2-Runtime (Domain Nodes)

Domain nodes (`JuiceBase`, `Juice2D`, `Juice3D`, `JuiceControl`) are **thin wiring** in V2:

| Responsibility | How |
|---------------|-----|
| Spawn orchestrator | `_ready()` creates one `JuiceOrchestrator` via factory (RUNTIME mode) |
| Config warnings | `_get_configuration_warnings()` calls `JuiceConfigValidator.validate(self)` |
| Hold recipe reference | `@export var recipe` — serialized, inspector-visible |
| Hold target reference | `@export var target` — serialized, inspector-visible |

Domain nodes have **zero** `_process()`, **zero** preview code, **zero** `_validate_property()`.

### L2-Editor (Plugin + Orchestrator)

Editor concerns live in dedicated editor classes:

| Class | Responsibility |
|-------|---------------|
| `JuiceEditorInspectorPlugin` | Property visibility, inspector layout (`_parse_property()`) |
| `JuicePreviewDirector` | Editor transport (play/stop/scrub), spawns PREVIEW orchestrators |
| `juice_plugin.gd` | Plugin lifecycle, registers inspector plugin |

---

## Orchestrator Contract (Single Class, Mode Enum)

`JuiceOrchestrator` is a single `@tool` class with two lifecycle modes:

```
JuiceOrchestrator
├── Mode.PREVIEW  → transient, queue_free() on teardown
└── Mode.RUNTIME  → persistent, reset() on retrigger (zero allocation)
```

### Mode Behaviors

| Event | PREVIEW | RUNTIME |
|-------|---------|---------|
| Animation completes | `teardown()` → restore → `queue_free()` | `_on_complete()` → restore → idle |
| Stop requested | `teardown()` → restore → `queue_free()` | `stop()` → restore → idle |
| Retrigger | N/A | `reset()` → restart (no reallocation) |

### Invariants

- RUNTIME orchestrator is spawned **once** in `_ready()`, lives until `_exit_tree()`.
- PREVIEW orchestrator is spawned by `JuicePreviewDirector`, freed on teardown.
- Both modes use `JuiceLedger` for delta registration — orchestrator is a `source_id`.
- `@tool` on the orchestrator is harmless — dynamically spawned nodes are never serialized.

---

## JuiceConfigValidator Contract

`JuiceConfigValidator` is a **static utility class** (no Node inheritance, no `@tool`):

- Pure-read validation: checks recipe assignment, target assignment, effect registration.
- Called from domain nodes' `_get_configuration_warnings()`.
- Has no timing dependencies on `_validate_property()` or resource load order.

---

## Cross-References

- `architecture-contracts.md` — L1-L3 layer contracts (unchanged, still applies)
- `v2-tool-surface.md` — what may be `@tool` and why
- `v2-anti-patterns.md` — V2-specific prohibited patterns
