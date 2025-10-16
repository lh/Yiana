//
//  AccessibilityAnnouncer.swift
//  Yiana
//
//  Created by Codex on 14/10/2025.
//

import Foundation

#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class AccessibilityAnnouncer {
    static let shared = AccessibilityAnnouncer()
    private init() {}

    func post(_ message: String) {
        #if os(iOS) || os(tvOS) || os(visionOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #elseif os(macOS)
        let element: Any = NSApp.mainWindow as Any? ?? NSApp as Any
        NSAccessibility.post(
            element: element,
            notification: .announcementRequested,
            userInfo: [.announcement: message]
        )
        #endif
    }
}
