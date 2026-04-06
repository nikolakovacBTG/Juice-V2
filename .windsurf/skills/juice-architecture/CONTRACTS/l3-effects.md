# L3 Effects Contracts

## Pure Delta Calculators
- Calculate deltas only, never write
- Store in inherited delta properties
- Target passed as parameter, never discovered

## Effect Types
- Transform: Position/rotation/scale deltas
- Appearance: Visual effects (outline, tint, etc.)
- Procedural: Generated animations
- Meta: Effect controllers and utilities

## Resource Pattern
- Extend JuiceEffectBase (Resource)
- No _ready(), _process(), lifecycle methods
- Conditional exports via _get_property_list()
