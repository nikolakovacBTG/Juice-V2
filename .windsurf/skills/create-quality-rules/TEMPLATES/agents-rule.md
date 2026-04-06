---
name: agents-rule-template
description: Template for AGENTS.md rules that apply to specific directories and subdirectories.
---

# AGENTS.md Rule Template

## File Location
`directory/AGENTS.md` (any directory in workspace)

## Template Structure
```markdown
# Directory-Specific Rule Title

## Overview
Description of what this rule covers for this directory and its subdirectories.

## Standards

### Category 1
- Specific instruction 1 for this directory
- Specific instruction 2 for this directory
- Specific instruction 3 for this directory

### Category 2
- Specific instruction 1 for this directory
- Specific instruction 2 for this directory
- Specific instruction 3 for this directory

## Examples
// Good example for this directory
export function directoryExample() {
    // implementation
}

## Anti-Patterns
// Bad example to avoid in this directory
function directoryExample() {
    // implementation
}
```

## Activation
- Automatic based on file location
- Applies to directory and subdirectories
- No frontmatter needed
- Discovered automatically

## Character Guidelines
- No explicit limit (but follow efficiency guidelines)
- Directory-specific content
- Local conventions
- Component patterns

## Directory Structure
```
src/
├── components/
│   └── AGENTS.md          # Component-specific rules
├── hooks/
│   └── AGENTS.md          # Hook-specific rules
├── utils/
│   └── AGENTS.md          # Utility function rules
└── types/
    └── AGENTS.md          # Type definition rules
```

## Content Guidelines
- Directory-specific conventions
- Component patterns
- Local standards
- File organization rules

## Discovery
- Automatic discovery by Windsurf
- Based on file location
- Applies to directory and subdirectories
- No manual configuration needed

## Validation
- [ ] Directory-specific content
- [ ] Clear scope definition
- [ ] Appropriate for directory
- [ ] No conflicts with parent rules
