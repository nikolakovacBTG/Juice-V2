# Appearance Effects — Phase D: Test Suite Plan

> Companion to the Architecture Plan (Phases A–C).
> File: `tests/suites/TestAppearanceEffects.gd` (full replacement of current file).

---

## Test Rig Helpers

### 2D rig (unchanged in structure, extended for stacking)
```gdscript
func _create_2d_rig(effects: Array, duration: float = 0.2) -> Array:
    # Target, single Juice2D with recipe containing all effects
    # Returns [target, juice]
func _create_2d_sibling_rig(effect_a: Juice2DEffectBase, effect_b: Juice2DEffectBase) -> Array:
    # Target, two sibling Juice2D nodes each with one effect
    # Returns [target, juice_a, juice_b]
```

### Control rig — CONTAINER-AWARE (replaces all existing Control rigs)
```gdscript
func _create_container_ctrl_rig(effects: Array, duration: float = 0.2) -> Array:
    var canvas_layer := CanvasLayer.new()
    _runner.add_child(canvas_layer)
    var vbox := VBoxContainer.new()
    vbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    canvas_layer.add_child(vbox)
    var btn := Button.new()
    btn.text = "Test Button"
    btn.custom_minimum_size = Vector2(120, 40)
    vbox.add_child(btn)
    # Add JuiceControl as child of btn
    var juice := JuiceControl.new()
    juice.trigger_on = JuiceBase.TriggerEvent.MANUAL
    var recipe := JuiceControlRecipe.new()
    for eff in effects:
        recipe.effects.append(eff)
    juice.recipe = recipe
    btn.add_child(juice)
    await wait_frames(3)  # Container layout pass
    return [btn, juice, canvas_layer]  # cleanup must free canvas_layer

func _create_container_sibling_ctrl_rig(eff_a, eff_b) -> Array:
    # Two sibling JuiceControl nodes inside same Button, same Container
```

### 3D rig
```gdscript
func _create_3d_rig(effects: Array, duration: float = 0.2) -> Array:
    # Node3D + MeshInstance3D(BoxMesh) + StandardMaterial3D
    # Returns [target, juice, mesh_inst]
func _create_3d_sibling_rig(eff_a, eff_b) -> Array:
```

---

## Full Test Method List

### 2D — FADE
```
test_2d_fade_animate_in_changes_alpha
test_2d_fade_restores_after_stop
test_2d_fade_from_custom_to_custom
test_2d_fade_from_self_to_custom
test_2d_fade_from_custom_to_self
test_2d_fade_animate_out_restores_toward_from
```

### 2D — TINT
```
test_2d_tint_animate_in_changes_rgb
test_2d_tint_restores_after_stop
test_2d_tint_from_custom_blend_to_custom_blend
test_2d_tint_from_self_to_custom
test_2d_tint_blend_zero_is_identity
test_2d_tint_blend_one_is_full_color
```

### 2D — OVERBRIGHT
```
test_2d_overbright_modulate_exceeds_one
test_2d_overbright_restores_after_stop
test_2d_overbright_from_1_to_2
test_2d_overbright_from_2_to_1_decreases
test_2d_overbright_from_self
```

### 2D — OUTLINE
```
test_2d_outline_installs_shader_material
test_2d_outline_restores_material_after_stop
test_2d_outline_from_zero_to_width_animates
test_2d_outline_from_width_to_zero_animates
test_2d_outline_color_is_set
test_2d_outline_conflict_warning_two_outlines_same_recipe
test_2d_outline_conflict_warning_sibling_juice_nodes
```

### 2D — STACKING (same recipe)
```
test_2d_overbright_plus_outline_both_apply
test_2d_fade_plus_tint_both_apply
test_2d_fade_plus_overbright_both_apply
test_2d_tint_plus_outline_tint_visible_through_outline
```

### 2D — STACKING (sibling Juice nodes)
```
test_2d_sibling_fade_nodes_both_contribute_to_alpha
test_2d_sibling_tint_nodes_factors_multiply
test_2d_sibling_overbright_nodes_boost_stacks
test_2d_sibling_first_stops_second_continues_clean
test_2d_sibling_outline_second_skips_with_warning
```

### 2D — FLICKER
```
test_2d_flicker_random_varies_tint_output (verify factor != constant over 0.5s)
test_2d_flicker_random_varies_fade_output
test_2d_flicker_random_varies_overbright_output
test_2d_flicker_outline_width_varies
test_2d_flicker_outline_color_alpha_varies
test_2d_flicker_outline_color_full_varies
test_2d_flicker_hard_flicker_is_binary (only 0 or 1 observed)
test_2d_flicker_scales_with_progress (at progress=0 flicker has no effect)
```

