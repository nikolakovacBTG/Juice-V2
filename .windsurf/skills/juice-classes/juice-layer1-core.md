# Layer 1: Core Infrastructure

**Layer 1** consists of `JuiceBase` (Node) and `JuiceEffectBase` (Resource). These define the shared unified timing, signaling, and interfaces used by all domains.

## JuiceBase (Node)
The master orchestrator attached to the scene tree.
- **Mode Selection**: `STACK` or `SEQUENCER`.
- **Trigger Config**: Holds `trigger_on`, `delay`, `looper`, and auto-connect system.
- **Lifecycle Loop**: Runs the `_process()` loop and ticks all active effects.
- **Target Tracking**: Discovers targets and passes them down via virtual methods.
- **Delta-First tracking**: Accumulates frame-by-frame contributions.
- **Does NOT**: Write directly to the target's physical properties (that is L2).

## JuiceEffectBase (Resource)
The abstract definition of a Juice animation.
- **Timing Config**: Holds `duration`, `curve`, `easing`, `hold_at_peak`, `crossfade_time`.
- **Chain & Sibling Logic**: Holds `chain_to` and `interrupt_siblings`.
- **Math/Easing**: Provides the eased `progress` float to subclasses.
- **Virtual Interfaces**: Provides `_apply_effect(progress, target)`, `_on_animate_start(target)`, `_restore_to_natural(target)`, and `_invalidate_base_cache()`.
- **Does NOT**: Perform logic. Subclasses implement the virtuals.
