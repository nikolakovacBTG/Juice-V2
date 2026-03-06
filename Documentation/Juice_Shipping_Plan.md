# Juice System — Shipping Plan

> **Created:** 2026-02-21
> **Status:** Planning
> **Goal:** Ship a high-quality, marketable Godot 4 juice/feedback addon
> **Development environment:** Cold Soul (testbed project)
> **Demo/product environment:** Juice Demo (new project, created in Phase 3)
> **Sync method:** Git Subtree

---

## Philosophy

The world is full of mediocre code — and AI generates more of it by default. This plan counteracts that through:

1. **Human-driven architecture and design** — AI executes, humans decide
2. **Rigorous multi-pass code review** — different AI models catch different blind spots
3. **Real-world testing through demos** — every comp used in a polished demo, not just a checkbox
4. **Clear shipping criteria** — no ambiguity about what "done" means

---

## Phase Overview

| Phase | Name | Where | Gate |
|-------|------|-------|------|
| **0** | Extraction & Subtree Setup | Cold Soul | Juice runs standalone in Cold Soul with no Cold Soul dependencies |
| **1** | Inventory | Cold Soul | Complete comp/utility table with domain coverage |
| **2** | Code Review (Alpha → Beta) | Cold Soul | All review items resolved, code is clean and optimized |
| **2.5** | Test Harness | Cold Soul | Automated regression tests for all comps |
| **3** | Demo Project & Beta Testing | Juice Demo | All comps have polished demos, bugs found and fixed |
| **4** | Documentation & Polish | Juice Demo | User docs, README, marketplace listing |
| **5** | Ship | Marketplace | Golden version released |

---

## Phase 0: Extraction & Git Subtree Setup

### Goal
Separate Juice into its own repo while keeping it developable inside Cold Soul.

### 0.1 Dependency Audit — ✅ DONE

Verified the Juice folder has **zero** dependencies on Cold Soul:

- [x] No references to `GameController`, `SceneManager`, or any Cold Soul autoload
- [x] No `res://` paths pointing outside `addons/juice/`
- [x] No `preload()`/`load()` calls to Cold Soul resources
- [x] Test scenes are NOT part of the addon (they stay in Cold Soul)
- [x] Icons/resources used by Juice scripts either live inside the Juice folder or are optional
- [x] `SignalRelayJuiceUtility` signal bus path now configurable (was hardcoded `/root/SignalBus`)
- [x] `JuiceTimeCoordinator` renamed to `TimeCoordinatorJuiceUtility` (naming convention)

**Result:** The `addons/juice/` folder is fully self-contained.

### 0.2 Folder Restructure — ✅ DONE

Moved from `Components/Component Nodes/Juice/` to addon format:

```
addons/
  juice/
    JuiceCompBase.gd
    2D/
    3D/
    Camera/
    Control/
    Events and Time/
    Property/
    Screen/
    Shaders/
    Utility/
    VFX/
    Visibility/
    Icons/                  ← Custom SVG icons for all Juice components (✅ DONE)
```

**Decided:** Yes — `plugin.cfg` + `juice_plugin.gd` (EditorPlugin) created.
Transport controls migrated from `addons/juice_transport_controls/` into `addons/juice/Editor/`.

### 0.3 Create Standalone Juice Repo — ✅ DONE

```powershell
# Standalone repo: https://github.com/nikolakovacBTG/Juice.git
# Remote name: juice-standalone

git remote add juice-standalone https://github.com/nikolakovacBTG/Juice.git
git subtree push --prefix=addons/juice juice-standalone main
```

### 0.4 Verify Round-Trip — ✅ DONE

```powershell
# In a DIFFERENT folder, clone the standalone repo
git clone https://github.com/nikolakovacBTG/Juice.git D:\Godot projekti\Juice_Standalone_Test

# Open in Godot — verified 2026-02-23 (no errors)
# Make a test edit, commit, push when needed

# Back in Cold Soul — pull the change
git subtree pull --prefix=addons/juice juice-standalone main --squash
```

### 0.5 Sync Workflow (daily use)

Create `sync_juice.ps1` in Cold Soul root:

```powershell
# Push Cold Soul's juice changes to standalone repo
git subtree push --prefix=addons/juice juice-standalone main

# Or pull latest from standalone into Cold Soul
# git subtree pull --prefix=addons/juice juice-standalone main --squash
```

