# Tier 2 — MCP Editor Realistic Scenario Library

These scenarios simulate what a developer does **inside the editor**, not at runtime. Run via `mcp_godot-mcp_execute_editor_script`.

---

## The User-Behaviour Framing Rule

Every Tier 2 test must start with: *"A developer opens the editor and..."*

Do NOT write tests that just call internal APIs. Write tests that simulate the sequence of actions a developer takes.

---

## Scenario Family F: "I'm configuring a Juice stack in the inspector"

| Test | What a developer does | What to assert |
|------|-----------------------|---------------|
| F1 — Fresh Juice node | Add Juice2D to scene (no recipe), inspect it | Config warning icon visible in scene tree, inspector shows warning message |
| F2 — Assign recipe | Drag recipe resource onto recipe slot | Warning clears, inspector shows recipe effects list |
| F3 — Add an effect | Click "Add Effect" in inspector, select Transform | New effect row appears, effect is now in recipe |
| F4 — Configure effect | Expand effect row, change `from_position` to `(100, 0)` | Inspector reflects new value, resource serialized correctly |
| F5 — Stack second effect | Add Shake effect to same recipe | Both effects visible in inspector, order preserved |

### MCP Pattern for F-family
```gdscript
func run():
    var scene_root = EditorInterface.get_edited_scene_root()
    var juice = scene_root.find_child("Juice2D", true, false)
    # Check warning state BEFORE recipe assignment
    var warnings_before = juice.get_configuration_warnings()
    # Assign recipe via property
    juice.recipe = load("res://tests/fixtures/test_recipe.tres")
    var warnings_after = juice.get_configuration_warnings()
    return {"warnings_before": warnings_before.size(), "warnings_after": warnings_after.size()}
```

---

## Scenario Family G: "I'm using the editor transport to preview animations"

| Test | What a developer does | What to assert |
|------|-----------------------|---------------|
| G1 — Press Play in transport | Click Play on a Juice node with a Transform recipe | Target moves away from natural position, PREVIEW orchestrator created |
| G2 — Press Stop in transport | Click Stop mid-animation | Target immediately restores to natural position |
| G3 — Non-zero position target | Preview on target at `(200, 150)` | Base captured correctly — target returns to `(200, 150)`, never snaps to `(0,0)` |
| G4 — Press Play again | Stop, then Play again | Second preview starts clean, base re-captured correctly |
| G5 — Deferred-init node | Preview on `TileMapLayer` or `SubViewport` target | Base capture waits for deferred init, no `(0,0)` snap |

### MCP Pattern for G-family
```gdscript
func run():
    var scene_root = EditorInterface.get_edited_scene_root()
    var juice = scene_root.find_child("Juice2D", true, false)
    var target = juice.target_node
    var natural_pos = target.position

    JuicePreviewDirector.preview(juice)
    # Sample after a few deferred frames
    var pos_during = target.position
    JuicePreviewDirector.stop_preview(juice)
    var pos_after = target.position

    return {
        "natural": natural_pos,
        "during_animation": pos_during,
        "after_stop": pos_after,
        "restored_correctly": pos_after.is_equal_approx(natural_pos)
    }
```

---

## Scenario Family H: "I'm saving the scene mid-workflow"

| Test | What a developer does | What to assert |
|------|-----------------------|---------------|
| H1 — Save with no Juice nodes | Normal Ctrl+S | No errors, no Juice-related metadata in saved .tscn |
| H2 — Save while transport is idle | Juice node configured, transport not active, Ctrl+S | Target position in .tscn matches design-time value |
| H3 — Save while transport is active | Transport playing, developer presses Ctrl+S | Plugin temporarily restores target, saves natural position, resumes preview |
| H4 — Open saved scene | Close and reopen scene after H3 | Target at correct design-time position, no animation artifacts |

---

## Scenario Family I: "I'm working with multiple Juice nodes in a complex scene"

| Test | What a developer does | What to assert |
|------|-----------------------|---------------|
| I1 — Select different Juice nodes | Click between two Juice nodes in scene tree | Inspector updates to each node's recipe, config warnings correct per node |
| I2 — Preview one, then select another | Preview Juice A, then click Juice B | Juice A's preview stops cleanly, Juice B is ready to preview |

---

