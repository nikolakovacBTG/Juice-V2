---
description: "Strict coding standards prioritizing clear, predictable, and inspector-driven Godot 4.x components. Enforces feature completeness, safe MCP scene editing, generic protocols over hardcoding, and proper composition patterns."
---

You are in CODING MODE.
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

---

## 1. General Principles & Feature Completeness (MANDATORY)

- **Complete the Design:** Implement ALL features from the approved design. Do NOT skip, simplify, or "phase" features unless authorized. If a design gap is found, STOP and ask.
- **Sprint Contract Check:** Before writing any code, state the sprint/phase goal in one sentence. Confirm that every type, case, and code path you are about to implement covers the full goal. If anything is being left out — **STOP and ask first.** Signal words: "fall back to", "not supported", "too niche", "excluded", "not needed", "pragmatic fallback" — writing any of these is a hard stop.
- **Goal:** Clarity over cleverness, simplicity over abstraction, predictable control flow.
- **Style:** No shorthand logic that harms readability. Every script should be understandable in isolation. Explain WHY, not just WHAT.
- **Godot Expectations:** Godot 4.x. Use composition-friendly patterns. Assume designers will tweak values.


---

## 2. Script Intent (MANDATORY HEADER COMMENT)

At the top of every script, include a clear comment explaining: What it does, why it exists, its system, and what it does NOT handle.

**The WHY Block Standard & Translation Rule:**
The `# WHY:` block must define the class's architectural purpose and the constraints it enforces. Do not explain migration history (e.g. no "V0", "V1", "refactored"). Transform legacy comments into pure structural rationale. Explain *why* the architecture demands a specific approach, without referencing past versions.

**Method Documentation Standard:**
Every method (public and private) must have a brief description and a short rationale (what problem it solves / why it is necessary). Use `##` for public methods to expose them to Godot's built-in docs. Use `#` for internal (`_`) methods to hide plumbing from end-users. Skip trivial overrides unless they contain non-obvious logic.

---

## 3. Inspector-Exposed Configuration

All gameplay-relevant values must be exported, grouped, and clearly named. No hardcoded logic numbers allowed.

### 3b. Conditional Export Display (Hybrid Approach)

#### Approach A: `_validate_property` (Simple show/hide within static groups)
1. Use normal `@export var`.
2. Controlling variable needs setter with `notify_property_list_changed()`.
3. Override `_validate_property()` to assign `PROPERTY_USAGE_NO_EDITOR`.
4. Call `super._validate_property(property)` first.

#### Approach B: `_get_property_list` (Dynamic groups, custom ordering)
1. Use normal `var` (not `@export`).
2. Controlling variable needs setter with `notify_property_list_changed()`.
3. Build and return properties in `_get_property_list()`.
4. Handle values via `_set()` and `_get()` so hidden properties still serialize.

**CRITICAL:** `notify_property_list_changed()` must be in a GDScript setter, not just overridden `_set()`.

---

## 4. Connections & external systems

When connecting to other systems, explain in comments: What system it is, why the connection exists, data flow, and fallback if missing. Fail gracefully if references are broken.

---

## 5. Generic Protocol Over Hardcoding

When implementing a fix or feature involving data communication between components:
1. **Never hardcode specific channels/properties/types.** Use a generic protocol.
2. **Never copy-paste the same logic into JuiceControl, Juice2D, AND Juice3D.** Code it generically in a shared base class.
3. If an architectural choice arises, present options to the user before implementing.

---

## 6. MCP Scene Editing Safety (MANDATORY)

- **NEVER use `mcp0_duplicate_node` for nodes with children.** The children lose their `owner` reference and vanish on save.
- **Instead:** Use `mcp0_execute_editor_script` to build hierarchies and explicitly set `node.owner = scene_root` for EVERY node.
- **Always verify:** Check `git status` to ensure `.tscn` files were properly written after edits.

---
## 7. Placeholder Paths

Use `[DEMOS_PATH]`, `[PRESETS_PATH]`, `[ASSETS_PATH]`, `[DOCUMENTATION_PATH]` instead of hardcoded strings until final config.

---

## 8. Final Check Before Responding

- Match approved design exactly. Do NOT add unauthorized features or premature optimizations.
- Verify inspector values.
- Verify the script is perfectly clear to a non-author.
