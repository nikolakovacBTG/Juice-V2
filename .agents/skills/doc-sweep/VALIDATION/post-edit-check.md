# Post-Edit Validation

Run after editing each file to catch common mistakes.

## Automated Checks

```powershell
# 1. Verify no RATIONALE: prefix crept back in
Select-String -Path "$FILE" -Pattern "RATIONALE:" -CaseSensitive

# 2. Verify no history references
Select-String -Path "$FILE" -Pattern "\bV0\b|\bV0's\b|Mirrors V0|migration|refactor" -CaseSensitive

# 3. Verify class tooltip exists (first line starts with ##)
$firstLine = (Get-Content "$FILE" -TotalCount 1)
if (-not ($firstLine -match '^##')) { Write-Warning "Missing class tooltip!" }
```

## Manual Checks

### Phase A Verification
1. **Class tooltip** — first line is `## Action-oriented sentence`?
2. **Export tooltips** — every `@export var` has `##` above it?
3. **History** — zero V0/V1/migration/phase references?

### Phase B Verification (critical — this is where sweeps previously failed)
4. **Comprehension** — Can you explain what base class calls each virtual hook implementation in this file?
5. **Triage completeness** — Was every `func` in the file explicitly triaged (DOCUMENT or SKIP)?
6. **Comment accuracy** — Do your comments match what the code ACTUALLY does? Re-read each comment against the method body.
7. **Adversarial test** — Would an adversarial reviewer flag any comment as useless filler?
8. **Fabrication check** — Did you write any comment without having traced the call chain? If yes, delete it and trace the chain first.

### Preservation Check
9. **Did you accidentally destroy any existing good comments?** — check the git diff
10. **Did you accidentally destroy any existing good inline comments?** — check method bodies in the diff

## Git Diff Review

```powershell
git diff -- "$FILE"
```

Review the diff before committing:
- Are any DELETIONS losing useful information?
- Are any ADDITIONS just restating code?
- Are any ADDITIONS fabricating behavior the code doesn't actually have?
- Is the net change positive (more insight, less noise)?
