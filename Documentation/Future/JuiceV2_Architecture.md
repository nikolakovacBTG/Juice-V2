# Juice V2 Architecture Design Proposal

> **Status**: Design proposal. Not scheduled. Captures architectural decisions reached during
> V1 production and the TileMapLayer ledger-snap diagnostic (May 2026).
>
> **Audience**: Future self, contributors, or the AI pair-programmer resuming this codebase.
> This document must not rot — update it when assumptions are invalidated.

---

## 1. Why This Document Exists

During V1 production, a specific bug (TileMapLayer position snapping to origin) led to a
root-cause diagnosis that exposed a broader architectural decision: the `juice_active_ledger`
was stored as Godot node metadata (`Node.set_meta()`), causing it to be serialized into
`.tscn` files. Ledger data is session-transient — it does not belong in the serialization
pipeline at all.

The V1 fix (static dictionary in `JuiceLedger.gd`) is correct and sufficient for V1. But
the diagnosis surfaced a deeper pattern: V1 domain nodes (`Juice2D`, `Juice3D`,
`JuiceControl`) carry **three distinct responsibilities** inside a single `@tool` script,
and the friction caused by this is not accidental — it is structural.

V2 exists to separate those responsibilities at the class boundary.

---

## 2. The V1 Structural Problem

### 2.1 Three responsibilities in one class

A V1 domain node (`Juice2D`) simultaneously:

1. **Carries user configuration** — exported properties, recipe reference, inspector display
2. **Coordinates runtime animation** — multi-writer ledger, delta aggregation, process tick
3. **Serves as the substrate for editor transport preview** — `_enter_editor_preview`,
   `_exit_editor_preview`, `_editor_preview_active` flag, `_deferred_editor_preview_init`

These are genuinely different jobs with different lifetimes, different state requirements,
and different serialization contracts. Packing them into one class requires:

- `Engine.is_editor_hint()` guards throughout `_ready()`, `_process()`, `_notification()`
- A behavioral mode-switch flag (`_editor_preview_active`) that prevents the wrong behavior
  from running at the wrong time
- `call_deferred()` timing gymnastics to handle the editor's deferred initialization order
- Metadata on target nodes that leaks into scene files

### 2.2 The `@tool` tax

Because domain nodes participate in editor preview, they must be `@tool` scripts. This has
three costs:

**A. Serialization surface.** Every `set_meta()` call on a `@tool` node's target becomes
a candidate for `.tscn` serialization. The ledger bug is a direct consequence of this.

**B. Inspector coupling.** `_validate_property()` — which powers the dynamic inspector
(show/hide properties based on other property values) — only runs on `@tool` scripts. This
ties the inspector UX logic to the domain class, making it impossible to separate without
rearchitecting the inspector layer.

**C. Editor overhead.** Every `@tool` script runs `_notification()`, `_validate_property()`,
`_get_configuration_warnings()` in the editor for every frame the scene is open. With a
complex demo scene, this is dozens of Juice nodes processing editor callbacks constantly,
for no runtime benefit.

### 2.3 The duality stink

The symptom of the above: `Engine.is_editor_hint()` appears ~8 times in `JuiceBase.gd`.
Each occurrence represents a place where one class is doing two jobs and branching on
environment. Every branch is a potential bug surface. The TileMapLayer snap bug was born
in exactly this context — the deferred init that works in runtime has different timing
semantics in the editor.

---

## 3. V2 Proposed Architecture

### Core principle

> **Separate editor concerns from runtime concerns at the class boundary, not via branching flags.**

Editor code and runtime code must not share a class. When they must share a target node,
they communicate through a defined interface, not through shared mutable state on the
target.

### 3.1 Domain nodes — runtime only, NOT `@tool`

`Juice2D`, `Juice3D`, `JuiceControl` become pure runtime scripts:

- No `@tool` tag
- No `Engine.is_editor_hint()` anywhere
- No `_enter_editor_preview` / `_exit_editor_preview`
- No `_editor_preview_active` flag
- `_ready()` has one path. `_process()` has one path.
- Responsibility: hold recipe, coordinate runtime animation via ledger, respond to triggers

This reduces domain scripts by an estimated 30-40% in line count and eliminates all
timing-sensitive editor guard code.

### 3.2 JuiceLedger — static in-memory dictionary (already fixed in V1)

The V1 static dict fix is the correct permanent solution:

```gdscript
# JuiceLedger.gd
static var _store: Dictionary = {}  # keyed by target.get_instance_id()
```

Never serialized. Purely in-memory. Self-cleaning via existing `cleanup_source` contract
(called from `_exit_tree`). The V1 fix is the V2 implementation for this component.