## Scenario Family J: "I have two Juice nodes targeting the same node — I preview both"

This is the editor-side counterpart to Tier 1's B2 family. It validates that the **PREVIEW orchestrator** and **ledger** handle concurrent editor previews correctly.

| Test | What a developer does | What to assert |
|------|-----------------------|---------------|
| J1 — Preview both simultaneously | Select Juice_A and Juice_B (both targeting same node), preview both | Target shows combined displacement. Ledger has two active sources. Neither PREVIEW orchestrator overwrites the other. |
| J2 — Stop one, other continues | While both previewing, stop Juice_A's transport | Target snaps to Juice_B's delta only. A's contribution cleanly removed. B continues unaffected. |
| J3 — Sequential preview, overlapping duration | Preview Juice_A. Halfway through A's animation, also preview Juice_B. | While overlap: sum of both deltas. When A ends: only B's delta. When B ends: target at exact natural position. |
| J4 — Save while both active | Both PREVIEW orchestrators active, developer presses Ctrl+S | Plugin restores full natural position (sum of both contributions undone), saves clean .tscn, both previews resume. |
| J5 — Deselect all | Both previewing, developer clicks empty space in scene tree | Both PREVIEW orchestrators tear down, target at exact natural position. |

### MCP Pattern for J-family
```gdscript
func run():
    var scene_root = EditorInterface.get_edited_scene_root()
    var juice_a = scene_root.find_child("JuiceA", true, false)
    var juice_b = scene_root.find_child("JuiceB", true, false)
    var target = juice_a.target_node  # both point to same node
    var natural_pos = target.position

    JuicePreviewDirector.preview(juice_a)
    JuicePreviewDirector.preview(juice_b)
    var pos_both_active = target.position

    JuicePreviewDirector.stop_preview(juice_a)
    var pos_b_only = target.position

    JuicePreviewDirector.stop_preview(juice_b)
    var pos_restored = target.position

    return {
        "natural": natural_pos,
        "both_active": pos_both_active,
        "b_only": pos_b_only,
        "fully_restored": pos_restored,
        "restore_correct": pos_restored.is_equal_approx(natural_pos)
    }
```

---

## Scenario Family L: "Editor robustness — undo, duplication, and missing resources"

These scenarios cover actions developers do reflexively without thinking, which are the most common source of addon bugs.

| Test | What a developer does | What to assert |
|------|-----------------------|---------------|
| L1 — Undo recipe assignment | Assign recipe to Juice node, press Ctrl+Z | Recipe reference cleared, config warning reappears, no crash |
| L2 — Undo effect configuration | Change `from_position` on an effect, press Ctrl+Z | Value reverts to previous, inspector reflects revert, resource state correct |
| L3 — Undo during preview | Transport playing, developer presses Ctrl+Z | Preview stops cleanly (or continues safely), target not left in animated state |
| L4 — Node duplication (Ctrl+D) | Duplicate a fully-configured Juice node | Duplicate gets an **independent** recipe resource copy — editing one does NOT affect the other |
| L5 — Duplication with shared sub-resources | Juice node has recipe with 2 effects, duplicate it | All sub-resources (effects) also independently duplicated — no shared state between original and copy |
| L6 — Copy-paste across scenes | Copy Juice node, paste into different scene | Pasted node works correctly, resource paths resolved, no broken references |
| L7 — Missing recipe after asset move | Recipe `.tres` assigned, then file moved in FileSystem dock | Juice node shows missing-resource warning, no crash on `animate_in()` |

### MCP Pattern for L4 (Duplication)
```gdscript
func run():
    var scene_root = EditorInterface.get_edited_scene_root()
    var original = scene_root.find_child("Juice2D", true, false)

    # Duplicate via editor script
    var duplicate = original.duplicate()
    scene_root.add_child(duplicate)
    duplicate.owner = scene_root

    # Modify original recipe — should NOT affect duplicate
    original.recipe.effects[0].from_position = Vector2(999, 999)

    var original_val = original.recipe.effects[0].from_position
    var duplicate_val = duplicate.recipe.effects[0].from_position

    return {
        "original_from": original_val,
        "duplicate_from": duplicate_val,
        "are_independent": not original_val.is_equal_approx(duplicate_val)
    }
```
