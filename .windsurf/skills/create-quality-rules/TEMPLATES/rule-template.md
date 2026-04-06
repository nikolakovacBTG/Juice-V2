---
trigger: always_on
description: Brief description of what this rule covers and when it applies.
---

# Rule Title

## Overview
Brief description of what this rule covers and why it matters for the project.

## Standards

### Category 1
- Specific, actionable instruction 1
- Specific, actionable instruction 2
- Specific, actionable instruction 3

### Category 2
- Specific, actionable instruction 1
- Specific, actionable instruction 2
- Specific, actionable instruction 3

### Category 3
- Specific, actionable instruction 1
- Specific, actionable instruction 2
- Specific, actionable instruction 3

## Examples

### Good Example
```typescript
// Example showing the correct pattern
interface ExampleProps {
    name: string;
    count: number;
}

export function ExampleComponent({ name, count }: ExampleProps) {
    return <div>{name}: {count}</div>;
}
```

### Good Example 2
```typescript
// Another example of the pattern
export function calculateTotal(items: Item[]): number {
    return items.reduce((sum, item) => sum + item.price, 0);
}
```

## Anti-Patterns

### Bad Example
```typescript
// Example showing what to avoid
function ExampleComponent(props) {
    return <div>{props.name}: {props.count}</div>;
}
```

### Bad Example 2
```typescript
// Another anti-pattern to avoid
function calculateTotal(items) {
    return items.reduce((sum, item) => sum + item.price, 0);
}
```

## Edge Cases

### Case 1: [Specific Scenario]
- How to handle this case
- What pattern to follow
- Example if needed

### Case 2: [Specific Scenario]
- How to handle this case
- What pattern to follow
- Example if needed

## Related Rules

- See [related-rule.md](related-rule.md) for related guidelines
- See [another-rule.md](another-rule.md) for complementary standards

## Troubleshooting

**Issue**: Problem description
**Solution**: How to resolve it

**Issue**: Another problem
**Solution**: Resolution approach
