# Known Bugs

## Chain To — Black dead field next to label

**Severity:** Cosmetic / Low  
**Status:** Open  
**Component:** `ChainToArrayEditor.gd` / Godot EditorProperty rendering

### Description

A dead black rectangle appears next to the "Chain To" label in the inspector when the `chain_to` array is empty (`Size: 0`). It disappears after interacting with the "Pick Siblings" popup.

### Root Cause

`ChainToArrayEditor` extends `EditorProperty`, sets `label = ""` in `_init()`, and uses `set_bottom_editor(_main_vbox)` to render the custom UI below the label row. Godot still allocates the default inline value-widget area on the label row, but since no widget is placed there, it renders as a black rectangle. After a popup interaction forces a re-layout, the stale area clears.

### Reproduction

1. Expand an effect in the recipe inspector
2. Scroll to the "Chaining" group
3. Observe the black rectangle next to "Chain To" (intermittent — may require fresh scene load)

### Possible Fix Directions

- Investigate whether setting `label` to the property name (instead of `""`) changes Godot's layout allocation
- Check if adding a transparent placeholder Control as the inline child (before `set_bottom_editor`) prevents the black area
- May require a Godot engine fix if the stale widget area is an `EditorProperty` base class issue

---

## PropertyTarget cross-node targeting via node_path fails silently

**Severity:** Moderate / UX Gap  
**Status:** Open  
**Component:** `PropertyTarget.gd` / `JuiceLedger.gd`

### Description

While `PropertyTarget` exposes a `node_path` property and correctly captures the base value from the target node, the interpolation delta is sent to `JuiceLedger`, which is hardcoded to apply changes back to the host node. This means if you try to target a sibling node's property, the property is written to the host node instead, failing silently if the host lacks that property.

### Proposed Fix

- Phase 6.2 scope: Add support for cross-node targeting in `JuiceLedger`.
- Short term: Add a clear tooltip/warning to `node_path` in the inspector explaining that cross-node targeting is currently unsupported.

---

## Appearance3DJuiceEffect material selection missing

**Severity:** Moderate / Feature Gap  
**Status:** Open  
**Component:** `Appearance3DJuiceEffect`

### Description

There is no way to target a specific material index or name when animating appearance in 3D. For example, it is impossible to tint only an emissive material on a multi-material object.

### Proposed Fix

- Fetch the materials list of the target node and add a selection field to pick which material(s) will have their appearance changed.

---

## Color Interpolation math bug (Green to Purple)

**Severity:** High  
**Status:** Open  
**Component:** `PropertyInterpolateJuiceEffectBase.gd`

### Description

When interpolating a Color property, setting the "to" color to Green results in the color turning Purple at runtime instead of Green. This indicates a math or color space conversion bug during interpolation.

---


## Phantom Input Field for Vector3 and similar types

**Severity:** High  
**Status:** Open  
**Component:** Editor Inspector

### Description

A phantom input field bug occurs in the inspector. This bug is not purely cosmetic; it actively prevents users from inputting values into fields like Vector3 input fields.

---

## Signal / Method Event Architecture Gap

**Severity:** High / Architectural Flaw  
**Status:** Open  
**Component:** `SignalEmitJuiceUtility` / `CallMethodJuiceUtility` / `JuiceBase`

### Description

Currently, utility resources like `SignalEmit3DJuiceUtility` emit their signals directly from the Resource itself. Godot 4's Inspector does not allow connecting signals from Resources inside arrays to other nodes in the GUI. This makes the utility practically useless without writing code to intercept it. 

### Proposed Fix (Event Router Architecture)

The base class (`JuiceBase`) needs to take responsibility for firing signals and method calls dictated by its resources. 
*Note on Ledger:* While a "Ledger" is specifically for mathematically summing continuous deltas (like position) and isn't mechanically needed for discrete events, the architecture *does* need a centralized **Event Router** at the Node level. 

**Bubbling to Sub-Scene Root:**
To truly fulfill the "no-code" philosophy and treat prefabs as black boxes, the Event Router should not just bubble the signal from the Resource to the `JuiceBase` node. It should include an option (e.g., `bubble_to_owner = true`) to traverse up and emit the signal directly from the **Sub-Scene Root** (`owner`). This way, the Main Scene can listen to the prefab root directly without needing to dig into its internal node hierarchy.
