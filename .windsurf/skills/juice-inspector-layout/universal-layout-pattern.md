# Universal Inspector Layout Pattern

All `JuiceEffectBase` subclasses must follow this exact top-to-bottom inspector layout to ensure a consistent designer experience.

## The 9-Step Hierarchy

```text
Effect                          # 1. Topmost group
├── [Main selector]             # Always visible (e.g., transform_target, appearance_effect)
├── [Core effect params]        # Most important settings (e.g., squash_amount)
├── trigger_behaviour           # Base properties from _get_effect_base_properties()
├── start_delay                 # Base properties
├── crossfade_time              # Base properties
├── loop_count                  # Base properties
│
[Effect-specific subgroups]     # 2. Meaningful subgroups for complex effects (e.g., Noise Pattern, Advanced)
├─ [Advanced settings...]
│
[From]                          # 3. Separate group (if the effect's nature allows it)
├─ from_reference: [Custom ▼]
├─ [from-specific params...]
│
[To]                            # 4. Separate group (if the effect's nature allows it)  
├─ to_reference: [Custom ▼]
├─ [to-specific params...]
│
Animate In                      # 5. Inherited from base
├─ duration, curve, easing, hold_at_peak
│
Animate Out                     # 6. Inherited from base (dynamically hidden when not used)
├─ duration, curve, easing...
│
Chaining                        # 7. Inherited from base
├─ chain_to, interrupt_siblings
│
Debug                           # 8. Inherited from base
├─ debug_enabled
│
Resource                        # 9. Inherited from Godot Resource
├─ resource_local_to_scene
```

## Implementation Rules

1. **Base Properties Placement**: The standard timing properties (`trigger_behaviour`, `start_delay`, `crossfade_time`, `loop_count`) are injected via `_get_effect_base_properties()`. They generally appear after the core effect parameters, they might precede effect-specific subgroups.
2. **Never Call Super**: NEVER call `super._get_property_list()`, `super._set()`, or `super._get()` from a subclass. Godot calls each script's methods independently and combines the results.
3. **Subgroup Naming**: Use semantic, descriptive names for effect-specific subgroups (e.g., `Noise Pattern`, `Settlement`). Do not dump everything into the main `Effect` group if the effect is complex.
