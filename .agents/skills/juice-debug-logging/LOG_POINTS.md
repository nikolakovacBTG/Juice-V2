# Log Points Reference

Where to insert logging calls for each class layer in the Juice stack.

## Base Classes

### JuiceBase.gd (Orchestrator Node)

| Method | Category | What to Log |
|--------|----------|-------------|
| `_ready()` / `_post_ready_init()` | 1-Info | Target resolved, trigger source resolved, recipe cloned |
| `_handle_trigger()` | 1-Info | Trigger direction, behaviour resolution, retrigger policy result |
| `_start_effects()` | 1-Info | How many effects started, play direction |
| `_on_effect_completed()` | 1-Info | Which effect finished, chaining info |
| `_on_all_effects_completed()` | 1-Info | Full recipe cycle complete, loop iteration |
| `stop()` | 1-Info | Explicit stop called |
| `set_external_progress()` | 1-Info | External value received |

### JuiceEffectBase.gd (Effect Resource Base)

| Method | Category | What to Log |
|--------|----------|-------------|
| `start()` | 1-Info | Effect name, target, direction, crossfade state |
| `tick()` | 3-Delta | Progress value + eased progress (only when interesting, see Templates) |
| `_on_animate_start()` | 2-Capture | From/To snapshot values |
| `_apply_effect()` | 3-Delta | Computed delta (subclass responsibility) |
| `_restore_to_natural()` | 1-Info | Reset to natural state |
| `stop()` | 1-Info | Effect stopped |

### Domain Nodes (JuiceControl, Juice2D, Juice3D)

| Method | Category | What to Log |
|--------|----------|-------------|
| `_capture_base_values()` | 2-Capture | `"Captured base: pos=%s rot=%s scale=%s"` |
| `_pre_tick()` | 5-Aggregation | External move detected: `"pos shifted from %s to %s"` (only when drift detected) |
| `_post_tick_write()` | 5-Aggregation | `"Write: base=%s + delta=%s → final=%s"` per channel |
| `_temporarily_undo_visual()` | 1-Info | When visual undo happens (for editor save) |

### JuiceLedger.gd

| Method | Category | What to Log |
|--------|----------|-------------|
| `register_delta()` | 5-Aggregation | Source + channel + delta value |
| `flush()` / `get_total_delta()` | 5-Aggregation | Final summed delta per channel |

---

## Effects (Concrete Classes)

### Transform Effects (Control/2D/3D)

| Method | Category | What to Log |
|--------|----------|-------------|
| `_on_animate_start()` | 2-Capture | From/To position, rotation, scale |
| `_apply_effect()` | 3-Delta | `"progress=%.3f pos_delta=%s rot_delta=%.3f scale_delta=%s"` |

### Shake Effects (Control/2D/3D)

| Method | Category | What to Log |
|--------|----------|-------------|
| `_apply_effect()` | 3-Delta | `"progress=%.3f shake_offset=%s decay=%.3f"` |

### Noise Effects (Control/2D/3D)

| Method | Category | What to Log |
|--------|----------|-------------|
| `_apply_effect()` | 3-Delta | `"progress=%.3f noise_sample=%s envelope=%.3f"` |

### Appearance Effects (Control/2D/3D)

| Method | Category | What to Log |
|--------|----------|-------------|
| `_on_animate_start()` | 2-Capture | Material RID, From/To modulate values |
| `_apply_effect()` | 3-Delta + 4-Shader | `"modulate_factor=%s"` + shader uniform checks |
| Shader uniform set | 4-Shader | `"Setting '%s' = %s on material %s"` — warn if uniform not found |

### Progress Effects (Control/2D/3D)

| Method | Category | What to Log |
|--------|----------|-------------|
| `_apply_effect()` | 3-Delta | `"progress=%.3f value_delta=%.3f"` |

### SquashStretch Effects (Control/2D/3D)

| Method | Category | What to Log |
|--------|----------|-------------|
| `_apply_effect()` | 3-Delta | `"progress=%.3f scale_delta=%s"` |

---

## Meta Effects (Property Family)

### InterpolatePropertyJuiceEffectBase

| Method | Category | What to Log |
|--------|----------|-------------|
| `_apply_effect()` | 3-Delta | `"property=%s progress=%.3f value=%s"` |

### NoisePropertyJuiceEffectBase

| Method | Category | What to Log |
|--------|----------|-------------|
| `_apply_effect()` | 3-Delta | `"property=%s noise_sample=%s envelope=%.3f"` |

### ShakePropertyJuiceEffectBase

| Method | Category | What to Log |
|--------|----------|-------------|
| `_apply_effect()` | 3-Delta | `"property=%s shake_offset=%s decay=%.3f"` |

---

## Utilities

### Interaction2D/3DJuiceUtility

| Method | Category | What to Log |
|--------|----------|-------------|
| Signal connection | 1-Info | `"Connected to %s.%s"` |
| Trigger forwarded | 1-Info | `"Forwarded trigger to %d Juice nodes"` |

### SoftTrigger (Control/2D/3D)

| Method | Category | What to Log |
|--------|----------|-------------|
| Threshold crossed | 1-Info | `"Threshold %.2f crossed, triggering %d nodes"` |
| Value update | 3-Delta | `"progress=%.3f value=%.3f"` |

### TimeCoordinatorJuiceUtility

| Method | Category | What to Log |
|--------|----------|-------------|
| Coordinator start | 1-Info | `"Coordinating %d nodes, stagger=%.2f"` |
| Node triggered | 1-Info | `"Triggered node %s at offset %.2f"` |

---

## Domain Guardrails (Category 6)

### JuiceRecipe.gd / JuiceBase._ready()

| Check | What to Log |
|-------|-------------|
| 2D effect on non-Node2D | `warn_domain_mismatch("Shake2DJuiceEffect", "Node2D", target.get_class())` |
| 3D effect on non-Node3D | `warn_domain_mismatch("Transform3DJuiceEffect", "Node3D", target.get_class())` |
| Control effect on non-Control | `warn_domain_mismatch("AppearanceControlJuiceEffect", "Control", target.get_class())` |
