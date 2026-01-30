//
//  AppDelegate.swift
//  Yiana
//
//  Ensures file URL opens (e.g., from Share → Copy to Yiana) are handled reliably.
//

import Foundation

// Define notifications for both iOS and macOS
extension Notification.Name {
    static let yianaOpenURL = Notification.Name("yianaOpenURL")
    static let yianaDocumentsChanged = Notification.Name("yianaDocumentsChanged")
    static let yianaDocumentsDownloaded = Notification.Name("yianaDocumentsDownloaded")
}

#if os(iOS)
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Broadcast to SwiftUI layer
        NotificationCenter.default.post(name: .yianaOpenURL, object: url)
        return true
    }
}
#endif
