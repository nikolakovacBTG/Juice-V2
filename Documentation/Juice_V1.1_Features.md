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
