# Godot Engine Realities (Anti-BS Guide)

When acting as the Adversarial Reviewer, you must not apply generic software engineering assumptions (like Java multithreading or Node.js async behavior) to the Godot engine. 

Before making a critique, cross-reference against these engine realities:

## 1. Single-Threaded Main Loop
- **The Reality:** Godot's `_process` and `_physics_process` execute synchronously and atomically on the main thread (unless explicitly using `WorkerThreadPool` or multi-threaded physics settings).
- **The Anti-BS Rule:** Do NOT invent "race conditions" within a `for` loop inside `_process` claiming a signal or external event will interrupt it mid-iteration. That is physically impossible in standard GDScript execution.

## 2. Array Iteration and Mutation
- **The Reality:** GDScript 4 handles array iteration safely. If you append to an array (`array.append(x)`) while iterating over it via a `for` loop, the iteration only considers the original array size at the start of the loop.
- **The Anti-BS Rule:** Do NOT claim that appending to an array during iteration will cause an "infinite loop" or "skip elements" in GDScript. If an algorithm relies on this behavior (e.g., adding an effect to a queue for the *next* frame), it is a feature, not a bug.

## 3. Container Layout Pass
- **The Reality:** Godot's Container classes (e.g., `VBoxContainer`) brutally overwrite the `position` and `size` (Rect2) of their children every frame they run their layout pass. They do not "add" offsets.
- **The Anti-BS Rule:** If code temporarily locks or freezes layout updates to perform a visual animation (e.g., using an `is_idle` check), do NOT propose subtracting offsets mathematically from the base. The base gets overwritten by the Container. Acknowledging Container overwrites is mandatory before proposing UI transform fixes.

## 4. Multiplicative vs. Additive Neutral Elements
- **The Reality:** Additive operations (position, rotation) use `0.0` or `Vector2.ZERO` as the identity element. Multiplicative operations (Colors, Modulate) use `1.0` or `Color.WHITE` as the identity element.
- **The Anti-BS Rule:** Do NOT claim that using `Color.WHITE` as a default accumulator value is a bug or will "break the architecture" just because it isn't `Color(0,0,0,0)`.

## 5. Signals are Lightweight
- **The Reality:** Godot's Observer pattern (`Signal` system) is incredibly lightweight and deeply optimized in C++.
- **The Anti-BS Rule:** Do NOT propose over-engineered, web-dev-style "Global Event Batchers" or complex queuing singletons just because multiple nodes receive a signal. Stick to native Godot signal patterns.
