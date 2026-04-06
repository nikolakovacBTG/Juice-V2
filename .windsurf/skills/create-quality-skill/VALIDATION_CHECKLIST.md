# Skill Quality Validation Checklist

## Token Efficiency

### Character Limits
- [ ] SKILL.md under 5,000 characters
- [ ] Each supporting file under 10,000 characters
- [ ] Total skill size under 50,000 characters

### Progressive Disclosure
- [ ] Level 1: Only metadata in frontmatter
- [ ] Level 2: Core instructions in SKILL.md only
- [ ] Level 3: Supporting files referenced, not embedded
- [ ] No duplicate content across files

### Reference Quality
- [ ] All file references are accurate
- [ ] Reference links are specific (not "see docs")
- [ ] No broken internal links
- [ ] External references are minimal

## Content Quality

### Frontmatter
- [ ] Name follows conventions (lowercase, hyphens)
- [ ] Description is complete sentence
- [ ] Description includes use cases/triggers
- [ ] No extra frontmatter fields

### Instructions
- [ ] Specific, actionable steps
- [ ] Positive framing ("do this" not "don't do that")
- [ ] Clear examples for complex concepts
- [ ] Single purpose per skill

### Organization
- [ ] Logical content flow
- [ ] Clear heading structure
- [ ] Related content grouped together
- [ ] Easy to navigate

## File Structure

### Required Files
- [ ] SKILL.md exists and is complete
- [ ] Directory structure follows conventions

### Optional Files
- [ ] TEMPLATES/ directory for reusable content
- [ ] REFERENCES/ directory for detailed information
- [ ] EXAMPLES/ directory for real-world usage
- [ ] VALIDATION/ directory for quality checks

### Naming Conventions
- [ ] Files use kebab-case
- [ ] Names are descriptive
- [ ] No duplicate file names
- [ ] Logical directory organization

## Content Standards

### Clarity
- [ ] No ambiguous instructions
- [ ] Technical terms explained
- [ ] Examples match the described patterns
- [ ] Steps are in logical order

### Completeness
- [ ] All referenced files exist
- [ ] Workflow covers complete process
- [ ] Edge cases addressed
- [ ] Error handling included

### Accuracy
- [ ] Technical information correct
- [ ] Examples actually work
- [ ] File paths accurate
- [ ] No contradictory information

## Progressive Disclosure Compliance

### Level 1 (Metadata)
- [ ] Only name and description in frontmatter
- [ ] Description includes when to use
- [ ] No other content at this level

### Level 2 (Core Instructions)
- [ ] SKILL.md contains essential workflow
- [ ] References to supporting files only
- [ ] No embedded detailed documentation
- [ ] Quick start for immediate needs

### Level 3 (Supporting Files)
- [ ] Detailed content in REFERENCES/
- [ ] Reusable templates in TEMPLATES/
- [ ] Concrete examples in EXAMPLES/
- [ ] Quality checks in VALIDATION/

## Anti-Pattern Checks

### Content Anti-Patterns
- [ ] No vague instructions ("write clean code")
- [ ] No negative-only instructions ("don't use var")
- [ ] No monolithic content dump
- [ ] No mixed concerns in single files

### Structure Anti-Patterns
- [ ] No duplicate content across files
- [ ] No unclear references ("see documentation")
- [ ] No broken file organization
- [ ] No missing essential files

### Token Anti-Patterns
- [ ] No unnecessary repetition
- [ ] No embedded large code blocks
- [ ] No verbose explanations in SKILL.md
- [ ] No redundant examples

## Validation Tests

### Manual Tests
- [ ] Skill can be followed without external knowledge
- [ ] Examples produce expected results
- [ ] Templates are immediately usable
- [ ] Troubleshooting guide covers common issues

### Automated Tests
- [ ] Run [VALIDATION/quality-check.md](VALIDATION/quality-check.md)
- [ ] Verify all internal links work
- [ ] Check character counts
- [ ] Validate file structure

### Integration Tests
- [ ] Skill works with target AI platform
- [ ] Progressive disclosure functions correctly
- [ ] References resolve properly
- [ ] Templates integrate seamlessly

## Final Quality Gates

### Must Pass
- [ ] SKILL.md under 5,000 characters
- [ ] Progressive disclosure implemented
- [ ] All file references accurate
- [ ] Single, clear purpose

### Should Pass  
- [ ] Examples included and tested
- [ ] Templates provided and working
- [ ] Troubleshooting comprehensive
- [ ] Quality checks automated

### Nice to Have
- [ ] Advanced scenarios covered
- [ ] Performance optimization notes
- [ ] Integration examples
- [ ] Community contribution guidelines

## Failure Remediation

### Token Issues
- Move detailed content to supporting files
- Combine related content
- Remove redundancy
- Use references instead of duplication

### Content Issues
- Add specific examples
- Clarify ambiguous instructions
- Fix organizational problems
- Complete missing sections

### Structure Issues
- Reorganize by concern
- Fix naming conventions
- Add missing directories
- Correct file references

## Validation Script Template

Create [VALIDATION/quality-check.md](VALIDATION/quality-check.md) with:
- Character count verification
- Link validation
- Structure compliance
- Content quality checks
- Anti-pattern detection
