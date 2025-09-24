//
//  MarkupConfiguration.swift
//  Yiana
//
//  Configuration for markup implementation selection
//

import Foundation

/// Configuration for markup feature implementation
struct MarkupConfiguration {
    
    /// Which markup implementation to use
    enum MarkupImplementation {
        /// Use Apple's QLPreviewController (currently broken in iOS 17+)
        case qlPreviewController

        /// Use PencilKit overlay for drawing and annotations
        case pencilKit
    }
    
    /// Storage key for runtime selection
    private static let implKey = "yiana.markupEngine"

    /// Current active implementation (backed by UserDefaults for runtime switching)
    static var activeImplementation: MarkupImplementation {
        get {
            guard let raw = UserDefaults.standard.string(forKey: implKey) else {
                return .pencilKit
            }
            switch raw {
            case "ql": return .qlPreviewController
            case "pencil": return .pencilKit
            default: return .pencilKit
            }
        }
        set {
            let raw: String
            switch newValue {
            case .qlPreviewController: raw = "ql"
            case .pencilKit: raw = "pencil"
            }
            UserDefaults.standard.set(raw, forKey: implKey)
        }
    }
    
    /// Check if QLPreviewController should be available
    /// Set to true when Apple fixes the iOS 17+ bug (FB14376916)
    static let isQLPreviewControllerFixed = false
    
    /// Feature flags for markup functionality
    struct Features {
        /// Enable text annotations
        static let textAnnotations = true
        
        /// Enable color selection
        static let colorSelection = true
        
        /// Enable eraser tool
        static let eraserTool = true
        
        /// Flatten annotations on save (make permanent)
        static let flattenOnSave = true
        
        /// Flatten annotations on page navigation
        static let flattenOnPageChange = true
        
        /// Create one-time backup before first markup
        static let createBackup = true
    }
    
    /// Get the recommended implementation based on iOS version and bug status
    static var recommendedImplementation: MarkupImplementation {
        if isQLPreviewControllerFixed {
            // If Apple has fixed the bug, we can use QLPreviewController
            return .qlPreviewController
        } else {
            // Use PencilKit implementation
            return .pencilKit
        }
    }
    
    /// Check if we should show a warning about implementation
    static var shouldShowImplementationWarning: Bool {
        #if DEBUG
        return activeImplementation == .qlPreviewController && !isQLPreviewControllerFixed
        #else
        return false
        #endif
    }
}

// MARK: - Future Migration Path

extension MarkupConfiguration {
    
    /// Instructions for reverting to QLPreviewController when Apple fixes the bug
    static let migrationInstructions = """
    To revert to QLPreviewController when Apple fixes FB14376916:

    1. Set MarkupConfiguration.isQLPreviewControllerFixed = true
    2. Change activeImplementation to .qlPreviewController
    3. Test thoroughly on iOS 17+ devices
    4. The MarkupCoordinator.swift code is preserved and ready to use

    The PencilKit implementation will remain as the primary option.
    """
}
