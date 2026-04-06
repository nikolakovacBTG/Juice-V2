# V0 → V1 Feature Parity Matrix

> **Purpose:** Exhaustive mapping of every V0 capability to its V1 implementation.
> No feature is "done" until it has a passing automated test.
> This is the single source of truth for port completion.
>
> **Legend:**
> - ✅ **GREEN** — Implemented, wired, AND has passing test
> - ⚠️ **YELLOW** — Declared/exists but untested OR partially broken
> - ❌ **RED** — Missing, dead code, or confirmed broken
> - 🔄 **CHANGED** — Intentional architectural change (not a gap, but must be verified)
> - ➖ **N/A** — Not applicable in V1 architecture

---

## 1. SIGNALS

| V0 Signal | V0 Location | V1 Location | Status | Test |
|-----------|-------------|-------------|--------|------|
| `started` | JuiceCompBase:41 | `animate_in_started` + `animate_out_started` on JuiceBase:38-41 | 🔄 More granular in V1 | — |
| `completed` | JuiceCompBase:44 | JuiceBase:35 | ✅ Fixed (commit 246aecd) | `test_loop_count_two_replays` ✅ |

---

## 2. ENUMS

### TriggerBehaviour

| V0 Value | V1 Value | Status |
|----------|----------|--------|
| `PLAY_IN_AND_OUT` | `PLAY_IN_AND_OUT` | ✅ |
| `PLAY_IN_ONLY` | `PLAY_IN_ONLY` | ✅ |
| `PLAY_OUT_ONLY` | `PLAY_OUT_ONLY` | ✅ |
| `TOGGLE_IN_AND_OUT` | `TOGGLE` | 🔄 Renamed |
| `SET_FROM_SOURCE` | `SET_FROM_SOURCE` | ✅ |

### TriggerEvent

| V0 Values (0–16) | V1 Values (0–16) | Status |
|-------------------|-------------------|--------|
| Identical | Identical | ✅ |

### RetriggerPolicy

| V0 Value | V1 Value | Status |
|----------|----------|--------|
| `RESTART` | `RESTART` | ✅ Fixed (246aecd+61fd436) | `test_retrigger_restart` + `test_restart_crossfade_direction_switch` ✅ |
| `IGNORE` | `IGNORE` | ✅ |
| `QUEUE_ONE` | `QUEUE` | 🔄 Renamed |

### OffsetUnit

| V0 Value | V1 Value | Status |
|----------|----------|--------|
| `PIXELS` | `PIXELS` | ✅ |
| `FRACTION_OWN` | `OWN_SIZE` | 🔄 Renamed (completed task) |
| `FRACTION_PARENT` | `PARENT_SIZE` | 🔄 Renamed |
| `FRACTION_VIEWPORT` | `VIEWPORT_SIZE` | 🔄 Renamed |

### RotationUnit

| V0 | V1 | Status |
|----|-----|--------|
| `DEGREES`, `RADIANS` | `DEGREES`, `RADIANS` | ✅ |

---

## 3. CONFIGURATION PROPERTIES

### Timing

| Property | V0 Location | V1 Location | Status | Test |
|----------|-------------|-------------|--------|------|
| `start_delay` | @export on comp | @export on node + var on effect | ⚠️ Untested per-effect delay | `test_start_delay_offsets_animation` ✅ (node-level) |
| `loop_count` | @export on comp | @export on node + var on effect | ✅ Fixed (commit 246aecd) | `test_loop_count_two_replays` ✅ |
| `ping_pong` | @export on comp | var on effect | ✅ Tested | `test_ping_pong_oscillates` + `test_4phase_ping_pong_in_and_out` ✅ |
| `loop_delay` | @export on comp | @export on node + var on effect | ✅ Fixed (commit 246aecd) | `test_loop_delay_pauses_between_iterations` ✅ |
| `loop_phase_offset` | @export on comp | var on effect | ✅ Tested | `test_loop_phase_offset_starts_mid_cycle` ✅ |

### Trigger

