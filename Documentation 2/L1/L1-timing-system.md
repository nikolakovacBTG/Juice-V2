## L1 Timing System

**Purpose:** Define the timing infrastructure and animation lifecycle that coordinates all Juice effects across domains.

**Mission:** Provide unified timing and animation coordination that enables effect synchronization and proper lifecycle management.

**Vision:** Create a timing system that seamlessly coordinates multiple effects while maintaining performance and predictability.

---

# ============================================================================
# WHAT: Unified timing infrastructure and animation lifecycle management
# EXPECTS: L2 domain nodes to implement per-frame timing coordination and L3 effects to use timing for calculations
# PROVIDES: Timing contracts, lifecycle events, and coordination patterns to all layers
# ARCHITECTURE: L1 core infrastructure that all domains use for animation timing
# ============================================================================

## Core Timing Model

### Animation Lifecycle
```
1. Trigger → animate_in() called
2. Setup → Base values captured, effects enabled
3. Process → _process(delta) runs each frame
4. Complete → Animation reaches end state
5. Cleanup → Effects disabled, state restored
```

### Timing Infrastructure
```gdscript
# L1 provides this timing foundation:
class JuiceBase:
    var _is_playing: bool = false
    var _progress: float = 0.0
    var _duration: float = 1.0
    var _start_delay: float = 0.0
    
    func _process(delta: float) -> void:
        if _is_playing:
            _update_timing(delta)
            _apply_frame_effects()
```

### Progress Calculation
```gdscript
# L1 defines this progress calculation:
func _update_timing(delta: float) -> void:
    if _start_delay > 0:
        _start_delay -= delta
        return
    
    _progress += delta / _duration
    
    if _progress >= 1.0:
        _progress = 1.0
        _on_animation_complete()
        _is_playing = false
```

---

## Timing Contracts

### L1 Provides to L2 (Domain Timing)
**Frame Timing Contract:**
```gdscript
# L1 provides this timing that L2 must use:
func _process(delta: float) -> void:
    # L2 must call this for frame timing
    _update_base_timing(delta)
    
    # L2 must implement per-frame effect processing
    _process_frame_effects()
```

**Animation Control Contract:**
```gdscript
# L1 provides these controls that L2 must implement:
func animate_in() -> void:
    # L2 must implement domain-specific start behavior
    _start_animation()

func stop() -> void:
    # L2 must implement domain-specific stop behavior
    _stop_animation()
```

**Lifecycle Event Contract:**
```gdscript
# L1 provides these events that L2 must handle:
signal animation_started
signal animation_completed  
signal animation_stopped

# L2 must connect and respond to these signals
```

### L1 Provides to L3 (Effect Timing)
**Progress Value Contract:**
```gdscript
# L1 provides this progress that L3 must use:
var _progress: float  # 0.0 to 1.0

# L3 effects must use this for calculations:
func _apply_effect(progress: float) -> Dictionary:
    return _calculate_delta_at_progress(progress)
```

**Timing Event Contract:**
```gdscript
# L1 provides these timing events that L3 must handle:
func _on_animate_start() -> void:
    # L3 must capture references at start

func _on_animate_stop() -> void:
    # L3 must clean up state
```

---

## Implementation Patterns

### Base Timing Implementation
```gdscript
# L1 provides this pattern for L2 implementation:
class JuiceBase:
    var _progress: float = 0.0
    var _duration: float = 1.0
    var _start_delay: float = 0.0
    var _is_playing: bool = false
    
    func _process(delta: float) -> void:
        if not _is_playing:
            return
        
        if _start_delay > 0:
            _start_delay -= delta
            return
        
        _progress += delta / _duration
        
        if _progress >= 1.0:
            _progress = 1.0
            _on_animation_complete()
            _is_playing = false
        
        _apply_frame_effects()
    
    func animate_in() -> void:
        _progress = 0.0
        _is_playing = true
        _on_animate_start()
    
    func stop() -> void:
        _is_playing = false
        _on_animate_stop()
```

### Domain Timing Implementation
```gdscript
# L2 implements timing coordination:
class JuiceControl extends JuiceBase:
    func _process(delta: float) -> void:
        super._process(delta)  # L1 timing
        
        if _is_playing:
            _detect_external_moves()
            _aggregate_effect_deltas()
            _write_target_values()
```

### Effect Timing Implementation
```gdscript
# L3 uses timing for calculations:
class TransformControlJuiceEffect extends JuiceControlEffectBase:
    func _apply_effect(progress: float) -> Dictionary:
        var eased_progress = _apply_easing(progress)
        var current_value = _interpolate(_from, _to, eased_progress)
        var delta = current_value - _natural_base
        return {"position": delta}
```

