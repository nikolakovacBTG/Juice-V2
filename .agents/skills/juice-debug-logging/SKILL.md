---
name: juice-debug-logging
description: Debug logging patterns and checklists for Juice. Auto-invoke when adding logging to addons/Juice_V2/ files.
---

# Juice Debug Logging

## First: Which Workflow Do You Need?

| Situation | Tool |
|-----------|------|
| **Logging already exists** but quality is insufficient | Use `/upgrade-logging` + `@juice-logging-upgrade` |
| **New script** with no logging yet | Use `/add-logging` (this skill) |
| **Single file** needing a spot fix | Follow the Quick Protocol below directly |

---

## MANDATORY Before Any Instrumentation Work

Before writing or modifying a single log call, execute the **Contract/Chain/Coverage Protocol**
from [QUALITY_GATE.md](QUALITY_GATE.md) § Pre-Implementation.

This means: state the contract, map the chain, audit coverage. In writing. Then instrument.

Skipping this produces mechanical logging. Mechanical logging is a defect.

---

## Decision Tree (After Protocol Is Done)
- **Adding to a base class?** → Read [LOG_POINTS.md](LOG_POINTS.md) § Base Classes
- **Adding to a concrete effect?** → Read [LOG_POINTS.md](LOG_POINTS.md) § Effects + [TEMPLATES.md](TEMPLATES.md) § Delta Reporting
- **Adding to a domain node?** → Read [LOG_POINTS.md](LOG_POINTS.md) § Domain Nodes + [TEMPLATES.md](TEMPLATES.md) § Aggregation
- **Adding to a utility?** → Read [LOG_POINTS.md](LOG_POINTS.md) § Utilities
- **Auditing existing prints?** → Read [TEMPLATES.md](TEMPLATES.md) § Audit Checklist
- **Verifying quality of finished work?** → Apply Completeness Test in [QUALITY_GATE.md](QUALITY_GATE.md) § Post-Implementation
- **Tracking batch progress?** → Read [CHECKLIST.md](CHECKLIST.md)

## Quick Rules
1. All logging through `JuiceLogger` — never raw `print()`
2. Guard: `OS.is_debug_build() AND (master_switch OR debug_enabled)`
3. Format: `[Juice][Domain][EffectType] TargetName: message`
4. Batch size: 3 files (complex), 5 files (simple), never mix domains in one batch
5. **Config at lifecycle start = EVERY field that feeds the computation chain.** No curated subsets.
6. **Per-frame log = computed output at that frame.** Never static config repeated from start.
7. **Unexpected silent `return` = `warn()` before it.** Normal animation behavior (hold active, fade-out complete, progress=0) must NOT warn — only config errors and impossible states. Silent bail-outs that would confuse a marketplace user always get a `warn()`.
8. **Completeness Test gates every file.** Three questions must answer YES before the file is done.

