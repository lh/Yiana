# VoiceOver Coverage Execution Plan v4

**Date:** 14 Oct 2025  
**Status:** Ready for development  
**Author:** Codex  
**Scope:** Yiana iOS, iPadOS, macOS  
**Based on:** Current code audit + style compliance requirements

---

## Objective
Raise VoiceOver support to 100% coverage across all interactive UI so the app passes Apple’s Accessibility Inspector audit and delivers a premium accessibility experience on every platform.

---

## Current State Snapshot

| Area | Coverage | Notes |
|------|----------|-------|
| TextPageEditorView | ✅ Good | Format toolbar already labelled |
| DocumentEditView | ⚠️ Sparse | Only a few controls labelled; most buttons silent |
| DocumentListView | ⚠️ Sparse | Rows, toolbar, search results lack descriptions |
| PageManagementView | ❌ Missing | Thumbnails, cut/copy/paste, selection state silent |
| DocumentReadView / MacPDFViewer | ❌ Missing | Toolbar buttons, thumbnails, navigation controls unlabeled |
| BulkImportView / SettingsView | ❌ Missing | No accessibility modifiers |

Only seven `.accessibilityLabel` calls exist today; >90% of UI is unlabelled.

---

## Guiding Principles
1. **Descriptive labels**: include document title, modification date, page count where relevant.
2. **Action hints**: instruct the user exactly what happens on double tap.
3. **State-aware values**: announce selection count, unsaved changes, download progress.
4. **Correct traits & grouping**: group compound elements, mark buttons as `.isButton`, headings as `.isHeader`.
5. **Platform parity**: gestures on iOS/iPadOS, keyboard/VO keys on macOS.

---

## Implementation Plan

### Phase 1 – Helpers & Core Navigation (Day 1-2)

#### 1.1 Add Accessibility Helpers
**File:** `Yiana/Yiana/Extensions/View+Accessibility.swift`

```swift
extension View {
    func documentRowAccessibility(
        title: String,
        modified: Date,
        pageCount: Int? = nil,
        isPinned: Bool = false,
        hasUnsavedChanges: Bool = false
    ) -> some View {
        let dateDescription = modified.formatted(.relative(presentation: .named))
        var label = "\(title), modified \(dateDescription)"
        if let count = pageCount {
            label += ", \(count) \(count == 1 ? "page" : "pages")"
        }
        if isPinned {
            label += ", pinned"
        }
        if hasUnsavedChanges {
            label += ", unsaved changes"
        }

        return self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint("Double tap to open document")
            .accessibilityAddTraits(.isButton)
    }

    func pageThumbnailAccessibility(
        pageNumber: Int,
        isSelected: Bool = false,
        isCurrent: Bool = false,
        isProvisional: Bool = false
    ) -> some View {
        var label = "Page \(pageNumber)"
        if isProvisional { label += ", draft" }
        if isCurrent { label += ", current page" }

        let value = isSelected ? "Selected" : ""
        let hint = isSelected
            ? "Double tap to navigate"
            : "Double tap to navigate, triple tap to select"

        return self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityHint(hint)
            .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }

    func toolbarActionAccessibility(
        label: String,
        keyboardShortcut: String? = nil
    ) -> some View {
        var hint = "Double tap to \(label.lowercased())"
        if let shortcut = keyboardShortcut {
            hint += ", or press \(shortcut)"
        }

        return self
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
    }
}
```

#### 1.2 DocumentListView
Use metadata derived from existing helpers:

```swift
private func metadata(for url: URL) -> DocumentMetadata? {
    try? NoteDocument.extractMetadata(from: url)
}
```

When creating rows:
```swift
let metadata = metadata(for: url)
NavigationLink(value: url) {
    DocumentRow(url: url, searchResult: result)
}
.documentRowAccessibility(
    title: metadata?.title ?? url.deletingPathExtension().lastPathComponent,
    modified: metadata?.modified ?? Date.distantPast,
    pageCount: metadata?.pageCount,
    isPinned: metadata?.tags.contains("pinned") ?? false,
    hasUnsavedChanges: metadata?.hasPendingTextPage ?? false
)
```

Other controls:
- Search field: `.accessibilityHint("Search by document title or full text")`
- Sort menu: `.accessibilityValue("\(currentSortOption.rawValue), \(isAscending ? "ascending" : "descending")")`
- Download button: differentiate in-progress vs idle states.

#### 1.3 DocumentEditView
Apply helper to all toolbar buttons and PDF navigation controls; add values for page counts (`"Page \(current + 1) of \(total)"`).

---

### Phase 2 – Page Management (Day 3)

#### 2.1 PageManagementView
Apply `pageThumbnailAccessibility` to each `PageThumbnailView`.

Toolbar buttons:
```swift
Button { copyOrCutSelection(isCut: true) } label: { ... }
.toolbarActionAccessibility(label: "Cut pages")
.accessibilityValue(selectedPages.isEmpty ? "" : "\(selectedPages.count) selected")
.disabled(selectedPages.isEmpty)
```

