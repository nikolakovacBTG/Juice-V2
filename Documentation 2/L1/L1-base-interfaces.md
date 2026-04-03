## L1 Base Interfaces

**Purpose:** Define the core interfaces and base classes that provide unified functionality across all Juice domains.

**Mission:** Provide consistent interfaces that enable domain-specific implementations while maintaining architectural contracts.

**Vision:** Create base classes that handle common functionality so domains can focus on their specific challenges.

---

# ============================================================================
# WHAT: Core interface definitions and base class implementations for Juice V1
# EXPECTS: L2 domain nodes to extend base classes and L3 effects to implement effect interfaces
# PROVIDES: Unified interfaces, base functionality, and extension patterns to all layers
# ARCHITECTURE: L1 core infrastructure that defines the inheritance hierarchy
# ============================================================================

## Base Class Hierarchy

### JuiceBase (Core Node Class)
```gdscript
# L1 provides this foundation for all domain nodes:
class JuiceBase extends Node:
    # Recipe management
    var recipe: JuiceRecipe
    var _is_playing: bool = false
    
    # Timing system
    var _progress: float = 0.0
    var _duration: float = 1.0
    var _start_delay: float = 0.0
    
    # Virtual methods for L2 implementation
    func _validate_target() -> bool:
        push_error("Must implement _validate_target in domain class")
        return false
    
    func _process_frame_effects() -> void:
        push_error("Must implement _process_frame_effects in domain class")
```

### JuiceEffectBase (Effect Resource Class)
```gdscript
# L1 provides this foundation for all effects:
class JuiceEffectBase extends Resource:
    # Effect configuration
    var trigger_behaviour: int = 0
    var start_delay: float = 0.0
    var crossfade_time: float = 0.0
    var loop_count: int = 1
    
    # Core interface methods
    func _apply_effect(progress: float) -> Dictionary:
        push_error("Must implement _apply_effect in effect class")
        return {}
    
    func _get_seq_contribution() -> Dictionary:
        return _apply_effect(_progress)
```

### JuiceRecipe (Effect Container)
```gdscript
# L1 provides this container for effects:
class JuiceRecipe extends Resource:
    var effects: Array[JuiceEffectBase] = []
    var trigger_mode: int = 0
    
    func add_effect(effect: JuiceEffectBase) -> void:
        effects.append(effect)
    
    func get_effects() -> Array[JuiceEffectBase]:
        return effects
```

---

## Interface Contracts

### JuiceBase Interface (L2 Implementation)
```gdscript
# L1 defines this interface that L2 must implement:

class JuiceBase extends Node:
    # Lifecycle management (L1 provides, L2 extends)
    func _ready() -> void
    func _process(delta: float) -> void
    func _exit_tree() -> void
    
    # Animation control (L1 provides, L2 extends)
    func animate_in() -> void
    func animate_out() -> void
    func stop() -> void
    
    # Domain-specific (L2 must implement)
    func _validate_target() -> bool
    func _capture_natural_base() -> void
    func _process_frame_effects() -> void
    func _write_target_values() -> void
    
    # State queries (L1 provides)
    func is_playing() -> bool
    func get_progress() -> float
```

### JuiceEffectBase Interface (L3 Implementation)
```gdscript
# L1 defines this interface that L3 must implement:

class JuiceEffectBase extends Resource:
    # Delta calculation (L3 must implement)
    func _apply_effect(progress: float) -> Dictionary
    
    # Stacking support (L3 must implement)
    func _get_seq_contribution() -> Dictionary
    
    # Lifecycle hooks (L3 can override)
    func _on_animate_start() -> void
    func _on_animate_stop() -> void
    
    # Configuration (L1 provides)
    func set_trigger_behaviour(behaviour: int) -> void
    func set_start_delay(delay: float) -> void
```

---

## Implementation Patterns

### Domain Node Pattern
```gdscript
# L2 extends L1 base for domain-specific implementation:
class JuiceControl extends JuiceBase:
    func _validate_target() -> bool:
        return get_parent() is Control
    
    func _capture_natural_base() -> void:
        _natural_base = {
            "position": target.position
        }
    
    func _process_frame_effects() -> void:
        var total_delta = _aggregate_effect_deltas()
        _write_target_values(total_delta)
```

### Effect Resource Pattern
```gdscript
# L3 extends L1 base for effect-specific implementation:
class TransformControlJuiceEffect extends JuiceControlEffectBase:
    var from_position: Vector2
    var to_position: Vector2
    
    func _apply_effect(progress: float) -> Dictionary:
        var current = from_position.lerp(to_position, progress)
        return {"position": current - _natural_base.position}
```

