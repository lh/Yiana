import SwiftUI

/// Controls which UI layout variant is active.
/// Used during design exploration to compare alternatives at runtime.
enum UIVariant: String, CaseIterable, Identifiable {
    case current = "current"
    case v2 = "v2"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .current: return "V1 (Original)"
        case .v2: return "V2 (Compact Toolbar)"
        }
    }

    /// Shared @AppStorage key
    static let storageKey = "uiVariant"
}
