---
name: workspace-rule-template
description: Template for workspace-specific Windsurf rules (12,000 character limit per file).
---

# Workspace Rule Template

## File Location
`.windsurf/rules/rule-name.md`

## Template Structure
```markdown
---
trigger: always_on|glob|model_decision|manual
glob: "**/*.pattern"     # for glob activation
description: "Brief description of rule purpose"
---

# Rule Title

## Overview
Description of what this rule covers and why it matters for this workspace.

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
// Good example for this workspace
export function workspaceExample() {
    // implementation
}

## Anti-Patterns
// Bad example to avoid in this workspace
function workspaceExample() {
    // implementation
}

## Workspace-Specific Notes
- Project-specific considerations
- Team conventions
- Integration requirements
```

## Character Guidelines
- Under 12,000 characters per file
- Workspace-specific content
- Project conventions
- Team standards

## Activation Modes

### always_on
- Core workspace standards
- Always apply
- Essential conventions

### glob
- File-specific patterns
- Use with specific glob patterns
- Targeted application

### model_decision
- Context-dependent rules
- Complex decisions
- AI-determined relevance

### manual
- Optional guidelines
- Supplementary information
- Best practices

## Content Guidelines
- Project-specific standards
- Team conventions
- Integration patterns
- Workspace requirements

## Validation
- [ ] Under 12,000 characters
- [ ] Workspace-specific content
- [ ] Appropriate activation mode
- [ ] Clear examples provided
