## RULE: V2 Anti-Patterns

**Purpose:** Define V2-specific prohibited patterns that build on the existing `anti-patterns.md`.

**Scope:** Only applies to code in `addons/Juice_V2/`. Does not replace `anti-patterns.md` — extends it.

---

## Domain Node Anti-Patterns

### No `_process()` in Domain Nodes

```gdscript
# ❌ WRONG — domain node ticking
class_name Juice2D extends JuiceBase
func _process(delta):
    _tick_effects(delta)

# ✅ CORRECT — orchestrator owns the tick
# Domain node has no _process(). JuiceOrchestrator._process() ticks effects.
```

**Why:** Domain nodes are thin wiring. Animation lifecycle is the orchestrator's job.

### No `_validate_property()` in Domain Nodes

```gdscript
# ❌ WRONG — domain node hiding properties
func _validate_property(property):
    if property.name == "some_effect_prop":
        property.usage |= PROPERTY_USAGE_NO_EDITOR

# ✅ CORRECT — inspector plugin handles visibility
# JuiceEditorInspectorPlugin._parse_property() controls what's visible.
```

**Why:** Property visibility is an editor concern, owned by `JuiceEditorInspectorPlugin`.

### No Preview Code in Domain Nodes

```gdscript
# ❌ WRONG — preview lifecycle in domain node
func _start_preview():
    _cloned_effects = _clone_recipe()
    _is_previewing = true

# ✅ CORRECT — preview is orchestrator's job
# JuicePreviewDirector creates a PREVIEW-mode JuiceOrchestrator.
```

**Why:** Editor preview is owned by `JuicePreviewDirector` + orchestrator (PREVIEW mode).

### Limited `Engine.is_editor_hint()` in Domain Nodes

```gdscript
# ❌ WRONG — scattered editor guards
func _process(delta):
    if Engine.is_editor_hint():
        _do_editor_thing()
    else:
        _do_runtime_thing()

# ✅ CORRECT — single guard in _ready() only
func _ready():
    if Engine.is_editor_hint():
        return  # Only runtime spawns the orchestrator
    _spawn_runtime_orchestrator()
```

**Why:** Domain nodes should have at most ONE editor guard — the `_ready()` skip. All other editor logic lives in the plugin/orchestrator.

---

## Orchestrator Anti-Patterns

### No Per-Trigger Allocation at Runtime

```gdscript
# ❌ WRONG — spawning a new orchestrator per trigger
func animate_in():
    var orch = JuiceOrchestratorFactory.create(recipe, target, Mode.RUNTIME)
    add_child(orch)  # New node every trigger = GC stutter

# ✅ CORRECT — reuse existing orchestrator
func animate_in():
    _orchestrator.reset()  # Clears state, restarts — zero allocation
```

**Why:** RUNTIME orchestrators are persistent. `reset()` avoids GC pressure from repeated `queue_free()` + `add_child()`.

### `queue_free()` Only in PREVIEW Mode

```gdscript
# ❌ WRONG — freeing runtime orchestrator
func _on_animation_complete():
    _orchestrator.queue_free()  # Leaked reference, GC stutter on retrigger

# ✅ CORRECT — only PREVIEW orchestrators free themselves
# RUNTIME: stays alive, idles until next trigger
# PREVIEW: queue_free() on teardown (editor performance doesn't matter)
```

---

## Cross-References

- `anti-patterns.md` — general Juice anti-patterns (still applies)
- `v2-architecture-contracts.md` — the contracts these anti-patterns enforce
- `v2-tool-surface.md` — what may be `@tool`
