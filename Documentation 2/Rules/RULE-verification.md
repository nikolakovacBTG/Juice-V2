## RULE: Verification

**Purpose:** Define Juice V1 testing and verification standards.

**Mission:** Ensure all features work correctly with proper test coverage.

---

# ============================================================================
# WHAT: Juice V1 testing and verification standards
# EXPECTS: All features have corresponding tests and verification
# PROVIDES: Quality assurance and regression prevention
# ARCHITECTURE: Rules layer that enforces testing standards
# ============================================================================

## Verification Requirements

### Never Claim Without Evidence
- **No "done" without test:** Never claim a feature works without citing test evidence
- **Test name and result:** Always cite `test_name` and whether it PASSes
- **No test = write one:** If no test exists, write one before claiming completion
- **Code review ≠ verification:** Only test results count as verification

### Test Evidence Format
```gdscript
# ✅ CORRECT - Cite specific test
"✅ Port complete - test_transform_effect_porting PASSes"

# ❌ WRONG - Claim without evidence
"✅ Port complete - looks good"
```

## Test Coverage Requirements

### Three Domain Testing
Every Juice component must have tests in all three domains:
- **Control:** Control targets with Juice components
- **2D:** Node2D targets with Sprite2D + Interaction2DJuiceUtility
- **3D:** Area3D targets with Interaction3DJuiceUtility + MeshInstance3D

### Test Categories
- **Unit tests:** Individual component behavior
- **Integration tests:** Component interaction
- **Domain tests:** Cross-domain consistency
- **Regression tests:** Bug fix verification

### Critical Test Scenarios
```gdscript
# External move detection recovery
func test_external_reset_during_warmup_hold_recovers():
    # Simulate external reset during warmup
    btn.scale = Vector2(1, 1)
    # Verify recovery within 5 frames
    assert_true(_recovers_within_frames(5))
    # Verify correct final animation values
    assert_eq(btn.scale, Vector2(0, 0))

# Container hold pattern
func test_container_hold_prevents_frame_zero_flash():
    # Test Container hold pattern works
    assert_false(_has_frame_zero_flash())
```

## Testing Standards

### Test Naming Convention
```gdscript
# Pattern: test_[feature]_[scenario]_[expected_result]
func test_transform_effect_applies_correct_delta()
func test_external_move_detection_recovers_base_values()
func test_container_hold_beats_deferred_sort()
```

### Test Structure
```gdscript
func test_feature_name():
    # Arrange
    var setup = _create_test_setup()
    
    # Act
    setup.trigger_feature()
    
    # Assert
    assert_true(setup.expected_behavior())
```

## Verification Process

### Before Claiming "Done"
1. **Run test suite:** Execute all relevant tests
2. **Check results:** Verify all tests PASS
3. **Cite evidence:** Reference specific test names
4. **Document results:** Note any test failures

### Bug Fix Verification
1. **Write failing test:** Demonstrate bug exists
2. **Implement fix:** Apply the fix
3. **Verify test passes:** Confirm bug is resolved
4. **Add to suite:** Include test in regular suite

### Architecture Verification
1. **Layer contracts:** Verify L1-3 boundaries respected
2. **Domain consistency:** Verify all domains equivalent
3. **Delta-first model:** Verify effects calculate deltas only
4. **Write coordination:** Verify single writes per frame

## Quality Gates

### Pre-Merge Checklist
- [ ] All tests PASS
- [ ] No regressions introduced
- [ ] Test evidence cited for all claims
- [ ] Architecture contracts verified

### Release Checklist
- [ ] Full test suite PASSes
- [ ] All three domains tested
- [ ] Performance benchmarks met
- [ ] Documentation updated

---

## Cross-References

**Related Rules:**
- See RULE-coding-standards.md for development standards
- See RULE-architecture-contracts.md for architectural verification

**Implementation Guides:**
- See L1 docs for core system testing
- See L2 docs for domain coordination testing
- See L3 docs for effect implementation testing

This verification rule ensures quality assurance and prevents false claims about feature completion.
