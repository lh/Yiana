import SwiftUI

/// Controls which UI layout variant is active.
/// Used during design exploration to compare alternatives at runtime.
enum UIVariant: String, CaseIterable, Identifiable {
    case current = "current"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .current: return "Current"
        }
    }

    /// Shared @AppStorage key
    static let storageKey = "uiVariant"
}
