# Pre-Commit Hook Fix: Check 3 (Conditional Nesting)

**Date:** 2025-10-26
**Issue:** False positive on nested conditionals check
**Status:** Fixed

## Problem

The awk script in Check 3 had a critical bug in how it identified SwiftUI view bodies:

1. It matched `var body: some View` on one line
2. Then looked for ANY opening brace `{` on ANY subsequent line as the body start
3. This caused it to incorrectly scope functions, closures, and other declarations as being "inside the body"
4. Result: Nested if-statements ANYWHERE in the file after seeing `var body:` were flagged

### Example False Positive

In `PDFViewer.swift`, line 212 in `updateUIView()` had this nesting:

```swift
if let document = pdfView.document {           // Level 1
    if totalPages != pageCount {                // Level 2
        if self.currentPage != clamped {        // Level 3 ← INCORRECTLY FLAGGED
```

This was reported as:
```
Yiana/Yiana/Views/PDFViewer.swift:nested if-statements exceed 2 levels (found 3)
✗ Yiana/Yiana/Views/PDFViewer.swift: conditional nesting exceeds 2 levels
```

But this code is in `updateUIView`, NOT in the SwiftUI `var body: some View` (lines 52-93).

## Root Cause

The original awk script:

```awk
/var body: some View/ { in_body = 1; if_depth = 0; next }
in_body && /^[[:space:]]*}[[:space:]]*$/ && --brace_count == 0 { in_body = 0 }
```

Problems:
- Line 1: Marks `in_body = 1` when seeing `var body: some View` (NO brace tracking yet)
- Line 2: Tries to exit when seeing `}`, but `brace_count` was never initialized
- Missing: Actual detection of the opening brace `{` that starts the body

## Solution

Changed the pattern to match the COMPLETE declaration on a single line:

```awk
/var body: some View.*\{/ {
    in_body = 1
    body_brace_depth = 1
    if_depth = 0
    # Count any extra braces on the same line
    opening_count = $0
    closing_count = $0
    gsub(/[^{]/, "", opening_count)
    gsub(/[^}]/, "", closing_count)
    body_brace_depth = length(opening_count) - length(closing_count)
    if (body_brace_depth == 0) {
        in_body = 0
    }
    next
}
```

Key changes:
1. Pattern `/var body: some View.*\{/` requires the opening brace on the SAME line
2. Properly initializes `body_brace_depth = 1`
3. Counts all braces on that line to handle single-line bodies
4. Tracks depth correctly through the body

## Verification

After fix:
```bash
cd /Users/rose/Code/Yiana && awk '<fixed script>' Yiana/Yiana/Views/PDFViewer.swift
```

Output:
```
Body starts at line 52, initial depth: 1
Body ends at line 93
```

✓ Correctly identifies lines 52-93 as the body
✓ NO false positive on line 212 in updateUIView
✓ Only analyzes code actually inside SwiftUI view builders

## Implementation

The fix is in `.git/hooks/pre-commit` at Check 3 (lines 85-131).

Since git hooks are not tracked, this must be manually applied to each repository clone.

## Related

- Original discussion: `discussion/2025-10-14-swiftui-typecheck-instability-v2.md`
- The hook correctly prevents actual SwiftUI body nesting issues that cause type-checker timeouts
- This fix ensures it only flags ACTUAL violations in view builders, not false positives in UIKit code