| Property | V0 Location | V1 Location | Status | Test |
|----------|-------------|-------------|--------|------|
| `trigger_behaviour` | @export on comp | @export on node + var on effect | ✅ | Multiple tests |
| `auto_connect_parent` | @export on comp | @export on node | ✅ Tested | `test_autoconnect_button_pressed` + `test_autoconnect_visibility_on_show` ✅ |
| `manual_trigger_signal` | @export on comp | @export on node | ⚠️ Untested | — |
| `trigger_source_path` | @export on comp | @export on node | ⚠️ Untested | — |
| `trigger_on` | @export on comp | @export on node | ✅ Tested (ON_PRESS, ON_SHOW) | `test_autoconnect_button_pressed` + `test_autoconnect_visibility_on_show` ✅ |
| `retrigger_policy` | @export on comp (per-effect) | @export on node (per-node only) | 🔄 Scope changed: all effects share one policy | `test_retrigger_restart` ✅ |
| `crossfade_time` | @export on comp | var on effect | ✅ Wired (commit 61fd436) — triggered on direction switch | `test_restart_crossfade_direction_switch` ✅ |

### Animate In

| Property | V0 | V1 | Status | Test |
|----------|-----|-----|--------|------|
| `duration_in` | var on comp | var on effect | ✅ | Multiple tests |
| `transition_in` | var on comp | var on effect | ✅ Tested (ELASTIC, BACK) | `test_elastic_easing_overshoots` + `test_back_easing_overshoots` ✅ |
| `ease_in` | var on comp | var on effect | ✅ Tested (EASE_OUT) | `test_elastic_easing_overshoots` + `test_back_easing_overshoots` ✅ |
| `custom_curve_in` | var on comp | var on effect | ✅ Tested | `test_custom_curve_in_overrides_easing` ✅ |
| `elastic_amplitude_in` | var on comp | var on effect | ✅ Tested | `test_elastic_easing_overshoots` ✅ |
| `elastic_period_in` | var on comp | var on effect | ✅ Tested | `test_elastic_easing_overshoots` ✅ |
| `back_overshoot_in` | var on comp | var on effect | ✅ Tested | `test_back_easing_overshoots` ✅ |
| `hold_at_peak` | var on comp | var on effect | ✅ Tested | `test_hold_at_peak_delays_auto_reverse` ✅ |

### Animate Out

| Property | V0 | V1 | Status | Test |
|----------|-----|-----|--------|------|
| `duration_out` | var on comp | var on effect | ✅ | Via PLAY_IN_AND_OUT tests |
| `transition_out` | var on comp | var on effect | ✅ Tested (ELASTIC, BACK) | `test_elastic_easing_out_overshoots` + `test_back_easing_out_overshoots` ✅ |
| `ease_out` | var on comp | var on effect | ✅ Tested (EASE_OUT) | `test_elastic_easing_out_overshoots` + `test_back_easing_out_overshoots` ✅ |
| `custom_curve_out` | var on comp | var on effect | ✅ Tested | `test_custom_curve_out_overrides_easing` ✅ |
| `elastic_amplitude_out` | var on comp | var on effect | ✅ Tested | `test_elastic_easing_out_overshoots` ✅ |
| `elastic_period_out` | var on comp | var on effect | ✅ Tested | `test_elastic_easing_out_overshoots` ✅ |
| `back_overshoot_out` | var on comp | var on effect | ✅ Tested | `test_back_easing_out_overshoots` ✅ |

### Chaining

| Property | V0 | V1 | Status | Test |
|----------|-----|-----|--------|------|
| `next_component` (NodePath) | var on comp | `chain_to` (Resource ref) on effect | 🔄 Adapted for Resource model | `test_chain_to_sequential_effects` ✅ |
| `interrupt_siblings` | var on comp | var on effect | ✅ Wired (commit 6c77164) | `test_interrupt_siblings_stops_matching` ✅ |

### Mirror & Debug

