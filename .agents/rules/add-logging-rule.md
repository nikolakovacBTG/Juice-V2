

# Debug Logging Standards

## Overview
Standards for adding and maintaining debug logging across the Juice V1 addon (`addons/Juice_V1/`). All logging must serve two audiences: AI agents fixing Juice bugs, and non-programmer users diagnosing misconfigurations.

## Log Format Standard

All Juice log output MUST use this format:
```
[Juice][Domain][EffectType] TargetName: message
```

Examples:
```
[Juice][Control][Transform] PlayBtn: Captured base: pos=(120, 340) scale=(1, 1)
[Juice][2D][Shake] Goblin: Delta: progress=0.500 offset=(3.2, -1.1)
[Juice][3D][Appearance] Chest: Shader uniform 'outline_width' not found on material
[Juice][Base] ButtonPop: Trigger handled: play_in=true, behaviour=PLAY_IN_ONLY
```

For warnings use `push_warning()` (yellow console output):
```
[Juice][WARNING] EnemyShake: Domain mismatch — Shake2DJuiceEffect on Control node
```

## Three-Tier Guard Pattern

Every log call must be wrapped in this hierarchy:

```gdscript
# Tier 1: OS.is_debug_build() — inside JuiceLogger methods (zero cost in export)
# Tier 2: Master switch — ProjectSettings "juice/debug/enabled" (one-click enable all)
# Tier 3: Per-node debug_enabled — individual node isolation

# The logic is OR between Tier 2 and Tier 3:
# Log if: OS.is_debug_build() AND (master_switch OR node.debug_enabled)
```

**Never** put `OS.is_debug_build()` checks in calling code — that gate lives exclusively inside `JuiceLogger` static methods.

## Mandatory: Use JuiceLogger

- **NEVER** use raw `print()` or `push_warning()` for Juice debug output
- **ALWAYS** go through `JuiceLogger` static methods
- This ensures format consistency, guard enforcement, and file logging

## Ad-Hoc Print Audit Rule

When encountering existing `if debug_enabled: print(...)` calls during instrumentation:
1. **Evaluate**: Is this log useful for diagnosing bugs in the wild?
2. **Keep + Convert**: If useful → convert to appropriate `JuiceLogger` method
3. **Remove**: If it's a dev leftover with no diagnostic value → delete it
4. **Never preserve raw prints** as-is — every print becomes a `JuiceLogger` call or gets removed

## The Six Logging Categories

| # | Category | JuiceLogger Method | When to Use |
|---|----------|--------------------|-------------|
| 1 | Standardized Header | `log_info()` | General lifecycle events (trigger, start, stop, complete) |
| 2 | Capture Verification | `log_capture()` | When base values or From/To snapshots are captured |
| 3 | Delta Reporting | `log_delta()` | Inside `_apply_effect()` — per-frame math trace |
| 4 | Shader Diagnostics | `log_shader()` | Appearance effects setting material uniforms |
| 5 | Aggregation Summary | `log_aggregation()` | Domain node `_post_tick_write()` — final write values |
| 6 | Domain Guardrails | `warn_domain_mismatch()` | Wrong effect type on wrong node type |

## Anti-Patterns

```gdscript
# BAD: Raw print
if debug_enabled:
    print("[%s] Started" % name)

# BAD: Format string outside guard (runs in release builds)
var msg := "[%s] Delta: %s" % [name, delta]
if debug_enabled:
    print(msg)

# BAD: OS.is_debug_build() in calling code
if OS.is_debug_build() and debug_enabled:
    print("something")

# GOOD: All logging through JuiceLogger
JuiceLogger.log_info(self, "Control", "Started", debug_enabled)
JuiceLogger.log_delta(self, progress, delta, target.name, debug_enabled)
```

## File Logging

When enabled via Project Settings (`juice/debug/log_to_file`), JuiceLogger writes simultaneously to:
- Godot Output console (for immediate visibility)
- `user://juice_debug.log` (for bug report collection)

The log file is the primary artifact for bug reports. Frame-by-frame delta logs (Category 3) always write to file when debug is active — the file handles the volume. Users never read the raw file; AI agents parse it.
