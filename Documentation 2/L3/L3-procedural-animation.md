## L3 Procedural Animation

**Purpose:** Define procedural effect patterns for noise, shake, and spring animations.

**Mission:** Provide mathematical procedural animations that react to external forces.

**Vision:** Create dynamic procedural effects that enhance visual feedback through ongoing motion.

---

# ============================================================================
# WHAT: Procedural delta calculations for noise, shake, and spring animations
# EXPECTS: L2 write coordination and L1 timing system for ongoing effect processing
# PROVIDES: Procedural delta calculations to L2 domain nodes for continuous animation
# ARCHITECTURE: L3 effect implementation that extends domain effect bases
# ============================================================================

## Procedural Animation Model

### Core Pattern
```gdscript
# L3 procedural effects calculate ongoing deltas:
func _get_seq_contribution() -> Dictionary:
    var delta = _calculate_procedural_delta()
    return {"property": delta}
```

### Continuous Animation
- No fixed From/To endpoints
- Reacts to external forces (from stacked effects)
- Provides ongoing motion throughout animation

---

## Noise Effects

### Noise Calculation
```gdscript
# L3 noise generates random motion:
class Noise2DJuiceEffect extends Juice2DEffectBase:
    var noise_frequency: float = 1.0
    var noise_amplitude: Vector2 = Vector2(10, 10)
    var noise_time: float = 0.0
    
    func _get_seq_contribution() -> Dictionary:
        noise_time += get_process_delta_time()
        
        var noise_offset = Vector2(
            _noise_1d(noise_time * noise_frequency.x) * noise_amplitude.x,
            _noise_1d(noise_time * noise_frequency.y) * noise_amplitude.y
        )
        
        return {"position": noise_offset}
    
    func _noise_1d(t: float) -> float:
        # Simple noise function
        return sin(t * 1.1) * 0.5 + sin(t * 2.3) * 0.3 + sin(t * 3.7) * 0.2
```

### Domain-Specific Noise
```gdscript
# L3 implements domain-specific noise:
class NoiseControlJuiceEffect extends JuiceControlEffectBase:
    func _get_seq_contribution() -> Dictionary:
        return {"position": _calculate_2d_noise()}

class Noise3DJuiceEffect extends Juice3DEffectBase:
    func _get_seq_contribution() -> Dictionary:
        return {"position": _calculate_3d_noise()}
```

---

## Shake Effects

### Shake Calculation
```gdscript
# L3 shake creates random impulses:
class Shake2DJuiceEffect extends Juice2DEffectBase:
    var shake_intensity: float = 10.0
    var shake_decay: float = 0.9
    var shake_velocity: Vector2 = Vector2.ZERO
    
    func _get_seq_contribution() -> Dictionary:
        # Add random impulse
        shake_velocity += Vector2(
            randf_range(-1, 1) * shake_intensity,
            randf_range(-1, 1) * shake_intensity
        )
        
        # Apply decay
        shake_velocity *= shake_decay
        
        return {"position": shake_velocity}
```

### Shake Parameters
- **intensity:** Maximum shake force
- **decay:** Damping factor (0-1)
- **frequency:** How often impulses are added

---

## Spring Effects

### Spring Physics
```gdscript
# L3 spring creates reactive motion:
class Spring2DJuiceEffect extends Juice2DEffectBase:
    var stiffness: float = 100.0
    var damping: float = 10.0
    var mass: float = 1.0
    var rest_position: Vector2
    var spring_position: Vector2
    var spring_velocity: Vector2
    
    func _get_seq_contribution() -> Dictionary:
        # Calculate spring force
        var displacement = rest_position - spring_position
        var spring_force = displacement * stiffness
        
        # Calculate damping force
        var damping_force = -spring_velocity * damping
        
        # Apply forces
        var acceleration = (spring_force + damping_force) / mass
        spring_velocity += acceleration * get_process_delta_time()
        spring_position += spring_velocity * get_process_delta_time()
        
        return {"position": spring_position - rest_position}
```

### Spring Configuration
- **stiffness:** Spring force strength
- **damping:** Velocity damping
- **mass:** Object mass for physics
- **rest_position:** Equilibrium position

---

## Cross-References

**Foundational Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-timing-system.md for continuous animation

**Domain Documents:**
- See L2-write-coordination.md for ongoing delta aggregation
- See L2-domain-separation.md for domain-specific math

**Effect Documents:**
- See L3-transform-deltas.md for transform patterns
- See L3-appearance-from-to.md for From/To patterns

---

## This Document's Role

### During Implementation
- **Procedural Reference:** Implement ongoing animations correctly
- **Physics Guide:** Use proper mathematical models
- **Domain Guide:** Handle domain-specific procedural math

### During Refactoring
- **Procedural Consistency:** Maintain ongoing animation behavior
- **Physics Preservation:** Ensure mathematical models remain accurate
- **Domain Compatibility:** Preserve domain-specific handling

### For Developers
- **Implementation Pattern:** Understand procedural delta calculation
- **Domain Rules:** Know domain-specific procedural requirements
- **Physics Guide:** Use proper mathematical models

---

## Cross-References

**Foundational Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-base-interfaces.md for effect interfaces

**Related L3 Documents:**
- See L3-transform-deltas.md for transform patterns
- See L3-appearance-from-to.md for reference resolution

**L2 Integration:**
- See L2 docs for ongoing delta aggregation and write coordination

This procedural animation system provides ongoing motion effects while maintaining delta-first architectural integrity across all domains.
