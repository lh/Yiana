# SwiftUI Type-Checking Instability Report (14 Oct 2025)

## Summary
- Multiple SwiftUI views (`MacPDFViewer`, `DocumentReadView`, previously DocumentList components) trigger `The compiler is unable to type-check this expression in reasonable time` build failures.
- The issue recurs whenever large view hierarchies mix conditional logic, inline `ForEach`, and computed state inside a single expression.
- Ad-hoc fixes (hoisting constants, wrapping subviews) reduce the problem temporarily but do not prevent it from coming back as more logic accumulates.

## Root Causes
1. **Monolithic view builders**  
   Large `body` expressions combine conditional UI, data transforms, and gestures. SwiftUI’s type checker struggles to infer nested generic types once complexity passes a threshold.

2. **Inline data derivation**  
   Computed values (`pdfDocument?.pageCount ?? 0`, metadata lookups, `ForEach` ranges) declared inline inside the builder create additional type-inference work on every render.

3. **Complex modifier chains**  
   Stacking accessibility modifiers, gestures, and view transforms on the same expression deepens the generic nesting Swift has to resolve.

## Recommended Remediation Strategy
1. **Componentize aggressively**  
   - Break complex sections into dedicated helper views or private `View` structs.  
   - Keep `body` expressions shallow by composing small subviews instead of large conditional blocks.

2. **Precompute data outside builders**  
   - Move metadata extraction, range calculations, and boolean flags to local variables or view-model methods before the view builder executes.
   - Favor simple data structs passed into subviews over inline optional chaining.

3. **Limit modifier depth**  
   - Apply heavy modifier chains (gestures, accessibility annotations) inside helper functions or single-purpose wrappers to avoid stacking everything on the base view.

4. **Adopt consistent patterns**  
   - Establish SwiftUI coding guidelines (e.g., “no more than one level of `if`/`ForEach` per view builder”), and require new PRs to follow them.
   - Encourage unit components (`SidebarThumbnailsView`, `ToolbarButton`) for repeated patterns.

5. **Automate checks**  
   - Add review checklist items to catch growing view bodies early.  
   - Consider smoke builds focused on macOS after UI changes to surface regressions quickly.

## Next Actions
- Refactor `DocumentReadView` using the pattern applied to `MacPDFViewer`: extract the toolbar and content sections into discrete subviews and precompute state.
- Audit other large SwiftUI views (DocumentEditView, PageManagementView) for similar risk and schedule refactors before adding further complexity.
- Incorporate the guidelines above into `docs/STYLE_GUIDE.md` or the accessibility/style compliance plan so future work maintains compiler-friendly structure.

By standardizing on composable SwiftUI patterns, we can stabilise type checking and avoid repeatedly chasing the same build failures.***
