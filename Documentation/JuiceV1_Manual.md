# Juice V1 — User Manual

> **Version:** V1 (Godot 4.x)
> **Status:** Draft — skeleton with intro paragraphs being authored per-effect.

---

## How Juice Works

At the core of the Juice system is the **JuiceBase** node (`JuiceControl`, `Juice2D`, `Juice3D`), which hosts a **JuiceRecipe** resource. A recipe contains an array of **JuiceEffect** resources. 

**Effects are Resources, not Nodes:** Effects describe *what* should happen (e.g., "shake position by 10 pixels") and calculate mathematical deltas, but they do not modify the scene themselves. The `JuiceBase` node aggregates these deltas and applies them to the target node safely, ensuring that multiple effects can stack without fighting over the same properties.

### Playback Modes: Stack vs Sequencer

The `JuiceBase` node can execute its recipe's effects in two primary modes:
- **STACK:** All effects in the recipe are fired simultaneously on the parent node. Used for composite hits (e.g., a "Damage" recipe that plays a shake, a flash, and a knockback all at once).
- **SEQUENCER:** Effects target an array of `NodePath`s rather than the parent. Used for choreographed routines. The sequencer provides extensive control over *what* to animate (`TargetScope`: Siblings, Children, Custom) and *how* to order them (`SequenceType`: Stagger Forward, Stagger Reverse, Random, All At Once).

### Trigger Events

Effects are triggered based on the `trigger_on` and `trigger_source` configuration of the `JuiceBase` node. Triggers are tailored to the specific domain context:
- **UI & Input:** `ON_PRESS`, `ON_RELEASE`, `ON_MOUSE_ENTERED`, `ON_MOUSE_EXITED`, `ON_FOCUS`, `ON_UNFOCUS`
- **Visibility:** `ON_SHOW`, `ON_HIDE`
- **Physics (2D/3D):** `ON_BODY_ENTERED`, `ON_BODY_EXITED`, `ON_AREA_ENTERED`, `ON_AREA_EXITED`
- **Object clicks:** `ON_LEFT_CLICK`, `ON_RIGHT_CLICK`, `ON_MIDDLE_CLICK`
- **Lifecycle:** `ON_READY`
- **Manual/Programmatic:** `MANUAL` (requires an explicit `play()` call, or you can supply a `manual_trigger_signal` name).

You can also use an **EXTERNAL** trigger pattern via `SET_FROM_SOURCE` behavior, where the node is continuously driven by a utility (like `SoftTrigger`) passing proximity data.

### Animation Lifecycle, Behaviours & Looping

Every effect follows an envelope lifecycle: `animate_in` → `hold_at_peak` → `animate_out`. How the effect traverses this envelope is defined by the **Trigger Behaviour**:
- **PLAY_IN_AND_OUT:** Executes the full cycle automatically.
- **PLAY_IN_ONLY:** Stops and holds at the peak.
- **PLAY_OUT_ONLY:** Plays only the exit envelope.
- **TOGGLE:** Flips between playing in and playing out (requires a paired trigger like hover/focus or manual input).
- **SET_FROM_SOURCE:** Bypasses normal playback, instead directly mapping an external `0.0–1.0` value to the animation progress.

**Looping:** `JuiceBase` supports looping via the `Loop` configuration group. You can set a number of loops (`loop_count`), or loop infinitely (-1), optionally adding a `loop_delay` between iterations.

**Retrigger Policy:** What happens if a new trigger arrives while the effect is already playing? You can configure it to `RESTART` (stop and crossfade from beginning), `QUEUE` (play after current finishes), or `IGNORE` the new trigger.

---

# Effect Families

Effects are organized by *family* — what they do, not which domain they animate. Each family typically has a Control, 2D, and 3D variant that share the same inspector layout and behavior, differing only in the property types they animate (Vector2 vs Vector3, float vs Vector2 for rotation, etc.).

---

## Transform

Animate position, rotation, or scale of a target node with tween-based easing and configurable From/To references.

