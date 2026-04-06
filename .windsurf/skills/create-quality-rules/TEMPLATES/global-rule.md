---
name: global-rule-template
description: Template for global Windsurf rules that apply across all workspaces (6,000 character limit).
---

# Global Rule Template

## File Location
`~/.codeium/windsurf/memories/global_rules.md`

## Template Structure
```markdown
# Global Rule Title

## Overview
Brief description of what this global rule covers and why it applies universally.

## Standards

### Category 1
- Specific instruction 1
- Specific instruction 2
- Specific instruction 3

### Category 2
- Specific instruction 1
- Specific instruction 2
- Specific instruction 3

## Examples
// Good example
export function example() {
    // implementation
}

## Anti-Patterns
// Bad example
function example() {
    // implementation
}
```

## Character Guidelines
- Total under 6,000 characters
- Focus on universal standards
- No project-specific content
- Essential conventions only

## Activation
- Always loaded (always_on)
- Applies to all workspaces
- Cannot be overridden by workspace rules

## Content Guidelines
- Universal coding standards
- Fundamental architectural patterns
- Core conventions
- Essential best practices

## Validation
- [ ] Under 6,000 characters
- [ ] Universal applicability
- [ ] No project-specific content
- [ ] Clear examples provided
