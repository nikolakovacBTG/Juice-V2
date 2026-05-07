---
description: Systematic, safe refactoring with backup, validation, and documentation
---

You are in REFACTOR MODE.

**Parent workflow:** `/architecture` — See `/architecture` for Juice V2 architecture context

**Skills auto-invoked:** `@juice-architecture`, `@verify-claims`, `@doc-sweep`

---

## Authorization Gate (MANDATORY)

Before making ANY write changes, I must ask for explicit authorization if the work involves:

- **Migrations** (changing configs/behaviour across scenes or systems)
- **Any edits to** `.tscn`, `.tres`, `.res`
- **Any revert/restore/cleanup** (including undoing user testing tweaks)

If authorization is not explicitly given, I may only do read-only investigation (search, read, report).

Your task is to restructure, rename, or reorganize code systematically and safely.
Refactoring changes code structure WITHOUT changing behavior.
Every step must be reversible, validated, and documented.

Primary goals:
- Improve code organization, naming, and structure
- Maintain identical external behavior
- Preserve version control history (use git mv for renames)
- Validate after every change
- Document all changes for future reference

GENERAL STOP RULE:
If scope is unclear or risks are high, STOP and ASK before proceeding.

---

### 1. Scope Definition (MANDATORY)

Before refactoring, explicitly confirm:
- What is being refactored? (file, class, system, naming convention)
- What is the goal? (rename, reorganize, extract, consolidate, comply with convention)
- What files/systems are affected?
- Is there a design specification guiding this refactor?

If scope is not clear:
- Ask precise clarification questions
- Never assume refactoring scope

---

### 2. Pre-Refactor Analysis

#### Impact Assessment
- List all files that will be modified
- Identify all references to items being changed (grep .gd, .tscn, .tres, .md)
- Map dependencies and consumers
- Identify potential breaking changes

#### Risk Assessment
| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Broken references | ... | Systematic grep and update |
| Missing renames | ... | Validation step |
| Godot cache issues | ... | Project reload |

---

### 3. Safety Checkpoint (MANDATORY)

Before making ANY changes:

// turbo
```
git status
```

If uncommitted changes exist:
// turbo
```
git add -A
git commit -m "Pre-refactor checkpoint: [brief description]"
```

This creates a safe rollback point.

---

### 4. Documentation Preparation

Create or update `Documentation/!_REFACTOR_PLAN.md`:

```markdown
# Refactor: [Name]
Date: [Date]
Status: In Progress

## Objective
[What we're changing and why]

## Scope
- Files affected: [list]
- Systems impacted: [list]

## Changes
| Item | From | To | Status |
|------|------|-----|--------|
| ... | ... | ... | ⬜ Pending |

## Validation Plan
- [ ] All references updated
- [ ] Godot project reloaded
- [ ] No errors in output
- [ ] Affected functionality tested
- [ ] Headless test suite run and passing

## Rollback
git revert to commit: [hash]
```

---

### 5. Execution Protocol

For EACH change, follow this sequence:

#### Step A: Make the Change
- For file renames: Use `git mv old_path new_path` to preserve history
- For class renames: Update `class_name` in script
- For content changes: Use targeted edits

#### Step B: Update All References
Search for old name in ALL relevant files:
// turbo
```
grep -r "OldName" --include="*.gd" --include="*.tscn" --include="*.tres" --include="*.md"
```

Update each reference found.

#### Step C: Verify No Orphaned References
Re-run grep to confirm zero matches for old name.

#### Step D: Document Completion
Update refactor plan with ✅ status.

---

### 6. Validation Protocol

After ALL changes are complete:

#### Static Validation
- [ ] Grep confirms no old references remain
- [ ] All files exist at new locations
- [ ] Git status shows expected changes

#### Headless Test Run (MANDATORY)
// turbo
```powershell
& "C:\Portable Software\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64_console.exe" --headless --path "D:\Godot_projekti\juice-demo" res://tests/run_tests.tscn 2>&1 | Select-String "Tests complete"
```
- [ ] Test count unchanged from pre-refactor baseline
- [ ] 0 new failures introduced

#### Runtime Validation
Using Godot MCP:
// turbo
- `mcp_godot-mcp_get_godot_errors` — check for load/parse errors
- `mcp_godot-mcp_play_scene` — test affected functionality