**Rule:** Use `--squash` on pulls to keep the host project's history clean.

### 0.6 Tag Strategy

In the standalone Juice repo:
- `v0.9-alpha` — extraction complete, working in Cold Soul
- `v0.9-beta` — after code review (Phase 2)
- `v1.0-rc1` — after demo testing (Phase 3)
- `v1.0` — ship

**Projects that need stability** (future games) pull tagged versions only.
**Active development projects** (Cold Soul, Juice Demo) track `main`.

---

## Phase 1: Inventory

### Goal
Complete master checklist of every script in the Juice system, tracking shipping readiness.

### Deliverable

A table in `Documentation/Juice_Component_Inventory.md`:

| # | Class Name | Finished | Demoed | Documented | Presets | Notes |
|---|------------|:---:|:---:|:---:|:---:|-------|
| 1 | `JuiceCompBase` | | | | — | Abstract base |
| 2 | `TransformControlJuiceComp` | | | | | |
| ... | ... | ... | ... | ... | ... | ... |

**Column definitions:**
- **Finished** — Code is final, reviewed, no known bugs
- **Demoed** — Has a polished demo in Juice Demo project
- **Documented** — Inline (export tooltips, header comments) + manual + videos
- **Presets** — Ready-to-copy preset scenes created

This table becomes the master checklist for Phases 2–5.

### What to include
- All domain comps (Control, 2D, 3D, Property)
- Utility scripts (Interaction2DJuiceUtility, Interaction3DJuiceUtility, etc.)
- Support scripts (CameraJuiceReceiverComp, ScreenJuiceReceiver, etc.)
- Flow comps (SequencerJuiceComp, RandomJuiceComp)
- SoftTriggerJuiceComp
- Editor tooling (JuicePreviewDirector, juice_plugin.gd)

---

## Phase 2: Code Review (Alpha → Beta)

### Goal
Eliminate AI slop, reduce unnecessary complexity, optimize without sacrificing clarity.

### Review Targets

| Category | What to Look For |
|----------|-----------------|
| **Redundant abstractions** | Code that exists "just in case" but is never used |
| **Copy-paste drift** | Similar logic across 3 domain variants that could share a helper |
| **Over-defensive code** | Null checks that can never trigger given the architecture |
| **AI verbosity** | Unnecessary intermediate variables, over-commented obvious code |
| **Magic values** | Hardcoded numbers or strings that should be exports or constants |
| **Dead paths** | Match/if branches that can never execute |
| **Signal misuse** | Signals used for 1-to-1 communication that should be direct calls |
| **Performance** | Allocations in hot loops, unnecessary per-frame work |

### Process

1. **Self-review with current model (Claude)** — systematic file-by-file audit
2. **Cross-review with different AI model(s)** — fresh eyes, different blind spots
3. **Human review (you)** — final arbiter on architecture decisions
4. **Each review produces a tracking doc** (like the Beta Code Review Plan)
5. **Fix items in sprints**, commit after each logical unit

### Principle

> "Reduce lines" means removing unnecessary lines, NOT compressing necessary logic.
> 10 clear lines always beat 3 clever ones.

---

## Phase 2.5: Test Harness

### Goal
Automated regression tests that catch breakage after any refactor.

### Approach

A test scene (`res://addons/juice/tests/juice_test_runner.tscn`) with a script that:

1. Instantiates each comp type programmatically
2. Verifies initial state (not playing, natural values captured)
3. Calls `animate_in()` → verifies `is_playing()` == true
4. Waits for completion → verifies `is_playing()` == false
5. Calls `animate_out()` → verifies reverse works
6. Verifies natural state is restored after full cycle
7. Tests sequencer recipe clone/restore cycle
8. Prints PASS/FAIL per comp

**This is NOT a unit test framework** — it's a Godot scene you run. Press play, read the output. Green = good, red = investigate.

### Coverage targets
- Every comp in at least one domain
- Sequencer in all 3 modes (SEQUENCERS_CHILDREN, TARGETS_STACK, TARGETS_CHILDREN)
- Polarity triggers (animate_in + animate_out cycle)
- Edge cases: retrigger during animation, stop mid-animation, reset_to_natural

---

## Phase 3: Demo Project & Beta Testing

### Goal
A standalone Godot project that showcases every Juice comp in polished, marketable demos. Also serves as a preset library.

### 3.1 Create Juice Demo Project

