# Juice System — BETA Milestone Plan

> **Status:** Planning
> **Prerequisite:** MVP Alpha complete (Transport Controls shipped, all core components working)
> **Goal:** Production-ready Godot plugin suitable for public release, marketing, and cross-project reuse.

---

## B1. Code Review & Cleanup

**Owner:** Cascade
**Status:** Not started

### Goal
Thorough code review of the entire Juice codebase to:
- Remove dead code (unused functions, variables, imports)
- Remove stale code (superseded patterns, old workarounds)
- Identify and fix anti-patterns
- Ensure consistency across all scripts
- Verify all scripts follow project coding standards (AGENTS.md)

### Review Checklist
- [ ] **Dead code:** Unused functions, variables, signals, enums
- [ ] **Stale code:** Old workarounds, commented-out blocks, deprecated patterns
- [ ] **Anti-patterns:** String-based node lookup, hardcoded paths, magic numbers
- [ ] **Type safety:** All type-safe discovery uses `is` operator, not string matching
- [ ] **Header comments:** Every script has WHAT/WHY/SYSTEM/DOES NOT
- [ ] **Debug toggles:** Every script has `debug_enabled` flag
- [ ] **Signal documentation:** All signal connections documented with WHY
- [ ] **Error handling:** Graceful failures with debug logging
- [ ] **Naming conventions:** Follows AGENTS.md (XxxComp, XxxDef, etc.)
- [ ] **Inspector exposure:** All gameplay values are `@export`ed

### Process
1. Use `/review` workflow for systematic review
2. Present findings as a categorized report
3. Get approval for cleanup batch
4. Implement all approved changes
5. Git commit: `refactor: Juice beta code review cleanup`

---

## B2. Script Cleanup — Stale Comments

**Owner:** Cascade
**Status:** Not started — blocked by B1

### Goal
Remove all leftover stale, outdated, or misleading comments from every Juice script. Comments that reference old architecture, removed features, or superseded patterns must go.

### Process
1. Audit every script in the Juice sub-module
2. Flag comments that are stale, incorrect, or reference removed code
3. Present findings for review
4. Remove approved stale comments in a single batch
5. Git commit: `chore: remove stale comments from Juice scripts`

### Scripts to Audit
- JuiceBase.gd
- All subclass comp scripts (Scale, Rotate, Position, Color, Flash, Flicker, etc.)
- Camera comps (Camera3D, Camera2D, ScreenMotion)
- Property comps (Tween, Shake, Noise, Spring)
- Utility comps (SFX, VFX, Progress)
- Receiver comps (CameraJuiceReceiverComp, ScreenJuiceReceiver)
- Transport Controls (plugin, director)
- Helper/utility scripts (Clickable2DComp, Clickable3DComp, etc.)

---

## B3. Tooltip Comments (Inspector UX)

**Owner:** Cascade
**Status:** Not started — blocked by B2

### Goal
Add clear, helpful tooltip comments to all `@export` properties across all Juice scripts. These appear when hovering over properties in the Godot inspector.

### Standards
- Every `@export` property must have a `## tooltip comment` on the line above
- Tooltips should explain **what the property does** and **what values mean**
- Use plain language — assume the user has never seen the code
- Include units where applicable (seconds, degrees, pixels)
- For enums, briefly describe each option

### Example
```gdscript
## How long the IN animation takes, in seconds. Longer = slower, more dramatic.
@export var duration_in: float = 0.3

## What happens when the trigger fires. PLAY_IN_AND_OUT auto-reverses after playing in.
@export var trigger_behaviour: TriggerBehaviour = TriggerBehaviour.PLAY_IN_AND_OUT
```

---

## B4. Custom Icons for Juice Components

**Owner:** User (design), Cascade (implementation)
**Status:** ✅ DONE (2026-03-01)

### Approach
- User designed a "J"-based icon system with domain-specific variants and utility symbols
- All icons are SVG files in `addons/juice/Icons/`
- Applied via `@icon("res://addons/juice/Icons/...")` annotation on every script

### Icon Family Design
| Icon File | Used By | Symbol |
|-----------|---------|--------|
| JuiceBase.svg | JuiceBase (inherited by all) | J |
| JuiceBase2D.svg | All 2D domain comps | J (2D variant) |
| JuiceBase3D.svg | All 3D domain comps | J (3D variant) |
| JuiceBaseControl.svg | All Control domain comps | J (Control variant) |
| JuiceBaseProperty.svg | All Property domain comps | .PJ |
| JuiceBaseVFX.svg | VFX + Trail comps | J (VFX variant) |
| JuiceBaseVisibility.svg | Visibility comp | J (Visibility variant) |
| JuiceUtilityArea2D.svg | Interaction2DJuiceUtility | Area2D variant |
| JuiceUtilityArea3D.svg | Interaction3DJuiceUtility | Area3D variant |
| JuiceUtilityMethods.svg | CallMethodJuiceUtility | .()J |
| JuiceUtilitySignals.svg | SignalRelay + SignalEmit utilities | Signal variant |
| JuiceUtilityTimeCoord.svg | TimeCoordinatorJuiceUtility | Time variant |
| JuiceUtilityTriggerControl.svg | SoftTriggerControlJuiceUtility | Trigger variant |
| JuiceUtilityScreen.svg | ScreenOverlay + ScreenJuiceUtility | Screen variant |
| JuiceCollisionShape2D.svg | Reference (naming convention) | CollisionShape2D |
| JuiceCollisionShape3D.svg | Reference (naming convention) | CollisionShape3D |

