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

## Anti-Patterns
- [ ] No effects writing directly to targets
- [ ] No domain nodes calculating deltas
- [ ] No hardcoded property channels
- [ ] No string IDs in arrays
- [ ] No external dependencies

## Quality Gate
Before declaring "done":
1. Run test suite - all must pass
2. Cite specific test names
3. Verify layer contracts
4. Check domain completeness
