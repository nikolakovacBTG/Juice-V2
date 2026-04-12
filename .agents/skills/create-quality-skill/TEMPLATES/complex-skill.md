---
name: complex-skill-template
description: Template for complex skills over 2,000 characters with full progressive disclosure structure.
---

# Complex Skill Template

## Structure
```
your-skill/
├── SKILL.md              # Core router (under 5,000 chars)
├── TEMPLATES/            # Reusable templates
├── REFERENCES/           # Detailed documentation
├── EXAMPLES/            # Real-world examples
└── VALIDATION/          # Quality checks
```

## SKILL.md Template
```markdown
---
name: your-skill-name
description: Brief description of what this skill does and when to use it.
---

# Skill Name

## Decision Tree
- **Scenario A**: Use [TEMPLATES/pattern-a.md](TEMPLATES/pattern-a.md)
- **Scenario B**: Use [TEMPLATES/pattern-b.md](TEMPLATES/pattern-b.md)
- **Scenario C**: Use [TEMPLATES/pattern-c.md](TEMPLATES/pattern-c.md)

## Quick Validation
Run [VALIDATION/quality-check.md](VALIDATION/quality-check.md).

## Troubleshooting
See [REFERENCES/troubleshooting.md](REFERENCES/troubleshooting.md).
```

## Supporting Files

### REFERENCES/
- **detailed-guide.md**: Complete procedures (3,000-5,000 chars)
- **api-reference.md**: Technical documentation
- **troubleshooting.md**: Common issues and solutions
- **advanced-patterns.md**: Complex scenarios

### TEMPLATES/
- **pattern-a.md**: Template for scenario A
- **pattern-b.md**: Template for scenario B
- **pattern-c.md**: Template for scenario C
- **checklist.md**: Quality validation checklist

### EXAMPLES/
- **basic-usage.md**: Simple implementation
- **advanced-scenarios.md**: Complex use cases
- **integration-patterns.md**: How to combine with other tools

## Character Guidelines
- SKILL.md: under 5,000 characters
- Each supporting file: under 10,000 characters
- Total skill size: under 50,000 characters

## Progressive Disclosure
- Level 1: Metadata (always loaded)
- Level 2: Decision router (loaded when triggered)
- Level 3: Supporting files (loaded as needed)

## Validation
- [ ] SKILL.md under 5,000 characters
- [ ] All references accurate
- [ ] No duplicate content
- [ ] Clear decision paths
