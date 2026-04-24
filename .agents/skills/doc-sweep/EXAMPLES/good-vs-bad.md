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

### BAD: Phase-tagged TODO
```gdscript
# TODO(phase-4): Absorb META_KEY into JuiceLedger
```

### GOOD: Clean TODO
```gdscript
# TODO: Absorb META_KEY into JuiceLedger
```

### OK: Sequential algorithm steps (not dev phases)
```gdscript
# Step 1: Start async loading
# Step 2: Cover with transition effect
# Step 3: Execute scene action
```
These describe the *algorithm flow*, not the *development timeline* — perfectly fine.

### SKIP: Self-documenting
```gdscript
# No comment needed — the name, return type, and body tell the full story.
func _needs_sustain() -> bool:
    return true
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
