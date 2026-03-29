# Juice V1 — Philosophy & Vision

> Extracted from Documentation/ folder, JUICE_CONTEXT.md, AGENTS.md, and design docs.

## Mission

Build the **definitive "game feel" addon for Godot 4.x** — inspector-driven, zero-code-required feedback components that make any game feel polished. Ship on the Godot Asset Library and marketplace as a premium product.

## Core Design Principles

### 1. Inspector-Driven, Zero Code Required
The primary user is a **non-programmer game developer**. Every effect must be fully configurable from the Godot Inspector with no GDScript knowledge needed. If a feature requires the user to write code, it has failed.

### 2. Three Domains — Always
Every effect must work in **Control** (UI), **2D** (Node2D), and **3D** (Node3D). If an effect exists in one domain but not the others, it is a **bug**. This is the single most important architectural rule.

### 3. Effects Stackable, Delta-First, Write-Once
Juice domain nodes must be stackable on their parent/target, and effects stackable in their recipe.
Effects are pure math — they compute offsets. The domain node owns all writes. This prevents effects from fighting each other and enables clean stacking.

### 4. Marketplace-Grade Quality
- Every script has header comments, typed exports, debug toggles
- Code must work in ANY project without path assumptions
- No external dependencies
- Refactor-proof (type-safe discovery, no hardcoded names)

### 5. Recipe System = Shareability
Recipes (`.tres` files) make effects portable, shareable, and marketplace-ready. Users can export/import effect presets. This is the DLC/expansion model.

## Product Strategy

### Core Product: Juice V1
- Free/paid addon on Godot Asset Library
- ~40 effects across Transform, Appearance, Camera, Screen, VFX, Events categories
- Inspector-driven, recipe-based

### Expansion Model (Post-V1)
From `Juice_DLC_Ideas.md`:
- **Shader Effects DLC**: Pixelate, wave, chromatic aberration, hue shift, hologram, glitch
- **Advanced Motion Pack**: Orbit, bezier paths, elastic chains
- **Audio Juice Pack**: Pitch/volume reactive, beat-sync
- **UI Juice Shader StyleBox**: StyleBox-based effects
- **Faux-3D Perspective Tilt**: Balatro-style card tilt
- **Physics-Driven Reactive Pack**: Pendulum, jiggle, momentum

### Product Suite Vision
From `Product_Suite_Strategy.md`:
- Juice is one product in a larger Godot tooling ecosystem
- Focus on polish/feel as the differentiator
- Each product should be independent but composable

## Development Philosophy

### Fix Forward, Not Backward
- Fixes go into the Demo project first
- Subtree push to standalone repo
- Pull into other projects as needed

### Test Everything
- 19 test suites, 100+ tests
- Custom test framework (not GUT — lightweight, headless-capable)
- **Never claim a feature works without citing a test name and result**

### Design Before Code
- `JuiceStack_Design.md` is the law
- If implementation differs from design doc, STOP and ask
- If a design gap is discovered, document it and ask

### Port Before Innovate
- V0 has ~55 proven effects
- V1 priority is porting those first
- New ideas go to roadmap, not immediately into code
- Balance: "Porting vs. Innovation"

## The "Juice" Philosophy

From the project name itself — the goal is to add **juice** (game feel, polish, feedback) to games:
- Screen shake on impact
- UI elements that bounce and spring
- Flash effects on damage
- Particle bursts on collection
- Camera zoom on boss encounter
- Time slow on critical hit

Everything should feel **alive, responsive, and satisfying** with zero programmer effort.

## Personal Coding Taste (From Developer)

- **Next port target**: Appearance effect (design doc ready in `Done/DONE_Appearance_Comp_Redesign.md`)
- **Demo strategy**: One showcase scene that plays like a game (no goal, just situations demoing possibilities). Covers all 3 domains. Built intuitively to beta-test real-life usage. Developer builds this manually — AI assists with debugging via MCP.
- **Release plan**: Port ALL effects → test → demo → ship as first general product. No partial releases.
- **Coding comfort**: Non-programmer. Needs concrete examples for advanced patterns. Wants to understand WHY, not just WHAT.
- **DLC/Shaders**: Strictly post-ship. No prototyping during V1 development.
- **Spring effect**: CUT from V1 scope. Deferred to separate future product (working title: "Reactor"). This was discovered through real-world demo beta testing.
- **Key insight**: Minimalistic tests (single button, no containers) failed to detect architectural shortcomings. Tests must be realistic.
