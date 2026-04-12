# Windsurf Rules Structure - 2026 Standards

## Rule Types and Scopes

### Global Rules
**Location**: `~/.codeium/windsurf/memories/global_rules.md`
- **Scope**: Applied across ALL workspaces
- **Character Limit**: 6,000 characters
- **Activation**: Always on
- **Use Case**: Universal coding standards, fundamental conventions

### Workspace Rules
**Location**: `.windsurf/rules/*.md`
- **Scope**: Current workspace and subdirectories
- **Character Limit**: 12,000 characters per file
- **Activation**: Multiple modes (always_on, glob, model_decision, manual)
- **Use Case**: Project-specific guidelines, team standards

### AGENTS.md Rules
**Location**: Any directory in workspace
- **Scope**: Directory and subdirectories where located
- **Character Limit**: No explicit limit (but follow same guidelines)
- **Activation**: Automatic based on file location
- **Use Case**: Location-specific conventions, component patterns

## Activation Modes

### always_on
**When to use**: Core standards that should always apply
**Examples**: Basic coding conventions, fundamental patterns
**Character impact**: Always in context

```yaml
---
trigger: always_on
description: "Core TypeScript coding standards"
---
```

### glob
**When to use**: File or directory-specific rules
**Examples**: Component patterns, test file conventions
**Character impact**: Loaded when matching files are in context

```yaml
---
trigger: glob
glob: "**/*.tsx"
description: "React component standards"
---
```

### model_decision
**When to use**: Context-dependent guidelines
**Examples**: Architecture decisions, complex conventions
**Character impact**: Loaded when AI determines relevance

```yaml
---
trigger: model_decision
description: "Database design patterns"
---
```

### manual
**When to use**: Optional guidelines, supplementary information
**Examples**: Best practices, optional conventions
**Character impact**: Only loaded when explicitly invoked

```yaml
---
trigger: manual
description: "Performance optimization guidelines"
---
```

## Directory Structure

### Workspace Rules Organization
```
.windsurf/rules/
├── core-standards.md          # always_on - fundamental conventions
├── typescript-patterns.md      # glob - **/*.ts files
├── react-components.md         # glob - **/*.tsx files  
├── testing-guidelines.md       # glob - **/*.test.ts files
├── api-design.md              # model_decision - API design patterns
└── performance-optimization.md # manual - optional guidelines
```

### AGENTS.md Organization
```
src/
├── components/
│   └── AGENTS.md              # Component-specific rules
├── hooks/
│   └── AGENTS.md              # Hook-specific rules
├── utils/
│   └── AGENTS.md              # Utility function rules
└── types/
    └── AGENTS.md              # Type definition rules
```

## File Format Standards

### Frontmatter Requirements
```yaml
---
trigger: always_on|glob|model_decision|manual
glob: "file-pattern"           # Required for glob trigger
description: "Clear description of rule purpose"
---
```

### Content Structure
```markdown
# Rule Title

## Overview
Brief description of what this rule covers and why it matters.

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
// Good example showing the pattern
export function exampleFunction(param: string): number {
    return param.length;
}

## Anti-Patterns
// Bad example to avoid
function exampleFunction(param) {
    return param.length;
}
```

## Quality Standards

### Content Guidelines

#### Be Specific, Not Vague
```markdown
# Bad - too vague
Write clean code and follow best practices.

# Good - specific and actionable
- Use explicit return types on all exported functions
- Destructure props in function signatures
- Handle all errors with try/catch blocks
```

#### Use Positive Instructions
```markdown
# Bad - only negative
- Don't use var
- Don't use class components
- Don't use inline styles

# Good - positive with context
- Use const for immutable values; use let only when reassignment is needed
- Use functional components with hooks for all React components
- Use CSS Modules for component styling
```

#### Include Examples
```markdown
// Good component structure example:
interface UserCardProps {
    name: string;
    email: string;
    avatarUrl?: string;
}

export function UserCard({ name, email, avatarUrl }: UserCardProps) {
    return (
        <div className={styles.card}>
            {avatarUrl && <img src={avatarUrl} alt={name} />}
            <h3>{name}</h3>
            <p>{email}</p>
        </div>
    );
}
```

