//
//  AppDelegate.swift
//  Yiana
//
//  Ensures file URL opens (e.g., from Share → Copy to Yiana) are handled reliably.
//

#if os(iOS)
import UIKit

extension Notification.Name {
    static let yianaOpenURL = Notification.Name("yianaOpenURL")
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Broadcast to SwiftUI layer
        NotificationCenter.default.post(name: .yianaOpenURL, object: url)
        return true
    }
}
#endif

