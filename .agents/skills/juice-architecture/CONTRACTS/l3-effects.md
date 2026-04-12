# L3 Effects Contracts

## Pure Delta Calculators
- Calculate deltas only, never write
- Store in inherited delta properties
- Target passed as parameter, never discovered

## Effect Types
- Transform: Position/rotation/scale deltas
- Appearance: Visual effects (outline, tint, etc.)
- Procedural: Generated animations
- Meta: Effect controllers and utilities

## Resource Pattern
- Extend JuiceEffectBase (Resource)
- No _ready(), _process(), lifecycle methods
- Conditional exports via _get_property_list()

## Approved Direct-Write Exceptions
Some effects operate outside the delta aggregation pipeline by design:
- **TimeJuiceEffectBase** — writes `Engine.time_scale` (global, not per-target)
- **ProgressPropertyJuiceEffectBase** — writes arbitrary node properties via `set_indexed()`

These are deliberate exceptions. All other effects MUST use the delta system.

## RESTART_REVERSED TickResult Contract

`JuiceEffectBase.TickResult` has three values: `PLAYING`, `COMPLETED`, `RESTART_REVERSED`.

`RESTART_REVERSED` is used **exclusively** by accumulation effects (Progress family) to implement
the REVERSE_EASED bound behaviour smoothly without violating the host-owns-lifecycle rule.

### Effect responsibilities (before returning RESTART_REVERSED):
1. Absorb accumulated state into base values (`_absorb_accumulated_into_base()`)
2. Flip internal direction (`_current_direction *= -1.0`)
3. Return `TickResult.RESTART_REVERSED` from `tick()`

### Host responsibilities (on receiving RESTART_REVERSED):
- Call `effect.start(target, true, false, self)` — animate-in, no start_delay

### Rules:
- NEVER return `RESTART_REVERSED` from `_apply_effect()` — only from `tick()`
- NEVER use `RESTART_REVERSED` for effects that don't accumulate state

## Delta in Accumulation Effects

`_apply_effect(progress, target)` does NOT receive a `delta` parameter.
If your effect needs per-frame time (e.g. continuous accumulation):
1. Override `tick(delta, target)` in the effect
2. Store `_last_delta: float = 0.0` in internal state
3. Set `_last_delta = delta` before calling `super.tick(delta, target)`
4. Read `_last_delta` inside `_apply_effect()`

**Why:** Effects are Resources, not Nodes — they have no `_process()` and
`get_process_delta_time()` does not exist on them.

## Effects Cannot Emit Node Signals

Do NOT call `completed.emit()` inside an effect. `completed` is a signal on
`JuiceBase` (the Node), not on `JuiceEffectBase` (the Resource).

To signal that an effect is done:
- Set `_is_playing = false` -- the host tick loop detects this and returns `TickResult.COMPLETED`
- The host node emits its own `completed` signal automatically

Replace `completed.emit()` with `_is_playing = false` in all bound handlers.

## Shared Base Pattern Does Not Apply to Transform Effects

A shared meta base (e.g. `ProgressJuiceEffectBase extends JuiceEffectBase`) cannot
also provide delta storage (`_pos_delta`, `_rot_delta`, `_scale_delta`).
Those are defined on domain-specific transform bases (`Juice2DTransformEffect`,
`JuiceControlTransformEffect`, `Juice3DTransformEffect`) and GDScript is single-inheritance.

**Rule:** If an effect produces transform deltas, each domain effect must extend
its own domain transform base directly. Shared logic lives in a static helper or
is duplicated across domain files. Do not create a shared base for transform effects.

## Transform Magnitude Standardization

When an effect calculates transform-related magnitudes that depend on footprint context (such as position amplitudes, shake strengths, or drift rates), it SHOULD expose a unit selection property utilizing the unit enums (`PositionIn` / `PositionIn3D`) inherited from its intermediate transform base class. The raw inspector values MUST then be routed through the base class's footprint inference helper (`_convert_to_pixels()`, `_convert_to_world_units()`, etc.) before calculating final deltas.

The default unit selection should be chosen sensibly per-effect based on design intent. Existing properties being ported should preserve behavior to maintain backward compatibility.
