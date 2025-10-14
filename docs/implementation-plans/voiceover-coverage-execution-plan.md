# VoiceOver Coverage Execution Plan

**Date:** 14 Oct 2025  
**Status:** Ready for development  
**Author:** Codex  
**Scope:** Yiana iOS, iPadOS, macOS

---

## Objective
Lift VoiceOver accessibility coverage from <10% to full compliance across all interactive UI in Yiana while satisfying Apple’s Accessibility Inspector audit.

---

## High-Level Approach
1. Inventory every interactive element (buttons, toggles, list rows, custom thumbnails, text fields).
2. Define accurate `accessibilityLabel`, `accessibilityHint`, `accessibilityValue`, and traits per element type.
3. Verify groupings (`accessibilityElement(children:)`) for composite controls.
4. Run Accessibility Inspector + VoiceOver manual sessions to validate experience end-to-end.

---

## Work Breakdown

### Phase 1 – Audit & Tagging (2 days)
1. **Generate Control Inventory**
   - Use SwiftLint script to log occurrences of `Button`, `NavigationLink`, `List` etc. that lack `.accessibility` modifiers.
   - Manually review custom views (`DocumentRow`, `PageThumbnailView`, `MacPDFViewer` overlays, etc.).
   - Create a spreadsheet mapping each control to its screen and desired label/hint.
2. **Define Semantics**
   - For list rows: combine children to read as single element (title + metadata).
   - For toggles/buttons: provide action verbs (“Duplicate page”, “Open document”).
   - For Page Management thumbnails: include page number, selection state, provisional state.
3. **Annotate Code**
   - Add `.accessibilityLabel`, `.accessibilityHint`, `.accessibilityValue`, `.accessibilityAddTraits`, `.accessibilityRemoveTraits` as appropriate.
   - Use `.accessibilityElement(children: .combine)` / `.ignore` to avoid repetitive announcements.
   - Ensure macOS AppKit wrappers (NSViewRepresentable) expose accessibility via `NSAccessibility` where needed.

### Phase 2 – Structural Improvements (1 day)
1. **Navigation Hierarchy**
   - Mark major Sections with `.accessibilityHeading(.h1/.h2)` for document lists.
2. **Custom Controls**
   - Implement `AccessibilityElement` wrappers for complex components (e.g., PDF thumbnail grid) to manage focus traversal.
3. **Dynamic Content Updates**
   - Fire `UIAccessibility.post(notification:.announcement)` when operations complete (e.g., “Copied 2 pages”).
   - Ensure state changes update `accessibilityValue` (selected pages count, unsaved status).

### Phase 3 – Testing & Validation (1 day)
1. **Automated Checks**
   - Run Accessibility Inspector’s Audit on all major screens (iPhone, iPad, macOS).
   - Add UITest that launches VoiceOver using `XCUIDevice.shared.perform(NSSelectorFromString("setAccessibilityAccessibilityEnabled:"), with: true)` (if permissible) and navigates key flows.
2. **Manual VoiceOver Pass**
   - On-device testing: iPhone with VoiceOver (swipe navigation), iPad pointer support, macOS with VO keys.
   - Validate rotor navigation, ensure no unexpected focus traps.
   - Confirm user actions (copy, paste, delete) provide spoken feedback.

---

## Coding Standards & Helpers
- Create `Accessibility.swift` extensions with reusable helpers:
  ```swift
  extension View {
      func documentRowAccessibility(title: String, modified: Date, hasUnsavedChanges: Bool) -> some View { ... }
  }
  ```
- Add SwiftLint custom rule (`accessibility_required`) that warns when a `Button` lacks accessibility modifiers.
- Document best practices in `docs/STYLE_GUIDE.md` for future contributors.

---

## Deliverables
1. Updated UI code with comprehensive VoiceOver annotations.
2. Accessibility inventory document (spreadsheet or Notion page).
3. Accessibility Inspector reports archived in `docs/accessibility/`.
4. New automated lint rule + optional basic UITest for VoiceOver navigation.

---

## Acceptance Criteria
- VoiceOver reads all controls with descriptive labels and hints.
- No unlabeled buttons reported by Accessibility Inspector.
- Dynamic content updates announce state changes.
- QA sign-off after manual VoiceOver walkthrough on iPhone, iPad, macOS.

---

## Dependencies
- Access to real devices (recommended) plus simulator.
- Accessibility Inspector (macOS) and SwiftLint.
- Coordination with design to ensure labels/hints match terminology.

---

## Timeline
- Audit & tagging: 2 days
- Structural improvements: 1 day
- Validation & fixes: 1 day
Total: **~4 working days**

---

Following this plan will ensure Yiana meets Apple’s VoiceOver expectations and forms the foundation for broader accessibility compliance.***
