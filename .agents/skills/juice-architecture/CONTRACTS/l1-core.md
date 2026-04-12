# L1 Core Contracts

## Delta-First Model
- Effects compute delta (offset from natural state) at given progress
- Effects NEVER write to target nodes
- Domain nodes aggregate and write once per frame

## Timing System
- Base timing interfaces for all domains
- Shared mathematical foundations
- No domain-specific logic in L1

## Base Interfaces
- JuiceEffectBase extends Resource
- TransformEffect extends EffectBase
- Common property patterns
