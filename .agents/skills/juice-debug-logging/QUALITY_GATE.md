# Logging Quality Gate

## Context

This is a 60fps game engine plugin. Effects tick every frame, helpers are called from hot paths, and the editor inspector fires property methods constantly. Logging must be **useful without being noisy**.

`debug_enabled` is a manual toggle — the user turns it on, reproduces the bug, turns it off. Log volume during that window is acceptable, but signal-to-noise matters: every line must carry a value you'd actually read.

---

## The Four Logging Boundaries

Not every method needs logging. Log at these four boundaries:

### 1. Lifecycle (runs once per animation)

**Where:** `_on_animate_start()`, `stop()`, `_restore_to_natural()`

**What to log:** Full state snapshot — all config values AND captured runtime values.

This is your baseline. When a user sends a log, you read this first to understand what was configured and what state the engine was in when the animation started.

```gdscript
# GOOD — config + captured engine state
JuiceLogger.log_capture(self, _get_domain_tag(), "start",
    {"property": property_path, "type": PropertyType.keys()[property_type],
     "base_value": _base_float, "rate": float_rate, "dir": _current_direction},
    debug_enabled)

# BAD — config only, no engine state
JuiceLogger.log_capture(self, _get_domain_tag(), "start",
    {"property": property_path, "type": PropertyType.keys()[property_type]},
    debug_enabled)
```

**Restore must also log.** If a user says "the property didn't reset," you need to see whether `_restore_to_natural` ran and what value it wrote back:

```gdscript
JuiceLogger.log_info(self, _get_domain_tag(),
    "restore: wrote %s = %s" % [property_path, written_value],
    debug_enabled)
```

### 2. Per-Frame (runs at 60fps)

**Where:** `_apply_effect()`

**What to log:** The **computed output** — the value that was produced this frame. Minimal payload, one line per frame.

Do NOT log inputs that were already logged at lifecycle start (config, property path, type). Do NOT log both inputs and outputs — that doubles log volume for no gain since inputs are derivable from the lifecycle log.

```gdscript
# GOOD — the actual computed value that matters
JuiceLogger.log_delta(self, _get_domain_tag(), progress,
    {"accumulated": _accumulated_float, "written": _base_float + _accumulated_float},
    target.name, debug_enabled)

# BAD — static config repeated every frame
JuiceLogger.log_delta(self, _get_domain_tag(), progress,
    {"path": property_path, "type": PropertyType.keys()[property_type]},
    target.name, debug_enabled)
```

**The test:** If you stare at 10 consecutive `log_delta` lines, can you see the value changing (or not changing, which IS the bug)? If yes, the payload is correct.

### 3. State Transitions (runs rarely)

**Where:** Direction reversals, bound breaches, phase changes, crossfade starts.

**What to log:** The old value, the new value, and enough context to understand why the transition happened.

```gdscript
# GOOD — before/after with context
JuiceLogger.log_info(self, _get_domain_tag(),
    "bound hit: accumulated=%.3f limit=%.3f → %s (dir: %.0f → %.0f)" % [
    accumulated_magnitude, bound_value,
    BoundBehaviour.keys()[bound_behaviour],
    old_direction, _current_direction],
    debug_enabled)

# BAD — event name only
JuiceLogger.log_info(self, _get_domain_tag(),
    "bound reached: REVERSE", debug_enabled)
```

### 4. Error Exits (runs rarely)

**Where:** Every early `return` that causes a method to skip its work.

**What to log:** Why it bailed. This diagnoses "nothing happened" bugs — the most common marketplace report.

```gdscript
# GOOD — explains the skip
if property_path.is_empty():
    JuiceLogger.warn(self, _get_domain_tag(),
        "Skipped _apply_effect: property_path is empty", debug_enabled)
    return

# BAD — silent, user sees nothing, effect does nothing, no one knows why
if property_path.is_empty():
    return
```

---

## What NOT To Log

| Method Type | Example | Why Not |
|---|---|---|
| **Editor inspector** | `_get_property_list()`, `_set()`, `_get()` | Fires during inspector clicks, not gameplay |
| **Pure helpers called from logged methods** | `_clamp_to_bound()`, `_wrap_accumulated()` | Parent method already logs the decision; logging both creates redundant nested output |
| **Pure getters returning bool** | `_is_bound_exceeded()` | Caller knows the result; the state transition log covers it |
| **Constructors / `_init()`** | Resource initialization | No runtime state exists yet |

---

## Per-File Completeness Check

After instrumenting a file, verify:

- [ ] **Lifecycle start** logs config AND captured engine values (not config alone)
- [ ] **Lifecycle stop/restore** logs what value was written back
- [ ] **Per-frame** logs the computed output value (not static config)
- [ ] **Every state transition** logs old→new with trigger context
- [ ] **Every silent `return` guard** has a warn explaining why it bailed
- [ ] **No helper method** duplicates logging from its caller
- [ ] **No editor method** has logging

---

## The 10-Line Test

After instrumenting a file, mentally simulate a bug ("value stuck at 0.7") and ask:

> If I read the lifecycle log + 10 consecutive per-frame lines, can I see:
> 1. What config was active?
> 2. What base value was captured from the engine?
> 3. What value is being computed each frame — and is it changing or stuck?
> 4. If it stopped, why?

If any of those four questions has no answer in the log, a log is missing or its payload is wrong.