### 3.2b Runtime orchestration — the same "born, do job, die" pattern at runtime

In V1, the domain node owns `_process` and drives effects itself. In V2, runtime animation
follows the exact same pattern as editor preview — a dynamically spawned Node handles
execution while the domain node becomes a pure configuration carrier.

```
animate_in() called on Juice2D
  → Spawn JuiceRuntimeOrchestrator(recipe, target)  — regular Node, NOT @tool
  → Orchestrator owns cloned effects, ledger entries, delta accumulation
  → Orchestrator._process drives animation each frame
  → On completion or stop(): orchestrator queue_free()’s itself
```

The pattern is symmetric:

| Context | Orchestrator type | `@tool`? |
|---------|-------------------|----------|
| Editor transport preview | `JuicePreviewOrchestrator` | ✅ (needs editor `_process`) |
| Runtime animation | `JuiceRuntimeOrchestrator` | ❌ (pure runtime) |

No autoload singleton. No centralized driver. Each orchestrator is self-managing: it
registers its ledger source on spawn, deregisters on free. The domain node (`Juice2D`)
reduces to: hold recipe, resolve target, respond to triggers, spawn the orchestrator.

Domain node `_process` is removed entirely. It has no process tick when idle — zero
runtime overhead for inactive Juice nodes, which is the common case.

**Lifecycle ownership:** The orchestrator is added as a child of the domain node (or a
dedicated transient child of the scene root). When the scene is freed, it is freed
automatically. Explicit cleanup via `stop()` calls `queue_free()` early.

**Multi-writer stacking** is unchanged: the ledger handles multiple orchestrators writing
to the same target simultaneously. This is already the V1 contract and carries forward
without modification.

### 3.3 JuicePreviewOrchestrator — the "born, do job, die" pattern

A dynamically instantiated `@tool` node, created by the plugin when a Juice node is
selected, and destroyed on deselection.

```
Plugin.selection_changed(juice_node)
  → Spawn JuicePreviewOrchestrator(juice_node)
  → Orchestrator.setup() — clone recipe, resolve target, prepare ledger state
  
User clicks Play
  → Orchestrator.play() — own _process loop begins, drives effects, writes to target

User deselects or clicks Stop
  → Orchestrator.teardown() — restore target to natural state
  → queue_free() — all state destroyed, zero persistence
```

**Key properties of the orchestrator:**
- IS `@tool` — owns its own `_process` tick in the editor
- Clones the recipe effects into its own in-memory array (never touches recipe resources)
- Uses the same delta/flush pattern as runtime Juice nodes — same output, different context
- Zero persistent state. Nothing written to target nodes beyond animation deltas.
- Holds a reference to the target; on teardown, restores natural state via its own ledger
  (local to the orchestrator instance, freed when it is)

**What this eliminates from domain nodes:**
- `_enter_editor_preview()` / `_exit_editor_preview()`
- `_editor_preview_active` flag
- `_deferred_editor_preview_init()`
- `_runtime_effects` (the cloned preview array) — orchestrator owns this instead
- All `Engine.is_editor_hint()` guards in `_process` and `_ready`

**What the test implications are:**
- Transport preview tests now test `JuicePreviewOrchestrator` directly
- Domain node tests are purely runtime and headless-compatible without special guards
- The headless/editor tier distinction becomes less necessary for domain behavior

**Relationship to JuiceEditorInspectorPlugin:**
The inspector plugin and the preview orchestrator are independent. The inspector plugin
handles *property display* — it never needs to know whether an orchestrator is active.
The orchestrator handles *animation execution* — it never touches inspector state.
They share no interface. The plugin spawns both independently: inspector plugin is
registered once at plugin load; orchestrators are spawned/killed per selection event.

**Spawning contracts — not just user selection:**
Orchestrators (both editor and, if adopted, runtime bindings) must be spawnable by
more than one caller:

1. **User selection in editor** — `JuicePreviewDirector` spawns on inspector click
2. **Sequencer orchestration** — the SEQUENCER mode imposes a recipe onto multiple
   targets, potentially in sequence. Each target gets its own orchestrator/binding.
   The sequencer must be able to spawn, control, and kill orchestrators for arbitrary
   targets that are not necessarily the Juice node's own parent.
3. **Nested scene targets** — a target may itself be an instanced scene containing
   Juice nodes at multiple nesting levels. The spawning contract must not assume a
   flat parent/child relationship. Orchestrators must accept any `Node` as target,
   resolved via the same NodePath logic already in `_resolve_target()`.

The spawning interface must therefore be a factory/service, not a method on the domain
node. A `JuiceOrchestratorFactory.create(recipe, target, mode)` pattern decouples
callers from orchestrator construction and allows sequencers and nested scenes to
produce orchestrators identically to the transport preview path.

