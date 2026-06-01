# Refactor: Phase 6.0 — JuiceLedger Hotpath Optimization
Date: 2026-05-10
Status: ✅ Complete

## Objective

Eliminate per-frame `Dictionary.values()` allocations in JuiceLedger's hot-path methods
and extend `zero_for()` to cover all Variant types that support arithmetic operators.

Source: `Documentation/Acknowledged_Architecture_Issues.md` §2 — "The Inefficient Ledger Iteration"

At 50 animated nodes × 4 properties × 60 FPS: ~24,000 Array allocations/sec.
Property family (Phase 6.1+) will multiply this further.

## Scope
- Files affected: `addons/Juice_V2/Base Classes/JuiceLedger.gd` only
- Systems impacted: none externally (pure optimization, no signature changes)

## Changes

| Item | From | To | Status |
|------|------|----|--------|
| `flush()` delta loop | `.values()` iteration | key-iteration + hoisted type check | ✅ Done |
| `get_total()` delta loop | `.values()` iteration | key-iteration + hoisted type check | ✅ Done |
| `sync_base_if_moved()` delta loop | `.values()` iteration | key-iteration + hoisted type check | ✅ Done |
| `zero_for()` | handles 4 types | handles 9 types (adds Vector2i, Vector3i, Vector4, Vector4i, Quaternion) | ✅ Done |

## Types NOT added to zero_for() — and why

`Rect2`, `Rect2i`, `AABB` have no `+` or `-` arithmetic operators in GDScript.
Registering a delta for these types would crash flush() at `base_val + total_delta`.
Property effects targeting these types MUST fall back to direct-write (Phase 6.1 decision).

## Validation Plan
- [x] All references updated (only JuiceLedger.gd — no callers affected)
- [x] Headless test suite run: 675/675, 0 failures
- [x] No new Godot errors

## Rollback
git reset --hard 816d561
