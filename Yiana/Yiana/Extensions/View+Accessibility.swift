//
//  View+Accessibility.swift
//  Yiana
//
//  Created by Codex on 14/10/2025.
//

import SwiftUI

extension View {
    /// Standard document row presentation for VoiceOver.
    func documentRowAccessibility(
        title: String,
        modified: Date,
        pageCount: Int? = nil,
        isPinned: Bool = false,
        hasUnsavedChanges: Bool = false
    ) -> some View {
        let relativeDate = modified.formatted(.relative(presentation: .named))
        var label = "\(title), modified \(relativeDate)"
        if let count = pageCount {
            label += ", \(count) \(count == 1 ? "page" : "pages")"
        }
        if isPinned {
            label += ", pinned"
        }
        if hasUnsavedChanges {
            label += ", unsaved changes"
        }

        return accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint("Double tap to open document")
            .accessibilityAddTraits(.isButton)
    }

    /// Accessibility description for a page thumbnail in grids or sidebars.
    func pageThumbnailAccessibility(
        pageNumber: Int,
        isSelected: Bool = false,
        isCurrent: Bool = false,
        isProvisional: Bool = false
    ) -> some View {
        var label = "Page \(pageNumber)"
        if isProvisional {
            label += ", draft"
        }
        if isCurrent {
            label += ", current page"
        }

        let value = isSelected ? "Selected" : ""
        let hint = isSelected
            ? "Double tap to navigate"
            : "Double tap to navigate, triple tap to select"

        var traits: AccessibilityTraits = [.isButton]
        if isCurrent {
            _ = traits.insert(.isSelected)
        }

        return accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(value)
            .accessibilityHint(hint)
            .accessibilityAddTraits(traits)
    }

    /// Accessibility wrapper for toolbar actions, optionally describing a keyboard shortcut.
    func toolbarActionAccessibility(
        label: String,
        keyboardShortcut: String? = nil
    ) -> some View {
        var hint = "Double tap to \(label.lowercased())"
        if let shortcut = keyboardShortcut {
            hint += ", or press \(shortcut)"
        }

        return accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
    }
}
