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

1. **Re-read the quality standard** — did you drift from the rules?
2. **Spot-check 2-3 comments you wrote** — do they pass the adversarial test?
3. **Did you accidentally destroy any existing good comments?** — check the git diff
4. **Are your comments the right syntax?** — `##` for public, `#` for private

## Git Diff Review

```powershell
git diff -- "$FILE"
```

Review the diff before committing:
- Are any DELETIONS losing useful information?
- Are any ADDITIONS just restating code?
- Is the net change positive (more insight, less noise)?
