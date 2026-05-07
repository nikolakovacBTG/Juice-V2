# JuiceLedger Migration — Handover Note for V2 Planning Agent

**Date:** 2026-05-07  
**Commits:** `65b8416` → `03b0133` → `9575240` → `0c7dcee`  
**Status:** Complete. All four phases shipped. 588/588 tests pass. Zero `juice_active_ledger` references anywhere in the codebase or scene files.

---

## What was done and why

### The problem (V1 architectural debt)

`JuiceLedger` stored its per-target animation state (`{"base": {...}, "deltas": {...}}`) as
**Godot node metadata** (`set_meta("juice_active_ledger", ...)`). Node metadata is part of
Godot's scene serialization pipeline, so this dictionary was being baked into `.tscn` files
as `metadata/juice_active_ledger = { ... }`.

This caused a real production bug: when a `@tool` node (e.g. `TileMapLayer`) had a deferred
initialization, the ledger captured a stale base (e.g. `position = (0, 0)`) before the node
settled. That stale base was then serialized and replayed on next scene load, causing animated
nodes to snap to `(0, 0)` on the first frame.

A band-aid patch (`_sync_stale_editor_ledger_base`) was added to `JuiceBase.gd` to heal the
corrupt base at editor preview time. The root cause was the serialization, not the capture order.

### What was changed

**Phase 0 — Transport test cleanup** (`65b8416`)  
Deleted `test_preview_play_animates_node` from `TestTransport.gd`. The test called
`animate_in()` before `_deferred_editor_preview_init` completed, so `_target_node` was always
`null` — it was a permanently failing no-op. Coverage of preview-play → node-moves already
exists in `test_sequencer_replay_after_stop/completion`.

**Phase 1 — Ledger storage migration** (`03b0133`)  
`JuiceLedger.gd` was rewritten to store all ledger data in:

```gdscript
static var _store: Dictionary = {}  # keyed by target.get_instance_id()
```

All `has_meta` / `get_meta` / `set_meta` / `remove_meta` calls replaced with `_store` lookups.
A `tree_exiting` signal connection (CONNECT_ONE_SHOT) was added in `ensure()` to auto-erase
the entry when the target node is freed — regardless of whether the Juice node's `_exit_tree`
fires first. This closes a cleanup gap that didn't exist with metadata (metadata was owned and
freed with the node automatically).

A `_store_entry_count()` debug accessor was added for test introspection.
`test_store_cleared_when_target_freed` was added to `TestJuiceLedger`.

Also fixed: `Juice3D._ensure_appearance_working_mat()` had a rogue direct `get_meta(JuiceLedger.KEY)`
call that bypassed the API. Converted to `JuiceLedger.force_base()`.

**Phase 3 — B-1 patch removal** (`9575240`)  
`_sync_stale_editor_ledger_base()` in `JuiceBase.gd` deleted at all three locations
(PRE_SAVE call, deferred-init call, method body). `JuiceLedger.KEY` compat const removed.

`force_base()` was **kept** — `Juice3D._ensure_appearance_working_mat()` uses it legitimately
to replace the `Color.WHITE` placeholder seed with the real natural albedo once the working
material is established. Its docstring was updated to reflect this general-purpose role.

---

## Current state of JuiceLedger

```
JuiceLedger (pure static class, no Node inheritance)
├── static var _store: Dictionary     ← in-memory only, never serialized
├── ensure()                          ← creates entry + connects tree_exiting auto-erase
├── sync_base_if_moved()              ← external-displacement detection
├── register_delta()                  ← per-source delta write
├── get_total() / get_base()          ← read API
├── force_base()                      ← placeholder correction (3D appearance)
├── get_base_dict()                   ← bulk base read for effect capture
├── cleanup_source()                  ← delta removal + permanent erase
├── flush()                           ← write base+Σdeltas to node
├── has_ledger()                      ← presence check
└── _store_entry_count()              ← test accessor
```

Cleanup contract (unchanged from V1):
- `cleanup_source(permanently=true)` → erases `_store[id]`
- Called from `_exit_tree()` in `Juice2D`, `Juice3D`, `JuiceControl`
- **Also** erased via `tree_exiting` signal if target freed before Juice node

---

## Phase 2 — Scene file cleanup (`0c7dcee`)

Nine now-inert `metadata/juice_active_ledger` entries stripped from `.tscn` files via
an MCP editor script (`node.remove_meta("juice_active_ledger")` + `save_scene()`).
200 lines deleted from scene files. `Select-String` grep returns zero results.

| File | Entries removed |
|------|-----------------|
| `Demo/Scenes/2D_Demo.tscn` | 3 |
| `Demo/Scenes/Main_Demo_Scene.tscn` | 5 |
| `Demo/Scenes/Utilities_Test_2D_Control.tscn` | 1 |

---

## V2 implications

**This migration is a prerequisite for V2's `@tool` removal.**

V1 domain nodes (`Juice2D`, `Juice3D`, `JuiceControl`) are `@tool` partly because
`NOTIFICATION_EDITOR_PRE_SAVE` was needed to run the stale-ledger healing before saving.
That notification is gone. The B-1 patch is gone. The ledger cannot be corrupted by
serialization because it is never serialized.

**V2 architectural notes:**

1. The `JuiceOrchestrator` ("born, do job, die") pattern in the V2 design doc
   (`Documentation/Future/JuiceV2_Architecture.md`) can use `JuiceLedger` without modification.
   The ledger's multi-writer merge contract (multiple sources, single sum per frame) is
   already correct for the orchestrator model — orchestrators register deltas as sources,
   exactly as domain nodes do in V1.

2. The `static var _store` will survive Play → Stop → Play cycles in the editor because
   `static var` persists for the engine session. This is correct: each Juice node's
   `_exit_tree` erases its target's entry at Stop, so the store is empty before the next Play.

3. `force_base()` remains in the API for V2 to use (3D appearance seeding pattern), but
   the B-1 healing logic is fully gone.

4. The `tree_exiting` gap closure means V2 orchestrators that `queue_free()` themselves
   (the "die" step) will also clean up correctly — the target's entry erases via
   `cleanup_source` (called from the orchestrator's `_exit_tree`), and if the target is freed
   first, the `tree_exiting` signal catches it.

---

## Files changed in this session

| File | Change |
|------|--------|
| `addons/Juice_V1/Base Classes/JuiceLedger.gd` | Full rewrite: static dict storage, tree_exiting, KEY removed, force_base doc updated |
| `addons/Juice_V1/Base Classes/JuiceBase.gd` | B-1 patch deleted (3 locations, ~24 lines) |
| `addons/Juice_V1/Base Classes/Juice3D.gd` | Rogue get_meta → force_base() API call |
| `tests/suites/TestJuiceLedger.gd` | New test: test_store_cleared_when_target_freed |
| `tests/suites/TestTransport.gd` | Deleted malformed test_preview_play_animates_node |
