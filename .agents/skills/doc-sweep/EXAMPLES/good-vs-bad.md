# Good vs Bad Comment Examples

Real examples from this codebase.

## Method Comments

### BAD: Restates the function name
```gdscript
# Stops the effect and restores to natural state.
func stop(target: Node) -> void:
```
The function signature already says `stop`. This comment adds zero information.

### GOOD: Explains non-obvious behavior
```gdscript
## Stop immediately and restore to natural state.
## Provides a hard reset for sequence cancellation or target node cleanup,
## ensuring no visual residue is left behind.
func stop(target: Node) -> void:
```
Now the reader knows WHY stop exists beyond just "stopping" — it's about cleanup guarantees.

### BAD: Cargo-cult prefix
```gdscript
# RATIONALE: Captures base values and resets the discrete tick timer before the first frame.
func _on_animate_start(target: Node) -> void:
```
The "RATIONALE:" prefix creates redundancy. The sentence IS the rationale.

### GOOD: Natural explanation
```gdscript
# Captures base values and resets the discrete tick timer before the first frame.
func _on_animate_start(target: Node) -> void:
```

## Virtual Hook Implementations (NEW — the biggest gap from the previous sweep)

Virtual hook implementations are methods in concrete effects that override base class hooks.
They are the connective tissue between the architecture and the domain-specific behavior.
Without comments, a reader must trace 3 levels of inheritance to understand what calls them and when.

### BAD: No comment at all
```gdscript
func _do_capture_base(target: Node) -> void:
    if _has_base:
        return
    var ctrl := target as Control
    # ...25 lines of ledger reads...
```
A developer reading this has no idea when `_do_capture_base` is called, by whom, or why it reads from the ledger instead of directly from the target.

### BAD: Restates the name
```gdscript
# Captures base values.
func _do_capture_base(target: Node) -> void:
```
This tells the reader nothing they couldn't see from the function name.

### GOOD: Explains the call chain and the WHY
```gdscript
# Called by JuiceControlTransformEffect._on_animate_start when effects start.
# Captures the natural position/rotation/scale from the JuiceLedger (not the
# target directly) to get the pre-Juice state even when other effects are active.
# Skip-guarded: only captures once per animation cycle to prevent mid-animation overwrite.
func _do_capture_base(target: Node) -> void:
```
Now a reader knows: (1) when it's called, (2) why it reads from ledger, (3) why the skip guard exists.

### BAD: Fabricated comment (doesn't match the code)
```gdscript
# Captures the current position from the target node.
func _capture_from_self_position_snapshot(target: Node) -> void:
    # Actually reads from ledger, falls back to editor cache...
```
This comment is WRONG — the method doesn't read from the target node directly. It reads from the ledger with an editor-cache fallback. A wrong comment is worse than no comment.

### GOOD: Honest description of the actual behavior
```gdscript
# Called during _on_animate_start when from_reference == SELF.
# Captures the starting position using the ledger's natural state to avoid
# reading dirty values from other active effects. Falls back to the baked
# editor cache when no ledger entry exists (rare — only before first ready).
func _capture_from_self_position_snapshot(target: Node) -> void:
```

## History References

### BAD: History reference
```gdscript
## Mirrors V0's direct-apply pattern: initialises effects on first call, then
## sets progress and writes deltas to the target node directly each call.
```

### GOOD: Translated to pure architecture
```gdscript
## Bypasses the standard animation loop to allow external systems to drive
## the effect directly. Initialises effects on first call, then sets progress
## and writes deltas to the target node each call.
## Does NOT rely on _process (which self-terminates when no effects are playing).
```
Same technical content, zero historical baggage.

### BAD: Development phase prefix
```gdscript
# Phase B: Sibling stacking with metadata-based natural base capture
```
"Phase B" is an internal development milestone label — marketplace buyers have no idea what it means.

### GOOD: Content without phase label
```gdscript
# Sibling stacking with metadata-based natural base capture
```

## Class Tooltips

### BAD: Generic filler
```gdscript
## A class that handles transform effects for Control nodes.
```

### GOOD: Action-oriented, specific
```gdscript
## Animate position, rotation, or scale of a [Control] with tween-based easing and From/To configuration.
```

## Export Tooltips

### BAD: Restates the variable name
```gdscript
## The duration.
@export var duration_in: float = 0.3
```

### GOOD: Explains what it controls
```gdscript
## Seconds for the animate_in phase. Applies the configured easing curve over this duration.
@export var duration_in: float = 0.3
```

## Self-Documenting (SKIP)

### No comment needed — the name, return type, and body tell the full story.
```gdscript
func _needs_sustain() -> bool:
    return true
```

### No comment needed — obvious reset-to-defaults.
```gdscript
func _clear_from_editor_cache_typed() -> void:
    _from_editor_cached_position = Vector2.ZERO
    _from_editor_cached_rotation = 0.0
    _from_editor_cached_scale = Vector2.ONE
```

## TODO Triage

### STALE TODO → Replace with accurate comment
```gdscript
# Before (stale — base class already handles this):
return null  # TODO: Sequencer mode target resolution

# After (explains the actual behavior):
return null  # SEQUENCER resolves per-target dynamically
```

### VALID TODO → Report as blocker, do NOT delete
```gdscript
# This TODO represents real unfinished work — the META_KEY pattern
# hasn't been unified with JuiceLedger yet. Report in batch summary,
# leave in place until user resolves.
# TODO: Absorb META_KEY into JuiceLedger as "self_modulate" property.
```

### WRONG: Blind deletion
```gdscript
# Never do this — deleting a valid TODO hides real work:
# (was) # TODO: Absorb META_KEY into JuiceLedger
# (now) [line deleted, work item lost]
```