### 3.4 JuiceEditorInspectorPlugin — conditional inspector without `@tool`

In V1, `_validate_property()` on domain nodes provides dynamic inspector behavior:
properties appear or disappear based on other property values (e.g. `trigger_source_path`
is hidden unless `trigger_source == NODE`).

This requires `@tool`. In V2, it must not.

**Solution:** Register a `JuiceEditorInspectorPlugin` (extends `EditorInspectorPlugin`)
from `juice_plugin.gd`. This plugin intercepts property display for all Juice node types
and applies the same show/hide logic, but from the plugin side.

```gdscript
# juice_plugin.gd
func _enter_tree() -> void:
    _inspector_plugin = JuiceEditorInspectorPlugin.new()
    add_inspector_plugin(_inspector_plugin)

func _exit_tree() -> void:
    remove_inspector_plugin(_inspector_plugin)
```

```gdscript
# JuiceEditorInspectorPlugin.gd
extends EditorInspectorPlugin

func _can_handle(object: Object) -> bool:
    return object is JuiceBase  # catches all domain nodes

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide) -> bool:
    # Replicate the _validate_property() logic here
    # Return true to suppress/override, false to allow default display
    ...
```

All `_validate_property()` methods on domain nodes are deleted. The domain class no longer
knows or cares about inspector display. This is a clean separation: the inspector plugin
is editor code; the domain node is runtime code.

**Implementation note:** `EditorInspectorPlugin._parse_property` gives full control over
property visibility. The existing `_validate_property` logic (which is already well-
documented per the project standards) maps directly to `_parse_property` conditions with
no semantic loss.

### 3.5 Plugin as the sole `@tool` surface

After V2:

| Class | `@tool`? | Reason |
|-------|----------|--------|
| `juice_plugin.gd` | ✅ | EditorPlugin requires it |
| `JuicePreviewOrchestrator` | ✅ | Must run `_process` in editor |
| `JuiceEditorInspectorPlugin` | ✅ | EditorInspectorPlugin requires it |
| `JuicePreviewDirector` | ✅ | Manages orchestrator lifecycle, owned by plugin |
| `Juice2D`, `Juice3D`, `JuiceControl` | ❌ | Pure runtime |
| `JuiceBase` | ❌ | Pure runtime base |
| `JuiceLedger` | ❌ | Static utility, no editor dependency |
| All effect resources | ❌ | Resource subclasses, no editor code |
| All recipe resources | ❌ | Resource subclasses, no editor code |

The editor surface is confined to four known, purpose-built classes. Everything else is
runtime code that can be reasoned about without editor context.

---

## 4. Migration Path V1 → V2

This is sequential. Each phase must gate before the next begins.

### Phase V1-fix (current sprint)
Static dict ledger migration. See `STUB: JuiceLedger Static Dict Fix (V1)` plan.
This is a prerequisite for V2 — it eliminates serialization leakage before the @tool
removal, so the removal is clean.

### Phase V2-A: EditorInspectorPlugin
- Create `JuiceEditorInspectorPlugin.gd`
- Port all `_validate_property()` logic from all domain nodes into `_parse_property()`
- Delete `_validate_property()` from all domain nodes
- Register/deregister plugin from `juice_plugin.gd`
- Gate: all inspector show/hide behavior verified manually per domain; suite unchanged

### Phase V2-B: JuicePreviewOrchestrator
- Create `JuicePreviewOrchestrator.gd` (@tool)
- Port preview lifecycle from domain nodes: effect cloning, process tick, write-to-target
- Modify `JuicePreviewDirector` to spawn/kill orchestrators instead of calling
  `_enter_editor_preview` / `_exit_editor_preview` on domain nodes
- Gate: transport suite passes; manual preview test on all three domain types

### Phase V2-C: Strip @tool from domain nodes
- Remove `@tool` from `JuiceBase.gd`, `Juice2D.gd`, `Juice3D.gd`, `JuiceControl.gd`
- Remove all `Engine.is_editor_hint()` guards
- Remove `_enter_editor_preview`, `_exit_editor_preview`, `_editor_preview_active`,
  `_deferred_editor_preview_init` from `JuiceBase.gd`
- Remove `_runtime_effects` cloning (owned by orchestrator now)
- Remove `NOTIFICATION_EDITOR_PRE_SAVE` handler (baking moved to plugin `_save_external_data`)
- Gate: full headless suite unchanged; editor preview verified via MCP (Tier 2)

### Phase V2-D: Clean configuration warnings
- Move `_get_configuration_warnings()` logic to inspector plugin or a dedicated checker
  called by the plugin on scene change
- Gate: warnings still appear correctly in editor; suite unchanged

