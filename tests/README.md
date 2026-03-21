# Juice V1 Test Framework

## Quick Start

### Visual Mode (interactive, shows UI with results)
```
"C:\Portable Software\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --path "D:\Godot projekti\juice-demo" res://tests/run_tests.tscn
```

### Headless Mode (automated, writes logs, exits with code)
```
"C:\Portable Software\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --headless --path "D:\Godot projekti\juice-demo" res://tests/run_tests.tscn
```

### Filter by suite
```
... res://tests/run_tests.tscn -- --suite=node_properties
```

### Filter by test name
```
... res://tests/run_tests.tscn -- --test=test_start_delay
```

## Results

Log files are written to `tests/results/`:
- `summary.log` — overall pass/fail counts
- `{suite_name}.log` — detailed per-assertion results

## Adding New Tests

1. Create a new script in `tests/suites/` extending `JuiceTestSuite`
2. Override `get_suite_name()` and `get_test_methods()`
3. Add the suite to `JuiceTestRunner._register_suites()`

## Architecture

```
tests/
  run_tests.tscn              # Entry point scene
  JuiceTestRunner.gd          # Orchestrator (visual + headless modes)
  JuiceTestSuite.gd           # Base class: assertions, wait helpers, node creation
  README.md                   # This file
  suites/
    TestNodeProperties.gd     # start_delay, loop, retrigger, trigger_behaviour
    TestTransformControl.gd   # Control transform effect (all PositionIn units, rotation, scale, stacking)
  results/                    # Runtime-generated log files (gitignored)
```
