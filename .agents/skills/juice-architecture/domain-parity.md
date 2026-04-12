# Domain Parity Rules

> **Contract Reference:** See `L1-3_CONTRACT_MATRIX.md` for complete layer contracts and validation rules

## All Three Domains Always
- **Final State Requirement**: Features must exist in Control, Node2D, and Node3D domains
- If a feature exists in one domain, its absence in others is a bug

## Sequential Implementation Order
To manage context and reduce errors, porting and development must follow this strict sequence:
1. **2D Domain** (simplest coordinate math)
2. **Control Domain** (adds UI quirks like containers re-sorting)
3. **3D Domain** (different coordinate math)

*Do NOT implement all 3 domains simultaneously. Complete one domain (including its unit tests) before starting the next.*

## Allowed Differences
- Property types: Vector2 vs Vector3
- Container hold: Control only
- Pivot compensation: Domain-specific math