Check for:
- [ ] No "file not found" errors
- [ ] No "class not found" errors
- [ ] No preload failures
- [ ] Affected systems initialize correctly

#### Functional Validation
- [ ] Test affected functionality manually
- [ ] Confirm behavior is unchanged

#### Documentation & Logging Quality Gate (per AGENTS.md — do NOT skip)
For **every file modified or created** during the refactor:
- [ ] `##` class tooltip present and action-oriented
- [ ] `# WHAT / WHY / SYSTEM / DOES NOT` block present
- [ ] Section banners (`# =============================================================================`)
- [ ] `##` on every public method
- [ ] `#` on every private helper
- [ ] `JuiceLogger.log_info()` at all lifecycle entry points
- [ ] `JuiceLogger.warn()` on all guard/fallback paths
- [ ] No silent fallback paths (`else` that changes behaviour must log)
- [ ] Script section ordering: Signals → Enums → Config → Internal State → Lifecycle → Public API → Core Logic → Helpers
- [ ] No translation violations (no 'V0/V1/ported/refactored' history in comments — explain WHY instead)

---

### 7. Common Refactoring Patterns

#### Pattern: Rename Class
1. Update `class_name` in script
2. Rename file to match (git mv)
3. Update all type hints referencing old name
4. Update all preload/load paths
5. Update scene files (.tscn) referencing script
6. Update resource files (.tres) referencing script

#### Pattern: Move File
1. git mv to new location
2. Update all preload/load paths
3. Update scene/resource references
4. Update AGENTS.md if folder rules changed

#### Pattern: Rename Convention (Batch)
1. List all files matching old convention
2. Create rename mapping table
3. Execute renames in order (git mv)
4. Batch update references
5. Validate no orphaned references

#### Pattern: Extract Component
1. Create new script with extracted logic
2. Add class_name
3. Update original to use new component
4. Update any external references

---

### 7b. MCP Scene Editing Safety (MANDATORY)

When creating or modifying nodes in Godot scenes via MCP tools:

**NEVER use `mcp0_duplicate_node` for nodes with children.**
Duplicated children lose their `owner` reference to the scene root, so Godot's serializer silently drops them on save. The nodes appear in the editor tree but vanish from the .tscn file.

**Instead:** Use `mcp0_execute_editor_script` to build node hierarchies programmatically, explicitly setting `node.owner = scene_root` for EVERY node (including all children, grandchildren, etc.).

**After any MCP scene edits:**
1. Save the scene (via editor script or manual save)
2. Verify the .tscn file is in the git changeset before committing: `git status` or `git diff --name-only`
3. If a scene file is missing from the changeset, the scene was NOT saved — re-save before committing

---

### 8. Godot-Specific Considerations

#### Resource Caching
Godot caches resource paths. After file moves:
- Reload project (`Project → Reload Current Project`)
- If errors persist, clear `.godot/` cache folder

#### UID Handling
Godot 4 uses UIDs in addition to paths. When renaming:
- UIDs remain stable (good)
- But paths in ext_resource must be updated
- Check both path and uid references

#### Scene Files (.tscn)
Scene files reference scripts via:
```
[ext_resource type="Script" uid="..." path="..." id="..."]
```
Update `path` values when moving scripts.

---

### 9. Post-Refactor Checklist

- [ ] All changes complete and documented
- [ ] No orphaned references (grep verified)
- [ ] Godot project reloaded
- [ ] No errors in Godot output
- [ ] Headless test suite: count unchanged, 0 new failures
- [ ] Affected functionality tested
- [ ] Doc/logging quality gate passed for all modified files
- [ ] Git commit with descriptive message
- [ ] Refactor plan updated with completion status

---

### 10. Commit Protocol

After successful validation:

// turbo
```
git add -A
```

Commit with structured message:
```
git commit -m "Refactor: [category] - [summary]

Changes:
- [change 1]
- [change 2]
- [change 3]

Files affected: [count]
Validated: [yes/no]"
```

---

### 11. Rollback Procedure

If refactor fails validation:

1. Check git log for checkpoint commit
2. `git revert HEAD` or `git reset --hard [checkpoint]`
3. Document what went wrong
4. Analyze root cause before retrying

FINAL RULES:
- Never skip the safety checkpoint
- Always validate after changes
- Use git mv for file renames
- Document everything
- One logical change at a time
- If in doubt, create smaller commits