### Phase V2-E: Systematic effect porting

All concrete effect classes (Transform, Shake, Noise, ProgressTransform, Appearance,
VFX, Camera, Screen, Trail, etc.) currently contain editor-specific code paths — mainly
`_on_editor_pre_save()` baking logic and any `_validate_property()` delegates.
These must be audited and migrated as part of the @tool removal.

**Porting checklist per effect:**
- [ ] Remove any `Engine.is_editor_hint()` guards
- [ ] Move `_on_editor_pre_save()` baking to the plugin's `_save_external_data()` call chain
- [ ] Verify `CaptureAt` logic works without editor-specific branches
- [ ] Confirm effect is registered in all three domain recipes (existing `/port` workflow gate)
- [ ] Run per-domain test suite (headless) + Tier 2 MCP test for editor preview

**Order:** Port effects in the same domain-first order as the `/port` workflow: 2D → Control
→ 3D per effect family. This mirrors the existing testing infrastructure.

**Risk area:** Effects that bake their From/To snapshots at `NOTIFICATION_EDITOR_PRE_SAVE`
must be confirmed to produce identical baked output via the plugin's pre-save path.
Write a regression test that compares baked values before and after the port.

- Gate: all effect unit suites unchanged; baked cache regression test passes for all
  CaptureAt.IN_EDITOR effects

---

## 5. Benefits Summary

| Concern | V1 | V2 |
|---------|----|----|
| Domain node size | ~2300 lines (JuiceBase) | Est. ~1500 lines |
| `Engine.is_editor_hint()` occurrences | ~8 in JuiceBase | 0 |
| Serialization leakage risk | Mitigated by static dict, still possible via @tool | Structurally impossible (no @tool on domain) |
| Inspector conditional display | `_validate_property()` on @tool domain node | `EditorInspectorPlugin._parse_property()` |
| Transport preview state | On domain node, flag-guarded | Orchestrator-local, destroyed on free |
| Test tier boundary | Fuzzy (headless simulates editor) | Clear: headless=runtime, MCP Tier 2=editor |
| `@tool` surface area | All domain nodes + plugin | Plugin + 3 purpose-built editor classes |

---

## 6. What V2 Does NOT Change

- The scene tree structure: Juice nodes remain children of their target. Users still add
  Juice nodes explicitly. The inspector-first workflow is unchanged.
- The recipe/effect resource system: `JuiceRecipe`, `JuiceEffectBase`, and all concrete
  effects remain `Resource` subclasses. Their serialization is correct and intended.
- The ledger coordination contract: multiple Juice nodes on one target still coordinate
  through the static JuiceLedger. The static dict approach carries forward unchanged.
- The `JuicePreviewDirector` UI role: it still owns the transport button state, scrubber,
  and loop toggle. It delegates animation execution to the orchestrator.

---

## 7. Open Questions for V2 Implementation

1. **Orchestrator ledger isolation**: The orchestrator runs effects on the same target as
   runtime Juice nodes might. During editor preview, should the orchestrator have its own
   isolated ledger namespace, or share the global static ledger? Sharing is simpler but
   could have edge cases if a scene is previewed while runtime effects are also active
   (unlikely but possible in play-in-editor mode).

2. **CaptureAt.IN_EDITOR baking**: Currently triggered by `NOTIFICATION_EDITOR_PRE_SAVE`
   on domain nodes. In V2, this must move to `juice_plugin.gd`'s `_save_external_data()`
   or a custom pre-save hook. Verify that `_save_external_data()` fires before the scene
   serializer runs (timing constraint).

3. **EditorInspectorPlugin property ordering**: `_parse_property` is called in the order
   properties are declared. The existing `_validate_property` logic relies on property
   ordering (e.g. checking the value of `trigger_source` before deciding whether to show
   `trigger_source_path`). Verify Godot 4.x guarantees consistent ordering.

4. **Runtime binding vs domain-node `_process`**: Resolved — use
   `JuiceRuntimeOrchestrator` (dynamic Node, §3.2b). No autoload needed.

5. **Orchestrator factory interface**: `JuiceOrchestratorFactory` is proposed as the
   common spawning path for editor preview, sequencer, and nested-scene targets.
   Define the factory contract (what it receives, what it returns, how ownership is
   tracked) before implementing either orchestrator or sequencer changes.

6. **Sequencer + nested Juice nodes**: Already solved by the V1 ledger. Multiple
   orchestrators writing to the same target co-exist via delta stacking. No new contract
   needed in V2 — confirm the orchestrator's `cleanup_source` call is symmetric with
   the domain node's existing pattern.

---

*Document created: May 2026. Do not add versioning history — explain architecture,
not migration history.*
