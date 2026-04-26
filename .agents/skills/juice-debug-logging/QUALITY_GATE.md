# Logging Quality Gate

## Context

This is a 60fps game engine plugin. Effects tick every frame, helpers are called from hot paths,
and the editor inspector fires property methods constantly. Logging must be useful without being noisy.

`debug_enabled` is a manual toggle — the user turns it on, reproduces the bug, turns it off.
Log volume during that window is acceptable, but every line must carry a value that advances
understanding of what the effect actually did.

---

## MANDATORY: Pre-Implementation Design

**Before writing or modifying any log call**, produce these two artifacts in writing.

They cannot be faked without reading the actual code. They become the spec your
implementation is verified against. An implementation that doesn't match its own
artifacts has a defect — either in the artifacts or in the code.

---

### Artifact 1 — Config Variable Map

Open the file. List **every** `@export var` and every config variable by its exact GDScript
name. For each one, assign it to a chain stage, or mark it with one of the reserved tags.

**Format:**
```
CONFIG MAP: [ClassName]
  [var_name]        → [stage_name]    # role in computation
  [var_name]        → ROUTING         # determines which branch runs
  [var_name]        → SIDE_EFFECT     # causes a write, not part of output delta
  [var_name]        → UNUSED          # not used in computation (justify this)
```

**Example — ShakeControlJuiceEffect:**
```
CONFIG MAP: ShakeControlJuiceEffect
  transform_target          → ROUTING         # selects position/rotation/scale branch
  shake_frequency           → oscillation     # freq × time × TAU drives sin()
  position_strength         → raw_offset      # per-axis scalar on blended oscillation
  position_unit             → raw_offset      # unit conversion factor for position
  position_randomness       → oscillation     # lerp blend weight sine↔rand
  rotation_amplitude        → oscillation     # degrees multiplied into sine output
  rotation_randomize_direction → oscillation  # flips _direction_multiplier at zero-cross
  scale_amplitude           → oscillation     # per-axis scalar for scale branch
  scale_randomness          → oscillation     # lerp blend weight for scale branch
  scale_uniform             → oscillation     # branches uniform vs anisotropic output
  pivot_mode                → SIDE_EFFECT     # sets pivot_offset once, not part of delta
  custom_pivot              → SIDE_EFFECT     # used only when pivot_mode = CUSTOM
```

**Rule: every variable mapped to a computation stage MUST appear in `log_capture` at
lifecycle start. No curated subsets. If it feeds the chain, it is logged.**

`ROUTING` variables: include as a string key in `log_capture` (they determine which
branch ran — critical for reading any other log line).

`SIDE_EFFECT` and `UNUSED` variables: do not need logging unless they produce a
visible discrepancy (e.g., wrong pivot set — log it in the method that sets it).

---

### Artifact 2 — Expected Log Template

Before writing any `log_capture` or `log_delta`, write what the actual log payload
should contain. Use real GDScript key names and realistic representative values.

**Format:**
```
EXPECTED log_capture at [method]:
  { "key": value, "key": value, ... }

EXPECTED log_delta at [method] (typical mid-animation frame):
  progress: 0.45, delta: { "key": value, "key": value }
```

**Example — ShakeControlJuiceEffect:**
```
EXPECTED log_capture at _on_animate_start:
  {
    "target": "POSITION",
    "freq": 20.0,
    "strength": "(5.00, 5.00)",
    "unit": "PIXELS",
    "randomness": 0.500,
    "seed": 847.32
  }
  # Note: pivot_mode logged separately in _apply_pivot_mode as SIDE_EFFECT

EXPECTED log_delta at _apply_effect (POSITION branch, mid-animation):
  progress: 0.45, delta: {
    "oscillation": 0.612,      # sine_val blended with rand — the intermediate
    "raw_offset": "(3.06, 2.14)",  # before unit conversion
    "pos_delta": "(3.06, 2.14)"    # final value registered with ledger
  }
```

**Rule: the implementation must match this template. If a key is impossible to log
because an intermediate is computed inline and discarded, the fix is to assign it
to a named variable — not to drop the key from the spec.**

This template also defines what a reviewer checks. If the implemented `log_capture`
is missing `seed` and `randomness`, the gap is visible without running the game.

---

## The Four Logging Boundaries

These are the structural positions that the chain stages above map to.
Use as a cross-check that no class of log is missing.

### 1. Lifecycle (runs once per animation)

**Where:** `_on_animate_start()`, `stop()`, `_restore_to_natural()`

**What:** Full state snapshot — every field from Artifact 1 that feeds the chain,
plus captured runtime values (base position, resolved From/To, material RID, etc.).

```gdscript
# GOOD — config fields + captured runtime state
JuiceLogger.log_capture(self, _get_domain_tag(), "start",
    {"target": TransformTarget.keys()[transform_target],
     "freq": shake_frequency, "strength": position_strength,
     "randomness": position_randomness, "seed": _shake_seed},
    debug_enabled)

# BAD — config subset, runtime state absent
JuiceLogger.log_capture(self, _get_domain_tag(), "start",
    {"freq": shake_frequency},
    debug_enabled)
```

Restore must log what value was written back. If a user says "the property didn't reset,"
you need to see whether `_restore_to_natural` ran and what it wrote:

```gdscript
JuiceLogger.log_info(self, _get_domain_tag(),
    "restore: wrote %s = %s" % [property_path, written_value],
    debug_enabled)
```

