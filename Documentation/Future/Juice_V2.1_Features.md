# Juice V2.1 Feature Tracker

This document tracks planned features, architectural upgrades, and UX improvements slated for the V2.1 release (after the initial V2.0 marketplace launch).

---

## 1. Global Addon Preferences (Juice Config)

**Concept:** Move hardcoded architectural defaults into a robust, user-facing configuration menu leveraging Godot's `ProjectSettings`.

**Implementation details:**
- Register a dedicated `juice/` category in the Godot Project Settings via `juice_plugin.gd`'s `_enter_tree()`.
- Use `ProjectSettings.set_initial_value()` and property hints to make the settings look native in the editor UI.

**Planned Settings:**
- `juice/config/auto_local_to_scene` (bool) — Determines if Juice resources should automatically be set to `resource_local_to_scene = true` on init, preventing shared-state bugs when users create presets (.tres files).
- `juice/editor/show_configuration_warnings` (bool) — Global toggle to suppress inspector warnings if advanced users find them noisy.
- `juice/defaults/default_trigger_behaviour` (enum) — Let users choose their preferred default polarity behavior (e.g., defaulting to Play In & Out instead of Play In Only).

---

## 2. 3D Outline Performance Scalability (Instance Uniforms)

**Problem (Material Duplication):**
Currently in V2.0, 3D appearance effects that apply an outline use "Material Duplication" (Approach 1). The `Juice3D` domain node duplicates the target's base material and instantiates a completely unique `ShaderMaterial` for the outline's `next_pass`, using standard `set_shader_parameter()` calls. While safe and perfectly isolated, this breaks rendering batching. If 50 enemies are outlined simultaneously, it results in 50 separate draw calls, which is unscalable for bullet-hell games or high-density scenes.

**Improvement Solution (Instance Uniforms):**
Transition the 3D outline system to use **Instance Uniforms** (Approach 2).
- Modify `overlay_3d.gdshader` to use `instance uniform` for parameters like outline amount and color.
- Update `Juice3D.gd` to maintain a single, globally shared `ShaderMaterial` resource for outlines instead of instantiating new ones.
- Set specific outline values per mesh instance using Godot 4's `set_instance_shader_parameter()` (or `RenderingServer.instance_set_shader_parameter()`).
- **Result:** The Godot renderer can draw every "juiced" outline object in a single batch, drastically reducing CPU/GPU overhead and enabling massive scale without frame drops.

---

## 3. Control Domain Container Refactor (Godot 4.7 Compatibility)

**Problem (Godot 4.x Container Aggressiveness):**
In Godot 4.0 - 4.6, Control containers aggressively override and reset the transforms of their children every single frame to ensure compliance with container layout rules. To make Juice work with UI elements inside containers, we implemented complex workarounds in the `JuiceControl` domain (like the Container hold pattern and JIT `_pre_tick()`) to battle the container and apply our visual effects after the container's sort pass.

**Improvement Solution (Godot 4.7 GUI Changes):**
With the release of Godot 4.7 (specifically changes detailed in 4.7 dev snapshots/betas), Control containers will no longer forcefully reset children's transforms every frame if they haven't intrinsically changed.
- Remove the aggressive frame-by-frame container hold patterns in `JuiceControl`.
- Simplify the layout shift detection logic.
- Remove workarounds that exist purely to fight the old container behavior, leading to cleaner, more robust, and significantly more performant UI juice.
- Re-evaluate if `_temporarily_undo_visual()` and `_temporarily_reapply_visual()` require any Control-specific container fighting logic going forward.

---

## 4. Unified Color & Property Ledger Pipeline (Conflict Safety)

**Status:** Deferred to V2.1.  
**Severity:** High — silent conflict potential when stacking Color/Property effects.

### Problem Statement: The Fractured Pipeline
During V2.0, two separate architectural exceptions were made regarding how effects write to node properties:
1. **The Property Family Exception:** The Property family (`InterpolateProperty*`, `NoiseProperty*`, etc.) was allowed to bypass the `JuiceLedger` entirely, writing directly to the target node via `set_indexed()`. This meant if two Property effects targeted the same path, the last writer won, completely breaking the additive stacking contract.
2. **The Appearance Family Exception:** The Appearance family (TINT/FADE/OVERBRIGHT) also bypassed the unified Ledger for color. Instead, domain nodes run a manual, parallel multiplication loop for a synthetic `_modulate_factor` and overwrite the target's `modulate` property manually at the end of the frame.

**The Breaking Point:** While recent V2.0 patches fixed the internal math for Color accumulation in the Ledger, the *pipelines* remain fractured. If an `Appearance` effect and an `InterpolateProperty` effect both target the `modulate` property simultaneously, they execute via two completely parallel, uncoordinated write paths. The manual Appearance write runs last and clobbers the Property effect's output without warning.

### The Unified Solution
To resolve this, both families must be stripped of their exceptions and migrated into fully compliant delta calculators that share a single, robust `JuiceLedger` pipeline.

#### Phase A: Generic Property Ledger Infrastructure

> **Reference:** For exhaustive design logic on Phase A (discrete-type priority order, variant-aware addition logic, and property cleanup constraints), refer to the original comprehensive design document: `Documentation/Future/PropertyFamily_Ledger_Refactor.md`.

- **Generic Property Channels:** Extend `JuiceLedger` to support arbitrary property paths.
- **Variant-Aware Addition:** Implement `flush_properties(target)` that reads the base value and sums all deltas. (Continuous types blend additively; Discrete types like bool/NodePath use a priority-based "last registration wins" model).
- **Update Property Effects:** Modify `PropertyJuiceEffectBase` to remove `set_indexed()` direct writes. Instead, compute the delta and call `register_property_delta()`.
- **Domain Node Hooks:** Add `JuiceLedger.flush_properties(target)` to all 3 domain nodes' `_post_tick_write()`, `_temporarily_undo_visual()`, and `_temporarily_reapply_visual()`.

