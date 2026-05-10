# Adversarial Review Workflow
**Description**: A strict, step-by-step procedure to perform a forensic architectural review of Godot code. It utilizes the `@adversarial-reviewer` skill and forces phase-by-phase execution to maintain deep context and prevent AI drift.

**Invocation**: `/adversarial-review [path/to/target/file.gd] [optional/path/to/design_doc.md]`

---

**IMPORTANT EXECUTION RULE**: 
You MUST execute this workflow phase by phase. Do NOT output the entire review at once. Output the report for Phase 1, ask the user if you should proceed to Phase 2 (or request a context refresh), and wait for their confirmation.

## Phase 1: Context Assembly & Alignment
1. **Action**: Invoke the `@juice-architecture` skill (if applicable) to understand standard project contracts.
2. **Action**: Read the complementary persona file: `[REFERENCES/persona-mandate.md]` (located in the `@adversarial-reviewer` skill directory).
3. **Action**: Use the `view_file` tool to read the target code file and its matching design document (if provided).
4. **Output**: Confirm you have internalized the Persona. Summarize the intended architecture of the target file in 2 sentences. Pause and wait for user go-ahead.

## Phase 2: Intent & Simplification Audit
1. **Action**: Analyze the code for "Black Box" fragility. 
2. **Action**: Identify patterns geared toward "non-coders". Interrogate whether these abstractions actually reduce complexity or merely hide it while creating bottlenecks.
3. **Action**: Look for "Abstraction Cascading" (where new layers were added because a previous developer was too timid to refactor a base class).
4. **Output**: Write the Phase 2 report. Pause and wait for user go-ahead.

## Phase 3: Execution Timing & Lifecycle Sweep
1. **Action**: Analyze the code purely for `_process`, `_physics_process`, `_ready`, `_exit_tree`, and signal timings.
2. **Action**: Dismantle the "happy path" assumptions. What happens if the target is `queue_free`'d exactly one frame before the effect? What happens if the visibility changes?
3. **Output**: Write the Phase 3 report using the `[TEMPLATES/verdict.md]` format if issues are found. Pause and wait for user go-ahead.

## Phase 4: Memory, Allocations & Bloat Sweep
1. **Action**: Perform a rigorous check for hot-loop allocations (e.g., using `Dictionary.values()` inside `_process`, creating new Arrays every frame).
2. **Action**: Look for "Architectural Bloat"—instances where native Godot Node and Signal systems were ignored in favor of heavy wrapper solutions.
3. **Output**: Write the Phase 4 report using the `[TEMPLATES/verdict.md]` format if issues are found. Pause and wait for user go-ahead.

## Phase 5: The Final Verdict
1. **Action**: Synthesize all phase findings.
2. **Action**: If issues were found, compile them clearly.
3. **Action**: Assign a final **`[Glass House Score]`** for the entire module's architecture.
4. **Action**: If NO issues are found across any phase, you MUST output the literal text: **"Precision Criticism: Bulletproof. No changes required."** Do not invent performative negativity.
