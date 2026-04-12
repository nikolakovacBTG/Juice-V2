# Juice System — Documentation Pass Plan

> **Created:** 2026-03-02
> **Status:** In Progress (parallel with Demo Project development)
> **Covers:** B1 (Code Review), B2 (Stale Comments), B3 (Tooltip Comments) — executed together, script by script
> **Execution:** One script at a time, in parallel with Demo Project (B6) development

---

## Philosophy

This is a slow, thorough pass. Each script gets reviewed, cleaned, and documented as part of building the Demo Project. The Demo serves four purposes simultaneously:

1. **Footage capture** — every comp demoed visually for marketing
2. **True system testing** — real usage exposes real bugs
3. **Script-by-script review** — each script touched as its demo is built
4. **Marketable demo + tutorial project** — the end product

B1, B2, B3, and B6 run in parallel. When you build a demo for a comp, you also review its code, clean its comments, and write its documentation. One script, fully polished, before moving to the next.

---

## Comment Convention

Godot uses `##` (double-hash) as **documentation comments** — these surface in the editor UI (tooltips, Script docs viewer, Add Child Node dialog). Single `#` comments are developer-only and never shown to users.

### The Problem (Before)

```gdscript
## JuiceBase.gd
## ============================================================================
## WHAT: Base class for all juice/feedback components in the Juice System.
## WHY: Provides shared timing, easing, auto-connect, and chaining logic so
##      concrete components only implement their specific effect.
## SYSTEM: Juice System (addons/juice/)
## DOES NOT: Implement any visual/audio effect - subclasses do that.
## ============================================================================
##
## ARCHITECTURE (Phase 3.5 - Delta-Based):
## ...30 more lines...

@tool
class_name JuiceBase
extends Node
```

This entire block becomes the Add Child Node tooltip — unreadable.

### The Fix (After)

```gdscript
## Base class for all Juice feedback components.
##
## Provides shared timing, easing, auto-connect, and chaining logic.
## Subclasses implement their specific visual/audio effect by overriding
## [method _apply_effect]. Add as a child of any node and configure via
## the inspector.
##
## @tutorial(Juice Quick Start): https://example.com/juice-quickstart
## @experimental

# ============================================================================
# ARCHITECTURE (Developer Notes — not shown in editor docs):
# Animation is progress-based: 0.0 = natural state, 1.0 = effect fully applied.
# Subclasses define an OFFSET/DELTA, not from/to values.
# animate_in() tweens progress from current → 1.0
# animate_out() tweens progress from current → 0.0
# ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBase.svg")
class_name JuiceBase
extends Node
```

### Rules

| Syntax | Purpose | Visible In |
|--------|---------|------------|
| `## Brief sentence.` | First line = Add Child Node tooltip | Tooltip + Script docs |
| `##` (blank) then `## Paragraph` | Detailed class description | Script docs viewer only |
| `## @tutorial(Name): URL` | Links to external docs/videos | Script docs "Online Tutorials" |
| `## @experimental` / `## @deprecated` | Stability markers | Script docs badge |
| `## Above @export` | Inspector property tooltip | Inspector hover + Script docs |
| `## Above func/signal/enum` | API reference for members | Script docs viewer |
| `# Single hash` | Dev notes, architecture, WHY | Source code only (never in editor) |

---

## 3-Layer Documentation Strategy

| Layer | Audience | Where | Content |
|-------|----------|-------|---------|
| **1. Tooltips** | Artist in inspector | `##` on `@export` vars | Short, plain language, BBCode formatting |
| **2. Class Docs** | Developer in Script viewport | `##` at script top + on members | Brief + description + @tutorial + cross-refs |
| **3. External Docs** | Everyone | Website/videos (linked via `@tutorial`) | Full guides, video tutorials, animated demos |

### Layer 1: Inspector Tooltips (`##` on exports)

```gdscript
## What happens when the trigger fires.[br]
## [b]PLAY_IN_AND_OUT:[/b] Auto-reverses after playing in.[br]
## [b]PLAY_IN_ONLY:[/b] Plays in and stays.[br]
## [b]SET_FROM_SOURCE:[/b] Follows a boolean state signal.
@export var trigger_behaviour: TriggerBehaviour = TriggerBehaviour.PLAY_IN_AND_OUT
```

