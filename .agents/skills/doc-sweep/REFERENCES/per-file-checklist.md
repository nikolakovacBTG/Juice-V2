# Per-File Documentation Checklist

Run through this for every `.gd` file in the sweep.

## 1. Class Tooltip (`##` at top of file)

- [ ] First line is a concise, action-oriented sentence (shows in Create New Node menu)
- [ ] Additional `##` paragraphs provide architectural context (shows in script docs only)
- [ ] No historical references (V0, V1, migration, ported)

## 2. Header WHY Block (`# ============` block)

- [ ] WHAT: one sentence saying what this class does
- [ ] WHY: one sentence saying why it exists as a separate class (not "because we need it")
- [ ] SYSTEM: which system it belongs to
- [ ] DOES NOT: what responsibilities are explicitly excluded
- [ ] No historical references

## 3. Export Tooltips

- [ ] Every `@export var` has a `##` comment above it (shows in Inspector hover)
- [ ] Tooltips describe what the value controls, not implementation details
- [ ] For `_get_property_list()` exports: tooltips are in the `hint_string` or in `##` above the backing `var`

## 4. Method Comments

For each method, apply the skill's decision tree:

- [ ] Public API methods have `##` with: what it does, when to call it, notable side effects
- [ ] Private methods with architectural significance have `#` explaining what problem they solve
- [ ] Trivial/boilerplate methods are deliberately left uncommented (NOT "I forgot")
- [ ] No comment just restates the function name as a sentence
- [ ] No `RATIONALE:`, `PURPOSE:`, `NOTE:` prefixes

## 5. History Sanitization

- [ ] Zero occurrences of: V0, V1, migration, ported, refactor (in comments)
- [ ] Zero occurrences of dev-phase prefixes: `Phase A/B/C:`, `Sprint N:`, `TODO(phase-N):`, `SEQUENCER Phase N`
- [ ] Historical comments with useful info have been translated to pure rationale
- [ ] Historical comments with no useful info have been deleted
- [ ] Debug print strings checked for phase/sprint references (e.g. `"[DEBUG] Phase B:"` → `"[DEBUG]"`)

## 6. Inline Comments

- [ ] Complex branching logic has brief `#` explaining the branch condition's purpose
- [ ] Magic numbers have `#` explaining what they represent
- [ ] No stale/outdated inline comments referring to code that's changed

## 7. TODO / FIXME / HACK Triage

No `TODO`, `FIXME`, or `HACK` comments in shipping code. When found during a sweep:

- [ ] Search the file for `TODO`, `FIXME`, `HACK` (case-insensitive)
- [ ] For each hit, **verify against surrounding code** — is the work done (stale) or still needed (valid)?
- [ ] **Stale:** Delete or replace with an accurate comment explaining the current behavior
- [ ] **Valid:** Do NOT delete. Do NOT implement during the sweep. Add to batch report as a **blocker** for the user to resolve before the TODO line can be removed
- [ ] After user resolves valid TODOs, re-sweep the file to confirm 0 hits