```powershell
# Create new Godot project
# Add Juice via subtree
git subtree add --prefix=addons/juice juice-standalone main --squash
```

### 3.2 Demo Structure

> **NOTE:** This is an AI-proposed structure. The user has a different vision for demo organization.
> To be replaced with user's design when Phase 3 begins.

```
Juice Demo/
  addons/juice/           ← Subtree from standalone repo
  demos/
    control/              ← GUI demos (buttons, panels, menus)
    2d/                   ← 2D demos (sprites, platformer feel)
    3d/                   ← 3D demos (objects, materials, camera)
    presets/              ← Ready-to-copy recipe scenes
  project.godot
  README.md
```

### 3.3 Demo Design Principles

- Each demo showcases 1-3 related comps in a visually appealing context
- Demos are self-contained scenes — drag into any project
- Presets are minimal scenes with just the juice comp stack — copy-paste ready
- Every demo has a brief on-screen description of what's happening

### 3.4 Beta Testing Process

Building demos IS the testing. For each demo:

1. Build the demo scene using the comp
2. Does it work as expected? → If not, file a bug, fix in Cold Soul, sync
3. Does the inspector make sense for a first-time user? → If not, improve labels/grouping
4. Does the comp interact well with others? → Test combinations
5. Is the default configuration useful? → Adjust defaults if needed

**Rule:** Fixes go into Cold Soul first (the development environment), then sync to standalone, then pull into Juice Demo. Never fix directly in Juice Demo.

---

## Phase 4: Documentation & Polish

> **NOTE:** User has a broader documentation vision that will be designed separately.
> Planned layers: tooltip comments on exports, sharpened script headers, text+image docs,
> website documentation with GIFs/videos, YouTube video tutorials.
> This phase will be properly designed when the time comes.

### Goal
Everything a customer needs to use the addon without reading source code.

### Polish Checklist (preliminary)

- [ ] All comps have clear `@export_group` names
- [ ] All comps have header comments readable by non-authors
- [ ] Inspector tooltips (hint strings) on non-obvious exports
- [ ] Default values produce a visible effect (no "configure 5 things before it works")
- [ ] `plugin.cfg` with proper name, description, author, version
- [ ] Addon icon

---

## Phase 5: Ship

### Shipping Criteria (Definition of Done)

**Must have:**
- [ ] Every comp works in all applicable domains (Control, 2D, 3D)
- [ ] Every comp has a demo in Juice Demo
- [ ] Every comp has a preset scene ready for copy-paste
- [ ] Zero `push_warning()` or `push_error()` in normal operation
- [ ] Test harness passes 100%
- [ ] README + quick-start tested by a non-programmer
- [ ] Inspector UX reviewed by a non-programmer (you)
- [ ] No Cold Soul dependencies (verified by running in blank project)
- [ ] Tagged `v1.0` in standalone repo

**Nice to have:**
- [ ] Video trailer showing demos
- [ ] GIF previews per component for marketplace listing
- [ ] Comparison: "without juice" vs "with juice" side-by-side

### Marketplace Listing

- **Godot Asset Library** (free or paid)
- **itch.io** (if paid, allows "pay what you want")
- **GitHub** (if open-source or freemium)

---

## Sync Workflow Reference

### Push changes from Cold Soul to standalone
```powershell
git subtree push --prefix=addons/juice juice-standalone main
```

### Pull latest into Juice Demo
```powershell
git subtree pull --prefix=addons/juice juice-standalone main --squash
```

### Tag a release (in standalone repo)
```powershell
git tag -a v0.9-beta -m "Beta: code review complete"
git push origin v0.9-beta
```

### Pull a specific tag into a stable project
```powershell
git subtree pull --prefix=addons/juice juice-standalone v0.9-beta --squash
```

---

## Current Status

| Phase | Status | Notes |
|-------|--------|-------|
| 0 — Extraction | ✅ DONE | Folder restructured, dependency audit clean, transport controls migrated, naming conventions fixed |
| 1 — Inventory | 🔲 IN PROGRESS | |
| 2 — Code Review | 🔲 NOT STARTED | Previous beta review (R1-R6) complete |
| 2.5 — Test Harness | 🔲 NOT STARTED | |
| 3 — Demo Project | 🔲 NOT STARTED | |
| 4 — Docs & Polish | 🔲 NOT STARTED | |
| 5 — Ship | 🔲 NOT STARTED | |

---

**END OF SHIPPING PLAN**
