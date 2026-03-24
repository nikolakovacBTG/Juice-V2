# Juice Product Suite Strategy

> **Purpose:** Strategic architecture and product decisions for the Juice brand suite.
> **Status:** Active — guiding V1 completion and future product planning.
> **Date:** 2025-03-24

---

## Suite Overview

The Juice brand is a suite of Godot 4.x addon products that make "juicing" games
dramatically easier. Each product targets a different class of visual/feel effects
while sharing UX patterns, trigger conventions, and interoperability.

| Product | Mental Model | Status |
|---------|-------------|--------|
| **Juice** (Core) | "I choreograph how this moves/looks" — animation-driven | Shipping V1 |
| **Reactor** (Physics DLC) | "I define how this reacts physically" — physics-driven | Future product |
| **Shader Effects DLC** | Visual shader effects (dissolve, glitch, hologram, etc.) | Future DLC |
| **Faux-3D DLC** | Perspective tilt illusion for 2D/Control | Future DLC |
| **Audio Juice** | Audio-reactive visuals, beat sync | Future product |

---

## Product 1: Juice (Core — V1)

Everything animation-driven. One mental model: *"I define HOW this should move/look."*

### Effect Categories

| Category | Domains | V1 Status |
|----------|---------|-----------|
| Transform | Control, 2D, 3D | ✅ Ported |
| SquashStretch | Control, 2D, 3D | ✅ Ported |
| Noise | Control, 2D, 3D | ✅ Ported |
| Shake | Control, 2D, 3D | ✅ Ported |
| Appearance | Control, 2D, 3D | 🔲 To port |
| Progress | Control, 2D, 3D | 🔲 To port |
| Camera | 2D, 3D | 🔲 To port |
| Screen (Motion, Overlay) | Global | 🔲 To port |
| Time | Global | 🔲 To port |
| Property (Noise, Shake, Progress, Shader) | Generic | 🔲 To port |
| VFX (Particles, Trail) | 2D, 3D | 🔲 To port |
| Visibility | All | 🔲 To port |

### Infrastructure

- **JuiceComp** (V0) / **JuiceControl, Juice2D, Juice3D** (V1 domain nodes)
- **JuiceRecipe** — composable effect stacks
- **Sequencer** — timeline orchestration with stagger, warmup, retrigger policies
- **Virtual Pivots** — effects compute position delta compensation, never mutate pivot_offset
- **Utilities** — Interaction, SoftTrigger, SignalRelay, CallMethod, SceneAction, etc.

### What was CUT from V1

- **Spring** (all domains) — continuous physics simulation doesn't fit animation lifecycle.
  Deferred to Reactor product.
- **SpringProperty** — same reason. Physics-based property animation belongs in Reactor.

### Architecture Characteristics

- Effects are **pure delta calculators** — compute offset from natural state at given progress
- Domain nodes **own write coordination** — aggregate deltas, write once per frame
- All effects follow **progress 0→1** lifecycle with curves and easing
- Stacking via **delta composition** — effects sum, never fight over properties

---

## Product 2: Reactor (Physics DLC — Future)

Everything physics-driven. Different mental model: *"I define HOW this should REACT."*

### Why Separate Product (not crammed into Juice)

| Concern | Crammed into Juice | Separate Reactor |
|---------|-------------------|-----------------|
| UX clarity | Inspector maze — "which effects are physics?" | Clean: Juice = curves, Reactor = physics |
| Architecture | Physics needs different base, lifecycle, virtual pivots | Own infrastructure, tailored |
| Target audience | Confuses beginners | Beginners buy Juice. Pros add Reactor. |
| Marketing | Hard to explain one product that does two things | Two clear pitches |
| Interop | N/A | Reactor nodes live NEXT TO Juice nodes, communicate via displacement |

### Planned Effects

| Effect | Description | Domains |
|--------|-------------|---------|
| Spring | Mass-spring-damper on position/rotation/scale | Control, 2D, 3D |
| Pendulum | Gravity-driven swing (signs, chains, lanterns) | 2D, 3D |
| Momentum/Inertia | Overshoot on any transform change | Control, 2D, 3D |
| Jiggle/Soft Body | Vertex-level spring mesh | Control, 2D |
| Buoyancy | Float/bob with wave surface | 2D, 3D |
| Wind Response | Procedural sway from wind field | 2D, 3D |
| SpringProperty | Physics-based generic property animation | Generic |

### Architecture (Own Infrastructure)

- `ReactorControl`, `Reactor2D`, `Reactor3D` domain nodes
- `ReactorEffectBase` with physics sub-stepping, NaN guards, energy-based settlement
- `ReactorRecipe` format
- **Virtual pivot system** built-in from day one
- Continuous physics simulation, not progress 0→1
- Leverages Godot's built-in physics features where possible

### Reuses from Juice

- Trigger system (signals, auto-connect patterns)
- Signal conventions (animate_in_started, completed, etc.)
- Sequencer integration (Reactor effects can be sequenced)
- Inspector UX patterns (conditional exports, subgroups)

---

## User Workflow (Both Products)

```
Target Node
├── JuiceControl          ← "slide in from left over 0.5s with bounce ease"
│   └── Recipe: [Transform, SquashStretch]
└── ReactorControl        ← "wobble physically when anything moves me"
    └── Recipe: [Spring(rotation), Momentum(scale)]
```

Same inspector patterns. Same trigger system. Two clearly different nodes.
Non-coder understands: "Juice = I choreograph it. Reactor = it reacts on its own."

---

## DLC → Product Mapping

| DLC Idea | Product |
|----------|---------|
| Physics-Driven Reactive Pack | = Reactor core |
| Advanced Motion (bezier, orbit) | Juice DLC (animation-driven paths) |
| Advanced Motion (magnetic, attraction) | Reactor (physics-driven) |
| Shader Effects | Juice DLC (Appearance effects) |
| Faux-3D Perspective Tilt | Either — cursor-relative = Reactor, canned = Juice |
| Audio Juice | Separate product |
| Particle Presets | Juice DLC (VFX category) |
| UI Juice Shader StyleBox | Juice DLC (Control domain) |

---

## Key Architecture Decisions

1. **V1 is the right architecture for Juice** — all remaining effects are animation-driven
2. **Spring cut was correct** — physics simulations are a different product category
3. **Virtual pivots** — effects compute position delta for pivot compensation, never mutate node properties
4. **Reactor is a separate product** — different lifecycle, different base class, clean separation
5. **Shared conventions** — trigger system, signals, inspector UX are brand-level standards