### 2D — STOP/RESTART
```
test_2d_stop_then_reanimate_clean_state
test_2d_stop_mid_animation_restores
```

---

### Control (container-aware rig) — FADE
```
test_ctrl_fade_animate_in_changes_alpha
test_ctrl_fade_restores_after_stop
test_ctrl_fade_from_self_captures_effective_modulate
test_ctrl_fade_writes_self_modulate_not_modulate
test_ctrl_fade_stop_clears_self_modulate_override
test_ctrl_fade_in_dimmed_container_respects_parent
```

### Control — TINT
```
test_ctrl_tint_animate_in_changes_rgb
test_ctrl_tint_restores_after_stop
test_ctrl_tint_from_self_to_custom
test_ctrl_tint_blend_zero_is_identity
```

### Control — OVERBRIGHT
```
test_ctrl_overbright_modulate_exceeds_one
test_ctrl_overbright_restores_after_stop
test_ctrl_overbright_from_1_to_2
```

### Control — OUTLINE
```
test_ctrl_outline_installs_shader_material
test_ctrl_outline_restores_material_after_stop
test_ctrl_outline_from_zero_to_width
test_ctrl_outline_conflict_warning
```

### Control — STACKING
```
test_ctrl_fade_plus_tint_stack_same_recipe
test_ctrl_sibling_juice_nodes_fade_stack
test_ctrl_sibling_juice_nodes_tint_stack
test_ctrl_sibling_first_stops_second_continues_clean
```

### Control — FLICKER
```
test_ctrl_flicker_random_varies_fade_output
test_ctrl_flicker_random_varies_tint_output
test_ctrl_flicker_outline_width_varies
test_ctrl_flicker_scales_with_progress
```

---

### 3D — FADE
```
test_3d_fade_changes_material_alpha
test_3d_fade_restores_after_stop
test_3d_fade_from_custom_to_custom
test_3d_fade_from_self_to_custom
```

### 3D — TINT
```
test_3d_tint_changes_albedo
test_3d_tint_restores_after_stop
test_3d_tint_from_self_to_custom
test_3d_tint_blend_zero_is_identity
```

### 3D — OVERBRIGHT
```
test_3d_overbright_albedo_exceeds_one
test_3d_overbright_increases_with_progress
test_3d_overbright_restores_after_stop
test_3d_overbright_from_1_to_3
test_3d_overbright_config_warning_on_incompatible_renderer  (mock renderer method = "gl_compatibility")
```

### 3D — OUTLINE (implementation via `next_pass` on working material, using `overlay_3d.gdshader`)
```
test_3d_outline_installs_shader_material_on_mesh
test_3d_outline_restores_material_after_stop
test_3d_outline_from_zero_to_width_animates
test_3d_outline_from_width_to_zero_animates
test_3d_outline_color_is_set
test_3d_outline_next_pass_installed_on_working_material
test_3d_outline_sibling_nodes_chain_next_pass
```

### 3D — STACKING
```
test_3d_fade_plus_tint_both_apply_to_working_material
test_3d_fade_plus_overbright
test_3d_sibling_juice_nodes_tint_stack
test_3d_sibling_juice_nodes_fade_stack
test_3d_sibling_first_stops_second_continues
```

### 3D — FLICKER
```
test_3d_flicker_random_varies_tint_albedo
test_3d_flicker_random_varies_fade_alpha
test_3d_flicker_scales_with_progress
```

---

## Assertions Used Per Category

**Modulate color change**: `assert_true(target.modulate.r < 0.9)` — directional check, not equal  
**Modulate restored**: `assert_approx_float(target.modulate.a, 1.0, ...)` — exact restore  
**Material installed**: `assert_true(target.material is ShaderMaterial)`  
**Material restored**: `assert_true(target.material == null)`  
**Flicker varies**: collect 10 samples over 0.5s, assert standard deviation > 0 (not constant)  
**Stacking**: activate two effects, assert both channels changed, assert neither alone explains the combined result  
**Sibling stacking**: after node A stops, assert node B's contribution persists  
**self_modulate written**: `assert_true(target.self_modulate != Color.WHITE)`  
**self_modulate cleared**: `assert_approx_float(target.self_modulate.a, 1.0, ...)`

---

## Runner Registration

Add to `JuiceTestRunner._register_suites()`:
```gdscript
suites.append(TestAppearanceEffects.new())
```

(Already registered — verify it runs with `--suite=appearance_effects`.)

---

## Notes

- All tests use `duration = 0.2s` for fast execution except flicker variance tests which need `0.5s` to observe oscillation.
- All tests use `trigger_behaviour = PLAY_IN_ONLY` to keep control simple.
- Container rig cleanup sequence: `canvas_layer.queue_free()` (frees the whole tree including btn and juice).
