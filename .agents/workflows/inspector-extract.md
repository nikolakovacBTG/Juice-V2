---
description: "One-time: Extract _validate_property() from domain nodes to EditorInspectorPlugin"
---

You are in INSPECTOR EXTRACTION MODE.

This is a **one-time migration workflow** for Juice V2 Phase 3. It moves all property visibility logic from domain nodes' `_validate_property()` to `JuiceEditorInspectorPlugin._parse_property()`.

---

## Checklist

### 1. Audit
- [ ] Grep `addons/Juice_V2/` for all `_validate_property()` overrides
- [ ] List each property name + show/hide condition
- [ ] Note which are in domain nodes vs effect Resources (effects keep theirs — Resources use `_get_property_list()`)

### 2. Create Inspector Plugin
- [ ] Create `addons/Juice_V2/Editor/JuiceEditorInspectorPlugin.gd`
- [ ] Register in `juice_plugin.gd` via `add_inspector_plugin()`
- [ ] Implement `_parse_property()` with equivalent visibility logic

### 3. Delete from Domain Nodes
- [ ] Remove `_validate_property()` from `JuiceBase.gd`
- [ ] Remove `_validate_property()` from `Juice2D.gd`, `Juice3D.gd`, `JuiceControl.gd`
- [ ] Verify no `_validate_property()` remains in domain nodes

### 4. Verify
- [ ] MCP Tier 2: open each Juice node type in inspector, verify property visibility matches V1 behavior
- [ ] Run full test suite

**Gate**: Zero `_validate_property()` in domain nodes. Inspector property visibility unchanged.
