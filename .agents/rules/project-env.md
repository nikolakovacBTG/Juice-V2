---
trigger: always_on
description: Centralized environment variables and paths for Godot Juice project. All workflows should reference this rule instead of hardcoding absolute paths.
---

# Project Environment Configuration

This rule defines the canonical paths and environment settings for the Juice Demo project. **Antigravity must consult this rule whenever a shell command or path-sensitive operation is performed.**

## Canonical Paths

| Variable | Value | Description |
|----------|-------|-------------|
| **PROJECT_ROOT** | `D:\Godot_projekti\juice-demo` | Absolute path to the repository root |
| **GODOT_EXE** | `C:\Portable Software\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64_console.exe` | Headless-capable Godot executable |
| **TEST_BAT** | `D:\Godot_projekti\juice-demo\tests\run_tests.bat` | The primary test entry point |
| **TEST_SCENE** | `res://tests/run_tests.tscn` | The Godot scene that runs automated suites |
| **LOG_SUMMARY** | `D:\Godot_projekti\juice-demo\tests\results\summary.log` | Central log file for test execution |

## Canonical Command Line Patterns

### Run All Tests (Headless)
```powershell
& "[GODOT_EXE]" --headless --path "[PROJECT_ROOT]" [TEST_SCENE]
```

### Run All Tests (Batch Fallback)
```powershell
cmd /c "[TEST_BAT]"
```

### Git Operations
```powershell
cd "[PROJECT_ROOT]"; git [command]
```

## PowerShell File Safety

**NEVER use `Set-Content` or `Out-File` to write GDScript files.**
PowerShell defaults cause UTF-8 corruption (em-dash `--`, special chars become garbage).

For batch text operations on `.gd` files use:
```powershell
[System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding $false))
```

Or use `mcp_edit_file` / `replace_file_content` tools directly -- they handle encoding correctly.

## Maintenance
If these paths change on the host machine, update this file immediately. No other workflow files should need to be touched if this file is updated correctly.
