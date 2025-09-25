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
        /// Use PencilKit overlay for drawing and annotations
        case pencilKit
    }

    /// Current active implementation (always PencilKit now)
    static let activeImplementation: MarkupImplementation = .pencilKit
    
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
}
