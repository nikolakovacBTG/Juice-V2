---
name: domain-skill-template
description: Template for domain-specific skills with specialized knowledge and patterns.
---

# Domain Skill Template

## Structure
```
domain-skill/
├── SKILL.md              # Domain-specific router
├── TEMPLATES/            # Domain templates
├── REFERENCES/           # Domain documentation
├── EXAMPLES/            # Domain implementations
└── VALIDATION/          # Domain-specific checks
```

## SKILL.md Template
```markdown
---
name: domain-your-skill
description: Domain-specific skill for [domain name]. Use when working with [domain technologies].
---

# Domain Skill Name

## Domain Selection
- **[Technology A]**: Use [TEMPLATES/tech-a-pattern.md](TEMPLATES/tech-a-pattern.md)
- **[Technology B]**: Use [TEMPLATES/tech-b-pattern.md](TEMPLATES/tech-b-pattern.md)
- **[Technology C]**: Use [TEMPLATES/tech-c-pattern.md](TEMPLATES/tech-c-pattern.md)

## Domain Validation
Run [VALIDATION/domain-check.md](VALIDATION/domain-check.md).

## Domain Reference
See [REFERENCES/domain-guide.md](REFERENCES/domain-guide.md) for complete domain knowledge.
```

## Domain-Specific Files

### REFERENCES/
- **domain-guide.md**: Complete domain documentation
- **best-practices.md**: Domain-specific standards
- **api-reference.md**: Domain API documentation
- **troubleshooting.md**: Domain-specific issues

### TEMPLATES/
- **tech-a-pattern.md**: Pattern for Technology A
- **tech-b-pattern.md**: Pattern for Technology B
- **tech-c-pattern.md**: Pattern for Technology C
- **domain-config.md**: Domain configuration template

### EXAMPLES/
- **basic-implementation.md**: Simple domain example
- **advanced-patterns.md**: Complex domain scenarios
- **integration-examples.md**: Cross-domain integration

### VALIDATION/
- **domain-check.md**: Domain-specific validation
- **compliance-check.md**: Standards compliance
- **performance-check.md**: Domain performance validation

## Domain Guidelines
- Focus on domain-specific knowledge
- Include domain terminology and concepts
- Reference domain standards and conventions
- Provide domain-relevant examples

## Character Guidelines
- SKILL.md: under 3,000 characters (domain-focused)
- Each supporting file: under 8,000 characters
- Domain reference: comprehensive but focused

## Validation
- [ ] Domain-specific terminology used correctly
- [ ] Domain standards referenced
- [ ] Examples domain-relevant
- [ ] No cross-domain confusion