#### Keep Rules Focused
```markdown
# Bad - one file for everything
# coding-standards.md (5,000 chars covering 10 topics)

# Good - organized by concern
# typescript-basics.md (1,000 chars)
# react-patterns.md (1,000 chars)  
# testing-guidelines.md (1,000 chars)
# api-design.md (1,000 chars)
```

### Organization Standards

#### Heading Structure
```markdown
# Main Rule Title
## Section 1
### Subsection 1.1
#### Sub-subsection 1.1.1
```

#### Content Grouping
- Group related instructions together
- Use logical flow from general to specific
- Separate concerns with clear headings
- Include examples after instructions

## Character Limits and Optimization

### Limits
- **Global Rules**: 6,000 characters maximum
- **Workspace Rules**: 12,000 characters maximum per file
- **AGENTS.md**: No explicit limit, but follow same efficiency guidelines

### Optimization Strategies

#### Remove Redundancy
```markdown
# Bad - repetitive
- Use TypeScript for type safety
- Use TypeScript for interfaces
- Use TypeScript for enums

# Good - consolidated
- Use TypeScript for all type definitions (interfaces, enums, types)
```

#### Use References
```markdown
# Bad - duplicated content
## API Design
[Full API design guidelines repeated here]

## Testing
[Full testing guidelines repeated here]

# Good - references
## API Design
See [api-design.md](api-design.md) for complete API guidelines.

## Testing  
See [testing-guidelines.md](testing-guidelines.md) for testing standards.
```

#### Efficient Examples
```markdown
# Bad - verbose examples
// Here is a complete React component with all the imports,
// props interface, styling, and full implementation...

# Good - focused examples
// Component export pattern:
export function ComponentName({ prop }: PropsType): ReturnType {
    return <div>{prop}</div>;
}
```

## Common Rule Patterns

### Coding Standards Rules
```markdown
# TypeScript Standards
## Types
- Use explicit return types on exported functions
- Prefer interface over type for object shapes
- Use readonly for immutable properties

## Functions
- Use arrow functions for callbacks
- Use function declarations for main functions
- Destructure parameters when beneficial
```

### Architectural Rules
```markdown
# Component Architecture
## Structure
- One component per file
- Export component as named export
- Props interface above component definition

## Patterns
- Use functional components with hooks
- Custom hooks go in src/hooks/
- Keep component state minimal
```

### Convention Rules
```markdown
# File Naming
## Files
- Components: PascalCase (UserProfile.tsx)
- Utilities: camelCase (formatDate.ts)
- Constants: UPPER_SNAKE_CASE (API_ENDPOINTS.ts)

## Directories
- Components: src/components/
- Hooks: src/hooks/
- Utils: src/utils/
- Types: src/types/
```

## Rule Discovery and Loading

### Discovery Order
1. **Global Rules**: Always loaded first
2. **Workspace Rules**: Discovered from `.windsurf/rules/`
3. **AGENTS.md**: Automatic discovery based on file location
4. **Git Repository**: Searches up to git root for rules

### Loading Behavior
- **always_on**: Always included in context
- **glob**: Loaded when matching files are in context
- **model_decision**: Loaded when AI determines relevance
- **manual**: Only loaded with explicit @rule-name invocation

### Conflict Resolution
- More specific rules override general rules
- Workspace rules override global rules
- Later rules in discovery order override earlier ones

## Validation Checklist

### Structure Validation
- [ ] Proper frontmatter with trigger and description
- [ ] Character limits respected
- [ ] Heading structure consistent
- [ ] File naming follows conventions

### Content Validation
- [ ] Instructions are specific and actionable
- [ ] Positive framing used
- [ ] Examples included and accurate
- [ ] Single purpose per rule file

### Efficiency Validation
- [ ] No duplicate content
- [ ] References used appropriately
- [ ] Examples are concise
- [ ] No unnecessary verbosity

### Activation Validation
- [ ] Trigger mode appropriate for content
- [ ] Glob patterns are specific
- [ ] Manual rules are truly optional
- [ ] Model decision rules are context-dependent
