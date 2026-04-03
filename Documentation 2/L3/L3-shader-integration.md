## L3 Shader Integration

**Purpose:** Define shader parameter animation patterns for advanced visual effects.

**Mission:** Provide shader delta calculations for material and shader property animation.

**Vision:** Create shader effects that enhance visual quality through material parameter animation.

---

# ============================================================================
# WHAT: Shader delta calculations for material and shader parameter animations
# EXPECTS: L2 write coordination and L1 timing system for shader effect processing
# PROVIDES: Shader delta calculations to L2 domain nodes for aggregation
# ARCHITECTURE: L3 effect implementation that extends domain effect bases
# ============================================================================

## Shader Integration Model

### Core Pattern
```gdscript
# L3 shader effects calculate parameter deltas:
func _get_seq_contribution() -> Dictionary:
    var current_value = _interpolate_shader_param()
    var delta = current_value - _natural_shader_value
    return {_shader_param_name: delta}
```

### Shader Parameter Types
- **Float:** Single numeric values
- **Vector2:** 2D coordinates and colors
- **Vector3:** 3D coordinates and colors
- **Color:** RGBA color values

---

## Material Animation

### Material Access
```gdscript
# L3 handles material parameter animation:
class ShaderEffectBase extends JuiceEffectBase:
    var shader_param_name: String = ""
    var material_path: String = ""
    
    func _get_shader_material() -> Material:
        if target.has_method("get_material"):
            return target.get_material()
        return null
    
    func _get_shader_param_value() -> Variant:
        var material = _get_shader_material()
        if material and material.has_method("get_shader_parameter"):
            return material.get_shader_parameter(shader_param_name)
        return null
```

### Parameter Animation
```gdscript
# L3 animates shader parameters:
class ColorShiftJuiceEffect extends ShaderEffectBase:
    var from_color: Color = Color.WHITE
    var to_color: Color = Color.RED
    
    func _get_seq_contribution() -> Dictionary:
        var current = from_color.lerp(to_color, _progress)
        var delta = current - _natural_shader_value
        return {"modulate": delta}
```

---

## Domain-Specific Implementation

### Control Shader Effects
```gdscript
# L3 Control handles Control shader animation:
class ShaderControlJuiceEffect extends JuiceControlEffectBase:
    func _get_seq_contribution() -> Dictionary:
        var current = _interpolate_shader_param()
        var delta = current - _natural_shader_value
        return {_shader_param_name: delta}
```

### Node2D Shader Effects
```gdscript
# L3 Node2D handles Sprite2D shader animation:
class Shader2DJuiceEffect extends Juice2DEffectBase:
    func _get_seq_contribution() -> Dictionary:
        if target is Sprite2D:
            var current = _interpolate_shader_param()
            var delta = current - _natural_shader_value
            return {_shader_param_name: delta}
        return {}
```

### Node3D Shader Effects
```gdscript
# L3 Node3D handles MeshInstance3D shader animation:
class Shader3DJuiceEffect extends Juice3DEffectBase:
    func _get_seq_contribution() -> Dictionary:
        if target is MeshInstance3D:
            var current = _interpolate_shader_param()
            var delta = current - _natural_shader_value
            return {_shader_param_name: delta}
        return {}
```

---

## Parameter Interpolation

### Type-Specific Interpolation
```gdscript
# L3 handles different parameter types:
func _interpolate_shader_param() -> Variant:
    var from_value = _get_shader_param_value()
    
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

## Cross-References

**Foundational Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-timing-system.md for progress integration

**Domain Documents:**
- See L2-write-coordination.md for delta aggregation
- See L2-domain-separation.md for domain-specific shader handling

**Effect Documents:**
- See L3-appearance-from-to.md for visual effect patterns
- See L3-procedural-animation.md for mathematical effects

---

## This Document's Role

### During Implementation
- **Shader Reference:** Implement shader parameter animation correctly
- **Material Guide:** Handle different material types
- **Domain Guide:** Know domain-specific shader requirements

### During Refactoring
- **Shader Consistency:** Maintain shader animation behavior across changes
- **Material Preservation:** Ensure material handling works correctly
- **Domain Compatibility:** Preserve domain-specific shader handling

### For Developers
- **Implementation Pattern:** Understand shader delta calculation
- **Domain Rules:** Know domain-specific shader requirements
- **Material Guide:** Handle different material types correctly

---

## Cross-References

**Foundational Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-base-interfaces.md for effect interfaces

**Related L3 Documents:**
- See L3-appearance-from-to.md for visual patterns
- See L3-procedural-animation.md for mathematical effects

**L2 Integration:**
- See L2 docs for delta aggregation and write coordination

This shader integration system provides material parameter animation while maintaining delta-first architectural integrity across all domains.
