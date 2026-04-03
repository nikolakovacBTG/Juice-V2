## L3 Appearance From/To

**Purpose:** Define appearance effect patterns for visibility, modulate, and shader properties.

**Mission:** Provide visual effect delta calculations using From/To reference resolution.

**Vision:** Create consistent appearance effects that work across all visual domains.

---

# ============================================================================
# WHAT: Appearance delta calculations for visibility, modulate, and shader properties
# EXPECTS: L2 write coordination and L1 timing system for visual effect processing
# PROVIDES: Appearance delta calculations to L2 domain nodes for aggregation
# ARCHITECTURE: L3 effect implementation that extends domain effect bases
# ============================================================================

## Appearance Delta Model

### Core Pattern
```gdscript
# L3 appearance effects calculate visual deltas:
func _get_seq_contribution() -> Dictionary:
    var current_value = _interpolate(_from, _to, _progress)
    var delta = current_value - _natural_base
    return {"property": delta}
```

### Visual Properties
- **Control:** modulate, self_modulate, visibility
- **Node2D:** modulate, self_modulate, visibility
- **Node3D:** modulate, self_modulate, visibility, shader parameters

---

## Domain Implementation

### Control Appearance
```gdscript
# L3 Control handles visual properties:
class AppearanceControlJuiceEffect extends JuiceControlEffectBase:
    var from_modulate: Color
    var to_modulate: Color
    var from_visible: bool
    var to_visible: bool
    
    func _get_seq_contribution() -> Dictionary:
        var contribution = {}
        
        if _should_animate_modulate():
            var current = from_modulate.lerp(to_modulate, _progress)
            contribution["modulate"] = current - _natural_base.modulate
        
        if _should_animate_visibility():
            contribution["visible"] = to_visible  # Binary, no delta needed
        
        return contribution
```

### Node2D Appearance
```gdscript
# L3 Node2D handles visual properties:
class Appearance2DJuiceEffect extends Juice2DEffectBase:
    func _get_seq_contribution() -> Dictionary:
        var contribution = {}
        
        if _animate_modulate:
            var current = from_modulate.lerp(to_modulate, _progress)
            contribution["modulate"] = current - _natural_base.modulate
        
        return contribution
```

### Node3D Appearance
```gdscript
# L3 Node3D handles visual properties:
class Appearance3DJuiceEffect extends Juice3DEffectBase:
    func _get_seq_contribution() -> Dictionary:
        var contribution = {}
        
        if _animate_modulate:
            var current = from_modulate.lerp(to_modulate, _progress)
            contribution["modulate"] = current - _natural_base.modulate
        
        if _animate_shader_param:
            var current = _interpolate_shader_param()
            contribution[_shader_param_name] = current - _natural_base_shader_value
        
        return contribution
```

---

## Shader Parameter Animation

### Parameter Resolution
```gdscript
# L3 handles shader parameter animation:
func _get_shader_param_value(param_name: String) -> Variant:
    if target.has_method("get_shader_parameter"):
        return target.get_shader_parameter(param_name)
    return null

func _set_shader_param_value(param_name: String, value: Variant) -> void:
    if target.has_method("set_shader_parameter"):
        target.set_shader_parameter(param_name, value)
```

### Parameter Interpolation
```gdscript
# L3 interpolates shader parameters:
func _interpolate_shader_param() -> Variant:
    var from_value = _get_shader_param_value(_shader_param_name)
    
    match typeof(from_value):
        TYPE_FLOAT:
            return lerp(from_value, to_shader_value, _progress)
        TYPE_VECTOR2:
            return from_value.lerp(to_shader_value, _progress)
        TYPE_VECTOR3:
            return from_value.lerp(to_shader_value, _progress)
        TYPE_COLOR:
            return from_value.lerp(to_shader_value, _progress)
        _:
            return to_shader_value
```

---

## Visibility Handling

### Binary Visibility
```gdscript
# L3 handles binary visibility changes:
func _calculate_visibility_delta() -> bool:
    # Visibility is binary, no delta calculation
    # Just return target state
    return to_visible
```

### Visibility Timing
```gdscript
# L3 handles visibility timing:
func _apply_visibility_effect() -> void:
    if _progress >= _visibility_threshold:
        target.visible = to_visible
```

---

## Cross-References

**Foundational Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-timing-system.md for progress integration

**Domain Documents:**
- See L2-write-coordination.md for delta aggregation
- See L2-domain-separation.md for domain-specific properties

**Effect Documents:**
- See L3-transform-deltas.md for delta patterns
- See L3-procedural-animation.md for mathematical effects

---

## This Document's Role

### During Implementation
- **Appearance Reference:** Implement visual effects correctly
- **Shader Guide:** Handle shader parameter animation
- **Visibility Guide:** Handle binary visibility changes

### During Refactoring
- **Appearance Consistency:** Maintain visual behavior across changes
- **Shader Preservation:** Ensure shader animation works
- **Domain Compatibility:** Preserve domain-specific visual properties

### For Developers
- **Implementation Pattern:** Understand appearance delta calculation
- **Domain Rules:** Know domain-specific visual properties
- **Shader Guide:** Animate shader parameters correctly

---

## Cross-References

**Foundational Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-base-interfaces.md for effect interfaces

**Related L3 Documents:**
- See L3-transform-deltas.md for delta patterns
- See L3-shader-integration.md for advanced shader handling

**L2 Integration:**
- See L2 docs for delta aggregation and write coordination

This appearance system provides visual effect delta calculations while maintaining delta-first architectural integrity across all domains.
