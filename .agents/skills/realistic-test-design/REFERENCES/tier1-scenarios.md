# Tier 1 — Headless Realistic Scenario Library

These scenarios model real developer workflows. Each maps to something a developer actually does in their project.

---

## Scenario Family A: "I'm setting up Juice for the first time on a new node"

| Test | What a developer does | What to assert |
|------|-----------------------|---------------|
| A1 — First-time setup | Add Juice2D to Node2D at non-zero position, assign a single Transform effect, call `animate_in()` | Target moves away from origin, returns to correct non-zero origin after completion |
| A2 — Wrong target | Assign Juice2D with no target set, call `animate_in()` | Fails gracefully, no crash, config warning present |
| A3 — Empty recipe | Assign Juice2D with recipe but no effects added, call `animate_in()` | Completes silently, target unchanged, no crash |

---

## Scenario Family B: "I'm stacking multiple effects on one target (single recipe)"

| Test | What a developer does | What to assert |
|------|-----------------------|---------------|
| B1 — Two tween effects | Assign Transform + SquashStretch to same recipe, `animate_in()` | Both deltas applied, target returns to exact origin (position AND scale) |
| B2 — Tween + procedural | Assign Transform + Shake, `PLAY_IN_ONLY` | Transform completes and stops, Shake sustains indefinitely, ledger tracks both sources |
| B3 — Three effects, one interruption | Three effects in recipe, call `stop()` mid-animation | All three effects restore target cleanly, no partial state |

---

## Scenario Family B2: "I have two separate Juice nodes on the same target, triggered independently"

This is the most important stacking family. It validates that the **ledger's delta aggregation** is correct when two orchestrators are writing to the same target simultaneously — from different sources, started at different times.

| Test | What a developer does | What to assert |
|------|-----------------------|---------------|
| B2a — Full overlap, same trigger | Juice_A and Juice_B both target Node2D. Trigger both `animate_in()` simultaneously. | Target displacement = sum of both deltas. Neither overwrites the other. Both restore correctly on completion. |
| B2b — Partial overlap (A first) | Trigger Juice_A. After 30% of A's duration, trigger Juice_B. | While both active: displacement = sum of both. When A completes: only B's delta remains. When B completes: target at exact natural position. |
| B2c — Partial overlap (B first) | Trigger Juice_B. After 50% of B's duration, trigger Juice_A. | Same correctness guarantee from B's perspective. |
| B2d — One stops early | Trigger both, then call `stop()` on Juice_A mid-animation. | Juice_B continues unaffected. A's contribution removed from ledger instantly. Target stays at B's delta offset only. |
| B2e — Different effect types | Juice_A has Transform (position), Juice_B has Shake (also position). Trigger simultaneously. | Tween offset and shake offset both applied — no channel conflict. Natural position preserved after both stop. |
| B2f — One is sustained, one is tween | Juice_A is Shake (`PLAY_IN_ONLY`), Juice_B is Transform tween. Trigger B, mid-flight trigger A. | B completes and stops, A sustains. After B completes: only shake delta visible. Stop A: target returns to exact origin. |
| B2g — Retrigger A while B active | Juice_A completes. While Juice_B still active, trigger Juice_A again (RESTART). | A restarts cleanly. B unaffected. Ledger tracks both source contributions independently. |

---

## Scenario Family C: "I'm building a UI with containers"

| Test | What a developer does | What to assert |
|------|-----------------------|---------------|
| C1 — Button in VBox | JuiceControl on Button inside VBoxContainer, `animate_in()` | Button animates, Container hold pattern prevents position reset by `_sort_children()` |
| C2 — Grid stagger | JuiceControl on each button in a 3×3 GridContainer, sequencer with stagger | All 9 buttons animate with correct offsets, all return to natural positions |
| C3 — Container resize mid-animation | Trigger layout resize (change a sibling's size) during active animation | Animation continues, target snaps back to new natural position gracefully |

---

## Scenario Family D: "I'm using the sequencer across multiple targets"

| Test | What a developer does | What to assert |
|------|-----------------------|---------------|
| D1 — Stagger forward | Sequencer across 5 targets, stagger forward | Each target starts in order, all complete, all restore |
| D2 — Reverse stagger | Same setup, stagger reverse | Last target starts first, same restoration guarantee |
| D3 — Random order | Same setup, stagger random | All targets animate (order varies), all restore |
| D4 — Retrigger mid-sequence | Call `animate_in()` while sequence is mid-flight, RESTART policy | Sequence restarts cleanly from beginning |

---

## Scenario Family E: "I'm chaining and triggering effects"

| Test | What a developer does | What to assert |
|------|-----------------------|---------------|
| E1 — Chain two effects | Effect A chains to Effect B via `chain_to` | Effect B starts exactly when A completes |
| E2 — Toggle sustained effect | `TOGGLE` trigger on Shake effect, toggle twice | On → Off → On state tracked correctly, no state leak |
| E3 — Trigger from signal | Wire `animate_in()` to a Button's `pressed` signal | Effect triggers on press, not before |

---

## Scenario Family K: "Runtime instantiation, cleanup, and crash safety"

These are not edge cases — they are everyday real-world Juice usage.

| Test | What a developer does | What to assert |
|------|-----------------------|---------------|
| K1 — Runtime instantiation | Spawn a PackedScene containing a Juice node at runtime via `instantiate()` + `add_child()` | Orchestrator created correctly in `_ready()`, animation works, no errors |
| K2 — Runtime cleanup | After K1, call `queue_free()` on the spawned node mid-animation | Orchestrator cleans up, ledger entry removed, no dangling references, no errors |
| K3 — Multiple PackedScene instances | Spawn the same PackedScene 3 times | Each instance gets its own independent recipe state. Ledger tracks all 3 separately. Animating one does not affect the others. |
| K4 — Target deleted at runtime | Start an animation. `queue_free()` the **target** node mid-animation. | Juice node handles freed reference gracefully — no crash, no error spam. Ledger cleans up. |
| K5 — Juice node deleted mid-animation | Start an animation. `queue_free()` the **Juice node itself** mid-animation. | Orchestrator stops cleanly. Target restored to natural position. Ledger entry removed. |
| K6 — Retrigger after scene transition | Juice node persists across scene change (e.g., via autoload or `DontDestroyOnLoad` pattern). Trigger animation in new scene. | Animation works correctly. Previous ledger state cleared. No stale references. |
| K7 — Missing recipe resource | Assign a recipe `.tres` that doesn't exist or is deleted from disk. Call `animate_in()`. | Fails gracefully with a config warning. No crash. No silent corruption. |
