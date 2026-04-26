---
name: juice-logging-upgrade
description: Upgrade existing Juice V1 debug logging to full chain coverage. Enforces the pre-implementation design protocol from QUALITY_GATE.md. Auto-invoke for /upgrade-logging workflow.
---

# Juice Logging Upgrade

This skill upgrades *existing* logging points from mechanical to faithful.
For adding logging to a **new script**, use `@juice-debug-logging` instead.

---

## The Problem This Fixes

Mechanical instrumentation adds one `log_capture` at start and one `log_delta` in
`_apply_effect()`. These are syntactically compliant but semantically thin:

- Config payloads are curated subsets — missing fields that feed the computation
- Intermediate chain stages are invisible — the log shows input and output, not the transform
- Silent early returns have no warning — "nothing happened" reports have no evidence

**The result:** `_pos_delta = (0, 0)` every frame. Was it `progress = 0.0`? Was it
`position_strength = (0, 0)`? Did `_convert_to_pixels` return zero? The log cannot say.

**The fix:** Log the chain faithfully. A bug becomes visible as the stage where actual
output first diverges from expected. No guessing required.

---

## The Pre-Implementation Protocol (Single Source of Truth)

The design protocol — Artifact 1 (Config Variable Map) and Artifact 2 (Expected Log
Template) — lives in:

```
@juice-debug-logging QUALITY_GATE.md § MANDATORY: Pre-Implementation Design
```

**Read it before touching any log call.** Do not reconstruct the protocol from memory.

For upgrade work specifically, Artifact 1 serves a second purpose: compare it against
the existing `log_capture` call. Every variable mapped to a computation stage that is
absent from the current `log_capture` is a gap that must be fixed.

---

## Per-Family Chain Reference

These chain maps are starting points for Artifact 1. You must verify them against
the actual code — the chain map is wrong if it doesn't match the implementation.

### Transform Effects
```
from_reference + to_reference
  → resolve_from() + resolve_to()     [SELF snapshot, TARGET_NODE, or CUSTOM]
  → lerp(progress)                    → desired_absolute
  → subtract(_base_value)             → _pos_delta / _rot_delta / _scale_delta
```
Critical: log `desired_absolute` AND `delta`. If desired is correct but delta is wrong,
the bug is in base-value capture, not interpolation.

### Shake Effects
```
config(freq, amplitude, randomness, seed) + progress(intensity_envelope)
  → shake_time (accumulated _current_delta)
  → oscillation (sine_val, rand_component, lerp-blended)
  → raw_offset (pre-unit-conversion strength application)
  → _convert_to_pixels                → _pos_delta
```
Critical: log the oscillation intermediate. `_pos_delta = (0,0)` with `oscillation = 0.0`
points to frequency/seed/time. With `oscillation ≠ 0.0` it points to unit conversion or strength.

### Noise Effects
```
config(freq, amplitude, octaves, lacunarity, gain, seed)
  → noise_sample (FastNoiseLite.get_noise_*())
  → amplitude_scale (progress × amplitude)
  → _pos_delta / _rot_delta / _scale_delta
```

### Appearance Effects
```
from_color + to_color + progress
  → lerp_color                        → interpolated_result
  → [branch: MODULATE] write target.modulate
  → [branch: OUTLINE]  set_shader_parameter(uniform, value)
  → [branch: CUSTOM]   set_shader_parameter(custom_uniform, value)
```
Critical: log which branch ran (ROUTING), what was written, and the material RID.
Shader bugs require `log_shader` on every `set_shader_parameter` call.

### Progress / SquashStretch Effects
```
from_value + to_value + progress
  → lerp(progress)                    → desired_absolute
  → subtract(_base_value)             → delta
```
Same as Transform, simpler chain. Log `desired_absolute` AND `delta`.

### Property Meta Effects
```
property_path + from_value + to_value + progress
  → resolve_property_on_target()      → confirmed type + current_value
  → lerp/noise/shake(progress)        → resolved_value
  → target.set(property_path, resolved_value)
```
Critical: log `property_path`, `resolved_value`, and the confirmed type.
Type mismatches are the most common silent failure.

### Domain Nodes (JuiceControl / Juice2D / Juice3D)
```
_capture_base_values:
  target.position / rotation / scale → _base_position / _base_rotation / _base_scale

_pre_tick (only on external-move detection):
  old_base → new_base                [log only when drift detected]

_post_tick_write:
  _base + total_delta                → target.position / rotation / scale   [per channel]
```

---

## Coverage Audit Table

After producing Artifact 1 and comparing it against existing log calls, fill this in:

| Variable / Stage | In Artifact 1? | In Current Log? | Action |
|------------------|----------------|-----------------|--------|
| `[var_name]` | stage name | YES / PARTIAL / NO | add / expand / remove |

Every row where "In Current Log?" ≠ "YES (full)" is a fix to make.

---

## The Completeness Test

After upgrading, apply the post-implementation gate from:
```
@juice-debug-logging QUALITY_GATE.md § The Completeness Test
```

All three questions must answer YES before the batch is done.
