# Logging Quality Gate

## The Rule

Every method that transforms data should log its **inputs and outputs**.

If the output is wrong, the inputs tell you why. This is systematic, not creative.

---

## How To Apply (Per File)

1. Open the file
2. Read **every method** — not just the ones that already have `JuiceLogger` calls
3. For each method, ask: "Does this method take input, do work, and produce output?"
4. If yes: log the inputs at entry, log the outputs after computation
5. If a `JuiceLogger` call already exists: does it log the actual runtime values (inputs/outputs), or just static config? Fix if static.
6. Move to next method, then next file

This process naturally:
- **Fixes bad payloads** — because you verify each existing log captures real I/O
- **Adds missing logs** — because you examine ALL methods, not just ones with existing calls
- **Requires zero guesswork** — no imagining failure modes, just reading what goes in and what comes out

---

## Payload Rules

### Runtime values, not static config

| ❌ Static config (useless) | ✅ Runtime I/O (useful) |
|---|---|
| `{"path": property_path, "type": "FLOAT"}` | `{"in_progress": progress, "in_delta": delta, "out_accumulated": _accumulated_float}` |
| `{"target": "POSITION"}` | `{"in_progress": progress, "out_pos_delta": _pos_delta}` |

### Silent returns need logging

If a method exits early without doing work, log why:

```gdscript
if property_path.is_empty():
    JuiceLogger.warn(self, _get_domain_tag(),
        "Skipped: property_path is empty", debug_enabled)
    return
```

### State transitions log before and after

```gdscript
# Direction reversal:
var old_dir := _current_direction
_current_direction *= -1.0
JuiceLogger.log_info(self, _get_domain_tag(),
    "direction: %.0f → %.0f at accumulated=%.3f" % [old_dir, _current_direction, accumulated],
    debug_enabled)
```

---

## Completeness Check (Per File)

After instrumenting a file, verify:

- [ ] Every method that computes or transforms data has I/O logging
- [ ] Every early-return guard has a warn log explaining why it bailed
- [ ] Every state transition logs the old→new values
- [ ] No `log_delta` payload contains only static config
- [ ] No `log_capture` payload omits the actual captured engine value