#### Phase B: Appearance Migration
- **Abolish `_modulate_factor`:** Remove the synthetic key and the manual multiplication loop entirely from all 3 domain nodes and all Appearance classes.
- **Merge into Property Pipeline:** Refactor the Appearance effect base classes to extend `PropertyJuiceEffectBase` directly. This effectively reduces the entire Appearance family to standard property effects that just happen to target `modulate` or `self_modulate`, enjoying the unified Variant-aware blending for free.
- **Rely on Flush:** `JuiceLedger.flush_properties()` will now execute the final property write for everything, safely combining Appearance and Property color deltas in one pass.

#### Test Coverage Requirements
- `test_two_interpolate_effects_same_property_stack_additively`
- `test_discrete_property_two_effects_priority_order`
- `test_appearance_and_property_stacking_on_modulate_blends_correctly`
These tests MUST PASS. Claims of completion require citing test results.

---

## 5. Custom Signal Picker for Trigger Source (Consideration)

**Status:** Unresolved consideration — needs design thinking before becoming a feature request.

### Observation

When `Trigger Source = NODE`, the user can slot any node. The `Trigger On` dropdown
shows only triggers mapped to the hardcoded `TriggerEvent` enum (values 0–16), filtered
by which known signal names (`mouse_entered`, `body_entered`, etc.) the slotted node has.

But any scripted node can have arbitrary custom signals (`signal combo_ready`,
`signal attack_finished`, etc.), and `has_signal()` can see them at editor time. These
are currently invisible to the `Trigger On` dropdown. The only way to fire Juice from a
custom signal is `Manual` mode with manual `animate_in()` calls from the game script —
which defeats the inspector-driven trigger system's purpose.

### What a Custom Signal Picker Would Look Like

A free-form signal name field (e.g. `@export var trigger_signal_name: StringName`) that
enumerates the slotted node's signals at editor time and lets the user pick one from a
dropdown. The auto-connect system would then do:

```gdscript
source_node.connect(trigger_signal_name, _on_trigger_momentary)
```

This would make `Manual` nearly obsolete for any node that emits signals.

### Implications That Need Thinking

- **Auto-connect architecture**: The current system has per-enum `match trigger_on:`
  blocks in each domain node (`_connect_collision_object_3d_signals`, etc.) that map
  each `TriggerEvent` value to specific signal wiring with polarity handling, button
  filtering, etc. A generic signal picker would bypass all of that — but some triggers
  need special wiring (e.g. `ON_PRESS` wires both `button_down` and `button_up` for
  toggle polarity). How would custom signals express polarity?

- **Coexistence with TriggerEvent**: Would this replace the enum entirely, or sit
  alongside it? Replacing is cleaner but breaks existing scenes. Alongside means two
  paths to maintain.

- **Signal arguments**: Custom signals may have arguments (`signal hit(damage: float)`).
  The current `_on_trigger_momentary` callback takes no arguments. How would argument
  signals be handled?

- **Editor UX**: Enumerating signals at editor time requires the source node's script
  to be loaded. What happens with `@tool`-less scripts? What about signals added via
  `add_user_signal()` at runtime (e.g. Interaction utility's dynamic click signals)?

This is not a clean feature request yet — it needs a design pass to resolve these
questions before implementation.

---

## 6. Appearance3D Multi-Surface Material Architecture

**Status:** Partial fix shipped in V2.0. Full architecture deferred to V2.1.

### What V2.0 Ships

`Juice3D.gd` uses a per-surface `Dictionary[int, Material]` for working/natural materials, so `Appearance3DJuiceEffect.material_surface_index` is respected at the `set_surface_override_material()` level. A single effect targeting surface 2 works correctly.

### The Limitation

The albedo accumulation pipeline (`_post_tick_write()`) reads `material_surface_index` from the **first contributing** appearance effect and applies all combined factors to that single surface. If two sibling Appearance3D effects in the same recipe target **different** surfaces (e.g., surface 0 = body tint, surface 1 = emissive pulse), only the first effect's surface gets the combined result. The second surface is ignored.

### Full V2.1 Architecture

To properly support multi-surface Appearance3D:

1. **Per-surface Ledger channels:** Replace the single `_appearance_factor` synthetic key with per-surface keys (e.g., `_appearance_factor_0`, `_appearance_factor_1`). Each Appearance3D effect registers its delta on the key matching its `material_surface_index`.

2. **Per-surface accumulation loop:** `_post_tick_write()` iterates all active surfaces (from the dictionary keys), reads the per-surface Ledger total, and writes to each surface's working material independently.

3. **Per-surface base capture:** `_ensure_appearance_working_mat(surface_idx)` already captures per-surface natural albedo/alpha, but these values need to be stored per-surface too (currently `_appearance_natural_albedo` / `_appearance_natural_alpha` are single values overwritten by the last `_ensure` call).

**Key work required:**
- `Juice3D.gd`: per-surface natural albedo/alpha dictionaries, per-surface Ledger key registration, per-surface accumulation in `_post_tick_write()`
- `JuiceLedger.gd`: no changes needed — already supports arbitrary string keys
- `Appearance3DJuiceEffect.gd`: no changes needed — already exposes `material_surface_index`
- Test suite: multi-surface stacking test (requires a mesh with 2+ materials)

---