### Additional UX
- Auto-generated collision shapes use `Juice_` naming prefix for visual identification
- SignalRelayJuiceUtility reverted to runtime-only (removed @tool complexity)

---

## B5. Git Sub-Module Extraction

**Owner:** User (git setup), Cascade (file moves, path fixes)
**Status:** ✅ DONE — Completed as Phase 0 of the Shipping Plan (2026-02-23)

### Result
- Juice lives at `addons/juice/` (fully self-contained addon)
- Standalone repo: `https://github.com/nikolakovacBTG/Juice.git`
- Sync method: Git Subtree (`git subtree push/pull`)
- Transport controls migrated into `addons/juice/Editor/`
- Zero Cold Soul dependencies verified
- See `Juice_Shipping_Plan.md` Phase 0 for full details

---

## B6. Demo Project (Marketing Content)

**Owner:** User (creative direction), Cascade (implementation)
**Status:** 🔲 IN PROGRESS — Demo project created, no content yet

### Goal
A standalone Godot project that showcases the Juice system's power through visually impressive, interactive scenes. Used for marketing videos, tutorials, and as a downloadable demo.

### Requirements
- Multiple scenes demonstrating different juice categories
- Juicy UI menus and transitions
- Reusable presets (saved as .tres resources) that users can drop into their own projects
- Clean, well-organized project structure
- Runs standalone — no Cold Soul dependencies

### Scene Ideas (brainstorm)
- **Interactive Showcase:** Grid of objects, click to trigger different juice effects
- **UI Demo:** Animated menus, buttons, transitions, notifications
- **Game-like Scene:** Mini-game or simulation with juice applied everywhere
- **A/B Comparison:** Side-by-side with/without juice to demonstrate impact
- **Preset Gallery:** Browse and preview available presets

### Preset Library
- Create `.tres` preset resources for common juice patterns
- Categories: UI buttons, UI transitions, hit feedback, pickups, environmental, camera
- Each preset should work out-of-the-box when attached to a node

---

## B7. Documentation & Animated GIFs

**Owner:** User (GIF capture), Cascade (written docs)
**Status:** Not started — blocked by B3, B6

### Goal
Comprehensive documentation for the Juice system, suitable for:
- Plugin marketplace listing (README)
- GitHub repo wiki / README
- In-editor help (tooltip comments cover this — see B3)

### Documentation Outline
1. **Quick Start Guide** — Install, add first juice comp, see it work
2. **Component Reference** — One page per comp type with parameters, examples, GIFs
3. **Architecture Overview** — How comps work, trigger system, preview system
4. **Preset Guide** — How to create, save, and share presets
5. **Advanced Patterns** — Cross-scene targeting, signal relay, custom triggers
6. **FAQ / Troubleshooting** — Common issues and solutions

### Animated GIFs
- One GIF per component showing its signature effect
- Before/after GIFs for the A/B comparison
- UI interaction GIFs for the transport controls
- Capture tool: TBD (OBS, ScreenToGif, Godot's built-in recorder)

---

## B8. Marketing Videos & Tutorials

**Owner:** User
**Status:** Not started — BETA testing phase, not this milestone

### Notes
- Short-form videos for social media (Twitter/X, YouTube Shorts, TikTok)
- Tutorial videos: "Add juice to your Godot game in 5 minutes"
- Depends on demo project (B6) and documentation (B7) being complete
- Research: recording workflow, editing tools, music/SFX licensing

> This task is tracked here for completeness but is explicitly **out of scope** for the current BETA development milestone. It belongs to the BETA testing / release phase.

---

## B9. Performance Profiling

**Owner:** Cascade
**Status:** Not started — after demo is feature-complete

### Goal
Verify that the composition-heavy Juice architecture performs well enough for production use. Stress test with increasing target counts to identify bottlenecks.

### Details
See `Juice_Shipping_Plan.md` Phase 2.6 for full test plan (metrics, variants, thresholds).

---

## Execution Order Summary

| Phase | Task | Blocked By | Priority |
|-------|------|-----------|----------|
| B1 | Code Review & Cleanup | — | High |
| B2 | Stale Comment Removal | B1 | High |
| B3 | Tooltip Comments | B2 | High |
| B4 | Custom Icons | ✅ DONE (2026-03-01) | Medium |
| B5 | Git Sub-Module Extraction | ✅ DONE (Phase 0, 2026-02-23) | High |
| B6 | Demo Project | B5 | High |
| B7 | Documentation & GIFs | B3, B6 | Medium |
| B8 | Marketing & Tutorials | B7 | Low (next phase) |
| B9 | Performance Profiling | B6 | Medium (pre-ship) |

> **Rationale:** Clean the code first (B1 → B2 → B3), then extract to sub-module (B5), then build the demo (B6) and docs (B7). Icons (B4) can happen in parallel whenever designs are ready.

---

## Product Tiers (Reference)

Per user's product plan:
- **Lite:** Basic workflow + core components, lower price point
- **Pro:** All features, advanced components, editor tooling, full preset library

Tier boundaries to be defined during demo project creation.
