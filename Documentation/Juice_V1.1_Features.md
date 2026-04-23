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
