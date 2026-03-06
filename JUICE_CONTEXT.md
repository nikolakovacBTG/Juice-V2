# Juice System — AI Context Handoff Document

> **Purpose:** Bootstrap document for AI assistants (Cascade/Windsurf) working in the Juice Demo project.
> **Created:** 2026-03-06
> **Source project:** Cold Soul (d:\Godot projekti\Cold_Soul_v0.1)
> **This project:** Juice Demo (d:\Godot projekti\juice-demo)

---

## What Is Juice?

Juice is a **Godot 4.x addon** (`addons/juice/`) that provides inspector-driven feedback/polish components. Artists and designers add Juice components as child nodes, configure them in the inspector, and get animated effects (transform, appearance, camera, screen, etc.) without writing code.

The addon is fully self-contained with zero external dependencies.

---

## System Architecture

### JuiceCompBase (the foundation)

All visual Juice components extend `JuiceCompBase` (`addons/juice/JuiceCompBase.gd`). Key concepts:

- **Progress-based animation:** 0.0 = natural state, 1.0 = effect fully applied
- **Delta/offset model:** Subclasses define an OFFSET, not from/to values. `_apply_effect(progress)` scales the offset by progress.
- **animate_in()** tweens progress 0→1 (apply effect), **animate_out()** tweens 1→0 (release)
- **Trigger system:** Auto-connect to parent signals (button pressed, area entered, etc.) or manual signal wiring
- **TriggerBehaviour enum:** PLAY_IN_ONLY, PLAY_OUT_ONLY, TOGGLE_IN_AND_OUT, PLAY_IN_AND_OUT, SET_FROM_SOURCE
- **RetriggerPolicy:** RESTART, QUEUE, IGNORE, CROSSFADE
- **Timing:** duration_in/out, transition_in/out (Tween curves), ease_in/out, custom_curve_in/out
- **Loops:** loop_count, ping_pong, loop_delay
- **Chaining:** next_component (NodePath to trigger after completion)
- **Conditional exports:** `_get_property_list()` + `_set()` + `_get()` pattern for dynamic inspector

### Sequencer Pattern

Some components extend JuiceCompBase but **bypass the animation loop**. They use the base class only for trigger infrastructure and chaining. Examples:
- `CallMethodJuiceUtility` — calls a method on any node
- `SceneActionJuiceUtility` — scene switching/overlaying/reloading/quitting
- `SequencerJuiceComp` — orchestrates child juice components

These override `animate_in()`/`animate_out()` directly.

### Three Domains

Most visual effects exist in 3 domain variants:
- **Control** — for UI elements (`TransformControlJuiceComp`, etc.)
- **2D** — for Node2D/Sprite2D (`Transform2DJuiceComp`, etc.)
- **3D** — for Node3D/MeshInstance3D (`Transform3DJuiceComp`, etc.)

Plus cross-domain components: Property, Camera, Screen, Events/Time, VFX, Visibility, Utilities.

### Runtime Comp Instantiation Pattern

Some utilities create existing Juice components at runtime instead of reimplementing logic:
- `SceneActionJuiceUtility` creates `ScreenOverlayJuiceComp` instances for transitions
- `SceneActionJuiceUtility` creates `TimeJuiceComp` instances for pause/slow-mo during overlays

This keeps DRY and reuses battle-tested code.

### Static Utility Patterns

- `JuiceScreenOverlayProvider` — shared full-screen ColorRect on CanvasLayer 100, persists across scene changes
- `TimeCoordinatorJuiceUtility` — optional coordinator for multiple `TimeJuiceComp` instances managing `Engine.time_scale`
- `ScreenJuiceUtility` — static instance for screen-space post-process effects

---

## Component Inventory (61 items)

### Base
| Class | Purpose |
|-------|---------|
| `JuiceCompBase` | Abstract base for all Juice components |

### Per-Domain Comps (Control / 2D / 3D)
| Family | What It Does |
|--------|-------------|
| **Transform** | Position, rotation, scale animation |
| **SquashStretch** | Squash & stretch deformation |
| **Shake** | Randomized shake effect |
| **Spring** | Physics-spring-based motion |
| **Noise** | Continuous procedural noise |
| **Progress** | Drives a 0–1 value (e.g., progress bars) |
| **Appearance** | Color modulation, flash, blend modes |
| **Outline** | Animated outline (shader-based for 2D) |

### Property Domain
| Class | Purpose |
|-------|---------|
| `ProgressPropertyJuiceComp` | Tween any numeric property |
| `ShakePropertyJuiceComp` | Shake any property |
| `SpringPropertyJuiceComp` | Spring any property |
| `NoisePropertyJuiceComp` | Noise any property |
| `ShaderPropertyJuiceComp` | Animate shader uniforms |

### Camera & Screen
| Class | Purpose |
|-------|---------|
| `Camera3DJuiceComp` / `Camera2DJuiceComp` | Camera shake/kick via receiver |
| `CameraJuiceReceiverComp` | Accumulates additive offsets on camera |
| `ScreenMotionJuiceComp` | Full-screen shake/kick/zoom/tilt |
| `ScreenJuiceUtility` | Static receiver for screen post-process |
| `ScreenOverlayJuiceComp` | Full-screen color/texture fade overlay |
| `JuiceScreenOverlayProvider` | Shared overlay lifecycle manager |

