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
- **ALWAYS check MCP1 documentation** before implementing Godot APIs
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
