---
name: juice-debug-logging
description: Debug logging patterns and checklists for Juice V1. Auto-invoke when adding logging to addons/Juice_V1/ files.
---

# Juice Debug Logging

## Decision Tree
- **Adding logging to a base class?** → Read [LOG_POINTS.md](LOG_POINTS.md) § Base Classes
- **Adding logging to a concrete effect?** → Read [LOG_POINTS.md](LOG_POINTS.md) § Effects + [TEMPLATES.md](TEMPLATES.md) § Delta Reporting
- **Adding logging to a domain node?** → Read [LOG_POINTS.md](LOG_POINTS.md) § Domain Nodes + [TEMPLATES.md](TEMPLATES.md) § Aggregation
- **Adding logging to a utility?** → Read [LOG_POINTS.md](LOG_POINTS.md) § Utilities
- **Auditing existing prints?** → Read [TEMPLATES.md](TEMPLATES.md) § Audit Checklist
- **Reviewing or fixing log quality?** → Read [QUALITY_GATE.md](QUALITY_GATE.md) (MANDATORY before writing any payload)
- **Tracking progress?** → Read [CHECKLIST.md](CHECKLIST.md)

## Quick Rules
1. All logging through `JuiceLogger` — never raw `print()`
2. Guard: `OS.is_debug_build() AND (master_switch OR debug_enabled)`
3. Format: `[Juice][Domain][EffectType] TargetName: message`
4. Batch size: 3 files (complex), 5 files (simple), never mix domains
5. **MANDATORY: Every log payload must pass the Diagnostic Value Test** (see [QUALITY_GATE.md](QUALITY_GATE.md)). A log that only contains static config is a defect.
6. **MANDATORY: Every file must cover its failure modes** (see QUALITY_GATE.md § Per-Family Failure Modes). Missing coverage = missing log = defect.

## Required Rule
Read `add-logging-rule.md` before any instrumentation work.