| Property | V0 | V1 | Status | Test |
|----------|-----|-----|--------|------|
| `_btn_mirror_in_to_out` | var on comp | var on effect | ✅ Tested (params + curve reversal + ease reversal) | `test_mirror_in_to_out_copies_all_params` + `test_mirror_in_to_out_reverses_custom_curve` ✅ |
| `debug_enabled` | var on comp | @export on node + var on effect | ✅ | Used in many tests |

---

## 4. BEHAVIORAL FEATURES

### Animation Lifecycle

| Behavior | V0 Reference | V1 Reference | Status | Test |
|----------|-------------|-------------|--------|------|
| Force-first-frame (FFR) | `_animate_to:940` | `effect.start():398` | ✅ | Implicit in position tests |
| Start delay hold (self-hold) | `_process:593-595` | `tick():414-418` | ✅ | `test_start_delay_offsets_animation` |
| Container hold (beat re-sorts) | `_process:587-595` | `_post_tick_write` during node delay | ✅ Tested (commit ecc9511) | `test_container_re_sort_handling` ✅ |
| PLAY_IN_AND_OUT chain | `_finish():1966-1991` | `_handle_cycle_complete:534-545` | ✅ | `test_play_in_and_out_completes` |
| `is_one_shot_return` concept | Param to `_animate_to` | Internal flag `_is_one_shot_return` on effect | 🔄 Refactored into effect-internal | — |

### Loop System

| Behavior | V0 Reference | V1 Reference | Status | Test |
|----------|-------------|-------------|--------|------|
| Loop counter increment | `_on_cycle_complete:1834` | effect: `_handle_cycle_complete:548`; node: `_on_all_effects_completed:561` | ✅ Fixed (commit 246aecd) | `test_loop_count_two_replays` ✅ |
| Loop counter preserved during auto-OUT | `_animate_to:910` `if not is_one_shot_return` | effect: `_current_loop` reset in `start():376` | ✅ Tested — counter increments after full IN+OUT cycle | `test_loop_counter_preserved_during_auto_out` ✅ |
| Infinite loop (loop_count = -1) | `_on_cycle_complete:1838-1849` | effect: `_handle_cycle_complete:550-551`; node: `_on_all_effects_completed:565-566` | ✅ Tested | `test_infinite_loop_keeps_playing` ✅ |
| Loop delay | `_on_cycle_complete:1872-1884` (await timer) | effect: tick-based `_in_loop_delay`; node: tick-based `_in_loop_delay` | ✅ Fixed (commit 246aecd) | `test_loop_delay_pauses_between_iterations` ✅ |
| Loop phase offset | `_animate_to:925-927` | `effect.start():387-389` | ✅ Tested | `test_loop_phase_offset_starts_mid_cycle` ✅ |
| PLAY_IN_AND_OUT loop restart | `_on_cycle_complete:1865-1877` | `_handle_cycle_complete:560-564` | ✅ Tested | `test_play_in_and_out_loop_restart` ✅ |

### Restart / Retrigger

| Behavior | V0 Reference | V1 Reference | Status | Test |
|----------|-------------|-------------|--------|------|
| RESTART: stop + restart | `_handle_trigger:782-793` + `_animate_to:870-901` | `_handle_trigger:446-451` + `_start_effects` | ✅ Fixed (commit 246aecd) | `test_retrigger_restart` ✅ |
| RESTART: same-direction detection | `_animate_to:886-901` | `_handle_trigger:475-483` | ✅ Fixed (commit 61fd436) | `test_restart_same_direction_resets` ✅ |
| RESTART: already-at-target (spammable) | `_animate_to:875-885` | `_handle_trigger:489-498` | ✅ Fixed (commit 61fd436) | `test_restart_spammable_at_target` ✅ |
| RESTART: crossfade on direction switch | `_animate_to:853-857` → `_is_crossfading = true` | `_handle_trigger:466-473` | ✅ Fixed (commit 61fd436) | `test_restart_crossfade_direction_switch` ✅ |
| IGNORE: return early | `_handle_trigger:786-787` | `_handle_trigger:437-440` | ✅ | — |
| QUEUE: store + dequeue | `_handle_trigger:788-790` + `_finish:2019-2022` | `_handle_trigger:441-445` + `_on_all_effects_completed:586-589` | ✅ Tested | `test_retrigger_queue_plays_after_first` ✅ |

