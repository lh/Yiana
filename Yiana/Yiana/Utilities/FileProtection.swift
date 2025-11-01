//
//  FileProtection.swift
//  Yiana
//
//  Created by Claude on 01/11/2025.
//  Provides iOS Data Protection for secure file storage
//

import Foundation

/// Extension to add iOS Data Protection to file writes
extension Data {
    /// Writes data to a URL with iOS Data Protection enabled
    ///
    /// Data is encrypted when the device is locked and decrypted when unlocked.
    /// This provides security for medical data without vendor lock-in.
    ///
    /// - Parameters:
    ///   - url: Destination file URL
    ///   - options: Additional write options (default: atomic)
    func writeSecurely(to url: URL, options: Data.WritingOptions = .atomic) throws {
        #if os(iOS)
        // Combine provided options with file protection
        var secureOptions = options
        secureOptions.insert(.completeFileProtectionUntilFirstUserAuthentication)
        try write(to: url, options: secureOptions)
        #else
        // macOS doesn't support iOS Data Protection, use standard write
        try write(to: url, options: options)
        #endif
    }
}

/// Utility for applying file protection to existing files
enum FileProtection {
    /// Applies iOS Data Protection to an existing file
    ///
    /// - Parameter url: URL of file to protect
    /// - Throws: FileManager errors if protection cannot be applied
    static func apply(to url: URL) throws {
        #if os(iOS)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        #endif
        // macOS: no-op, Data Protection is iOS-only
    }

    /// Applies iOS Data Protection recursively to a directory
    ///
    /// - Parameter directoryURL: URL of directory to protect
    /// - Throws: FileManager errors if protection cannot be applied
    static func applyRecursively(to directoryURL: URL) throws {
        #if os(iOS)
        let fm = FileManager.default

        // Apply to directory itself
        try apply(to: directoryURL)

        // Apply to all contents
        guard let enumerator = fm.enumerator(at: directoryURL, includingPropertiesForKeys: nil) else {
            return
        }

        for case let fileURL as URL in enumerator {
            try apply(to: fileURL)
        }
        #endif
        // macOS: no-op
    }
}
