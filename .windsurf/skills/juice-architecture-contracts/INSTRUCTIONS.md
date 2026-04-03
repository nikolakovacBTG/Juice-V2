# Juice V1 Architecture - One Page

## Layers (What goes where?)

| Layer | Files | Promise | NEVER |
|-------|-------|---------|-------|
| **L1 Core** | JuiceBase, JuiceEffectBase, JuiceRecipe | Unified interfaces & timing | Domain-specific code |
| **L2 Domain** | JuiceControl/2D/3D, utilities | Filter targets, write ONCE/frame | Implement effect logic |
| **L3 Effects** | {Effect}{Domain}JuiceEffect.gd | Compute deltas only | Write to targets |

## Decision Tree

```
What are you making?
├─ Node with lifecycle → L2: Juice{Domain}.gd (extends JuiceBase)
├─ Configuration/behavior → L3: {Effect}{Domain}JuiceEffect.gd
├─ Recipe container → L3: Juice{Domain}Recipe.gd (extends JuiceRecipe)
└─ Core infrastructure → L1: Base Classes/
```

## Critical Contracts

**Delta-First Model:**
- Effects return offsets from natural state
- Domain nodes write: `target = natural + sum(deltas)`
- NEVER absolute values from effects

**Domain Separation:**
- Control ↔ Control targets only
- 2D ↔ Node2D targets only
- 3D ↔ Node3D targets only

**Write Coordination:**
- Capture natural state with external-move detection
- Aggregate ALL effect deltas
- Write exactly ONCE per property per frame

## Quick Validation

Before coding, ask:
1. Which layer? (L1/L2/L3)
2. Am I returning deltas only? (L3)
3. Am I writing once per frame? (L2)
4. Is this domain-safe? (no cross-domain)

## Anti-Patterns (NEVER)

❌ Effect writing directly to target  
❌ Domain node implementing effect logic  
❌ Multiple writes per frame  
❌ Cross-domain target handling  
❌ Hardcoded property channels (use generic protocol)