---

## Easing and Curves

### Easing Integration
```gdscript
# L1 provides easing integration:
class JuiceBase:
    var _easing_type: int = EASE_LINEAR
    
    func _get_eased_progress(progress: float) -> float:
        match _easing_type:
            EASE_LINEAR:
                return progress
            EASE_IN_OUT:
                return _ease_in_out(progress)
            # ... other easing types
```

### Common Easing Functions
```gdscript
# L1 provides these easing functions:
func _ease_in_out(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)

func _ease_in(t: float) -> float:
    return t * t

func _ease_out(t: float) -> float:
    return 1.0 - (1.0 - t) * (1.0 - t)
```

---

## Chaining and Sequencing

### Animation Chaining
```gdscript
# L1 provides chaining infrastructure:
class JuiceBase:
    var _chain_next: JuiceBase
    var _auto_chain: bool = false
    
    func _on_animation_complete() -> void:
        if _auto_chain and _chain_next:
            _chain_next.animate_in()
```

### Delay and Stagger
```gdscript
# L1 provides delay coordination:
class JuiceBase:
    var _start_delay: float = 0.0
    
    func set_start_delay(delay: float) -> void:
        _start_delay = delay
    
    # Used by L2 for stagger effects
```

---

## Performance Considerations

### Frame Rate Independence
```gdscript
# L1 ensures frame rate independence:
func _process(delta: float) -> void:
    # Delta-based timing, not frame counting
    _progress += delta / _duration
```

### Process Optimization
```gdscript
# L1 provides process control:
class JuiceBase:
    var _is_playing: bool = false
    
    func _process(delta: float) -> void:
        # Early exit when not playing
        if not _is_playing:
            return
        
        # Minimal per-frame work
        _update_timing(delta)
        _apply_effects()
```

### Memory Efficiency
```gdscript
# L1 provides memory-efficient timing:
class JuiceBase:
    # Reuse timing variables
    var _progress: float = 0.0
    var _last_delta: float = 0.0
    
    # Avoid per-frame allocations
    func _apply_effects() -> void:
        # Re-use delta dictionaries
```

---

## Timing Validation

### Timing Accuracy Validation
- [ ] Progress values stay within 0.0 to 1.0 range
- [ ] Duration calculations are frame-rate independent
- [ ] Start delay functions correctly
- [ ] Animation completes at expected time

### Performance Validation
- [ ] Process overhead is minimal when not playing
- [ ] No per-frame memory allocations
- [ ] Frame rate independence maintained
- [ ] Multiple animations scale linearly

### Integration Validation
- [ ] L2 domains properly inherit timing
- [ ] L3 effects correctly use progress values
- [ ] Lifecycle events fire at correct times
- [ ] Chaining and sequencing work as expected

---

## Cross-Reference Contracts

### Required Timing References
**L1 Documents Must Reference:**
- L1-layer-contracts.md (timing contract definitions)
- L1-base-interfaces.md (timing interface methods)

**L2 Documents Must Reference:**
- L1-timing-system.md (timing implementation)
- L1-layer-contracts.md (timing coordination contracts)

**L3 Documents Must Reference:**
- L1-timing-system.md (progress usage)
- L1-base-interfaces.md (timing event hooks)

---

## This Document's Role

### During Implementation
- **Timing Reference:** Ensure consistent timing across all domains
- **Performance Guide:** Optimize timing for frame rate independence
- **Integration Source:** Coordinate timing between layers

### During Refactoring
- **Timing Consistency:** Maintain timing behavior across changes
- **Performance Preservation:** Ensure timing optimizations are maintained
- **Contract Validation:** Verify timing contracts are honored

### For Developers
- **Timing Patterns:** Understand how to implement timing correctly
- **Performance Guidelines:** Write efficient timing code
- **Integration Rules:** Know how timing works across layers

---

## Cross-References

**Foundational Documents:**
- See L1-layer-contracts.md for timing contract definitions
- See L1-base-interfaces.md for timing interface methods

**Implementation Documents:**
- See L2 docs for domain-specific timing implementation
- See L3 docs for effect timing usage

**Validation Documents:**
- See VALIDATION_STANDARDS.md for timing validation criteria
- See L1-3_CONTRACT_MATRIX.md for complete timing contracts

This timing system provides the temporal foundation that coordinates all Juice effects while maintaining performance and predictability across all domains.
