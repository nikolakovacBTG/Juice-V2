# Architecture Validation Checklist

## Layer Contract Compliance
- [ ] L1: Pure math foundations only
- [ ] L2: Coordinates but doesn't calculate deltas
- [ ] L3: Calculates deltas but doesn't write
- [ ] No cross-domain dependencies

## Domain Completeness
- [ ] Features exist in Control, Node2D, Node3D
- [ ] Domain-specific math correct (Vector2 vs Vector3)
- [ ] Container hold pattern for Control only
- [ ] External move detection in all domains
- [ ] L2 virtual stubs present in JuiceBase (5 methods)
- [ ] JIT `_pre_tick()` called before `_temporarily_undo_visual()` in `_start_effects()`

## Anti-Patterns
- [ ] No effects writing directly to targets (except approved exceptions in l3-effects.md)
- [ ] No domain nodes calculating deltas
- [ ] No hardcoded property channels
- [ ] No string IDs in arrays
- [ ] No external dependencies
- [ ] No effect returning RESTART_REVERSED unless it is an accumulation effect (Progress family)
- [ ] No effect calling animate_in/out on itself — use RESTART_REVERSED if a restart is needed

## Quality Gate
Before declaring "done":
1. Run test suite - all must pass
2. Cite specific test names
3. Verify layer contracts
4. Check domain completeness