**Domain variants:** `TransformControlJuiceEffect` · `Transform2DJuiceEffect` · `Transform3DJuiceEffect`

### Transform — Overview

Transform is the workhorse effect of the Juice system. It drives a single transform channel — position, rotation, or scale — from a **From** value to a **To** value over the effect's duration, shaped by an easing curve. Multiple Transform effects can stack on the same node (e.g. one animating position, another animating scale), and their contributions are summed per-frame by the domain node.

Each endpoint (From and To) is independently configured with a **reference source**:

| Reference | Meaning |
|-----------|---------|
| **Custom** | A literal offset value you type in the inspector. Position is *relative* to the node's natural state; rotation and scale are absolute or offset depending on context. |
| **Self** | Captures the target's own transform at a chosen moment (`Trigger`, `Ready`, or `In Editor`). Useful for "return to where you started" patterns. |
| **Target Node** | Reads the transform of *another* node in the scene, live. Useful for "move to the door frame" or "match the scale of that marker." |

**When to use Transform:**
- Moving a UI panel from off-screen to its resting position (Control)
- Sliding a door open on trigger (2D/3D)
- Rotating a key 360° as a collect animation
- Scaling a button up on hover, back down on release
- Any A→B transition that should feel "designed" — with easing, duration, and precise control

**When NOT to use Transform:**
- Continuous spinning (use **Progress** — it accumulates per-frame, never "lands")
- Random jittering (use **Noise** — it's procedural, not A→B)
- Impact reactions (use **Shake** — it oscillates around the natural state)
- Organic squash on landing (use **SquashStretch** — it preserves volume)

### Transform — 2D

`Transform2DJuiceEffect` animates `Node2D.position`, `Node2D.rotation`, and `Node2D.scale` as `Vector2` / `float` types. It is the most commonly used effect for 2D games — handling everything from platform elevators to collectible bounce arcs to enemy knockback.

**Key 2D-specific behaviors:**

- **Position** values are `Vector2`. The `position_unit` selector lets you author offsets in **pixels** (default), **own size** (fraction of the node's visual bounds), or **parent size** (fraction of the parent's bounds). Own/parent size makes effects resolution-independent.
- **Rotation** is a `float` in degrees (single axis — 2D only rotates around Z). The `from_rotation_degrees` / `to_rotation_degrees` fields use `lerp_angle()` internally, so a From=350° → To=10° transition correctly takes the short 20° path, not the long 340° path.
- **Pivot** for rotation and scale uses position compensation. Node2D has no built-in `pivot_offset`, so the effect computes `fixed_pivot = base_pos + pivot.rotated(base_rot)` and adjusts position each frame to simulate rotation/scale around that pivot. The `AUTO_CENTER` mode infers the visual center from child `Sprite2D`, `CollisionShape2D`, or `Polygon2D` bounds. `CUSTOM` lets you set an explicit local-space offset.
- **Scale** values are `Vector2`. A From of `(0, 0)` → To of `(1, 1)` produces a pop-in; From `(1, 1)` → To `(0, 0)` produces a shrink-out.

**Typical 2D use cases:**

| Scenario | Config |
|----------|--------|
| Sprite hover scale-up | target=Scale, From=Self, To=Custom(1.1, 1.1), trigger=ON_HOVER_ENTER |
| Platform elevator | target=Position, From=Self(In Editor), To=Target Node(top marker), trigger=EXTERNAL (SoftTrigger) |
| Coin collect arc | target=Position, From=Self, To=Custom(0, -50px), trigger=ON_CLICK, play_mode=PLAY_IN |
| Enemy knockback | target=Position, From=Self, To=Custom(30px, 0), trigger=EXTERNAL, duration=0.15 |

### Transform — Control

`TransformControlJuiceEffect` operates identically to the 2D version but animates `Control.position`, `Control.rotation` (in degrees), and `Control.scale`. It uses the `pivot_offset` built into the `Control` node for pivot calculations and includes a Container Hold pattern to ensure UI layouts don't instantly snap back during deferred sorts.

### Transform — 3D

`Transform3DJuiceEffect` operates in 3D space, animating `Node3D.position` (`Vector3`), `Node3D.rotation` (`Vector3` via Quaternion spherical interpolation to prevent gimbal lock), and `Node3D.scale` (`Vector3`). Pivot compensation is handled via AABB visual center calculation or a custom `Vector3` offset.

---

## Progress

Continuously accumulate position, rotation, or scale at a configurable rate per second. Unlike Transform (which interpolates A→B), Progress adds a delta every frame. The effect's animation envelope (the `animate_in` / `animate_out` curves) acts as an **intensity multiplier** — smoothly fading the speed up from 0 to full rate, and back down again.

Progress is incredibly versatile. It is used for continuous spins, endless scrolling textures, or when an animation is driven by an external `0.0–1.0` value (like a SoftTrigger) acting as a direct speed throttle.

**Domain variants:** `ProgressControlJuiceEffect` · `Progress2DJuiceEffect` · `Progress3DJuiceEffect`

### Progress — Overview

The defining feature of Progress is the **Bound System**. Since it accumulates continuously, you often need to define what happens when it reaches a certain limit (`bound_enabled`):
- **BoundMode:** Compare either the overall `MAGNITUDE` or check `PER_AXIS`.
- **BoundBehaviour:** When the bound is hit, the effect can `STOP`, instantly `REVERSE` direction (ping-pong), `REVERSE_EASED` (smoothly decelerate and reverse), `WRAP` (reset to 0 and continue), `EMIT_COMPLETED` (to trigger chained effects), or even `DESTROY_PARENT`.

This makes Progress ideal for looping platforms (Wrap) or bouncing objects (Reverse Eased).

### Progress — 2D

`Progress2DJuiceEffect` accumulates `Vector2` rates for position and scale, and a `float` rate (degrees/sec) for rotation. It natively supports pixel, own-size, or parent-size units.

### Progress — Control

`ProgressControlJuiceEffect` functions identically to the 2D variant but applies offsets to the UI `Control` node, utilizing its native `pivot_offset`.

### Progress — 3D

`Progress3DJuiceEffect` accumulates `Vector3` rates for position, rotation (degrees/sec), and scale. Pivot compensation utilizes the visual AABB center.

---

## Noise

Continuous procedural noise-driven animation for position, rotation, or scale. Uses `FastNoiseLite` for configurable noise patterns with fractal and domain warp options. The progress envelope controls intensity — at progress=0 the noise is silent, at progress=1 it's full amplitude.

**Domain variants:** `NoiseControlJuiceEffect` · `Noise2DJuiceEffect` · `Noise3DJuiceEffect`

### Noise — Overview

Noise effects act as a procedural offset added to the natural state of the target node. The core math is: `amplitude × noise_sample(time) × progress`. Because the `progress` envelope multiplies the result, the noise smoothly fades in from zero at the start of the animation, reaches full amplitude during the hold phase, and fades out to zero at the end.

**Configuration:**
- **Noise Pattern:** Fully exposes Godot's `FastNoiseLite` (Simplex, Cellular, Perlin, etc.) with fractal and domain warp support.
- **Speed & Axis:** `noise_speed` controls the global time scale, while `axis_speed` allows you to make the noise sample faster on X than on Y.
- **Direction:** `noise_direction` can be `BOTH` (wobbles positively and negatively around the origin), `POSITIVE_ONLY` (only moves up/right), or `NEGATIVE_ONLY` (only moves down/left).
- **Clamping:** `clamp_min` and `clamp_max` allow you to flatten the peaks of the noise wave.

*Key mental model: "Noise adds organic randomness that never repeats and never settles."*

### Noise — 2D

`Noise2DJuiceEffect` applies procedural noise offsets to `Node2D` transforms using `Vector2` amplitude constraints.

### Noise — Control

`NoiseControlJuiceEffect` applies procedural noise offsets to `Control` node transforms.

### Noise — 3D

`Noise3DJuiceEffect` applies procedural noise offsets to `Node3D` transforms using `Vector3` amplitude constraints.

---

## Shake

Sine-wave + random oscillation for position, rotation, or scale. The progress envelope controls intensity — perfect for impacts, screen shakes, and nervous anticipation. Unlike Noise (which is smooth and organic), Shake is rhythmic and aggressive, driven by a configurable frequency (Hz).

**Domain variants:** `ShakeControlJuiceEffect` · `Shake2DJuiceEffect` · `Shake3DJuiceEffect`

### Shake — Overview

Unlike Noise (which is smooth and organic), Shake is rhythmic and aggressive. The core math uses a high-frequency sine wave: `sin(time × frequency × TAU)`. To prevent it from looking completely robotic, this sine wave is blended with a random value (`randf_range(-1, 1)`) per frame. 

**Configuration:**
- **Frequency:** `shake_frequency` (in Hz) controls the speed of the oscillation.
- **Randomness Blend:** `position_randomness` or `scale_randomness` (0.0–1.0) controls the lerp between the pure sine wave and pure white noise.
- **Rotation Chaos:** For rotation, `rotation_randomize_direction` tracks the zero-crossings of the sine wave and organically flips the rotation direction multiplier, preventing the object from just wagging like a metronome.

Like Noise, the output is multiplied by the effect's `progress` envelope, so the shake naturally ramps up and decays down.

*Key mental model: "Shake is an earthquake — strong, directional, and decaying."*

### Shake — 2D

`Shake2DJuiceEffect` applies rhythmic oscillation to `Node2D` transform channels.

### Shake — Control

`ShakeControlJuiceEffect` applies rhythmic oscillation to `Control` transform channels.

### Shake — 3D

`Shake3DJuiceEffect` applies rhythmic oscillation to `Node3D` transform channels.

---

## Squash & Stretch

Classic squash and stretch deformation with optional volume preservation. The primary axis compresses at the peak of the animation curve, while perpendicular axes expand to maintain visual volume. Ideal for landing impacts, bouncy anticipation, and breathing idle animations.

**Domain variants:** `SquashStretchControlJuiceEffect` · `SquashStretch2DJuiceEffect` · `SquashStretch3DJuiceEffect`

### Squash & Stretch — Overview

The deformation is driven by a `sin(progress × PI)` curve, which evaluates to 0.0 at the start and end of the animation, and exactly 1.0 (peak) in the middle. 

**Configuration:**
- **Primary Axis:** `squash_axis` (X or Y for 2D; X, Y, or Z for 3D) determines which axis compresses.
- **Amount:** `squash_amount` (0.0 to 0.99) dictates how much that primary axis shrinks at the peak.
- **Volume Preservation:** If `preserve_volume` is true, the perpendicular axes automatically expand as the primary axis compresses. 
  - **In 2D:** The perpendicular axis scales by `1.0 / primary_multiplier`.
  - **In 3D:** The two perpendicular axes scale by `sqrt(1.0 / primary_multiplier)`.
- **Pivot:** `pivot_offset` lets you anchor the deformation (e.g., placing the pivot at a character's feet so they squash downward into the floor, not toward their center).

*Key mental model: "Cartoon physics — something hits the ground and pancakes, then bounces back."*

### Squash & Stretch — 2D

`SquashStretch2DJuiceEffect` applies volume-preserving deformation to `Node2D` scale.

### Squash & Stretch — Control

`SquashStretchControlJuiceEffect` applies volume-preserving deformation to `Control` scale.

### Squash & Stretch — 3D

`SquashStretch3DJuiceEffect` applies volume-preserving deformation to `Node3D` scale.

---

## Appearance

Animate visual appearance properties: tint, fade (alpha), overbright (HDR bloom), and outline. Each mode uses the From/To reference system (Custom or Self, with configurable capture timing). An optional Flicker sub-system modulates the output with noise or a custom curve for flickering, strobing, or pulsing effects.

**Domain variants:** `AppearanceControlJuiceEffect` · `Appearance2DJuiceEffect` · `Appearance3DJuiceEffect`

### Appearance — Overview

Appearance effects alter the visual properties of a node without moving it. They operate by modifying the node's underlying material (or modulate) properties. Each endpoint (From and To) uses the standard `AppearanceReference` system (`CUSTOM` literal values or `SELF` snapshot).

**Effect Types:**
- **TINT:** Blends the base color toward a target color using a `tint_blend` strength. (Multiplicative blend, does not alter alpha).
- **FADE:** Animates the alpha channel (opacity) directly.
- **OVERBRIGHT:** Boosts RGB values above 1.0. Designed specifically for HDR rendering (bloom).
- **OUTLINE:** Adds a colored border around the object. (Uses `modulate` tricks in 2D/Control, and `next_pass` ShaderMaterials in 3D).

**Flicker Sub-System:**
All appearance effects can optionally have temporal flicker applied *on top* of the animation progress.
- **Modes:** `RANDOM` (driven by FastNoiseLite) or `CUSTOM` (driven by a Curve resource).
- **Behavior:** Oscillates between `flicker_min` and `flicker_max`. `hard_flicker` snaps between these values (like a broken neon sign) instead of interpolating smoothly.
- **Outline Targets:** For the Outline effect, flicker can specifically modulate the outline's `WIDTH`, `COLOR_ALPHA`, or lerp to a secondary `COLOR`.

*Key mental model: "Appearance changes how something looks without moving it."*

### Appearance — 2D

`Appearance2DJuiceEffect` operates on `CanvasItem` properties. TINT and FADE directly manipulate the `modulate` property. OUTLINE leverages the `self_modulate` trick or a simple shader depending on the implementation.

### Appearance — Control

`AppearanceControlJuiceEffect` functions identically to the 2D variant, acting on the `Control` node's `modulate` and `self_modulate` properties.

### Appearance — 3D

`Appearance3DJuiceEffect` is more complex because `Node3D` does not have a native `modulate`. It dynamically adjusts the `albedo_color` of the `MeshInstance3D`'s active `StandardMaterial3D`. For OUTLINE, the domain node (`Juice3D`) dynamically injects an `overlay_3d.gdshader` into the material's `next_pass` slot.

---

## Camera

Animate Camera2D or Camera3D properties (position, rotation, FOV/zoom) from any entity in the scene. The effect auto-discovers the active camera each tick and auto-creates a `CameraJuiceUtility` if one doesn't exist. No manual camera setup required.

**Effect classes:** `Camera2DJuiceEffect` · `Camera3DJuiceEffect`
**Utility:** `CameraJuiceUtility` (auto-bootstrapped)

### Camera — Overview

### Camera — Overview

Camera effects are meta-effects — they don't animate the target they are attached to. Instead, they dynamically discover the active camera in the viewport every frame and write offset values to a `CameraJuiceUtility` node attached to that camera. If no utility exists, the effect **auto-bootstraps** one onto the camera.

**Configuration:**
- **Channels:** `POSITION` (kick, dolly), `ROTATION` (tilt, dutch angle), or `ZOOM` (punch-in, breathe).
- **Animation Modes:** 
  - `DETERMINISTIC`: Plays a smooth curve-shaped ramp (`0 → peak → 0`).
  - `SHAKE`: A chaotic `FastNoiseLite` oscillator where the curve acts as the amplitude envelope.
- **Contribution Tracking:** The effect uses a "delta-first" pattern. It subtracts its previous contribution and adds its new one each frame, allowing multiple camera effects from different sources (e.g., three overlapping explosions) to stack perfectly without drifting the camera permanently.

*Key mental model: "Put this effect on the explosion, not on the camera — the explosion causes the shake. The effect will find the camera automatically."*

### Camera — 2D

`Camera2DJuiceEffect` targets `Camera2D`. For the POSITION channel, the `position_unit` can be set to `PIXELS` (absolute) or `PERCENT_VIEWPORT` (resolution-independent relative offsets). Zoom offsets the `zoom` scale factor.

### Camera — 3D

`Camera3DJuiceEffect` targets `Camera3D`. It offsets `position` (Vector3), `rotation` (Vector3), and `fov` (float).

---

## Screen

Animate full-screen post-processing effects via `ScreenJuiceUtility` and its shader. Supports 7 channels: Offset, Rotation, Zoom, Skew, Barrel distortion, Wave, and Chromatic aberration. Each channel can run in Deterministic (curve-shaped) or Shake (noise-driven) mode. The utility auto-bootstraps at `SceneTree.root` — no manual CanvasLayer setup required.

**Effect class:** `ScreenJuiceEffect` (domain-agnostic — works from any recipe)
**Utility:** `ScreenJuiceUtility` (auto-bootstrapped)

### Screen — Overview

Similar to the Camera effect, Screen effects are meta-effects that auto-bootstrap at runtime. When triggered, the effect generates a `ScreenJuiceUtility` full-screen CanvasLayer at `SceneTree.root` (if one doesn't exist) and drives its shader uniforms.

**Configuration:**
- **Channels:** `OFFSET` (screen kick), `ROTATION` (spin), `ZOOM` (punch-in), `SKEW` (lean/warp), `BARREL` (lens distortion), `WAVE` (scanline/underwater), `CHROMATIC` (RGB split).
- **Animation Modes:** Like Camera, supports `DETERMINISTIC` (curve) or `SHAKE` (noise envelope).
- **Wave Options:** `wave_direction` supports `HORIZONTAL` (rows shift), `VERTICAL` (columns shift), or `CONCENTRIC` (radial ripples).
- **Chromatic Mode:** Supports `UNIFORM_SHIFT`, `VIGNETTE_FALLOFF` (stronger at edges, realistic), or `NOISE_PER_CHANNEL` ("drunken" warp).
- **Vignette & Pivot:** A radial vignette mask can fade effects toward the center. `pivot_offset` lets you move the origin point for rotation, zoom, skew, and barrel distortion.

*Key mental model: "The whole screen warps — for impacts, power-ups, damage, or atmosphere."*

### Screen — Overlay

`ScreenOverlayJuiceEffect` — Animates a colored overlay covering the entire screen (flash white on hit, fade to black for transitions, red vignette for damage).

**Domain variants:** `ScreenOverlayControlJuiceEffect` · `ScreenOverlay2DJuiceEffect` · `ScreenOverlay3DJuiceEffect`

This effect flashes a colored rectangle over the entire screen, interpolating the alpha channel. It's an easy way to create damage flashes (red vignette overlay), transition fades (fade to black), or flashbangs (pure white). Supports a vignette mask to keep the center of the screen clear.

---

## Property  *(domain-agnostic family)*

Animate *any* node property by path — not just transform channels. The Property family provides the same animation behaviors as the domain-bound families (interpolate, noise, shake, progress) but targets arbitrary `Variant` properties via an inspector-configured path (e.g. `modulate:a`, `custom_minimum_size:x`, `material:shader_parameter/dissolve`).

Because `lerp()` in GDScript 4 is polymorphic, these effects natively support `float`, `Vector2`, `Vector3`, and `Color`. (Integers are lerped as floats and cast back). Unlike visual effects that sum their deltas, Property effects **persist** their writes. The last written value at the end of the animation remains.

**Sub-families:**

### Interpolate Property
`InterpolatePropertyJuiceEffectBase` → `InterpolatePropertyControlJuiceEffect` · `InterpolateProperty2DJuiceEffect` · `InterpolateProperty3DJuiceEffect`

Tween-based A→B interpolation of any property. Analogous to Transform, but for arbitrary properties. 

### Noise Property
`NoisePropertyJuiceEffectBase` → `NoisePropertyControlJuiceEffect` · `NoiseProperty2DJuiceEffect` · `NoiseProperty3DJuiceEffect`

Procedural `FastNoiseLite` oscillation on any property. Analogous to Noise, but for arbitrary properties.

### Shake Property
`ShakePropertyJuiceEffectBase` → `ShakePropertyControlJuiceEffect` · `ShakeProperty2DJuiceEffect` · `ShakeProperty3DJuiceEffect`

Sine+random oscillation on any property. Analogous to Shake, but for arbitrary properties.

### Progress Property
`ProgressPropertyJuiceEffectBase` → `ProgressPropertyControlJuiceEffect` · `ProgressProperty2DJuiceEffect` · `ProgressProperty3DJuiceEffect`

A continuous accumulator (like a motor) that adds to a property every frame, bound by the standard Wrap/Reverse/Stop bound system. Analogous to Progress, but for arbitrary properties.

---

## Time  *(domain-agnostic meta effect)*

Time effects manipulate `Engine.time_scale` globally to create hitstops, dramatic slowdowns, or Matrix-style bullet time. They are domain-agnostic meta-effects — they don't animate the target node itself.

**Domain variants:** `TimeControlJuiceEffect` · `Time2DJuiceEffect` · `Time3DJuiceEffect`

### Time — Overview

**Modes:**
- **FREEZE:** Instantly sets `time_scale` to 0.0 for a precise number of frames (hitstop). This uses a real-time `SceneTreeTimer` because the standard `_process` loop is paused.
- **SLOW_MO:** Smoothly interpolates down to a `target_scale` (e.g., 0.3 for 30% speed) and back up.
- **BULLET_TIME:** Same as SLOW_MO, but you can define an array of `exempt_nodes` that will continue to run at normal speed (`PROCESS_MODE_ALWAYS`).

**Time Management Hierarchy:**
Because multiple effects might try to change time simultaneously, the system uses a 3-layer architecture:
1. **Layer 1 (Built-in static fallback):** Multiple `TimeJuiceEffect` instances coordinate via a static dictionary. The slowest slow-mo request always wins.
2. **Layer 2 (Signal Escape Hatch):** Set `use_external_coordinator = true`. The effect emits `time_scale_requested(scale)` instead of touching the engine directly, letting your custom game logic handle it.
3. **Layer 3 (TimeCoordinatorJuiceUtility):** An auto-discovered singleton that handles time scale resolution and can also coordinate audio pitch shifts (so sound slows down with the action).

*Key mental model: "Time manipulation is just another effect in the recipe stack. It chains and sequences naturally."*

---

## Utilities (Meta & External Drivers)

Utility nodes are non-visual components that manage control flow, scene state, hardware interaction, or signal routing. They can be broken down into Meta Effects (triggered inside recipes) and External Drivers (stand-alone nodes that trigger recipes).

### Meta Utilities (Triggered inside Recipes)

**CallMethod**
Executes arbitrary functions when a Juice effect starts or finishes (`ON_START`, `ON_COMPLETE`, or `ON_BOTH`). Holds an array of `CallMethodEntry` sub-resources, letting a single utility call multiple methods on different target nodes (with arguments) dynamically.

**SignalEmit**
Emits Godot signals via `juice_signal(payload)` when triggered. Holds an array of `SignalEmitEntry` sub-resources. Ideal for wiring up custom game logic (e.g., "when this animation peaks, notify the UI to update the score").

**SceneAction**
An ephemeral orchestrator that handles scene transitions entirely from the inspector. When triggered, it spawns an independent node on `SceneTree.root` that manages `SWITCH_SCENE`, `OVERLAY_SCENE`, `RELOAD_SCENE`, or `QUIT_GAME`. It supports visual transitions (SOLID_COLOR, IMAGE, SCENE) that mask the load.

### External Drivers & Sensors (Trigger Recipes)

**SoftTrigger (2D / 3D / Control)**
A proximity-driven continuous progress driver. Instead of binary enter/exit, it tracks how deep inside the collision shape a tracked entity (mouse, body, area) is, calculating a `0.0 – 1.0` value. It drives sibling `JuiceBase` nodes directly each frame, completely bypassing the internal timing system. Enables smooth, Balatro-style hover effects or spatial magnetic zones.

**Interaction (2D / 3D)**
A convenience wrapper for `Area2D` / `Area3D`. Handles collision shape auto-creation, zone gating, and relays standard input events (like clicks) into dynamic Godot signals (e.g., `left_click` or custom action map strings). Child `JuiceBase` nodes automatically connect to its native signals.

**SignalRelay**
A lightweight signal router. Listens to a local signal (e.g., a button's `pressed`) and re-emits a named signal onto a global autoload SignalBus. Crucial for architectures where the Juice components live in a completely different scene than the UI element that triggers them.

**TimeCoordinator**
An autoload singleton that mediates requests between multiple `TimeJuiceEffect` instances (resolving conflicts so the slowest request wins) and can optionally sync the global audio pitch (`AudioServer`) to match the visual time dilation.

---

# Debug Logging

Juice V1 includes a structured debug logging system that makes animation bugs diagnosable from a log file alone, without running the editor interactively.

## How It Works

All log output flows through `JuiceLogger` — a static utility with **three-tier gating**:

1. **Build type** — logs are stripped entirely in export builds (`OS.is_debug_build()`). Zero cost at runtime.
2. **Master switch** — `Project Settings → juice/debug/enabled` turns on all logging at once. Use when you want to capture everything.
3. **Per-node flag** — `debug_enabled` on any `JuiceBase` node isolates logging to that node only, without touching the global switch.

Logic: a log call proceeds if `debug_build AND (master_switch OR node_flag)`.

## Log Categories

Each call site uses the appropriate category method on `JuiceLogger`:

| Category | Method | What It Records |
|----------|--------|-----------------|
| 1 | `log_info` | Lifecycle events — trigger, start, stop, complete, timing state transitions |
| 2 | `log_capture` | Base value and From/To snapshot captures |
| 3 | `log_delta` | Per-frame delta computed by `_apply_effect()` |
| 4 | `log_shader` | Shader uniform writes from Appearance effects |
| 5 | `log_aggregation` | Final value written to the target node each frame |
| 6 | `warn_domain_mismatch` | Configuration error: wrong effect type for this domain |

Categories 3 and 5 (per-frame) are **file-only by default**. Enable `juice/debug/verbose` to also print them to the console — expect high volume.

## Log Format

Every line follows a consistent, machine-parseable format:

```
[Juice][Domain][EffectType] SourceName: message
```

Example:
```
[Juice][Control][Transform] @Button@42: animate_in complete (progress=1.000, target=@Button@42)
[Juice][Control] @Node@43: Started 2 root effects (play_in=true): [TransformControlJuiceEffect, NoiseControlJuiceEffect]
```

The domain tag (`Control`, `2D`, `3D`, `Screen`, etc.) and effect type are always present, so filtering by domain or effect family in a text editor is straightforward.

## File Logging

Enable `juice/debug/log_to_file` to write all output to `user://juice_debug.log`. The file persists after the scene stops, which is required for bug reports (the in-memory ring buffer resets on stop).

## Bug Reports

**Tools → Export Juice Bug Report** generates a self-contained `juice_debug_report.json` and opens it immediately. The report contains:

- Godot version, OS, project name
- Current Juice debug settings (so you can confirm logging was actually enabled)
- An inventory of every `JuiceBase` node in the current scene with its configuration
- The full contents of `juice_debug.log`

To file a complete bug report:
1. Enable `juice/debug/log_to_file = true` in Project Settings
2. Enable `debug_enabled` on the relevant `JuiceBase` node (or turn on the master switch)
3. Run the scene and reproduce the bug
4. Stop the scene
5. **Tools → Export Juice Bug Report**
6. Attach `juice_debug_report.json`

---

# Not Yet Ported

The following V0 components have not yet been ported to V1:

| V0 Component | Target V1 | Notes |
|-------------|-----------|-------|
| `VFXJuiceComp` | `VFXJuiceEffect` | Particle effect spawning |
| `TrailJuiceComp` | `TrailJuiceEffect` | Trail/ribbon rendering |
| `PauseJuiceComp` | `PauseJuiceEffect` | Sequencer pause step |
| `ScreenMotionJuiceComp` | `ScreenMotionJuiceEffect` | 🔧 In progress |
| `JuicePreviewDirector` | TBD | Editor transport preview |