### Events & Flow
| Class | Purpose |
|-------|---------|
| `SequencerJuiceComp` | Orchestrates child juice components |
| `RandomJuiceComp` | Randomly triggers one of N children |
| `LooperJuiceComp` | Repeats child animations |
| `PauseJuiceComp` | Delays in a sequence chain |
| `TimeJuiceComp` | Freeze/slow-mo/bullet-time |

### VFX
| Class | Purpose |
|-------|---------|
| `VFXJuiceComp` | Spawns particle/scene VFX |
| `TrailJuiceComp` | Motion trail effect |

### Visibility
| Class | Purpose |
|-------|---------|
| `VisibilityJuiceComp` | Show/hide with animation |

### Utilities
| Class | Purpose |
|-------|---------|
| `Interaction3DJuiceUtility` / `Interaction2DJuiceUtility` | Click/hover/zone triggers |
| `SoftTrigger3DJuiceUtility` / `SoftTrigger2DJuiceUtility` | Proximity-based soft triggers |
| `SoftTriggerControlJuiceUtility` | Mouse proximity soft trigger for Control |
| `SignalEmitJuiceUtility` | Emits custom signal on juice event |
| `SignalRelayJuiceUtility` | Relays local signal to global bus |
| `CallMethodJuiceUtility` | Calls a method on any node when triggered |
| `TimeCoordinatorJuiceUtility` | Coordinates Engine.time_scale from multiple sources |
| `SceneActionJuiceUtility` | Scene switch/overlay/reload/quit with transitions |

### Editor Tooling
| Class | Purpose |
|-------|---------|
| `JuicePreviewDirector` | Editor preview lifecycle (Transport Controls) |
| `juice_plugin.gd` | Master EditorPlugin |

---

## Key Patterns to Know

### Trigger Auto-Connect
JuiceCompBase auto-connects to parent node signals based on node type:
- `Button` → `pressed`
- `Area3D/Area2D` → `input_event` or interaction signals
- `Control` → various UI signals
- `trigger_source_path` overrides parent for auto-connect
- `manual_trigger_signal` for custom signal names

### Conditional Export System
Used extensively. Pattern:
1. Backing `var` (not `@export`) for conditional properties
2. Controlling var has setter calling `notify_property_list_changed()`
3. `_get_property_list()` conditionally includes properties
4. `_set()` / `_get()` handle ALL properties for serialization

### Type-Safe Discovery
**Always** use `is` operator for finding nodes. Never hardcode names.

### Editor Integration (@tool)
All Juice components are `@tool` scripts for Transport Controls preview. They check `Engine.is_editor_hint()` to skip runtime-only behavior.

---

## Development Workflow

### Sync Flow
```
Cold Soul (development) → Standalone Repo → Juice Demo (this project)
```

- **Fixes:** Found in Demo → fix in Cold Soul → subtree push → subtree pull into Demo
- **New features:** Designed and implemented in Cold Soul → synced to Demo
- **Demo-only code** (demo scenes, UI, presets): lives only in this project

### Subtree Commands
```powershell
# Pull latest Juice into Demo
git subtree pull --prefix=addons/juice juice-standalone main --squash

# Push upstream (rare — prefer fixing in Cold Soul)
git subtree push --prefix=addons/juice juice-standalone main
```

### Shipping Phases (current status)
| Phase | Status |
|-------|--------|
| 0 — Extraction & Subtree | ✅ DONE |
| 1 — Inventory | ✅ DONE |
| 2 — Code Review | 🔲 NOT STARTED |
| 2.5 — Test Harness | 🔲 NOT STARTED |
| 3 — Demo Project | 🟡 IN PROGRESS (this project) |
| 4 — Docs & Polish | 🔲 NOT STARTED |
| 5 — Ship | 🔲 NOT STARTED |

### Documentation Pass (parallel with Demo)
B1 (review) + B2 (cleanup) + B3 (tooltips) + B6 (demo) run **per-script, in parallel**:
- Build a demo for a comp → review its code → clean comments → write docs → commit

### Comment Convention
- `##` = editor-facing (tooltips, Script docs, Add Child Node dialog)
- `#` = developer-only (architecture, WHY reasoning)
- First `##` line = brief tooltip (keep SHORT)

---

## Files In This Project

| Path | Purpose |
|------|---------|
| `addons/juice/` | The Juice addon (git subtree — read-only) |
| `AGENTS.md` | Project rules for AI assistants |
| `JUICE_CONTEXT.md` | This file — system knowledge bootstrap |
| `.windsurf/workflows/` | Slash command workflows (/code, /design, /debug, /review, /refactor, /test) |
| `Documentation/` | Shipping plan, milestone plan, documentation pass plan, component inventory |

---

## Important Design Decisions (Historical)

These decisions were made during development in Cold Soul and should be respected:

1. **No v2 mentality** — every feature is designed to be complete in v1
2. **Runtime comp instantiation** over reimplementing existing logic
3. **All JuiceCompBase groups remain visible** in subclasses — no hiding inherited features
4. **Composition over inheritance** — Juice comps are children of the node they affect
5. **Inspector-driven** — non-programmers can build complete interactive demos
6. **Three-domain coverage** — Control, 2D, 3D for every applicable effect
7. **Additive effects** — camera/screen effects accumulate, not override
8. **Type-safe discovery** — `is` operator, never string names

---

**END OF CONTEXT HANDOFF**