### 2. Per-Frame (runs at 60fps)

**Where:** `_apply_effect()`

**What:** The computed output at this frame — intermediate values that change frame-to-frame,
plus the final delta. One compact line. **Never repeat static config here** — it was already
logged at lifecycle start.

```gdscript
# GOOD — intermediate oscillation + final delta, both change each frame
JuiceLogger.log_delta(self, _get_domain_tag(), progress,
    {"oscillation": blended, "raw_offset": raw_offset, "pos_delta": _pos_delta},
    target.name, debug_enabled)

# BAD — static config logged per-frame (same value 3600 times)
JuiceLogger.log_delta(self, _get_domain_tag(), progress,
    {"freq": shake_frequency, "strength": position_strength},
    target.name, debug_enabled)
```

### 3. State Transitions (runs rarely)

**Where:** Direction reversals, bound breaches, phase changes, crossfade starts.

**What:** Old value → new value + what triggered it.

```gdscript
# GOOD
JuiceLogger.log_info(self, _get_domain_tag(),
    "bound hit: accumulated=%.3f limit=%.3f → %s (dir: %.0f → %.0f)" % [
    accumulated_magnitude, bound_value,
    BoundBehaviour.keys()[bound_behaviour],
    old_direction, _current_direction],
    debug_enabled)

# BAD — event name only, nothing to reason about
JuiceLogger.log_info(self, _get_domain_tag(), "bound reached: REVERSE", debug_enabled)
```

### 4. Error Exits (runs rarely)

**Where:** Every early `return` that skips effect work.

**What:** Why it bailed. This diagnoses "nothing happened" reports — the most common
class of marketplace bug.

```gdscript
# GOOD
if property_path.is_empty():
    JuiceLogger.warn(self, _get_domain_tag(),
        "Skipped _apply_effect: property_path is empty", debug_enabled)
    return

# BAD — silent, effect does nothing, log shows nothing
if property_path.is_empty():
    return
```

---

## What NOT To Log

| Method Type | Example | Why Not |
|---|---|---|
| **Editor inspector** | `_get_property_list()`, `_set()`, `_get()` | Fires on every inspector click, not gameplay |
| **Pure helpers called from logged methods** | `_clamp_to_bound()`, `_wrap_accumulated()` | Caller already logs the decision; double-logging is noise |
| **Pure boolean getters** | `_is_bound_exceeded()` | Result visible from the state transition log |
| **Constructors / `_init()`** | Resource initialization | No runtime state exists yet |
| **Static config per-frame** | `property_path` in `_apply_effect()` | Belongs at lifecycle start; 3600 identical lines add nothing |

---

## The Completeness Test (Post-Implementation Gate)

> [!CAUTION]
> **This test requires REAL log output from the test suite. Code reasoning is not permitted.**
> Before answering, you MUST:
> 1. Clear the log: `Remove-Item "C:\Users\nikol\AppData\Roaming\Godot\app_userdata\Juice Demo\juice_debug.log" -ErrorAction SilentlyContinue`
> 2. Run ONLY the batch suites: `cmd /c "D:\Godot_projekti\juice-demo\tests\run_tests.bat" -- --suite=<family>`
> 3. Read and filter the log: `Get-Content "...\juice_debug.log" | Select-String "\[FamilyTag\]"`
> 4. Paste the relevant lines as quoted evidence — must include all 3 domains (Control, 2D, 3D)
>
> Custom verify scenes are not permitted — the test suite exercises all domains already.
> Answering "YES" by reasoning about what the code *would* produce is self-certification
> and invalidates the entire test. If you cannot quote a log line showing a stage,
> that stage is not logged — regardless of what the source code says.

After obtaining real log output, answer these three questions by **quoting specific
lines from that output**. Each YES answer must cite the line it is based on.

> **1. Wrong output:** If the effect produced an unexpected value, can you identify the
>    exact chain stage where actual output first diverged from expected?
>    → Quote the log_delta line(s) that would expose the divergence.
>
> **2. No output:** If the effect produced nothing (zero delta, no change), can you
>    determine which early return or zero-condition fired?
>    → Quote the warn() line or the absence of log_delta lines as evidence.
>
> **3. Reconstruction:** Can you reconstruct the full computation — all inputs, all
>    intermediate values, the final result — from the lifecycle log + 10 consecutive
>    per-frame lines?
>    → Quote the log_capture line and at least 3 consecutive log_delta lines.

If any answer requires reasoning rather than quoting → a stage is missing. Return to Artifact 1.

If all three cite real log lines → the file is done.

---

## Per-File Completeness Checklist

Quick structural check after the Completeness Test passes:

- [ ] Every variable in Artifact 1 mapped to a stage appears in `log_capture` at lifecycle start
- [ ] Artifact 2 template matches the implemented log calls (keys, values, method)
- [ ] Per-frame log contains computed output values, not static config
- [ ] Every state transition logs old→new with trigger context
- [ ] Every silent `return` has a `warn()` before it
- [ ] No helper method duplicates logging already present in its caller
- [ ] No editor method (`_get_property_list`, `_set`, `_get`) has any logging
- [ ] **Every log that follows a state-clearing call (`_clear_deltas`, `cleanup_source`, `queue_free`, etc.) is MOVED to before that call** — logging after a clear always produces trivially correct output and is useless for diagnosis
