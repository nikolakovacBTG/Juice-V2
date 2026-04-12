# Agent Skills Structure - 2026 Standards

## Progressive Disclosure Architecture

Based on Anthropic's official Agent Skills specification, skills use 3-level progressive disclosure to manage context efficiently.

### Level 1: Metadata (Always Loaded)
- **Content**: YAML frontmatter (name, description)
- **When loaded**: At agent startup
- **Purpose**: Discovery - agent knows skill exists and when to use it
- **Token impact**: Minimal (~50-100 characters per skill)

```yaml
---
name: pdf-processing
description: Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.
---
```

### Level 2: Core Instructions (Loaded When Triggered)
- **Content**: Main SKILL.md body
- **When loaded**: When task matches skill description
- **Purpose**: Procedural knowledge and workflows
- **Token impact**: Moderate (keep under 5,000 characters)

### Level 3: Supporting Resources (Loaded As Needed)
- **Content**: Reference files, templates, examples
- **When loaded**: Only when explicitly referenced
- **Purpose**: Detailed information, reusable components
- **Token impact**: On-demand consumption

## Directory Structure

```
skill-name/
├── SKILL.md              # Required: Core instructions (Level 2)
├── TEMPLATES/            # Optional: Reusable templates
│   ├── code-template.py
│   └── config-template.yaml
├── REFERENCES/           # Optional: Detailed documentation
│   ├── api-reference.md
│   ├── troubleshooting.md
│   └── advanced-workflows.md
├── EXAMPLES/            # Optional: Real-world examples
│   ├── basic-usage.md
│   └── advanced-scenarios.md
├── VALIDATION/          # Optional: Quality checks
│   ├── quality-check.md
│   └── test-cases.md
└── scripts/             # Optional: Utility scripts
    ├── setup.sh
    └── validate.py
```

## File Organization Patterns

### Simple Skills (< 2,000 characters)
```
simple-skill/
└── SKILL.md
```

### Complex Skills (> 5,000 characters total)
```
complex-skill/
├── SKILL.md              # Core workflow (2,000 chars)
├── REFERENCES/
│   ├── detailed-guide.md    # 3,000 chars
│   └── api-reference.md      # 2,000 chars
├── TEMPLATES/
│   └── starter-template.py   # 500 chars
└── EXAMPLES/
    └── real-world-case.md    # 1,000 chars
```

### Domain-Specific Skills
```
domain-skill/
├── SKILL.md              # Domain-specific workflow
├── REFERENCES/
│   ├── domain-concepts.md
│   └── best-practices.md
├── TEMPLATES/
│   ├── domain-config.yaml
│   └── domain-script.py
└── EXAMPLES/
    ├── basic-implementation.md
    └── advanced-patterns.md
```

## Content Distribution Guidelines

### SKILL.md (Core - Level 2)
**Keep under 5,000 characters:**
- Quick start instructions
- Core workflow steps
- Key decision points
- References to detailed content
- Essential examples only

### REFERENCES/ (Detailed - Level 3)
**Detailed information:**
- API documentation
- Complete workflows
- Troubleshooting guides
- Technical specifications
- Domain knowledge

### TEMPLATES/ (Reusable - Level 3)
**Starting points:**
- Code templates
- Configuration files
- Checklists
- Standard structures
- Boilerplate content

### EXAMPLES/ (Illustrative - Level 3)
**Real applications:**
- Use cases
- Implementation examples
- Before/after comparisons
- Integration patterns

## Token Efficiency Strategies

### 1. Reference, Don't Duplicate
```markdown
# Bad - duplicates content
## API Reference
[Full API documentation repeated here]

# Good - references external file
## API Reference
See [REFERENCES/api-reference.md](REFERENCES/api-reference.md) for complete API documentation.
```

### 2. Progressive Detail
```markdown
# SKILL.md - Quick overview
## Form Filling
For basic form filling, use the fill_form() function. See [REFERENCES/forms.md](REFERENCES/forms.md) for advanced scenarios.

# REFERENCES/forms.md - Detailed guide
## Advanced Form Filling
[Detailed technical instructions]
```

### 3. Conditional Loading
```markdown
# SKILL.md
## Troubleshooting
Common issues in [REFERENCES/troubleshooting.md](REFERENCES/troubleshooting.md).

# Only loaded if user has problems
```

## Quality Standards

### Metadata Quality
- **name**: lowercase, hyphens for spaces, descriptive
- **description**: complete sentence, includes use cases
- **Example**: "Extract PDF text, fill forms, merge files. Use when handling PDFs."

### Content Quality
- Specific, actionable instructions
- Positive framing ("do this" not "don't do that")
- Clear examples and templates
- Single purpose per skill

### File Organization
- Logical grouping of related content
- Clear naming conventions
- Minimal redundancy
- Easy navigation

## Common Anti-Patterns to Avoid

### 1. Monolithic SKILL.md
```markdown
# Bad - 10,000 character SKILL.md
[Everything in one file]
```

### 2. Vague References
```markdown
# Bad - unclear what to reference
See documentation for more details.

# Good - specific reference
See [REFERENCES/api-endpoints.md](REFERENCES/api-endpoints.md) for endpoint specifications.
```

### 3. Poor Organization
```markdown
# Bad - mixed concerns
## API Reference
## UI Guidelines  
## Database Schema
## Testing

# Good - organized by concern
## API Integration
→ See [REFERENCES/api.md](REFERENCES/api.md)
## UI Components  
→ See [REFERENCES/ui.md](REFERENCES/ui.md)
```

## Validation Checklist

- [ ] Frontmatter has name and description
- [ ] Description includes use cases
- [ ] SKILL.md under 5,000 characters
- [ ] References are specific and accurate
- [ ] File structure follows conventions
- [ ] Content is organized by concern
- [ ] Examples are concrete and useful
- [ ] Templates are reusable
- [ ] No duplicate content across files