- Every `@export` must have a `##` tooltip above it
- Use plain language — assume the user has never seen the code
- Include units where applicable (seconds, degrees, pixels)
- For enums, briefly describe each option
- Use BBCode: `[b]`, `[code]`, `[br]`, `[member]`, `[method]`

### Layer 2: Class Docs (`##` at script top + on members)

```gdscript
## Animate the position of a [Control] node with tween-based easing.
##
## Displaces [member Control.position] by [member position_offset] pixels
## during animate-in, and returns to the original position on animate-out.
## Useful for slide-in menus, notification entries, and button press feedback.
##
## @tutorial(Position Juice): https://example.com/juice/position
## @experimental
```

Structure:
1. **Brief** (first line) — one sentence, shown in Add Child Node tooltip
2. **Description** (after blank `##`) — 2-4 sentences, explains what it does and common use cases
3. **@tutorial** — links to video/written tutorials
4. **@experimental / @deprecated** — stability tag

Cross-reference other classes and members:
- `[JuiceBase]` — links to class
- `[method animate_in]` — links to method
- `[member duration_in]` — links to property
- `[signal animation_started]` — links to signal
- `[enum TriggerBehaviour]` — links to enum

### Layer 3: External Documentation

- Video tutorials (planned — user will create)
- Written guides on website/GitHub (future)
- Linked from scripts via `@tutorial` tags
- Covers: quick start, component recipes, architecture overview, advanced patterns
- Animated demos go here (Godot docs don't support GIF animation)

### Images in Docs

Godot `##` comments support `[img]` BBCode:
```gdscript
## [img width=64]res://addons/juice/docs/images/bounce_diagram.png[/img]
```

- Static images (PNG, SVG) work — good for diagrams
- **No animated GIF support** in the editor viewer
- For animated demos, use `@tutorial` links to external video/GIF content
- Images must use `res://` paths (bundled with addon)

---

## Per-Script Checklist

When touching a script (during Demo development), apply this checklist:

### Documentation (B3)
- [ ] **Brief description** — one sentence `##` before `class_name` (or after `extends`)
- [ ] **Detailed description** — 2-4 sentences after blank `##` line
- [ ] **@tutorial link** — to relevant external doc (placeholder URL is fine for now)
- [ ] **@experimental tag** — if not yet stable
- [ ] **Export tooltips** — every `@export` has a `##` above it with plain-language description
- [ ] **Member docs** — public methods, signals, and enums have `##` descriptions
- [ ] **BBCode cross-refs** — use `[method]`, `[member]`, `[signal]`, `[enum]`, `[ClassName]` where helpful

### Comment Cleanup (B2)
- [ ] **Demote dev notes** — move WHAT/WHY/SYSTEM/ARCHITECTURE blocks from `##` to `#`
- [ ] **Remove stale comments** — references to old architecture, removed features, superseded patterns
- [ ] **Remove filename comment** — `## ScriptName.gd` line (redundant — the file IS the name)
- [ ] **Remove separator bars** — `## ====` decorations in doc comments (they render as literal text)

### Code Review (B1)
- [ ] **Dead code** — unused functions, variables, signals, enums
- [ ] **Stale code** — old workarounds, commented-out blocks, deprecated patterns
- [ ] **Anti-patterns** — string-based node lookup, hardcoded paths, magic numbers
- [ ] **Type safety** — all discovery uses `is` operator, not string matching
- [ ] **Debug toggle** — `@export var debug_enabled: bool = false` present
- [ ] **Naming** — follows AGENTS.md conventions
- [ ] **Inspector groups** — logical `@export_group` structure

---

## Execution Flow

```
For each script being demoed:

  1. BUILD the demo scene in Demo Project
     ├── Use the comp in a real, polished context
     ├── Note any bugs or UX friction
     └── Capture footage / screenshots

  2. REVIEW the script (B1)
     ├── Check for dead code, anti-patterns
     ├── Fix any bugs found during demo
     └── Verify naming and type safety

  3. CLEAN comments (B2)
     ├── Demote ## dev notes to #
     ├── Remove stale/outdated comments
     └── Remove decoration (====, filename lines)

  4. DOCUMENT (B3)
     ├── Write brief + description (## at top)
     ├── Write export tooltips (## on @exports)
     ├── Add @tutorial links
     └── Add BBCode cross-references

  5. COMMIT
     └── "docs(juice): review + document [ComponentName]"
```

---

## Tracking

Progress is tracked per-script. Mark each column as the script passes through the flow:

| # | Script | Demoed | Reviewed (B1) | Cleaned (B2) | Documented (B3) | Committed |
|---|--------|:---:|:---:|:---:|:---:|:---:|
| 1 | JuiceBase | | | | | |
| 2 | TransformControlJuiceComp | | | | | |
| 3 | Transform2DJuiceComp | | | | | |
| 4 | Transform3DJuiceComp | | | | | |
| 5 | NoiseControlJuiceComp | | | | | |
| 6 | Noise2DJuiceComp | | | | | |
| 7 | Noise3DJuiceComp | | | | | |
| 8 | AppearanceControlJuiceComp | | | | | |
| 9 | Appearance2DJuiceComp | | | | | |
| 10 | Appearance3DJuiceComp | | | | | |
| 11 | Outline2DJuiceComp | | | | | |
| 12 | OutlineControlJuiceComp | | | | | |
| 13 | Outline3DJuiceComp | | | | | |
| 14 | VisibilityJuiceComp | | | | | |
| 15 | Camera3DJuiceComp | | | | | |
| 16 | Camera2DJuiceComp | | | | | |
| 17 | CameraJuiceUtility | | | | | |
| 18 | CameraJuiceReceiverComp | | | | | |
| 19 | ScreenMotionJuiceComp | | | | | |
| 20 | ScreenOverlayJuiceComp | | | | | |
| 21 | ScreenJuiceUtility | | | | | |
| 22 | NoisePropertyJuiceComp | | | | | |
| 23 | ShakePropertyJuiceComp | | | | | |
| 24 | SpringPropertyJuiceComp | | | | | |
| 25 | ProgressPropertyJuiceComp | | | | | |
| 26 | SFXJuiceComp | | | | | |
| 27 | VFXJuiceComp | | | | | |
| 28 | TrailJuiceComp | | | | | |
| 29 | SequencerJuiceComp | | | | | |
| 30 | RandomJuiceComp | | | | | |
| 31 | SoftTriggerControlJuiceUtility | | | | | |
| 32 | Interaction3DJuiceUtility | | | | | |
| 33 | Interaction2DJuiceUtility | | | | | |
| 34 | SignalRelayJuiceUtility | | | | | |
| 35 | SignalEmitJuiceUtility | | | | | |
| 36 | CallMethodJuiceUtility | | | | | |
| 37 | TimeCoordinatorJuiceUtility | | | | | |
| 38 | JuicePreviewDirector | | | | | |
| 39 | juice_plugin.gd | | | | | |

> **Note:** Add rows for any new scripts created during the pass. JuiceBase should be done first since all other scripts reference it.

---

## @tutorial URL Strategy

Until external documentation is hosted, use placeholder URLs:

```gdscript
## @tutorial(Juice Quick Start): https://juice.example.com/quickstart
## @tutorial(Transform Juice): https://juice.example.com/components/transform
```

These will be bulk-replaced with real URLs once the documentation site or video playlist is live. The placeholder structure establishes the linking pattern now so nothing is missed later.

---

## Relationship to Beta Milestone Plan

This plan replaces the sequential B1 → B2 → B3 flow with a **parallel, per-script** flow:

| Beta Phase | Old Plan | New Plan |
|------------|----------|----------|
| B1 (Code Review) | All scripts, then B2 | Per-script, during demo development |
| B2 (Stale Comments) | All scripts, then B3 | Per-script, same pass as B1 |
| B3 (Tooltip Comments) | All scripts at once | Per-script, same pass as B1+B2 |
| B6 (Demo Project) | After B5 | **Drives the whole process** — demo first, then review+document |

The Demo Project is the engine that drives B1, B2, and B3. Building a demo for a comp forces you to use it, which forces you to review it, which is the natural time to clean and document it.

---

**END OF DOCUMENTATION PASS PLAN**