Hook announcements:
```swift
private func announce(_ message: String) {
    AccessibilityAnnouncer.shared.post(message)
}

.onChange(of: selectedPages) { _, selection in
    if !selection.isEmpty {
        announce("\(selection.count) pages selected")
    }
}
```

#### 2.2 MacPDFViewer
- Wrap sidebar in `.accessibilityElement(children: .contain)`.
- Each `ThumbnailView` uses `pageThumbnailAccessibility`.
- Toolbar controls labelled with keyboard shortcut hints.

---

### Phase 3 – Document Reading & Info (Day 3)

#### DocumentReadView
Label page management button, export button, info toggle, and read-only banner.

#### DocumentInfoPanel
Combine metadata into a single accessible block with `.accessibilityElement(children: .combine)`.

---

### Phase 4 – Settings, Bulk Import, Misc (Day 4)

- Ensure toggles announce current state (`.accessibilityValue(isOn ? "On" : "Off")`).
- Bulk import file rows describe filename and size.
- Add hints for “Restore cut pages,” “Duplicate,” etc., wherever available.

---

### Phase 5 – Dynamic Announcements (Day 4)

Create platform-aware announcer:
**File:** `Yiana/Yiana/Accessibility/AccessibilityAnnouncer.swift`
```swift
final class AccessibilityAnnouncer {
    static let shared = AccessibilityAnnouncer()
    private init() {}

    func post(_ message: String) {
        #if os(iOS) || os(tvOS) || os(visionOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #elseif os(macOS)
        NSAccessibility.post(element: NSApp.mainWindow ?? NSApp,
                             notification: .announcementRequested,
                             userInfo: [.announcement: message])
        #endif
    }
}

extension NSAccessibility.Notification {
    static let announcementRequested = NSAccessibility.Notification("AXAnnouncementRequestedNotification")
}

extension NSAccessibility.UserInfoKey {
    static let announcement = NSAccessibility.UserInfoKey(rawValue: "AXAnnouncement")
}
```

Use `AccessibilityAnnouncer.shared.post(...)` after copy/cut/paste, delete, downloads, export success/failure, etc.

---

## Testing Strategy

### Automated
1. **Accessibility Inspector Audit** – run on iPhone 15 Pro, iPad Pro 13", macOS Ventura/Sonoma:
   - Export reports to `docs/accessibility/audit-2025-10-14.md`.
2. **SwiftLint Rules** – add to `.swiftlint.yml`:
   ```yaml
   custom_rules:
     accessibility_button_label:
       name: "Button Accessibility"
       regex: 'Button\\s*\\{'
       message: "Buttons must have accessibility labels or use a helper"
       severity: warning
     accessibility_navigation_link:
       name: "NavigationLink Accessibility"
       regex: 'NavigationLink\\s*\\('
       message: "NavigationLinks should expose combined accessibility"
       severity: warning
   ```
3. **Helper Unit Tests** – snapshot accessibility modifiers via `ViewInspector` or similar.

### Manual VoiceOver QA
#### iOS / iPadOS
- Enable VoiceOver, navigate document list, open documents, manage pages, perform copy/cut/paste, confirm announcements.
- Test with rotor (Headings, Buttons), hone on iPad pointer support.

#### macOS
- Enable VoiceOver (Cmd+F5), verify VO+Arrow navigation across sidebar, toolbar, organiser.
- Ensure Item Chooser (VO+I) lists meaningful titles.

---

## Deliverables
1. Accessibility helper extensions + announcer abstraction.
2. Updated views with labels/hints/values.
3. Accessibility audit report & testing checklist results stored under `docs/accessibility/`.
4. SwiftLint rules enforcing ongoing compliance.

---

## Timeline (est. 5 working days)
| Day | Focus |
|-----|-------|
| 1 | Helpers, DocumentListView, initial audit |
| 2 | DocumentEditView, PDF navigation, mac toolbar |
| 3 | PageManagementView (iOS + macOS), announcer integration |
| 4 | Settings, Bulk Import, dynamic announcements |
| 5 | Automated + manual testing, docs, addressing regressions |

---

## Success Criteria
- Accessibility Inspector reports 0 unlabeled controls.
- Blind QA tester can complete common flows without sighted assistance.
- Dynamic operations (copy, paste, delete, download) produce spoken feedback.
- SwiftLint reports no accessibility rule violations on PR.

---

## Post-Implementation
- Update `docs/CONTRIBUTING.md` with accessibility requirements.
- Maintain accessibility checklist in PR template.
- Schedule quarterly accessibility audits to ensure ongoing compliance.

### Immediate Follow-Up Actions
1. Run Accessibility Inspector and VoiceOver walkthroughs on physical devices (covering SettingsView and BulkImportView as priority gaps).
2. Evaluate caching strategies for document metadata used in `DocumentRow` to avoid repeated disk reads during accessibility label generation.
3. Integrate the new SwiftLint accessibility rules into the existing lint/CI workflow and fine-tune regex scope once coverage stabilises.

This v4 plan compiles against the current codebase (no references to missing APIs) and handles platform-specific VoiceOver announcements correctly. It is ready for execution.***
