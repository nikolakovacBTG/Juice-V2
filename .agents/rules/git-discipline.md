## RULE: Git Discipline

**Purpose:** Define Git workflow and safety standards. **PREVENT data loss.**

**Mission:** Ensure safe, trackable development with proper rollback capabilities.

---

# ============================================================================
# WHAT: Git workflow and safety standards
# EXPECTS: All development follows Git safety protocols
# PROVIDES: Safe development environment with rollback capabilities
# ARCHITECTURE: Rules layer that enforces development safety
# ============================================================================

## ⛔ MANDATORY SAFETY GATE — DESTRUCTIVE COMMANDS

**The following git commands can PERMANENTLY DESTROY uncommitted work.
NEVER run them without FIRST running `git status` and confirming the
working tree is clean OR stashing/committing all changes.**

### 🔴 CRITICAL — Always ask user permission FIRST

| Command | Risk | What it destroys |
|---------|------|-----------------|
| `git checkout <branch>` | **CRITICAL** | Wipes ALL uncommitted changes silently |
| `git checkout -- <file>` | **CRITICAL** | Discards file changes permanently |
| `git switch <branch>` | **CRITICAL** | Same as checkout for branch switching |
| `git restore` | **CRITICAL** | Discards working tree changes |
| `git reset --hard` | **CRITICAL** | Loses commits AND uncommitted changes |
| `git clean -f` | **CRITICAL** | Permanently deletes untracked files |

### 🟡 HIGH RISK — Check with user before running

| Command | Risk | What it destroys |
|---------|------|-----------------|
| `git reset` (any form) | **High** | Can lose staged changes or commits |
| `git stash drop` | **High** | Loses specific stashed work |
| `git stash clear` | **High** | Loses ALL stashed work |
| `git rebase` | **High** | Rewrites commit history |
| `git push --force` | **High** | Overwrites remote history |
| `git branch -D` | **Medium** | Deletes branch with unmerged work |
| `git merge` | **Medium** | Can create conflicts, modify tree |
| `git revert` | **Medium** | Creates revert commits |

### ✅ SAFE — Can run freely (read-only or reversible)

`git status`, `git log`, `git diff`, `git show`, `git grep`,
`git add`, `git commit`, `git stash` (save), `git remote` (list),
`git branch` (list), `git tag` (list), `git subtree push/pull`

### Pre-Destructive-Command Checklist (MANDATORY)

Before running ANY 🔴 or 🟡 command:

1. Run `git status` — check for uncommitted/untracked changes
2. If dirty: `git stash` or `git add -A; git commit -m "WIP: safety save"`
3. TELL the user what you found and what you plan to do
4. WAIT for user approval before proceeding
5. **NEVER assume "it's fine" — uncommitted work = potential hours lost**

## 📖 Read Code From Other Commits — NEVER Checkout

**To read code from a different commit or branch, use `git show` — NEVER `git checkout`.**

```powershell
# Read a specific file at any commit — SAFE, read-only, no working tree change
git show abc123:path/to/file.gd
git show HEAD~3:addons/Juice_V2/Editor/JuiceArrayEditor.gd
git show main:path/to/file.gd

# Compare current file with committed version
git diff HEAD -- path/to/file.gd

# See what changed in a specific commit
git show abc123 --stat
git show abc123 -- path/to/file.gd
```

**This MUST be the default research pattern.** There is NEVER a reason to
`git checkout` a branch just to read its code. `git show` does the same
thing without touching the working tree or risking data loss.

## Git Safety Protocol

### Pre-Refactor Safety Net
1. **Baseline Commit:** Commit current state before any refactor
2. **Feature Branch:** Create dedicated branch for refactor work
3. **Rollback Strategy:** Always have rollback plan ready
4. **Progress Tracking:** Commit in logical units, not large batches

### PowerShell Command Rules
```powershell
# ❌ WRONG - PowerShell doesn't support &&
git add -A && git commit -m "message"

# ✅ CORRECT - Use semicolon
git add -A; git commit -m "message"

# ✅ CORRECT - Run separately
git add -A
git commit -m "message"
```

## Subtree Workflow

### Pull Latest Juice
```powershell
# Pull from standalone repo into Demo
git subtree pull --prefix=addons/juice juice-standalone main --squash
```

### Push Demo Fixes
```powershell
# Push Demo fixes upstream to standalone
git subtree push --prefix=addons/juice juice-standalone main
```

### Subtree Commands Reference
```powershell
# Add subtree (initial setup)
git subtree add --prefix=addons/juice juice-standalone main

# Pull updates
git subtree pull --prefix=addons/juice juice-standalone main --squash

# Push changes
git subtree push --prefix=addons/juice juice-standalone main
```

## Commit Standards

### Logical Unit Commits
- **One feature per commit** when possible
- **Related changes together** in single commit
- **Don't accumulate** changes without committing
- **Descriptive messages** explaining what and why

### Commit Message Format
```
Brief summary (50 chars max)

Detailed explanation if needed:
- What was changed
- Why it was changed
- Any breaking changes
```

### Branch Strategy
```powershell
# Create feature branch
git checkout -b feature/juice-v1-refactor

# Work on feature branch
# ... make changes ...

# Commit regularly
git add -A; git commit -m "Create L1 documentation structure"

# Merge to master when ready
git checkout master
git merge feature/juice-v1-refactor
```

## Refactor Safety

### Before Refactoring
1. **Commit baseline:** `git add -A; git commit -m "Pre-refactor baseline"`
2. **Create branch:** `git checkout -b refactor/[feature-name]`
3. **Verify clean state:** `git status` should be clean

### During Refactoring
1. **Commit frequently:** Every logical unit of work
2. **Test between commits:** Ensure each commit works
3. **Monitor progress:** Track what's done vs remaining

### After Refactoring
1. **Final validation:** Test complete refactored system
2. **Commit final:** `git add -A; git commit -m "Complete [feature] refactor"`
3. **Merge safely:** Review changes before merging to master

## Validation Rules

### Git Safety Checklist
- [ ] Baseline committed before starting
- [ ] Feature branch created for work
- [ ] PowerShell commands use semicolons
- [ ] Commits made in logical units
- [ ] Descriptive commit messages used

### Subtree Workflow Checklist
- [ ] Correct subtree commands used
- [ --squash flag used for pulls
- [ ] Changes pushed upstream when appropriate
- [ ] Subtree conflicts resolved properly

---

## Cross-References

**Related Rules:**
- See RULE-coding-standards.md for development standards
- See RULE-verification.md for testing requirements

**Implementation Guides:**
- See Documentation 2/REFACTOR_PROGRESS.md for refactor tracking
- See project README for Git setup instructions

This Git discipline rule ensures safe, trackable development with proper rollback capabilities.
