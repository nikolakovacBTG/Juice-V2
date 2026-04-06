# Rules Quality Validation Checklist

## Character Limits

### Global Rules
- [ ] Under 6,000 characters total
- [ ] No single section over 1,000 characters
- [ ] Efficient use of space

### Workspace Rules
- [ ] Under 12,000 characters per file
- [ ] No single section over 2,000 characters
- [ ] Content density optimized

### AGENTS.md Rules
- [ ] Follows same efficiency guidelines
- [ ] No unnecessary verbosity
- [ ] Appropriate length for scope

## Frontmatter Validation

### Required Fields
- [ ] trigger field present and valid (always_on, glob, model_decision, manual)
- [ ] description field present and descriptive
- [ ] glob field present for glob triggers

### Field Quality
- [ ] trigger matches rule content and purpose
- [ ] description clearly explains when rule applies
- [ ] glob patterns are specific and accurate
- [ ] No unnecessary frontmatter fields

## Content Quality

### Specificity
- [ ] Instructions are specific and actionable
- [ ] No vague statements ("write clean code")
- [ ] Clear patterns and conventions
- [ ] Concrete implementation guidance

### Positive Framing
- [ ] Uses "do this" instead of "don't do that"
- [ ] Positive instructional language
- [ ] Constructive guidance
- [ ] No negative-only instructions

### Examples
- [ ] Good examples included for each pattern
- [ ] Bad examples (anti-patterns) shown
- [ ] Examples are accurate and tested
- [ ] Code examples are complete and runnable

### Organization
- [ ] Logical content flow
- [ ] Clear heading structure
- [ ] Related content grouped together
- [ ] Easy to navigate and scan

## Structure Validation

### Heading Structure
- [ ] H1 for main title
- [ ] H2 for major sections
- [ ] H3 for subsections
- [ ] Consistent heading hierarchy

### Content Organization
- [ ] Overview section explaining purpose
- [ ] Standards section with clear categories
- [ ] Examples section with good/bad patterns
- [ ] Anti-patterns section showing what to avoid

### File Organization
- [ ] Single purpose per rule file
- [ ] No mixed concerns in single file
- [ ] Logical file naming
- [ ] Appropriate directory placement

## Token Efficiency

### Content Density
- [ ] No redundant content
- [ ] Minimal repetition
- [ ] Concise explanations
- [ ] Focused examples

### Reference Usage
- [ ] External references instead of duplication
- [ ] Internal references are specific
- [ ] No broken reference links
- [ ] Appropriate reference density

### Example Efficiency
- [ ] Examples are minimal but complete
- [ ] No unnecessary code in examples
- [ ] Examples illustrate specific points
- [ ] No example overload

## Activation Mode Validation

### always_on Rules
- [ ] Content is universally applicable
- [ ] Core standards that always apply
- [ ] No context-specific content
- [ ] Essential for all code in workspace

### glob Rules
- [ ] Glob pattern matches intended files
- [ ] Pattern is specific and not too broad
- [ ] Content relevant to matched files
- [ ] No conflicts with other glob rules

### model_decision Rules
- [ ] Content requires contextual judgment
- [ ] AI can determine relevance
- [ ] Complex patterns or decisions
- [ ] Not suitable for automatic activation

### manual Rules
- [ ] Content is truly optional
- [ ] Supplementary guidelines
- [ ] Best practices not requirements
- [ ] Appropriate for manual invocation

## Quality Standards

### Technical Accuracy
- [ ] All code examples are syntactically correct
- [ ] Technical information is accurate
- [ ] Examples follow described patterns
- [ ] No contradictory information

### Completeness
- [ ] All aspects of topic covered
- [ ] Edge cases addressed
- [ ] Error conditions considered
- [ ] Related patterns mentioned

### Consistency
- [ ] Examples consistent with instructions
- [ ] Formatting consistent throughout
- [ ] Terminology consistent
- [ ] Style guidelines consistent

## Anti-Pattern Detection

### Content Anti-Patterns
- [ ] No vague instructions found
- [ ] No negative-only instructions
- [ ] No mixed concerns in single file
- [ ] No unnecessary complexity

### Structure Anti-Patterns
- [ ] No duplicate content across sections
- [ ] No unclear references
- [ ] No broken organization
- [ ] No missing essential sections

### Token Anti-Patterns
- [ ] No unnecessary repetition
- [ ] No embedded large code blocks
- [ ] No verbose explanations
- [ ] No redundant examples

## Integration Validation

### Platform Compatibility
- [ ] Works with Windsurf/Cascade
- [ ] Follows Windsurf rule format
- [ ] Compatible with AI model constraints
- [ ] No platform-specific issues

### Team Usability
- [ ] Clear for team members to understand
- [ ] Easy to follow and implement
- [ ] Minimal learning curve
- [ ] Good documentation quality

### Maintenance
- [ ] Easy to update and modify
- [ ] Clear structure for changes
- [ ] Version control friendly
- [ ] Minimal dependencies

## Validation Tests

### Manual Tests
- [ ] Rule can be followed without external knowledge
- [ ] Examples produce expected results
- [ ] Instructions are unambiguous
- [ ] Edge cases are handled properly

### Automated Tests
- [ ] Character count verification passes
- [ ] Link validation passes
- [ ] Format validation passes
- [ ] Structure validation passes

### Integration Tests
- [ ] Rule activates correctly in context
- [ ] AI follows rule instructions
- [ ] No conflicts with other rules
- [ ] Proper precedence behavior

## Failure Remediation

### Character Limit Issues
- [ ] Move detailed content to separate files
- [ ] Combine related content efficiently
- [ ] Remove redundancy and duplication
- [ ] Use references instead of embedding

### Content Quality Issues
- [ ] Add specific examples for vague instructions
- [ ] Convert negative instructions to positive
- [ ] Fix organizational problems
- [ ] Complete missing sections

### Structure Issues
- [ ] Reorganize by single concern
- [ ] Fix heading hierarchy
- [ ] Add missing sections
- [ ] Correct file references

### Activation Issues
- [ ] Review trigger mode appropriateness
- [ ] Fix glob pattern specificity
- [ ] Adjust content for activation type
- [ ] Resolve conflicts with other rules

## Final Quality Gates

### Must Pass
- [ ] Character limits respected
- [ ] Frontmatter complete and valid
- [ ] Content specific and actionable
- [ ] Examples included and accurate

### Should Pass
- [ ] Positive framing used throughout
- [ ] Single purpose per file
- [ ] Token-efficient content
- [ ] Integration tests pass

### Nice to Have
- [ ] Advanced scenarios covered
- [ ] Performance considerations included
- [ ] Team guidelines documented
- [ ] Migration paths provided

## Quality Metrics

### Efficiency Metrics
- Characters per instruction: < 100
- Examples per standard: ≥ 1
- References per 1000 chars: < 5
- Anti-patterns per pattern: ≥ 1

### Coverage Metrics
- Standards have examples: 100%
- Anti-patterns shown: 100%
- Edge cases covered: ≥ 80%
- Related rules referenced: ≥ 90%

### Usability Metrics
- Reading time: < 5 minutes
- Implementation time: < 10 minutes
- Learning curve: Low
- Maintenance effort: Low
