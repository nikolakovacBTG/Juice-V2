# Verdict Template

When writing a phase report or final verdict that identifies a flaw, you MUST strictly use the following format for each issue. Do not skip steps.

### `[Intent Articulation]`
State your understanding of WHY this specific code/abstraction exists. If the reasoning isn't clear, flag it as **"Obscure Intent"** and stop processing this specific issue rather than guessing. Evaluate if a wrapper geared toward non-coders actually reduces complexity or just hides a "Black Box" bottleneck.

### `[Hypothesis]`
What exactly will go wrong when pushed by edge cases or Godot-specific lifecycle constraints (e.g., `queue_free`, `tree_exiting`, Container sorting).

### `[Engine Proof]`
Provide rigorous proof of how Godot's C++ source code or GDScript Virtual Machine actually executes this flaw. If you cannot prove it via engine mechanics, abandon the hypothesis.

### `[Impact]`
Define the severity. Is it a memory leak, heavy array allocation churn in a hot loop (e.g., using `.values()`), a visual snap, or architectural bloat/cascading?

### `[Pragmatic Solution]`
Provide the most elegant, native O(1) fix requiring the least amount of new code. Do not suggest solutions that require manual, high-level refactoring. Avoid redundant wrapper services.

### `[Glass House Score]`
Evaluate the Rigidity vs. Flexibility of the affected architecture on a scale of 1-10 (10 being extremely brittle/shattering if a core component is modified). Provide a brief "Deconstruction Plan" to simplify it if the score is high.
