# Juice V1.1 Feature Tracker

This document tracks planned features, architectural upgrades, and UX improvements slated for the V1.1 release (after the initial V1.0 marketplace launch).

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
Currently in V1.0, 3D appearance effects that apply an outline use "Material Duplication" (Approach 1). The `Juice3D` domain node duplicates the target's base material and instantiates a completely unique `ShaderMaterial` for the outline's `next_pass`, using standard `set_shader_parameter()` calls. While safe and perfectly isolated, this breaks rendering batching. If 50 enemies are outlined simultaneously, it results in 50 separate draw calls, which is unscalable for bullet-hell games or high-density scenes.

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

## 4. Property Effect Family — Ledger Refactor (Conflict Safety)

**Status:** Deferred from V1.0. Shipped as an approved Direct-Write Exception.  
**Full plan:** `Documentation/Future/PropertyFamily_Ledger_Refactor.md`

**Why deferred:**
The Property family (`InterpolateProperty*`, `NoiseProperty*`, `ShakeProperty*`, `ProgressProperty*`) bypasses the JuiceLedger and writes directly to the target node via `set_indexed()`. This was a deliberate V1.0 scope decision — the Ledger aggregates typed channels (position/rotation/scale/modulate) and extending it to arbitrary user-picked properties requires a new generic channel API and L2 domain changes across all three domains.

**The V1.1 conflict being solved:**
Two Property Effects in the same Recipe targeting the same property path simultaneously produce a last-writer-wins conflict. V1's Ledger delta aggregation solves this — but the Property family must first register deltas instead of writing directly.

**Key work required:**
- `JuiceLedger.gd`: generic property channel (`register_property_delta`, `flush_properties`)
- `PropertyJuiceEffectBase.gd`: remove `set_indexed()`, register delta instead
- All 3 domain nodes: call `JuiceLedger.flush_properties(target)` in `_post_tick_write()` and handle `_temporarily_undo/reapply_visual()` for property channels
- `PropertyTarget.gd`: register base value with Ledger at capture time
- Test suite: stacking, cleanup, and discrete-type priority tests required before shipping

See `PropertyFamily_Ledger_Refactor.md` for full implementation order and test requirements.

---

## 5. Flaky Noise/Shake Test Timing Fix

**Status:** Known pre-existing issue. Fix deferred.

Several noise/shake property tests fail intermittently because they assert property changes after too few simulation frames. These effects need multiple frames of accumulation before output exceeds the assertion threshold.

**Fix pattern:** Replace single-frame assertions with a frame-loop advancing simulation at least 10 frames before checking, consistent with how other noise/shake tests in the suite were previously corrected.

