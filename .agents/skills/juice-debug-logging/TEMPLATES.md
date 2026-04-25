# GDScript Logging Templates

Copy-paste patterns for each logging category. All patterns assume `JuiceLogger` exists as a static class.

## JuiceLogger API Reference

```gdscript
# Category 1: Lifecycle info
static func log_info(source: Object, domain: String, message: String, debug_flag: bool) -> void

# Category 2: Base value / snapshot capture
static func log_capture(source: Object, domain: String, property: String, value: Variant, debug_flag: bool) -> void

# Category 3: Per-frame math trace
static func log_delta(source: Object, domain: String, progress: float, delta: Variant, target_name: String, debug_flag: bool) -> void

# Category 4: Shader uniform diagnostics
static func log_shader(source: Object, domain: String, uniform_name: String, value: Variant, material_info: String, debug_flag: bool) -> void

# Category 5: Aggregation write summary
static func log_aggregation(domain: String, target_name: String, channel: String, base: Variant, total_delta: Variant, final_value: Variant, debug_flag: bool) -> void

# Category 6: Domain mismatch warning (always logs — no debug_flag needed)
static func warn_domain_mismatch(effect_class: String, expected_domain: String, actual_class: String) -> void

# General warning
static func warn(source: Object, domain: String, message: String, debug_flag: bool) -> void
```

## Pattern: Category 1 — Lifecycle Info

Use at trigger, start, stop, complete events.

```gdscript
# In JuiceBase._handle_trigger():
JuiceLogger.log_info(self, _get_domain_tag(), 
    "Trigger: play_in=%s behaviour=%s" % [play_in, 
    JuiceEffectBase.TriggerBehaviour.keys()[trigger_behaviour]], 
    debug_enabled)

# In JuiceBase.stop():
JuiceLogger.log_info(self, _get_domain_tag(), "Stopped", debug_enabled)

# In JuiceEffectBase.start():
JuiceLogger.log_info(self, _get_domain_tag(),
    "Start: direction=%s crossfade=%s" % [
    "IN" if play_in else "OUT", _is_crossfading],
    debug_enabled)
```

## Pattern: Category 2 — Capture Verification

Use when base values or From/To snapshots are captured.

```gdscript
# In domain node _capture_base_values():
JuiceLogger.log_capture(self, "Control", "position", _base_position, debug_enabled)
JuiceLogger.log_capture(self, "Control", "rotation", _base_rotation, debug_enabled)
JuiceLogger.log_capture(self, "Control", "scale", _base_scale, debug_enabled)

# In effect _on_animate_start():
JuiceLogger.log_capture(self, _get_domain_tag(), 
    "From.position", _from_position, debug_enabled)
JuiceLogger.log_capture(self, _get_domain_tag(), 
    "To.position", _to_position, debug_enabled)
```

## Pattern: Category 3 — Delta Reporting

Use inside `_apply_effect()`. Keep the line compact — it fires every frame.

```gdscript
# In a Transform effect _apply_effect():
func _apply_effect(progress: float, target: Node) -> void:
    # ... compute delta_position, delta_rotation, delta_scale ...
    
    JuiceLogger.log_delta(self, _get_domain_tag(), progress,
        {"pos": delta_position, "rot": delta_rotation, "scale": delta_scale},
        target.name, debug_enabled)

# In a Shake effect _apply_effect():
func _apply_effect(progress: float, target: Node) -> void:
    # ... compute shake_offset, decay ...
    
    JuiceLogger.log_delta(self, _get_domain_tag(), progress,
        {"offset": shake_offset, "decay": decay},
        target.name, debug_enabled)
```

## Pattern: Category 4 — Shader Diagnostics

Use in Appearance effects when setting material uniforms.

```gdscript
# When setting a shader uniform:
if material != null and material is ShaderMaterial:
    var shader := material.shader
    if shader != null:
        material.set_shader_parameter(uniform_name, value)
        JuiceLogger.log_shader(self, _get_domain_tag(),
            uniform_name, value, 
            "rid=%s" % material.get_rid(),
            debug_enabled)
    else:
        JuiceLogger.warn(self, _get_domain_tag(),
            "Shader is null on material %s" % material.get_rid(),
            debug_enabled)
```

## Pattern: Category 5 — Aggregation Summary

Use in domain node `_post_tick_write()`.

```gdscript
# In JuiceControl._post_tick_write():
JuiceLogger.log_aggregation("Control", target.name, "position",
    _base_position, total_pos_delta, target.position, debug_enabled)
JuiceLogger.log_aggregation("Control", target.name, "scale",
    _base_scale, total_scale_delta, target.scale, debug_enabled)
```

## Pattern: Category 6 — Domain Guardrails

Use in recipe validation or JuiceBase._ready(). No debug_flag — always warn.

```gdscript
# In JuiceBase._ready() or recipe validation:
if effect is Juice2DEffectBase and not (_target_node is Node2D):
    JuiceLogger.warn_domain_mismatch(
        effect.get_script().get_global_name(),
        "Node2D", _target_node.get_class())
```

## Pattern: Audit Checklist

When reviewing existing `if debug_enabled: print(...)` calls:

1. **Read the print**: What information does it convey?
2. **Classify**: Which of the 6 categories does it belong to?
3. **Evaluate**: Would this help diagnose a bug in the wild?
   - YES → Convert to appropriate `JuiceLogger` method
   - NO → Remove it (dev leftover)
4. **Convert**: Replace with the matching template pattern above
5. **Verify**: Run the file in editor, confirm no syntax errors

## _get_domain_tag() Virtual Method

Every domain effect base must override this:

```gdscript
# In JuiceControlEffectBase:
func _get_domain_tag() -> String: return "Control"

# In Juice2DEffectBase:
func _get_domain_tag() -> String: return "2D"

# In Juice3DEffectBase:
func _get_domain_tag() -> String: return "3D"

# In JuiceEffectBase (fallback):
func _get_domain_tag() -> String: return "Base"
```

For Node-based classes (JuiceBase, domain nodes), the domain tag is determined by the class type directly in the log call.
