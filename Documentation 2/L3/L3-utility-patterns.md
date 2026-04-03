## L3 Utility Patterns

**Purpose:** Define utility effect patterns for common reusable functionality.

**Mission:** Provide utility effects that simplify common animation and interaction patterns.

**Vision:** Create utility effects that enhance developer productivity and code reusability.

---

# ============================================================================
# WHAT: Utility delta calculations for common reusable functionality patterns
# EXPECTS: L2 write coordination and L1 timing system for utility effect processing
# PROVIDES: Utility delta calculations to L2 domain nodes for common tasks
# ARCHITECTURE: L3 effect implementation that extends domain effect bases
# ============================================================================

## Utility Pattern Model

### Core Pattern
```gdscript
# L3 utility effects calculate task-specific deltas:
func _get_seq_contribution() -> Dictionary:
    var delta = _calculate_utility_delta()
    return {"property": delta}
```

### Utility Categories
- **Interaction Effects:** User input and interaction patterns
- **Scene Actions:** Scene management and transitions
- **Utility Helpers:** Common animation helpers

---

## Interaction Effects

### Button Feedback
```gdscript
# L3 interaction effects handle user feedback:
class ButtonPressJuiceEffect extends JuiceControlEffectBase:
    var press_scale: Vector2 = Vector2(0.95, 0.95)
    var hover_color: Color = Color.WHITE
    
    func _get_seq_contribution() -> Dictionary:
        var contribution = {}
        
        if _should_animate_press():
            var current = Vector2.ONE.lerp(press_scale, _progress)
            contribution["scale"] = current - _natural_base.scale
        
        if _should_animate_hover():
            var current = Color.WHITE.lerp(hover_color, _progress)
            contribution["modulate"] = current - _natural_base.modulate
        
        return contribution
```

### Input Response
```gdscript
# L3 interaction effects respond to input:
class InputFeedbackJuiceEffect extends JuiceEffectBase:
    var input_type: String = "mouse"
    
    func _get_seq_contribution() -> Dictionary:
        match input_type:
            "mouse":
                return _calculate_mouse_feedback()
            "keyboard":
                return _calculate_keyboard_feedback()
            "touch":
                return _calculate_touch_feedback()
        return {}
```

---

## Scene Actions

### Scene Transitions
```gdscript
# L3 scene action effects handle scene management:
class SceneActionJuiceEffect extends JuiceEffectBase:
    var target_scene: String = ""
    var transition_type: String = "fade"
    
    func _get_seq_contribution() -> Dictionary:
        # Scene actions don't write to target
        # They coordinate with scene management
        _execute_scene_action()
        return {}
    
    func _execute_scene_action():
        match transition_type:
            "fade":
                _fade_to_scene()
            "slide":
                _slide_to_scene()
            "instant":
                _instant_scene_change()
```

### Node Management
```gdscript
# L3 utility effects handle node operations:
class NodeUtilityJuiceEffect extends JuiceEffectBase:
    var operation: String = ""
    var target_path: NodePath
    
    func _get_seq_contribution() -> Dictionary:
        match operation:
            "show":
                _show_target()
            "hide":
                _hide_target()
            "enable":
                _enable_target()
            "disable":
                _disable_target()
        return {}
```

---

## Domain-Specific Implementation

### Control Utilities
```gdscript
# L3 Control handles Control-specific utilities:
class UtilityControlJuiceEffect extends JuiceControlEffectBase:
    func _get_seq_contribution() -> Dictionary:
        match utility_type:
            UtilityType.INTERACTION:
                return _handle_interaction_utility()
            UtilityType.SCENE_ACTION:
                return _handle_scene_utility()
            UtilityType.HELPER:
                return _handle_helper_utility()
```

### Node2D Utilities
```gdscript
# L3 Node2D handles Node2D-specific utilities:
class Utility2DJuiceEffect extends Juice2DEffectBase:
    func _get_seq_contribution() -> Dictionary:
        return _calculate_2d_utility_delta()
```

### Node3D Utilities
```gdscript
# L3 Node3D handles Node3D-specific utilities:
class Utility3DJuiceEffect extends Juice3DEffectBase:
    func _get_seq_contribution() -> Dictionary:
        return _calculate_3d_utility_delta()
```

---

## Cross-References

**Foundational Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-timing-system.md for utility coordination

**Domain Documents:**
- See L2-write-coordination.md for utility delta aggregation
- See L2-domain-separation.md for domain-specific utility handling

**Effect Documents:**
- See L3-transform-deltas.md for transform patterns
- See L3-meta-effects.md for system-level patterns

---

## This Document's Role

### During Implementation
- **Utility Reference:** Implement common functionality correctly
- **Helper Guide:** Use utility patterns for common tasks
- **Domain Guide:** Know domain-specific utility requirements

### During Refactoring
- **Utility Consistency:** Maintain common functionality across changes
- **Helper Preservation:** Ensure utility patterns work correctly
- **Domain Compatibility:** Preserve domain-specific utility handling

### For Developers
- **Implementation Pattern:** Understand utility delta calculation
- **Domain Rules:** Know domain-specific utility requirements
- **Helper Guide:** Use utilities for common tasks

---

## Cross-References

**Foundational Documents:**
- See L1-delta-first-model.md for mathematical foundation
- See L1-base-interfaces.md for effect interfaces

**Related L3 Documents:**
- See L3-transform-deltas.md for transform patterns
- See L3-meta-effects.md for system-level effects

**L2 Integration:**
- See L2 docs for utility delta aggregation and write coordination

This utility pattern system provides common functionality while maintaining delta-first architectural integrity across all domains.