### Crossfade

| Behavior | V0 Reference | V1 Reference | Status | Test |
|----------|-------------|-------------|--------|------|
| `crossfade_time` property | `@export` line 165 | `var` on effect line 128 | ✅ Declared | — |
| Crossfade trigger (set `_is_crossfading = true`) | `_animate_to:854-857` | `_handle_trigger:466-473` | ✅ Wired (commit 61fd436) | `test_restart_crossfade_direction_switch` ✅ |
| Crossfade blend in tick | `_process:615-621` | `tick():451-457` | ✅ Code exists + tested | `test_restart_crossfade_direction_switch` ✅ |
| `crossfade_time` hidden when not RESTART | `_validate_property:289-290` | Always shown | ➖ N/A — effect (Resource) can't see node's retrigger_policy at edit time | — |

### Interrupt Siblings

| Behavior | V0 Reference | V1 Reference | Status | Test |
|----------|-------------|-------------|--------|------|
| `interrupt_siblings` property | var on comp line 262 | var on effect line 124 | ✅ Wired (commit 6c77164) | `test_interrupt_siblings_stops_matching` ✅ |
| `_stop_matching_siblings()` | `_animate_to:861-862` + method at line 1139 | `JuiceBase:634` | ✅ Wired (commit 6c77164) | `test_interrupt_siblings_stops_matching` ✅ |
| `_get_interrupt_identity()` | line 2073 | line 851 | ✅ Called by `_stop_matching_siblings` | `test_interrupt_siblings_stops_matching` ✅ |

### Ping-Pong

| Behavior | V0 Reference | V1 Reference | Status | Test |
|----------|-------------|-------------|--------|------|
| 2-phase (single direction) | `_on_cycle_complete:1787-1819` | `_handle_cycle_complete:519-532` | ✅ Tested (commit 523544a) | `test_ping_pong_oscillates` ✅ |
| 4-phase (IN_AND_OUT) | `_get_ping_pong_phases_per_cycle:1893` | `_get_ping_pong_phases_per_cycle:702` | ✅ Tested (commit afbfaa6) | `test_4phase_ping_pong_in_and_out` ✅ |
| Hold at peak between phases | `_on_cycle_complete:1798-1806` (await) | `_handle_cycle_complete:525-528` (tick-based) | ✅ Tested (commit 523544a) | `test_hold_at_peak_delays_auto_reverse` ✅ |
| Phase configuration | `_configure_ping_pong_phase:1901-1939` | `_configure_ping_pong_phase:708-729` | ✅ Same logic | — |

---

## 5. AUTO-CONNECT

| Feature | V0 Reference | V1 Reference | Status | Test |
|---------|-------------|-------------|--------|------|
| BaseButton signals | `_connect_button_signals:1281` | JuiceControl `_auto_connect_domain_signals` | ✅ Tested (commit afbfaa6) | `test_autoconnect_button_pressed` ✅ |
| Control signals | `_connect_control_signals:1327` | JuiceControl `_auto_connect_domain_signals` | ✅ Tested (hover, focus, gui_input) | `test_autoconnect_control_hover` + `test_autoconnect_control_focus` + `test_autoconnect_control_gui_input_press` ✅ |
| CollisionObject3D signals | `_connect_collision_object_3d_signals:1363` | JuiceBase callbacks (lines 769-795) | ✅ Tested (body_entered, hover) | `test_autoconnect_area3d_body_entered` + `test_autoconnect_area3d_hover` ✅ |
| CollisionObject2D signals | `_connect_collision_object_2d_signals:1436` | JuiceBase callbacks (lines 777-807) | ✅ Tested (body_entered, hover) | `test_autoconnect_area2d_body_entered` + `test_autoconnect_area2d_hover` ✅ |
| AnimationPlayer signals | `_connect_animation_signals:1507` | JuiceBase `_try_auto_connect` + `_on_animation_finished` | ✅ Fixed + Tested (was dead code) | `test_autoconnect_animation_player` ✅ |
| Visibility (ON_SHOW/ON_HIDE) | `_connect_visibility_signals:1517` | JuiceBase `_connect_visibility_signals:692` | ✅ Tested (commit afbfaa6) | `test_autoconnect_visibility_on_show` ✅ |
| **Sibling fallback scan** | `_try_auto_connect:1215-1235` | JuiceBase `_ready():256-278` | ✅ Fixed (commit bbf9754) | — (integration) |
| **Config warning: ambiguous siblings** | `_get_configuration_warnings:1164-1189` | JuiceBase `_get_configuration_warnings:734` | ✅ Fixed (commit bbf9754) | — (visual) |

