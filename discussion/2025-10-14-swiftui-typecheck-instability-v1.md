# SwiftUI Type-Check Instability – Review Notes (v3)

**Date:** 14 Oct 2025  
**Reviewer:** Codex  

---

## Quick Assessment
- v2 captures the correct architectural root cause (overly dense `body` builders) and highlights the right anti-patterns.
- The “For New Views” guidelines are strong but could use an execution checklist for existing code so it’s easier to apply during refactors.
- Order of operations is implied but not explicit; teams may hesitate without a prioritised migration path.

---

## Comments & Suggestions
1. **Make Current-State Audit Explicit**  
   Add a short “Audit” section listing the views still violating the guidelines (e.g. `DocumentReadView`, `PageManagementView`, `DocumentEditView`). This turns the document from theory into an actionable tracker.

2. **Call Out Testing Impact**  
   Mention that breaking views into components demands fresh snapshot/UI tests (or VoiceOver runs) to ensure behaviour parity. Calling this out avoids regressions.

3. **Reference Helper Modules**  
   Note that we now have `View+Accessibility` and `AccessibilityAnnouncer` helpers. Encourage new components to reuse them instead of reapplying modifiers manually.

4. **Provide Refactor Checklist** (for insertion into the doc):  
   ```
   - [ ] Extract computed state from `body`
   - [ ] Split toolbar/sidebar/content into dedicated subviews
   - [ ] Replace two-way bindings with `selectedValue` + `onChange`
   - [ ] Ensure each new subview has preview/SwiftUI inspection
   ```

---

## Proposed Order of Work
1. **DocumentReadView** – currently the most complex view and the source of the latest compiler failure. Break into toolbar/sidebar/content/status components.
2. **PageManagementView** – second-largest builder; refactor after DocumentReadView to leverage the same patterns.
3. **DocumentEditView** – contains nested overlays and scan controls; refactor once the first two are stable.

This order lets us resolve the active build block first and locks in reusable patterns for subsequent work.

---

## Next Steps
- Incorporate the audit checklist and refactor checklist into the main doc.
- Track each targeted view refactor in implementation plans with granular tasks (junior-friendly).
- Align testing plan (UI + accessibility) with each refactor milestone.***
