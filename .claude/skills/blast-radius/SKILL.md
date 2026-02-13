---
name: blast-radius
description: Traces code paths and analyzes impact before making changes. Use when user says "blast radius", "what could break", "trace the code path", "analyze impact", or asks to understand all affected components before implementing a fix or feature.
---

# Blast-Radius Analysis

Before making any code changes, trace through the full code path involved so we understand all the components that could be affected. Then propose a fix and list what else might break.

## Steps

1. **ANALYZE BLAST RADIUS**: Read all files that will be modified. Use mcp__serena__find_symbol and Grep to find every caller/consumer of the functions you'll change. Write a TodoWrite checklist of every component that could break.

2. **PRE-FLIGHT CHECKS**: For each item in your checklist, note the current working behavior (e.g., 'schema migration runs columns before indexes', 'OCR service picks up files within 30s', 'both iOS and macOS ViewModels call indexDocument').

3. **IMPLEMENT**: Make the change.

4. **POST-FLIGHT VERIFICATION**: Go through every checklist item. Build both platforms. Grep for patterns that indicate regressions (e.g., force-unwraps on optionals you changed, missing platform conditionals, ordering dependencies). Mark each TodoWrite item as verified or failed.

5. Only commit if all checklist items pass. If any fail, fix and re-verify ALL items, not just the failed one.
