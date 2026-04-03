# Cascade Memory Backup - Pre Documentation Refactor

**Created:** 2026-04-03
**Purpose:** Backup of all Cascade memories before documentation refactor
**Reason:** Safety net for catastrophic failure recovery

## Current Memories Identified

From system-retrieved memories in this conversation:

### Memory: Anti-Rushing Rule
**ID:** 3155ed27-0496-40d1-abc8-90fa4a7f74f8
**Tags:** rules, anti_rushing, thoroughness, development_policy, architecture
**Content:** Rules for analyzing bugs and architectural changes in Juice system
- NEVER assume features are "not needed" without user confirmation
- NEVER use script comments as authoritative design intent
- ALWAYS analyze ALL domains × ALL properties
- If external-move detection exists in one domain, must exist in all domains
- When user pushes back, STOP and re-examine assumptions
- Think as top-tier architect for scale considerations
- Choose generic/extensible approaches over hardcoded solutions
- Ask architectural questions when discovered

### Memory: Container Hold Pattern
**ID:** 672ef85d-b562-464f-a6ae-1b40e186ccf9
**Tags:** sequencer, frame_0_flash, container_layout, hold_pattern, bug_fix, architecture
**Content:** Problem and solution for Control targets in Godot Containers
- Problem: Container layout system overrides position changes
- Solution: Hold pattern in SequencerJuiceComp with _held_entries tracking
- Supporting fixes: FFR, external-move detection, deferred ordering
- Removed obsolete _pre_position_target methods

### Memory: V1 Sequencer Enum Names
**ID:** 0c399665-097f-445d-ae45-5de9e6a5445f
**Tags:** v1_architecture, sequencer, naming, enums
**Content:** V1 JuiceSource enum naming (user-approved)
- RECIPE (replaces SEQUENCERS_CHILDREN)
- TARGETS_STACK (same as V0)
- TARGETS_CHILDREN (same as V0)
- Other enums keep exact names: TargetScope, SequenceType

### Memory: External Reset During Warmup
**ID:** 0e6c51ab-b38d-4ef9-a65b-5a069f683d02
**Tags:** bugfix, sequencer, warmup, contribution_tracking, external_reset, v1
**Content:** Fix for external property resets between warmup and first _process tick
- Problem: External resets break contribution tracking formula
- Solution: _seq_expected_after_write dictionary for detection
- Generic: Works for any property channel via _get_seq_contribution()
- Test: test_external_reset_during_warmup_hold_recovers

### Memory: Spring Effect Redesign (CUT)
**ID:** 11bdda40-1001-4587-b5b5-6b7e38a8bdd0
**Tags:** spring, redesign, design_decision, torque, center_of_gravity
**Content:** Spring effect redesign details (NOTE: Spring has been cut)
- Core model: Purely reactive, no kick, no one_shot_mode
- New properties: swing_range, stiffness, damping, mass, center_of_gravity
- Per-channel behavior and rotation torque model
- Soft clamp implementation

## Backup Status
- **Total memories identified:** 5
- **Active memories:** 4 (Spring cut)
- **Backup complete:** Yes
- **Ready for compliance check:** Yes

## Next Steps
1. Check each memory against new L1-3 docs and Rules
2. Update non-compliant memories
3. Preserve functional memory system while improving alignment