### Recipe Composition Pattern
```gdscript
# L1 provides recipe composition:
var recipe = JuiceRecipe.new()
recipe.add_effect(TransformControlJuiceEffect.new())
recipe.add_effect(AppearanceControlJuiceEffect.new())

juice_node.recipe = recipe
```

---

## Extension Points

### Domain Extension Points
```gdscript
# L2 can extend L1 functionality:
class Juice2D extends JuiceBase:
    # Add domain-specific properties
    var pivot_compensation: bool = true
    
    # Extend base methods
    func _process(delta: float) -> void:
        super._process(delta)
        _handle_2d_specifics()
    
    # Add domain-specific methods
    func _handle_pivot_compensation() -> void:
        # 2D-specific pivot handling
```

### Effect Extension Points
```gdscript
# L3 can extend L1 functionality:
class Shake2DJuiceEffect extends Juice2DEffectBase:
    # Add effect-specific properties
    var noise_frequency: float = 1.0
    var noise_amplitude: float = 10.0
    
    # Extend base methods
    func _apply_effect(progress: float) -> Dictionary:
        var base_delta = super._apply_effect(progress)
        var shake_delta = _calculate_shake(progress)
        return {"position": base_delta.position + shake_delta}
```

---

## Virtual Methods

### JuiceBase Virtual Methods
```gdscript
# L1 provides these virtual methods for L2:

# Must implement:
func _validate_target() -> bool
func _capture_natural_base() -> void
func _process_frame_effects() -> void
func _write_target_values() -> void

# Can override:
func _on_animation_start() -> void
func _on_animation_complete() -> void
func _on_animation_stop() -> void
```

### JuiceEffectBase Virtual Methods
```gdscript
# L1 provides these virtual methods for L3:

# Must implement:
func _apply_effect(progress: float) -> Dictionary

# Can override:
func _on_animate_start() -> void
func _on_animate_stop() -> void
func _validate_configuration() -> bool
```

---

## Signal System

### JuiceBase Signals
```gdscript
# L1 provides these signals:
signal animation_started
signal animation_progressed(progress: float)
signal animation_completed
signal animation_stopped

# L2 can emit these signals:
func _process(delta: float) -> void:
    super._process(delta)
    animation_progressed.emit(_progress)
```

### JuiceEffectBase Signals
```gdscript
# L1 provides effect signals:
signal effect_started
signal effect_completed

# L3 can emit these signals:
func _on_animate_start() -> void:
    effect_started.emit()
```

---

## Validation Interfaces

### Base Validation
```gdscript
# L1 provides validation framework:
class JuiceBase:
    func _validate_configuration() -> bool:
        return _validate_target() and _validate_recipe()
    
    func _validate_target() -> bool:
        # L2 implements domain-specific validation
        pass
    
    func _validate_recipe() -> bool:
        return recipe != null and recipe.effects.size() > 0
```

### Effect Validation
```gdscript
# L1 provides effect validation:
class JuiceEffectBase:
    func _validate_configuration() -> bool:
        return _validate_parameters() and _validate_timing()
    
    func _validate_parameters() -> bool:
        # L3 implements effect-specific validation
        pass
```

---

## Cross-Reference Contracts

### Interface Dependencies
**L1-base-interfaces.md Must Reference:**
- L1-layer-contracts.md (interface contract definitions)
- L1-delta-first-model.md (interface mathematical context)

**L2 Documents Must Reference:**
- L1-base-interfaces.md (base class usage)
- L1-layer-contracts.md (interface implementation contracts)

**L3 Documents Must Reference:**
- L1-base-interfaces.md (effect interface methods)
- L1-timing-system.md (timing event hooks)

---

## This Document's Role

### During Implementation
- **Interface Reference:** Ensure consistent interface usage across domains
- **Extension Guide:** Understand how to properly extend base classes
- **Validation Source:** Verify interface contracts are honored

### During Refactoring
- **Interface Consistency:** Maintain interface stability across changes
- **Extension Compatibility:** Ensure extensions continue to work
- **Contract Validation:** Verify interface contracts are preserved

### For Developers
- **Inheritance Guide:** Understand how to extend base classes correctly
- **Interface Reference:** Know which methods to implement vs override
- **Validation Rules:** Understand validation requirements

---

## Cross-References

**Foundational Documents:**
- See L1-layer-contracts.md for interface contract definitions
- See L1-delta-first-model.md for mathematical context

**Implementation Documents:**
- See L2 docs for domain-specific base class usage
- See L3 docs for effect interface implementation

**Validation Documents:**
- See VALIDATION_STANDARDS.md for interface validation criteria
- See L1-3_CONTRACT_MATRIX.md for complete interface contracts

These base interfaces provide the foundation that enables consistent domain implementations while maintaining architectural contracts across the entire Juice system.