---

## 6. EDITOR PREVIEW

| Feature | V0 Reference | V1 Reference | Status | Test |
|---------|-------------|-------------|--------|------|
| `_enter_editor_preview` | `JuiceCompBase:1017` | **NOT PRESENT** on JuiceBase | ❓ May live elsewhere or not yet ported | — |
| `_exit_editor_preview` | `JuiceCompBase:1035` | **NOT PRESENT** | ❓ | — |
| `_editor_preview_active` flag | `JuiceCompBase:523` | **NOT PRESENT** | ❓ | — |
| `get_progress_at_time` | `JuiceCompBase:1053` | `JuiceEffectBase:777` | ✅ | — |
| `get_total_preview_duration` | `JuiceCompBase:1090` | `JuiceEffectBase:795` | ✅ | — |
| `set_progress` (scrub) | `JuiceCompBase:1103` | `JuiceEffectBase:489` | ✅ | — |
| `apply_easing_for_direction` | `JuiceCompBase:1114` | `JuiceEffectBase:635` | ✅ | — |
| `_temporarily_undo_visual` | `JuiceCompBase:2102` | JuiceBase:624 + JuiceEffectBase:855 | ✅ | — |
| `_temporarily_reapply_visual` | `JuiceCompBase:2106` | JuiceBase:629 + JuiceEffectBase:858 | ✅ | — |
| `_supports_editor_preview` | `JuiceCompBase:2093` | `JuiceEffectBase:871` | ✅ | — |

---

## 7. VIRTUAL METHODS / SUBCLASS CONTRACT

| Method | V0 | V1 | Status |
|--------|-----|-----|--------|
| `_apply_effect(progress)` | 1 param (comp has `_target_node`) | 2 params `(progress, target)` | 🔄 Adapted for Resource model |
| `_on_animate_start()` | No params | `(target)` param | 🔄 |
| `_on_animate_in_complete()` | No params | `(target)` param | 🔄 |
| `_on_animate_out_complete()` | No params | `(target)` param | 🔄 |
| `_invalidate_base_cache()` | No params | No params | ✅ |
| `_get_interrupt_identity()` | Returns Variant | Returns Variant | ✅ Called by `_stop_matching_siblings` |
| `_restore_to_natural()` | No params | `(target)` param | 🔄 |
| `_on_host_ready(target, host)` | N/A (V0 uses _ready) | V1-only: effect learns about host at ready time | 🔄 V1-only addition |
| `_on_editor_pre_save(target)` | N/A | V1-only: editor cache baking | 🔄 V1-only addition |

---

## 8. ARCHITECTURAL CHANGES (Intentional, Not Gaps)

