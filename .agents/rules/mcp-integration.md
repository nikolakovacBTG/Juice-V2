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
- **NEVER manually edit Godot files** if MCP0 can edit them
- **ALWAYS check MCP1 documentation** before implementing ANY Godot class API
  - Verify method exists on the class (e.g. `Resource` vs `Node` vs `Object`)
  - Verify signal exists on that specific class (not just a parent)
  - Example: `get_process_delta_time()` exists on `Node`, NOT on `Resource`
  - Example: `completed` signal exists on `JuiceBase`, NOT on `JuiceEffectBase`
- **VERIFY disk state after MCP0 `edit_file` on infrastructure files** (base classes, enums)
  - MCP0 edits operate on the editor's in-memory state and may not flush to disk
  - After editing `JuiceEffectBase`, `JuiceBase`, or any base class, call `view_file` to
    confirm the change is present on disk before writing dependent code
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
