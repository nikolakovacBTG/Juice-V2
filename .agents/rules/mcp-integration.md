---
trigger: always_on
description: MCP integration for Godot operations. Use MCP0 for engine access, MCP1 for documentation.
---

# MCP Integration Rules

## MCP Usage Priority

**ALWAYS use MCP before manual operations:**
- **MCP0 (godot-mcp)**: Scene manipulation, node creation, testing, file operations
- **MCP1 (godot-mcp-docs)**: Documentation lookup, API verification, class references

## Core Rules

- **NEVER use bash for Godot operations** if MCP0 can handle it
- **For GDScript code edits — prefer native tools over MCP0 `edit_file`**
  - `write_to_file` (Overwrite) / `replace_file_content` / `multi_replace_file_content` write directly to disk and are reliable
  - MCP0 `edit_file` operates on editor in-memory state and can silently no-op if the search string doesn't match exactly
  - Use MCP0 `edit_file` only for small, targeted tweaks where the match string is unambiguous (e.g. a single property value)
- **ALWAYS check MCP1 documentation** before implementing ANY Godot class API
  - Verify method exists on the class (e.g. `Resource` vs `Node` vs `Object`)
  - Verify signal exists on that specific class (not just a parent)
  - Example: `get_process_delta_time()` exists on `Node`, NOT on `Resource`
  - Example: `completed` signal exists on `JuiceBase`, NOT on `JuiceEffectBase`
- **VERIFY disk state after any MCP0 `edit_file` call** — call `view_file` to confirm the change landed
  - MCP0 `edit_file` returns "File edited" even on a silent no-op (search text not found)
  - For full-file rewrites, always use `write_to_file` with `Overwrite: true` — it never silently fails
- **USE MCP0 for testing** - scene playback, test execution, validation

## Common Scenarios

| Task | MCP Tool | Manual Alternative |
|------|----------|-------------------|
| Create scene/node | MCP0 | Manual file creation |
| Edit scene properties | MCP0 | Text file editing |
| Run tests | MCP0 | .bat files |
| Lookup class API | MCP1 | Web search/memory |
| Verify method signature | MCP1 | Guesswork |

## Enforcement

This Rule ensures MCP is the primary interface to Godot, not manual operations.