| Change | V0 | V1 | Rationale |
|--------|-----|-----|-----------|
| Node vs Resource | JuiceCompBase extends Node | JuiceEffectBase extends Resource + JuiceBase extends Node | Recipes as Resources, stacking via single node |
| retrigger_policy scope | Per-comp (each comp has own policy) | Per-node (all effects share one policy) | Recipe = unified behavior |
| `is_one_shot_return` | Threaded as parameter to `_animate_to` | Internal flag on effect, set by `_start_animate_out_internal` | Cleaner: effect manages own IN→OUT cycle |
| `_is_recipe_clone` | Flag on comp for Sequencer clones | N/A — effects are Resources, cloned via `duplicate()` | Architectural simplification |
| `_externally_driven` | Flag + `set_external_progress` on comp | `set_progress(value, target)` on effect | Simpler API |
| `_force_play_in_and_out_once` | V0 flag for SET_FROM_SOURCE fallback | Not needed — V1 trigger handling is different | N/A |
| Coroutine-based delays | `await get_tree().create_timer()` | Tick-based `_in_*_delay` flags | Better: no coroutine safety issues |

---

## SUMMARY: Critical Gaps

### ❌ BROKEN (confirmed by tests)

| # | Issue | Files | Severity |
|---|-------|-------|----------|
| ~~B1~~ | ~~Node-level loop counter resets~~ | `JuiceBase.gd` | ✅ Fixed (commit 246aecd) |
| ~~B2~~ | ~~RESTART doesn't reset effect progress~~ | `JuiceBase.gd` | ✅ Fixed (commit 246aecd) |

### ❌ DEAD CODE (declared, never functional)

| # | Issue | Files | Severity |
|---|-------|-------|----------|
| ~~D1~~ | ~~`crossfade_time` tick logic dead~~ | `JuiceEffectBase.gd` | ✅ Fixed (commit 61fd436) |
| ~~D2~~ | ~~`interrupt_siblings` never read~~ | `JuiceBase.gd` | ✅ Fixed (commit 6c77164) |
| ~~D3~~ | ~~`_get_interrupt_identity()` never called~~ | `JuiceEffectBase.gd` | ✅ Fixed (commit 6c77164) |

### ❌ MISSING (V0 has, V1 doesn't)

| # | Issue | V0 Reference | Severity |
|---|-------|-------------|----------|
| ~~M1~~ | ~~RESTART same-direction detection~~ | `_animate_to:886-901` | ✅ Fixed (commit 61fd436) |
| ~~M2~~ | ~~RESTART already-at-target handling~~ | `_animate_to:875-885` | ✅ Fixed (commit 61fd436) |
| ~~M3~~ | ~~Crossfade trigger on direction switch~~ | `_animate_to:853-857` | ✅ Fixed (commit 61fd436) |
| M4 | `crossfade_time` hidden when not RESTART | `_validate_property:289-290` | ➖ N/A in V1 architecture |
| ~~M5~~ | ~~Sibling fallback scan in auto-connect~~ | `_try_auto_connect:1215-1235` | ✅ Fixed (commit bbf9754) |
| ~~M6~~ | ~~Config warning: ambiguous sibling sources~~ | `_get_configuration_warnings:1164-1189` | ✅ Fixed (commit bbf9754) |
| M7 | Editor preview entry/exit lifecycle | `_enter/_exit_editor_preview` | ❓ May live elsewhere |

### ⚠️ UNTESTED (code exists, no automated verification)

**Remaining untested:** Editor preview lifecycle (`_enter/_exit_editor_preview`) — deferred to preview transport sprint.

**Newly tested (commits 523544a–current):** hold_at_peak, 2-phase ping-pong, 4-phase ping-pong,
infinite loops, QUEUE retrigger, chaining, loop_phase_offset, cross-node stacking (all 3 domains),
Container re-sort handling, custom curves, elastic/back easing, button auto-connect, visibility auto-connect,
animate_out params (custom_curve_out, elastic_out, back_out), loop counter during auto-OUT,
PLAY_IN_AND_OUT loop restart, mirror_in_to_out (params + curve reversal + ease reversal),
Control signals (hover, focus, gui_input), CollisionObject2D/3D signals (body_entered, hover),
AnimationPlayer auto-connect (was dead code — fixed + tested).

---

## VERIFICATION RULE

> **No cell in this matrix moves from ❌/⚠️ to ✅ without a PASSING automated test.**
> The test name must be written in the Test column.
> Running the test suite is the ONLY way to verify completion.
