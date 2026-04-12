---
name: simple-skill-template
description: Template for simple skills under 2,000 characters with minimal file structure.
---

# Simple Skill Template

## Structure
```
your-skill/
└── SKILL.md
```

## SKILL.md Template
```markdown
---
name: sample-skill
description: A short, concise description of what this skill does and when to use it.
---

# Skill Name

**DO NOT** write long, token-rich, data-poor rules. Skills should be lean routers that direct the AI agent to smaller, focused support documents.

## Quick Start
Provide a high-level overview and immediately route to support documents.

- **Topic 1**: `@support-doc-1`
  Brief explanation of when to read this doc.

- **Topic 2**: `@support-doc-2`
  Brief explanation of when to read this doc.

## Core Directives
List 3-5 absolute, unbreakable rules that apply universally to this domain.
1. **Rule 1**: Concise explanation.
2. **Rule 2**: Concise explanation.
3. **Rule 3**: Concise explanation.
```

## Character Guidelines
- Keep SKILL.md lean and focused (router-only)
- Move detailed information, patterns, and code examples into smaller support docs
- Use `@support-doc-name` to route AI agents to specific topics
- Avoid repetitive, token-rich "AI slop"
- DO NOT use the simple-skill template for rules or recipes

## Validation
- [ ] SKILL.md acts primarily as a router
- [ ] Complex patterns moved to support docs
- [ ] No repetitive information or generic filler text
